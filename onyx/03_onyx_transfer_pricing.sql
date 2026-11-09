-- ============================================================================
-- Fix déploiement (Sprint 1) : FK -> common.currencies(code) (et non currency_code,
-- colonne inexistante). ROLLBACK : rétablir common.currencies(currency_code) si
-- la colonne de référence est renommée. Voir SPRINT1_GAMMES_BUILD.md.
-- EdenFin ONYX - Module 03: Transfer Pricing
-- ============================================================================
-- Version: 1.0.0
-- Date: 2026-02-11
-- Description: Transfer pricing compliance - policies, documentation,
--              benchmarking, Country-by-Country Reporting (CbCR)
-- Dependencies: JASPE (00-09), RUBIS (01-03), SAPHIR (01-05), ONYX (01-02)
-- ============================================================================

-- ============================================================================
-- SECTION 1: ENUMS
-- ============================================================================

-- Transaction types for transfer pricing
CREATE TYPE sys.tp_transaction_type AS ENUM (
    'GOODS',                -- Tangible goods
    'SERVICES',             -- Services (management, technical, etc.)
    'ROYALTIES',            -- IP licensing, royalties
    'INTEREST',             -- Intercompany financing
    'COST_SHARING',         -- R&D cost sharing
    'GUARANTEE',            -- Financial guarantees
    'RENT',                 -- Property/equipment rental
    'OTHER'
);

-- OECD-approved pricing methods
CREATE TYPE sys.tp_pricing_method AS ENUM (
    'CUP',                  -- Comparable Uncontrolled Price
    'COST_PLUS',            -- Cost Plus Method
    'RESALE_MINUS',         -- Resale Price Method
    'TNMM',                 -- Transactional Net Margin Method
    'PSM',                  -- Profit Split Method
    'OTHER'                 -- Other method with justification
);

-- Documentation types
CREATE TYPE sys.tp_documentation_type AS ENUM (
    'MASTER_FILE',          -- Group-level documentation
    'LOCAL_FILE',           -- Entity-level documentation
    'CBCR',                 -- Country-by-Country Report
    'BENCHMARKING_STUDY',   -- Comparables analysis
    'APA',                  -- Advance Pricing Agreement
    'MAP',                  -- Mutual Agreement Procedure
    'AUDIT_RESPONSE'        -- Response to tax audit
);

-- Comparable search status
CREATE TYPE sys.comparable_status AS ENUM (
    'IDENTIFIED',           -- Found in database
    'SCREENED',             -- Passed initial filters
    'ACCEPTED',             -- Final comparable
    'REJECTED',             -- Rejected with reason
    'SUPERSEDED'            -- Replaced by newer search
);

-- Arm's length test result
CREATE TYPE sys.al_test_result AS ENUM (
    'WITHIN_RANGE',         -- Price within IQR
    'BELOW_RANGE',          -- Price below Q1
    'ABOVE_RANGE',          -- Price above Q3
    'AT_MEDIAN',            -- Adjustment to median
    'PENDING',              -- Test not complete
    'WAIVED'                -- Test waived (de minimis, etc.)
);

-- CbCR submission status
CREATE TYPE sys.cbcr_status AS ENUM (
    'DRAFT',                -- Being prepared
    'REVIEW',               -- Under review
    'APPROVED',             -- Ready to submit
    'SUBMITTED',            -- Submitted to authority
    'ACCEPTED',             -- Accepted by authority
    'REJECTED',             -- Rejected, needs correction
    'AMENDED'               -- Amendment submitted
);

-- Functional characterization
CREATE TYPE sys.functional_profile AS ENUM (
    'FULL_FLEDGED',         -- Full entrepreneur
    'LIMITED_RISK',         -- Limited risk distributor/manufacturer
    'CONTRACT_MANUFACTURER', -- Toll manufacturing
    'COMMISSIONAIRE',       -- Sales agent
    'SERVICE_PROVIDER',     -- Routine service provider
    'IP_OWNER',             -- Principal/IP owner
    'FINANCING_ENTITY',     -- Group treasury
    'HOLDING'               -- Passive holding
);

-- ============================================================================
-- SECTION 2: TRANSFER PRICING POLICIES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 2.1 Transfer Pricing Policies
-- ----------------------------------------------------------------------------
CREATE TABLE sys.transfer_pricing_policies (
    policy_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    policy_code VARCHAR(30) NOT NULL,
    policy_name VARCHAR(200) NOT NULL,
    policy_description TEXT,

    -- Counterparties
    entity_from_id BIGINT NOT NULL REFERENCES sys.tenant_entities(entity_id),
    entity_to_id BIGINT NOT NULL REFERENCES sys.tenant_entities(entity_id),

    -- Transaction classification
    transaction_type sys.tp_transaction_type NOT NULL,
    transaction_description TEXT,

    -- Pricing method
    pricing_method sys.tp_pricing_method NOT NULL,
    pricing_method_justification TEXT,

    -- Functional analysis
    entity_from_profile sys.functional_profile,
    entity_to_profile sys.functional_profile,
    functions_performed TEXT,           -- Functions, assets, risks analysis
    assets_used TEXT,
    risks_assumed TEXT,

    -- Pricing parameters
    base_indicator VARCHAR(50),         -- e.g., 'OPERATING_COST', 'NET_SALES'
    markup_percentage DECIMAL(8,4),     -- For cost-plus
    margin_percentage DECIMAL(8,4),     -- For resale-minus/TNMM
    profit_split_key VARCHAR(50),       -- For PSM (e.g., 'HEADCOUNT', 'R&D_SPEND')

    -- Arm's length range (from benchmarking)
    comparable_range_q1 DECIMAL(8,4),   -- First quartile
    comparable_range_median DECIMAL(8,4), -- Median (interquartile)
    comparable_range_q3 DECIMAL(8,4),   -- Third quartile
    comparable_range_min DECIMAL(8,4),  -- Full range min
    comparable_range_max DECIMAL(8,4),  -- Full range max

    -- Validity
    effective_from DATE NOT NULL,
    effective_to DATE,
    renewal_reminder_days INT DEFAULT 90,

    -- Approval
    approved_by BIGINT,
    approved_at TIMESTAMPTZ,
    approval_notes TEXT,

    -- Documentation reference
    master_file_ref VARCHAR(100),
    local_file_ref VARCHAR(100),

    -- Status
    is_active BOOLEAN DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,

    UNIQUE (policy_code),
    CHECK (entity_from_id <> entity_to_id)
);

