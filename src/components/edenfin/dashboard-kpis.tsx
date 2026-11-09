/**
 * Composants Dashboard pour EdenFin
 * KPIs, cartes de statistiques et graphiques
 */

import { TrendingUp, TrendingDown } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { cn } from "@/lib/utils";

export interface KpiCardProps {
  label: string;
  value: string | number;
  trend?: number;
  unit?: string;
  tone?: "success" | "warning" | "info" | "default";
  hint?: string;
  delta?: string;
  icon?: React.ReactNode;
}

/**
 * Carte KPI individuelle
 */
export function KpiCard({
  label,
  value,
  trend,
  unit,
  tone = "default",
  hint,
  delta,
  icon,
}: KpiCardProps) {
  const trendPositive = trend !== undefined && trend > 0;
  const trendNegative = trend !== undefined && trend < 0;

  const toneClasses = {
    success: "border-green-500/50 bg-green-50/50 dark:bg-green-950/20",
    warning: "border-yellow-500/50 bg-yellow-50/50 dark:bg-yellow-950/20",
    info: "border-blue-500/50 bg-blue-50/50 dark:bg-blue-950/20",
    default: "",
  };

  return (
    <Card className={cn("transition-all hover:shadow-md", toneClasses[tone])}>
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-sm font-medium text-muted-foreground">
          {label}
        </CardTitle>
        {icon && <div className="text-muted-foreground">{icon}</div>}
      </CardHeader>
      <CardContent>
        <div className="text-2xl font-bold">
          {typeof value === "number"
            ? new Intl.NumberFormat("fr-FR").format(value)
            : value}
          {unit && <span className="ml-1 text-sm font-normal">{unit}</span>}
        </div>

        {(trend !== undefined || delta || hint) && (
          <div className="mt-1 flex items-center gap-2 text-xs text-muted-foreground">
            {trend !== undefined && (
              <span
                className={cn(
                  "flex items-center gap-0.5 font-medium",
                  trendPositive && "text-green-600 dark:text-green-400",
                  trendNegative && "text-red-600 dark:text-red-400"
                )}
              >
                {trendPositive && <TrendingUp className="h-3 w-3" />}
                {trendNegative && <TrendingDown className="h-3 w-3" />}
                {Math.abs(trend)}%
              </span>
            )}
            {delta && <span>{delta}</span>}
            {hint && <span>{hint}</span>}
          </div>
        )}
      </CardContent>
    </Card>
  );
}

/**
 * Grille de KPIs (2 ou 4 colonnes)
 */
export function KpiGrid({ children }: { children: React.ReactNode }) {
  return (
    <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">{children}</div>
  );
}

/**
 * Carte module/section
 */
export interface ModuleCardProps {
  title: string;
  description?: string;
  action?: React.ReactNode;
  children: React.ReactNode;
}

export function ModuleCard({
  title,
  description,
  action,
  children,
}: ModuleCardProps) {
  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between">
          <div>
            <CardTitle>{title}</CardTitle>
            {description && (
              <p className="mt-1 text-sm text-muted-foreground">
                {description}
              </p>
            )}
          </div>
          {action && <div>{action}</div>}
        </div>
      </CardHeader>
      <CardContent>{children}</CardContent>
    </Card>
  );
}

/**
 * Badge de statut coloré
 */
export interface StatusBadgeProps {
  children: React.ReactNode;
  tone?: "success" | "warning" | "info" | "default";
}

export function StatusBadge({ children, tone = "default" }: StatusBadgeProps) {
  const toneClasses = {
    success:
      "bg-green-100 text-green-700 dark:bg-green-950 dark:text-green-300",
    warning:
      "bg-yellow-100 text-yellow-700 dark:bg-yellow-950 dark:text-yellow-300",
    info: "bg-blue-100 text-blue-700 dark:bg-blue-950 dark:text-blue-300",
    default: "bg-muted text-muted-foreground",
  };

  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium",
        toneClasses[tone]
      )}
    >
      {children}
    </span>
  );
}
