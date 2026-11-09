/**
 * Airtel Money webhook (callback URL).
 * À configurer dans le portail Airtel : POST /api/public/airtel-webhook
 * Le body Airtel ressemble à :
 * { transaction: { id, status_code, airtel_money_id, message } }
 * status_code: TS = succès, TF = échec.
 */
import { createFileRoute } from "@tanstack/react-router";
import { supabaseAdmin } from "@/integrations/supabase/client.server";

interface AirtelCallbackBody {
  // Forme "notification serveur" historique
  transaction?: {
    id?: string;
    status_code?: string;
    status?: string;
    airtel_money_id?: string;
    message?: string;
  };
  // Forme alignée sur la réponse API actuelle
  data?: {
    message?: string;
    status?: string;
    transaction?: {
      id?: string;
      status?: string;
      airtel_money_id?: string;
    };
  };
  status?: { code?: string; message?: string; success?: boolean };
  hash?: string;
}

export const Route = createFileRoute("/api/public/airtel-webhook")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        let payload: AirtelCallbackBody;
        try {
          payload = (await request.json()) as AirtelCallbackBody;
        } catch {
          return new Response("Invalid JSON", { status: 400 });
        }

        const tx = payload.data?.transaction ?? payload.transaction ?? {};
        const transactionId = tx.id;
        const txStatus = (tx.status ?? "").toUpperCase();
        const statusCode = payload.transaction?.status_code;

        if (!transactionId) {
          return new Response("Missing transaction.id", { status: 400 });
        }

        const success =
          payload.status?.success === true ||
          txStatus === "SUCCESS" ||
          statusCode === "TS";

        // Récupère le paiement correspondant
        const { data: payment } = await supabaseAdmin
          .from("payments")
          .select("id, user_id, plan_id, subscription_id, status")
          .eq("transaction_id", transactionId)
          .eq("provider", "airtel")
          .maybeSingle();

        if (!payment) {
          // Inconnu — on ACK pour qu'Airtel n'insiste pas
          return Response.json({ ok: true, ignored: true });
        }

        const newStatus = success ? "succeeded" : "failed";

        await supabaseAdmin
          .from("payments")
          .update({
            status: newStatus,
            provider_payment_id: tx.airtel_money_id ?? null,
            raw_response: JSON.parse(JSON.stringify(payload)),
          })
          .eq("id", payment.id);

        // Active l'abonnement si succès
        if (success && payment.plan_id) {
          const { data: plan } = await supabaseAdmin
            .from("subscription_plans")
            .select("interval")
            .eq("id", payment.plan_id)
            .maybeSingle();

          const months =
            plan?.interval === "yearly"
              ? 12
              : plan?.interval === "quarterly"
                ? 3
                : 1;
          const now = new Date();
          const end = new Date(now);
          end.setMonth(end.getMonth() + months);

          await supabaseAdmin
            .from("subscriptions")
            .update({
              status: "active",
              plan_id: payment.plan_id,
              current_period_start: now.toISOString(),
              current_period_end: end.toISOString(),
            })
            .eq("user_id", payment.user_id);
        }

        return Response.json({ ok: true });
      },
    },
  },
});
