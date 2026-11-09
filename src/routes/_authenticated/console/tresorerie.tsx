import { createFileRoute } from "@tanstack/react-router";
import { Wallet, RefreshCw, ArrowDownToLine, TrendingUp } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  KpiCard,
  KpiGrid,
  ModuleCard,
  ModuleShell,
  StatusBadge,
} from "@/components/edenfin/module-shell";

export const Route = createFileRoute("/_authenticated/console/tresorerie")({
  component: TresoreriePage,
});

const comptes = [
  { code: "521000", nom: "Banque CBAO — courant XAF", solde: "42 318 500", devise: "XAF", dernier: "12/03/2025", tone: "success" as const, statut: "Rapproché" },
  { code: "521100", nom: "Banque Ecobank — pro XAF", solde: "18 942 200", devise: "XAF", dernier: "11/03/2025", tone: "warning" as const, statut: "3 écarts" },
  { code: "522000", nom: "Banque UBA — USD", solde: "27 480 USD", devise: "USD", dernier: "08/03/2025", tone: "warning" as const, statut: "Partiel" },
  { code: "571000", nom: "Caisse siège", solde: "1 240 000", devise: "XAF", dernier: "12/03/2025", tone: "success" as const, statut: "OK" },
];

const previsionnel = [
  { semaine: "S11 · 10-16 mars", encaissements: "8 420 000", decaissements: "5 120 000", solde: "+3 300 000", tone: "success" as const },
  { semaine: "S12 · 17-23 mars", encaissements: "6 180 000", decaissements: "9 850 000", solde: "−3 670 000", tone: "danger" as const },
  { semaine: "S13 · 24-30 mars", encaissements: "11 200 000", decaissements: "7 410 000", solde: "+3 790 000", tone: "success" as const },
  { semaine: "S14 · 31 mars-6 avril", encaissements: "4 900 000", decaissements: "6 220 000", solde: "−1 320 000", tone: "warning" as const },
];

function TresoreriePage() {
  return (
    <ModuleShell
      icon={<Wallet className="h-5 w-5" />}
      title="Trésorerie"
      subtitle="Position consolidée, rapprochement bancaire et prévisionnel à 13 semaines."
      tabs={[
        { key: "position", label: "Position", active: true },
        { key: "rapprochement", label: "Rapprochement" },
        { key: "previsionnel", label: "Prévisionnel" },
        { key: "mouvements", label: "Mouvements" },
      ]}
      actions={
        <>
          <Button variant="outline" size="sm">
            <ArrowDownToLine className="h-4 w-4" /> Importer relevé
          </Button>
          <Button variant="prestige" size="sm">
            <RefreshCw className="h-4 w-4" /> Rapprocher
          </Button>
        </>
      }
    >
      <div className="space-y-6">
        <KpiGrid>
          <KpiCard label="Trésorerie nette" value="62,5 M XAF" delta="+8,4 % vs M-1" tone="success" />
          <KpiCard label="Encaissements 30j" value="42,1 M" delta="+12 ops" tone="success" />
          <KpiCard label="Décaissements 30j" value="28,6 M" delta="−4 ops" tone="default" />
          <KpiCard label="Écarts à traiter" value="11" delta="3 banques concernées" tone="warning" />
        </KpiGrid>

        <div className="grid gap-6 lg:grid-cols-5">
          <div className="lg:col-span-3">
            <ModuleCard
              title="Comptes bancaires"
              description="Soldes à date · 12/03/2025"
              action={
                <Button variant="ghost" size="sm">
                  Tout voir
                </Button>
              }
            >
              <div className="divide-y divide-border">
                {comptes.map((c) => (
                  <div key={c.code} className="flex items-center justify-between py-3 first:pt-0 last:pb-0">
                    <div className="min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="font-mono text-[11px] text-muted-foreground">{c.code}</span>
                        <span className="text-sm font-medium text-foreground">{c.nom}</span>
                      </div>
                      <div className="mt-0.5 text-xs text-muted-foreground">
                        Dernier rapprochement : {c.dernier}
                      </div>
                    </div>
                    <div className="flex items-center gap-4">
                      <div className="text-right">
                        <div className="font-display text-base font-bold tabular-nums text-foreground">
                          {c.solde}
                        </div>
                        <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                          {c.devise}
                        </div>
                      </div>
                      <StatusBadge tone={c.tone}>{c.statut}</StatusBadge>
                    </div>
                  </div>
                ))}
              </div>
            </ModuleCard>
          </div>

          <div className="lg:col-span-2">
            <ModuleCard
              title="Prévisionnel 4 semaines"
              description="Glissant à partir du 10/03"
              action={<TrendingUp className="h-4 w-4 text-primary" />}
            >
              <div className="space-y-3">
                {previsionnel.map((p) => (
                  <div key={p.semaine} className="rounded-lg border border-border bg-background/60 p-3">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-medium text-foreground">{p.semaine}</span>
                      <StatusBadge tone={p.tone}>{p.solde}</StatusBadge>
                    </div>
                    <div className="mt-2 flex justify-between text-[11px] text-muted-foreground">
                      <span>↑ {p.encaissements}</span>
                      <span>↓ {p.decaissements}</span>
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
