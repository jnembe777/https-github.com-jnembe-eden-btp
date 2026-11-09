import { createFileRoute } from "@tanstack/react-router";
import { GitPullRequestArrow } from "lucide-react";

import {
  ModuleShell,
  KpiGrid,
  KpiCard,
  ModuleCard,
  StatusBadge,
} from "@/components/edenfin/module-shell";
import { useGammeGate } from "@/components/edenfin/gamme-gate";
import { SmartGrid, GridColumn } from "@/components/edenfin/smart-grid";
import { MOCK_APPROVALS, type Approval } from "@/lib/mock-gammes";
import { useGammeData } from "@/hooks/use-gamme-data";

export const Route = createFileRoute(
  "/_authenticated/console/saphir-workflow",
)({
  component: SaphirWorkflowPage,
});

const fmtXAF = (n: number) =>
  n > 0 ? new Intl.NumberFormat("fr-FR", { maximumFractionDigits: 0 }).format(n) + " XAF" : "—";

function SaphirWorkflowPage() {
  const { data: approvals, isDemo } = useGammeData<Approval>("v_pending_approvals", MOCK_APPROVALS, { schema: "SYSTEM" });
  const pending = approvals.filter((a) => a.status === "PENDING");
  const overdue = pending.filter((a) => a.due_in_days < 0).length;

  const columns: GridColumn<Approval>[] = [
    { key: "document", label: "Document", type: "text", width: "auto" },
    {
      key: "amount",
      label: "Montant",
      type: "number",
      width: "150px",
      align: "right",
      render: (v) => <span className="font-medium">{fmtXAF(v)}</span>,
    },
    { key: "current_step", label: "Étape courante", type: "text", width: "180px" },
    { key: "requester", label: "Demandeur", type: "text", width: "120px" },
    {
      key: "status",
      label: "Statut",
      type: "badge",
      width: "120px",
      badgeMap: {
        PENDING: { label: "En attente", variant: "secondary" },
        APPROVED: { label: "Approuvé", variant: "default" },
        REJECTED: { label: "Rejeté", variant: "destructive" },
      },
    },
    {
      key: "due_in_days",
      label: "Échéance",
      type: "custom",
      width: "120px",
      align: "right",
      render: (v) => {
        const d = v as number;
        if (d < 0) return <StatusBadge tone="danger">En retard ({-d} j)</StatusBadge>;
        if (d === 0) return <StatusBadge tone="default">Clôturé</StatusBadge>;
        return <StatusBadge tone="info">J-{d}</StatusBadge>;
      },
    },
  ];

  const locked = useGammeGate("SAPHIR");
  if (locked) return locked;

  return (
    <ModuleShell
      icon={<GitPullRequestArrow className="h-5 w-5" />}
      title="Workflows d'approbation"
      subtitle="Gamme SAPHIR · Circuits de validation paramétrables (commandes, paiements, écritures, budgets)."
      actions={isDemo ? (
        <StatusBadge tone="warning">Mode démonstration</StatusBadge>
      ) : (
        <StatusBadge tone="success">Données Supabase</StatusBadge>
      )}
      tabs={[
        { key: "afaire", label: "À valider", active: true },
        { key: "circuits", label: "Circuits" },
        { key: "historique", label: "Historique" },
      ]}
    >
      <div className="space-y-6">
        <KpiGrid>
          <KpiCard label="En attente" value={String(pending.length)} hint="toutes étapes" />
          <KpiCard label="En retard" value={String(overdue)} delta="échéance dépassée" tone="danger" />
          <KpiCard label="Délai moyen" value="1,8 j" hint="validation" />
          <KpiCard label="Taux d'approbation" value="92 %" tone="success" />
        </KpiGrid>

        <ModuleCard
          title="Demandes en cours"
          description="Chaque document suit un circuit paramétré (workflow_definitions / workflow_steps / approvals)."
        >
          <div className="mb-3">
            <StatusBadge tone="info">Source : sys.v_pending_approvals</StatusBadge>
          </div>
          <SmartGrid
            columns={columns}
            data={approvals}
            title="Demandes"
            description={`${pending.length} en attente · ${overdue} en retard`}
            showSearch
            showExport
            showPagination={false}
            showCreate={false}
            emptyMessage="Aucune demande en attente"
          />
        </ModuleCard>
      </div>
    </ModuleShell>
  );
}
