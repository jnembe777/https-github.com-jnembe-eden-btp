-- ============================================================================
-- Fix déploiement (Sprint 1) : FK -> common.currencies(code) (et non currency_code,
-- colonne inexistante). ROLLBACK : rétablir common.currencies(currency_code) si
-- la colonne de référence est renommée. Voir SPRINT1_GAMMES_BUILD.md.
-- EdenFin ONYX - Module 01: Multi-Country Management
-- ============================================================================
-- Version: 1.0.0
-- Date: 2026-02-11
-- Description: Multi-country, multi-jurisdiction, multi-GAAP support
-- Dependencies: JASPE (00-09), RUBIS (01-03), SAPHIR (01-05)
-- ============================================================================

-- ============================================================================
-- SECTION 1: ENUMS
-- ============================================================================

-- Legal form types across jurisdictions
CREATE TYPE sys.legal_form_type AS ENUM (
    -- OHADA Zone
    'SA',           -- Société Anonyme
    'SARL',         -- Société à Responsabilité Limitée
    'SAS',          -- Société par Actions Simplifiée
    'SNC',          -- Société en Nom Collectif
    'SCS',          -- Société en Commandite Simple
    'GIE',          -- Groupement d'Intérêt Économique
    -- French
    'EURL',         -- Entreprise Unipersonnelle à Responsabilité Limitée
    -- German
    'GMBH',         -- Gesellschaft mit beschränkter Haftung
    'AG',           -- Aktiengesellschaft
    -- UK
    'LTD',          -- Private Limited Company
    'PLC',          -- Public Limited Company
    'LLP',          -- Limited Liability Partnership
    -- US
    'INC',          -- Corporation
    'LLC',          -- Limited Liability Company
    'LP',           -- Limited Partnership
    -- Other
    'BRANCH',       -- Branch office
    'REP_OFFICE',   -- Representative office
    'JV',           -- Joint Venture
    'OTHER'
);

-- GAAP frameworks
CREATE TYPE sys.gaap_framework AS ENUM (
    'OHADA',        -- SYSCOHADA (17 African countries)
    'IFRS',         -- International Financial Reporting Standards
    'IFRS_SME',     -- IFRS for SMEs
    'US_GAAP',      -- United States GAAP
    'FR_GAAP',      -- French GAAP (PCG)
    'DE_GAAP',      -- German GAAP (HGB)
    'UK_GAAP',      -- UK GAAP (FRS 102)
    'IPSAS',        -- Public sector
    'LOCAL'         -- Other local GAAP
);

-- Jurisdiction types
CREATE TYPE sys.jurisdiction_type AS ENUM (
    'COUNTRY',
    'STATE',
    'PROVINCE',
    'REGION',
    'MUNICIPALITY',
    'ZONE',             -- Special economic zone
    'FREE_TRADE_ZONE',
    'TAX_HAVEN'
);

-- Tax identification types
CREATE TYPE sys.tax_id_type AS ENUM (
    'NIF',          -- Numéro d'Identification Fiscale (OHADA)
    'RCCM',         -- Registre du Commerce (OHADA)
    'TIN',          -- Tax Identification Number (US)
    'VAT',          -- VAT number (EU)
    'EIN',          -- Employer Identification Number (US)
    'SIRET',        -- France
    'SIREN',        -- France
    'CIF',          -- Spain
    'CNPJ',         -- Brazil
    'OTHER'
);

-- Consolidation methods
CREATE TYPE sys.consolidation_method_type AS ENUM (
    'FULL',             -- 100% subsidiary
    'PROPORTIONAL',     -- Joint venture by %
    'EQUITY',           -- Associate (20-50%)
    'COST',             -- < 20% influence
    'NONE'              -- Not consolidated
);

-- GAAP adjustment types
CREATE TYPE sys.gaap_adjustment_type AS ENUM (
    'RECLASSIFICATION',     -- Different account classification
    'REVALUATION',          -- Different measurement basis
    'TIMING',               -- Different recognition timing
    'DISCLOSURE',           -- Disclosure difference only
    'ELIMINATION',          -- Consolidation elimination
    'TRANSLATION'           -- Currency translation
);

-- ============================================================================
-- SECTION 2: CORE TABLES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 2.1 Countries Master
-- ----------------------------------------------------------------------------
CREATE TABLE sys.countries (
    country_code VARCHAR(2) PRIMARY KEY,  -- ISO 3166-1 alpha-2
    country_code_3 VARCHAR(3) NOT NULL,   -- ISO 3166-1 alpha-3
    country_name VARCHAR(100) NOT NULL,
    country_name_local VARCHAR(100),

    -- Currency
    currency_code VARCHAR(3) NOT NULL REFERENCES common.currencies(code),
    currency_symbol VARCHAR(5),

    -- Localization
    language_code VARCHAR(5) NOT NULL DEFAULT 'en',  -- ISO 639-1
    date_format VARCHAR(20) DEFAULT 'YYYY-MM-DD',
    number_format VARCHAR(20) DEFAULT '#,##0.00',
    decimal_separator CHAR(1) DEFAULT '.',
    thousand_separator CHAR(1) DEFAULT ',',

    -- Fiscal
    fiscal_year_start_month INT NOT NULL DEFAULT 1 CHECK (fiscal_year_start_month BETWEEN 1 AND 12),
    fiscal_year_start_day INT NOT NULL DEFAULT 1 CHECK (fiscal_year_start_day BETWEEN 1 AND 31),

    -- Tax configuration
    vat_standard_rate DECIMAL(5,2),
    vat_reduced_rates JSONB DEFAULT '[]',
    corporate_tax_rate DECIMAL(5,2),
    withholding_tax_config JSONB DEFAULT '{}',
    tax_id_format VARCHAR(50),  -- Regex pattern
    tax_id_type sys.tax_id_type DEFAULT 'OTHER',

    -- Legal
    statutory_audit_threshold DECIMAL(18,2),
    statutory_audit_required BOOLEAN DEFAULT FALSE,

    -- Regional groupings
    economic_zone VARCHAR(20),  -- OHADA, EU, UEMOA, CEMAC, etc.
    customs_union VARCHAR(20),

    -- GAAP
    primary_gaap sys.gaap_framework NOT NULL DEFAULT 'IFRS',

    -- Status
    is_active BOOLEAN DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT
);

