/**
 * Données mock pour le développement et les tests EdenFin JASPE
 * Données conformes OHADA/CEMAC (Gabon)
 */

export interface KPI {
  label: string;
  value: string | number;
  trend?: number;
  unit?: string;
}

export interface MonthlyData {
  month: string;
  ca: number;
  charges: number;
  resultat: number;
}

export interface ChargesBreakdown {
  label: string;
  value: number;
  color: string;
}

export interface TopClient {
  name: string;
  ca: number;
  pct: number;
}

export interface Alert {
  type: "warning" | "info" | "success";
  message: string;
  date: string;
}

export interface JournalEntry {
  id: string;
  entry_number: string;
  entry_date: string;
  journal_code: string;
  reference?: string;
  description: string;
  total_debit: number;
  total_credit: number;
  status: "DRAFT" | "POSTED" | "VALIDATED" | "CANCELLED";
}

export interface Account {
  id: string;
  account_number: string;
  account_label: string;
  account_type: string;
  class: number;
  is_active: boolean;
}

export interface FiscalPeriod {
  id: string;
  fiscal_year: number;
  period_number: number;
  period_label: string;
  start_date: string;
  end_date: string;
  status: "OPEN" | "CLOSED" | "LOCKED";
}

// KPIs Dashboard
export const MOCK_KPI: KPI[] = [
  { label: "CA mensuel", value: 45200000, trend: 12.5, unit: "XAF" },
  { label: "Résultat net", value: 8400000, trend: 8.2, unit: "XAF" },
  { label: "Trésorerie", value: 32100000, trend: -3.1, unit: "XAF" },
  { label: "Masse salariale", value: 12800000, trend: 2.1, unit: "XAF" },
];

// Évolution CA mensuel
export const MONTHLY_CA: MonthlyData[] = [
  { month: "Janv", ca: 38000000, charges: 28000000, resultat: 10000000 },
  { month: "Févr", ca: 42000000, charges: 30000000, resultat: 12000000 },
  { month: "Mars", ca: 40000000, charges: 29000000, resultat: 11000000 },
  { month: "Avr", ca: 43000000, charges: 31000000, resultat: 12000000 },
  { month: "Mai", ca: 41000000, charges: 30000000, resultat: 11000000 },
  { month: "Juin", ca: 45000000, charges: 32000000, resultat: 13000000 },
  { month: "Juil", ca: 44000000, charges: 31000000, resultat: 13000000 },
  { month: "Août", ca: 39000000, charges: 28000000, resultat: 11000000 },
  { month: "Sept", ca: 46000000, charges: 33000000, resultat: 13000000 },
  { month: "Oct", ca: 48000000, charges: 34000000, resultat: 14000000 },
  { month: "Nov", ca: 47000000, charges: 33000000, resultat: 14000000 },
  { month: "Déc", ca: 45000000, charges: 32000000, resultat: 13000000 },
];

// Répartition des charges
export const REPARTITION_CHARGES: ChargesBreakdown[] = [
  { label: "Achats", value: 12500000, color: "#3b82f6" },
  { label: "Salaires", value: 12800000, color: "#10b981" },
  { label: "Loyers", value: 3200000, color: "#f59e0b" },
  { label: "Autres", value: 3500000, color: "#6366f1" },
];

// Top 5 clients
export const MOCK_TOP_CLIENTS: TopClient[] = [
  { name: "SOBRAGA", ca: 8200000, pct: 18.1 },
  { name: "Total Gabon", ca: 6500000, pct: 14.4 },
  { name: "BGFI Bank", ca: 5800000, pct: 12.8 },
  { name: "Gabon Télécom", ca: 4200000, pct: 9.3 },
  { name: "Airtel Gabon", ca: 3900000, pct: 8.6 },
];

// Alertes
export const MOCK_ALERTS: Alert[] = [
  { type: "warning", message: "3 factures impayées > 30j", date: "2026-02-08" },
  { type: "info", message: "Déclaration TVA à faire avant le 15/02", date: "2026-02-09" },
  { type: "success", message: "Paie de janvier validée", date: "2026-02-05" },
];

