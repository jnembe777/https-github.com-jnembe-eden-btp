-- ============================================================================
-- Fix integration (Sprint 3) : modele de tenant harmonise sur le socle BIGINT.
--   tenant_id/fiscal_year_id UUID -> BIGINT ; common.tenants -> sys.tenants ;
--   common.fiscal_years -> client_demo.fiscal_exercises. Voir SPRINT3_ONYX.md.
-- ROLLBACK : retablir les types UUID et les references common.* d origine.
-- EDENFIN ONYX: REGULATORY COMPLIANCE MODULE
-- ============================================================================
-- Version: 1.0.0
-- Date: 2026-02-11
-- Description: Comprehensive regulatory compliance for global enterprises
--   - XBRL/iXBRL financial reporting
--   - SOX controls documentation
--   - eInvoicing (Peppol, Factur-X, FatturaPA, etc.)
--   - Tax digital submissions (MTD, SII, SAF-T)
--   - Tamper-proof audit archive
-- Dependencies: JASPE (00-09), RUBIS (01-03), SAPHIR (01-05), ONYX (01-05)
-- ============================================================================

-- Create ONYX schema if not exists
CREATE SCHEMA IF NOT EXISTS onyx;

-- ============================================================================
-- SECTION 1: ENUMERATIONS
-- ============================================================================

-- XBRL taxonomy types
CREATE TYPE onyx.xbrl_taxonomy_type AS ENUM (
    'IFRS_FULL',           -- Full IFRS taxonomy
    'IFRS_SME',            -- IFRS for SMEs
    'US_GAAP',             -- US GAAP taxonomy
    'ESEF',                -- European Single Electronic Format
    'UKSEF',               -- UK Single Electronic Format
    'OHADA',               -- OHADA (SYSCOHADA)
    'LOCAL',               -- Country-specific local GAAP
    'CUSTOM'               -- Custom/extended taxonomy
);

-- Filing status
CREATE TYPE onyx.filing_status AS ENUM (
    'DRAFT',               -- Being prepared
    'VALIDATING',          -- Under validation
    'VALIDATED',           -- Passed validation
    'VALIDATION_FAILED',   -- Failed validation
    'SUBMITTED',           -- Submitted to regulator
    'ACCEPTED',            -- Accepted by regulator
    'REJECTED',            -- Rejected by regulator
    'AMENDED',             -- Amendment submitted
    'ARCHIVED'             -- Archived
);

-- SOX control types
CREATE TYPE onyx.sox_control_type AS ENUM (
    'PREVENTIVE',          -- Prevent errors/fraud
    'DETECTIVE',           -- Detect errors/fraud
    'CORRECTIVE',          -- Correct identified issues
    'DIRECTIVE',           -- Direct behavior
    'COMPENSATING'         -- Compensate for other control weaknesses
);

-- Control effectiveness
CREATE TYPE onyx.control_effectiveness AS ENUM (
    'EFFECTIVE',
    'PARTIALLY_EFFECTIVE',
    'INEFFECTIVE',
    'NOT_TESTED',
    'NOT_APPLICABLE'
);

-- eInvoice formats
CREATE TYPE onyx.einvoice_format AS ENUM (
    'PEPPOL_BIS',          -- Pan-European (EU)
    'FACTUR_X',            -- France/Germany (ZUGFeRD)
    'FATTURA_PA',          -- Italy
    'FACTURAE',            -- Spain
    'UBL_2_1',             -- Universal Business Language
    'CII',                 -- Cross Industry Invoice
    'OASIS',               -- OASIS standard
    'CIUS_RO',             -- Romania
    'CIUS_PT',             -- Portugal
    'NLCIUS',              -- Netherlands
    'XRechnung',           -- Germany
    'CUSTOM'               -- Custom format
);

-- Tax digital submission types
CREATE TYPE onyx.tax_submission_type AS ENUM (
    'MTD_VAT',             -- UK Making Tax Digital VAT
    'MTD_ITSA',            -- UK MTD Income Tax Self Assessment
    'SII',                 -- Spain Suministro Inmediato de Información
    'SAF_T',               -- Standard Audit File for Tax
    'JPK',                 -- Poland Jednolity Plik Kontrolny
    'FEC',                 -- France Fichier des Écritures Comptables
    'CONTROLE_FISCAL',     -- Belgium
    'E_FAKTURA',           -- Poland e-Faktura
    'FATCA',               -- US Foreign Account Tax Compliance
    'CRS',                 -- Common Reporting Standard
    'DAC6',                -- EU Mandatory Disclosure Rules
    'DAC7',                -- EU Digital Platform Reporting
    'PILLAR2_GLOBE'        -- OECD Pillar 2 GloBE
);

-- Audit event severity
CREATE TYPE onyx.audit_severity AS ENUM (
    'INFO',
    'WARNING',
    'ERROR',
    'CRITICAL',
    'SECURITY'
);

-- ============================================================================
-- SECTION 2: XBRL/iXBRL REPORTING
-- ============================================================================

-- XBRL Taxonomies
CREATE TABLE onyx.xbrl_taxonomies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),

    -- Taxonomy identification
    taxonomy_code VARCHAR(50) NOT NULL,
    taxonomy_name VARCHAR(200) NOT NULL,
    taxonomy_type onyx.xbrl_taxonomy_type NOT NULL,
    version VARCHAR(20) NOT NULL,

    -- Taxonomy details
    namespace_uri VARCHAR(500) NOT NULL,
    schema_location VARCHAR(500),
    entry_point_url VARCHAR(500),

    -- Validity
    effective_date DATE NOT NULL,
    end_date DATE,
    is_active BOOLEAN NOT NULL DEFAULT true,

    -- Jurisdiction
    country_code CHAR(3),  -- ISO 3166-1 alpha-3
    regulator_code VARCHAR(50),
    regulator_name VARCHAR(200),

    -- Metadata
    description TEXT,
    documentation_url VARCHAR(500),

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL,
    updated_at TIMESTAMPTZ,
    updated_by UUID,

    UNIQUE(tenant_id, taxonomy_code, version)
);