CREATE INDEX idx_tp_policies_from_entity ON sys.transfer_pricing_policies(entity_from_id);
CREATE INDEX idx_tp_policies_to_entity ON sys.transfer_pricing_policies(entity_to_id);
CREATE INDEX idx_tp_policies_type ON sys.transfer_pricing_policies(transaction_type);
CREATE INDEX idx_tp_policies_active ON sys.transfer_pricing_policies(is_active) WHERE is_active = TRUE;

COMMENT ON TABLE sys.transfer_pricing_policies IS 'Intercompany transfer pricing policies with OECD-compliant methods';

-- ----------------------------------------------------------------------------
-- 2.2 TP Transactions
-- ----------------------------------------------------------------------------
CREATE TABLE sys.tp_transactions (
    transaction_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    policy_id BIGINT NOT NULL REFERENCES sys.transfer_pricing_policies(policy_id),

    -- Transaction details
    transaction_date DATE NOT NULL,
    transaction_reference VARCHAR(50),
    fiscal_year INT NOT NULL,
    fiscal_period INT,                  -- Month or quarter

    -- Source document
    source_document_type VARCHAR(30),   -- INVOICE, CREDIT_NOTE, etc.
    source_document_id BIGINT,
    source_document_ref VARCHAR(50),

    -- Amounts
    currency_code VARCHAR(3) NOT NULL REFERENCES common.currencies(code),
    amount_charged DECIMAL(18,2) NOT NULL,
    quantity DECIMAL(18,4),
    unit_price DECIMAL(18,6),

    -- Arm's length calculation
    base_amount DECIMAL(18,2),          -- Base for markup/margin calculation
    arm_length_amount DECIMAL(18,2),
    variance DECIMAL(18,2) GENERATED ALWAYS AS (amount_charged - arm_length_amount) STORED,
    variance_pct DECIMAL(8,4) GENERATED ALWAYS AS (
        CASE WHEN arm_length_amount <> 0
             THEN ((amount_charged - arm_length_amount) / ABS(arm_length_amount)) * 100
             ELSE NULL
        END
    ) STORED,

    -- Adjustment
    adjustment_required BOOLEAN DEFAULT FALSE,
    adjustment_amount DECIMAL(18,2),
    adjustment_direction VARCHAR(10),   -- INCREASE, DECREASE
    adjustment_reason TEXT,

    -- Test result
    al_test_result sys.al_test_result DEFAULT 'PENDING',
    tested_at TIMESTAMPTZ,
    tested_by BIGINT,

    -- Status
    is_included_in_filing BOOLEAN DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0
);

CREATE INDEX idx_tp_txn_policy ON sys.tp_transactions(policy_id);
CREATE INDEX idx_tp_txn_date ON sys.tp_transactions(transaction_date);
CREATE INDEX idx_tp_txn_year ON sys.tp_transactions(fiscal_year);
CREATE INDEX idx_tp_txn_adjustment ON sys.tp_transactions(adjustment_required) WHERE adjustment_required = TRUE;

COMMENT ON TABLE sys.tp_transactions IS 'Individual intercompany transactions subject to transfer pricing';

-- ============================================================================
-- SECTION 3: DOCUMENTATION
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 3.1 TP Documentation
-- ----------------------------------------------------------------------------
CREATE TABLE sys.tp_documentation (
    document_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    document_type sys.tp_documentation_type NOT NULL,
    document_reference VARCHAR(50) NOT NULL,
    document_title VARCHAR(200) NOT NULL,

    -- Scope
    entity_id BIGINT REFERENCES sys.tenant_entities(entity_id),  -- NULL for Master File
    fiscal_year INT NOT NULL,
    reporting_period_start DATE,
    reporting_period_end DATE,

    -- Content
    description TEXT,
    executive_summary TEXT,

    -- File storage
    file_path TEXT,
    file_name VARCHAR(255),
    file_size_bytes BIGINT,
    file_hash VARCHAR(64),              -- SHA-256 for integrity
    mime_type VARCHAR(100),

    -- Version control
    version_number INT NOT NULL DEFAULT 1,
    previous_version_id BIGINT REFERENCES sys.tp_documentation(document_id),

    -- Review and approval
    prepared_by BIGINT,
    prepared_at TIMESTAMPTZ,
    reviewed_by BIGINT,
    reviewed_at TIMESTAMPTZ,
    approved_by BIGINT,
    approved_at TIMESTAMPTZ,
    approval_notes TEXT,

    -- Deadlines
    statutory_deadline DATE,
    internal_deadline DATE,

    -- Status
    status VARCHAR(20) DEFAULT 'DRAFT',  -- DRAFT, REVIEW, APPROVED, FILED

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,

    UNIQUE (document_reference)
);

CREATE INDEX idx_tp_doc_type ON sys.tp_documentation(document_type);
CREATE INDEX idx_tp_doc_entity ON sys.tp_documentation(entity_id);
CREATE INDEX idx_tp_doc_year ON sys.tp_documentation(fiscal_year);
CREATE INDEX idx_tp_doc_deadline ON sys.tp_documentation(statutory_deadline);

COMMENT ON TABLE sys.tp_documentation IS 'Transfer pricing documentation (Master File, Local Files, etc.)';

