import { Link } from "@tanstack/react-router";
import { ArrowRight, Gem } from "lucide-react";
import { cn } from "@/lib/utils";

export interface GammeCardProps {
  code: "JASPE" | "RUBIS" | "SAPHIR" | "ONYX";
  tagline: string;
  cible: string;
  highlights: string[];
  status: "live" | "soon";
  to?: string;
  accent?: "emerald" | "ruby" | "sapphire" | "onyx";
}

const accents = {
  emerald: { chip: "bg-primary/12 text-primary border-primary/30", dot: "bg-primary" },
  ruby: { chip: "bg-destructive/10 text-destructive border-destructive/30", dot: "bg-destructive" },
  sapphire: { chip: "bg-chart-4/15 text-chart-4 border-chart-4/30", dot: "bg-chart-4" },
  onyx: { chip: "bg-foreground/10 text-foreground border-foreground/30", dot: "bg-foreground" },
} as const;

export function GammeCard({
  code,
  tagline,
  cible,
  highlights,
  status,
  to,
  accent = "emerald",
}: GammeCardProps) {
  const isLive = status === "live";
  const a = accents[accent];

  return (
    <article
      className={cn(
        "group relative flex flex-col overflow-hidden rounded-2xl border bg-card p-7 transition-all",
        isLive
          ? "border-primary/25 shadow-prestige hover:-translate-y-1"
          : "border-border opacity-90 hover:opacity-100",
      )}
    >
      <div className="flex items-start justify-between">
        <div className="flex items-center gap-3">
          <span className={cn("grid h-11 w-11 place-items-center rounded-xl border", a.chip)}>
            <Gem className="h-5 w-5" />
          </span>
          <div>
            <h3 className="font-display text-2xl font-bold tracking-tight">{code}</h3>
            <p className="text-xs uppercase tracking-[0.16em] text-muted-foreground">{cible}</p>
          </div>
        </div>

        <span
          className={cn(
            "flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[10px] font-semibold uppercase tracking-wider",
            isLive
              ? "border-success/40 bg-success/10 text-success"
              : "border-gold/40 bg-gold/10 text-foreground/70",
          )}
        >
          <span className={cn("h-1.5 w-1.5 rounded-full", isLive ? "bg-success" : "bg-gold")} />
          {isLive ? "Disponible" : "À venir"}
        </span>
      </div>

      <p className="mt-5 text-balance text-base text-foreground/85">{tagline}</p>

      <ul className="mt-5 space-y-2">
        {highlights.map((h) => (
          <li key={h} className="flex items-start gap-2 text-sm text-muted-foreground">
            <span className={cn("mt-1.5 h-1 w-1 shrink-0 rounded-full", a.dot)} />
            <span>{h}</span>
          </li>
        ))}
      </ul>

      <div className="mt-7 flex items-center justify-between border-t border-border/60 pt-5">
        {isLive && to ? (
          <Link
            to={to}
            className="inline-flex items-center gap-1.5 text-sm font-semibold text-primary transition-colors hover:text-primary-glow"
          >
            Explorer la gamme
            <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-0.5" />
          </Link>
        ) : (
          <span className="text-sm text-muted-foreground">Roadmap 2026</span>
        )}
      </div>
    </article>
  );
}
