/**
 * Données de démonstration pour les frontends des gammes supérieures
 * (RUBIS / SAPHIR / ONYX). Les valeurs reflètent le backend intégré
 * (schémas sys / onyx) : ventilation analytique, parité EUR/XAF, référentiel
 * multi-pays CEMAC/OHADA. Elles servent de repli tant que le backend n'est pas
 * déployé sur Supabase ; les pages basculeront sur les hooks useSupabase* /
 * useSupabaseRPC sans changer de structure.
 */

// ─────────────────────────── RUBIS (PME) — Analytique ───────────────────────

export interface AnalyticalAxis {
  id: number;
  axis_code: string;
  axis_name: string;
  axis_type: string;
  values_count: number;
  is_active: boolean;
}

export interface DistributionTemplate {
  id: number;
  template_code: string;
  template_name: string;
  axis_code: string;
  lines_count: number;
  total_percentage: number;
  is_valid: boolean;
}

export const MOCK_ANALYTICAL_AXES: AnalyticalAxis[] = [
  { id: 1, axis_code: "CC", axis_name: "Centres de coût", axis_type: "COST_CENTER", values_count: 8, is_active: true },
  { id: 2, axis_code: "PROJ", axis_name: "Projets", axis_type: "PROJECT", values_count: 14, is_active: true },
  { id: 3, axis_code: "DEPT", axis_name: "Départements", axis_type: "DEPARTMENT", values_count: 5, is_active: true },
  { id: 4, axis_code: "PROD", axis_name: "Lignes de produits", axis_type: "PRODUCT", values_count: 11, is_active: true },
  { id: 5, axis_code: "ZONE", axis_name: "Zones géographiques", axis_type: "GEOGRAPHY", values_count: 4, is_active: false },
];

export const MOCK_DISTRIBUTION_TEMPLATES: DistributionTemplate[] = [
  { id: 1, template_code: "TPL_ADMIN", template_name: "Frais administratifs 60/40", axis_code: "CC", lines_count: 2, total_percentage: 100, is_valid: true },
  { id: 2, template_code: "TPL_RH", template_name: "Charges RH par département", axis_code: "DEPT", lines_count: 5, total_percentage: 100, is_valid: true },
  { id: 3, template_code: "TPL_ENERGIE", template_name: "Énergie par centre", axis_code: "CC", lines_count: 4, total_percentage: 100, is_valid: true },
  { id: 4, template_code: "TPL_MKT", template_name: "Marketing par produit", axis_code: "PROD", lines_count: 6, total_percentage: 85, is_valid: false },
  { id: 5, template_code: "TPL_LOGISTIQUE", template_name: "Logistique par zone", axis_code: "ZONE", lines_count: 3, total_percentage: 100, is_valid: true },
  { id: 6, template_code: "TPL_IT", template_name: "SI par projet", axis_code: "PROJ", lines_count: 7, total_percentage: 70, is_valid: false },
];

// ─────────────────────────── SAPHIR (ETI) — Multi-devises ────────────────────

export interface ExchangeRate {
  id: number;
  from_currency: string;
  to_currency: string;
  rate: number;
  rate_type: string;
  rate_date: string;
}

export const MOCK_EXCHANGE_RATES: ExchangeRate[] = [
  { id: 1, from_currency: "EUR", to_currency: "XAF", rate: 655.957, rate_type: "SPOT", rate_date: "2026-11-01" },
  { id: 2, from_currency: "USD", to_currency: "XAF", rate: 603.412, rate_type: "SPOT", rate_date: "2026-11-01" },
  { id: 3, from_currency: "GBP", to_currency: "XAF", rate: 765.204, rate_type: "SPOT", rate_date: "2026-11-01" },
  { id: 4, from_currency: "CNY", to_currency: "XAF", rate: 84.118, rate_type: "SPOT", rate_date: "2026-11-01" },
  { id: 5, from_currency: "EUR", to_currency: "USD", rate: 1.0871, rate_type: "SPOT", rate_date: "2026-11-01" },
  { id: 6, from_currency: "EUR", to_currency: "XAF", rate: 655.957, rate_type: "CLOSING", rate_date: "2026-10-31" },
  { id: 7, from_currency: "ZAR", to_currency: "XAF", rate: 33.642, rate_type: "SPOT", rate_date: "2026-11-01" },
  { id: 8, from_currency: "NGN", to_currency: "XAF", rate: 0.389, rate_type: "SPOT", rate_date: "2026-11-01" },
];

// ─────────────────────────── ONYX (GE/public) — Multi-pays ───────────────────

export interface CountryConfig {
  country_code: string;
  country_name: string;
  currency_code: string;
  economic_zone: string;
  primary_gaap: string;
  vat_standard_rate: number;
  corporate_tax_rate: number;
}