-- Indexes
CREATE INDEX idx_countries_economic_zone ON sys.countries(economic_zone);
CREATE INDEX idx_countries_active ON sys.countries(is_active) WHERE is_active = TRUE;

COMMENT ON TABLE sys.countries IS 'Country master with legal, tax, and localization configuration';

-- ----------------------------------------------------------------------------
-- 2.2 Jurisdictions (Sub-national)
-- ----------------------------------------------------------------------------
CREATE TABLE sys.jurisdictions (
    jurisdiction_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    country_code VARCHAR(2) NOT NULL REFERENCES sys.countries(country_code),
    jurisdiction_code VARCHAR(10) NOT NULL,
    jurisdiction_name VARCHAR(100) NOT NULL,
    jurisdiction_type sys.jurisdiction_type NOT NULL DEFAULT 'STATE',

    -- Parent jurisdiction (for hierarchy)
    parent_jurisdiction_id BIGINT REFERENCES sys.jurisdictions(jurisdiction_id),

    -- Tax authority
    tax_authority_name VARCHAR(100),
    tax_authority_code VARCHAR(20),

    -- Local taxes
    local_tax_rates JSONB DEFAULT '{}',
    additional_vat_rate DECIMAL(5,2),  -- Some jurisdictions add local VAT

    -- Special zones
    is_special_economic_zone BOOLEAN DEFAULT FALSE,
    is_free_trade_zone BOOLEAN DEFAULT FALSE,
    zone_benefits JSONB DEFAULT '{}',

    -- Status
    is_active BOOLEAN DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,

    UNIQUE (country_code, jurisdiction_code)
);

CREATE INDEX idx_jurisdictions_country ON sys.jurisdictions(country_code);
CREATE INDEX idx_jurisdictions_type ON sys.jurisdictions(jurisdiction_type);

COMMENT ON TABLE sys.jurisdictions IS 'Sub-national jurisdictions (states, provinces, zones)';

-- ----------------------------------------------------------------------------
-- 2.3 Accounting Standards
-- ----------------------------------------------------------------------------
CREATE TABLE sys.accounting_standards (
    standard_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    gaap_framework sys.gaap_framework NOT NULL,
    standard_code VARCHAR(20) NOT NULL,
    standard_name VARCHAR(200) NOT NULL,
    description TEXT,

    -- Version tracking
    effective_date DATE NOT NULL,
    superseded_date DATE,
    superseded_by_id BIGINT REFERENCES sys.accounting_standards(standard_id),

    -- Classification
    topic_area VARCHAR(50),  -- Revenue, Leases, Financial Instruments, etc.
    is_mandatory BOOLEAN DEFAULT TRUE,

    -- Documentation
    reference_url VARCHAR(500),

    -- Status
    is_active BOOLEAN DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (gaap_framework, standard_code, effective_date)
);

CREATE INDEX idx_standards_gaap ON sys.accounting_standards(gaap_framework);
CREATE INDEX idx_standards_topic ON sys.accounting_standards(topic_area);

COMMENT ON TABLE sys.accounting_standards IS 'Accounting standards by GAAP framework';

-- ----------------------------------------------------------------------------
-- 2.4 Legal Entity Registry
-- ----------------------------------------------------------------------------
CREATE TABLE sys.legal_entity_registry (
    registry_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(entity_id) ON DELETE CASCADE,

    -- Legal identification
    legal_name VARCHAR(200) NOT NULL,
    trade_name VARCHAR(200),
    legal_form sys.legal_form_type NOT NULL,

    -- Registration
    country_code VARCHAR(2) NOT NULL REFERENCES sys.countries(country_code),
    jurisdiction_id BIGINT REFERENCES sys.jurisdictions(jurisdiction_id),
    registration_number VARCHAR(50),
    registration_date DATE,
    registration_authority VARCHAR(100),

    -- Tax identifiers
    tax_id VARCHAR(50),
    tax_id_type sys.tax_id_type,
    vat_id VARCHAR(50),
    secondary_tax_ids JSONB DEFAULT '{}',  -- Additional IDs per jurisdiction

    -- Address
    registered_address_line1 VARCHAR(200),
    registered_address_line2 VARCHAR(200),
    registered_city VARCHAR(100),
    registered_state VARCHAR(100),
    registered_postal_code VARCHAR(20),
    registered_country VARCHAR(2),

    -- Capital structure
    share_capital DECIMAL(18,2),
    share_capital_currency VARCHAR(3),
    authorized_shares BIGINT,
    issued_shares BIGINT,

    -- Accounting
    functional_currency VARCHAR(3) NOT NULL REFERENCES common.currencies(code),
    reporting_currency VARCHAR(3) REFERENCES common.currencies(code),
    gaap_framework sys.gaap_framework NOT NULL DEFAULT 'OHADA',
    fiscal_year_end_month INT NOT NULL DEFAULT 12 CHECK (fiscal_year_end_month BETWEEN 1 AND 12),
    fiscal_year_end_day INT NOT NULL DEFAULT 31,

    -- Consolidation
    is_holding BOOLEAN DEFAULT FALSE,
    is_consolidated BOOLEAN DEFAULT TRUE,
    parent_entity_id BIGINT REFERENCES sys.tenant_entities(entity_id),
    ownership_percentage DECIMAL(5,2) CHECK (ownership_percentage BETWEEN 0 AND 100),
    voting_rights_percentage DECIMAL(5,2) CHECK (voting_rights_percentage BETWEEN 0 AND 100),
    consolidation_method sys.consolidation_method_type DEFAULT 'FULL',
    consolidation_start_date DATE,
    consolidation_end_date DATE,

    -- Governance
    auditor_name VARCHAR(200),
    auditor_appointment_date DATE,
    directors JSONB DEFAULT '[]',  -- List of directors

    -- Status
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'DORMANT', 'LIQUIDATING', 'DISSOLVED')),
    dissolution_date DATE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,

    UNIQUE (entity_id)
);

