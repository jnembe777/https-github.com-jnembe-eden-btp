/**
 * Hook de données pour les pages de gammes (RUBIS / SAPHIR / ONYX).
 *
 * Branche une page sur Supabase RÉEL tout en restant robuste tant que le schéma
 * des gammes n'est pas déployé sur l'instance : il interroge la table/vue cible
 * (via useSupabaseQuery) et **retombe sur des données de démonstration** si la
 * requête échoue (table absente) ou ne renvoie aucune ligne.
 *
 * Dès que le backend des gammes est déployé et exposé (PostgREST `db-schemas`),
 * les vraies données s'affichent automatiquement, sans changer les composants.
 */

import { useSupabaseQuery, type QueryOptions, type UseSupabaseTableOptions } from "./use-supabase";

export interface GammeDataResult<T> {
  /** Données réelles si disponibles, sinon le jeu de démonstration. */
  data: T[];
  /** true quand on affiche les données de démonstration (pas de données réelles). */
  isDemo: boolean;
  /** true pendant la première requête. */
  isLoading: boolean;
}

export function useGammeData<T = unknown>(
  table: string,
  mock: T[],
  options: QueryOptions & UseSupabaseTableOptions = {},
): GammeDataResult<T> {
  // softDelete désactivé par défaut : les tables/vues de gammes n'ont pas
  // toutes une colonne deleted_at.
  const query = useSupabaseQuery<T>(table, { softDelete: false, ...options });

  const hasReal =
    !query.isError && Array.isArray(query.data) && query.data.length > 0;

  return {
    data: hasReal ? (query.data as T[]) : mock,
    isDemo: !hasReal,
    isLoading: query.isLoading,
  };
}
