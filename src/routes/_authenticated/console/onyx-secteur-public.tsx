import { createFileRoute } from "@tanstack/react-router";
import { Scale } from "lucide-react";

import {
  ModuleShell,
  KpiGrid,
  KpiCard,
  ModuleCard,
  StatusBadge,
} from "@/components/edenfin/module-shell";
import { useGammeGate } from "@/components/edenfin/gamme-gate";
import { SmartGrid, GridColumn } from "@/components/edenfin/smart-grid";
import { MOCK_APPROPRIATIONS, type Appropriation } from "@/lib/mock-gammes";
import { useGammeData } from "@/hooks/use-gamme-data";

export const Route = createFileRoute(
  "/_authenticated/console/onyx-secteur-public",
)({
  component: OnyxSecteurPublicPage,
});

const fmtM = (n: number) =>
  new Intl.NumberFormat("fr-FR", { maximumFractionDigits: 1 }).format(n / 1_000_000) + " M";

function OnyxSecteurPublicPage() {
  const { data: apps, isDemo } = useGammeData<Appropriation>("appropriations", MOCK_APPROPRIATIONS, { schema: "ONYX" });
  const totalBudget = apps.reduce((s, a) => s + a.original_amount, 0);
  const totalCommitted = apps.reduce((s, a) => s + a.committed, 0);
  const totalAvailable = apps.reduce((s, a) => s + a.available, 0);
  const execRate = Math.round((totalCommitted / totalBudget) * 100);
  const exhausted = apps.filter((a) => a.available === 0).length;

  const columns: GridColumn<Appropriation>[] = [
    {
      key: "appropriation_code",
      label: "Code",
      type: "text",
      width: "100px",
      render: (v) => <span className="font-mono text-sm font-medium">{v}</span>,
    },
    { key: "appropriation_name", label: "Crédit budgétaire", type: "text", width: "auto" },
    {
      key: "original_amount",
      label: "Dotation",
      type: "number",
      width: "130px",
      align: "right",
      render: (v) => <span className="text-muted-foreground">{fmtM(v)}</span>,
    },
    {
      key: "committed",
      label: "Engagé",
      type: "number",
      width: "130px",
      align: "right",
      render: (v) => <span>{fmtM(v)}</span>,
    },
    {
      key: "available",
      label: "Disponible",
      type: "number",
      width: "130px",
      align: "right",
      render: (v) => (
        <span className={v === 0 ? "font-medium text-destructive" : "font-medium text-success"}>
          {fmtM(v)}
        </span>
      ),
    },
    {
      key: "id",
      label: "Consommation",
      type: "custom",
      width: "130px",
      render: (_v, row) => {
        const pct = Math.round((row.committed / row.original_amount) * 100);
        return (
          <div className="flex items-center gap-2">
            <div className="h-1.5 w-16 overflow-hidden rounded-full bg-muted">
              <div
                className={`h-full ${pct >= 100 ? "bg-destructive" : pct >= 85 ? "bg-warning" : "bg-primary"}`}
                style={{ width: `${Math.min(pct, 100)}%` }}
              />
            </div>
            <span className="text-xs text-muted-foreground">{pct} %</span>
          </div>
        );
      },
    },
  ];

  const locked = useGammeGate("ONYX");
  if (locked) return locked;

  return (
    <ModuleShell
      icon={<Scale className="h-5 w-5" />}
      title="Secteur public"
      subtitle="Gamme ONYX · Comptabilité publique : crédits budgétaires, engagements, chaîne ordonnateur / comptable."
      actions={isDemo ? (
        <StatusBadge tone="warning">Mode démonstration</StatusBadge>
      ) : (
        <StatusBadge tone="success">Données Supabase</StatusBadge>
      )}
      tabs={[
        { key: "credits", label: "Crédits & engagements", active: true },
        { key: "mandats", label: "Mandats & titres" },
        { key: "subventions", label: "Subventions" },
      ]}
    >
      <div className="space-y-6">
        <KpiGrid>
          <KpiCard label="Budget voté" value={fmtM(totalBudget)} hint="exercice 2026" />
          <KpiCard label="Engagé" value={fmtM(totalCommitted)} delta={`taux d'exécution ${execRate} %`} tone="default" />
          <KpiCard label="Disponible" value={fmtM(totalAvailable)} tone="success" />
          <KpiCard label="Crédits épuisés" value={String(exhausted)} delta="disponible = 0" tone="warning" />
        </KpiGrid>

        <ModuleCard
          title="Crédits budgétaires"
          description="Contrôle d'engagement : rpc_check_appropriation / rpc_create_encumbrance."
        >
          <div className="mb-3">
            <StatusBadge tone="info">Source : onyx.appropriations</StatusBadge>
          </div>
          <SmartGrid
            columns={columns}
            data={apps}
            title="Crédits"
            description={`${apps.length} crédits · exécution ${execRate} %`}
            showSearch
            showExport
            showPagination={false}
            showCreate={false}
            emptyMessage="Aucun crédit budgétaire"
          />
        </ModuleCard>
      </div>
    </ModuleShell>
  );
}
