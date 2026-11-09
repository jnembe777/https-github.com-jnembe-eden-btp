import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import type {
  AirtelCollectionInput,
  AirtelCollectionResponse,
  AirtelNormalizedStatus,
  AirtelStatusInput,
  AirtelStatusResponse,
  AirtelTransactionStatusCode,
  IAirtelClient,
} from "@/lib/airtel.server";

// ============== Public: list plans ==============
export const listPlans = createServerFn({ method: "GET" }).handler(async () => {
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  const { data, error } = await supabaseAdmin
    .from("subscription_plans")
    .select("id, code, account_type, interval, name, amount_xaf, currency, sort_order")
    .eq("active", true)
    .order("account_type", { ascending: true })
    .order("sort_order", { ascending: true });
  if (error) throw new Error(error.message);
  return { plans: data ?? [] };
});

// ============== Authenticated: get my subscription + profile + access level ==============
export const getMyAccount = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }) => {
    const { supabase, userId } = context;

    const [{ data: profile }, { data: sub }, { data: access }] = await Promise.all([
      supabase.from("profiles").select("*").eq("id", userId).maybeSingle(),
      supabase
        .from("subscriptions")
        .select("*, plan:subscription_plans(*)")
        .eq("user_id", userId)
        .maybeSingle(),
      supabase.rpc("get_access_level", { _user_id: userId }),
    ]);

    return {
      profile: profile ?? null,
      subscription: sub ?? null,
      accessLevel: (access as unknown as string) ?? "none",
    };
  });

// ============== Authenticated: list my payments ==============
export const getMyPayments = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }) => {
    const { data, error } = await context.supabase
      .from("payments")
      .select("id, transaction_id, amount_xaf, currency, method, status, created_at, plan:subscription_plans(name)")
      .order("created_at", { ascending: false })
      .limit(50);
    if (error) throw new Error(error.message);
    return { payments: data ?? [] };
  });

// ============== Authenticated: initiate CinetPay payment ==============
const initiateInput = z.object({
  planId: z.string().uuid(),
  method: z.enum(["card", "mobile_money"]),
});