-- ----------------------------------------------------------------------------
-- 3.2 Documentation Sections (for Master/Local Files)
-- ----------------------------------------------------------------------------
CREATE TABLE sys.tp_documentation_sections (
    section_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    document_id BIGINT NOT NULL REFERENCES sys.tp_documentation(document_id) ON DELETE CASCADE,

    -- Section info
    section_number VARCHAR(20) NOT NULL,  -- e.g., "1.2.3"
    section_title VARCHAR(200) NOT NULL,
    section_content TEXT,

    -- OECD Annex reference (for Master/Local Files)
    oecd_annex_ref VARCHAR(50),         -- e.g., "Annex I Chapter V, para 5.16"

    -- Order
    display_order INT DEFAULT 0,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE INDEX idx_tp_doc_section ON sys.tp_documentation_sections(document_id);

COMMENT ON TABLE sys.tp_documentation_sections IS 'Sections within TP documentation';

-- ============================================================================
-- SECTION 4: BENCHMARKING
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 4.1 Benchmarking Studies
-- ----------------------------------------------------------------------------
CREATE TABLE sys.tp_benchmarking_studies (
    study_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    study_reference VARCHAR(50) NOT NULL,
    study_name VARCHAR(200) NOT NULL,

    -- Scope
    policy_id BIGINT REFERENCES sys.transfer_pricing_policies(policy_id),
    fiscal_year INT NOT NULL,
    region VARCHAR(50),                 -- Geographic scope

    -- Search strategy
    database_used VARCHAR(100),         -- e.g., 'Orbis', 'TP Catalyst', 'RoyaltyStat'
    search_date DATE NOT NULL,
    search_criteria JSONB,              -- Detailed search parameters

    -- Industry classification
    sic_codes VARCHAR[],
    nace_codes VARCHAR[],
    industry_description TEXT,

    -- Financial filters
    revenue_min DECIMAL(18,2),
    revenue_max DECIMAL(18,2),
    employee_min INT,
    employee_max INT,
    independence_criteria TEXT,

    -- Results
    initial_companies_found INT,
    after_quantitative_screen INT,
    after_qualitative_screen INT,
    final_comparables_count INT,

    -- Statistical results
    profit_indicator VARCHAR(50),       -- Operating margin, Berry ratio, etc.
    range_q1 DECIMAL(8,4),
    range_median DECIMAL(8,4),
    range_q3 DECIMAL(8,4),
    range_mean DECIMAL(8,4),
    range_std_dev DECIMAL(8,4),

    -- Validity
    valid_from DATE,
    valid_to DATE,

    -- Status
    status VARCHAR(20) DEFAULT 'DRAFT',

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,

    UNIQUE (study_reference)
);

CREATE INDEX idx_tp_study_policy ON sys.tp_benchmarking_studies(policy_id);
CREATE INDEX idx_tp_study_year ON sys.tp_benchmarking_studies(fiscal_year);

COMMENT ON TABLE sys.tp_benchmarking_studies IS 'Benchmarking studies for comparable analysis';

-- ----------------------------------------------------------------------------
-- 4.2 Comparable Companies
-- ----------------------------------------------------------------------------
CREATE TABLE sys.tp_comparables (
    comparable_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    study_id BIGINT NOT NULL REFERENCES sys.tp_benchmarking_studies(study_id) ON DELETE CASCADE,

    -- Company identification
    company_name VARCHAR(200) NOT NULL,
    company_id_bvd VARCHAR(50),         -- Bureau van Dijk ID
    country_code VARCHAR(2),
    sic_code VARCHAR(10),
    nace_code VARCHAR(10),

    -- Status in study
    status sys.comparable_status NOT NULL DEFAULT 'IDENTIFIED',
    rejection_reason TEXT,

    -- Functional analysis
    functional_description TEXT,
    is_functionally_comparable BOOLEAN,

    -- Financial data (weighted average or multi-year)
    data_years VARCHAR(50),             -- e.g., "2022-2024"
    revenue DECIMAL(18,2),
    operating_profit DECIMAL(18,2),
    total_assets DECIMAL(18,2),
    employees INT,

    -- Profit level indicator
    operating_margin DECIMAL(8,4),
    return_on_assets DECIMAL(8,4),
    return_on_sales DECIMAL(8,4),
    berry_ratio DECIMAL(8,4),
    cost_plus_markup DECIMAL(8,4),

    -- Adjustments
    working_capital_adjustment DECIMAL(8,4),
    adjusted_margin DECIMAL(8,4),

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tp_comp_study ON sys.tp_comparables(study_id);
CREATE INDEX idx_tp_comp_status ON sys.tp_comparables(status);
CREATE INDEX idx_tp_comp_country ON sys.tp_comparables(country_code);

COMMENT ON TABLE sys.tp_comparables IS 'Comparable companies in benchmarking studies';

-- ============================================================================
-- SECTION 5: ARM'S LENGTH TESTING
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 5.1 Arm's Length Tests
-- ----------------------------------------------------------------------------
CREATE TABLE sys.arm_length_tests (
    test_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    policy_id BIGINT NOT NULL REFERENCES sys.transfer_pricing_policies(policy_id),
    study_id BIGINT REFERENCES sys.tp_benchmarking_studies(study_id),

    -- Test scope
    fiscal_year INT NOT NULL,
    test_date DATE NOT NULL,
    test_period_start DATE,
    test_period_end DATE,

    -- Tested party
    tested_entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(entity_id),
    tested_party_role VARCHAR(50),      -- 'seller', 'buyer', 'licensor', etc.

    -- Profit level indicator
    profit_indicator VARCHAR(50) NOT NULL,  -- Operating margin, TNMM, etc.
    indicator_numerator VARCHAR(100),   -- e.g., 'Operating profit'
    indicator_denominator VARCHAR(100), -- e.g., 'Net sales'

    -- Actual results
    actual_value DECIMAL(8,4) NOT NULL,
    actual_amount DECIMAL(18,2),

    -- Benchmark range
    range_q1 DECIMAL(8,4),
    range_median DECIMAL(8,4),
    range_q3 DECIMAL(8,4),

    -- Test result
    result sys.al_test_result NOT NULL,
    is_within_iqr BOOLEAN GENERATED ALWAYS AS (
        actual_value >= range_q1 AND actual_value <= range_q3
    ) STORED,

    -- Adjustment (if needed)
    adjustment_target VARCHAR(20),      -- 'Q1', 'MEDIAN', 'Q3'
    adjustment_required BOOLEAN DEFAULT FALSE,
    adjustment_amount DECIMAL(18,2),
    adjustment_currency VARCHAR(3),

    -- Commentary
    analysis_notes TEXT,
    conclusion TEXT,

    -- Approval
    performed_by BIGINT,
    reviewed_by BIGINT,
    approved_by BIGINT,
    approved_at TIMESTAMPTZ,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0
);

CREATE INDEX idx_al_test_policy ON sys.arm_length_tests(policy_id);
CREATE INDEX idx_al_test_entity ON sys.arm_length_tests(tested_entity_id);
CREATE INDEX idx_al_test_year ON sys.arm_length_tests(fiscal_year);
CREATE INDEX idx_al_test_result ON sys.arm_length_tests(result);

COMMENT ON TABLE sys.arm_length_tests IS 'Annual arm''s length testing results';

-- ============================================================================
-- SECTION 6: COUNTRY-BY-COUNTRY REPORTING
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 6.1 CbCR Reports
-- ----------------------------------------------------------------------------
CREATE TABLE sys.cbcr_reports (
    report_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    report_reference VARCHAR(50) NOT NULL,

    -- Reporting entity
    group_entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(entity_id),
    ultimate_parent_name VARCHAR(200),
    ultimate_parent_jurisdiction VARCHAR(2),
    ultimate_parent_tax_id VARCHAR(50),

    -- Reporting period
    reporting_fiscal_year INT NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,

    -- Submission
    submission_jurisdiction VARCHAR(2) NOT NULL,  -- Where report is filed
    submission_authority VARCHAR(100),
    submission_deadline DATE,
    submission_status sys.cbcr_status NOT NULL DEFAULT 'DRAFT',
    submission_date TIMESTAMPTZ,
    confirmation_number VARCHAR(100),

    -- Exchange arrangements
    exchange_jurisdictions TEXT[],      -- Jurisdictions receiving via exchange

    -- Surrogate filing (if applicable)
    is_surrogate_filing BOOLEAN DEFAULT FALSE,
    surrogate_entity_id BIGINT REFERENCES sys.tenant_entities(entity_id),
    surrogate_jurisdiction VARCHAR(2),

    -- Notifications
    notification_filed BOOLEAN DEFAULT FALSE,
    notification_date DATE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,

    UNIQUE (report_reference)
);

CREATE INDEX idx_cbcr_group ON sys.cbcr_reports(group_entity_id);
CREATE INDEX idx_cbcr_year ON sys.cbcr_reports(reporting_fiscal_year);
CREATE INDEX idx_cbcr_status ON sys.cbcr_reports(submission_status);
CREATE INDEX idx_cbcr_deadline ON sys.cbcr_reports(submission_deadline);

COMMENT ON TABLE sys.cbcr_reports IS 'Country-by-Country Report headers';

-- ----------------------------------------------------------------------------
-- 6.2 CbCR Jurisdiction Data (Table 1)
-- ----------------------------------------------------------------------------
CREATE TABLE sys.cbcr_jurisdiction_data (
    data_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    report_id BIGINT NOT NULL REFERENCES sys.cbcr_reports(report_id) ON DELETE CASCADE,

    -- Jurisdiction
    jurisdiction_code VARCHAR(2) NOT NULL,
    jurisdiction_name VARCHAR(100),

    -- Table 1 data (OECD format)
    revenues_unrelated DECIMAL(18,2) NOT NULL DEFAULT 0,
    revenues_related DECIMAL(18,2) NOT NULL DEFAULT 0,
    revenues_total DECIMAL(18,2) GENERATED ALWAYS AS (revenues_unrelated + revenues_related) STORED,

    profit_loss_before_tax DECIMAL(18,2) NOT NULL DEFAULT 0,

    income_tax_paid_cash DECIMAL(18,2) NOT NULL DEFAULT 0,
    income_tax_accrued DECIMAL(18,2) NOT NULL DEFAULT 0,

    stated_capital DECIMAL(18,2) NOT NULL DEFAULT 0,
    accumulated_earnings DECIMAL(18,2) NOT NULL DEFAULT 0,

    number_of_employees INT NOT NULL DEFAULT 0,
    tangible_assets DECIMAL(18,2) NOT NULL DEFAULT 0,

    -- Derived metrics
    effective_tax_rate DECIMAL(8,4) GENERATED ALWAYS AS (
        CASE WHEN profit_loss_before_tax > 0
             THEN income_tax_accrued / profit_loss_before_tax
             ELSE NULL
        END
    ) STORED,

    -- Source currency (before conversion to reporting currency)
    source_currency VARCHAR(3),
    exchange_rate_used DECIMAL(18,8),

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (report_id, jurisdiction_code)
);

CREATE INDEX idx_cbcr_data_report ON sys.cbcr_jurisdiction_data(report_id);
CREATE INDEX idx_cbcr_data_jurisdiction ON sys.cbcr_jurisdiction_data(jurisdiction_code);

COMMENT ON TABLE sys.cbcr_jurisdiction_data IS 'CbCR Table 1 - Aggregate data by jurisdiction';

-- ----------------------------------------------------------------------------
-- 6.3 CbCR Entity Data (Table 2)
-- ----------------------------------------------------------------------------
CREATE TABLE sys.cbcr_entity_data (
    entity_data_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    report_id BIGINT NOT NULL REFERENCES sys.cbcr_reports(report_id) ON DELETE CASCADE,

    -- Jurisdiction (links to Table 1)
    jurisdiction_code VARCHAR(2) NOT NULL,

    -- Entity identification
    entity_id BIGINT REFERENCES sys.tenant_entities(entity_id),
    entity_name VARCHAR(200) NOT NULL,
    entity_jurisdiction_tax_id VARCHAR(50),

    -- Incorporation vs residence
    jurisdiction_of_incorporation VARCHAR(2),
    jurisdiction_of_tax_residence VARCHAR(2),

    -- Main business activities (OECD codes)
    activity_research_development BOOLEAN DEFAULT FALSE,
    activity_holding_ip BOOLEAN DEFAULT FALSE,
    activity_purchasing_procurement BOOLEAN DEFAULT FALSE,
    activity_manufacturing BOOLEAN DEFAULT FALSE,
    activity_sales_marketing BOOLEAN DEFAULT FALSE,
    activity_administrative_support BOOLEAN DEFAULT FALSE,
    activity_provision_services BOOLEAN DEFAULT FALSE,
    activity_internal_finance BOOLEAN DEFAULT FALSE,
    activity_regulated_financial BOOLEAN DEFAULT FALSE,
    activity_insurance BOOLEAN DEFAULT FALSE,
    activity_holding_shares BOOLEAN DEFAULT FALSE,
    activity_dormant BOOLEAN DEFAULT FALSE,
    activity_other BOOLEAN DEFAULT FALSE,
    activity_other_description VARCHAR(200),

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_cbcr_entity_report ON sys.cbcr_entity_data(report_id);
CREATE INDEX idx_cbcr_entity_jurisdiction ON sys.cbcr_entity_data(jurisdiction_code);
CREATE INDEX idx_cbcr_entity_id ON sys.cbcr_entity_data(entity_id);

COMMENT ON TABLE sys.cbcr_entity_data IS 'CbCR Table 2 - Entity list by jurisdiction';

-- ----------------------------------------------------------------------------
-- 6.4 CbCR Additional Info (Table 3)
-- ----------------------------------------------------------------------------
CREATE TABLE sys.cbcr_additional_info (
    info_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    report_id BIGINT NOT NULL REFERENCES sys.cbcr_reports(report_id) ON DELETE CASCADE,

    -- Reference
    jurisdiction_code VARCHAR(2),
    entity_id BIGINT REFERENCES sys.tenant_entities(entity_id),

    -- Additional information
    info_type VARCHAR(50) NOT NULL,     -- SOURCE_DATA, EXCHANGE_RATES, OTHER
    description TEXT NOT NULL,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_cbcr_info_report ON sys.cbcr_additional_info(report_id);

COMMENT ON TABLE sys.cbcr_additional_info IS 'CbCR Table 3 - Additional information';

-- ============================================================================
-- SECTION 7: VIEWS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 7.1 TP Policy Summary
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW sys.v_tp_policy_summary AS
SELECT
    p.policy_id,
    p.policy_code,
    p.policy_name,
    ef.entity_code AS entity_from_code,
    ef.entity_name AS entity_from_name,
    et.entity_code AS entity_to_code,
    et.entity_name AS entity_to_name,
    p.transaction_type,
    p.pricing_method,
    p.markup_percentage,
    p.margin_percentage,
    p.comparable_range_q1,
    p.comparable_range_median,
    p.comparable_range_q3,
    p.effective_from,
    p.effective_to,
    p.is_active,
    -- Transaction statistics
    COUNT(t.transaction_id) AS transaction_count,
    SUM(t.amount_charged) AS total_amount,
    SUM(CASE WHEN t.adjustment_required THEN 1 ELSE 0 END) AS adjustments_needed
FROM sys.transfer_pricing_policies p
JOIN sys.tenant_entities ef ON p.entity_from_id = ef.entity_id
JOIN sys.tenant_entities et ON p.entity_to_id = et.entity_id
LEFT JOIN sys.tp_transactions t ON p.policy_id = t.policy_id
GROUP BY p.policy_id, p.policy_code, p.policy_name,
         ef.entity_code, ef.entity_name, et.entity_code, et.entity_name,
         p.transaction_type, p.pricing_method, p.markup_percentage,
         p.margin_percentage, p.comparable_range_q1, p.comparable_range_median,
         p.comparable_range_q3, p.effective_from, p.effective_to, p.is_active;

COMMENT ON VIEW sys.v_tp_policy_summary IS 'Transfer pricing policy overview with transaction statistics';

-- ----------------------------------------------------------------------------
-- 7.2 Arm's Length Test Results
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW sys.v_al_test_results AS
SELECT
    t.test_id,
    p.policy_code,
    e.entity_code AS tested_entity,
    t.fiscal_year,
    t.profit_indicator,
    t.actual_value,
    t.range_q1,
    t.range_median,
    t.range_q3,
    t.result,
    t.is_within_iqr,
    t.adjustment_required,
    t.adjustment_amount,
    t.test_date
FROM sys.arm_length_tests t
JOIN sys.transfer_pricing_policies p ON t.policy_id = p.policy_id
JOIN sys.tenant_entities e ON t.tested_entity_id = e.entity_id
ORDER BY t.fiscal_year DESC, t.test_date DESC;

COMMENT ON VIEW sys.v_al_test_results IS 'Arm''s length test results summary';

-- ----------------------------------------------------------------------------
-- 7.3 CbCR Summary
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW sys.v_cbcr_summary AS
SELECT
    r.report_id,
    r.report_reference,
    e.entity_name AS group_entity,
    r.reporting_fiscal_year,
    r.submission_jurisdiction,
    r.submission_status,
    r.submission_deadline,
    COUNT(DISTINCT d.jurisdiction_code) AS jurisdictions_count,
    SUM(d.revenues_total) AS total_revenues,
    SUM(d.profit_loss_before_tax) AS total_profit_before_tax,
    SUM(d.income_tax_paid_cash) AS total_tax_paid,
    SUM(d.number_of_employees) AS total_employees,
    SUM(d.tangible_assets) AS total_tangible_assets
FROM sys.cbcr_reports r
JOIN sys.tenant_entities e ON r.group_entity_id = e.entity_id
LEFT JOIN sys.cbcr_jurisdiction_data d ON r.report_id = d.report_id
GROUP BY r.report_id, r.report_reference, e.entity_name,
         r.reporting_fiscal_year, r.submission_jurisdiction,
         r.submission_status, r.submission_deadline;

COMMENT ON VIEW sys.v_cbcr_summary IS 'CbCR report summary with aggregates';

-- ----------------------------------------------------------------------------
-- 7.4 TP Documentation Status
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW sys.v_tp_documentation_status AS
SELECT
    d.document_id,
    d.document_type,
    d.document_reference,
    d.document_title,
    e.entity_code,
    e.entity_name,
    d.fiscal_year,
    d.status,
    d.statutory_deadline,
    d.statutory_deadline - CURRENT_DATE AS days_until_deadline,
    d.prepared_at,
    d.reviewed_at,
    d.approved_at
FROM sys.tp_documentation d
LEFT JOIN sys.tenant_entities e ON d.entity_id = e.entity_id
WHERE d.status NOT IN ('FILED', 'ARCHIVED')
ORDER BY d.statutory_deadline;

COMMENT ON VIEW sys.v_tp_documentation_status IS 'TP documentation status and deadlines';

-- ============================================================================
-- SECTION 8: RPC FUNCTIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 8.1 Validate TP Transaction
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sys.rpc_validate_tp_transaction(
    p_transaction_id BIGINT,
    p_user_id BIGINT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_txn RECORD;
    v_policy RECORD;
    v_al_amount DECIMAL(18,2);
    v_variance DECIMAL(18,2);
    v_result sys.al_test_result;
    v_adjustment_required BOOLEAN := FALSE;
    v_adjustment_amount DECIMAL(18,2);
BEGIN
    -- Get transaction
    SELECT * INTO v_txn FROM sys.tp_transactions WHERE transaction_id = p_transaction_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Transaction not found');
    END IF;

    -- Get policy
    SELECT * INTO v_policy FROM sys.transfer_pricing_policies WHERE policy_id = v_txn.policy_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Policy not found');
    END IF;

    -- Calculate arm's length amount based on method
    CASE v_policy.pricing_method
        WHEN 'COST_PLUS' THEN
            v_al_amount := COALESCE(v_txn.base_amount, 0) * (1 + COALESCE(v_policy.markup_percentage, 0) / 100);
        WHEN 'RESALE_MINUS' THEN
            v_al_amount := v_txn.amount_charged / (1 - COALESCE(v_policy.margin_percentage, 0) / 100);
        WHEN 'TNMM' THEN
            -- Use median as target
            v_al_amount := COALESCE(v_txn.base_amount, 0) * (1 + COALESCE(v_policy.comparable_range_median, 0) / 100);
        ELSE
            -- CUP or other - use amount as is
            v_al_amount := v_txn.amount_charged;
    END CASE;

    -- Calculate variance
    v_variance := v_txn.amount_charged - v_al_amount;

    -- Determine result
    IF v_policy.comparable_range_q1 IS NOT NULL AND v_policy.comparable_range_q3 IS NOT NULL THEN
        DECLARE
            v_actual_margin DECIMAL(8,4);
        BEGIN
            -- Calculate actual margin
            IF v_txn.base_amount IS NOT NULL AND v_txn.base_amount <> 0 THEN
                v_actual_margin := ((v_txn.amount_charged - v_txn.base_amount) / v_txn.base_amount) * 100;
            ELSE
                v_actual_margin := 0;
            END IF;

            IF v_actual_margin >= v_policy.comparable_range_q1 AND v_actual_margin <= v_policy.comparable_range_q3 THEN
                v_result := 'WITHIN_RANGE';
            ELSIF v_actual_margin < v_policy.comparable_range_q1 THEN
                v_result := 'BELOW_RANGE';
                v_adjustment_required := TRUE;
                v_adjustment_amount := v_al_amount - v_txn.amount_charged;
            ELSE
                v_result := 'ABOVE_RANGE';
                v_adjustment_required := TRUE;
                v_adjustment_amount := v_txn.amount_charged - v_al_amount;
            END IF;
        END;
    ELSE
        v_result := 'PENDING';
    END IF;

    -- Update transaction
    UPDATE sys.tp_transactions
    SET arm_length_amount = v_al_amount,
        adjustment_required = v_adjustment_required,
        adjustment_amount = v_adjustment_amount,
        al_test_result = v_result,
        tested_at = NOW(),
        tested_by = p_user_id
    WHERE transaction_id = p_transaction_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'transaction_id', p_transaction_id,
        'amount_charged', v_txn.amount_charged,
        'arm_length_amount', v_al_amount,
        'variance', v_variance,
        'result', v_result,
        'adjustment_required', v_adjustment_required,
        'adjustment_amount', v_adjustment_amount
    );
END;
$$;

COMMENT ON FUNCTION sys.rpc_validate_tp_transaction IS 'Validate a TP transaction against arm''s length standard';

-- ----------------------------------------------------------------------------
-- 8.2 Generate CbCR Report
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sys.rpc_generate_cbcr_report(
    p_group_entity_id BIGINT,
    p_fiscal_year INT,
    p_submission_jurisdiction VARCHAR(2),
    p_user_id BIGINT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_report_id BIGINT;
    v_report_reference VARCHAR(50);
    v_group_entity RECORD;
    v_jurisdiction_count INT := 0;
BEGIN
    -- Validate group entity
    SELECT * INTO v_group_entity
    FROM sys.tenant_entities
    WHERE entity_id = p_group_entity_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Group entity not found');
    END IF;

    -- Generate reference
    v_report_reference := 'CBCR-' || p_fiscal_year || '-' || v_group_entity.entity_code;

    -- Check if already exists
    IF EXISTS (SELECT 1 FROM sys.cbcr_reports WHERE report_reference = v_report_reference) THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'CbCR report already exists for this year');
    END IF;

    -- Create report
    INSERT INTO sys.cbcr_reports (
        report_reference,
        group_entity_id,
        ultimate_parent_name,
        ultimate_parent_jurisdiction,
        reporting_fiscal_year,
        period_start,
        period_end,
        submission_jurisdiction,
        submission_deadline,
        created_by
    ) VALUES (
        v_report_reference,
        p_group_entity_id,
        v_group_entity.entity_name,
        (SELECT country_code FROM sys.legal_entity_registry WHERE entity_id = p_group_entity_id),
        p_fiscal_year,
        make_date(p_fiscal_year, 1, 1),
        make_date(p_fiscal_year, 12, 31),
        p_submission_jurisdiction,
        make_date(p_fiscal_year + 1, 12, 31),  -- Typically 12 months after year-end
        p_user_id
    )
    RETURNING report_id INTO v_report_id;

    -- Populate jurisdiction data from legal entity registry
    INSERT INTO sys.cbcr_jurisdiction_data (
        report_id,
        jurisdiction_code,
        jurisdiction_name,
        revenues_unrelated,
        revenues_related,
        profit_loss_before_tax,
        income_tax_paid_cash,
        income_tax_accrued,
        stated_capital,
        accumulated_earnings,
        number_of_employees,
        tangible_assets
    )
    SELECT
        v_report_id,
        ler.country_code,
        c.country_name,
        0, 0, 0, 0, 0, 0, 0, 0, 0  -- Placeholder values to be filled
    FROM sys.legal_entity_registry ler
    JOIN sys.countries c ON ler.country_code = c.country_code
    WHERE ler.parent_entity_id = p_group_entity_id
       OR ler.entity_id = p_group_entity_id
    GROUP BY ler.country_code, c.country_name;

    GET DIAGNOSTICS v_jurisdiction_count = ROW_COUNT;

    -- Populate entity data
    INSERT INTO sys.cbcr_entity_data (
        report_id,
        jurisdiction_code,
        entity_id,
        entity_name,
        jurisdiction_of_incorporation,
        jurisdiction_of_tax_residence
    )
    SELECT
        v_report_id,
        ler.country_code,
        ler.entity_id,
        ler.legal_name,
        ler.country_code,
        ler.country_code
    FROM sys.legal_entity_registry ler
    WHERE ler.parent_entity_id = p_group_entity_id
       OR ler.entity_id = p_group_entity_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'report_id', v_report_id,
        'report_reference', v_report_reference,
        'group_entity', v_group_entity.entity_name,
        'fiscal_year', p_fiscal_year,
        'jurisdictions_count', v_jurisdiction_count,
        'message', 'CbCR report created. Populate financial data for each jurisdiction.'
    );
END;
$$;

COMMENT ON FUNCTION sys.rpc_generate_cbcr_report IS 'Generate CbCR report structure from group entities';

-- ----------------------------------------------------------------------------
-- 8.3 Run Annual TP Test
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sys.rpc_run_annual_tp_test(
    p_policy_id BIGINT,
    p_fiscal_year INT,
    p_study_id BIGINT DEFAULT NULL,
    p_user_id BIGINT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_policy RECORD;
    v_study RECORD;
    v_total_transactions DECIMAL(18,2);
    v_total_base DECIMAL(18,2);
    v_actual_margin DECIMAL(8,4);
    v_test_id BIGINT;
    v_result sys.al_test_result;
    v_adjustment_required BOOLEAN := FALSE;
    v_adjustment_amount DECIMAL(18,2);
BEGIN
    -- Get policy
    SELECT * INTO v_policy FROM sys.transfer_pricing_policies WHERE policy_id = p_policy_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Policy not found');
    END IF;

    -- Get benchmarking study if provided, else use policy ranges
    IF p_study_id IS NOT NULL THEN
        SELECT * INTO v_study FROM sys.tp_benchmarking_studies WHERE study_id = p_study_id;
    END IF;

    -- Aggregate transactions for the year
    SELECT
        SUM(amount_charged),
        SUM(base_amount)
    INTO v_total_transactions, v_total_base
    FROM sys.tp_transactions
    WHERE policy_id = p_policy_id
      AND fiscal_year = p_fiscal_year;

    IF v_total_transactions IS NULL OR v_total_base IS NULL OR v_total_base = 0 THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'No transactions found or invalid base amount');
    END IF;

    -- Calculate actual margin
    v_actual_margin := ((v_total_transactions - v_total_base) / v_total_base) * 100;

    -- Determine result using study or policy ranges
    DECLARE
        v_q1 DECIMAL(8,4) := COALESCE(v_study.range_q1, v_policy.comparable_range_q1);
        v_median DECIMAL(8,4) := COALESCE(v_study.range_median, v_policy.comparable_range_median);
        v_q3 DECIMAL(8,4) := COALESCE(v_study.range_q3, v_policy.comparable_range_q3);
    BEGIN
        IF v_q1 IS NULL OR v_q3 IS NULL THEN
            v_result := 'PENDING';
        ELSIF v_actual_margin >= v_q1 AND v_actual_margin <= v_q3 THEN
            v_result := 'WITHIN_RANGE';
        ELSIF v_actual_margin < v_q1 THEN
            v_result := 'BELOW_RANGE';
            v_adjustment_required := TRUE;
            -- Adjust to Q1
            v_adjustment_amount := v_total_base * (v_q1 - v_actual_margin) / 100;
        ELSE
            v_result := 'ABOVE_RANGE';
            v_adjustment_required := TRUE;
            -- Adjust to Q3
            v_adjustment_amount := v_total_base * (v_actual_margin - v_q3) / 100;
        END IF;

        -- Create test record
        INSERT INTO sys.arm_length_tests (
            policy_id,
            study_id,
            fiscal_year,
            test_date,
            test_period_start,
            test_period_end,
            tested_entity_id,
            profit_indicator,
            indicator_numerator,
            indicator_denominator,
            actual_value,
            actual_amount,
            range_q1,
            range_median,
            range_q3,
            result,
            adjustment_required,
            adjustment_amount,
            performed_by,
            created_by
        ) VALUES (
            p_policy_id,
            p_study_id,
            p_fiscal_year,
            CURRENT_DATE,
            make_date(p_fiscal_year, 1, 1),
            make_date(p_fiscal_year, 12, 31),
            v_policy.entity_from_id,  -- Or entity_to based on tested party
            'Operating Margin',
            'Operating Profit',
            'Net Sales',
            v_actual_margin,
            v_total_transactions,
            v_q1,
            v_median,
            v_q3,
            v_result,
            v_adjustment_required,
            v_adjustment_amount,
            p_user_id,
            p_user_id
        )
        RETURNING test_id INTO v_test_id;

        RETURN jsonb_build_object(
            'success', TRUE,
            'test_id', v_test_id,
            'policy_code', v_policy.policy_code,
            'fiscal_year', p_fiscal_year,
            'total_transactions', v_total_transactions,
            'total_base', v_total_base,
            'actual_margin', v_actual_margin,
            'range', jsonb_build_object('q1', v_q1, 'median', v_median, 'q3', v_q3),
            'result', v_result,
            'adjustment_required', v_adjustment_required,
            'adjustment_amount', v_adjustment_amount
        );
    END;
END;
$$;

COMMENT ON FUNCTION sys.rpc_run_annual_tp_test IS 'Run annual transfer pricing test for a policy';

-- ----------------------------------------------------------------------------
-- 8.4 Get TP Dashboard
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sys.rpc_get_tp_dashboard(
    p_entity_id BIGINT DEFAULT NULL,
    p_fiscal_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INT,
    p_user_id BIGINT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_policies JSONB;
    v_test_results JSONB;
    v_documentation JSONB;
    v_cbcr_status JSONB;
BEGIN
    -- Active policies summary
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'policy_code', policy_code,
        'transaction_type', transaction_type,
        'pricing_method', pricing_method,
        'transaction_count', transaction_count,
        'total_amount', total_amount,
        'adjustments_needed', adjustments_needed
    )), '[]')
    INTO v_policies
    FROM sys.v_tp_policy_summary
    WHERE is_active = TRUE
      AND (p_entity_id IS NULL OR entity_from_code = (SELECT entity_code FROM sys.tenant_entities WHERE entity_id = p_entity_id)
           OR entity_to_code = (SELECT entity_code FROM sys.tenant_entities WHERE entity_id = p_entity_id));

    -- Recent test results
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'policy_code', policy_code,
        'fiscal_year', fiscal_year,
        'actual_value', actual_value,
        'result', result,
        'adjustment_required', adjustment_required
    )), '[]')
    INTO v_test_results
    FROM sys.v_al_test_results
    WHERE fiscal_year >= p_fiscal_year - 2
    LIMIT 20;

    -- Documentation status
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'document_type', document_type,
        'fiscal_year', fiscal_year,
        'status', status,
        'days_until_deadline', days_until_deadline
    )), '[]')
    INTO v_documentation
    FROM sys.v_tp_documentation_status
    WHERE fiscal_year >= p_fiscal_year - 1;

    -- CbCR status
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'report_reference', report_reference,
        'fiscal_year', reporting_fiscal_year,
        'status', submission_status,
        'jurisdictions', jurisdictions_count
    )), '[]')
    INTO v_cbcr_status
    FROM sys.v_cbcr_summary
    WHERE reporting_fiscal_year >= p_fiscal_year - 2;

    RETURN jsonb_build_object(
        'success', TRUE,
        'fiscal_year', p_fiscal_year,
        'policies', v_policies,
        'test_results', v_test_results,
        'documentation', v_documentation,
        'cbcr_reports', v_cbcr_status
    );
