import { createFileRoute } from "@tanstack/react-router";
import { Network } from "lucide-react";

import {
  ModuleShell,
  KpiGrid,
  KpiCard,
  ModuleCard,
  StatusBadge,
} from "@/components/edenfin/module-shell";
import { useGammeGate } from "@/components/edenfin/gamme-gate";
import { SmartGrid, GridColumn } from "@/components/edenfin/smart-grid";
import { MOCK_CONSOLIDATION, type ConsolidationLine } from "@/lib/mock-gammes";
import { useGammeData } from "@/hooks/use-gamme-data";

export const Route = createFileRoute(
  "/_authenticated/console/saphir-consolidation",
)({
  component: SaphirConsolidationPage,
});

const fmtM = (n: number) =>
  new Intl.NumberFormat("fr-FR", { maximumFractionDigits: 1 }).format(n / 1_000_000) + " M";

function SaphirConsolidationPage() {
  const { data: lines, isDemo } = useGammeData<ConsolidationLine>("consolidation_group_members", MOCK_CONSOLIDATION, { schema: "SYSTEM" });
  const totalResult = lines.reduce(
    (s, l) => s + (l.contribution_result * l.ownership_percentage) / 100,
    0,
  );
  const fully = lines.filter((l) => l.method === "FULL").length;

  const columns: GridColumn<ConsolidationLine>[] = [
    { key: "entity_name", label: "Entité", type: "text", width: "auto" },
    {
      key: "method",
      label: "Méthode",
      type: "badge",
      width: "170px",
      badgeMap: {
        FULL: { label: "Intégration globale", variant: "default" },
        PROPORTIONAL: { label: "Intégration prop.", variant: "secondary" },
        EQUITY: { label: "Mise en équivalence", variant: "outline" },
      },
    },
    {
      key: "ownership_percentage",
      label: "% intérêt",
      type: "number",
      width: "100px",
      align: "right",
      render: (v) => <span>{v} %</span>,
    },
    {
      key: "contribution_result",
      label: "Résultat (100 %)",
      type: "number",
      width: "160px",
      align: "right",
      render: (v) => <span className="text-muted-foreground">{fmtM(v)}</span>,
    },
    {
      key: "id",
      label: "Quote-part groupe",
      type: "custom",
      width: "160px",
      align: "right",
      render: (_v, row) => (
        <span className="font-medium">
          {fmtM((row.contribution_result * row.ownership_percentage) / 100)}
        </span>
      ),
    },
    {
      key: "currency_code",
      label: "Devise",
      type: "text",
      width: "80px",
      align: "center",
      render: (v) => <span className="font-mono text-xs">{v}</span>,
    },
  ];

  const locked = useGammeGate("SAPHIR");
  if (locked) return locked;

  return (
    <ModuleShell
      icon={<Network className="h-5 w-5" />}
      title="Consolidation"
      subtitle="Gamme SAPHIR · Périmètre, méthodes de consolidation et quote-part de résultat (OHADA + IFRS)."
      actions={isDemo ? (
        <StatusBadge tone="warning">Mode démonstration</StatusBadge>
      ) : (
        <StatusBadge tone="success">Données Supabase</StatusBadge>
      )}
      tabs={[
        { key: "perimetre", label: "Périmètre & résultat", active: true },
        { key: "eliminations", label: "Éliminations" },
        { key: "etats", label: "États consolidés" },
      ]}
    >
      <div className="space-y-6">
        <KpiGrid>
          <KpiCard label="Entités consolidées" value={String(lines.length)} hint={`${fully} en intégration globale`} />
          <KpiCard label="Résultat part du groupe" value={fmtM(totalResult) + " XAF"} tone="success" delta="exercice 2026" />
          <KpiCard label="Devises" value={String(new Set(lines.map((l) => l.currency_code)).size)} hint="conversion automatique" />
          <KpiCard label="Référentiels" value="OHADA + IFRS" hint="double reporting" />
        </KpiGrid>

        <ModuleCard
          title="Périmètre de consolidation"
          description="rpc_calculate_nci / rpc_generate_eliminations / rpc_run_consolidation."
        >
          <div className="mb-3">
            <StatusBadge tone="info">Source : sys.consolidation_* </StatusBadge>
          </div>
          <SmartGrid
            columns={columns}
            data={lines}
            title="Entités"
            description={`${lines.length} entités dans le périmètre`}
            showSearch
            showExport
            showPagination={false}
            showCreate={false}
            emptyMessage="Aucune entité consolidée"
          />
        </ModuleCard>
      </div>
    </ModuleShell>
  );
}
