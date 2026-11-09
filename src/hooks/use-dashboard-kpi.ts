/**
 * Hook Dashboard KPI — EdenFin JASPE
 * Appelle rpc_dashboard_kpi (T17) via useQuery (lecture automatique au montage).
 * Niveau D (Décisionnel) — STANDARD-UI-TPD §1.
 */

import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/lib/supabase";

export interface DashboardKpi {
  ca: number;
  charges: number;
  resultat: number;
  tresorerie: number;
  dso: number;
  marge_pct: number;
}

export interface MonthlySummaryRow {
  month: number;
  ca: number;
  charges: number;
  resultat: number;
}

export interface DashboardKpiResult {
  kpi: DashboardKpi;
  monthly: MonthlySummaryRow[];
}

export function useDashboardKpi(fiscalYear: number) {
  return useQuery<DashboardKpiResult | null>({
    queryKey: ["rpc_dashboard_kpi", fiscalYear],
    queryFn: async () => {
      const { data, error } = await supabase.rpc("rpc_dashboard_kpi", {
        p_fiscal_year: fiscalYear,
      });

      if (error) throw new Error(error.message);
      if (!data?.success) return null;

      const monthly: MonthlySummaryRow[] = (data.monthly ?? []).map(
        (m: { month: number; ca: unknown; charges: unknown }) => {
          const ca = Number(m.ca) || 0;
          const charges = Number(m.charges) || 0;
          return { month: m.month, ca, charges, resultat: ca - charges };
        }
      );

      return {
        kpi: {
          ca: Number(data.kpi.ca) || 0,
          charges: Number(data.kpi.charges) || 0,
          resultat: Number(data.kpi.resultat) || 0,
          tresorerie: Number(data.kpi.tresorerie) || 0,
          dso: Number(data.kpi.dso) || 0,
          marge_pct: Number(data.kpi.marge_pct) || 0,
        },
        monthly,
      };
    },
  });
}
