import { createFileRoute, Link } from "@tanstack/react-router";
import {
  ArrowRight,
  BookOpen,
  Wallet,
  Users,
  FileText,
  Building2,
  BarChart3,
  CheckCircle2,
} from "lucide-react";

import { Button } from "@/components/ui/button";
import { SiteHeader } from "@/components/edenfin/site-header";
import { SiteFooter } from "@/components/edenfin/site-footer";

export const Route = createFileRoute("/jaspe")({
  head: () => ({
    meta: [
      { title: "JASPE — Gamme TPE · EdenFin" },
      {
        name: "description",
        content:
          "JASPE est la gamme EdenFin pour TPE : comptabilité, paie, trésorerie, fiscalité, immobilisations et analyse — conforme SYSCOHADA.",
      },
      { property: "og:title", content: "JASPE — Gamme TPE · EdenFin" },
      {
        property: "og:description",
        content:
          "Six modules métier prêts à l'emploi pour piloter une TPE OHADA de bout en bout.",
      },
    ],
  }),
  component: JaspePage,
});

const modules = [
  {
    icon: BookOpen,
    name: "Comptabilité",
    body: "Saisie d'écritures, lettrage automatique, balance générale, clôture de période.",
    items: ["13 fonctions RPC", "Plan SYSCOHADA", "Audit trail complet"],
  },
  {
    icon: Wallet,
    name: "Trésorerie",
    body: "Rapprochement bancaire automatique et prévisionnel de cash sur 12 mois.",
    items: ["Auto-matching", "Forecast glissant", "Multi-banques"],
  },
  {
    icon: Users,
    name: "Paie",
    body: "Calcul des bulletins OHADA avec taux CNSS, retraite et IRPP paramétrables.",
    items: ["Bulletins automatisés", "OD de paie", "Simulateur"],
  },
  {
    icon: FileText,
    name: "Fiscal",
    body: "Déclaration TVA mensuelle/trimestrielle, contrôles de cohérence intégrés.",
    items: ["TVA collectée/déductible", "Liasse simplifiée", "Alertes écart"],
  },
  {
    icon: Building2,
    name: "Immobilisations",
    body: "Amortissements linéaires et dégressifs, cessions avec calcul VNC automatique.",
    items: ["Dotations mensuelles", "Cessions tracées", "Catégories OHADA"],
  },
  {
    icon: BarChart3,
    name: "Analyse",
    body: "Ratios financiers, dashboard KPI et score de santé en temps réel.",
    items: ["BFR · DSO · DPO", "Score santé /100", "Tendances"],
  },
] as const;

function JaspePage() {
  return (
    <div className="flex min-h-screen flex-col">
      <SiteHeader />

      <main className="flex-1">
        <section className="relative overflow-hidden border-b border-border/60 bg-prestige-radial text-primary-foreground">
          <div className="container relative mx-auto grid gap-12 px-6 py-20 md:grid-cols-[1.2fr_0.8fr] md:py-28">
            <div>
              <span className="inline-flex items-center gap-2 rounded-full border border-gold/40 bg-gold/10 px-3.5 py-1.5 text-xs font-medium uppercase tracking-[0.18em] text-gold-soft">
                Gamme TPE · disponible
              </span>
              <h1 className="mt-6 font-display text-5xl font-bold leading-[1.05] tracking-tight text-balance md:text-6xl">
                <span className="text-gold">JASPE</span> — l'essentiel financier d'une TPE
                conforme OHADA
              </h1>
              <p className="mt-6 max-w-xl text-lg text-primary-foreground/75">
                Six modules métier prêts à l'emploi : comptabilité, paie, trésorerie, fiscalité,
                immobilisations et analyse. Pensé pour les TPE de moins de 10 salariés.
              </p>

              <div className="mt-8 flex flex-wrap gap-3">
                <Button asChild size="xl" variant="gold">
                  <Link to="/console">
                    Accéder à la console
                    <ArrowRight className="h-5 w-5" />
                  </Link>
                </Button>
                <Button
                  asChild
                  size="xl"
                  variant="ghost"
                  className="text-primary-foreground hover:bg-primary-foreground/10 hover:text-primary-foreground"
                >
                  <a href="#modules">Voir les modules</a>
                </Button>
              </div>
            </div>

            <aside className="rounded-2xl border border-gold/25 bg-primary/30 p-6 shadow-prestige backdrop-blur">
              <p className="font-display text-sm uppercase tracking-[0.2em] text-gold-soft">
                En chiffres
              </p>
              <dl className="mt-5 grid grid-cols-2 gap-5">
                {[
                  ["13", "fonctions RPC"],
                  ["8", "services métier"],
                  ["20", "traitements MCT"],
                  ["100%", "OHADA"],
                ].map(([n, l]) => (
                  <div key={l}>
                    <dt className="font-display text-4xl font-bold text-gold">{n}</dt>
                    <dd className="mt-1 text-xs uppercase tracking-wider text-primary-foreground/60">
                      {l}
                    </dd>
                  </div>
                ))}
              </dl>
            </aside>
          </div>
        </section>

        <section id="modules" className="bg-background py-24 scroll-mt-20">
          <div className="container mx-auto px-6">
            <div className="mx-auto max-w-2xl text-center">
              <span className="text-xs uppercase tracking-[0.2em] text-foreground/55">
                Six modules
              </span>
              <h2 className="mt-3 font-display text-4xl font-bold tracking-tight md:text-5xl">
                Tout le périmètre <span className="text-primary">d'une TPE</span>
              </h2>
              <p className="mt-4 text-balance text-muted-foreground">
                Chaque module est servi par des fonctions PostgreSQL sécurisées, avec RLS et audit
                trail.
              </p>
            </div>

            <div className="mt-14 grid gap-5 md:grid-cols-2 lg:grid-cols-3">
              {modules.map(({ icon: Icon, name, body, items }) => (
                <article
                  key={name}
                  className="group flex flex-col rounded-2xl border border-border bg-card p-6 transition-all hover:-translate-y-1 hover:border-primary/30 hover:shadow-prestige"
                >
                  <span className="grid h-11 w-11 place-items-center rounded-lg bg-primary/10 text-primary transition-colors group-hover:bg-primary group-hover:text-primary-foreground">
                    <Icon className="h-5 w-5" />
                  </span>
                  <h3 className="mt-5 font-display text-xl font-bold tracking-tight">{name}</h3>
                  <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{body}</p>
                  <ul className="mt-4 space-y-1.5">
                    {items.map((i) => (
                      <li
                        key={i}
                        className="flex items-center gap-2 text-xs text-muted-foreground"
                      >
                        <CheckCircle2 className="h-3.5 w-3.5 text-success" />
                        {i}
                      </li>
                    ))}
                  </ul>
                </article>
              ))}
            </div>
          </div>
        </section>

        <section className="border-t border-border/60 bg-card/50 py-20">
          <div className="container mx-auto px-6 text-center">
            <h2 className="font-display text-3xl font-bold tracking-tight md:text-4xl">
              Prêt à piloter votre TPE avec JASPE ?
            </h2>
            <p className="mx-auto mt-3 max-w-xl text-muted-foreground">
              Accédez à la console et explorez les six modules métier.
            </p>
            <div className="mt-7">
              <Button asChild size="xl" variant="prestige">
                <Link to="/console">
                  Ouvrir la console
                  <ArrowRight className="h-5 w-5" />
                </Link>
              </Button>
            </div>
          </div>
        </section>
      </main>

      <SiteFooter />
    </div>
  );
}
