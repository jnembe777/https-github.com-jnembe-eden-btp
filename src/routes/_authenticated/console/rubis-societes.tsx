import { createFileRoute } from "@tanstack/react-router";
import { Building2 } from "lucide-react";

import {
  ModuleShell,
  KpiGrid,
  KpiCard,
  ModuleCard,
  StatusBadge,
} from "@/components/edenfin/module-shell";
import { useGammeGate } from "@/components/edenfin/gamme-gate";
import { SmartGrid, GridColumn } from "@/components/edenfin/smart-grid";
import { MOCK_ENTITIES, type Entity } from "@/lib/mock-gammes";
import { useGammeData } from "@/hooks/use-gamme-data";

export const Route = createFileRoute(
  "/_authenticated/console/rubis-societes",
)({
  component: RubisSocietesPage,
});

function RubisSocietesPage() {
  const { data: entities, isDemo } = useGammeData<Entity>("tenant_entities", MOCK_ENTITIES, { schema: "SYSTEM" });
  const parents = entities.filter((e) => e.is_consolidation_parent).length;
  const countries = Array.from(new Set(entities.map((e) => e.country_code)));
  const fully = entities.filter((e) => e.consolidation_method === "FULL").length;

  const columns: GridColumn<Entity>[] = [
    {
      key: "entity_code",
      label: "Code",
      type: "text",
      width: "110px",
      render: (v) => <span className="font-mono text-sm font-medium">{v}</span>,
    },
    { key: "entity_name", label: "Société", type: "text", width: "auto" },
    {
      key: "country_code",
      label: "Pays",
      type: "text",
      width: "80px",
      align: "center",
      render: (v) => <span className="font-mono text-xs">{v}</span>,
    },
    {
      key: "currency_code",
      label: "Devise",
      type: "text",
      width: "80px",
      align: "center",
      render: (v) => <span className="font-mono text-xs">{v}</span>,
    },
    {
      key: "ownership_percentage",
      label: "% détention",
      type: "number",
      width: "110px",
      align: "right",
      render: (v) => <span>{v} %</span>,
    },
    {
      key: "consolidation_method",
      label: "Méthode",
      type: "badge",
      width: "140px",
      badgeMap: {
        PARENT: { label: "Société mère", variant: "default" },
        FULL: { label: "Intégration globale", variant: "secondary" },
        EQUITY: { label: "Mise en équivalence", variant: "outline" },
      },
    },
  ];

  const locked = useGammeGate("RUBIS");
  if (locked) return locked;

  return (
    <ModuleShell
      icon={<Building2 className="h-5 w-5" />}
      title="Multi-sociétés"
      subtitle="Gamme RUBIS · Périmètre du groupe, détention et méthodes de consolidation."
      actions={isDemo ? (
        <StatusBadge tone="warning">Mode démonstration</StatusBadge>
      ) : (
        <StatusBadge tone="success">Données Supabase</StatusBadge>
      )}
      tabs={[
        { key: "entites", label: "Sociétés", active: true },
        { key: "intercos", label: "Transactions inter-sociétés" },
        { key: "perimetres", label: "Périmètres" },
      ]}
    >
      <div className="space-y-6">
        <KpiGrid>
          <KpiCard label="Sociétés du groupe" value={String(entities.length)} hint={`${parents} société mère`} />
          <KpiCard label="Pays" value={String(countries.length)} hint={countries.join(" · ")} />
          <KpiCard label="Intégration globale" value={String(fully)} delta="consolidées" tone="success" />
          <KpiCard label="Mise en équivalence" value={String(entities.length - fully - parents)} hint="influence notable" />
        </KpiGrid>

        <ModuleCard
          title="Sociétés & détention"
          description="Isolation des données par société (entity_id) et règles de consolidation."
        >
          <div className="mb-3">
            <StatusBadge tone="info">Source : sys.tenant_entities</StatusBadge>
          </div>
          <SmartGrid
            columns={columns}
            data={entities}
            title="Sociétés"
            description={`${entities.length} sociétés · ${countries.length} pays`}
            showSearch
            showCreate
            showExport
            showPagination={false}
            emptyMessage="Aucune société"
          />
        </ModuleCard>
      </div>
    </ModuleShell>
  );
}
