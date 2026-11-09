import type { ReactNode } from "react";
import { Link } from "@tanstack/react-router";
import { Lock, ArrowUpRight, Gem } from "lucide-react";

import { useGammeTier } from "@/hooks/use-gamme-tier";
import {
  GAMME_META,
  GAMME_TIERS,
  hasTierAccess,
  type GammeTier,
} from "@/lib/gammes";
import { cn } from "@/lib/utils";

/**
 * Garde d'accès par gamme. À utiliser en tête d'une page de module :
 *   const locked = useGammeGate("SAPHIR");
 *   if (locked) return locked;
 * Renvoie null si l'abonnement courant donne accès ; sinon un écran d'upsell.
 */
export function useGammeGate(required: GammeTier): ReactNode | null {
  const { tier } = useGammeTier();
  if (hasTierAccess(tier, required)) return null;

  const meta = GAMME_META[required];
  return (
    <div className="flex min-h-[calc(100vh-3.5rem)] items-center justify-center bg-muted/30 px-4">
      <div className="max-w-md rounded-2xl border border-border bg-card p-8 text-center shadow-sm">
        <span className="mx-auto mb-4 grid h-14 w-14 place-items-center rounded-xl bg-muted text-muted-foreground">
          <Lock className="h-6 w-6" />
        </span>
        <div className="mb-1 inline-flex items-center gap-1.5 text-[11px] uppercase tracking-[0.18em] text-muted-foreground">
          <span className={cn("h-1.5 w-1.5 rounded-full", meta.dot)} />
          Gamme {meta.label} · {meta.cible}
        </div>
        <h1 className="font-display text-xl font-bold text-foreground">
          Module réservé à la gamme {meta.label}
        </h1>
        <p className="mt-2 text-sm text-muted-foreground">
          Ce module n'est pas inclus dans votre abonnement actuel. Passez à la
          gamme {meta.label} pour débloquer la consolidation, les workflows, le
          multi-pays et bien plus.
        </p>
        <Link
          to="/console/abonnement"
          className="mt-6 inline-flex items-center justify-center gap-1.5 rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/90"
        >
          <Gem className="h-4 w-4" />
          Passer à {meta.label}
          <ArrowUpRight className="h-4 w-4" />
        </Link>
      </div>
    </div>
  );
}

/**
 * Sélecteur de tier (DÉMONSTRATION) : simule la gamme souscrite pour visualiser
 * le gating. À remplacer par le tier réel de l'abonnement une fois câblé.
 */
export function TierSwitcher() {
  const { tier, setTier } = useGammeTier();
  return (
    <div className="px-2 pb-1 group-data-[collapsible=icon]:hidden">
      <label className="mb-1 block text-[10px] uppercase tracking-[0.16em] text-sidebar-foreground/55">
        Abonnement (démo)
      </label>
      <select
        value={tier}
        onChange={(e) => setTier(e.target.value as GammeTier)}
        className="h-7 w-full rounded-md border border-sidebar-border/60 bg-sidebar px-2 text-xs text-sidebar-foreground focus:outline-none focus:ring-1 focus:ring-ring"
      >
        {GAMME_TIERS.map((t) => (
          <option key={t} value={t}>
            {GAMME_META[t].label} · {GAMME_META[t].cible}
          </option>
        ))}
      </select>
    </div>
  );
}
