-- ============================================================================
-- EDENFIN JASPE — SCRIPT 02 : RÉFÉRENTIELS COMMUNS (schéma common)
-- À exécuter APRÈS le script 01
-- Source consolidée : 01_schema_common.sql
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS common;

-- ────────────────────────────────────────────────────────────────────────────
-- 1. PLANS COMPTABLES (templates partagés)
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE common.chart_of_accounts_templates (
  id BIGSERIAL PRIMARY KEY,
  code VARCHAR(20) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  country_code VARCHAR(3),
  type VARCHAR(50) NOT NULL CHECK (type IN ('LOCAL_GAAP', 'IFRS', 'US_GAAP', 'PUBLIC')),
  version VARCHAR(50),
  effective_date DATE NOT NULL,
  end_date DATE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  deleted_at TIMESTAMPTZ,
  deleted_by BIGINT,
  version_number INT NOT NULL DEFAULT 1
);

CREATE INDEX idx_coa_templates_code ON common.chart_of_accounts_templates(code) WHERE deleted_at IS NULL;
CREATE INDEX idx_coa_templates_type ON common.chart_of_accounts_templates(type, is_active);
CREATE INDEX idx_coa_templates_country ON common.chart_of_accounts_templates(country_code);
COMMENT ON TABLE common.chart_of_accounts_templates IS 'Templates de plans comptables (OHADA, IFRS, PCG, etc.)';

