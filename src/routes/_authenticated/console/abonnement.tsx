import { createFileRoute } from "@tanstack/react-router";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { useState } from "react";
import {
  CreditCard,
  Smartphone,
  Check,
  Loader2,
  AlertTriangle,
  Calendar,
  User,
  Building2,
} from "lucide-react";
import { z } from "zod";

import {
  getMyAccount,
  getMyPayments,
  listPlans,
  initiatePayment,
  initiateAirtelPayment,
  checkAirtelStatus,
} from "@/lib/subscriptions.functions";
import { Button } from "@/components/ui/button";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { cn } from "@/lib/utils";
import { AirtelStatusCard } from "@/components/edenfin/airtel-status-card";

const searchSchema = z.object({
  plan: z.string().optional(),
  tx: z.string().optional(),
});

export const Route = createFileRoute("/_authenticated/console/abonnement")({
  validateSearch: (s) => searchSchema.parse(s),
  component: AbonnementPage,
});

function formatXAF(n: number) {
  return new Intl.NumberFormat("fr-FR").format(n) + " F CFA";
}
function formatDate(s: string | null | undefined) {
  if (!s) return "—";
  return new Date(s).toLocaleDateString("fr-FR", {
    day: "2-digit",
    month: "long",
    year: "numeric",
  });
}

const STATUS_BADGE: Record<string, { label: string; cls: string }> = {
  active: { label: "Actif", cls: "bg-emerald-500/15 text-emerald-700 dark:text-emerald-400" },
  trialing: { label: "Essai", cls: "bg-blue-500/15 text-blue-700 dark:text-blue-400" },
  past_due: { label: "En retard", cls: "bg-amber-500/15 text-amber-700 dark:text-amber-400" },
  canceled: { label: "Annulé", cls: "bg-muted text-muted-foreground" },
  expired: { label: "Expiré", cls: "bg-destructive/15 text-destructive" },
};






