import { createFileRoute } from "@tanstack/react-router";
import { Layers } from "lucide-react";

import {
  ModuleShell,
  KpiGrid,
  KpiCard,
  ModuleCard,
  StatusBadge,
} from "@/components/edenfin/module-shell";
import { useGammeGate } from "@/components/edenfin/gamme-gate";
import { SmartGrid, GridColumn } from "@/components/edenfin/smart-grid";
import {
  MOCK_ANALYTICAL_AXES,
  MOCK_DISTRIBUTION_TEMPLATES,
  type AnalyticalAxis,
  type DistributionTemplate,
} from "@/lib/mock-gammes";
import { useGammeData } from "@/hooks/use-gamme-data";

export const Route = createFileRoute(
  "/_authenticated/console/rubis-analytique",
)({
  component: RubisAnalytiquePage,
});

function RubisAnalytiquePage() {
  const { data: axes, isDemo } = useGammeData<AnalyticalAxis>("analytical_axes", MOCK_ANALYTICAL_AXES, { schema: "SYSTEM" });
  const { data: templates } = useGammeData<DistributionTemplate>("analytical_distribution_templates", MOCK_DISTRIBUTION_TEMPLATES, { schema: "SYSTEM" });

  const validTemplates = templates.filter((t) => t.is_valid).length;
  const activeAxes = axes.filter((a) => a.is_active).length;
  const totalValues = axes.reduce((s, a) => s + a.values_count, 0);

  const axisColumns: GridColumn<AnalyticalAxis>[] = [
    {
      key: "axis_code",
      label: "Code",
      type: "text",
      width: "100px",
      render: (v) => <span className="font-mono text-sm font-medium">{v}</span>,
    },
    { key: "axis_name", label: "Axe analytique", type: "text", width: "auto" },
    {
      key: "axis_type",
      label: "Type",
      type: "badge",
      width: "170px",
      badgeMap: {
        COST_CENTER: { label: "Centre de coût", variant: "secondary" },
        PROJECT: { label: "Projet", variant: "secondary" },
        DEPARTMENT: { label: "Département", variant: "secondary" },
        PRODUCT: { label: "Produit", variant: "secondary" },
        GEOGRAPHY: { label: "Géographie", variant: "secondary" },
      },
    },
    {
      key: "values_count",
      label: "Valeurs",
      type: "number",
      width: "90px",
      align: "center",
    },
    {
      key: "is_active",
      label: "Actif",
      type: "boolean",
      width: "80px",
      align: "center",
      render: (v) => (
        <span
          className={`inline-block h-2 w-2 rounded-full ${v ? "bg-green-500" : "bg-gray-300"}`}
        />
      ),
    },
  ];

  const templateColumns: GridColumn<DistributionTemplate>[] = [
    {
      key: "template_code",
      label: "Code",
      type: "text",
      width: "150px",
      render: (v) => <span className="font-mono text-sm font-medium">{v}</span>,
    },
    { key: "template_name", label: "Modèle de ventilation", type: "text", width: "auto" },
    {
      key: "axis_code",
      label: "Axe",
      type: "text",
      width: "90px",
      align: "center",
      render: (v) => <span className="font-mono text-xs">{v}</span>,
    },
    {
      key: "lines_count",
      label: "Lignes",
      type: "number",
      width: "90px",
      align: "center",
    },
    {
      key: "total_percentage",
      label: "Total",
      type: "number",
      width: "110px",
      align: "right",
      render: (v) => (
        <span className={v === 100 ? "font-medium text-success" : "font-medium text-destructive"}>
          {v} %
        </span>
      ),
    },
    {
      key: "is_valid",
      label: "Statut",
      type: "custom",
      width: "130px",
      render: (v) =>
        v ? (
          <StatusBadge tone="success">Valide (100 %)</StatusBadge>
        ) : (
          <StatusBadge tone="warning">Incomplet</StatusBadge>
        ),
    },
  ];

  const locked = useGammeGate("RUBIS");
  if (locked) return locked;

  return (
    <ModuleShell
      icon={<Layers className="h-5 w-5" />}
      title="Comptabilité analytique"
      subtitle="Gamme RUBIS · Axes d'analyse, centres de coût et modèles de ventilation multi-axes."
      actions={isDemo ? (
        <StatusBadge tone="warning">Mode démonstration</StatusBadge>
      ) : (
        <StatusBadge tone="success">Données Supabase</StatusBadge>
      )}
      tabs={[
        { key: "axes", label: "Axes & valeurs", active: true },
        { key: "templates", label: "Modèles de ventilation" },
        { key: "reporting", label: "Reporting analytique" },
      ]}
    >
      <div className="space-y-6">
        <KpiGrid>
          <KpiCard label="Axes analytiques" value={String(axes.length)} hint={`${activeAxes} actifs`} />
          <KpiCard label="Valeurs analytiques" value={String(totalValues)} hint="centres, projets, produits…" />
          <KpiCard
            label="Modèles de ventilation"
            value={String(templates.length)}
            delta={`${validTemplates} valides`}
            tone="success"
          />
          <KpiCard
            label="À compléter"
            value={String(templates.length - validTemplates)}
            delta="total ≠ 100 %"
            tone="warning"
          />
        </KpiGrid>

        <ModuleCard
          title="Modèles de ventilation analytique"
          description="Chaque modèle doit totaliser 100 % (contrôle rpc_add_template_line / validate_distribution_template)."
        >
          <SmartGrid
            columns={templateColumns}
            data={templates}
            title="Modèles"
            description={`${templates.length} modèles · ${validTemplates} valides`}
            showSearch
            showCreate
            showExport
            showPagination
            pageSize={10}
            emptyMessage="Aucun modèle de ventilation"
          />
        </ModuleCard>

        <ModuleCard
          title="Axes analytiques"
          description="Dimensions d'analyse déclarées pour le tenant."
        >
          <SmartGrid
            columns={axisColumns}
            data={axes}
            title="Axes"
            description={`${axes.length} axes`}
            showSearch
            showCreate
            showExport
            showPagination={false}
            emptyMessage="Aucun axe analytique"
          />
        </ModuleCard>
      </div>
    </ModuleShell>
  );
}
