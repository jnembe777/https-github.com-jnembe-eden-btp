import { createFileRoute } from "@tanstack/react-router";
import { Landmark } from "lucide-react";

import {
  ModuleShell,
  KpiGrid,
  KpiCard,
  ModuleCard,
  StatusBadge,
} from "@/components/edenfin/module-shell";
import { useGammeGate } from "@/components/edenfin/gamme-gate";
import { SmartGrid, GridColumn } from "@/components/edenfin/smart-grid";
import { MOCK_CASH_POSITIONS, type CashPosition } from "@/lib/mock-gammes";
import { useGammeData } from "@/hooks/use-gamme-data";

export const Route = createFileRoute(
  "/_authenticated/console/onyx-tresorerie",
)({
  component: OnyxTresoreriePage,
});

const fmtM = (n: number) =>
  new Intl.NumberFormat("fr-FR", { maximumFractionDigits: 1 }).format(n / 1_000_000) + " M";

function OnyxTresoreriePage() {
  const { data: positions, isDemo } = useGammeData<CashPosition>("cash_pools", MOCK_CASH_POSITIONS, { schema: "ONYX" });
  const total = positions.reduce((s, p) => s + p.balance, 0);
  const countries = Array.from(new Set(positions.map((p) => p.country_code)));
  const currencies = Array.from(new Set(positions.map((p) => p.currency_code)));

  const columns: GridColumn<CashPosition>[] = [
    { key: "entity_name", label: "Entité", type: "text", width: "auto" },
    { key: "bank", label: "Banque", type: "text", width: "180px" },
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
      key: "balance",
      label: "Solde",
      type: "number",
      width: "160px",
      align: "right",
      render: (v) => <span className="font-medium">{fmtM(v)}</span>,
    },
  ];

  const locked = useGammeGate("ONYX");
  if (locked) return locked;

  return (
    <ModuleShell
      icon={<Landmark className="h-5 w-5" />}
      title="Trésorerie groupe"
      subtitle="Gamme ONYX · Cash pooling multi-pays, positions bancaires et netting inter-sociétés."
      actions={isDemo ? (
        <StatusBadge tone="warning">Mode démonstration</StatusBadge>
      ) : (
        <StatusBadge tone="success">Données Supabase</StatusBadge>
      )}
      tabs={[
        { key: "positions", label: "Positions", active: true },
        { key: "pooling", label: "Cash pooling" },
        { key: "netting", label: "Netting" },
      ]}
    >
      <div className="space-y-6">
        <KpiGrid>
          <KpiCard label="Position nette groupe" value={fmtM(total)} delta="toutes devises (contre-valeur XAF)" tone="success" />
          <KpiCard label="Comptes bancaires" value={String(positions.length)} hint={`${countries.length} pays`} />
          <KpiCard label="Devises" value={String(currencies.length)} hint={currencies.join(" · ")} />
          <KpiCard label="Cash pools actifs" value="2" hint="notionnel + physique" />
        </KpiGrid>

        <ModuleCard
          title="Positions bancaires"
          description="rpc_get_treasury_dashboard / rpc_run_cash_pool_sweep (multi-pays, multi-devises)."
        >
          <div className="mb-3">
            <StatusBadge tone="info">Source : onyx.cash_pools · client_demo.bank_accounts</StatusBadge>
          </div>
          <SmartGrid
            columns={columns}
            data={positions}
            title="Comptes"
            description={`${positions.length} comptes · ${countries.length} pays`}
            showSearch
            showExport
            showPagination={false}
            showCreate={false}
            emptyMessage="Aucune position"
          />
        </ModuleCard>
      </div>
    </ModuleShell>
  );
}