export const initiatePayment = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .validator((data: unknown) => initiateInput.parse(data))
  .handler(async ({ data, context }) => {
    const { supabase, userId } = context;
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");

    // Load plan + profile
    const [{ data: plan }, { data: profile }] = await Promise.all([
      supabase
        .from("subscription_plans")
        .select("id, name, amount_xaf, currency, account_type")
        .eq("id", data.planId)
        .eq("active", true)
        .maybeSingle(),
      supabase.from("profiles").select("*").eq("id", userId).maybeSingle(),
    ]);
    if (!plan) throw new Error("Plan introuvable");

    // CinetPay credentials
    const apiKey = process.env.CINETPAY_API_KEY;
    const siteId = process.env.CINETPAY_SITE_ID;
    const notifyBase = process.env.PUBLIC_APP_URL ?? "";
    if (!apiKey || !siteId) {
      throw new Error(
        "Paiement non configuré : les clés CinetPay (CINETPAY_API_KEY, CINETPAY_SITE_ID) ne sont pas définies.",
      );
    }

    // Unique transaction ref
    const transactionId = `EF-${userId.slice(0, 8)}-${Date.now()}`;

    // Insert pending payment (admin to bypass RLS insert restriction)
    const { error: insErr } = await supabaseAdmin.from("payments").insert({
      user_id: userId,
      plan_id: plan.id,
      transaction_id: transactionId,
      provider: "cinetpay",
      amount_xaf: plan.amount_xaf,
      currency: plan.currency,
      method: data.method,
      status: "pending",
    });
    if (insErr) throw new Error(insErr.message);

    // Call CinetPay init API
    const payload = {
      apikey: apiKey,
      site_id: siteId,
      transaction_id: transactionId,
      amount: plan.amount_xaf,
      currency: plan.currency,
      description: `Abonnement ${plan.name}`,
      notify_url: `${notifyBase}/api/public/cinetpay-webhook`,
      return_url: `${notifyBase}/console/abonnement?tx=${transactionId}`,
      channels: data.method === "card" ? "CREDIT_CARD" : "MOBILE_MONEY",
      customer_id: userId,
      customer_name: profile?.full_name ?? profile?.company_name ?? "Client",
      customer_surname: " ",
      customer_email: "",
      customer_phone_number: profile?.phone ?? "",
      customer_address: profile?.company_address ?? "",
      customer_city: " ",
      customer_country: profile?.country ?? "CM",
      customer_state: " ",
      customer_zip_code: " ",
      metadata: JSON.stringify({ user_id: userId, plan_id: plan.id }),
    };

    const res = await fetch("https://api-checkout.cinetpay.com/v2/payment", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    const body = (await res.json()) as {
      code?: string;
      message?: string;
      data?: { payment_url?: string; payment_token?: string };
    };

    if (body.code !== "201" || !body.data?.payment_url) {
      await supabaseAdmin
        .from("payments")
        .update({ status: "failed", raw_response: body })
        .eq("transaction_id", transactionId);
      throw new Error(`CinetPay: ${body.message ?? "init refusée"}`);
    }

    return {
      paymentUrl: body.data.payment_url,
      transactionId,
    };
  });

// ============== Authenticated: initiate Airtel Money payment (Gabon UAT) ==============
const airtelInput = z.object({
  planId: z.string().uuid(),
  msisdn: z
    .string()
    .trim()
    .regex(/^[0-9]{8,12}$/, "Numéro invalide (chiffres uniquement)"),
});

export const initiateAirtelPayment = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .validator((d: unknown) => airtelInput.parse(d))
  .handler(async ({ data, context }) => {
    const { supabase, userId } = context;
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const { getAirtelClient } = await import("@/lib/airtel.server");

    const { data: plan } = await supabase
      .from("subscription_plans")
      .select("id, name, amount_xaf, currency")
      .eq("id", data.planId)
      .eq("active", true)
      .maybeSingle();
    if (!plan) throw new Error("Plan introuvable");

    const transactionId = `EFA-${userId.slice(0, 8)}-${Date.now()}`;

    const { error: insErr } = await supabaseAdmin.from("payments").insert({
      user_id: userId,
      plan_id: plan.id,
      transaction_id: transactionId,
      provider: "airtel",
      amount_xaf: plan.amount_xaf,
      currency: plan.currency,
      method: "mobile_money",
      status: "pending",
    });
    if (insErr) throw new Error(insErr.message);

    try {
      const client: IAirtelClient = getAirtelClient();
      const collectionInput: AirtelCollectionInput = {
        msisdn: data.msisdn,
        amount: plan.amount_xaf,
        currency: "XAF",
        country: "GA",
        reference: `Abonnement ${plan.name}`,
        transactionId,
      };
      const _resp: AirtelCollectionResponse = await client.initiateCollection(
        collectionInput,
      );
      void _resp;
    } catch (e) {
      await supabaseAdmin
        .from("payments")
        .update({ status: "failed" })
        .eq("transaction_id", transactionId);
      throw e;
    }

    return { transactionId };
  });

// ============== Authenticated: poll Airtel transaction status ==============
const airtelStatusInput = z.object({
  transactionId: z.string().trim().min(3).max(80),
});

export const checkAirtelStatus = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .validator((d: unknown) => airtelStatusInput.parse(d))
  .handler(async ({ data, context }) => {
    const { userId } = context;
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const {
      getAirtelClient,
      normalizeAirtelStatus,
    } = await import("@/lib/airtel.server");

    // Vérifie que cette transaction appartient bien à l'utilisateur
    const { data: payment } = await supabaseAdmin
      .from("payments")
      .select("id, user_id, status, transaction_id, provider_payment_id")
      .eq("transaction_id", data.transactionId)
      .maybeSingle();
    if (!payment || payment.user_id !== userId) {
      throw new Error("Transaction introuvable");
    }

    const client: IAirtelClient = getAirtelClient();
    const statusInput: AirtelStatusInput = {
      transactionId: data.transactionId,
      country: "GA",
      currency: "XAF",
    };
    const res: AirtelStatusResponse = await client.getTransactionStatus(statusInput);
    const tx = res.data?.transaction;
    const code: AirtelTransactionStatusCode | null =
      (tx?.status as AirtelTransactionStatusCode | undefined) ?? null;
    const mapped: AirtelNormalizedStatus = normalizeAirtelStatus(code);

    if (mapped !== payment.status) {
      await supabaseAdmin
        .from("payments")
        .update({
          status: mapped,
          provider_payment_id: tx?.airtel_money_id ?? payment.provider_payment_id,
          raw_response: JSON.parse(JSON.stringify(res)),
        })
        .eq("transaction_id", data.transactionId);
    }

    return {
      transactionId: data.transactionId,
      airtelStatusCode: code,
      status: mapped,
      airtelMoneyId: tx?.airtel_money_id ?? null,
      message: tx?.message ?? res.status?.message ?? null,
    };
  });


// ============== Authenticated: update profile ==============
const profileInput = z.object({
  full_name: z.string().trim().max(200).optional().nullable(),
  phone: z.string().trim().max(40).optional().nullable(),
  country: z.string().trim().max(80).optional().nullable(),
  company_name: z.string().trim().max(200).optional().nullable(),
  company_tax_id: z.string().trim().max(60).optional().nullable(),
  company_address: z.string().trim().max(300).optional().nullable(),
});

export const updateMyProfile = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .validator((d: unknown) => profileInput.parse(d))
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase
      .from("profiles")
      .update(data)
      .eq("id", context.userId);
    if (error) throw new Error(error.message);
    return { ok: true };
  });