export const MOCK_COUNTRIES: CountryConfig[] = [
  { country_code: "GA", country_name: "Gabon", currency_code: "XAF", economic_zone: "CEMAC", primary_gaap: "OHADA", vat_standard_rate: 18.0, corporate_tax_rate: 30.0 },
  { country_code: "CM", country_name: "Cameroun", currency_code: "XAF", economic_zone: "CEMAC", primary_gaap: "OHADA", vat_standard_rate: 19.25, corporate_tax_rate: 33.0 },
  { country_code: "CF", country_name: "Centrafrique", currency_code: "XAF", economic_zone: "CEMAC", primary_gaap: "OHADA", vat_standard_rate: 19.0, corporate_tax_rate: 30.0 },
  { country_code: "TD", country_name: "Tchad", currency_code: "XAF", economic_zone: "CEMAC", primary_gaap: "OHADA", vat_standard_rate: 18.0, corporate_tax_rate: 35.0 },
  { country_code: "CG", country_name: "Congo", currency_code: "XAF", economic_zone: "CEMAC", primary_gaap: "OHADA", vat_standard_rate: 18.0, corporate_tax_rate: 30.0 },
  { country_code: "GQ", country_name: "Guinée Équatoriale", currency_code: "XAF", economic_zone: "CEMAC", primary_gaap: "OHADA", vat_standard_rate: 15.0, corporate_tax_rate: 35.0 },
  { country_code: "CI", country_name: "Côte d'Ivoire", currency_code: "XOF", economic_zone: "UEMOA", primary_gaap: "OHADA", vat_standard_rate: 18.0, corporate_tax_rate: 25.0 },
  { country_code: "SN", country_name: "Sénégal", currency_code: "XOF", economic_zone: "UEMOA", primary_gaap: "OHADA", vat_standard_rate: 18.0, corporate_tax_rate: 30.0 },
  { country_code: "CD", country_name: "RD Congo", currency_code: "CDF", economic_zone: "OHADA", primary_gaap: "OHADA", vat_standard_rate: 16.0, corporate_tax_rate: 30.0 },
  { country_code: "FR", country_name: "France", currency_code: "EUR", economic_zone: "EU", primary_gaap: "IFRS", vat_standard_rate: 20.0, corporate_tax_rate: 25.0 },
  { country_code: "NG", country_name: "Nigeria", currency_code: "NGN", economic_zone: "ECOWAS", primary_gaap: "IFRS", vat_standard_rate: 7.5, corporate_tax_rate: 30.0 },
  { country_code: "ZA", country_name: "Afrique du Sud", currency_code: "ZAR", economic_zone: "SADC", primary_gaap: "IFRS", vat_standard_rate: 15.0, corporate_tax_rate: 27.0 },
];

// ═══════════════════════ RUBIS — Multi-sociétés & Facturation ════════════════

export interface Entity {
  id: number;
  entity_code: string;
  entity_name: string;
  country_code: string;
  currency_code: string;
  is_consolidation_parent: boolean;
  ownership_percentage: number;
  consolidation_method: string;
}

export const MOCK_ENTITIES: Entity[] = [
  { id: 1, entity_code: "HOLD", entity_name: "Groupe Mbolo Holding", country_code: "GA", currency_code: "XAF", is_consolidation_parent: true, ownership_percentage: 100, consolidation_method: "PARENT" },
  { id: 2, entity_code: "GA-IND", entity_name: "Mbolo Industries SA", country_code: "GA", currency_code: "XAF", is_consolidation_parent: false, ownership_percentage: 100, consolidation_method: "FULL" },
  { id: 3, entity_code: "GA-SERV", entity_name: "Mbolo Services SARL", country_code: "GA", currency_code: "XAF", is_consolidation_parent: false, ownership_percentage: 75, consolidation_method: "FULL" },
  { id: 4, entity_code: "CM-DIST", entity_name: "Mbolo Distribution Cameroun", country_code: "CM", currency_code: "XAF", is_consolidation_parent: false, ownership_percentage: 60, consolidation_method: "FULL" },
  { id: 5, entity_code: "CI-NEG", entity_name: "Mbolo Négoce Abidjan", country_code: "CI", currency_code: "XOF", is_consolidation_parent: false, ownership_percentage: 40, consolidation_method: "EQUITY" },
];

export interface Invoice {
  id: number;
  invoice_number: string;
  partner_name: string;
  invoice_date: string;
  amount_ht: number;
  amount_ttc: number;
  status: string;
  paid: boolean;
}

export const MOCK_INVOICES: Invoice[] = [
  { id: 1, invoice_number: "FAC-2026-0141", partner_name: "SEEG", invoice_date: "2026-10-28", amount_ht: 12500000, amount_ttc: 14750000, status: "VALIDATED", paid: true },
  { id: 2, invoice_number: "FAC-2026-0142", partner_name: "Total Energies Gabon", invoice_date: "2026-10-30", amount_ht: 8200000, amount_ttc: 9676000, status: "VALIDATED", paid: false },
  { id: 3, invoice_number: "FAC-2026-0143", partner_name: "BGFI Bank", invoice_date: "2026-11-02", amount_ht: 3400000, amount_ttc: 4012000, status: "VALIDATED", paid: false },
  { id: 4, invoice_number: "FAC-2026-0144", partner_name: "Airtel Gabon", invoice_date: "2026-11-04", amount_ht: 5600000, amount_ttc: 6608000, status: "DRAFT", paid: false },
  { id: 5, invoice_number: "FAC-2026-0138", partner_name: "CNSS", invoice_date: "2026-09-15", amount_ht: 9900000, amount_ttc: 11682000, status: "VALIDATED", paid: false },
];