function AbonnementPage() {
  const { plan: preselectedPlanId, tx } = Route.useSearch();
  const queryClient = useQueryClient();

  const accountFn = useServerFn(getMyAccount);
  const plansFn = useServerFn(listPlans);
  const paymentsFn = useServerFn(getMyPayments);
  const initiateFn = useServerFn(initiatePayment);
  const initiateAirtelFn = useServerFn(initiateAirtelPayment);
  const checkAirtelFn = useServerFn(checkAirtelStatus);

  const accountQ = useQuery({ queryKey: ["my-account"], queryFn: () => accountFn() });
  const plansQ = useQuery({ queryKey: ["plans"], queryFn: () => plansFn() });
  const paymentsQ = useQuery({ queryKey: ["my-payments"], queryFn: () => paymentsFn() });

  const accountType = accountQ.data?.profile?.account_type ?? "individual";
  const country = (accountQ.data?.profile?.country ?? "").toLowerCase();
  const isGabon = country === "ga" || country.startsWith("gab");
  const [tab, setTab] = useState<"individual" | "company">(accountType);
  const [selectedPlan, setSelectedPlan] = useState<string | null>(
    preselectedPlanId ?? null,
  );
  const [method, setMethod] = useState<"card" | "mobile_money" | "airtel_ga">(
    "mobile_money",
  );
  const [airtelMsisdn, setAirtelMsisdn] = useState("");
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [airtelInfo, setAirtelInfo] = useState<string | null>(null);
  const [airtelResult, setAirtelResult] = useState<{
    transactionId: string;
    status: "succeeded" | "failed" | "pending";
    airtelStatusCode: string | null;
    airtelMoneyId: string | null;
    message: string | null;
  } | null>(null);

  // --- Panneau de test Airtel (independant du flow d'abonnement) ---
  const [testMsisdn, setTestMsisdn] = useState("");
  const [testTxId, setTestTxId] = useState<string | null>(null);
  const [testResult, setTestResult] = useState<{
    status: "succeeded" | "failed" | "pending";
    airtelStatusCode: string | null;
    airtelMoneyId: string | null;
    message: string | null;
  } | null>(null);

  const payMutation = useMutation({
    mutationFn: (vars: { planId: string; method: "card" | "mobile_money" }) =>
      initiateFn({ data: vars }),
    onSuccess: ({ paymentUrl }) => {
      window.location.href = paymentUrl;
    },
    onError: (err) => {
      setErrorMsg(err instanceof Error ? err.message : "Erreur de paiement");
    },
  });

  const pollStatus = async (transactionId: string, attempts = 6) => {
    for (let i = 0; i < attempts; i++) {
      await new Promise((r) => setTimeout(r, i === 0 ? 2000 : 3000));
      try {
        const r = await checkAirtelFn({ data: { transactionId } });
        if (r.status !== "pending") return r;
        // continue
        if (i === attempts - 1) return r;
      } catch (e) {
        if (i === attempts - 1) throw e;
      }
    }
    return null;
  };

  const airtelMutation = useMutation({
    mutationFn: (vars: { planId: string; msisdn: string }) =>
      initiateAirtelFn({ data: vars }),
    onSuccess: async ({ transactionId }) => {
      setAirtelInfo(
        `Demande envoyée. Validez le paiement sur votre téléphone (référence ${transactionId}).`,
      );
      setAirtelResult({
        transactionId,
        status: "pending",
        airtelStatusCode: null,
        airtelMoneyId: null,
        message: null,
      });
      queryClient.invalidateQueries({ queryKey: ["my-payments"] });
      try {
        const r = await pollStatus(transactionId);
        if (r) setAirtelResult({ ...r });
        queryClient.invalidateQueries({ queryKey: ["my-payments"] });
      } catch (e) {
        setErrorMsg(e instanceof Error ? e.message : "Erreur statut Airtel");
      }
    },
    onError: (err) => {
      setErrorMsg(err instanceof Error ? err.message : "Erreur Airtel Money");
    },
  });

  // Test mutation : utilise le plan le moins cher pour générer une transaction réelle
  const testMutation = useMutation({
    mutationFn: async (vars: { msisdn: string }) => {
      // On réutilise le premier plan disponible pour matérialiser la transaction côté DB
      const cheapest = [...(plansQ.data?.plans ?? [])].sort(
        (a, b) => a.amount_xaf - b.amount_xaf,
      )[0];
      if (!cheapest) throw new Error("Aucun plan disponible pour le test");
      const init = await initiateAirtelFn({
        data: { planId: cheapest.id, msisdn: vars.msisdn },
      });
      setTestTxId(init.transactionId);
      setTestResult({
        status: "pending",
        airtelStatusCode: null,
        airtelMoneyId: null,
        message: "Demande envoyée, en attente de validation…",
      });
      const r = await pollStatus(init.transactionId);
      return { transactionId: init.transactionId, result: r };
    },
    onSuccess: ({ result }) => {
      if (result) {
        setTestResult({
          status: result.status,
          airtelStatusCode: result.airtelStatusCode,
          airtelMoneyId: result.airtelMoneyId,
          message: result.message,
        });
      }
      queryClient.invalidateQueries({ queryKey: ["my-payments"] });
    },
    onError: (err) => {
      setTestResult({
        status: "failed",
        airtelStatusCode: null,
        airtelMoneyId: null,
        message: err instanceof Error ? err.message : "Erreur test Airtel",
      });
    },
  });

  const sub = accountQ.data?.subscription ?? null;
  const profile = accountQ.data?.profile;
  const plans = plansQ.data?.plans ?? [];
  const payments = paymentsQ.data?.payments ?? [];
  const status = sub?.status ?? "expired";
  const badge = STATUS_BADGE[status] ?? STATUS_BADGE.expired;

  return (
    <div className="space-y-8 p-6 lg:p-8">
      <header className="space-y-1">
        <h1 className="font-display text-2xl font-bold tracking-tight">Abonnement</h1>
        <p className="text-sm text-muted-foreground">
          Gérez votre formule, renouvelez ou changez de plan.
        </p>
      </header>

      {tx ? (
        <div className="rounded-lg border border-blue-500/30 bg-blue-500/5 p-4 text-sm">
          Paiement <code className="font-mono text-xs">{tx}</code> en cours de
          vérification. Le statut sera mis à jour automatiquement dans quelques
          secondes.
        </div>
      ) : null}

      {/* Current subscription */}
      <section className="rounded-xl border border-border bg-card p-6">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div className="space-y-2">
            <div className="flex items-center gap-3">
              <h2 className="text-lg font-semibold">Mon abonnement</h2>
              <span className={cn("rounded-full px-2.5 py-0.5 text-xs font-medium", badge.cls)}>
                {badge.label}
              </span>
            </div>
            <div className="flex flex-wrap items-center gap-4 text-sm text-muted-foreground">
              <span className="inline-flex items-center gap-1.5">
                {profile?.account_type === "company" ? (
                  <Building2 className="h-4 w-4" />
                ) : (
                  <User className="h-4 w-4" />
                )}
                Compte {profile?.account_type === "company" ? "Société" : "Individuel"}
              </span>
              {sub?.plan ? (
                <span className="font-medium text-foreground">{sub.plan.name}</span>
              ) : null}
              <span className="inline-flex items-center gap-1.5">
                <Calendar className="h-4 w-4" />
                {status === "trialing"
                  ? `Essai jusqu'au ${formatDate(sub?.trial_end)}`
                  : `Période en cours jusqu'au ${formatDate(sub?.current_period_end)}`}
              </span>
            </div>
          </div>
        </div>
      </section>

      {/* Choose plan */}
      <section className="space-y-4">
        <h2 className="text-lg font-semibold">
          {sub?.status === "active" ? "Renouveler ou changer de plan" : "Choisir une formule"}
        </h2>

        <Tabs value={tab} onValueChange={(v) => setTab(v as typeof tab)}>
          <TabsList className="grid w-full max-w-md grid-cols-2">
            <TabsTrigger value="individual">Individuel</TabsTrigger>
            <TabsTrigger value="company">Société</TabsTrigger>
          </TabsList>

          {(["individual", "company"] as const).map((type) => (
            <TabsContent key={type} value={type} className="mt-6">
              <div className="grid gap-4 md:grid-cols-3">
                {plans
                  .filter((p) => p.account_type === type)
                  .map((p) => {
                    const isSelected = selectedPlan === p.id;
                    return (
                      <button
                        key={p.id}
                        type="button"
                        onClick={() => setSelectedPlan(p.id)}
                        className={cn(
                          "rounded-xl border bg-card p-5 text-left transition",
                          isSelected
                            ? "border-gold ring-2 ring-gold/30"
                            : "border-border hover:border-foreground/30",
                        )}
                      >
                        <div className="flex items-center justify-between">
                          <span className="text-sm font-semibold uppercase tracking-wide text-muted-foreground">
                            {p.interval === "monthly"
                              ? "Mensuel"
                              : p.interval === "quarterly"
                                ? "Trimestriel"
                                : "Annuel"}
                          </span>
                          {isSelected ? <Check className="h-4 w-4 text-gold" /> : null}
                        </div>
                        <p className="mt-3 text-2xl font-bold">{formatXAF(p.amount_xaf)}</p>
                      </button>
                    );
                  })}
              </div>
            </TabsContent>
          ))}
        </Tabs>
      </section>

      {/* Payment method */}
      {selectedPlan ? (
        <section className="space-y-4">
          <h2 className="text-lg font-semibold">Mode de paiement</h2>
          <div className={cn("grid gap-3", isGabon ? "sm:grid-cols-3" : "sm:grid-cols-2")}>
            <button
              type="button"
              onClick={() => setMethod("mobile_money")}
              className={cn(
                "flex items-center gap-3 rounded-xl border p-4 text-left transition",
                method === "mobile_money"
                  ? "border-gold ring-2 ring-gold/30"
                  : "border-border hover:border-foreground/30",
              )}
            >
              <Smartphone className="h-5 w-5 text-gold" />
              <div>
                <p className="font-medium">Mobile money</p>
                <p className="text-xs text-muted-foreground">
                  Orange Money, MTN MoMo, Moov
                </p>
              </div>
            </button>
            <button
              type="button"
              onClick={() => setMethod("card")}
              className={cn(
                "flex items-center gap-3 rounded-xl border p-4 text-left transition",
                method === "card"
                  ? "border-gold ring-2 ring-gold/30"
                  : "border-border hover:border-foreground/30",
              )}
            >
              <CreditCard className="h-5 w-5 text-gold" />
              <div>
                <p className="font-medium">Carte bancaire</p>
                <p className="text-xs text-muted-foreground">Visa, Mastercard</p>
              </div>
            </button>
            {isGabon ? (
              <button
                type="button"
                onClick={() => setMethod("airtel_ga")}
                className={cn(
                  "flex items-center gap-3 rounded-xl border p-4 text-left transition",
                  method === "airtel_ga"
                    ? "border-gold ring-2 ring-gold/30"
                    : "border-border hover:border-foreground/30",
                )}
              >
                <Smartphone className="h-5 w-5 text-gold" />
                <div>
                  <p className="font-medium">Airtel Money Gabon</p>
                  <p className="text-xs text-muted-foreground">
                    Validation USSD directe
                  </p>
                </div>
              </button>
            ) : null}
          </div>

          {method === "airtel_ga" ? (
            <div className="space-y-2 rounded-lg border border-border bg-muted/30 p-4">
              <label className="text-sm font-medium" htmlFor="airtel-msisdn">
                Numéro Airtel Money (sans indicatif)
              </label>
              <input
                id="airtel-msisdn"
                type="tel"
                inputMode="numeric"
                placeholder="074123456"
                value={airtelMsisdn}
                onChange={(e) => setAirtelMsisdn(e.target.value.replace(/\D/g, ""))}
                className="w-full max-w-xs rounded-md border border-input bg-background px-3 py-2 text-sm"
              />
              <p className="text-xs text-muted-foreground">
                Vous recevrez une demande de validation sur votre téléphone.
              </p>
            </div>
          ) : null}

          {errorMsg ? (
            <div className="flex items-start gap-2 rounded-md border border-destructive/40 bg-destructive/5 p-3 text-sm text-destructive">
              <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
              <span>{errorMsg}</span>
            </div>
          ) : null}

          {airtelInfo ? (
            <div className="rounded-md border border-blue-500/30 bg-blue-500/5 p-3 text-sm text-blue-700 dark:text-blue-400">
              {airtelInfo}
            </div>
          ) : null}

          {airtelResult ? <AirtelStatusCard r={airtelResult} /> : null}

          <Button
            size="lg"
            disabled={payMutation.isPending || airtelMutation.isPending}
            onClick={() => {
              setErrorMsg(null);
              setAirtelInfo(null);
              if (method === "airtel_ga") {
                if (airtelMsisdn.length < 8) {
                  setErrorMsg("Veuillez saisir un numéro Airtel valide.");
                  return;
                }
                airtelMutation.mutate({ planId: selectedPlan, msisdn: airtelMsisdn });
              } else {
                payMutation.mutate({ planId: selectedPlan, method });
              }
            }}
          >
            {payMutation.isPending || airtelMutation.isPending ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                {method === "airtel_ga" ? "Envoi de la demande…" : "Redirection…"}
              </>
            ) : method === "airtel_ga" ? (
              "Demander le paiement Airtel"
            ) : (
              "Procéder au paiement"
            )}
          </Button>
        </section>
      ) : null}

      {/* --- Test Airtel Money (UAT) --- */}
      {isGabon ? (
        <section className="space-y-3 rounded-xl border border-dashed border-gold/40 bg-gold/5 p-6">
          <div>
            <h2 className="text-lg font-semibold">Test Airtel Money (UAT)</h2>
            <p className="text-sm text-muted-foreground">
              Déclenche une demande de paiement réelle vers le sandbox Airtel
              Gabon et affiche immédiatement le statut renvoyé par l'API.
            </p>
          </div>
          <div className="flex flex-wrap items-end gap-3">
            <div className="space-y-1">
              <label htmlFor="test-msisdn" className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                Numéro Airtel (sans indicatif)
              </label>
              <input
                id="test-msisdn"
                type="tel"
                inputMode="numeric"
                placeholder="074123456"
                value={testMsisdn}
                onChange={(e) => setTestMsisdn(e.target.value.replace(/\D/g, ""))}
                className="w-56 rounded-md border border-input bg-background px-3 py-2 text-sm"
              />
            </div>
            <Button
              variant="secondary"
              disabled={testMutation.isPending || testMsisdn.length < 8}
              onClick={() => {
                setTestResult(null);
                setTestTxId(null);
                testMutation.mutate({ msisdn: testMsisdn });
              }}
            >
              {testMutation.isPending ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Test en cours…
                </>
              ) : (
                "Lancer un test"
              )}
            </Button>
            {testTxId ? (
              <Button
                variant="ghost"
                disabled={testMutation.isPending}
                onClick={async () => {
                  try {
                    const r = await checkAirtelFn({ data: { transactionId: testTxId } });
                    setTestResult({
                      status: r.status,
                      airtelStatusCode: r.airtelStatusCode,
                      airtelMoneyId: r.airtelMoneyId,
                      message: r.message,
                    });
                    queryClient.invalidateQueries({ queryKey: ["my-payments"] });
                  } catch (e) {
                    setTestResult({
                      status: "failed",
                      airtelStatusCode: null,
                      airtelMoneyId: null,
                      message: e instanceof Error ? e.message : "Erreur",
                    });
                  }
                }}
              >
                Rafraîchir le statut
              </Button>
            ) : null}
          </div>

          {testTxId ? (
            <div className="rounded-md border border-border bg-background/60 p-3 text-sm">
              <p className="text-muted-foreground">Transaction ID</p>
              <p className="font-mono text-xs">{testTxId}</p>
            </div>
          ) : null}

          {testResult ? (
            <AirtelStatusCard
              r={{
                transactionId: testTxId ?? "",
                status: testResult.status,
                airtelStatusCode: testResult.airtelStatusCode,
                airtelMoneyId: testResult.airtelMoneyId,
                message: testResult.message,
              }}
            />
          ) : null}
        </section>
      ) : null}



      {/* Payments history */}
      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Historique des paiements</h2>
        {payments.length === 0 ? (
          <p className="text-sm text-muted-foreground">Aucun paiement pour le moment.</p>
        ) : (
          <div className="overflow-hidden rounded-xl border border-border">
            <table className="w-full text-sm">
              <thead className="bg-muted/40 text-left text-xs uppercase tracking-wider text-muted-foreground">
                <tr>
                  <th className="px-4 py-2.5">Date</th>
                  <th className="px-4 py-2.5">Plan</th>
                  <th className="px-4 py-2.5">Mode</th>
                  <th className="px-4 py-2.5">Montant</th>
                  <th className="px-4 py-2.5">Statut</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {payments.map((p) => (
                  <tr key={p.id}>
                    <td className="px-4 py-2.5">{formatDate(p.created_at)}</td>
                    <td className="px-4 py-2.5">{p.plan?.name ?? "—"}</td>
                    <td className="px-4 py-2.5">
                      {p.method === "card" ? "Carte" : "Mobile money"}
                    </td>
                    <td className="px-4 py-2.5 font-medium">
                      {formatXAF(p.amount_xaf)}
                    </td>
                    <td className="px-4 py-2.5">
                      <span
                        className={cn(
                          "rounded-full px-2 py-0.5 text-xs font-medium",
                          p.status === "succeeded"
                            ? "bg-emerald-500/15 text-emerald-700 dark:text-emerald-400"
                            : p.status === "pending"
                              ? "bg-amber-500/15 text-amber-700 dark:text-amber-400"
                              : "bg-destructive/15 text-destructive",
                        )}
                      >
                        {p.status === "succeeded"
                          ? "Payé"
                          : p.status === "pending"
                            ? "En attente"
                            : p.status === "failed"
                              ? "Échec"
                              : p.status}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