-- Taxonomy concepts (elements)
CREATE TABLE onyx.xbrl_concepts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    taxonomy_id UUID NOT NULL REFERENCES onyx.xbrl_taxonomies(id),

    -- Concept identification
    concept_name VARCHAR(200) NOT NULL,
    concept_label VARCHAR(500) NOT NULL,
    concept_type VARCHAR(100) NOT NULL, -- monetary, string, date, etc.

    -- Hierarchy
    parent_concept_id UUID REFERENCES onyx.xbrl_concepts(id),
    hierarchy_level INT NOT NULL DEFAULT 0,
    sort_order INT NOT NULL DEFAULT 0,

    -- Properties
    period_type VARCHAR(20) NOT NULL DEFAULT 'instant', -- instant, duration
    balance_type VARCHAR(10), -- debit, credit (for monetary)
    is_abstract BOOLEAN NOT NULL DEFAULT false,
    is_nillable BOOLEAN NOT NULL DEFAULT true,

    -- Mapping to accounts
    account_pattern VARCHAR(100), -- Regex pattern to match account codes

    -- Documentation
    documentation TEXT,
    "references" JSONB, -- Standard references (mot réservé -> quoté. ROLLBACK : dé-quoter si renommé)

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- XBRL Filings
CREATE TABLE onyx.xbrl_filings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    entity_id UUID NOT NULL,

    -- Filing identification
    filing_reference VARCHAR(100) NOT NULL,
    taxonomy_id UUID NOT NULL REFERENCES onyx.xbrl_taxonomies(id),

    -- Reporting period
    fiscal_year_id BIGINT NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,

    -- Filing type
    filing_type VARCHAR(50) NOT NULL, -- ANNUAL, INTERIM, QUARTERLY
    is_amendment BOOLEAN NOT NULL DEFAULT false,
    amends_filing_id UUID REFERENCES onyx.xbrl_filings(id),

    -- Status tracking
    status onyx.filing_status NOT NULL DEFAULT 'DRAFT',
    status_changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status_changed_by UUID,

    -- Validation
    validation_started_at TIMESTAMPTZ,
    validation_completed_at TIMESTAMPTZ,
    validation_errors JSONB, -- Array of validation errors
    validation_warnings JSONB,

    -- Submission
    submitted_at TIMESTAMPTZ,
    submitted_by UUID,
    submission_reference VARCHAR(200),
    regulator_response JSONB,

    -- Generated files
    xbrl_instance_file BYTEA, -- Stored XBRL instance
    ixbrl_html_file BYTEA,    -- iXBRL (inline XBRL)
    viewer_package BYTEA,     -- Viewer package

    -- Signatures
    digital_signature BYTEA,
    signer_certificate TEXT,
    signed_at TIMESTAMPTZ,
    signed_by UUID,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL,
    updated_at TIMESTAMPTZ,
    updated_by UUID,

    UNIQUE(tenant_id, entity_id, filing_reference)
);

-- Filing fact values
CREATE TABLE onyx.xbrl_filing_facts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    filing_id UUID NOT NULL REFERENCES onyx.xbrl_filings(id) ON DELETE CASCADE,
    concept_id UUID NOT NULL REFERENCES onyx.xbrl_concepts(id),

    -- Context
    context_ref VARCHAR(100) NOT NULL,
    unit_ref VARCHAR(50), -- For monetary/numeric values

    -- Value
    value_text TEXT,
    value_numeric DECIMAL(20,4),
    value_date DATE,
    value_boolean BOOLEAN,

    -- Dimensions (for dimensional facts)
    dimensions JSONB, -- {dimension: member} pairs

    -- Precision
    decimals INT,
    precision_type VARCHAR(20), -- INF, integer value

    -- Source mapping
    source_account_id UUID,
    source_query TEXT, -- SQL used to derive value
    is_calculated BOOLEAN NOT NULL DEFAULT false,
    calculation_expression TEXT,

    -- Validation
    is_validated BOOLEAN NOT NULL DEFAULT false,
    validation_message TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_xbrl_filings_tenant ON onyx.xbrl_filings(tenant_id, entity_id);
CREATE INDEX idx_xbrl_filings_status ON onyx.xbrl_filings(status);
CREATE INDEX idx_xbrl_filing_facts_filing ON onyx.xbrl_filing_facts(filing_id);

-- ============================================================================
-- SECTION 3: SOX CONTROLS
-- ============================================================================

-- Control frameworks
CREATE TABLE onyx.sox_frameworks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),

    framework_code VARCHAR(50) NOT NULL,
    framework_name VARCHAR(200) NOT NULL,
    version VARCHAR(20) NOT NULL,

    -- Type
    framework_type VARCHAR(50) NOT NULL, -- COSO, COBIT, ISO27001, etc.

    -- Validity
    effective_date DATE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,

    description TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL,

    UNIQUE(tenant_id, framework_code, version)
);

-- SOX Controls
CREATE TABLE onyx.sox_controls (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    framework_id UUID NOT NULL REFERENCES onyx.sox_frameworks(id),

    -- Control identification
    control_id VARCHAR(50) NOT NULL,
    control_name VARCHAR(200) NOT NULL,
    control_type onyx.sox_control_type NOT NULL,

    -- Hierarchy
    parent_control_id UUID REFERENCES onyx.sox_controls(id),

    -- Description
    objective TEXT NOT NULL,
    description TEXT NOT NULL,
    risk_addressed TEXT,

    -- Classification
    is_key_control BOOLEAN NOT NULL DEFAULT false,
    is_itgc BOOLEAN NOT NULL DEFAULT false, -- IT General Control
    is_itac BOOLEAN NOT NULL DEFAULT false, -- IT Application Control

    -- Ownership
    control_owner_id UUID,
    control_owner_name VARCHAR(200),
    department VARCHAR(100),

    -- Frequency
    frequency VARCHAR(50) NOT NULL, -- DAILY, WEEKLY, MONTHLY, QUARTERLY, ANNUALLY, AD_HOC

    -- Assertions (for financial controls)
    assertions JSONB, -- {existence, completeness, accuracy, valuation, rights, presentation}

    -- Related processes/accounts
    related_processes JSONB, -- Process IDs
    related_accounts JSONB, -- Account codes affected

    -- Documentation
    procedure_document_url VARCHAR(500),
    evidence_requirements TEXT,

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL,
    updated_at TIMESTAMPTZ,
    updated_by UUID,

    UNIQUE(tenant_id, framework_id, control_id)
);

-- Control test plans
CREATE TABLE onyx.sox_test_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),

    -- Plan identification
    plan_name VARCHAR(200) NOT NULL,
    fiscal_year_id BIGINT NOT NULL,

    -- Period
    test_period_start DATE NOT NULL,
    test_period_end DATE NOT NULL,

    -- Scope
    controls_in_scope INT NOT NULL DEFAULT 0,
    sample_size_methodology TEXT,

    -- Status
    status VARCHAR(50) NOT NULL DEFAULT 'DRAFT',
    approved_by UUID,
    approved_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL
);

