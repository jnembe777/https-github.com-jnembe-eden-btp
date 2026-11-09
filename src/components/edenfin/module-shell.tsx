import type { ReactNode } from "react";
import { Link } from "@tanstack/react-router";
import { ChevronRight } from "lucide-react";

import { cn } from "@/lib/utils";

export interface ModuleShellProps {
  icon: ReactNode;
  title: string;
  subtitle?: string;
  actions?: ReactNode;
  tabs?: Array<{ key: string; label: string; active?: boolean; href?: string }>;
  children: ReactNode;
}

export function ModuleShell({
  icon,
  title,
  subtitle,
  actions,
  tabs,
  children,
}: ModuleShellProps) {
  return (
    <div className="flex min-h-[calc(100vh-3.5rem)] flex-col bg-muted/30">
      <header className="border-b border-border bg-card">
        <div className="px-6 pt-5">
          <nav className="flex items-center gap-1.5 text-[11px] uppercase tracking-[0.18em] text-muted-foreground">
            <Link to="/console" className="hover:text-foreground">
              Console
            </Link>
            <ChevronRight className="h-3 w-3" />
            <span className="text-foreground">{title}</span>
          </nav>

          <div className="mt-3 flex flex-wrap items-start justify-between gap-4">
            <div className="flex items-start gap-3">
              <span className="grid h-11 w-11 shrink-0 place-items-center rounded-lg bg-primary/10 text-primary">
                {icon}
              </span>
              <div>
                <h1 className="font-display text-2xl font-bold leading-tight text-foreground">
                  {title}
                </h1>
                {subtitle ? (
                  <p className="mt-1 max-w-2xl text-sm text-muted-foreground">{subtitle}</p>
                ) : null}
              </div>
            </div>
            {actions ? <div className="flex flex-wrap items-center gap-2">{actions}</div> : null}
          </div>
        </div>

        {tabs?.length ? (
          <div className="mt-4 flex gap-1 overflow-x-auto px-6">
            {tabs.map((t) => (
              <button
                key={t.key}
                type="button"
                className={cn(
                  "relative whitespace-nowrap px-3 pb-2.5 pt-1 text-sm transition-colors",
                  t.active
                    ? "text-foreground"
                    : "text-muted-foreground hover:text-foreground",
                )}
              >
                {t.label}
                {t.active ? (
                  <span className="absolute inset-x-2 -bottom-px h-0.5 rounded-full bg-primary" />
                ) : null}
              </button>
            ))}
          </div>
        ) : null}
      </header>

      <div className="flex-1 px-6 py-6">{children}</div>
    </div>
  );
}

export interface KpiCardProps {
  label: string;
  value: string;
  delta?: string;
  tone?: "default" | "success" | "warning" | "danger";
  hint?: string;
}

const toneClass: Record<NonNullable<KpiCardProps["tone"]>, string> = {
  default: "text-muted-foreground",
  success: "text-success",
  warning: "text-warning",
  danger: "text-destructive",
};

export function KpiCard({ label, value, delta, tone = "default", hint }: KpiCardProps) {
  return (
    <div className="rounded-xl border border-border bg-card p-4 shadow-sm">
      <div className="text-[11px] uppercase tracking-[0.16em] text-muted-foreground">{label}</div>
      <div className="mt-2 font-display text-2xl font-bold text-foreground">{value}</div>
      {delta ? <div className={cn("mt-1 text-xs font-medium", toneClass[tone])}>{delta}</div> : null}
      {hint ? <div className="mt-1 text-[11px] text-muted-foreground">{hint}</div> : null}
    </div>
  );
}

export function KpiGrid({ children }: { children: ReactNode }) {
  return <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">{children}</div>;
}

export function ModuleCard({
  title,
  description,
  action,
  children,
}: {
  title: string;
  description?: string;
  action?: ReactNode;
  children: ReactNode;
}) {
  return (
    <section className="rounded-xl border border-border bg-card shadow-sm">
      <header className="flex flex-wrap items-start justify-between gap-3 border-b border-border px-5 py-3.5">
        <div>
          <h2 className="font-display text-base font-bold text-foreground">{title}</h2>
          {description ? (
            <p className="mt-0.5 text-xs text-muted-foreground">{description}</p>
          ) : null}
        </div>
        {action}
      </header>
      <div className="p-5">{children}</div>
    </section>
  );
}

export function StatusBadge({
  children,
  tone = "default",
}: {
  children: ReactNode;
  tone?: "default" | "success" | "warning" | "danger" | "info";
}) {
  const tones: Record<string, string> = {
    default: "bg-muted text-muted-foreground",
    success: "bg-success/15 text-success",
    warning: "bg-warning/15 text-warning",
    danger: "bg-destructive/15 text-destructive",
    info: "bg-primary/10 text-primary",
  };
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-2 py-0.5 text-[11px] font-medium",
        tones[tone],
      )}
    >
      {children}
    </span>
  );
}
