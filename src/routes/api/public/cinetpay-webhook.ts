import { createFileRoute } from "@tanstack/react-router";
import { createHmac, timingSafeEqual } from "crypto";

/**
 * CinetPay webhook handler.
 *
 * CinetPay POSTs form-encoded data with:
 *  - cpm_trans_id (our transaction_id)
 *  - cpm_site_id
 *  - signature (HMAC, header `x-token`)
 * We then re-query CinetPay /v2/payment/check to validate the real status.
 */
export const Route = createFileRoute("/api/public/cinetpay-webhook")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        const secretKey = process.env.CINETPAY_SECRET_KEY ?? "";
        const apiKey = process.env.CINETPAY_API_KEY ?? "";
        const siteId = process.env.CINETPAY_SITE_ID ?? "";
        if (!secretKey || !apiKey || !siteId) {
          return new Response("Webhook not configured", { status: 500 });
        }

        const rawBody = await request.text();
        const params = new URLSearchParams(rawBody);
        const transactionId = params.get("cpm_trans_id");
        const incomingToken = request.headers.get("x-token") ?? "";

        if (!transactionId) {
          return new Response("Missing transaction_id", { status: 400 });
        }

        // Signature verification (per CinetPay docs: HMAC-SHA256 of concat of
        // ordered fields with the secret). We do a best-effort check on the body.
        if (incomingToken) {
          const expected = createHmac("sha256", secretKey)
            .update(rawBody)
            .digest("hex");
          try {
            const a = Buffer.from(incomingToken);
            const b = Buffer.from(expected);
            if (a.length !== b.length || !timingSafeEqual(a, b)) {
              // Don't hard-fail — CinetPay signature scheme varies; we also
              // re-verify via the check endpoint below.
              console.warn("CinetPay HMAC mismatch for", transactionId);
            }
          } catch {
            // ignore comparison errors
          }
        }

        // Verify with CinetPay
        const verifyRes = await fetch(
          "https://api-checkout.cinetpay.com/v2/payment/check",
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              apikey: apiKey,
              site_id: siteId,
              transaction_id: transactionId,
            }),
          },
        );
        const verifyBody = (await verifyRes.json()) as {
          code?: string;
          message?: string;
          data?: {
            status?: string;
            amount?: string | number;
            currency?: string;
            payment_method?: string;
            operator_id?: string;
          };
        };

        const { supabaseAdmin } = await import(
          "@/integrations/supabase/client.server"
        );

        const { data: payment } = await supabaseAdmin
          .from("payments")
          .select("id, user_id, plan_id, status, amount_xaf")
          .eq("transaction_id", transactionId)
          .maybeSingle();

        if (!payment) {
          return new Response("Payment not found", { status: 404 });
        }
        if (payment.status === "succeeded") {
          return new Response("Already processed", { status: 200 });
        }

        const cpStatus = verifyBody.data?.status ?? "FAILED";
        const isSuccess = verifyBody.code === "00" && cpStatus === "ACCEPTED";

        if (!isSuccess) {
          await supabaseAdmin
            .from("payments")
            .update({ status: "failed", raw_response: verifyBody })
            .eq("id", payment.id);
          return new Response("Payment failed", { status: 200 });
        }

        // Load plan to know the interval
        const { data: plan } = await supabaseAdmin
          .from("subscription_plans")
          .select("id, interval")
          .eq("id", payment.plan_id!)
          .maybeSingle();

        // Compute new period end
        const now = new Date();
        const end = new Date(now);
        if (plan?.interval === "monthly") end.setMonth(end.getMonth() + 1);
        else if (plan?.interval === "quarterly") end.setMonth(end.getMonth() + 3);
        else if (plan?.interval === "yearly") end.setFullYear(end.getFullYear() + 1);

        // Upsert subscription
        const { data: existingSub } = await supabaseAdmin
          .from("subscriptions")
          .select("id")
          .eq("user_id", payment.user_id)
          .maybeSingle();

        if (existingSub) {
          await supabaseAdmin
            .from("subscriptions")
            .update({
              plan_id: payment.plan_id,
              status: "active",
              current_period_start: now.toISOString(),
              current_period_end: end.toISOString(),
              cancel_at_period_end: false,
            })
            .eq("id", existingSub.id);
        } else {
          await supabaseAdmin.from("subscriptions").insert({
            user_id: payment.user_id,
            plan_id: payment.plan_id,
            status: "active",
            current_period_start: now.toISOString(),
            current_period_end: end.toISOString(),
          });
        }

        const { data: subRow } = await supabaseAdmin
          .from("subscriptions")
          .select("id")
          .eq("user_id", payment.user_id)
          .maybeSingle();

        await supabaseAdmin
          .from("payments")
          .update({
            status: "succeeded",
            subscription_id: subRow?.id ?? null,
            provider_payment_id: verifyBody.data?.operator_id ?? null,
            raw_response: verifyBody,
          })
          .eq("id", payment.id);

        return new Response("ok", { status: 200 });
      },
      GET: async () => new Response("CinetPay webhook endpoint", { status: 200 }),
    },
  },
});