// Journal des écritures
export const MOCK_JOURNAL_ENTRIES: JournalEntry[] = [
  {
    id: "1",
    entry_number: "VT-001",
    entry_date: "2026-02-01",
    journal_code: "VT",
    reference: "FAC-2026-0023",
    description: "Vente marchandises - SOBRAGA",
    total_debit: 4720000,
    total_credit: 4720000,
    status: "POSTED",
  },
  {
    id: "2",
    entry_number: "AC-002",
    entry_date: "2026-02-03",
    journal_code: "AC",
    reference: "FACT-SUP-045",
    description: "Achat matières premières",
    total_debit: 3200000,
    total_credit: 3200000,
    status: "POSTED",
  },
  {
    id: "3",
    entry_number: "BQ-003",
    entry_date: "2026-02-05",
    journal_code: "BQ",
    reference: "VIR-001",
    description: "Paiement fournisseur ABC",
    total_debit: 1850000,
    total_credit: 1850000,
    status: "POSTED",
  },
  {
    id: "4",
    entry_number: "OD-004",
    entry_date: "2026-02-06",
    journal_code: "OD",
    reference: undefined,
    description: "Régularisation stocks",
    total_debit: 420000,
    total_credit: 420000,
    status: "DRAFT",
  },
];

// Plan comptable OHADA (extrait)
export const MOCK_COA: Account[] = [
  {
    id: "1",
    account_number: "101000",
    account_label: "Capital social",
    account_type: "CAPITAUX",
    class: 1,
    is_active: true,
  },
  {
    id: "2",
    account_number: "120000",
    account_label: "Résultat de l'exercice",
    account_type: "CAPITAUX",
    class: 1,
    is_active: true,
  },
  {
    id: "3",
    account_number: "164000",
    account_label: "Emprunts bancaires",
    account_type: "DETTES",
    class: 1,
    is_active: true,
  },
  {
    id: "4",
    account_number: "211000",
    account_label: "Terrains",
    account_type: "ACTIF",
    class: 2,
    is_active: true,
  },
  {
    id: "5",
    account_number: "244000",
    account_label: "Matériel informatique",
    account_type: "ACTIF",
    class: 2,
    is_active: true,
  },
  {
    id: "6",
    account_number: "281400",
    account_label: "Amortissements matériel",
    account_type: "ACTIF",
    class: 2,
    is_active: true,
  },
  {
    id: "7",
    account_number: "310000",
    account_label: "Marchandises",
    account_type: "ACTIF",
    class: 3,
    is_active: true,
  },
  {
    id: "8",
    account_number: "411000",
    account_label: "Clients",
    account_type: "ACTIF",
    class: 4,
    is_active: true,
  },
  {
    id: "9",
    account_number: "401000",
    account_label: "Fournisseurs",
    account_type: "PASSIF",
    class: 4,
    is_active: true,
  },
  {
    id: "10",
    account_number: "443100",
    account_label: "TVA collectée",
    account_type: "PASSIF",
    class: 4,
    is_active: true,
  },
  {
    id: "11",
    account_number: "445200",
    account_label: "TVA déductible",
    account_type: "ACTIF",
    class: 4,
    is_active: true,
  },
  {
    id: "12",
    account_number: "512000",
    account_label: "Banque",
    account_type: "ACTIF",
    class: 5,
    is_active: true,
  },
  {
    id: "13",
    account_number: "531000",
    account_label: "Caisse",
    account_type: "ACTIF",
    class: 5,
    is_active: true,
  },
  {
    id: "14",
    account_number: "601000",
    account_label: "Achats de marchandises",
    account_type: "CHARGES",
    class: 6,
    is_active: true,
  },
  {
    id: "15",
    account_number: "661100",
    account_label: "Salaires bruts",
    account_type: "CHARGES",
    class: 6,
    is_active: true,
  },
  {
    id: "16",
    account_number: "663000",
    account_label: "Charges sociales CNSS",
    account_type: "CHARGES",
    class: 6,
    is_active: true,
  },
  {
    id: "17",
    account_number: "681100",
    account_label: "Dotations aux amortissements",
    account_type: "CHARGES",
    class: 6,
    is_active: true,
  },
  {
    id: "18",
    account_number: "701000",
    account_label: "Ventes de marchandises",
    account_type: "PRODUITS",
    class: 7,
    is_active: true,
  },
];

// Périodes fiscales
export const MOCK_FISCAL_PERIODS: FiscalPeriod[] = [
  {
    id: "1",
    fiscal_year: 2026,
    period_number: 1,
    period_label: "Janvier 2026",
    start_date: "2026-01-01",
    end_date: "2026-01-31",
    status: "CLOSED",
  },
  {
    id: "2",
    fiscal_year: 2026,
    period_number: 2,
    period_label: "Février 2026",
    start_date: "2026-02-01",
    end_date: "2026-02-28",
    status: "OPEN",
  },
];