CREATE INDEX idx_legal_entity_country ON sys.legal_entity_registry(country_code);
CREATE INDEX idx_legal_entity_parent ON sys.legal_entity_registry(parent_entity_id);
CREATE INDEX idx_legal_entity_tax ON sys.legal_entity_registry(tax_id) WHERE tax_id IS NOT NULL;
CREATE INDEX idx_legal_entity_gaap ON sys.legal_entity_registry(gaap_framework);

COMMENT ON TABLE sys.legal_entity_registry IS 'Comprehensive legal entity registration and corporate structure';

-- ----------------------------------------------------------------------------
-- 2.5 Multi-GAAP Account Mappings
-- ----------------------------------------------------------------------------
CREATE TABLE sys.gaap_mappings (
    mapping_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(entity_id),

    -- Source (entity's primary GAAP)
    source_gaap sys.gaap_framework NOT NULL,
    source_account_code VARCHAR(20) NOT NULL,
    source_account_name VARCHAR(200),

    -- Target (parallel reporting GAAP)
    target_gaap sys.gaap_framework NOT NULL,
    target_account_code VARCHAR(20) NOT NULL,
    target_account_name VARCHAR(200),

    -- Adjustment
    adjustment_type sys.gaap_adjustment_type NOT NULL DEFAULT 'RECLASSIFICATION',
    adjustment_formula TEXT,  -- Optional calculation formula
    adjustment_percentage DECIMAL(8,4),  -- For proportional adjustments

    -- Applicable standard
    accounting_standard_id BIGINT REFERENCES sys.accounting_standards(standard_id),

    -- Validity
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE,

    -- Status
    is_active BOOLEAN DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,

    UNIQUE (entity_id, source_gaap, source_account_code, target_gaap, effective_from)
);

CREATE INDEX idx_gaap_mappings_entity ON sys.gaap_mappings(entity_id);
CREATE INDEX idx_gaap_mappings_source ON sys.gaap_mappings(source_gaap, source_account_code);
CREATE INDEX idx_gaap_mappings_target ON sys.gaap_mappings(target_gaap, target_account_code);

COMMENT ON TABLE sys.gaap_mappings IS 'Account mappings between different GAAP frameworks';

-- ----------------------------------------------------------------------------
-- 2.6 Statutory Reporting Configuration
-- ----------------------------------------------------------------------------
CREATE TABLE sys.statutory_reporting_config (
    config_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    country_code VARCHAR(2) NOT NULL REFERENCES sys.countries(country_code),

    -- Report type
    report_code VARCHAR(30) NOT NULL,
    report_name VARCHAR(200) NOT NULL,
    report_description TEXT,

    -- Filing requirements
    filing_frequency VARCHAR(20) NOT NULL CHECK (filing_frequency IN ('MONTHLY', 'QUARTERLY', 'SEMI_ANNUAL', 'ANNUAL', 'ON_DEMAND')),
    filing_deadline_days INT,  -- Days after period end
    filing_authority VARCHAR(100),

    -- Format
    format_type VARCHAR(20) CHECK (format_type IN ('PDF', 'XML', 'XBRL', 'IXBRL', 'CSV', 'EXCEL', 'CUSTOM')),
    template_reference VARCHAR(200),

    -- Thresholds
    revenue_threshold DECIMAL(18,2),
    asset_threshold DECIMAL(18,2),
    employee_threshold INT,

    -- Status
    is_mandatory BOOLEAN DEFAULT TRUE,
    is_active BOOLEAN DEFAULT TRUE,

    -- Validity
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (country_code, report_code, effective_from)
);

CREATE INDEX idx_statutory_config_country ON sys.statutory_reporting_config(country_code);

COMMENT ON TABLE sys.statutory_reporting_config IS 'Country-specific statutory reporting requirements';

-- ----------------------------------------------------------------------------
-- 2.7 Tax Regimes
-- ----------------------------------------------------------------------------
CREATE TABLE sys.tax_regimes (
    regime_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    country_code VARCHAR(2) NOT NULL REFERENCES sys.countries(country_code),
    jurisdiction_id BIGINT REFERENCES sys.jurisdictions(jurisdiction_id),

    -- Identification
    regime_code VARCHAR(20) NOT NULL,
    regime_name VARCHAR(100) NOT NULL,
    description TEXT,

    -- Tax type
    tax_type VARCHAR(30) NOT NULL CHECK (tax_type IN (
        'CORPORATE_INCOME', 'VAT', 'WITHHOLDING', 'PAYROLL',
        'PROPERTY', 'CUSTOMS', 'EXCISE', 'STAMP_DUTY', 'OTHER'
    )),

    -- Rates
    standard_rate DECIMAL(8,4) NOT NULL,
    reduced_rates JSONB DEFAULT '[]',
    rate_brackets JSONB DEFAULT '[]',  -- For progressive taxes

    -- Calculation rules
    base_calculation TEXT,
    deductions_allowed JSONB DEFAULT '[]',
    credits_available JSONB DEFAULT '[]',

    -- Filing
    filing_frequency VARCHAR(20),
    payment_due_days INT,

    -- Validity
    effective_from DATE NOT NULL,
    effective_to DATE,

    -- Status
    is_active BOOLEAN DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,

    UNIQUE (country_code, regime_code, effective_from)
);

CREATE INDEX idx_tax_regimes_country ON sys.tax_regimes(country_code);
CREATE INDEX idx_tax_regimes_type ON sys.tax_regimes(tax_type);

COMMENT ON TABLE sys.tax_regimes IS 'Tax regime configurations by country/jurisdiction';

-- ----------------------------------------------------------------------------
-- 2.8 Labor Law Configuration
-- ----------------------------------------------------------------------------
CREATE TABLE sys.labor_law_config (
    config_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    country_code VARCHAR(2) NOT NULL REFERENCES sys.countries(country_code),
    jurisdiction_id BIGINT REFERENCES sys.jurisdictions(jurisdiction_id),

    -- Working hours
    standard_hours_week DECIMAL(4,1) DEFAULT 40,
    max_hours_week DECIMAL(4,1) DEFAULT 48,
    overtime_threshold_daily DECIMAL(4,1),

    -- Leave entitlements
    annual_leave_days INT DEFAULT 21,
    sick_leave_days INT,
    maternity_leave_days INT,
    paternity_leave_days INT,
    public_holidays JSONB DEFAULT '[]',

    -- Compensation
    minimum_wage DECIMAL(12,2),
    minimum_wage_currency VARCHAR(3),
    minimum_wage_period VARCHAR(20) DEFAULT 'MONTHLY',
    overtime_rate_multiplier DECIMAL(3,2) DEFAULT 1.50,
    night_shift_multiplier DECIMAL(3,2),

    -- Social contributions
    employer_social_rate DECIMAL(5,2),
    employee_social_rate DECIMAL(5,2),
    social_contribution_caps JSONB DEFAULT '{}',

    -- Termination
    notice_period_days INT,
    severance_formula TEXT,

    -- Validity
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE,

    -- Status
    is_active BOOLEAN DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Fix déploiement : UNIQUE avec expression COALESCE interdit en contrainte de
-- table -> index unique sur expression. ROLLBACK : DROP INDEX IF EXISTS sys.uq_labor_law_config;
CREATE UNIQUE INDEX uq_labor_law_config ON sys.labor_law_config (
  country_code, COALESCE(jurisdiction_id, 0), effective_from
);

CREATE INDEX idx_labor_config_country ON sys.labor_law_config(country_code);

COMMENT ON TABLE sys.labor_law_config IS 'Labor law requirements by country/jurisdiction';

-- ============================================================================
-- SECTION 3: VIEWS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 3.1 Entity Legal Summary View
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW sys.v_entity_legal_summary AS
SELECT
    e.entity_id,
    e.entity_name,
    e.entity_code,
    ler.legal_name,
    ler.legal_form,
    ler.country_code,
    c.country_name,
    c.economic_zone,
    ler.tax_id,
    ler.vat_id,
    ler.functional_currency,
    ler.gaap_framework,
    ler.is_holding,
    ler.is_consolidated,
    ler.parent_entity_id,
    pe.entity_name AS parent_entity_name,
    ler.ownership_percentage,
    ler.consolidation_method,
    ler.status,
    ler.share_capital,
    ler.share_capital_currency
FROM sys.tenant_entities e
LEFT JOIN sys.legal_entity_registry ler ON e.entity_id = ler.entity_id
LEFT JOIN sys.countries c ON ler.country_code = c.country_code
LEFT JOIN sys.tenant_entities pe ON ler.parent_entity_id = pe.entity_id
WHERE e.deleted_at IS NULL;

COMMENT ON VIEW sys.v_entity_legal_summary IS 'Entity legal and corporate structure summary';

-- ----------------------------------------------------------------------------
-- 3.2 Multi-GAAP Mapping Summary
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW sys.v_gaap_mapping_summary AS
SELECT
    gm.entity_id,
    e.entity_name,
    gm.source_gaap,
    gm.target_gaap,
    COUNT(*) AS mapping_count,
    COUNT(*) FILTER (WHERE gm.adjustment_type = 'RECLASSIFICATION') AS reclassifications,
    COUNT(*) FILTER (WHERE gm.adjustment_type = 'REVALUATION') AS revaluations,
    COUNT(*) FILTER (WHERE gm.adjustment_type = 'TIMING') AS timing_diffs
FROM sys.gaap_mappings gm
JOIN sys.tenant_entities e ON gm.entity_id = e.entity_id
WHERE gm.is_active = TRUE
  AND (gm.effective_to IS NULL OR gm.effective_to >= CURRENT_DATE)
GROUP BY gm.entity_id, e.entity_name, gm.source_gaap, gm.target_gaap;

COMMENT ON VIEW sys.v_gaap_mapping_summary IS 'Summary of GAAP mappings by entity';

-- ----------------------------------------------------------------------------
-- 3.3 Consolidation Hierarchy View
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW sys.v_consolidation_hierarchy AS
WITH RECURSIVE hierarchy AS (
    -- Base case: top-level entities (no parent)
    SELECT
        ler.entity_id,
        e.entity_name,
        ler.legal_name,
        ler.country_code,
        ler.parent_entity_id,
        ler.ownership_percentage,
        ler.consolidation_method,
        1 AS level,
        ARRAY[ler.entity_id] AS path,
        -- Fix déploiement : le terme récursif produit un numeric non contraint
        -- (h.effective_ownership * ... / 100) ; on aligne l'ancrage en numeric
        -- pour éviter « type numeric(5,2) ... but type numeric overall ».
        -- ROLLBACK : retirer le cast ::numeric si les deux termes sont alignés.
        ler.ownership_percentage::numeric AS effective_ownership
    FROM sys.legal_entity_registry ler
    JOIN sys.tenant_entities e ON ler.entity_id = e.entity_id
    WHERE ler.parent_entity_id IS NULL
      AND ler.is_consolidated = TRUE
      AND ler.status = 'ACTIVE'

    UNION ALL

    -- Recursive case: children
    SELECT
        ler.entity_id,
        e.entity_name,
        ler.legal_name,
        ler.country_code,
        ler.parent_entity_id,
        ler.ownership_percentage,
        ler.consolidation_method,
        h.level + 1,
        h.path || ler.entity_id,
        h.effective_ownership * ler.ownership_percentage / 100
    FROM sys.legal_entity_registry ler
    JOIN sys.tenant_entities e ON ler.entity_id = e.entity_id
    JOIN hierarchy h ON ler.parent_entity_id = h.entity_id
    WHERE ler.is_consolidated = TRUE
      AND ler.status = 'ACTIVE'
      AND NOT ler.entity_id = ANY(h.path)  -- Prevent cycles
)
SELECT
    entity_id,
    entity_name,
    legal_name,
    country_code,
    parent_entity_id,
    ownership_percentage AS direct_ownership,
    effective_ownership,
    consolidation_method,
    level,
    path
FROM hierarchy
ORDER BY path;

COMMENT ON VIEW sys.v_consolidation_hierarchy IS 'Recursive consolidation hierarchy with effective ownership';

-- ----------------------------------------------------------------------------
-- 3.4 Country Tax Summary View
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW sys.v_country_tax_summary AS
SELECT
    c.country_code,
    c.country_name,
    c.economic_zone,
    c.vat_standard_rate,
    c.corporate_tax_rate,
    (
        SELECT COALESCE(SUM(1), 0)
        FROM sys.tax_regimes tr
        WHERE tr.country_code = c.country_code AND tr.is_active
    ) AS active_tax_regimes,
    (
        SELECT COUNT(*)
        FROM sys.legal_entity_registry ler
        WHERE ler.country_code = c.country_code AND ler.status = 'ACTIVE'
    ) AS entity_count
FROM sys.countries c
WHERE c.is_active = TRUE;

COMMENT ON VIEW sys.v_country_tax_summary IS 'Country tax summary with entity counts';

-- ============================================================================
-- SECTION 4: RPC FUNCTIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 4.1 Get Entity Legal Configuration
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sys.rpc_get_entity_legal_config(
    p_entity_id BIGINT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'entity_id', ler.entity_id,
        'legal_name', ler.legal_name,
        'trade_name', ler.trade_name,
        'legal_form', ler.legal_form,
        'country', jsonb_build_object(
            'code', c.country_code,
            'name', c.country_name,
            'economic_zone', c.economic_zone,
            'currency', c.currency_code,
            'fiscal_year_start', c.fiscal_year_start_month
        ),
        'jurisdiction', CASE WHEN j.jurisdiction_id IS NOT NULL THEN
            jsonb_build_object(
                'id', j.jurisdiction_id,
                'code', j.jurisdiction_code,
                'name', j.jurisdiction_name,
                'type', j.jurisdiction_type
            )
        ELSE NULL END,
        'tax_ids', jsonb_build_object(
            'primary', ler.tax_id,
            'vat', ler.vat_id,
            'additional', ler.secondary_tax_ids
        ),
        'accounting', jsonb_build_object(
            'functional_currency', ler.functional_currency,
            'reporting_currency', ler.reporting_currency,
            'gaap_framework', ler.gaap_framework,
            'fiscal_year_end', ler.fiscal_year_end_month || '-' || ler.fiscal_year_end_day
        ),
        'consolidation', jsonb_build_object(
            'is_holding', ler.is_holding,
            'is_consolidated', ler.is_consolidated,
            'parent_entity_id', ler.parent_entity_id,
            'ownership_percentage', ler.ownership_percentage,
            'method', ler.consolidation_method
        ),
        'status', ler.status
    ) INTO v_result
    FROM sys.legal_entity_registry ler
    JOIN sys.countries c ON ler.country_code = c.country_code
    LEFT JOIN sys.jurisdictions j ON ler.jurisdiction_id = j.jurisdiction_id
    WHERE ler.entity_id = p_entity_id;

    RETURN COALESCE(v_result, '{}'::JSONB);
END;
$$;

COMMENT ON FUNCTION sys.rpc_get_entity_legal_config IS 'Get comprehensive legal configuration for an entity';

-- ----------------------------------------------------------------------------
-- 4.2 Convert GAAP
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sys.rpc_convert_gaap(
    p_entity_id BIGINT,
    p_source_gaap sys.gaap_framework,
    p_target_gaap sys.gaap_framework,
    p_period_start DATE,
    p_period_end DATE
) RETURNS TABLE (
    source_account VARCHAR(20),
    target_account VARCHAR(20),
    adjustment_type sys.gaap_adjustment_type,
    source_balance DECIMAL(18,2),
    adjustment_amount DECIMAL(18,2),
    target_balance DECIMAL(18,2)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH account_balances AS (
        -- Get source GAAP balances (simplified - actual implementation would join to GL)
        SELECT
            gm.source_account_code,
            gm.target_account_code,
            gm.adjustment_type,
            gm.adjustment_percentage,
            gm.adjustment_formula,
            COALESCE(
                (SELECT SUM(debit - credit)
                 FROM sys.journal_entry_lines jel
                 JOIN sys.journal_entries je ON jel.journal_entry_id = je.journal_entry_id
                 WHERE jel.account_code = gm.source_account_code
                   AND je.entity_id = p_entity_id
                   AND je.entry_date BETWEEN p_period_start AND p_period_end
                   AND je.status = 'POSTED'),
                0
            ) AS source_bal
        FROM sys.gaap_mappings gm
        WHERE gm.entity_id = p_entity_id
          AND gm.source_gaap = p_source_gaap
          AND gm.target_gaap = p_target_gaap
          AND gm.is_active = TRUE
          AND gm.effective_from <= p_period_end
          AND (gm.effective_to IS NULL OR gm.effective_to >= p_period_start)
    )
    SELECT
        ab.source_account_code,
        ab.target_account_code,
        ab.adjustment_type,
        ab.source_bal,
        CASE
            WHEN ab.adjustment_percentage IS NOT NULL THEN
                ab.source_bal * ab.adjustment_percentage / 100
            ELSE 0
        END AS adj_amount,
        ab.source_bal + CASE
            WHEN ab.adjustment_percentage IS NOT NULL THEN
                ab.source_bal * ab.adjustment_percentage / 100
            ELSE 0
        END AS target_bal
    FROM account_balances ab;
END;
$$;

COMMENT ON FUNCTION sys.rpc_convert_gaap IS 'Convert trial balance from one GAAP to another';

-- ----------------------------------------------------------------------------
-- 4.3 Register Legal Entity
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sys.rpc_register_legal_entity(
    p_entity_id BIGINT,
    p_legal_name VARCHAR(200),
    p_legal_form sys.legal_form_type,
    p_country_code VARCHAR(2),
    p_tax_id VARCHAR(50),
    p_functional_currency VARCHAR(3),
    p_gaap_framework sys.gaap_framework,
    p_parent_entity_id BIGINT DEFAULT NULL,
    p_ownership_percentage DECIMAL(5,2) DEFAULT 100,
    p_user_id BIGINT DEFAULT 0
) RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_registry_id BIGINT;
    v_consol_method sys.consolidation_method_type;
BEGIN
    -- Determine consolidation method based on ownership
    v_consol_method := CASE
        WHEN p_ownership_percentage >= 50 THEN 'FULL'
        WHEN p_ownership_percentage >= 20 THEN 'EQUITY'
        ELSE 'COST'
    END;

    -- Insert or update
    INSERT INTO sys.legal_entity_registry (
        entity_id, legal_name, legal_form, country_code,
        tax_id, functional_currency, gaap_framework,
        parent_entity_id, ownership_percentage, consolidation_method,
        is_holding, is_consolidated,
        created_by
    ) VALUES (
        p_entity_id, p_legal_name, p_legal_form, p_country_code,
        p_tax_id, p_functional_currency, p_gaap_framework,
        p_parent_entity_id, p_ownership_percentage, v_consol_method,
        (p_parent_entity_id IS NULL), TRUE,
        p_user_id
    )
    ON CONFLICT (entity_id) DO UPDATE SET
        legal_name = EXCLUDED.legal_name,
        legal_form = EXCLUDED.legal_form,
        country_code = EXCLUDED.country_code,
        tax_id = EXCLUDED.tax_id,
        functional_currency = EXCLUDED.functional_currency,
        gaap_framework = EXCLUDED.gaap_framework,
        parent_entity_id = EXCLUDED.parent_entity_id,
        ownership_percentage = EXCLUDED.ownership_percentage,
        consolidation_method = EXCLUDED.consolidation_method,
        updated_at = NOW(),
        updated_by = p_user_id
    RETURNING registry_id INTO v_registry_id;

    RETURN v_registry_id;
END;
$$;

COMMENT ON FUNCTION sys.rpc_register_legal_entity IS 'Register or update legal entity information';

-- ----------------------------------------------------------------------------
-- 4.4 Get Country Tax Configuration
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sys.rpc_get_country_tax_config(
    p_country_code VARCHAR(2),
    p_as_of_date DATE DEFAULT CURRENT_DATE
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'country', jsonb_build_object(
            'code', c.country_code,
            'name', c.country_name,
            'vat_standard_rate', c.vat_standard_rate,
            'vat_reduced_rates', c.vat_reduced_rates,
            'corporate_tax_rate', c.corporate_tax_rate,
            'withholding_tax_config', c.withholding_tax_config
        ),
        'tax_regimes', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'regime_code', tr.regime_code,
                'regime_name', tr.regime_name,
                'tax_type', tr.tax_type,
                'standard_rate', tr.standard_rate,
                'reduced_rates', tr.reduced_rates,
                'filing_frequency', tr.filing_frequency
            )), '[]'::JSONB)
            FROM sys.tax_regimes tr
            WHERE tr.country_code = p_country_code
              AND tr.is_active = TRUE
              AND tr.effective_from <= p_as_of_date
              AND (tr.effective_to IS NULL OR tr.effective_to >= p_as_of_date)
        ),
        'statutory_reports', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'report_code', src.report_code,
                'report_name', src.report_name,
                'filing_frequency', src.filing_frequency,
                'deadline_days', src.filing_deadline_days,
                'format', src.format_type,
                'is_mandatory', src.is_mandatory
            )), '[]'::JSONB)
            FROM sys.statutory_reporting_config src
            WHERE src.country_code = p_country_code
              AND src.is_active = TRUE
              AND src.effective_from <= p_as_of_date
              AND (src.effective_to IS NULL OR src.effective_to >= p_as_of_date)
        )
    ) INTO v_result
    FROM sys.countries c
    WHERE c.country_code = p_country_code;

    RETURN COALESCE(v_result, '{}'::JSONB);