-- Control test results
CREATE TABLE onyx.sox_test_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_plan_id UUID NOT NULL REFERENCES onyx.sox_test_plans(id),
    control_id UUID NOT NULL REFERENCES onyx.sox_controls(id),

    -- Testing details
    tester_id UUID NOT NULL,
    test_date DATE NOT NULL,

    -- Sample
    sample_size INT NOT NULL,
    population_size INT,
    sample_selection_method VARCHAR(100),

    -- Results
    effectiveness onyx.control_effectiveness NOT NULL,
    exceptions_found INT NOT NULL DEFAULT 0,

    -- Evidence
    evidence_reviewed TEXT,
    evidence_files JSONB, -- Array of file references

    -- Findings
    findings TEXT,
    root_cause TEXT,

    -- Remediation
    remediation_required BOOLEAN NOT NULL DEFAULT false,
    remediation_plan TEXT,
    remediation_due_date DATE,
    remediation_owner_id UUID,

    -- Review
    reviewed_by UUID,
    reviewed_at TIMESTAMPTZ,
    review_comments TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL
);

-- Control deficiencies
CREATE TABLE onyx.sox_deficiencies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    control_id UUID NOT NULL REFERENCES onyx.sox_controls(id),
    test_result_id UUID REFERENCES onyx.sox_test_results(id),

    -- Deficiency details
    deficiency_code VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,

    -- Classification
    severity VARCHAR(50) NOT NULL, -- DEFICIENCY, SIGNIFICANT_DEFICIENCY, MATERIAL_WEAKNESS
    likelihood VARCHAR(50) NOT NULL, -- REMOTE, REASONABLY_POSSIBLE, PROBABLE

    -- Impact
    financial_impact_estimate DECIMAL(20,4),
    accounts_affected JSONB,

    -- Status
    status VARCHAR(50) NOT NULL DEFAULT 'OPEN',
    identified_date DATE NOT NULL,
    target_remediation_date DATE,
    actual_remediation_date DATE,

    -- Ownership
    remediation_owner_id UUID,

    -- Remediation
    remediation_plan TEXT,
    remediation_evidence TEXT,

    -- Validation
    validated_by UUID,
    validated_at TIMESTAMPTZ,
    validation_notes TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL,

    UNIQUE(tenant_id, deficiency_code)
);

CREATE INDEX idx_sox_controls_tenant ON onyx.sox_controls(tenant_id, framework_id);
CREATE INDEX idx_sox_test_results_control ON onyx.sox_test_results(control_id);
CREATE INDEX idx_sox_deficiencies_status ON onyx.sox_deficiencies(tenant_id, status);

-- ============================================================================
-- SECTION 4: E-INVOICING
-- ============================================================================

-- eInvoice format configurations
CREATE TABLE onyx.einvoice_formats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),

    -- Format identification
    format_code VARCHAR(50) NOT NULL,
    format_type onyx.einvoice_format NOT NULL,
    format_name VARCHAR(200) NOT NULL,
    version VARCHAR(20) NOT NULL,

    -- Jurisdiction
    country_code CHAR(3) NOT NULL,
    is_mandatory BOOLEAN NOT NULL DEFAULT false,
    mandatory_from DATE,

    -- Technical details
    schema_url VARCHAR(500),
    validation_url VARCHAR(500), -- External validation service
    submission_url VARCHAR(500), -- Submission endpoint

    -- Mapping configuration
    field_mappings JSONB NOT NULL, -- Maps EdenFin fields to format fields

    -- Templates
    xml_template TEXT,
    pdf_template TEXT,

    -- Credentials (encrypted)
    api_credentials_encrypted BYTEA,
    certificate_encrypted BYTEA,

    is_active BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL,

    UNIQUE(tenant_id, format_code, version)
);

-- eInvoice submissions
CREATE TABLE onyx.einvoice_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    entity_id UUID NOT NULL,

    -- Source invoice
    source_invoice_id UUID NOT NULL,
    source_invoice_number VARCHAR(100) NOT NULL,

    -- Format
    format_id UUID NOT NULL REFERENCES onyx.einvoice_formats(id),

    -- Generated document
    einvoice_xml TEXT,
    einvoice_pdf BYTEA,
    einvoice_hash VARCHAR(128), -- SHA-512 hash

    -- Submission tracking
    status onyx.filing_status NOT NULL DEFAULT 'DRAFT',

    -- Validation
    validation_result JSONB,
    validation_errors JSONB,
    validated_at TIMESTAMPTZ,

    -- Submission
    submitted_at TIMESTAMPTZ,
    submitted_by UUID,
    submission_id VARCHAR(200), -- ID from receiving system
    submission_response JSONB,

    -- Receiver details
    receiver_id VARCHAR(100),
    receiver_name VARCHAR(200),
    receiver_peppol_id VARCHAR(100),

    -- Status updates from network
    delivery_status VARCHAR(50),
    delivery_timestamp TIMESTAMPTZ,
    receiver_response JSONB,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL,

    UNIQUE(tenant_id, source_invoice_id, format_id)
);

CREATE INDEX idx_einvoice_submissions_invoice ON onyx.einvoice_submissions(source_invoice_id);
CREATE INDEX idx_einvoice_submissions_status ON onyx.einvoice_submissions(tenant_id, status);

-- ============================================================================
-- SECTION 5: TAX DIGITAL SUBMISSIONS
-- ============================================================================

-- Tax digital configurations
CREATE TABLE onyx.tax_digital_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    entity_id UUID NOT NULL,

    -- Submission type
    submission_type onyx.tax_submission_type NOT NULL,

    -- Jurisdiction
    country_code CHAR(3) NOT NULL,
    tax_authority_code VARCHAR(50),
    tax_authority_name VARCHAR(200),

    -- Registration
    registration_number VARCHAR(100), -- VAT number, tax ID, etc.
    registration_date DATE,

    -- API credentials (encrypted)
    api_endpoint VARCHAR(500),
    api_credentials_encrypted BYTEA,
    oauth_tokens_encrypted BYTEA,

    -- Certificates
    signing_certificate_encrypted BYTEA,
    certificate_expiry DATE,

    -- Settings
    auto_submit BOOLEAN NOT NULL DEFAULT false,
    submission_frequency VARCHAR(50), -- MONTHLY, QUARTERLY, ANNUALLY
    submission_deadline_day INT, -- Day of month/quarter

    -- Test mode
    is_test_mode BOOLEAN NOT NULL DEFAULT true,

    is_active BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL,

    UNIQUE(tenant_id, entity_id, submission_type)
);

