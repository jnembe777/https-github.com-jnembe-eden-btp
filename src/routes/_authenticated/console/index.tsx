import { createFileRoute } from "@tanstack/react-router";
import {
  ArrowRight,
  BookOpen,
  Wallet,
  Users,
  FileText,
  Building2,
  BarChart3,
} from "lucide-react";

export const Route = createFileRoute("/_authenticated/console/")({
  component: ConsoleHome,
});

const modules = [
  { icon: BookOpen, name: "Comptabilité", desc: "Écritures, lettrage, balance, clôture", to: "/console/comptabilite" },
  { icon: Wallet, name: "Trésorerie", desc: "Rapprochement et prévisionnel", to: "/console/tresorerie" },
  { icon: Users, name: "Paie", desc: "Bulletins OHADA et OD de paie", to: "/console/paie" },
  { icon: FileText, name: "Fiscal", desc: "Déclaration TVA et liasse", to: "/console/fiscal" },
  { icon: Building2, name: "Immobilisations", desc: "Amortissements et cessions", to: "/console/immobilisations" },
  { icon: BarChart3, name: "Analyse", desc: "Ratios et tableau de bord", to: "/console/analyse" },
] as const;

function ConsoleHome() {
  return (
    <div className="container mx-auto max-w-6xl px-6 py-10">
      <section className="overflow-hidden rounded-2xl border border-primary/20 bg-prestige-radial p-8 text-primary-foreground shadow-prestige md:p-10">
        <span className="text-xs uppercase tracking-[0.2em] text-gold-soft">
          Console JASPE · démo
        </span>
        <h1 className="mt-3 font-display text-3xl font-bold tracking-tight md:text-4xl">
          Bienvenue dans votre suite financière
        </h1>
        <p className="mt-3 max-w-xl text-primary-foreground/75">
          Les six modules JASPE sont prêts. Le backend de démonstration et les données métier
          arrivent au prochain lot.
        </p>
      </section>

      <section className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {[
          { label: "Chiffre d'affaires", value: "—", hint: "FCFA · YTD" },
          { label: "Trésorerie nette", value: "—", hint: "FCFA" },
          { label: "Score de santé", value: "—", hint: "sur 100" },
          { label: "BFR", value: "—", hint: "jours de CA" },
        ].map((k) => (
          <div key={k.label} className="rounded-xl border border-border bg-card p-5">
            <p className="text-xs uppercase tracking-wider text-muted-foreground">{k.label}</p>
            <p className="mt-2 font-display text-3xl font-bold tracking-tight">{k.value}</p>
            <p className="mt-1 text-xs text-muted-foreground/80">{k.hint}</p>
          </div>
        ))}
      </section>

      <section className="mt-10">
        <h2 className="font-display text-xl font-bold tracking-tight">Modules</h2>
        <p className="text-sm text-muted-foreground">
          Accédez à chaque domaine fonctionnel de la gamme JASPE.
        </p>

        <div className="mt-5 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {modules.map(({ icon: Icon, name, desc, to }) => (
            <a
              key={to}
              href={to}
              className="group flex items-start gap-4 rounded-xl border border-border bg-card p-5 transition-all hover:-translate-y-0.5 hover:border-primary/30 hover:shadow-prestige"
            >
              <span className="grid h-10 w-10 shrink-0 place-items-center rounded-lg bg-primary/10 text-primary transition-colors group-hover:bg-primary group-hover:text-primary-foreground">
                <Icon className="h-5 w-5" />
              </span>
              <div className="flex-1">
                <p className="font-display text-base font-bold tracking-tight">{name}</p>
                <p className="mt-0.5 text-sm text-muted-foreground">{desc}</p>
              </div>
              <ArrowRight className="mt-1 h-4 w-4 text-muted-foreground transition-all group-hover:translate-x-0.5 group-hover:text-primary" />
            </a>
          ))}
        </div>
      </section>
    </div>
  );
}
