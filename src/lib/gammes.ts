/**
 * Gammes EdenFin et gating par abonnement.
 *
 * Les gammes sont CUMULATIVES : un abonnement à une gamme donne accès à ses
 * modules et à ceux des gammes inférieures.
 *   JASPE (TPE) ⊂ RUBIS (PME) ⊂ SAPHIR (ETI) ⊂ ONYX (GE / Public)
 */

export const GAMME_TIERS = ["JASPE", "RUBIS", "SAPHIR", "ONYX"] as const;
export type GammeTier = (typeof GAMME_TIERS)[number];

export const GAMME_META: Record<
  GammeTier,
  { label: string; cible: string; dot: string }
> = {
  JASPE: { label: "JASPE", cible: "TPE", dot: "bg-primary" },
  RUBIS: { label: "RUBIS", cible: "PME", dot: "bg-destructive" },
  SAPHIR: { label: "SAPHIR", cible: "ETI", dot: "bg-chart-4" },
  ONYX: { label: "ONYX", cible: "GE / Public", dot: "bg-foreground" },
};

export function tierRank(t: GammeTier): number {
  return GAMME_TIERS.indexOf(t);
}

/** true si le tier souscrit `current` donne accès à un module de tier `required`. */
export function hasTierAccess(current: GammeTier, required: GammeTier): boolean {
  return tierRank(current) >= tierRank(required);
}

/** Déduit la gamme d'une route de module de la console. */
export function moduleTier(url: string): GammeTier {
  if (url.startsWith("/console/rubis-")) return "RUBIS";
  if (url.startsWith("/console/saphir-")) return "SAPHIR";
  if (url.startsWith("/console/onyx-")) return "ONYX";
  return "JASPE";
}