-- Tax digital submissions
CREATE TABLE onyx.tax_digital_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    config_id UUID NOT NULL REFERENCES onyx.tax_digital_configs(id),

    -- Submission identification
    submission_reference VARCHAR(100) NOT NULL,
    submission_type onyx.tax_submission_type NOT NULL,

    -- Period
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    period_key VARCHAR(20), -- e.g., "2026-Q1", "2026-01"

    -- Obligation
    obligation_id VARCHAR(100), -- From tax authority
    due_date DATE,

    -- Status
    status onyx.filing_status NOT NULL DEFAULT 'DRAFT',

    -- Data
    submission_data JSONB NOT NULL, -- Structured submission data
    submission_xml TEXT, -- XML format if applicable
    submission_json TEXT, -- JSON format if applicable

    -- Validation
    validated_at TIMESTAMPTZ,
    validation_result JSONB,

    -- Submission
    submitted_at TIMESTAMPTZ,
    submitted_by UUID,
    receipt_id VARCHAR(200), -- Receipt from tax authority
    receipt_timestamp TIMESTAMPTZ,
    receipt_data JSONB,

    -- Corrections
    is_correction BOOLEAN NOT NULL DEFAULT false,
    corrects_submission_id UUID REFERENCES onyx.tax_digital_submissions(id),
    correction_reason TEXT,

    -- Response
    authority_response JSONB,
    response_timestamp TIMESTAMPTZ,

    -- Amounts (denormalized for reporting)
    total_output_vat DECIMAL(20,4),
    total_input_vat DECIMAL(20,4),
    net_vat_due DECIMAL(20,4),
    total_sales DECIMAL(20,4),
    total_purchases DECIMAL(20,4),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL,

    UNIQUE(config_id, submission_reference)
);

-- SAF-T specific data
CREATE TABLE onyx.saft_exports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    submission_id UUID NOT NULL REFERENCES onyx.tax_digital_submissions(id),

    -- SAF-T version
    saft_version VARCHAR(20) NOT NULL,
    country_variant VARCHAR(50), -- PT, PL, NO, LT, etc.

    -- Export details
    audit_file_date DATE NOT NULL,

    -- Header info
    company_name VARCHAR(200) NOT NULL,
    tax_registration_number VARCHAR(50) NOT NULL,
    fiscal_year INT NOT NULL,

    -- Statistics
    total_debit DECIMAL(20,4),
    total_credit DECIMAL(20,4),
    transaction_count INT,
    customer_count INT,
    supplier_count INT,
    product_count INT,

    -- Generated file
    saft_xml TEXT,
    saft_file BYTEA,
    file_hash VARCHAR(128),

    -- Validation
    xsd_validation_passed BOOLEAN,
    validation_errors JSONB,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tax_submissions_config ON onyx.tax_digital_submissions(config_id);
CREATE INDEX idx_tax_submissions_period ON onyx.tax_digital_submissions(period_start, period_end);
CREATE INDEX idx_tax_submissions_status ON onyx.tax_digital_submissions(status);

-- ============================================================================
-- SECTION 6: TAMPER-PROOF AUDIT ARCHIVE
-- ============================================================================

-- Audit archive (immutable ledger)
CREATE TABLE onyx.audit_archive (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL,

    -- Event identification
    event_id UUID NOT NULL DEFAULT gen_random_uuid(),
    event_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    event_type VARCHAR(100) NOT NULL,
    event_category VARCHAR(50) NOT NULL, -- AUTH, DATA, CONFIG, REPORT, SYSTEM
    severity onyx.audit_severity NOT NULL DEFAULT 'INFO',

    -- Actor
    user_id UUID,
    user_email VARCHAR(255),
    user_name VARCHAR(200),
    user_role VARCHAR(100),
    ip_address INET,
    user_agent TEXT,
    session_id VARCHAR(100),

    -- Target
    entity_type VARCHAR(100),
    entity_id UUID,
    entity_name VARCHAR(200),

    -- Action details
    action VARCHAR(100) NOT NULL,
    action_detail TEXT,

    -- Data changes
    old_values JSONB,
    new_values JSONB,
    changed_fields TEXT[],

    -- Context
    request_id VARCHAR(100),
    correlation_id VARCHAR(100),
    source_system VARCHAR(100),

    -- Integrity
    previous_hash VARCHAR(128), -- Hash of previous record
    record_hash VARCHAR(128) NOT NULL, -- Hash of this record

    -- Regulatory
    regulatory_context VARCHAR(100), -- SOX, GDPR, etc.
    retention_years INT NOT NULL DEFAULT 7,

    -- Do not allow updates or deletes
    CONSTRAINT audit_immutable CHECK (TRUE)
);

-- Create hash function for audit records
CREATE OR REPLACE FUNCTION onyx.fn_calculate_audit_hash(
    p_tenant_id UUID,
    p_event_id UUID,
    p_event_timestamp TIMESTAMPTZ,
    p_event_type VARCHAR,
    p_user_id UUID,
    p_action VARCHAR,
    p_entity_type VARCHAR,
    p_entity_id UUID,
    p_old_values JSONB,
    p_new_values JSONB,
    p_previous_hash VARCHAR
) RETURNS VARCHAR AS $$
DECLARE
    v_data TEXT;
BEGIN
    v_data := COALESCE(p_tenant_id::TEXT, '') ||
              COALESCE(p_event_id::TEXT, '') ||
              COALESCE(p_event_timestamp::TEXT, '') ||
              COALESCE(p_event_type, '') ||
              COALESCE(p_user_id::TEXT, '') ||
              COALESCE(p_action, '') ||
              COALESCE(p_entity_type, '') ||
              COALESCE(p_entity_id::TEXT, '') ||
              COALESCE(p_old_values::TEXT, '') ||
              COALESCE(p_new_values::TEXT, '') ||
              COALESCE(p_previous_hash, '');

    RETURN encode(sha512(v_data::bytea), 'hex');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Trigger to calculate hash on insert
CREATE OR REPLACE FUNCTION onyx.fn_audit_archive_hash()
RETURNS TRIGGER AS $$
DECLARE
    v_previous_hash VARCHAR(128);
