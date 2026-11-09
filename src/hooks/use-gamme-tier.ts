/**
 * Tier d'abonnement actif (gamme souscrite).
 *
 * Source réelle : le tier du tenant (sys.tenants.tier) / l'abonnement. Tant que
 * ce n'est pas câblé côté backend, un **sélecteur de démonstration** permet de
 * simuler le tier (persisté en localStorage) afin de visualiser le gating.
 *
 * `setGammeTier` est partagé : la sidebar et les gardes de page se mettent à
 * jour en même temps (useSyncExternalStore).
 */

import { useSyncExternalStore } from "react";
import { GAMME_TIERS, type GammeTier } from "@/lib/gammes";

const STORAGE_KEY = "edenfin_demo_tier";
const DEFAULT_TIER: GammeTier = "RUBIS";

function readStored(): GammeTier {
  try {
    const v = localStorage.getItem(STORAGE_KEY);
    if (v && (GAMME_TIERS as readonly string[]).includes(v)) return v as GammeTier;
  } catch {
    /* localStorage indisponible */
  }
  return DEFAULT_TIER;
}

let currentTier: GammeTier =
  typeof window !== "undefined" ? readStored() : DEFAULT_TIER;

const listeners = new Set<() => void>();

export function setGammeTier(tier: GammeTier): void {
  currentTier = tier;
  try {
    localStorage.setItem(STORAGE_KEY, tier);
  } catch {
    /* ignore */
  }
  listeners.forEach((l) => l());
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export interface GammeTierState {
  tier: GammeTier;
  setTier: (t: GammeTier) => void;
  /** true : tier simulé (démo), pas encore lu depuis l'abonnement réel. */
  isDemo: boolean;
}

export function useGammeTier(): GammeTierState {
  const tier = useSyncExternalStore(
    subscribe,
    () => currentTier,
    () => DEFAULT_TIER,
  );
  return { tier, setTier: setGammeTier, isDemo: true };
}