END;
$$;

COMMENT ON FUNCTION sys.rpc_get_tp_dashboard IS 'Get transfer pricing dashboard data';

-- ============================================================================
-- SECTION 9: PERMISSIONS
-- ============================================================================

-- Fix déploiement (Sprint 2) : sys.permissions a pour colonnes
-- (permission_code, module_code, resource, action, description), non
-- (permission_name, permission_category). On enveloppe les VALEURS d'origine
-- dans un SELECT dérivant resource/action depuis permission_code (RES.ACTION),
-- sans toucher aux lignes. ROLLBACK : rétablir l'INSERT ... VALUES direct.
INSERT INTO sys.permissions (permission_code, module_code, resource, action, description)
SELECT v.code, v.category, v.code,
       CASE split_part(v.code, '.', 2)
         WHEN 'VIEW' THEN 'READ'   WHEN 'MANAGE' THEN 'UPDATE' WHEN 'EDIT' THEN 'UPDATE'
         WHEN 'CREATE' THEN 'CREATE' WHEN 'DELETE' THEN 'DELETE' WHEN 'READ' THEN 'READ'
         WHEN 'UPDATE' THEN 'UPDATE' WHEN 'VALIDATE' THEN 'VALIDATE'
         WHEN 'EXPORT' THEN 'EXPORT' WHEN 'IMPORT' THEN 'IMPORT' WHEN 'APPROVE' THEN 'APPROVE'
         WHEN 'SUBMIT' THEN 'APPROVE' WHEN 'CONFIRM' THEN 'APPROVE' WHEN 'DESIGNATE' THEN 'APPROVE'
         WHEN 'EXECUTE' THEN 'APPROVE' WHEN 'SWEEP' THEN 'APPROVE'
         ELSE 'READ'
       END,
       v.description
