/**
 * Dashboard dirigeant — EdenFin JASPE
 * Niveau D (Décisionnel) — STANDARD-UI-TPD §1
 * KPIs : rpc_dashboard_kpi (T17)
 * Graphique mensuel : v_monthly_summary
 */

import { createFileRoute } from "@tanstack/react-router";
import {
  BarChart3,
  DollarSign,
  TrendingUp,
  AlertTriangle,
  Loader2,
  LayoutDashboard,
} from "lucide-react";
import {
  BarChart,
  Bar,
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
} from "recharts";

import { ModuleShell } from "@/components/edenfin/module-shell";
import {
  KpiCard,
  KpiGrid,
  ModuleCard,
  StatusBadge,
} from "@/components/edenfin/dashboard-kpis";
import {
  REPARTITION_CHARGES,
  MOCK_TOP_CLIENTS,
  MOCK_ALERTS,
} from "@/lib/mock-data";
import { formatXAF, formatPercent } from "@/lib/formatters";
import { useSupabaseQuery } from "@/hooks/use-supabase";
import { useDashboardKpi } from "@/hooks/use-dashboard-kpi";
import { Alert, AlertDescription } from "@/components/ui/alert";

export const Route = createFileRoute("/_authenticated/console/dashboard")({
  component: DashboardPage,
});

const FISCAL_YEAR = new Date().getFullYear();

const MONTH_SHORT = [
  "Jan", "Fév", "Mar", "Avr", "Mai", "Jun",
  "Jul", "Aoû", "Sep", "Oct", "Nov", "Déc",
];

function monthLabel(n: number): string {
  return MONTH_SHORT[n - 1] ?? String(n);
}

