import { useMemo, useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { Coins, ArrowRight } from "lucide-react";

import {
  ModuleShell,
  KpiGrid,
  KpiCard,
  ModuleCard,
  StatusBadge,
} from "@/components/edenfin/module-shell";
import { useGammeGate } from "@/components/edenfin/gamme-gate";
import { SmartGrid, GridColumn } from "@/components/edenfin/smart-grid";
import { MOCK_EXCHANGE_RATES, type ExchangeRate } from "@/lib/mock-gammes";
import { useGammeData } from "@/hooks/use-gamme-data";

export const Route = createFileRoute(
  "/_authenticated/console/saphir-devises",
)({
  component: SaphirDevisesPage,
});

const fmt = (n: number) =>
  new Intl.NumberFormat("fr-FR", { maximumFractionDigits: 2 }).format(n);

function SaphirDevisesPage() {
  const { data: rates, isDemo } = useGammeData<ExchangeRate>("exchange_rates", MOCK_EXCHANGE_RATES, { schema: "SYSTEM" });
  const currencies = Array.from(
    new Set(rates.flatMap((r) => [r.from_currency, r.to_currency])),
  ).sort();

  // Convertisseur (reflète sys.rpc_convert_amount = ROUND(montant × taux, 2))
  const [amount, setAmount] = useState(1000);
  const [from, setFrom] = useState("EUR");
  const [to, setTo] = useState("XAF");

  const rate = useMemo(() => {
    if (from === to) return 1;
    const direct = rates.find(
      (r) => r.from_currency === from && r.to_currency === to && r.rate_type === "SPOT",
    );
    if (direct) return direct.rate;
    const inverse = rates.find(
      (r) => r.from_currency === to && r.to_currency === from && r.rate_type === "SPOT",
    );
    if (inverse) return 1 / inverse.rate;
    return null;
  }, [rates, from, to]);

  const converted = rate != null ? Math.round(amount * rate * 100) / 100 : null;

  const columns: GridColumn<ExchangeRate>[] = [
    {
      key: "from_currency",
      label: "De",
      type: "text",
      width: "80px",
      align: "center",
      render: (v) => <span className="font-mono text-sm font-semibold">{v}</span>,
    },
    {
      key: "to_currency",
      label: "Vers",
      type: "text",
      width: "80px",
      align: "center",
      render: (v) => <span className="font-mono text-sm font-semibold">{v}</span>,
    },
    {
      key: "rate",
      label: "Taux",
      type: "number",
      width: "auto",
      align: "right",
      render: (v) => <span className="font-medium">{fmt(v)}</span>,
    },
    {
      key: "rate_type",
      label: "Type",
      type: "badge",
      width: "130px",
      badgeMap: {
        SPOT: { label: "Spot", variant: "secondary" },
        CLOSING: { label: "Clôture", variant: "outline" },
      },
    },
    { key: "rate_date", label: "Date", type: "date", width: "130px", align: "center" },
  ];

  const selectCls =
    "h-9 rounded-md border border-border bg-background px-2 text-sm focus:outline-none focus:ring-2 focus:ring-ring";

  const locked = useGammeGate("SAPHIR");
  if (locked) return locked;

  return (
    <ModuleShell
      icon={<Coins className="h-5 w-5" />}
      title="Gestion multi-devises"
      subtitle="Gamme SAPHIR · Taux de change, conversions et positions de change pour la consolidation IFRS."
      actions={isDemo ? (
        <StatusBadge tone="warning">Mode démonstration</StatusBadge>
      ) : (
        <StatusBadge tone="success">Données Supabase</StatusBadge>
      )}
      tabs={[
        { key: "rates", label: "Taux de change", active: true },
        { key: "positions", label: "Positions FX" },
        { key: "reval", label: "Réévaluation" },
      ]}
    >
      <div className="space-y-6">
        <KpiGrid>
          <KpiCard label="Devises actives" value={String(currencies.length)} hint="paires suivies" />
          <KpiCard label="EUR → XAF" value={fmt(655.957)} delta="parité fixe" tone="default" />
          <KpiCard label="Taux chargés" value={String(rates.length)} hint="spot + clôture" />
          <KpiCard label="Référentiel" value="IFRS" hint="conversion & écarts de change" />
        </KpiGrid>

        <ModuleCard
          title="Convertisseur"
          description="Aperçu de sys.rpc_convert_amount = ROUND(montant × taux, 2) ; taux inverse dérivé automatiquement."
        >
          <div className="flex flex-wrap items-end gap-3">
            <div className="flex flex-col gap-1">
              <label className="text-[11px] uppercase tracking-wide text-muted-foreground">Montant</label>
              <input
                type="number"
                value={amount}
                onChange={(e) => setAmount(Number(e.target.value))}
                className={`${selectCls} w-36`}
              />
            </div>
            <div className="flex flex-col gap-1">
              <label className="text-[11px] uppercase tracking-wide text-muted-foreground">De</label>
              <select value={from} onChange={(e) => setFrom(e.target.value)} className={selectCls}>
                {currencies.map((c) => (
                  <option key={c} value={c}>{c}</option>
                ))}
              </select>
            </div>
            <ArrowRight className="mb-2 h-4 w-4 text-muted-foreground" />
            <div className="flex flex-col gap-1">
              <label className="text-[11px] uppercase tracking-wide text-muted-foreground">Vers</label>
              <select value={to} onChange={(e) => setTo(e.target.value)} className={selectCls}>
                {currencies.map((c) => (
                  <option key={c} value={c}>{c}</option>
                ))}
              </select>
            </div>
            <div className="ml-auto rounded-lg border border-border bg-muted/40 px-4 py-2 text-right">
              <div className="text-[11px] uppercase tracking-wide text-muted-foreground">Résultat</div>
              {converted != null ? (
                <div className="font-display text-xl font-bold text-foreground">
                  {fmt(converted)} <span className="text-sm text-muted-foreground">{to}</span>
                </div>
              ) : (
                <div className="text-sm text-destructive">Taux indisponible</div>
              )}
              {rate != null && (
                <div className="text-[11px] text-muted-foreground">1 {from} = {fmt(rate)} {to}</div>
              )}
            </div>
          </div>
        </ModuleCard>

        <ModuleCard title="Taux de change" description="Taux spot et de clôture par paire de devises.">
          <div className="mb-3">
            <StatusBadge tone="info">Source : sys.exchange_rates</StatusBadge>
          </div>
          <SmartGrid
            columns={columns}
            data={rates}
            title="Taux"
            description={`${rates.length} taux chargés`}
            showSearch
            showCreate
            showExport
            showPagination={false}
            emptyMessage="Aucun taux de change"
          />
        </ModuleCard>
      </div>
    </ModuleShell>
  );
}