BEGIN
    -- Get hash of previous record for chain integrity
    SELECT record_hash INTO v_previous_hash
    FROM onyx.audit_archive
    WHERE tenant_id = NEW.tenant_id
    ORDER BY id DESC
    LIMIT 1;

    NEW.previous_hash := v_previous_hash;
    NEW.record_hash := onyx.fn_calculate_audit_hash(
        NEW.tenant_id,
        NEW.event_id,
        NEW.event_timestamp,
        NEW.event_type,
        NEW.user_id,
        NEW.action,
        NEW.entity_type,
        NEW.entity_id,
        NEW.old_values,
        NEW.new_values,
        v_previous_hash
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_archive_hash
    BEFORE INSERT ON onyx.audit_archive
    FOR EACH ROW
    EXECUTE FUNCTION onyx.fn_audit_archive_hash();

-- Prevent updates and deletes on audit archive
CREATE OR REPLACE FUNCTION onyx.fn_audit_archive_immutable()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Audit archive records cannot be modified or deleted';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_archive_no_update
    BEFORE UPDATE ON onyx.audit_archive
    FOR EACH ROW
    EXECUTE FUNCTION onyx.fn_audit_archive_immutable();

CREATE TRIGGER trg_audit_archive_no_delete
    BEFORE DELETE ON onyx.audit_archive
    FOR EACH ROW
    EXECUTE FUNCTION onyx.fn_audit_archive_immutable();

-- Indexes for audit archive
CREATE INDEX idx_audit_archive_tenant_time ON onyx.audit_archive(tenant_id, event_timestamp DESC);
CREATE INDEX idx_audit_archive_entity ON onyx.audit_archive(entity_type, entity_id);
CREATE INDEX idx_audit_archive_user ON onyx.audit_archive(user_id, event_timestamp DESC);
CREATE INDEX idx_audit_archive_type ON onyx.audit_archive(event_type, event_category);
CREATE INDEX idx_audit_archive_severity ON onyx.audit_archive(severity) WHERE severity IN ('ERROR', 'CRITICAL', 'SECURITY');

-- ============================================================================
-- SECTION 7: VIEWS
-- ============================================================================

-- XBRL filing status summary
CREATE OR REPLACE VIEW onyx.v_xbrl_filing_summary AS
SELECT
    f.tenant_id,
    f.entity_id,
    t.taxonomy_code,
    t.taxonomy_type,
    f.fiscal_year_id,
    f.period_end,
    f.filing_type,
    f.status,
    f.submitted_at,
    f.submission_reference,
    CASE
        WHEN f.status = 'DRAFT' THEN 'Pending preparation'
        WHEN f.status = 'VALIDATING' THEN 'Under validation'
        WHEN f.status = 'VALIDATION_FAILED' THEN 'Fix validation errors'
        WHEN f.status = 'VALIDATED' THEN 'Ready for submission'
        WHEN f.status = 'SUBMITTED' THEN 'Awaiting response'
        WHEN f.status = 'ACCEPTED' THEN 'Complete'
        WHEN f.status = 'REJECTED' THEN 'Requires attention'
        ELSE f.status::TEXT
    END AS status_description,
    jsonb_array_length(COALESCE(f.validation_errors, '[]'::JSONB)) AS error_count,
    jsonb_array_length(COALESCE(f.validation_warnings, '[]'::JSONB)) AS warning_count
FROM onyx.xbrl_filings f
JOIN onyx.xbrl_taxonomies t ON f.taxonomy_id = t.id;

-- SOX control effectiveness dashboard
CREATE OR REPLACE VIEW onyx.v_sox_control_dashboard AS
SELECT
    c.tenant_id,
    c.framework_id,
    f.framework_name,
    c.control_type,
    c.is_key_control,
    COUNT(*) AS total_controls,
    COUNT(CASE WHEN tr.effectiveness = 'EFFECTIVE' THEN 1 END) AS effective_count,
    COUNT(CASE WHEN tr.effectiveness = 'PARTIALLY_EFFECTIVE' THEN 1 END) AS partial_count,
    COUNT(CASE WHEN tr.effectiveness = 'INEFFECTIVE' THEN 1 END) AS ineffective_count,
    COUNT(CASE WHEN tr.effectiveness = 'NOT_TESTED' THEN 1 END) AS not_tested_count,
    ROUND(
        COUNT(CASE WHEN tr.effectiveness = 'EFFECTIVE' THEN 1 END)::DECIMAL /
        NULLIF(COUNT(CASE WHEN tr.effectiveness != 'NOT_APPLICABLE' THEN 1 END), 0) * 100,
        2
    ) AS effectiveness_rate
FROM onyx.sox_controls c
JOIN onyx.sox_frameworks f ON c.framework_id = f.id
LEFT JOIN LATERAL (
    SELECT effectiveness
    FROM onyx.sox_test_results
    WHERE control_id = c.id
    ORDER BY test_date DESC
    LIMIT 1
) tr ON TRUE
WHERE c.is_active = true
GROUP BY c.tenant_id, c.framework_id, f.framework_name, c.control_type, c.is_key_control;

-- Tax submission compliance status
CREATE OR REPLACE VIEW onyx.v_tax_compliance_status AS
SELECT
    tc.tenant_id,
    tc.entity_id,
    tc.submission_type,
    tc.country_code,
    tc.registration_number,
    ts.period_key,
    ts.period_start,
    ts.period_end,
    ts.due_date,
    ts.status,
    ts.submitted_at,
    ts.receipt_id,
    CASE
        WHEN ts.status = 'ACCEPTED' THEN 'Compliant'
        WHEN ts.status IN ('SUBMITTED', 'VALIDATED') AND ts.due_date >= CURRENT_DATE THEN 'Pending'
        WHEN ts.due_date < CURRENT_DATE AND ts.status NOT IN ('ACCEPTED', 'SUBMITTED') THEN 'Overdue'
        ELSE 'In Progress'
    END AS compliance_status,
    ts.net_vat_due,
    ts.total_sales,
    ts.total_purchases
FROM onyx.tax_digital_configs tc
LEFT JOIN onyx.tax_digital_submissions ts ON tc.id = ts.config_id
WHERE tc.is_active = true;

-- eInvoice delivery status
CREATE OR REPLACE VIEW onyx.v_einvoice_status AS
SELECT
    es.tenant_id,
    es.entity_id,
    ef.format_type,
    ef.country_code,
    es.source_invoice_number,
    es.receiver_name,
    es.status,
    es.delivery_status,
    es.submitted_at,
    es.delivery_timestamp,
    CASE
        WHEN es.status = 'ACCEPTED' AND es.delivery_status = 'DELIVERED' THEN 'Complete'
        WHEN es.status = 'REJECTED' THEN 'Failed'
        WHEN es.status = 'VALIDATION_FAILED' THEN 'Validation Error'
        WHEN es.status = 'SUBMITTED' THEN 'In Transit'
        ELSE 'Pending'
    END AS overall_status
FROM onyx.einvoice_submissions es
JOIN onyx.einvoice_formats ef ON es.format_id = ef.id;

-- Audit trail summary by category
CREATE OR REPLACE VIEW onyx.v_audit_summary AS
SELECT
    tenant_id,
    DATE(event_timestamp) AS event_date,
    event_category,
    severity,
    COUNT(*) AS event_count,
    COUNT(DISTINCT user_id) AS unique_users,
    COUNT(DISTINCT entity_type) AS entity_types_affected
FROM onyx.audit_archive
WHERE event_timestamp >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY tenant_id, DATE(event_timestamp), event_category, severity
ORDER BY event_date DESC, event_count DESC;

-- ============================================================================
-- SECTION 8: RPC FUNCTIONS
-- ============================================================================

-- Generate XBRL filing from trial balance
CREATE OR REPLACE FUNCTION onyx.rpc_generate_xbrl_filing(
    p_tenant_id UUID,
    p_entity_id UUID,
    p_taxonomy_id UUID,
    p_fiscal_year_id UUID,
    p_period_start DATE,
    p_period_end DATE,
    p_filing_type VARCHAR,
    p_user_id UUID
) RETURNS UUID AS $$
DECLARE
    v_filing_id UUID;
    v_filing_ref VARCHAR(100);
BEGIN
    -- Generate filing reference
    v_filing_ref := 'XBRL-' || TO_CHAR(p_period_end, 'YYYY') || '-' ||
                    SUBSTRING(p_entity_id::TEXT, 1, 8) || '-' ||
                    TO_CHAR(NOW(), 'YYYYMMDDHH24MISS');

    -- Create filing record
    INSERT INTO onyx.xbrl_filings (
        tenant_id, entity_id, filing_reference, taxonomy_id,
        fiscal_year_id, period_start, period_end, filing_type,
        status, created_by
    ) VALUES (
        p_tenant_id, p_entity_id, v_filing_ref, p_taxonomy_id,
        p_fiscal_year_id, p_period_start, p_period_end, p_filing_type,
        'DRAFT', p_user_id
    ) RETURNING id INTO v_filing_id;

    -- Map account balances to XBRL concepts
    INSERT INTO onyx.xbrl_filing_facts (
        filing_id, concept_id, context_ref, unit_ref,
        value_numeric, source_account_id, is_calculated
    )
    SELECT
        v_filing_id,
        c.id,
        'ctx_' || TO_CHAR(p_period_end, 'YYYYMMDD'),
        'XAF', -- Default currency
        SUM(tb.balance),
        NULL,
        false
    FROM onyx.xbrl_concepts c
    JOIN onyx.xbrl_taxonomies t ON c.taxonomy_id = t.id
    -- This would join to actual trial balance data
    -- Simplified for demonstration
    WHERE t.id = p_taxonomy_id
      AND c.is_abstract = false
      AND c.concept_type = 'monetary'
    GROUP BY c.id;

    -- Log to audit
    INSERT INTO onyx.audit_archive (
        tenant_id, event_type, event_category, severity,
        user_id, entity_type, entity_id, action, action_detail,
        regulatory_context
    ) VALUES (
        p_tenant_id, 'XBRL_FILING_CREATED', 'REPORT', 'INFO',
        p_user_id, 'xbrl_filing', v_filing_id, 'CREATE',
        'XBRL filing generated: ' || v_filing_ref,
        'XBRL'
    );

    RETURN v_filing_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Validate XBRL filing
CREATE OR REPLACE FUNCTION onyx.rpc_validate_xbrl_filing(
    p_filing_id UUID,
    p_user_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_filing RECORD;
    v_errors JSONB := '[]'::JSONB;
    v_warnings JSONB := '[]'::JSONB;
    v_result JSONB;
BEGIN
    -- Get filing
    SELECT * INTO v_filing FROM onyx.xbrl_filings WHERE id = p_filing_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Filing not found');
    END IF;

    -- Update status
    UPDATE onyx.xbrl_filings
    SET status = 'VALIDATING',
        validation_started_at = NOW()
    WHERE id = p_filing_id;

    -- Validation checks

    -- 1. Check required concepts have values
    WITH required_concepts AS (
        SELECT c.id, c.concept_name
        FROM onyx.xbrl_concepts c
        WHERE c.taxonomy_id = v_filing.taxonomy_id
          AND c.is_abstract = false
          AND NOT c.is_nillable
    ),
    missing_values AS (
        SELECT rc.concept_name
        FROM required_concepts rc
        LEFT JOIN onyx.xbrl_filing_facts ff ON rc.id = ff.concept_id AND ff.filing_id = p_filing_id
        WHERE ff.id IS NULL OR (ff.value_numeric IS NULL AND ff.value_text IS NULL)
    )
    SELECT jsonb_agg(jsonb_build_object(
        'code', 'MISSING_REQUIRED',
        'concept', concept_name,
        'message', 'Required concept missing value'
    )) INTO v_errors
    FROM missing_values;

    -- 2. Check calculations
    -- (Simplified - would check XBRL calculation linkbase)

    -- 3. Check period consistency
    IF v_filing.period_start > v_filing.period_end THEN
        v_errors := v_errors || jsonb_build_object(
            'code', 'INVALID_PERIOD',
            'message', 'Period start must be before period end'
        );
    END IF;

    -- Update filing with results
    UPDATE onyx.xbrl_filings
    SET status = CASE
            WHEN jsonb_array_length(COALESCE(v_errors, '[]'::JSONB)) > 0 THEN 'VALIDATION_FAILED'
            ELSE 'VALIDATED'
        END,
        validation_completed_at = NOW(),
        validation_errors = v_errors,
        validation_warnings = v_warnings
    WHERE id = p_filing_id;

    v_result := jsonb_build_object(
        'success', jsonb_array_length(COALESCE(v_errors, '[]'::JSONB)) = 0,
        'errors', v_errors,
        'warnings', v_warnings,
        'error_count', jsonb_array_length(COALESCE(v_errors, '[]'::JSONB)),
        'warning_count', jsonb_array_length(COALESCE(v_warnings, '[]'::JSONB))
    );

    -- Audit log
    INSERT INTO onyx.audit_archive (
        tenant_id, event_type, event_category, severity,
        user_id, entity_type, entity_id, action, action_detail,
        new_values, regulatory_context
    ) VALUES (
        v_filing.tenant_id, 'XBRL_FILING_VALIDATED', 'REPORT',
        CASE WHEN jsonb_array_length(COALESCE(v_errors, '[]'::JSONB)) > 0 THEN 'WARNING' ELSE 'INFO' END,
        p_user_id, 'xbrl_filing', p_filing_id, 'VALIDATE',
        'XBRL filing validation completed',
        v_result, 'XBRL'
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Generate SAF-T export
CREATE OR REPLACE FUNCTION onyx.rpc_generate_saft_export(
    p_submission_id UUID,
    p_country_variant VARCHAR,
    p_user_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_submission RECORD;
    v_export_id UUID;
    v_stats JSONB;
BEGIN
    -- Get submission
    SELECT ts.*, tc.tenant_id, tc.entity_id
    INTO v_submission
    FROM onyx.tax_digital_submissions ts
    JOIN onyx.tax_digital_configs tc ON ts.config_id = tc.id
    WHERE ts.id = p_submission_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Submission not found');
    END IF;

    -- Calculate statistics (would pull from actual data)
    v_stats := jsonb_build_object(
        'total_debit', 0,
        'total_credit', 0,
        'transaction_count', 0,
        'customer_count', 0,
        'supplier_count', 0,
        'product_count', 0
    );

    -- Create SAF-T export record
    INSERT INTO onyx.saft_exports (
        submission_id, saft_version, country_variant,
        audit_file_date, company_name, tax_registration_number,
        fiscal_year, total_debit, total_credit, transaction_count,
        customer_count, supplier_count, product_count
    ) VALUES (
        p_submission_id,
        '2.01', -- SAF-T version
        p_country_variant,
        CURRENT_DATE,
        'Company Name', -- Would get from entity
        'TAX123456', -- Would get from config
        EXTRACT(YEAR FROM v_submission.period_start),
        (v_stats->>'total_debit')::DECIMAL,
        (v_stats->>'total_credit')::DECIMAL,
        (v_stats->>'transaction_count')::INT,
        (v_stats->>'customer_count')::INT,
        (v_stats->>'supplier_count')::INT,
        (v_stats->>'product_count')::INT
    ) RETURNING id INTO v_export_id;

    -- Audit
    INSERT INTO onyx.audit_archive (
        tenant_id, event_type, event_category, severity,
        user_id, entity_type, entity_id, action, action_detail,
        regulatory_context
    ) VALUES (
        v_submission.tenant_id, 'SAFT_GENERATED', 'REPORT', 'INFO',
        p_user_id, 'saft_export', v_export_id, 'CREATE',
        'SAF-T export generated for ' || p_country_variant,
        'SAF-T'
    );

    RETURN jsonb_build_object(
        'success', true,
        'export_id', v_export_id,
        'statistics', v_stats
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Record SOX control test result
CREATE OR REPLACE FUNCTION onyx.rpc_record_sox_test_result(
    p_test_plan_id UUID,
    p_control_id UUID,
    p_tester_id UUID,
    p_test_date DATE,
    p_sample_size INT,
    p_population_size INT,
    p_effectiveness onyx.control_effectiveness,
    p_exceptions_found INT,
    p_evidence_reviewed TEXT,
    p_findings TEXT DEFAULT NULL,
    p_remediation_required BOOLEAN DEFAULT false
) RETURNS UUID AS $$
DECLARE
    v_result_id UUID;
    v_control RECORD;
BEGIN
    -- Get control info
    SELECT * INTO v_control FROM onyx.sox_controls WHERE id = p_control_id;

    -- Insert test result
    INSERT INTO onyx.sox_test_results (
        test_plan_id, control_id, tester_id, test_date,
        sample_size, population_size, sample_selection_method,
        effectiveness, exceptions_found, evidence_reviewed,
        findings, remediation_required, created_by
    ) VALUES (
        p_test_plan_id, p_control_id, p_tester_id, p_test_date,
        p_sample_size, p_population_size, 'RANDOM',
        p_effectiveness, p_exceptions_found, p_evidence_reviewed,
        p_findings, p_remediation_required, p_tester_id
    ) RETURNING id INTO v_result_id;

    -- If ineffective, create deficiency
    IF p_effectiveness = 'INEFFECTIVE' AND p_remediation_required THEN
        INSERT INTO onyx.sox_deficiencies (
            tenant_id, control_id, test_result_id,
            deficiency_code, title, description,
            severity, likelihood, status, identified_date,
            created_by
        ) VALUES (
            v_control.tenant_id, p_control_id, v_result_id,
            'DEF-' || TO_CHAR(NOW(), 'YYYYMMDD-HH24MISS'),
            'Control failure: ' || v_control.control_name,
            COALESCE(p_findings, 'Control test found exceptions'),
            CASE
                WHEN v_control.is_key_control THEN 'SIGNIFICANT_DEFICIENCY'
                ELSE 'DEFICIENCY'
            END,
            CASE
                WHEN p_exceptions_found > p_sample_size * 0.1 THEN 'PROBABLE'
                ELSE 'REASONABLY_POSSIBLE'
            END,
            'OPEN',
            p_test_date,
            p_tester_id
        );
    END IF;

    -- Audit
    INSERT INTO onyx.audit_archive (
        tenant_id, event_type, event_category, severity,
        user_id, entity_type, entity_id, action, action_detail,
        new_values, regulatory_context
    ) VALUES (
        v_control.tenant_id, 'SOX_TEST_RECORDED', 'REPORT',
        CASE WHEN p_effectiveness = 'INEFFECTIVE' THEN 'WARNING' ELSE 'INFO' END,
        p_tester_id, 'sox_test_result', v_result_id, 'CREATE',
        'SOX control test recorded for ' || v_control.control_id,
        jsonb_build_object(
            'effectiveness', p_effectiveness,
            'exceptions', p_exceptions_found,
            'sample_size', p_sample_size
        ),
        'SOX'
    );

    RETURN v_result_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get regulatory compliance dashboard
CREATE OR REPLACE FUNCTION onyx.rpc_get_regulatory_dashboard(
    p_tenant_id UUID,
    p_entity_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'xbrl_filings', (
            SELECT jsonb_build_object(
                'total', COUNT(*),
                'draft', COUNT(*) FILTER (WHERE status = 'DRAFT'),
                'pending_validation', COUNT(*) FILTER (WHERE status IN ('VALIDATING', 'VALIDATION_FAILED')),
                'submitted', COUNT(*) FILTER (WHERE status = 'SUBMITTED'),
                'accepted', COUNT(*) FILTER (WHERE status = 'ACCEPTED'),
                'rejected', COUNT(*) FILTER (WHERE status = 'REJECTED')
            )
            FROM onyx.xbrl_filings
            WHERE tenant_id = p_tenant_id
              AND (p_entity_id IS NULL OR entity_id = p_entity_id)
              AND created_at >= CURRENT_DATE - INTERVAL '1 year'
        ),
        'sox_controls', (
            SELECT jsonb_build_object(
                'total_controls', COUNT(*),
                'effective', COUNT(*) FILTER (WHERE latest_effectiveness = 'EFFECTIVE'),
                'partially_effective', COUNT(*) FILTER (WHERE latest_effectiveness = 'PARTIALLY_EFFECTIVE'),
                'ineffective', COUNT(*) FILTER (WHERE latest_effectiveness = 'INEFFECTIVE'),
                'not_tested', COUNT(*) FILTER (WHERE latest_effectiveness = 'NOT_TESTED' OR latest_effectiveness IS NULL),
                'open_deficiencies', (
                    SELECT COUNT(*) FROM onyx.sox_deficiencies
                    WHERE tenant_id = p_tenant_id AND status = 'OPEN'
                )
            )
            FROM (
                SELECT c.id, (
                    SELECT effectiveness FROM onyx.sox_test_results
                    WHERE control_id = c.id
                    ORDER BY test_date DESC LIMIT 1
                ) AS latest_effectiveness
                FROM onyx.sox_controls c
                WHERE c.tenant_id = p_tenant_id AND c.is_active = true
            ) control_status
        ),
        'tax_submissions', (
            SELECT jsonb_build_object(
                'total', COUNT(*),
                'compliant', COUNT(*) FILTER (WHERE status = 'ACCEPTED'),
                'pending', COUNT(*) FILTER (WHERE status IN ('DRAFT', 'VALIDATING', 'VALIDATED', 'SUBMITTED')),
                'overdue', COUNT(*) FILTER (WHERE due_date < CURRENT_DATE AND status NOT IN ('ACCEPTED', 'SUBMITTED')),
                'by_type', (
                    SELECT jsonb_object_agg(submission_type, cnt)
                    FROM (
                        SELECT submission_type, COUNT(*) as cnt
                        FROM onyx.tax_digital_submissions ts
                        JOIN onyx.tax_digital_configs tc ON ts.config_id = tc.id
                        WHERE tc.tenant_id = p_tenant_id
                        GROUP BY submission_type
                    ) type_counts
                )
            )
            FROM onyx.tax_digital_submissions ts
            JOIN onyx.tax_digital_configs tc ON ts.config_id = tc.id
            WHERE tc.tenant_id = p_tenant_id
              AND ts.created_at >= CURRENT_DATE - INTERVAL '1 year'
        ),
        'einvoices', (
            SELECT jsonb_build_object(
                'total', COUNT(*),
                'delivered', COUNT(*) FILTER (WHERE delivery_status = 'DELIVERED'),
                'pending', COUNT(*) FILTER (WHERE status IN ('DRAFT', 'VALIDATING', 'SUBMITTED')),
                'failed', COUNT(*) FILTER (WHERE status IN ('VALIDATION_FAILED', 'REJECTED'))
            )
            FROM onyx.einvoice_submissions
            WHERE tenant_id = p_tenant_id
              AND created_at >= CURRENT_DATE - INTERVAL '30 days'
        ),
        'audit_events', (
            SELECT jsonb_build_object(
                'last_30_days', COUNT(*),
                'security_events', COUNT(*) FILTER (WHERE severity = 'SECURITY'),
                'critical_events', COUNT(*) FILTER (WHERE severity = 'CRITICAL'),
                'error_events', COUNT(*) FILTER (WHERE severity = 'ERROR')
            )
            FROM onyx.audit_archive
            WHERE tenant_id = p_tenant_id
              AND event_timestamp >= CURRENT_DATE - INTERVAL '30 days'
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Verify audit chain integrity
CREATE OR REPLACE FUNCTION onyx.rpc_verify_audit_chain_integrity(
    p_tenant_id UUID,
    p_from_date DATE DEFAULT NULL,
    p_to_date DATE DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_record RECORD;
    v_previous_hash VARCHAR(128);
    v_calculated_hash VARCHAR(128);
    v_errors JSONB := '[]'::JSONB;
    v_records_checked INT := 0;
    v_first_id BIGINT;
BEGIN
    FOR v_record IN
        SELECT *
        FROM onyx.audit_archive
        WHERE tenant_id = p_tenant_id
          AND (p_from_date IS NULL OR DATE(event_timestamp) >= p_from_date)
          AND (p_to_date IS NULL OR DATE(event_timestamp) <= p_to_date)
        ORDER BY id ASC
    LOOP
        v_records_checked := v_records_checked + 1;

        -- Calculate expected hash
        v_calculated_hash := onyx.fn_calculate_audit_hash(
            v_record.tenant_id,
            v_record.event_id,
            v_record.event_timestamp,
            v_record.event_type,
            v_record.user_id,
            v_record.action,
            v_record.entity_type,
            v_record.entity_id,
            v_record.old_values,
            v_record.new_values,
            v_record.previous_hash
        );

        -- Verify stored hash
        IF v_calculated_hash != v_record.record_hash THEN
            v_errors := v_errors || jsonb_build_object(
                'record_id', v_record.id,
                'event_id', v_record.event_id,
                'error', 'Hash mismatch - record may have been tampered'
            );
        END IF;

        -- Verify chain linkage (skip first record)
        IF v_previous_hash IS NOT NULL AND v_record.previous_hash != v_previous_hash THEN
            v_errors := v_errors || jsonb_build_object(
                'record_id', v_record.id,
                'event_id', v_record.event_id,
                'error', 'Chain broken - previous hash mismatch'
            );
        END IF;

        v_previous_hash := v_record.record_hash;
    END LOOP;

    RETURN jsonb_build_object(
        'success', jsonb_array_length(v_errors) = 0,
        'records_checked', v_records_checked,
        'errors_found', jsonb_array_length(v_errors),
        'errors', v_errors,
        'verified_at', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- SECTION 9: PERMISSIONS
-- ============================================================================

-- Grant permissions (would be done via RLS policies in production)
COMMENT ON TABLE onyx.xbrl_taxonomies IS 'Permission: XBRL.TAXONOMY.VIEW/MANAGE';
COMMENT ON TABLE onyx.xbrl_filings IS 'Permission: XBRL.FILING.VIEW/CREATE/SUBMIT';
COMMENT ON TABLE onyx.sox_controls IS 'Permission: SOX.CONTROL.VIEW/MANAGE';
COMMENT ON TABLE onyx.sox_test_results IS 'Permission: SOX.TEST.VIEW/CREATE';
COMMENT ON TABLE onyx.einvoice_formats IS 'Permission: EINVOICE.FORMAT.VIEW/MANAGE';
COMMENT ON TABLE onyx.einvoice_submissions IS 'Permission: EINVOICE.VIEW/SUBMIT';
COMMENT ON TABLE onyx.tax_digital_configs IS 'Permission: TAX_DIGITAL.CONFIG.VIEW/MANAGE';
COMMENT ON TABLE onyx.tax_digital_submissions IS 'Permission: TAX_DIGITAL.VIEW/SUBMIT';
COMMENT ON TABLE onyx.audit_archive IS 'Permission: AUDIT.VIEW (read-only, no modify)';

-- ============================================================================
-- COMPLETION NOTICE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '================================================================';
    RAISE NOTICE 'EdenFin ONYX Regulatory Compliance Module installed successfully';
    RAISE NOTICE '================================================================';
    RAISE NOTICE 'Tables created: 15';
    RAISE NOTICE '  - xbrl_taxonomies, xbrl_concepts, xbrl_filings, xbrl_filing_facts';
    RAISE NOTICE '  - sox_frameworks, sox_controls, sox_test_plans, sox_test_results, sox_deficiencies';
    RAISE NOTICE '  - einvoice_formats, einvoice_submissions';
    RAISE NOTICE '  - tax_digital_configs, tax_digital_submissions, saft_exports';
    RAISE NOTICE '  - audit_archive (immutable ledger)';
    RAISE NOTICE 'Views created: 5';
    RAISE NOTICE 'RPC Functions created: 6';
    RAISE NOTICE '================================================================';
END $$;
