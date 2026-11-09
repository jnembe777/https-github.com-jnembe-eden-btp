import { createFileRoute } from "@tanstack/react-router";
import { Globe2 } from "lucide-react";

import {
  ModuleShell,
  KpiGrid,
  KpiCard,
  ModuleCard,
  StatusBadge,
} from "@/components/edenfin/module-shell";
import { useGammeGate } from "@/components/edenfin/gamme-gate";
import { SmartGrid, GridColumn } from "@/components/edenfin/smart-grid";
import { MOCK_COUNTRIES, type CountryConfig } from "@/lib/mock-gammes";
import { useGammeData } from "@/hooks/use-gamme-data";

export const Route = createFileRoute("/_authenticated/console/onyx-pays")({
  component: OnyxPaysPage,
});

function OnyxPaysPage() {
  const { data: countries, isDemo } = useGammeData<CountryConfig>("countries", MOCK_COUNTRIES, { schema: "SYSTEM" });
  const zones = Array.from(new Set(countries.map((c) => c.economic_zone)));
  const currencies = Array.from(new Set(countries.map((c) => c.currency_code)));
  const ohada = countries.filter((c) => c.primary_gaap === "OHADA").length;

  const columns: GridColumn<CountryConfig>[] = [
    {
      key: "country_code",
      label: "Code",
      type: "text",
      width: "80px",
      align: "center",
      render: (v) => (
        <span className="inline-flex items-center rounded bg-foreground/10 px-1.5 py-0.5 font-mono text-xs font-semibold">
          {v}
        </span>
      ),
    },
    { key: "country_name", label: "Pays", type: "text", width: "auto" },
    {
      key: "currency_code",
      label: "Devise",
      type: "text",
      width: "90px",
      align: "center",
      render: (v) => <span className="font-mono text-xs">{v}</span>,
    },
    {
      key: "economic_zone",
      label: "Zone",
      type: "badge",
      width: "130px",
      badgeMap: {
        CEMAC: { label: "CEMAC", variant: "default" },
        UEMOA: { label: "UEMOA", variant: "secondary" },
        OHADA: { label: "OHADA", variant: "secondary" },
        EU: { label: "UE", variant: "outline" },
        ECOWAS: { label: "CEDEAO", variant: "outline" },
        SADC: { label: "SADC", variant: "outline" },
      },
    },
    {
      key: "primary_gaap",
      label: "Référentiel",
      type: "badge",
      width: "120px",
      badgeMap: {
        OHADA: { label: "OHADA", variant: "default" },
        IFRS: { label: "IFRS", variant: "secondary" },
      },
    },
    {
      key: "vat_standard_rate",
      label: "TVA",
      type: "number",
      width: "90px",
      align: "right",
      render: (v) => <span>{v} %</span>,
    },
    {
      key: "corporate_tax_rate",
      label: "IS",
      type: "number",
      width: "90px",
      align: "right",
      render: (v) => <span>{v} %</span>,
    },
  ];

  const locked = useGammeGate("ONYX");
  if (locked) return locked;

  return (
    <ModuleShell
      icon={<Globe2 className="h-5 w-5" />}
      title="Configuration multi-pays"
      subtitle="Gamme ONYX · Référentiel pays, zones économiques, référentiels comptables et fiscalité (rpc_get_country_tax_config)."
      actions={isDemo ? (
        <StatusBadge tone="warning">Mode démonstration</StatusBadge>
      ) : (
        <StatusBadge tone="success">Données Supabase</StatusBadge>
      )}
      tabs={[
        { key: "pays", label: "Pays", active: true },
        { key: "gaap", label: "Multi-GAAP" },
        { key: "reporting", label: "Reporting réglementaire" },
      ]}
    >
      <div className="space-y-6">
        <KpiGrid>
          <KpiCard label="Pays configurés" value={String(countries.length)} hint="référentiel actif" />
          <KpiCard label="Zones économiques" value={String(zones.length)} hint={zones.join(" · ")} />
          <KpiCard label="Devises" value={String(currencies.length)} hint="multi-devises" />
          <KpiCard label="Zone OHADA" value={String(ohada)} delta="pays OHADA" tone="success" />
        </KpiGrid>

        <ModuleCard
          title="Référentiel pays"
          description="Chaque pays porte sa devise, sa zone, son référentiel comptable et ses taux (TVA, IS)."
        >
          <div className="mb-3">
            <StatusBadge tone="info">Source : sys.countries · rpc_get_country_tax_config</StatusBadge>
          </div>
          <SmartGrid
            columns={columns}
            data={countries}
            title="Pays"
            description={`${countries.length} pays · ${zones.length} zones`}
            showSearch
            showCreate
            showExport
            showPagination
            pageSize={15}
            emptyMessage="Aucun pays configuré"
          />
        </ModuleCard>
      </div>
    </ModuleShell>
  );
}
