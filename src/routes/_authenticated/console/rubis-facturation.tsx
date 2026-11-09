import { createFileRoute } from "@tanstack/react-router";
import { Receipt } from "lucide-react";

import {
  ModuleShell,
  KpiGrid,
  KpiCard,
  ModuleCard,
  StatusBadge,
} from "@/components/edenfin/module-shell";
import { useGammeGate } from "@/components/edenfin/gamme-gate";
import { SmartGrid, GridColumn } from "@/components/edenfin/smart-grid";
import { MOCK_INVOICES, type Invoice } from "@/lib/mock-gammes";
import { useGammeData } from "@/hooks/use-gamme-data";

export const Route = createFileRoute(
  "/_authenticated/console/rubis-facturation",
)({
  component: RubisFacturationPage,
});

const fmtXAF = (n: number) =>
  new Intl.NumberFormat("fr-FR", { maximumFractionDigits: 0 }).format(n) + " XAF";

function RubisFacturationPage() {
  const { data: invoices, isDemo } = useGammeData<Invoice>("invoices", MOCK_INVOICES, { schema: "SYSTEM" });
  const totalTTC = invoices.reduce((s, i) => s + i.amount_ttc, 0);
  const unpaid = invoices.filter((i) => i.status === "VALIDATED" && !i.paid);
  const unpaidTotal = unpaid.reduce((s, i) => s + i.amount_ttc, 0);
  const drafts = invoices.filter((i) => i.status === "DRAFT").length;

  const columns: GridColumn<Invoice>[] = [
    {
      key: "invoice_number",
      label: "N° facture",
      type: "text",
      width: "150px",
      render: (v) => <span className="font-mono text-sm font-medium">{v}</span>,
    },
    { key: "partner_name", label: "Client", type: "text", width: "auto" },
    { key: "invoice_date", label: "Date", type: "date", width: "120px", align: "center" },
    {
      key: "amount_ht",
      label: "Montant HT",
      type: "number",
      width: "150px",
      align: "right",
      render: (v) => <span className="text-muted-foreground">{fmtXAF(v)}</span>,
    },
    {
      key: "amount_ttc",
      label: "Montant TTC",
      type: "number",
      width: "160px",
      align: "right",
      render: (v) => <span className="font-medium">{fmtXAF(v)}</span>,
    },
    {
      key: "status",
      label: "Statut",
      type: "badge",
      width: "110px",
      badgeMap: {
        VALIDATED: { label: "Validée", variant: "default" },
        DRAFT: { label: "Brouillon", variant: "outline" },
      },
    },
    {
      key: "paid",
      label: "Règlement",
      type: "custom",
      width: "120px",
      render: (v) =>
        v ? (
          <StatusBadge tone="success">Réglée</StatusBadge>
        ) : (
          <StatusBadge tone="warning">En attente</StatusBadge>
        ),
    },
  ];

  const locked = useGammeGate("RUBIS");
  if (locked) return locked;

  return (
    <ModuleShell
      icon={<Receipt className="h-5 w-5" />}
      title="Facturation"
      subtitle="Gamme RUBIS · Cycle de facturation client avec ventilation analytique et suivi des règlements."
      actions={isDemo ? (
        <StatusBadge tone="warning">Mode démonstration</StatusBadge>
      ) : (
        <StatusBadge tone="success">Données Supabase</StatusBadge>
      )}
      tabs={[
        { key: "ventes", label: "Factures de vente", active: true },
        { key: "achats", label: "Factures d'achat" },
        { key: "reglements", label: "Règlements & relances" },
      ]}
    >
      <div className="space-y-6">
        <KpiGrid>
          <KpiCard label="Total facturé (TTC)" value={fmtXAF(totalTTC)} hint={`${invoices.length} factures`} />
          <KpiCard label="En attente de règlement" value={fmtXAF(unpaidTotal)} delta={`${unpaid.length} factures`} tone="warning" />
          <KpiCard label="Brouillons" value={String(drafts)} hint="à valider" />
          <KpiCard label="Taux de recouvrement" value="68 %" delta="30 j" tone="success" />
        </KpiGrid>

        <ModuleCard
          title="Factures de vente"
          description="rpc_create_invoice / rpc_validate_invoice / rpc_record_payment."
        >
          <div className="mb-3">
            <StatusBadge tone="info">Source : sys.invoices</StatusBadge>
          </div>
          <SmartGrid
            columns={columns}
            data={invoices}
            title="Factures"
            description={`${invoices.length} factures`}
            showSearch
            showCreate
            showExport
            showPagination
            pageSize={15}
            emptyMessage="Aucune facture"
          />
        </ModuleCard>
      </div>
    </ModuleShell>
  );
}