function DashboardPage() {
  // KPIs annuels — rpc_dashboard_kpi (T17)
  const {
    data: dashboardData,
    isLoading: kpisLoading,
    error: kpisError,
  } = useDashboardKpi(FISCAL_YEAR);

  // Graphique mensuel — vue v_monthly_summary
  const {
    data: monthlySalesRaw,
    isLoading: salesLoading,
    error: salesError,
  } = useSupabaseQuery<{
    fiscal_year: number;
    month: number;
    month_label: string;
    ca: number;
    charges: number;
    resultat: number;
  }>("v_monthly_summary", {
    softDelete: false,
    filters: { fiscal_year: FISCAL_YEAR },
    order: { column: "month", ascending: true },
  });

  const kpi = dashboardData?.kpi;

  // Données du graphique avec label de mois formaté
  const chartData = (monthlySalesRaw ?? []).map((row) => ({
    month: monthLabel(row.month),
    ca: Number(row.ca) || 0,
    charges: Number(row.charges) || 0,
    resultat: Number(row.resultat) || 0,
  }));

  const hasChartData = chartData.some((r) => r.ca > 0 || r.charges > 0);
  const hasKpiError = !!kpisError;
  const hasSalesError = !!salesError;

  return (
    <ModuleShell
      icon={<BarChart3 className="h-5 w-5" />}
      title="Tableau de bord"
      subtitle="Vue d'ensemble de votre activité et indicateurs clés de performance."
    >
      <div className="space-y-6">
        {/* Erreur de connexion Supabase */}
        {(hasKpiError || hasSalesError) && (
          <Alert variant="destructive">
            <AlertTriangle className="h-4 w-4" />
            <AlertDescription>
              Impossible de charger les données depuis Supabase. Vérifiez la
              configuration de connexion.
            </AlertDescription>
          </Alert>
        )}

        {/* KPIs principaux */}
        <KpiGrid>
          {kpisLoading ? (
            <div className="col-span-4 flex items-center justify-center p-8">
              <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
            </div>
          ) : (
            <>
              <KpiCard
                label="CA annuel"
                value={formatXAF(kpi?.ca, false)}
                unit="XAF"
                tone="success"
                icon={<DollarSign className="h-4 w-4" />}
                hint={`Exercice ${FISCAL_YEAR}`}
              />
              <KpiCard
                label="Résultat net"
                value={formatXAF(kpi?.resultat, false)}
                unit="XAF"
                tone={
                  kpi && kpi.resultat < 0
                    ? "warning"
                    : kpi && kpi.resultat > 0
                      ? "success"
                      : "info"
                }
                icon={<TrendingUp className="h-4 w-4" />}
                hint={`Exercice ${FISCAL_YEAR}`}
              />
              <KpiCard
                label="Trésorerie"
                value={formatXAF(kpi?.tresorerie, false)}
                unit="XAF"
                tone={kpi && kpi.tresorerie < 0 ? "warning" : "default"}
                icon={<DollarSign className="h-4 w-4" />}
                hint="Soldes bancaires actifs"
              />
              <KpiCard
                label="Marge nette"
                value={kpi ? formatPercent(kpi.marge_pct / 100) : "—"}
                tone={
                  kpi && kpi.marge_pct < 0
                    ? "warning"
                    : kpi && kpi.marge_pct > 0
                      ? "success"
                      : "default"
                }
                icon={<BarChart3 className="h-4 w-4" />}
                hint="CA − Charges / CA"
              />
            </>
          )}
        </KpiGrid>

        {/* Graphiques */}
        <div className="grid gap-6 lg:grid-cols-2">
          {/* Évolution CA — v_monthly_summary */}
          <ModuleCard
            title="Évolution du chiffre d'affaires"
            description={`${FISCAL_YEAR} — données réelles`}
          >
            {salesLoading ? (
              <div className="flex h-[300px] items-center justify-center">
                <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
              </div>
            ) : !hasChartData ? (
              <EmptyChart message="Aucune écriture validée pour cet exercice." />
            ) : (
              <ResponsiveContainer width="100%" height={300}>
                <LineChart data={chartData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="month" />
                  <YAxis tickFormatter={(v: number) => formatXAF(v, false)} />
                  <Tooltip
                    formatter={(value: number) => formatXAF(value)}
                    labelStyle={{ color: "#000" }}
                  />
                  <Line
                    type="monotone"
                    dataKey="ca"
                    stroke="#3b82f6"
                    strokeWidth={2}
                    name="CA"
                  />
                  <Line
                    type="monotone"
                    dataKey="charges"
                    stroke="#f59e0b"
                    strokeWidth={2}
                    name="Charges"
                  />
                  <Line
                    type="monotone"
                    dataKey="resultat"
                    stroke="#10b981"
                    strokeWidth={2}
                    name="Résultat"
                  />
                </LineChart>
              </ResponsiveContainer>
            )}
          </ModuleCard>

          {/* Répartition charges — données de référence */}
          <ModuleCard
            title="Répartition des charges"
            description="Mois en cours"
          >
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie
                  data={REPARTITION_CHARGES}
                  dataKey="value"
                  nameKey="label"
                  cx="50%"
                  cy="50%"
                  outerRadius={100}
                  label={(entry) =>
                    `${entry.label}: ${formatXAF(entry.value)}`
                  }
                >
                  {REPARTITION_CHARGES.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip formatter={(value: number) => formatXAF(value)} />
              </PieChart>
            </ResponsiveContainer>
          </ModuleCard>
        </div>

        {/* Top clients et alertes */}
        <div className="grid gap-6 lg:grid-cols-2">
          <ModuleCard title="Top 5 clients" description="Par chiffre d'affaires">
            <div className="space-y-4">
              {MOCK_TOP_CLIENTS.map((client, idx) => (
                <div key={idx} className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className="flex h-8 w-8 items-center justify-center rounded-full bg-primary/10 text-sm font-semibold text-primary">
                      {idx + 1}
                    </div>
                    <div>
                      <div className="font-medium">{client.name}</div>
                      <div className="text-xs text-muted-foreground">
                        {client.pct}% du CA total
                      </div>
                    </div>
                  </div>
                  <div className="text-right font-mono text-sm">
                    {formatXAF(client.ca)}
                  </div>
                </div>
              ))}
            </div>
          </ModuleCard>

          <ModuleCard
            title="Alertes"
            description="Notifications importantes"
            action={
              <StatusBadge tone="warning">
                {MOCK_ALERTS.length} actives
              </StatusBadge>
            }
          >
            <div className="space-y-3">
              {MOCK_ALERTS.map((alert, idx) => (
                <div
                  key={idx}
                  className="flex items-start gap-3 rounded-lg border p-3"
                >
                  <AlertTriangle
                    className={`h-5 w-5 ${
                      alert.type === "warning"
                        ? "text-yellow-500"
                        : alert.type === "info"
                          ? "text-blue-500"
                          : "text-green-500"
                    }`}
                  />
                  <div className="flex-1">
                    <p className="text-sm font-medium">{alert.message}</p>
                    <p className="text-xs text-muted-foreground">
                      {new Date(alert.date).toLocaleDateString("fr-FR")}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </ModuleCard>
        </div>

        {/* Analyse mensuelle — v_monthly_summary */}
        <ModuleCard
          title="Analyse mensuelle"
          description={`Comparaison CA / Charges / Résultat — ${FISCAL_YEAR}`}
        >
          {salesLoading ? (
            <div className="flex h-[400px] items-center justify-center">
              <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
            </div>
          ) : !hasChartData ? (
            <EmptyChart message="Aucune écriture validée pour cet exercice. Les graphiques apparaîtront dès la première écriture comptabilisée." />
          ) : (
            <ResponsiveContainer width="100%" height={400}>
              <BarChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="month" />
                <YAxis tickFormatter={(v: number) => formatXAF(v, false)} />
                <Tooltip
                  formatter={(value: number) => formatXAF(value)}
                  labelStyle={{ color: "#000" }}
                />
                <Bar dataKey="ca" fill="#3b82f6" name="CA" />
                <Bar dataKey="charges" fill="#f59e0b" name="Charges" />
                <Bar dataKey="resultat" fill="#10b981" name="Résultat" />
              </BarChart>
            </ResponsiveContainer>
          )}
        </ModuleCard>
      </div>
    </ModuleShell>
  );
}

function EmptyChart({ message }: { message: string }) {
  return (
    <div className="flex h-[300px] flex-col items-center justify-center gap-3 text-center text-muted-foreground">
      <LayoutDashboard className="h-10 w-10 opacity-30" />
      <p className="max-w-xs text-sm">{message}</p>
    </div>
  );
}
