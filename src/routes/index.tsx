import { createFileRoute, Link } from "@tanstack/react-router";
import { ArrowRight, ShieldCheck, Layers, Sparkles } from "lucide-react";

import { Button } from "@/components/ui/button";
import { SiteHeader } from "@/components/edenfin/site-header";
import { SiteFooter } from "@/components/edenfin/site-footer";
import { GammeCard, type GammeCardProps } from "@/components/edenfin/gamme-card";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "EdenFin — La suite financière des entreprises OHADA" },
      {
        name: "description",
        content:
          "EdenFin réunit comptabilité, paie, trésorerie et fiscalité dans une suite gradée — JASPE, RUBIS, SAPHIR, ONYX — conforme SYSCOHADA.",
      },
      { property: "og:title", content: "EdenFin — Suite financière OHADA" },
      {
        property: "og:description",
        content:
          "Quatre gammes pour accompagner la croissance des entreprises africaines, de la TPE au grand groupe.",
      },
    ],
  }),
  component: Index,
});

function Index() {
  return (
    <div className="flex min-h-screen flex-col">
      <SiteHeader />
      <main className="flex-1">
        <Hero />
        <Highlights />
        <Gammes />
      </main>
      <SiteFooter />
    </div>
  );
}

function Hero() {
  return (
    <section className="relative overflow-hidden bg-prestige-radial text-primary-foreground">
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 opacity-[0.07]"
        style={{
          backgroundImage:
            "linear-gradient(var(--gold) 1px, transparent 1px), linear-gradient(90deg, var(--gold) 1px, transparent 1px)",
          backgroundSize: "48px 48px",
        }}
      />
      <div className="container relative mx-auto px-6 py-24 md:py-32">
        <div className="mx-auto max-w-3xl text-center">
          <span className="inline-flex items-center gap-2 rounded-full border border-gold/40 bg-gold/10 px-3.5 py-1.5 text-xs font-medium uppercase tracking-[0.18em] text-gold-soft">
            <Sparkles className="h-3 w-3" />
            Conforme SYSCOHADA révisé
          </span>

          <h1 className="mt-6 font-display text-5xl font-bold leading-[1.05] tracking-tight text-balance md:text-7xl">
            La suite financière <span className="text-gold">taillée pour l'Afrique</span>
          </h1>

          <p className="mx-auto mt-7 max-w-2xl text-balance text-lg text-primary-foreground/75 md:text-xl">
            EdenFin réunit comptabilité, paie, trésorerie, fiscalité et pilotage dans quatre gammes
            progressives — de la TPE au grand groupe. Conçue pour la zone OHADA, de bout en bout.
          </p>

          <div className="mt-10 flex flex-col items-center justify-center gap-3 sm:flex-row">
            <Button asChild size="xl" variant="gold">
              <Link to="/jaspe">
                Démarrer avec JASPE
                <ArrowRight className="h-5 w-5" />
              </Link>
            </Button>
            <Button
              asChild
              size="xl"
              variant="ghost"
              className="text-primary-foreground hover:bg-primary-foreground/10 hover:text-primary-foreground"
            >
              <a href="#gammes">Voir toutes les gammes</a>
            </Button>
          </div>

          <p className="mt-8 text-xs uppercase tracking-[0.18em] text-primary-foreground/55">
            JASPE · RUBIS · SAPHIR · ONYX
          </p>
        </div>
      </div>
    </section>
  );
}

const highlights = [
  {
    icon: ShieldCheck,
    title: "Conformité native",
    body: "Plan comptable SYSCOHADA révisé, RLS multi-tenant, audit trail complet sur chaque écriture.",
  },
  {
    icon: Layers,
    title: "Architecture en gammes",
    body: "Quatre gammes (JASPE → ONYX) qui suivent la croissance, sans changer d'outil ni de données.",
  },
  {
    icon: Sparkles,
    title: "Pilotage en temps réel",
    body: "Ratios, prévisionnel de trésorerie et score de santé calculés directement sur la base.",
  },
] as const;

function Highlights() {
  return (
    <section className="border-b border-border/60 bg-background py-20">
      <div className="container mx-auto grid gap-8 px-6 md:grid-cols-3">
        {highlights.map(({ icon: Icon, title, body }) => (
          <div key={title} className="flex flex-col">
            <span className="mb-4 grid h-11 w-11 place-items-center rounded-lg bg-primary/10 text-primary">
              <Icon className="h-5 w-5" />
            </span>
            <h3 className="font-display text-xl font-bold tracking-tight">{title}</h3>
            <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{body}</p>
          </div>
        ))}
      </div>
    </section>
  );
}

const gammes: GammeCardProps[] = [
  {
    code: "JASPE",
    cible: "TPE · < 10 salariés",
    tagline:
      "L'essentiel comptable et financier pour une jeune structure : écritures, paie, TVA, trésorerie.",
    highlights: [
      "Comptabilité SYSCOHADA + balance et clôture",
      "Paie OHADA avec calcul automatique CNSS / IRPP",
      "Rapprochement bancaire et prévisionnel de trésorerie",
      "Tableau de bord KPI et score de santé",
    ],
    status: "live",
    to: "/jaspe",
    accent: "emerald",
  },
  {
    code: "RUBIS",
    cible: "PME · 10 à 50 salariés",
    tagline:
      "JASPE étendue : workflow de validation multi-niveaux, DSN, gestion des absences, BFR avancé.",
    highlights: [
      "Workflow de validation à plusieurs niveaux",
      "DSN et gestion fine des absences",
      "Optimisation du BFR et reporting consolidé",
    ],
    status: "soon",
    accent: "ruby",
  },
  {
    code: "SAPHIR",
    cible: "ETI · 50 à 250 salariés",
    tagline:
      "Consolidation multi-entités, liasse fiscale complète, comptabilité analytique sectorielle.",
    highlights: [
      "Consolidation multi-entités et multi-devises",
      "Liasse fiscale OHADA complète",
      "Comptabilité analytique avancée",
    ],
    status: "soon",
    accent: "sapphire",
  },
  {
    code: "ONYX",
    cible: "Grand groupe · 250+",
    tagline:
      "Cube OLAP, BI intégrée, conformité IFRS et orchestration de filiales à l'échelle internationale.",
    highlights: [
      "Cube OLAP et reporting BI",
      "Conformité IFRS et normes internationales",
      "Orchestration multi-filiales internationale",
    ],
    status: "soon",
    accent: "onyx",
  },
];

function Gammes() {
  return (
    <section id="gammes" className="bg-background py-24 scroll-mt-20">
      <div className="container mx-auto px-6">
        <div className="mx-auto max-w-2xl text-center">
          <span className="text-xs uppercase tracking-[0.2em] text-foreground/55">
            Quatre gammes
          </span>
          <h2 className="mt-3 font-display text-4xl font-bold tracking-tight md:text-5xl">
            Une suite, <span className="text-primary">quatre niveaux</span> de maturité
          </h2>
          <p className="mt-4 text-balance text-muted-foreground">
            Commencez avec JASPE quand vous démarrez, montez en gamme sans migration ni rupture de
            données quand votre organisation grandit.
          </p>
        </div>

        <div className="mt-14 grid gap-6 md:grid-cols-2 xl:grid-cols-4">
          {gammes.map((g) => (
            <GammeCard key={g.code} {...g} />
          ))}
        </div>
      </div>
    </section>
  );
}
