import { createFileRoute } from "@tanstack/react-router";
import { FileText, Send, Download, AlertTriangle } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  KpiCard,
  KpiGrid,
  ModuleCard,
  ModuleShell,
  StatusBadge,
} from "@/components/edenfin/module-shell";

export const Route = createFileRoute("/_authenticated/console/fiscal")({
  component: FiscalPage,
});

const declarations = [
  { code: "TVA-0325", libelle: "TVA mensuelle — Mars 2025", echeance: "15/04/2025", base: "128 400 000", montant: "23 112 000", statut: "Préparée", tone: "info" as const },
  { code: "ITS-0325", libelle: "ITS — Mars 2025", echeance: "15/04/2025", base: "48 200 000", montant: "6 850 000", statut: "Préparée", tone: "info" as const },
  { code: "IS-2024", libelle: "Acompte IS — T1 2025", echeance: "20/04/2025", base: "—", montant: "4 200 000", statut: "À calculer", tone: "warning" as const },
  { code: "TVA-0225", libelle: "TVA mensuelle — Février 2025", echeance: "15/03/2025", base: "112 800 000", montant: "20 304 000", statut: "Télédéclarée", tone: "success" as const },
  { code: "ITS-0225", libelle: "ITS — Février 2025", echeance: "15/03/2025", base: "47 100 000", montant: "6 690 000", statut: "Télédéclarée", tone: "success" as const },
];

function FiscalPage() {
  return (
    <ModuleShell
      icon={<FileText className="h-5 w-5" />}
      title="Fiscal"
      subtitle="Déclarations TVA, ITS et liasse fiscale — calendrier OHADA."
      tabs={[
        { key: "declarations", label: "Déclarations", active: true },
        { key: "tva", label: "TVA" },
        { key: "its", label: "ITS / IRPP" },
        { key: "is", label: "Impôt société" },
        { key: "liasse", label: "Liasse" },
      ]}
      actions={
        <>
          <Button variant="outline" size="sm">
            <Download className="h-4 w-4" /> Export DGI
          </Button>
          <Button variant="prestige" size="sm">
            <Send className="h-4 w-4" /> Télédéclarer
          </Button>
        </>
      }
    >
      <div className="space-y-6">
        <KpiGrid>
          <KpiCard label="TVA collectée mars" value="23,1 M XAF" delta="+2,8 M vs M-1" tone="default" />
          <KpiCard label="TVA déductible" value="8,4 M XAF" delta="reportable : 0" />
          <KpiCard label="Échéances 30j" value="3" delta="prochaine : 15/04" tone="warning" />
          <KpiCard label="Conformité" value="98 %" delta="2 anomalies mineures" tone="success" />
        </KpiGrid>

        <div className="flex items-start gap-3 rounded-xl border border-warning/30 bg-warning/5 p-4 text-sm">
          <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0 text-warning" />
          <div>
            <div className="font-medium text-foreground">Acompte IS T1 à calculer avant le 20 avril</div>
            <p className="mt-0.5 text-xs text-muted-foreground">
              Le résultat fiscal prévisionnel n'a pas encore été arrêté. Lancez la simulation pour préparer la déclaration.
            </p>
          </div>
        </div>

        <ModuleCard
          title="Calendrier déclaratif"
          description="Période fiscale 2025 — Sénégal"
        >
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left text-[11px] uppercase tracking-wider text-muted-foreground">
                  <th className="py-2 pr-3 font-medium">Code</th>
                  <th className="py-2 pr-3 font-medium">Déclaration</th>
                  <th className="py-2 pr-3 font-medium">Échéance</th>
                  <th className="py-2 pr-3 text-right font-medium">Base</th>
                  <th className="py-2 pr-3 text-right font-medium">Montant</th>
                  <th className="py-2 pr-3 font-medium">Statut</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {declarations.map((d) => (
                  <tr key={d.code} className="hover:bg-muted/40">
                    <td className="py-2.5 pr-3 font-mono text-xs text-muted-foreground">{d.code}</td>
                    <td className="py-2.5 pr-3 font-medium text-foreground">{d.libelle}</td>
                    <td className="py-2.5 pr-3 text-muted-foreground">{d.echeance}</td>
                    <td className="py-2.5 pr-3 text-right font-mono tabular-nums">{d.base}</td>
                    <td className="py-2.5 pr-3 text-right font-mono tabular-nums font-semibold">
                      {d.montant}
                    </td>
                    <td className="py-2.5 pr-3">
                      <StatusBadge tone={d.tone}>{d.statut}</StatusBadge>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </ModuleCard>
      </div>
    </ModuleShell>
  );
}
