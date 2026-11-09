/**
 * Page Paie — Niveau T (SmartGrid employés) + P (RPCPanel T5/T6/T7)
 * Tables: employees, payslips, pay_periods (schéma client_demo)
 * RPC: rpc_calculate_payroll (T5), rpc_validate_payslip (T6), rpc_generate_payroll_entries (T7)
 * Workflow bulletins : DRAFT→VALIDATED (irréversible, NOYAU-NORMATIF §2)
 */

import { useState, useMemo } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { createFileRoute } from "@tanstack/react-router";
import {
  Users,
  Download,
  Calculator,
  CheckCircle,
  FileText,
  Loader2,
} from "lucide-react";

import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import {
  KpiCard,
  KpiGrid,
  ModuleCard,
  ModuleShell,
  StatusBadge,
} from "@/components/edenfin/module-shell";
import { SmartGrid, type GridColumn } from "@/components/edenfin/smart-grid";
import { RPCPanel, type RPCFunction } from "@/components/edenfin/rpc-panel";
import { formatXAF, formatDate, formatPeriod } from "@/lib/formatters";
import { supabase } from "@/lib/supabase";
import { useToast } from "@/hooks/use-toast";

export const Route = createFileRoute("/_authenticated/console/paie")({
  ssr: false,
  component: PaiePage,
});

type PayslipStatus = "DRAFT" | "VALIDATED" | "PAID" | "CANCELLED";
type ActiveTab = "bulletins" | "employes" | "traitements";

const STATUS_LABEL: Record<PayslipStatus, string> = {
  DRAFT: "Brouillon",
  VALIDATED: "Validé",
  PAID: "Payé",
  CANCELLED: "Annulé",
};

const STATUS_TONE: Record<
  PayslipStatus,
  "default" | "success" | "warning" | "danger"
> = {
  DRAFT: "warning",
  VALIDATED: "success",
  PAID: "success",
  CANCELLED: "danger",
};

// ── T5 : Calcul de paie mensuel ───────────────────────────────────────────────
const T5_CALCULATE: RPCFunction = {
  name: "rpc_calculate_payroll",
  label: "T5 — Calcul de paie",
  description:
    "Calcule les bulletins de paie pour le mois sélectionné. Taux CNSS/CRF/CNAMGS lus depuis contribution_rates. IRPP lu depuis common.tax_codes. Crée les bulletins DRAFT pour tous les employés actifs.",
  category: "Paie",
  icon: <Calculator className="h-4 w-4" />,
  parameters: [
    {
      name: "p_month",
      type: "number",
      label: "Mois (1-12)",
      description: "Numéro du mois de la période de paie",
      required: true,
      defaultValue: new Date().getMonth() + 1,
    },
    {
      name: "p_year",
      type: "number",
      label: "Année",
      description: "Année de la période de paie",
      required: true,
      defaultValue: new Date().getFullYear(),
    },
  ],
};

// ── T6 : Validation d'un bulletin (DRAFT → VALIDATED, irréversible) ────────────
const T6_VALIDATE: RPCFunction = {
  name: "rpc_validate_payslip",
  label: "T6 — Valider un bulletin",
  description:
    "Valide un bulletin DRAFT (transition irréversible DRAFT→VALIDATED, NOYAU-NORMATIF §2). Saisir l'ID du bulletin (colonne ID dans la liste des bulletins).",
  category: "Paie",
  icon: <CheckCircle className="h-4 w-4" />,
  parameters: [
    {
      name: "p_payslip_id",
      type: "number",
      label: "ID bulletin",
      description: "Identifiant du bulletin de paie à valider (table payslips)",
      required: true,
    },
  ],
};