// ═══════════════════════ SAPHIR — Consolidation & Workflow ═══════════════════

export interface ConsolidationLine {
  id: number;
  entity_name: string;
  method: string;
  ownership_percentage: number;
  contribution_result: number;
  currency_code: string;
}

export const MOCK_CONSOLIDATION: ConsolidationLine[] = [
  { id: 1, entity_name: "Mbolo Industries SA", method: "FULL", ownership_percentage: 100, contribution_result: 1840000000, currency_code: "XAF" },
  { id: 2, entity_name: "Mbolo Services SARL", method: "FULL", ownership_percentage: 75, contribution_result: 420000000, currency_code: "XAF" },
  { id: 3, entity_name: "Mbolo Distribution Cameroun", method: "FULL", ownership_percentage: 60, contribution_result: 312000000, currency_code: "XAF" },
  { id: 4, entity_name: "Mbolo Négoce Abidjan", method: "EQUITY", ownership_percentage: 40, contribution_result: 88000000, currency_code: "XOF" },
];

export interface Approval {
  id: number;
  document: string;
  amount: number;
  current_step: string;
  requester: string;
  status: string;
  due_in_days: number;
}

export const MOCK_APPROVALS: Approval[] = [
  { id: 1, document: "Commande fournisseur CF-2026-0912", amount: 45000000, current_step: "Direction financière", requester: "A. Nguema", status: "PENDING", due_in_days: 2 },
  { id: 2, document: "Paiement fournisseur PF-2026-0455", amount: 18500000, current_step: "Trésorier", requester: "M. Ondo", status: "PENDING", due_in_days: -1 },
  { id: 3, document: "Budget révisé Q4 Industries", amount: 0, current_step: "Contrôle de gestion", requester: "S. Mba", status: "PENDING", due_in_days: 5 },
  { id: 4, document: "Écriture OD-2026-0231", amount: 9200000, current_step: "Chef comptable", requester: "J. Koumba", status: "APPROVED", due_in_days: 0 },
  { id: 5, document: "Immobilisation IMMO-2026-044", amount: 32000000, current_step: "Directeur général", requester: "P. Boussougou", status: "PENDING", due_in_days: 3 },
];

// ═══════════════════════ ONYX — Trésorerie & Secteur public ══════════════════

export interface CashPosition {
  id: number;
  entity_name: string;
  bank: string;
  country_code: string;
  currency_code: string;
  balance: number;
}

export const MOCK_CASH_POSITIONS: CashPosition[] = [
  { id: 1, entity_name: "Mbolo Industries SA", bank: "BGFI Bank", country_code: "GA", currency_code: "XAF", balance: 1240000000 },
  { id: 2, entity_name: "Mbolo Services SARL", bank: "Ecobank", country_code: "GA", currency_code: "XAF", balance: 318000000 },
  { id: 3, entity_name: "Mbolo Distribution Cameroun", bank: "Afriland First Bank", country_code: "CM", currency_code: "XAF", balance: 512000000 },
  { id: 4, entity_name: "Mbolo Négoce Abidjan", bank: "SGBCI", country_code: "CI", currency_code: "XOF", balance: 205000000 },
  { id: 5, entity_name: "Mbolo Trading DRC", bank: "Rawbank", country_code: "CD", currency_code: "CDF", balance: 980000000 },
];

export interface Appropriation {
  id: number;
  appropriation_code: string;
  appropriation_name: string;
  original_amount: number;
  committed: number;
  available: number;
}

export const MOCK_APPROPRIATIONS: Appropriation[] = [
  { id: 1, appropriation_code: "CH-61", appropriation_name: "Transports et déplacements", original_amount: 800000000, committed: 540000000, available: 260000000 },
  { id: 2, appropriation_code: "CH-62", appropriation_name: "Services extérieurs", original_amount: 1500000000, committed: 1320000000, available: 180000000 },
  { id: 3, appropriation_code: "IN-21", appropriation_name: "Investissements — Équipements", original_amount: 3200000000, committed: 2100000000, available: 1100000000 },
  { id: 4, appropriation_code: "SU-65", appropriation_name: "Subventions versées", original_amount: 2000000000, committed: 2000000000, available: 0 },
  { id: 5, appropriation_code: "PE-60", appropriation_name: "Achats de biens", original_amount: 950000000, committed: 610000000, available: 340000000 },
];
