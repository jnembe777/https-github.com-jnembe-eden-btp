import { createFileRoute } from "@tanstack/react-router";
import { Building2, Plus, Receipt } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  KpiCard,
  KpiGrid,
  ModuleCard,
  ModuleShell,
  StatusBadge,
} from "@/components/edenfin/module-shell";

export const Route = createFileRoute("/_authenticated/console/immobilisations")({
  component: ImmobilisationsPage,
});

const assets = [
  { code: "IMM-0014", libelle: "Véhicule Toyota Hilux", categorie: "Matériel transport", acquisition: "15/01/2023", valeur: "18 500 000", amortis: "7 400 000", vnc: "11 100 000", taux: "20 %", statut: "En service", tone: "success" as const },
  { code: "IMM-0021", libelle: "Serveur Dell PowerEdge R750", categorie: "Matériel informatique", acquisition: "04/06/2024", valeur: "8 250 000", amortis: "1 375 000", vnc: "6 875 000", taux: "33 %", statut: "En service", tone: "success" as const },
  { code: "IMM-0027", libelle: "Mobilier bureau open-space", categorie: "Mobilier", acquisition: "12/09/2022", valeur: "4 800 000", amortis: "2 880 000", vnc: "1 920 000", taux: "20 %", statut: "En service", tone: "success" as const },
  { code: "IMM-0033", libelle: "Photocopieur Canon iR-ADV", categorie: "Matériel bureau", acquisition: "20/03/2021", valeur: "3 200 000", amortis: "3 200 000", vnc: "0", taux: "25 %", statut: "Totalement amorti", tone: "warning" as const },
  { code: "IMM-0041", libelle: "Bâtiment annexe Dakar", categorie: "Construction", acquisition: "01/01/2020", valeur: "85 000 000", amortis: "21 250 000", vnc: "63 750 000", taux: "5 %", statut: "En service", tone: "success" as const },
];

function ImmobilisationsPage() {
  return (
    <ModuleShell
      icon={<Building2 className="h-5 w-5" />}
      title="Immobilisations"
      subtitle="Fichier des immobilisations, dotations aux amortissements et cessions."
      tabs={[
        { key: "fichier", label: "Fichier", active: true },
        { key: "amortissements", label: "Amortissements" },
        { key: "cessions", label: "Cessions" },
        { key: "inventaire", label: "Inventaire" },
      ]}
      actions={
        <>
          <Button variant="outline" size="sm">
            <Receipt className="h-4 w-4" /> Dotation période
          </Button>
          <Button variant="prestige" size="sm">
            <Plus className="h-4 w-4" /> Nouvelle immo
          </Button>
        </>
      }
    >
      <div className="space-y-6">
        <KpiGrid>
          <KpiCard label="Valeur d'origine" value="119,7 M XAF" delta="42 immobilisations" />
          <KpiCard label="Amortissements cumulés" value="36,1 M XAF" delta="taux moyen 30 %" />
          <KpiCard label="VNC totale" value="83,6 M XAF" delta="+2 acquisitions 2025" tone="success" />
          <KpiCard label="Dotation mars" value="1,84 M XAF" delta="à comptabiliser" tone="warning" />
        </KpiGrid>

        <ModuleCard
          title="Fichier des immobilisations"
          description="42 actifs · groupés par catégorie"
        >
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left text-[11px] uppercase tracking-wider text-muted-foreground">
                  <th className="py-2 pr-3 font-medium">Code</th>
                  <th className="py-2 pr-3 font-medium">Libellé</th>
                  <th className="py-2 pr-3 font-medium">Catégorie</th>
                  <th className="py-2 pr-3 font-medium">Acquisition</th>
                  <th className="py-2 pr-3 text-right font-medium">Valeur</th>
                  <th className="py-2 pr-3 text-right font-medium">Amortis</th>
                  <th className="py-2 pr-3 text-right font-medium">VNC</th>
                  <th className="py-2 pr-3 text-right font-medium">Taux</th>
                  <th className="py-2 pr-3 font-medium">Statut</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {assets.map((a) => (
                  <tr key={a.code} className="hover:bg-muted/40">
                    <td className="py-2.5 pr-3 font-mono text-xs text-muted-foreground">{a.code}</td>
                    <td className="py-2.5 pr-3 font-medium text-foreground">{a.libelle}</td>
                    <td className="py-2.5 pr-3 text-muted-foreground">{a.categorie}</td>
                    <td className="py-2.5 pr-3 text-muted-foreground">{a.acquisition}</td>
                    <td className="py-2.5 pr-3 text-right font-mono tabular-nums">{a.valeur}</td>
                    <td className="py-2.5 pr-3 text-right font-mono tabular-nums text-muted-foreground">
                      {a.amortis}
                    </td>
                    <td className="py-2.5 pr-3 text-right font-mono tabular-nums font-semibold">
                      {a.vnc}
                    </td>
                    <td className="py-2.5 pr-3 text-right text-xs text-muted-foreground">{a.taux}</td>
                    <td className="py-2.5 pr-3">
                      <StatusBadge tone={a.tone}>{a.statut}</StatusBadge>
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
