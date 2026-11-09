import { createFileRoute } from "@tanstack/react-router";
import { BarChart3, Download, TrendingUp, TrendingDown } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  KpiCard,
  KpiGrid,
  ModuleCard,
  ModuleShell,
} from "@/components/edenfin/module-shell";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/_authenticated/console/analyse")({
  component: AnalysePage,
});

const ratios = [
  { nom: "Marge brute", valeur: "42,8 %", cible: "≥ 40 %", evo: "+1,2 pt", positif: true },
  { nom: "EBE / CA", valeur: "18,4 %", cible: "≥ 15 %", evo: "+0,6 pt", positif: true },
  { nom: "Délai règlement clients", valeur: "47 j", cible: "≤ 45 j", evo: "+3 j", positif: false },
  { nom: "Délai règlement fournisseurs", valeur: "38 j", cible: "≥ 30 j", evo: "−2 j", positif: false },
  { nom: "Rotation des stocks", valeur: "6,2x", cible: "≥ 5x", evo: "+0,4x", positif: true },
  { nom: "Endettement net", valeur: "0,42", cible: "≤ 0,6", evo: "−0,03", positif: true },
];

const ca = [
  { mois: "Oct", v: 78 },
  { mois: "Nov", v: 92 },
  { mois: "Déc", v: 118 },
  { mois: "Jan", v: 88 },
  { mois: "Fév", v: 96 },
  { mois: "Mar", v: 128 },
];

const maxCa = Math.max(...ca.map((d) => d.v));

function AnalysePage() {
  return (
    <ModuleShell
      icon={<BarChart3 className="h-5 w-5" />}
      title="Analyse"
      subtitle="Tableau de bord, ratios financiers et indicateurs de performance."
      tabs={[
        { key: "synthese", label: "Synthèse", active: true },
        { key: "compte-resultat", label: "Compte de résultat" },
        { key: "bilan", label: "Bilan" },
        { key: "ratios", label: "Ratios" },
        { key: "decisionnel", label: "Décisionnel" },
      ]}
      actions={
        <Button variant="outline" size="sm">
          <Download className="h-4 w-4" /> Export PDF
        </Button>
      }
    >
      <div className="space-y-6">
        <KpiGrid>
          <KpiCard label="CA cumulé 2025" value="312 M XAF" delta="+18,4 % YTD" tone="success" />
          <KpiCard label="Résultat net" value="48,6 M" delta="marge nette 15,6 %" tone="success" />
          <KpiCard label="Trésorerie nette" value="62,5 M" delta="+8,4 % vs M-1" tone="success" />
          <KpiCard label="Capacité d'auto-financement" value="56,2 M" delta="CAF / CA : 18 %" />
        </KpiGrid>

        <div className="grid gap-6 lg:grid-cols-5">
          <div className="lg:col-span-3">
            <ModuleCard
              title="Chiffre d'affaires — 6 derniers mois"
              description="en millions XAF"
            >
              <div className="flex h-56 items-end gap-3">
                {ca.map((d) => (
                  <div key={d.mois} className="flex flex-1 flex-col items-center gap-2">
                    <div className="text-xs font-medium tabular-nums text-foreground">{d.v}</div>
                    <div
                      className="w-full rounded-t-md bg-gradient-to-t from-primary to-primary-glow transition-all"
                      style={{ height: `${(d.v / maxCa) * 100}%` }}
                    />
                    <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                      {d.mois}
                    </div>
                  </div>
                ))}
              </div>
            </ModuleCard>
          </div>

          <div className="lg:col-span-2">
            <ModuleCard title="Ratios clés" description="vs objectifs annuels">
              <div className="space-y-3">
                {ratios.map((r) => (
                  <div
                    key={r.nom}
                    className="flex items-center justify-between rounded-lg border border-border bg-background/60 p-3"
                  >
                    <div>
                      <div className="text-sm font-medium text-foreground">{r.nom}</div>
                      <div className="text-[11px] text-muted-foreground">Cible {r.cible}</div>
                    </div>
                    <div className="text-right">
                      <div className="font-display text-base font-bold tabular-nums text-foreground">
                        {r.valeur}
                      </div>
                      <div
                        className={cn(
                          "mt-0.5 inline-flex items-center gap-0.5 text-[11px] font-medium",
                          r.positif ? "text-success" : "text-destructive",
                        )}
                      >
                        {r.positif ? (
                          <TrendingUp className="h-3 w-3" />
                        ) : (
                          <TrendingDown className="h-3 w-3" />
                        )}
                        {r.evo}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </ModuleCard>
          </div>
        </div>
      </div>
    </ModuleShell>
  );
}