FROM (VALUES
    ('TP.POLICY.VIEW', 'View TP Policies', 'TRANSFER_PRICING', 'View transfer pricing policies'),
    ('TP.POLICY.EDIT', 'Edit TP Policies', 'TRANSFER_PRICING', 'Create and modify TP policies'),
    ('TP.TRANSACTION.VIEW', 'View TP Transactions', 'TRANSFER_PRICING', 'View TP transactions'),
    ('TP.TRANSACTION.VALIDATE', 'Validate TP Transactions', 'TRANSFER_PRICING', 'Run arm''s length validation'),
    ('TP.DOCUMENTATION.VIEW', 'View TP Documentation', 'TRANSFER_PRICING', 'View Master/Local files'),
    ('TP.DOCUMENTATION.EDIT', 'Edit TP Documentation', 'TRANSFER_PRICING', 'Create and modify TP documentation'),
    ('TP.BENCHMARKING.VIEW', 'View Benchmarking', 'TRANSFER_PRICING', 'View benchmarking studies'),
    ('TP.BENCHMARKING.MANAGE', 'Manage Benchmarking', 'TRANSFER_PRICING', 'Create and modify benchmarking studies'),
    ('CBCR.VIEW', 'View CbCR', 'TRANSFER_PRICING', 'View Country-by-Country Reports'),
    ('CBCR.EDIT', 'Edit CbCR', 'TRANSFER_PRICING', 'Create and modify CbCR'),
    ('CBCR.SUBMIT', 'Submit CbCR', 'TRANSFER_PRICING', 'Submit CbCR to authorities')
) AS v(code, name, category, description)
ON CONFLICT (permission_code) DO NOTHING;

-- ============================================================================
-- SECTION 10: INDEXES AND COMPLETION
-- ============================================================================

-- Additional performance indexes
CREATE INDEX idx_tp_txn_year_policy ON sys.tp_transactions(fiscal_year, policy_id);
CREATE INDEX idx_al_test_year_policy ON sys.arm_length_tests(fiscal_year, policy_id);

-- ============================================================================
-- END OF ONYX TRANSFER PRICING MODULE
-- ============================================================================

COMMENT ON SCHEMA sys IS 'EdenFin system schema with ONYX Transfer Pricing module';