// ── T7 : OD de paie — écritures SYSCOHADA ─────────────────────────────────────
const T7_GENERATE: RPCFunction = {
  name: "rpc_generate_payroll_entries",
  label: "T7 — Générer OD de paie",
  description:
    "Génère les écritures comptables SYSCOHADA pour tous les bulletins VALIDATED de la période. Comptes de contrepartie depuis payroll_rubrics.debit_account_id/credit_account_id (NOYAU-NORMATIF §5 — aucun compte en dur).",
  category: "Paie",
  icon: <FileText className="h-4 w-4" />,
  parameters: [
    {
      name: "p_pay_period_id",
      type: "number",
      label: "ID période de paie",
      description: "Identifiant de la période de paie (table pay_periods)",
      required: true,
    },
    {
      name: "p_fiscal_period_id",
      type: "number",
      label: "ID période fiscale",
      description:
        "Période fiscale SYSCOHADA à rattacher (table fiscal_periods)",
      required: true,
    },
  ],
};

// ── Colonnes SmartGrid employés ───────────────────────────────────────────────
const EMPLOYEE_COLUMNS: GridColumn[] = [
  { key: "employee_number", label: "Matricule", type: "text", sortable: true },
  { key: "last_name", label: "Nom", type: "text", sortable: true },
  { key: "first_name", label: "Prénom", type: "text", sortable: true },
  { key: "position", label: "Poste", type: "text" },
  { key: "department", label: "Département", type: "text" },
  {
    key: "contract_type",
    label: "Contrat",
    type: "badge",
    sortable: true,
    badgeMap: {
      CDI: { label: "CDI", variant: "success" },
      CDD: { label: "CDD", variant: "warning" },
      INTERIM: { label: "Intérim", variant: "default" },
      APPRENTICE: { label: "Apprenti", variant: "info" },
      INTERN: { label: "Stagiaire", variant: "default" },
      FREELANCE: { label: "Freelance", variant: "info" },
    },
  },
  {
    key: "base_salary",
    label: "Salaire brut",
    type: "currency",
    align: "right",
    sortable: true,
    render: (v) => formatXAF(v),
  },
  {
    key: "hire_date",
    label: "Embauche",
    type: "date",
    sortable: true,
    render: (v) => formatDate(v),
  },
  {
    key: "is_active",
    label: "Statut",
    type: "badge",
    badgeMap: {
      true: { label: "Actif", variant: "success" },
      false: { label: "Inactif", variant: "default" },
    },
  },
];

const TABS: { key: ActiveTab; label: string }[] = [
  { key: "bulletins", label: "Bulletins" },
  { key: "employes", label: "Employés" },
  { key: "traitements", label: "Traitements" },
];

