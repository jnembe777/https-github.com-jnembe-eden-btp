/**
 * Supabase Client Configuration
 * EdenFin JASPE - TypeScript Edition
 */

import { createClient } from "@supabase/supabase-js";

// Environment variables
const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL || "";
const SUPABASE_ANON_KEY =
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY ||
  import.meta.env.VITE_SUPABASE_ANON_KEY ||
  "";

// Validate configuration
if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.warn(
    "[EdenFin] Supabase configuration missing. Please set VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY environment variables."
  );
}

// Create Supabase client
export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true,
  },
  db: {
    schema: "client_demo", // Default schema for EdenFin JASPE
  },
  global: {
    headers: {
      "x-edenfin-version": "2.0.0",
    },
  },
});

// Schema constants
export const SCHEMAS = {
  COMMON: "common",
  SYSTEM: "sys",
  CLIENT: "client_demo",
  ONYX: "onyx",
} as const;

// Table names mapping
export const TABLES = {
  accounts: "chart_of_accounts",
  employees: "employees",
  partners: "partners",
  payroll_rubrics: "payroll_rubrics",
  contribution_rates: "contribution_rates",
  absence_types: "absence_types",
  asset_categories: "asset_categories",
  fixed_assets: "fixed_assets",
  entries: "journal_entries",
  journals: "journals",
  bank_accounts: "bank_accounts",
  bank_transactions: "bank_transactions",
  fiscal_periods: "fiscal_periods",
} as const;

// Error messages in French
export const ERROR_MESSAGES: Record<string, string> = {
  // PostgreSQL error codes
  "23505": "Enregistrement en doublon - cette valeur existe déjà",
  "23503": "Contrainte de clé étrangère - enregistrement lié introuvable",
  "23502": "Champ obligatoire manquant",
  "23514": "Contrainte de vérification non respectée",
  "42501": "Permission refusée - vous n'avez pas les droits nécessaires",
  "42P01": "Table introuvable",
  PGRST116: "Aucun enregistrement trouvé",
  PGRST301: "Trop de résultats - veuillez affiner votre recherche",
  // Generic
  NETWORK_ERROR: "Erreur de connexion - vérifiez votre connexion internet",
  AUTH_ERROR: "Session expirée - veuillez vous reconnecter",
  UNKNOWN: "Une erreur inattendue s'est produite",
};

/**
 * Get a French error message from a Supabase error
 */
export function getErrorMessage(error: any): string {
  if (!error) return ERROR_MESSAGES.UNKNOWN;

  // Check for specific PostgreSQL error codes
  const code = error.code || error.details?.code;
  if (code && ERROR_MESSAGES[code]) {
    return ERROR_MESSAGES[code];
  }

  // Check for network errors
  if (error.message?.includes("fetch") || error.message?.includes("network")) {
    return ERROR_MESSAGES.NETWORK_ERROR;
  }

  // Check for auth errors
  if (error.message?.includes("JWT") || error.message?.includes("auth")) {
    return ERROR_MESSAGES.AUTH_ERROR;
  }

  // Return the original message or unknown
  return error.message || ERROR_MESSAGES.UNKNOWN;
}

/**
 * Check if Supabase is configured
 */
export function isSupabaseConfigured(): boolean {
  return !!(SUPABASE_URL && SUPABASE_ANON_KEY);
}

/**
 * Get Supabase connection status
 */
export async function checkConnection(): Promise<{
  connected: boolean;
  error?: string;
}> {
  if (!isSupabaseConfigured()) {
    return { connected: false, error: "Configuration Supabase manquante" };
  }

  try {
    const { error } = await supabase.from("journals").select("id").limit(1);
    if (error) throw error;
    return { connected: true };
  } catch (error: any) {
    return { connected: false, error: getErrorMessage(error) };
  }
}

export default supabase;