CREATE TABLE common.chart_of_accounts_details (
  id BIGSERIAL PRIMARY KEY,
  chart_template_id BIGINT NOT NULL REFERENCES common.chart_of_accounts_templates(id),
  account_number VARCHAR(20) NOT NULL,
  account_label VARCHAR(500) NOT NULL,
  account_type VARCHAR(50) NOT NULL CHECK (account_type IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE')),
  parent_account_number VARCHAR(20),
  level INT NOT NULL CHECK (level > 0),
  is_detail_account BOOLEAN NOT NULL DEFAULT TRUE,
  normal_balance VARCHAR(10) NOT NULL CHECK (normal_balance IN ('DEBIT', 'CREDIT')),
  financial_statement VARCHAR(50) CHECK (financial_statement IN ('BALANCE_SHEET', 'INCOME_STATEMENT', 'CASH_FLOW')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  deleted_at TIMESTAMPTZ,
  deleted_by BIGINT,
  version_number INT NOT NULL DEFAULT 1,
  UNIQUE(chart_template_id, account_number)
);

CREATE INDEX idx_coa_details_template ON common.chart_of_accounts_details(chart_template_id);
CREATE INDEX idx_coa_details_number ON common.chart_of_accounts_details(account_number);
CREATE INDEX idx_coa_details_type ON common.chart_of_accounts_details(account_type);
COMMENT ON TABLE common.chart_of_accounts_details IS 'Comptes du plan comptable par template';

-- ────────────────────────────────────────────────────────────────────────────
-- 2. RÉFÉRENTIELS GÉOGRAPHIQUES
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE common.countries (
  id BIGSERIAL PRIMARY KEY,
  code_iso2 CHAR(2) NOT NULL UNIQUE,
  code_iso3 CHAR(3) NOT NULL UNIQUE,
  name_fr VARCHAR(200) NOT NULL,
  name_en VARCHAR(200) NOT NULL,
  phone_prefix VARCHAR(10),
  region VARCHAR(50) CHECK (region IN ('EUROPE', 'AFRICA', 'ASIA', 'AMERICAS', 'OCEANIA')),
  currency_code CHAR(3),
  is_eu_member BOOLEAN NOT NULL DEFAULT FALSE,
  tax_system VARCHAR(100),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  deleted_at TIMESTAMPTZ,
  deleted_by BIGINT,
  version_number INT NOT NULL DEFAULT 1
);

CREATE INDEX idx_countries_region ON common.countries(region);
CREATE INDEX idx_countries_currency ON common.countries(currency_code);
COMMENT ON TABLE common.countries IS 'Référentiel des pays (ISO 3166)';

CREATE TABLE common.currencies (
  id BIGSERIAL PRIMARY KEY,
  code CHAR(3) NOT NULL UNIQUE,
  name_fr VARCHAR(100) NOT NULL,
  name_en VARCHAR(100) NOT NULL,
  symbol VARCHAR(10),
  decimal_places INT NOT NULL DEFAULT 2,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  deleted_at TIMESTAMPTZ,
  deleted_by BIGINT,
  version_number INT NOT NULL DEFAULT 1
);

CREATE INDEX idx_currencies_active ON common.currencies(is_active);
COMMENT ON TABLE common.currencies IS 'Référentiel des devises (ISO 4217)';

CREATE TABLE common.exchange_rates (
  id BIGSERIAL PRIMARY KEY,
  base_currency CHAR(3) NOT NULL,
  target_currency CHAR(3) NOT NULL,
  rate_date DATE NOT NULL,
  rate DECIMAL(18,8) NOT NULL CHECK (rate > 0),
  source VARCHAR(50) NOT NULL,
  rate_type VARCHAR(20) NOT NULL DEFAULT 'SPOT' CHECK (rate_type IN ('SPOT', 'AVERAGE', 'CLOSING', 'BUDGET')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  UNIQUE(base_currency, target_currency, rate_date, rate_type)
);

CREATE INDEX idx_exchange_rates_date ON common.exchange_rates(rate_date DESC);
CREATE INDEX idx_exchange_rates_currencies ON common.exchange_rates(base_currency, target_currency);
COMMENT ON TABLE common.exchange_rates IS 'Historique des taux de change';

-- ────────────────────────────────────────────────────────────────────────────
-- 3. RÉFÉRENTIELS FISCAUX
-- ────────────────────────────────────────────────────────────────────────────

-- Taux et codes de taxes par pays (TVA, retenues, charges sociales)
-- RÈGLE NORMATIVE : les taux TVA ne sont JAMAIS codés en dur dans les RPC.
-- Lire depuis cette table (country_code + type + effective_date courant).
CREATE TABLE common.tax_codes (
  id BIGSERIAL PRIMARY KEY,
  country_code CHAR(3) NOT NULL,
  code VARCHAR(20) NOT NULL,
  name VARCHAR(200) NOT NULL,
  rate DECIMAL(5,2) NOT NULL CHECK (rate >= 0 AND rate <= 100),
  type VARCHAR(50) NOT NULL CHECK (type IN ('VAT', 'SALES_TAX', 'WITHHOLDING', 'PAYROLL', 'OTHER')),
  effective_date DATE NOT NULL,
  end_date DATE,
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  deleted_at TIMESTAMPTZ,
  deleted_by BIGINT,
  version_number INT NOT NULL DEFAULT 1,
  UNIQUE(country_code, code, effective_date)
);

CREATE INDEX idx_tax_codes_country ON common.tax_codes(country_code);
CREATE INDEX idx_tax_codes_type ON common.tax_codes(type);
CREATE INDEX idx_tax_codes_effective ON common.tax_codes(effective_date, end_date);
COMMENT ON TABLE common.tax_codes IS 'Codes et taux de taxes par pays — source de vérité pour tous les RPC';

CREATE TABLE common.fiscal_years (
  id BIGSERIAL PRIMARY KEY,
  year INT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  country_code CHAR(3) NOT NULL,
  is_leap_year BOOLEAN NOT NULL DEFAULT FALSE,
  status VARCHAR(20) NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'CLOSED', 'LOCKED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  UNIQUE(year, country_code),
  CHECK (end_date > start_date)
);

CREATE INDEX idx_fiscal_years_country ON common.fiscal_years(country_code, year);
CREATE INDEX idx_fiscal_years_status ON common.fiscal_years(status);
COMMENT ON TABLE common.fiscal_years IS 'Calendrier des exercices fiscaux par pays';

-- ────────────────────────────────────────────────────────────────────────────
-- 4. PARAMÈTRES RÉGLEMENTAIRES
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE common.regulatory_parameters (
  id BIGSERIAL PRIMARY KEY,
  country_code CHAR(3) NOT NULL,
  parameter_type VARCHAR(100) NOT NULL,
  parameter_key VARCHAR(100) NOT NULL,
  parameter_value VARCHAR(500) NOT NULL,
  effective_date DATE NOT NULL,
  end_date DATE,
  description TEXT,
  legal_reference VARCHAR(500),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  UNIQUE(country_code, parameter_type, parameter_key, effective_date)
);

CREATE INDEX idx_regulatory_params_country ON common.regulatory_parameters(country_code);
CREATE INDEX idx_regulatory_params_type ON common.regulatory_parameters(parameter_type);
COMMENT ON TABLE common.regulatory_parameters IS 'Paramètres réglementaires (plafonds, seuils, barèmes)';

-- ────────────────────────────────────────────────────────────────────────────
-- 5. NORMES COMPTABLES
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE common.accounting_standards (
  id BIGSERIAL PRIMARY KEY,
  standard_code VARCHAR(20) NOT NULL UNIQUE,
  standard_name VARCHAR(100) NOT NULL,
  version VARCHAR(50),
  effective_date DATE NOT NULL,
  issuing_body VARCHAR(100),
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  CHECK (standard_code IN ('IFRS', 'US_GAAP', 'FR_GAAP', 'OHADA', 'UK_GAAP', 'HGB', 'PGC', 'OIC'))
);

COMMENT ON TABLE common.accounting_standards IS 'Normes comptables internationales et locales';

-- ────────────────────────────────────────────────────────────────────────────
-- 6. JOURS FÉRIÉS
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE common.holidays (
  id BIGSERIAL PRIMARY KEY,
  country_code CHAR(3) NOT NULL,
  holiday_date DATE NOT NULL,
  holiday_name VARCHAR(200) NOT NULL,
  is_recurring BOOLEAN NOT NULL DEFAULT TRUE,
  recurrence_rule VARCHAR(100),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  UNIQUE(country_code, holiday_date)
);

CREATE INDEX idx_holidays_country ON common.holidays(country_code, holiday_date);
COMMENT ON TABLE common.holidays IS 'Jours fériés par pays pour calculs paie et échéances';

-- ────────────────────────────────────────────────────────────────────────────
-- 7. VUES UTILES
-- ────────────────────────────────────────────────────────────────────────────

CREATE VIEW common.v_active_chart_templates AS
SELECT id, code, name, country_code, type, version, effective_date, description
FROM common.chart_of_accounts_templates
WHERE deleted_at IS NULL AND is_active = TRUE
  AND (end_date IS NULL OR end_date > CURRENT_DATE);

CREATE VIEW common.v_current_exchange_rates AS
SELECT DISTINCT ON (base_currency, target_currency)
  base_currency, target_currency, rate, rate_date, source
FROM common.exchange_rates
WHERE rate_type = 'SPOT'
ORDER BY base_currency, target_currency, rate_date DESC;

CREATE VIEW common.v_active_tax_codes AS
SELECT id, country_code, code, name, rate, type, effective_date, is_default
FROM common.tax_codes
WHERE deleted_at IS NULL
  AND effective_date <= CURRENT_DATE
  AND (end_date IS NULL OR end_date > CURRENT_DATE);

-- ────────────────────────────────────────────────────────────────────────────
-- 8. DONNÉES INITIALES
-- ────────────────────────────────────────────────────────────────────────────

INSERT INTO common.currencies (code, name_fr, name_en, symbol, decimal_places, is_active) VALUES
  ('EUR', 'Euro',               'Euro',             '€',    2, TRUE),
  ('USD', 'Dollar américain',   'US Dollar',        '$',    2, TRUE),
  ('GBP', 'Livre sterling',     'British Pound',    '£',    2, TRUE),
  ('CHF', 'Franc suisse',       'Swiss Franc',      'CHF',  2, TRUE),
  ('XOF', 'Franc CFA (BCEAO)', 'CFA Franc BCEAO', 'CFA',  0, TRUE),
  ('XAF', 'Franc CFA (BEAC)',  'CFA Franc BEAC',  'FCFA', 0, TRUE),
  ('MAD', 'Dirham marocain',    'Moroccan Dirham',  'MAD',  2, TRUE),
  ('TND', 'Dinar tunisien',     'Tunisian Dinar',   'TND',  3, TRUE),
  ('CAD', 'Dollar canadien',    'Canadian Dollar',  'CAD',  2, TRUE)
ON CONFLICT (code) DO NOTHING;

INSERT INTO common.countries (code_iso2, code_iso3, name_fr, name_en, phone_prefix, region, currency_code, is_eu_member) VALUES
  ('FR', 'FRA', 'France',             'France',                '+33',  'EUROPE',   'EUR', TRUE),
  ('DE', 'DEU', 'Allemagne',          'Germany',               '+49',  'EUROPE',   'EUR', TRUE),
  ('GB', 'GBR', 'Royaume-Uni',        'United Kingdom',        '+44',  'EUROPE',   'GBP', FALSE),
  ('US', 'USA', 'États-Unis',         'United States',         '+1',   'AMERICAS', 'USD', FALSE),
  ('CA', 'CAN', 'Canada',             'Canada',                '+1',   'AMERICAS', 'CAD', FALSE),
  ('GA', 'GAB', 'Gabon',              'Gabon',                 '+241', 'AFRICA',   'XAF', FALSE),
  ('SN', 'SEN', 'Sénégal',            'Senegal',               '+221', 'AFRICA',   'XOF', FALSE),
  ('CI', 'CIV', 'Côte d''Ivoire',     'Ivory Coast',           '+225', 'AFRICA',   'XOF', FALSE),
  ('CM', 'CMR', 'Cameroun',           'Cameroon',              '+237', 'AFRICA',   'XAF', FALSE),
  ('CG', 'COG', 'Congo',              'Congo',                 '+242', 'AFRICA',   'XAF', FALSE),
  ('TD', 'TCD', 'Tchad',              'Chad',                  '+235', 'AFRICA',   'XAF', FALSE),
  ('BF', 'BFA', 'Burkina Faso',       'Burkina Faso',          '+226', 'AFRICA',   'XOF', FALSE),
  ('ML', 'MLI', 'Mali',               'Mali',                  '+223', 'AFRICA',   'XOF', FALSE),
  ('GQ', 'GNQ', 'Guinée Équatoriale', 'Equatorial Guinea',     '+240', 'AFRICA',   'XAF', FALSE),
  ('CF', 'CAF', 'Centrafrique',       'Central African Republic','+236','AFRICA',  'XAF', FALSE),
  ('MA', 'MAR', 'Maroc',              'Morocco',               '+212', 'AFRICA',   'MAD', FALSE),
  ('TN', 'TUN', 'Tunisie',            'Tunisia',               '+216', 'AFRICA',   'TND', FALSE)
ON CONFLICT (code_iso2) DO NOTHING;

INSERT INTO common.accounting_standards (standard_code, standard_name, version, effective_date, issuing_body, is_active) VALUES
  ('IFRS',    'International Financial Reporting Standards', '2025', '2025-01-01', 'IASB',  TRUE),
  ('US_GAAP', 'US Generally Accepted Accounting Principles', '2025', '2025-01-01', 'FASB',  TRUE),
  ('FR_GAAP', 'Plan Comptable Général France',               '2025', '2025-01-01', 'ANC',   TRUE),
  ('OHADA',   'SYSCOHADA Révisé',                           '2017', '2017-01-01', 'OHADA', TRUE)
ON CONFLICT (standard_code) DO NOTHING;

-- Taux TVA (lus par les RPC — ne JAMAIS hardcoder ces valeurs dans les fonctions)
INSERT INTO common.tax_codes (country_code, code, name, rate, type, effective_date, is_default) VALUES
  -- Gabon CEMAC
  ('GAB', 'TVA_GA_18',    'TVA Gabon 18%',          18.00, 'VAT',     '2024-01-01', TRUE),
  ('GAB', 'TVA_GA_10',    'TVA Gabon Réduit 10%',   10.00, 'VAT',     '2024-01-01', FALSE),
  ('GAB', 'TVA_GA_0',     'Exonéré TVA Gabon',       0.00, 'VAT',     '2024-01-01', FALSE),
  ('GAB', 'IRPP_GA_STD',  'IRPP Gabon (barème progressif)', 0.00, 'PAYROLL', '2024-01-01', TRUE),
  -- France
  ('FRA', 'TVA_FR_20',    'TVA France 20%',          20.00, 'VAT',     '2024-01-01', TRUE),
  ('FRA', 'TVA_FR_10',    'TVA France Intermédiaire 10%', 10.00, 'VAT', '2024-01-01', FALSE),
  ('FRA', 'TVA_FR_5.5',   'TVA France Réduit 5,5%',  5.50, 'VAT',     '2024-01-01', FALSE),
  ('FRA', 'TVA_FR_0',     'Exonéré TVA France',       0.00, 'VAT',     '2024-01-01', FALSE),
  -- Cameroun
  ('CMR', 'TVA_CM_19.25', 'TVA Cameroun 19,25%',    19.25, 'VAT',     '2024-01-01', TRUE),
  -- Côte d''Ivoire
  ('CIV', 'TVA_CI_18',    'TVA Côte d''Ivoire 18%', 18.00, 'VAT',     '2024-01-01', TRUE)
ON CONFLICT (country_code, code, effective_date) DO NOTHING;

-- Paramètres réglementaires Gabon (plafonds CNSS — lus par les RPC)
INSERT INTO common.regulatory_parameters (country_code, parameter_type, parameter_key, parameter_value, effective_date, description, legal_reference) VALUES
  ('GAB', 'CNSS', 'PLAFOND_TRANCHE_A', '1500000', '2025-01-01', 'Plafond mensuel tranche A CNSS Gabon en XAF', 'Décret CNSS Gabon 2025'),
  ('GAB', 'CNSS', 'SMIC_MENSUEL',      '150000',  '2024-01-01', 'SMIC mensuel Gabon en XAF',                   'Code du travail gabonais')
ON CONFLICT (country_code, parameter_type, parameter_key, effective_date) DO NOTHING;

-- Template OHADA (l''entrée racine pour le script 06 - plan comptable)
INSERT INTO common.chart_of_accounts_templates (code, name, country_code, type, version, effective_date, description) VALUES
  ('OHADA_2017', 'SYSCOHADA Révisé 2017', NULL, 'LOCAL_GAAP', '2017', '2017-01-01',
   'Plan comptable OHADA révisé applicable dans les 17 États membres de l''espace OHADA')
ON CONFLICT (code) DO NOTHING;

-- ────────────────────────────────────────────────────────────────────────────
-- PERMISSIONS SUPABASE
-- ────────────────────────────────────────────────────────────────────────────

GRANT USAGE ON SCHEMA common TO authenticated;
GRANT USAGE ON SCHEMA common TO service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA common TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA common TO service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA common TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA common TO service_role;

-- ============================================================================
DO $$ BEGIN RAISE NOTICE '✅ Script 02 OK — Référentiels communs créés';
END $$;
