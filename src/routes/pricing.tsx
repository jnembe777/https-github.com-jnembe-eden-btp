import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { Check, Building2, User, ArrowRight } from "lucide-react";

import { listPlans } from "@/lib/subscriptions.functions";
import { Button } from "@/components/ui/button";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/pricing")({
  ssr: false,
  head: () => ({
    meta: [
      { title: "Tarifs · EdenFin JASPE" },
      {
        name: "description",
        content:
          "Abonnements Individuel et Société pour la console comptable EdenFin JASPE. Paiement par carte ou mobile money.",
      },
    ],
  }),
  component: PricingPage,
});

const FEATURES_INDIVIDUAL = [
  "Comptabilité OHADA complète",
  "Trésorerie & rapprochement",
  "Déclarations fiscales",
  "Export PDF & Excel",
  "1 utilisateur",
];
const FEATURES_COMPANY = [
  "Tout l'Individuel, plus :",
  "Gestion de la paie",
  "Immobilisations & amortissements",
  "Tableaux d'analyse avancés",
  "Support prioritaire",
];

function formatXAF(n: number) {
  return new Intl.NumberFormat("fr-FR").format(n) + " F CFA";
}

type Interval = "monthly" | "quarterly" | "yearly";
const INTERVAL_LABEL: Record<Interval, string> = {
  monthly: "Mensuel",
  quarterly: "Trimestriel",
  yearly: "Annuel",
};

function PricingPage() {
  const [tab, setTab] = useState<"individual" | "company">("individual");
  const { data, isLoading } = useQuery({
    queryKey: ["plans"],
    queryFn: () => listPlans(),
  });

  const plans = data?.plans ?? [];

  return (
    <div className="min-h-screen bg-background">
      <header className="border-b border-border">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
          <Link to="/" className="flex items-center gap-2">
            <span className="grid h-9 w-9 place-items-center rounded-md bg-gold text-gold-foreground">
              <span className="font-display text-base font-bold">E</span>
            </span>
            <span className="font-display text-lg font-bold">EdenFin</span>
          </Link>
          <Link
            to="/console"
            className="text-sm font-medium text-muted-foreground hover:text-foreground"
          >
            Accéder à la console →
          </Link>
        </div>
      </header>

      <main className="mx-auto max-w-6xl px-6 py-16">
        <div className="mx-auto max-w-2xl text-center">
          <h1 className="font-display text-4xl font-bold tracking-tight text-foreground sm:text-5xl">
            Choisissez votre formule
          </h1>
          <p className="mt-4 text-base text-muted-foreground">
            14 jours d'essai gratuit sur toutes les formules. Paiement par carte
            bancaire ou mobile money (Orange Money, MTN MoMo, Airtel, Moov).
          </p>
        </div>

        <Tabs
          value={tab}
          onValueChange={(v) => setTab(v as typeof tab)}
          className="mt-10"
        >
          <TabsList className="mx-auto grid w-full max-w-md grid-cols-2">
            <TabsTrigger value="individual" className="gap-2">
              <User className="h-4 w-4" /> Individuel
            </TabsTrigger>
            <TabsTrigger value="company" className="gap-2">
              <Building2 className="h-4 w-4" /> Société
            </TabsTrigger>
          </TabsList>

          {(["individual", "company"] as const).map((type) => (
            <TabsContent key={type} value={type} className="mt-10">
              {isLoading ? (
                <p className="text-center text-sm text-muted-foreground">
                  Chargement des tarifs…
                </p>
              ) : (
                <div className="grid gap-6 md:grid-cols-3">
                  {plans
                    .filter((p) => p.account_type === type)
                    .map((p) => {
                      const featured = p.interval === "yearly";
                      const features =
                        type === "individual"
                          ? FEATURES_INDIVIDUAL
                          : FEATURES_COMPANY;
                      return (
                        <div
                          key={p.id}
                          className={cn(
                            "flex flex-col rounded-2xl border bg-card p-6 shadow-sm",
                            featured
                              ? "border-gold ring-2 ring-gold/30"
                              : "border-border",
                          )}
                        >
                          {featured && (
                            <span className="mb-2 inline-flex w-fit rounded-full bg-gold/10 px-2.5 py-0.5 text-xs font-semibold text-gold">
                              Meilleure offre
                            </span>
                          )}
                          <h3 className="text-lg font-semibold">
                            {INTERVAL_LABEL[p.interval as Interval]}
                          </h3>
                          <div className="mt-3 flex items-baseline gap-1">
                            <span className="text-3xl font-bold tracking-tight">
                              {formatXAF(p.amount_xaf)}
                            </span>
                          </div>
                          <p className="mt-1 text-xs text-muted-foreground">
                            {p.interval === "monthly"
                              ? "par mois"
                              : p.interval === "quarterly"
                                ? "par trimestre"
                                : "par an"}
                          </p>
                          <ul className="mt-6 space-y-2 text-sm">
                            {features.map((f) => (
                              <li key={f} className="flex items-start gap-2">
                                <Check className="mt-0.5 h-4 w-4 shrink-0 text-gold" />
                                <span>{f}</span>
                              </li>
                            ))}
                          </ul>
                          <div className="mt-6 pt-2">
                            <Button asChild className="w-full" variant={featured ? "default" : "outline"}>
                              <Link
                                to="/console/abonnement"
                                search={{ plan: p.id }}
                              >
                                Choisir cette formule <ArrowRight className="ml-1 h-4 w-4" />
                              </Link>
                            </Button>
                          </div>
                        </div>
                      );
                    })}
                </div>
              )}
            </TabsContent>
          ))}
        </Tabs>
      </main>
    </div>
  );
}