END;
$$;

COMMENT ON FUNCTION sys.rpc_get_country_tax_config IS 'Get country tax and reporting configuration';

-- ----------------------------------------------------------------------------
-- 4.5 Calculate Effective Ownership
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sys.rpc_calculate_effective_ownership(
    p_entity_id BIGINT
) RETURNS TABLE (
    entity_id BIGINT,
    entity_name VARCHAR(200),
    direct_ownership DECIMAL(5,2),
    effective_ownership DECIMAL(10,4),
    consolidation_method sys.consolidation_method_type,
    level INT,
    path BIGINT[]
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        vh.entity_id,
        vh.entity_name,
        vh.direct_ownership,
        vh.effective_ownership,
        vh.consolidation_method,
        vh.level,
        vh.path
    FROM sys.v_consolidation_hierarchy vh
    WHERE p_entity_id = ANY(vh.path)
       OR vh.entity_id = p_entity_id
    ORDER BY vh.path;
END;
$$;

COMMENT ON FUNCTION sys.rpc_calculate_effective_ownership IS 'Calculate effective ownership chain for an entity';

-- ----------------------------------------------------------------------------
-- 4.6 Create GAAP Mapping
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sys.rpc_create_gaap_mapping(
    p_entity_id BIGINT,
    p_source_gaap sys.gaap_framework,
    p_source_account VARCHAR(20),
    p_target_gaap sys.gaap_framework,
    p_target_account VARCHAR(20),
    p_adjustment_type sys.gaap_adjustment_type,
    p_adjustment_percentage DECIMAL(8,4) DEFAULT NULL,
    p_user_id BIGINT DEFAULT 0
) RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_mapping_id BIGINT;
BEGIN
    INSERT INTO sys.gaap_mappings (
        entity_id, source_gaap, source_account_code,
        target_gaap, target_account_code,
        adjustment_type, adjustment_percentage,
        created_by
    ) VALUES (
        p_entity_id, p_source_gaap, p_source_account,
        p_target_gaap, p_target_account,
        p_adjustment_type, p_adjustment_percentage,
        p_user_id
    )
    RETURNING mapping_id INTO v_mapping_id;

    RETURN v_mapping_id;
END;
$$;

COMMENT ON FUNCTION sys.rpc_create_gaap_mapping IS 'Create a GAAP mapping rule';

-- ============================================================================
-- SECTION 5: SEED DATA
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 5.1 OHADA Zone Countries
-- ----------------------------------------------------------------------------
INSERT INTO sys.countries (
    country_code, country_code_3, country_name, currency_code,
    language_code, fiscal_year_start_month, vat_standard_rate,
    corporate_tax_rate, economic_zone, primary_gaap
) VALUES
-- CEMAC Zone
('GA', 'GAB', 'Gabon', 'XAF', 'fr', 1, 18.00, 30.00, 'CEMAC', 'OHADA'),
('CM', 'CMR', 'Cameroun', 'XAF', 'fr', 1, 19.25, 33.00, 'CEMAC', 'OHADA'),
('CF', 'CAF', 'Centrafrique', 'XAF', 'fr', 1, 19.00, 30.00, 'CEMAC', 'OHADA'),
('TD', 'TCD', 'Tchad', 'XAF', 'fr', 1, 18.00, 35.00, 'CEMAC', 'OHADA'),
('CG', 'COG', 'Congo', 'XAF', 'fr', 1, 18.00, 30.00, 'CEMAC', 'OHADA'),
('GQ', 'GNQ', 'Guinée Équatoriale', 'XAF', 'es', 1, 15.00, 35.00, 'CEMAC', 'OHADA'),
-- UEMOA Zone
('BJ', 'BEN', 'Bénin', 'XOF', 'fr', 1, 18.00, 30.00, 'UEMOA', 'OHADA'),
('BF', 'BFA', 'Burkina Faso', 'XOF', 'fr', 1, 18.00, 27.50, 'UEMOA', 'OHADA'),
('CI', 'CIV', 'Côte d''Ivoire', 'XOF', 'fr', 1, 18.00, 25.00, 'UEMOA', 'OHADA'),
('GW', 'GNB', 'Guinée-Bissau', 'XOF', 'pt', 1, 17.00, 25.00, 'UEMOA', 'OHADA'),
('ML', 'MLI', 'Mali', 'XOF', 'fr', 1, 18.00, 30.00, 'UEMOA', 'OHADA'),
('NE', 'NER', 'Niger', 'XOF', 'fr', 1, 19.00, 30.00, 'UEMOA', 'OHADA'),
('SN', 'SEN', 'Sénégal', 'XOF', 'fr', 1, 18.00, 30.00, 'UEMOA', 'OHADA'),
('TG', 'TGO', 'Togo', 'XOF', 'fr', 1, 18.00, 27.00, 'UEMOA', 'OHADA'),
-- Non-CFA OHADA
('KM', 'COM', 'Comores', 'KMF', 'fr', 1, 10.00, 35.00, 'OHADA', 'OHADA'),
('GN', 'GIN', 'Guinée', 'GNF', 'fr', 1, 18.00, 35.00, 'OHADA', 'OHADA'),
('CD', 'COD', 'RD Congo', 'CDF', 'fr', 1, 16.00, 30.00, 'OHADA', 'OHADA')
ON CONFLICT (country_code) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 5.2 Major International Countries (for multinationals)
-- ----------------------------------------------------------------------------
INSERT INTO sys.countries (
    country_code, country_code_3, country_name, currency_code,
    language_code, fiscal_year_start_month, vat_standard_rate,
    corporate_tax_rate, economic_zone, primary_gaap
) VALUES
('FR', 'FRA', 'France', 'EUR', 'fr', 1, 20.00, 25.00, 'EU', 'IFRS'),
('DE', 'DEU', 'Allemagne', 'EUR', 'de', 1, 19.00, 29.90, 'EU', 'IFRS'),
('GB', 'GBR', 'Royaume-Uni', 'GBP', 'en', 4, 20.00, 25.00, 'UK', 'IFRS'),
('US', 'USA', 'États-Unis', 'USD', 'en', 1, 0.00, 21.00, 'NAFTA', 'US_GAAP'),
('CN', 'CHN', 'Chine', 'CNY', 'zh', 1, 13.00, 25.00, 'ASIA', 'IFRS'),
('AE', 'ARE', 'Émirats Arabes Unis', 'AED', 'ar', 1, 5.00, 9.00, 'GCC', 'IFRS'),
('MA', 'MAR', 'Maroc', 'MAD', 'fr', 1, 20.00, 31.00, 'MAGHREB', 'IFRS'),
('ZA', 'ZAF', 'Afrique du Sud', 'ZAR', 'en', 3, 15.00, 27.00, 'SADC', 'IFRS'),
('NG', 'NGA', 'Nigeria', 'NGN', 'en', 1, 7.50, 30.00, 'ECOWAS', 'IFRS')
ON CONFLICT (country_code) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 5.3 Sample Accounting Standards
-- ----------------------------------------------------------------------------
INSERT INTO sys.accounting_standards (
    gaap_framework, standard_code, standard_name, effective_date, topic_area
) VALUES
-- OHADA
('OHADA', 'SYSCOHADA', 'Système Comptable OHADA Révisé', '2018-01-01', 'General'),
('OHADA', 'SYSCOHADA-PME', 'SYSCOHADA Système Allégé PME', '2018-01-01', 'SME'),
-- IFRS
('IFRS', 'IFRS9', 'Financial Instruments', '2018-01-01', 'Financial Instruments'),
('IFRS', 'IFRS15', 'Revenue from Contracts with Customers', '2018-01-01', 'Revenue'),
('IFRS', 'IFRS16', 'Leases', '2019-01-01', 'Leases'),
('IFRS', 'IAS21', 'Effects of Changes in Foreign Exchange Rates', '2005-01-01', 'Foreign Currency'),
('IFRS', 'IAS36', 'Impairment of Assets', '2004-03-31', 'Impairment'),
-- IPSAS
('IPSAS', 'IPSAS1', 'Presentation of Financial Statements', '2017-01-01', 'Presentation'),
('IPSAS', 'IPSAS23', 'Revenue from Non-Exchange Transactions', '2017-01-01', 'Revenue')
ON CONFLICT (gaap_framework, standard_code, effective_date) DO NOTHING;

-- ============================================================================
-- SECTION 6: GRANTS
-- ============================================================================

-- Grant execute on functions
GRANT EXECUTE ON FUNCTION sys.rpc_get_entity_legal_config(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION sys.rpc_convert_gaap(BIGINT, sys.gaap_framework, sys.gaap_framework, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION sys.rpc_register_legal_entity(BIGINT, VARCHAR, sys.legal_form_type, VARCHAR, VARCHAR, VARCHAR, sys.gaap_framework, BIGINT, DECIMAL, BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION sys.rpc_get_country_tax_config(VARCHAR, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION sys.rpc_calculate_effective_ownership(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION sys.rpc_create_gaap_mapping(BIGINT, sys.gaap_framework, VARCHAR, sys.gaap_framework, VARCHAR, sys.gaap_adjustment_type, DECIMAL, BIGINT) TO authenticated;

-- Grant select on views
GRANT SELECT ON sys.v_entity_legal_summary TO authenticated;
GRANT SELECT ON sys.v_gaap_mapping_summary TO authenticated;
GRANT SELECT ON sys.v_consolidation_hierarchy TO authenticated;
GRANT SELECT ON sys.v_country_tax_summary TO authenticated;

-- ============================================================================
-- END OF MODULE 01: MULTI-COUNTRY
-- ============================================================================