function PaiePage() {
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const [activeTab, setActiveTab] = useState<ActiveTab>("bulletins");

  const period = useMemo(() => {
    const now = new Date();
    return { fiscalYear: now.getFullYear(), month: now.getMonth() + 1 };
  }, []);

  const periodStart = `${period.fiscalYear}-${String(period.month).padStart(2, "0")}-01`;
  const periodEndDate = new Date(period.fiscalYear, period.month, 0);
  const periodEndStr = `${period.fiscalYear}-${String(period.month).padStart(2, "0")}-${String(periodEndDate.getDate()).padStart(2, "0")}`;
  const periodLabel = formatPeriod(period.fiscalYear, period.month);

  // ── Bulletins du mois courant ──────────────────────────────────────────────
  const payslipsQuery = useQuery({
    queryKey: ["payslips", period],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("payslips")
        .select(
          "id, gross_salary, net_salary, net_taxable, employer_contributions, status, period_start, period_end, validated_at, employees(employee_number, first_name, last_name, position)"
        )
        .gte("period_start", periodStart)
        .lte("period_end", periodEndStr)
        .is("deleted_at", null)
        .order("created_at", { ascending: false })
        .limit(200);
      if (error) throw new Error(error.message);
      return data ?? [];
    },
  });

  // ── Employés actifs (chargé uniquement si onglet actif) ────────────────────
  const employeesQuery = useQuery({
    queryKey: ["employees-paie"],
    enabled: activeTab === "employes",
    queryFn: async () => {
      const { data, error } = await supabase
        .from("employees")
        .select("*")
        .is("deleted_at", null)
        .order("last_name", { ascending: true })
        .limit(500);
      if (error) throw new Error(error.message);
      return data ?? [];
    },
  });

  // ── Agrégats KPI ───────────────────────────────────────────────────────────
  const payslips = useMemo(() => payslipsQuery.data ?? [], [payslipsQuery.data]);

  const kpiBulletins = payslips.length;
  const kpiBrouillons = payslips.filter((p: any) => p.status === "DRAFT").length;
  const kpiValidated = payslips.filter((p: any) => p.status === "VALIDATED").length;
  const kpiMasseBrute = payslips.reduce(
    (s: number, p: any) => s + Number(p.gross_salary ?? 0),
    0
  );
  const kpiNetPayer = payslips.reduce(
    (s: number, p: any) => s + Number(p.net_salary ?? 0),
    0
  );
  const kpiChargesPatronales = payslips.reduce(
    (s: number, p: any) => s + Number(p.employer_contributions ?? 0),
    0
  );

  const isAuthError =
    payslipsQuery.isError &&
    (payslipsQuery.error?.message?.includes("JWT") ||
      payslipsQuery.error?.message?.includes("permission") ||
      payslipsQuery.error?.message?.includes("auth"));

  // ── Exécution RPC avec feedback utilisateur ────────────────────────────────
  const handleRpcExecute = async (
    fnName: string,
    params: Record<string, any>
  ) => {
    const { data, error } = await supabase.rpc(fnName, params);
    if (error) throw new Error(error.message);
    const result = data as any;
    if (result && result.success === false)
      throw new Error(result.error ?? "Erreur RPC");

    let description = "Opération réussie.";
    if (fnName === "rpc_calculate_payroll") {
      description = `${result.employees_processed ?? 0} bulletin(s) calculé(s) — masse brute : ${formatXAF(result.total_brut)}`;
    } else if (fnName === "rpc_validate_payslip") {
      description = `Bulletin #${result.payslip_id} validé — net : ${formatXAF(result.net_salary)}`;
    } else if (fnName === "rpc_generate_payroll_entries") {
      description = `OD #${result.journal_entry_id} générée — ${result.payslips_processed ?? 0} bulletin(s) — brut : ${formatXAF(result.total_brut)}`;
    }

    toast({ title: "Exécution réussie", description });
    queryClient.invalidateQueries({ queryKey: ["payslips"] });
    return result;
  };

  return (
    <ModuleShell
      icon={<Users className="h-5 w-5" />}
      title="Paie"
      subtitle="Bulletins SYSCOHADA/OHADA — cotisations CNSS, CRF, CNAMGS et IRPP depuis le paramétrage."
      actions={
        <>
          <Button variant="outline" size="sm">
            <Download className="h-4 w-4" /> Exporter
          </Button>
          <Button
            variant="prestige"
            size="sm"
            onClick={() => setActiveTab("traitements")}
          >
            <Calculator className="h-4 w-4" /> Lancer la paie
          </Button>
        </>
      }
    >
      <div className="space-y-6">
        {/* ── Barre d'onglets ─────────────────────────────────────────────── */}
        <div className="-mt-2 flex gap-1 border-b border-border pb-0">
          {TABS.map((t) => (
            <button
              key={t.key}
              type="button"
              onClick={() => setActiveTab(t.key)}
              className={cn(
                "relative whitespace-nowrap px-3 pb-2.5 pt-1 text-sm transition-colors",
                t.key === activeTab
                  ? "text-foreground"
                  : "text-muted-foreground hover:text-foreground"
              )}
            >
              {t.label}
              {t.key === activeTab && (
                <span className="absolute inset-x-2 -bottom-px h-0.5 rounded-full bg-primary" />
              )}
            </button>
          ))}
        </div>

        {/* ── KPIs communs ─────────────────────────────────────────────────── */}
        <KpiGrid>
          <KpiCard
            label={`Bulletins ${periodLabel}`}
            value={payslipsQuery.isLoading ? "…" : String(kpiBulletins)}
            delta={
              kpiBrouillons > 0
                ? `${kpiBrouillons} à valider · ${kpiValidated} validé(s)`
                : "Tous validés"
            }
            tone={kpiBrouillons > 0 ? "warning" : "success"}
          />
          <KpiCard
            label="Masse salariale brute"
            value={payslipsQuery.isLoading ? "…" : formatXAF(kpiMasseBrute)}
            hint={periodLabel}
            tone="default"
          />
          <KpiCard
            label="Charges patronales"
            value={
              payslipsQuery.isLoading ? "…" : formatXAF(kpiChargesPatronales)
            }
            hint="CNSS · CRF · CNAMGS"
          />
          <KpiCard
            label="Net à payer total"
            value={payslipsQuery.isLoading ? "…" : formatXAF(kpiNetPayer)}
            hint="bulletins de la période"
            tone="success"
          />
        </KpiGrid>

        {/* ── Onglet BULLETINS ───────────────────────────────────────────── */}
        {activeTab === "bulletins" && (
          <>
            {isAuthError && (
              <div className="rounded-md border border-destructive/40 bg-destructive/10 px-4 py-3 text-sm text-destructive">
                Accès restreint — connectez-vous avec un compte autorisé pour
                afficher les bulletins de paie.
              </div>
            )}

            <ModuleCard
              title={`Bulletins de paie — ${periodLabel}`}
              description={`${kpiBulletins} bulletin(s) · ${kpiBrouillons} en attente de validation`}
              action={
                <Button variant="ghost" size="sm">
                  <FileText className="h-4 w-4" /> Sommier
                </Button>
              }
            >
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-border text-left text-[11px] uppercase tracking-wider text-muted-foreground">
                      <th className="py-2 pr-3 font-medium">ID</th>
                      <th className="py-2 pr-3 font-medium">Matricule</th>
                      <th className="py-2 pr-3 font-medium">Salarié</th>
                      <th className="py-2 pr-3 font-medium">Poste</th>
                      <th className="py-2 pr-3 text-right font-medium">
                        Brut
                      </th>
                      <th className="py-2 pr-3 text-right font-medium">
                        Charges patron.
                      </th>
                      <th className="py-2 pr-3 text-right font-medium">
                        Net à payer
                      </th>
                      <th className="py-2 pr-3 font-medium">Statut</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border">
                    {payslipsQuery.isLoading ? (
                      <tr>
                        <td
                          colSpan={8}
                          className="py-10 text-center text-muted-foreground"
                        >
                          <Loader2 className="mx-auto h-4 w-4 animate-spin" />
                        </td>
                      </tr>
                    ) : payslips.length === 0 ? (
                      <tr>
                        <td
                          colSpan={8}
                          className="py-10 text-center text-muted-foreground"
                        >
                          {isAuthError
                            ? "Authentification requise pour afficher les bulletins."
                            : `Aucun bulletin sur ${periodLabel}. Lancez le calcul T5 depuis l'onglet Traitements.`}
                        </td>
                      </tr>
                    ) : (
                      payslips.map((p: any) => {
                        const emp = p.employees as any;
                        const status = p.status as PayslipStatus;
                        return (
                          <tr key={p.id} className="hover:bg-muted/40">
                            <td className="py-2.5 pr-3 font-mono text-xs text-muted-foreground">
                              #{p.id}
                            </td>
                            <td className="py-2.5 pr-3 font-mono text-xs text-foreground">
                              {emp?.employee_number ?? "—"}
                            </td>
                            <td className="py-2.5 pr-3 font-medium text-foreground">
                              {emp
                                ? `${emp.last_name} ${emp.first_name}`
                                : "—"}
                            </td>
                            <td className="py-2.5 pr-3 text-muted-foreground text-xs">
                              {emp?.position ?? "—"}
                            </td>
                            <td className="py-2.5 pr-3 text-right font-mono tabular-nums">
                              {formatXAF(p.gross_salary, false)}
                            </td>
                            <td className="py-2.5 pr-3 text-right font-mono tabular-nums text-muted-foreground">
                              {formatXAF(p.employer_contributions, false)}
                            </td>
                            <td className="py-2.5 pr-3 text-right font-mono tabular-nums font-semibold text-foreground">
                              {formatXAF(p.net_salary, false)}
                            </td>
                            <td className="py-2.5 pr-3">
                              <StatusBadge
                                tone={STATUS_TONE[status] ?? "default"}
                              >
                                {STATUS_LABEL[status] ?? status}
                              </StatusBadge>
                            </td>
                          </tr>
                        );
                      })
                    )}
                  </tbody>
                  {payslips.length > 0 && (
                    <tfoot>
                      <tr className="border-t-2 border-border text-sm font-semibold">
                        <td
                          colSpan={4}
                          className="py-3 pr-3 text-right text-[11px] uppercase tracking-wider text-muted-foreground"
                        >
                          Totaux période
                        </td>
                        <td className="py-3 pr-3 text-right font-mono tabular-nums">
                          {formatXAF(kpiMasseBrute, false)}
                        </td>
                        <td className="py-3 pr-3 text-right font-mono tabular-nums text-muted-foreground">
                          {formatXAF(kpiChargesPatronales, false)}
                        </td>
                        <td className="py-3 pr-3 text-right font-mono tabular-nums">
                          {formatXAF(kpiNetPayer, false)}
                        </td>
                        <td />
                      </tr>
                    </tfoot>
                  )}
                </table>
              </div>
            </ModuleCard>
          </>
        )}

        {/* ── Onglet EMPLOYÉS ────────────────────────────────────────────── */}
        {activeTab === "employes" && (
          <ModuleCard
            title="Référentiel Employés"
            description="Employés — schéma client_demo.employees (lecture, RLS company_id)"
          >
            <SmartGrid
              columns={EMPLOYEE_COLUMNS}
              data={employeesQuery.data ?? []}
              loading={employeesQuery.isLoading}
              showCreate={false}
              emptyMessage={
                employeesQuery.isError
                  ? "Erreur de chargement — authentification requise."
                  : "Aucun employé trouvé dans la base."
              }
            />
          </ModuleCard>
        )}

        {/* ── Onglet TRAITEMENTS : RPCPanel T5 / T6 / T7 ─────────────────── */}
        {activeTab === "traitements" && (
          <div className="space-y-6">
            <div className="rounded-md border border-primary/20 bg-primary/5 px-4 py-3 text-sm">
              <strong>Prérequis T6 & T7 :</strong> appliquer la migration{" "}
              <code className="rounded bg-muted px-1 font-mono text-xs">
                20260725000001_paie-rpc-t6-t7.sql
              </code>{" "}
              dans Supabase avant d&apos;exécuter ces fonctions.
            </div>

            <RPCPanel
              rpcFunction={T5_CALCULATE}
              onExecute={(params) =>
                handleRpcExecute("rpc_calculate_payroll", params)
              }
              showResults
            />

            <RPCPanel
              rpcFunction={T6_VALIDATE}
              onExecute={(params) =>
                handleRpcExecute("rpc_validate_payslip", params)
              }
              showResults
            />

            <RPCPanel
              rpcFunction={T7_GENERATE}
              onExecute={(params) =>
                handleRpcExecute("rpc_generate_payroll_entries", params)
              }
              showResults
            />
          </div>
        )}
      </div>
    </ModuleShell>
  );
}
