-- =====================================================
-- Fix integration (Sprint 3) : modele de tenant harmonise sur le socle BIGINT.
--   tenant_id/fiscal_year_id UUID -> BIGINT ; common.tenants -> sys.tenants ;
--   common.fiscal_years -> client_demo.fiscal_exercises. Voir SPRINT3_ONYX.md.
-- ROLLBACK : retablir les types UUID et les references common.* d origine.
-- EdenFin ONYX Tier: Public Sector & Fund Accounting
-- Target: GE (250+ employees, government/public entities)
-- =====================================================
-- Features:
--   - Fund accounting (governmental funds)
--   - Appropriations & budget authority
--   - Encumbrances (commitment accounting)
--   - Grant management
--   - IPSAS compliance
--   - Inter-fund transfers
--   - Public procurement integration
--   - Budget amendments
--   - Fiscal year carry-forward
-- =====================================================

-- ===========================================
-- SECTION 1: ENUMS
-- ===========================================

CREATE TYPE onyx.fund_type AS ENUM (
    'GENERAL',              -- General Fund (unrestricted)
    'SPECIAL_REVENUE',      -- Special Revenue Funds
    'CAPITAL_PROJECTS',     -- Capital Projects Fund
    'DEBT_SERVICE',         -- Debt Service Fund
    'ENTERPRISE',           -- Enterprise Funds (business-like)
    'INTERNAL_SERVICE',     -- Internal Service Funds
    'TRUST',                -- Trust Funds (fiduciary)
    'AGENCY',               -- Agency Funds (custodial)
    'PENSION',              -- Pension Funds
    'INVESTMENT'            -- Investment Funds
);

CREATE TYPE onyx.fund_category AS ENUM (
    'GOVERNMENTAL',         -- Governmental funds
    'PROPRIETARY',          -- Proprietary funds (enterprise, internal service)
    'FIDUCIARY'             -- Fiduciary funds (trust, agency, pension)
);

CREATE TYPE onyx.appropriation_type AS ENUM (
    'OPERATING',            -- Operating expenses
    'CAPITAL',              -- Capital expenditures
    'PERSONNEL',            -- Personnel costs
    'TRANSFER',             -- Interfund transfers
    'DEBT_SERVICE',         -- Debt principal & interest
    'CONTINGENCY'           -- Contingency/reserve
);

CREATE TYPE onyx.appropriation_status AS ENUM (
    'DRAFT',
    'PROPOSED',
    'APPROVED',
    'ACTIVE',
    'FROZEN',
    'CLOSED',
    'LAPSED'
);

CREATE TYPE onyx.encumbrance_type AS ENUM (
    'PURCHASE_ORDER',       -- PO encumbrance
    'CONTRACT',             -- Contract encumbrance
    'RESERVATION',          -- Budget reservation
    'COMMITMENT',           -- Other commitment
    'PRE_ENCUMBRANCE'       -- Requisition (pre-PO)
);

CREATE TYPE onyx.encumbrance_status AS ENUM (
    'OPEN',
    'PARTIALLY_LIQUIDATED',
    'FULLY_LIQUIDATED',
    'CANCELLED',
    'CARRIED_FORWARD'
);

CREATE TYPE onyx.grant_type AS ENUM (
    'FEDERAL',              -- Federal government grant
    'STATE',                -- State/regional grant
    'LOCAL',                -- Local government grant
    'INTERNATIONAL',        -- International organization
    'PRIVATE',              -- Private foundation
    'PASS_THROUGH'          -- Pass-through grant
);

CREATE TYPE onyx.grant_status AS ENUM (
    'APPLIED',
    'AWARDED',
    'ACTIVE',
    'SUSPENDED',
    'CLOSED',
    'RETURNED'
);

CREATE TYPE onyx.amendment_type AS ENUM (
    'SUPPLEMENTAL',         -- Additional appropriation
    'TRANSFER',             -- Between categories
    'REDUCTION',            -- Budget cut
    'REALLOCATION',         -- Within same total
    'EMERGENCY',            -- Emergency appropriation
    'TECHNICAL'             -- Technical correction
);

-- ===========================================
-- SECTION 2: FUND STRUCTURE
-- ===========================================

-- Fund definitions
CREATE TABLE onyx.funds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),

    -- Identification
    fund_code VARCHAR(20) NOT NULL,
    fund_name VARCHAR(200) NOT NULL,
    description TEXT,

    -- Classification
    fund_type onyx.fund_type NOT NULL,
    fund_category onyx.fund_category NOT NULL,

    -- Hierarchy
    parent_fund_id UUID REFERENCES onyx.funds(id),
    fund_level INT DEFAULT 1,

    -- Legal basis
    legal_authority VARCHAR(200),       -- Law or regulation creating fund
    establishment_date DATE,
    sunset_date DATE,                   -- When fund expires (if applicable)

    -- Restrictions
    is_restricted BOOLEAN DEFAULT false,
    restriction_type VARCHAR(50),       -- LEGAL, DONOR, CONTRACTUAL
    restriction_description TEXT,

    -- Accounting
    fund_balance_account VARCHAR(20),
    revenues_account_prefix VARCHAR(10),
    expenditures_account_prefix VARCHAR(10),

    -- Reporting
    is_major_fund BOOLEAN DEFAULT false,
    reporting_category VARCHAR(50),
    cafr_classification VARCHAR(50),    -- CAFR = Comprehensive Annual Financial Report

    -- State
    is_active BOOLEAN DEFAULT true,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT now(),

    UNIQUE(tenant_id, fund_code)
);

-- Fund fiscal year settings
CREATE TABLE onyx.fund_fiscal_years (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fund_id UUID NOT NULL REFERENCES onyx.funds(id),
    fiscal_year_id BIGINT NOT NULL REFERENCES client_demo.fiscal_exercises(id),

    -- Budget
    original_budget DECIMAL(20,2) DEFAULT 0,
    revised_budget DECIMAL(20,2) DEFAULT 0,
    final_budget DECIMAL(20,2) DEFAULT 0,

    -- Balances
    beginning_fund_balance DECIMAL(20,2) DEFAULT 0,
    ending_fund_balance DECIMAL(20,2),

    -- Encumbrances
    encumbrances_outstanding DECIMAL(20,2) DEFAULT 0,
    encumbrances_carried_forward DECIMAL(20,2) DEFAULT 0,

    -- Status
    is_closed BOOLEAN DEFAULT false,
    closed_at TIMESTAMPTZ,
    closed_by UUID,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),

    UNIQUE(fund_id, fiscal_year_id)
);

-- ===========================================
-- SECTION 3: APPROPRIATIONS
-- ===========================================

CREATE TABLE onyx.appropriations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fund_id UUID NOT NULL REFERENCES onyx.funds(id),
    fiscal_year_id BIGINT NOT NULL REFERENCES client_demo.fiscal_exercises(id),

    -- Identification
    appropriation_code VARCHAR(30) NOT NULL,
    appropriation_name VARCHAR(200) NOT NULL,
    description TEXT,

    -- Classification
    appropriation_type onyx.appropriation_type NOT NULL,

    -- Organizational
    department_id UUID,
    program_id UUID,
    project_id UUID,

    -- Budget structure (OHADA compatible)
    budget_chapter VARCHAR(10),
    budget_article VARCHAR(10),
    budget_paragraph VARCHAR(10),
    economic_classification VARCHAR(20),
    functional_classification VARCHAR(20),

    -- Amounts
    original_amount DECIMAL(20,2) NOT NULL,
    amendments_amount DECIMAL(20,2) DEFAULT 0,
    transfers_in DECIMAL(20,2) DEFAULT 0,
    transfers_out DECIMAL(20,2) DEFAULT 0,
    current_amount DECIMAL(20,2) GENERATED ALWAYS AS (
        original_amount + amendments_amount + transfers_in - transfers_out
    ) STORED,

    -- Execution
    encumbered DECIMAL(20,2) DEFAULT 0,
    expended DECIMAL(20,2) DEFAULT 0,
    available DECIMAL(20,2) GENERATED ALWAYS AS (
        original_amount + amendments_amount + transfers_in - transfers_out - encumbered - expended
    ) STORED,

    -- Control
    allotment_control BOOLEAN DEFAULT true,   -- Enforce budget limits
    allow_overspend BOOLEAN DEFAULT false,
    overspend_limit_pct DECIMAL(5,2) DEFAULT 0,

    -- Timing
    effective_date DATE NOT NULL,
    expiration_date DATE,
    is_continuing BOOLEAN DEFAULT false,      -- Multi-year appropriation

    -- Carry-forward
    carry_forward_eligible BOOLEAN DEFAULT false,
    carry_forward_percentage DECIMAL(5,2) DEFAULT 100,
    carry_forward_max_amount DECIMAL(20,2),

    -- Status
    status onyx.appropriation_status DEFAULT 'DRAFT',
    approved_at TIMESTAMPTZ,
    approved_by UUID,

    -- Legal reference
    legislation_reference VARCHAR(100),
    authorization_document_id UUID,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT now(),

    UNIQUE(fund_id, fiscal_year_id, appropriation_code)
);

-- Budget amendments
CREATE TABLE onyx.budget_amendments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    fiscal_year_id BIGINT NOT NULL REFERENCES client_demo.fiscal_exercises(id),

    -- Identification
    amendment_number VARCHAR(30) NOT NULL,
    amendment_type onyx.amendment_type NOT NULL,
    description TEXT NOT NULL,

    -- Amounts
    total_increase DECIMAL(20,2) DEFAULT 0,
    total_decrease DECIMAL(20,2) DEFAULT 0,
    net_change DECIMAL(20,2) GENERATED ALWAYS AS (total_increase - total_decrease) STORED,

    -- Status
    status VARCHAR(20) DEFAULT 'DRAFT',
    submitted_at TIMESTAMPTZ,
    submitted_by UUID,
    approved_at TIMESTAMPTZ,
    approved_by UUID,

    -- Legal
    resolution_number VARCHAR(50),
    resolution_date DATE,
    effective_date DATE,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT now(),

    UNIQUE(tenant_id, fiscal_year_id, amendment_number)
);

CREATE TABLE onyx.budget_amendment_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    amendment_id UUID NOT NULL REFERENCES onyx.budget_amendments(id) ON DELETE CASCADE,
    appropriation_id UUID NOT NULL REFERENCES onyx.appropriations(id),

    -- Change
    amount DECIMAL(20,2) NOT NULL,  -- Positive = increase, negative = decrease
    reason TEXT,

    -- Previous value (for audit)
    previous_amount DECIMAL(20,2),

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ===========================================
-- SECTION 4: ENCUMBRANCES
-- ===========================================

CREATE TABLE onyx.encumbrances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    appropriation_id UUID NOT NULL REFERENCES onyx.appropriations(id),

    -- Identification
    encumbrance_number VARCHAR(30) NOT NULL,
    encumbrance_type onyx.encumbrance_type NOT NULL,
    description TEXT,

    -- Reference documents
    purchase_order_id UUID,
    contract_id UUID,
    requisition_id UUID,

    -- Vendor
    vendor_id UUID,
    vendor_name VARCHAR(200),

    -- Amounts
    original_amount DECIMAL(20,2) NOT NULL,
    liquidated_amount DECIMAL(20,2) DEFAULT 0,
    cancelled_amount DECIMAL(20,2) DEFAULT 0,
    outstanding_amount DECIMAL(20,2) GENERATED ALWAYS AS (
        original_amount - liquidated_amount - cancelled_amount
    ) STORED,

    -- Dates
    encumbrance_date DATE NOT NULL,
    expected_liquidation_date DATE,
    expiration_date DATE,

    -- Status
    status onyx.encumbrance_status DEFAULT 'OPEN',

    -- Carry-forward
    is_carried_forward BOOLEAN DEFAULT false,
    original_fiscal_year_id UUID,
    carry_forward_date DATE,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT now(),

    UNIQUE(appropriation_id, encumbrance_number)
);

-- Encumbrance liquidations (link to actual expenditures)
CREATE TABLE onyx.encumbrance_liquidations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encumbrance_id UUID NOT NULL REFERENCES onyx.encumbrances(id),

    -- Amount
    liquidation_amount DECIMAL(20,2) NOT NULL,
    liquidation_date DATE NOT NULL,

    -- Reference
    invoice_id UUID,
    payment_id UUID,
    voucher_number VARCHAR(30),

    -- Variance
    is_final_liquidation BOOLEAN DEFAULT false,
    variance_amount DECIMAL(20,2),  -- Difference from encumbrance

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    created_by UUID
);

-- ===========================================
-- SECTION 5: GRANTS
-- ===========================================

CREATE TABLE onyx.grants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    fund_id UUID REFERENCES onyx.funds(id),  -- Dedicated fund for grant

    -- Identification
    grant_number VARCHAR(50) NOT NULL,
    grant_name VARCHAR(300) NOT NULL,
    description TEXT,

    -- Classification
    grant_type onyx.grant_type NOT NULL,
    cfda_number VARCHAR(20),  -- Catalog of Federal Domestic Assistance (US)
    program_area VARCHAR(100),

    -- Grantor
    grantor_name VARCHAR(200) NOT NULL,
    grantor_agency VARCHAR(200),
    grantor_contact VARCHAR(200),
    grantor_email VARCHAR(100),

    -- Pass-through (if applicable)
    is_pass_through BOOLEAN DEFAULT false,
    pass_through_entity VARCHAR(200),
    pass_through_grant_number VARCHAR(50),

    -- Award
    award_date DATE,
    award_amount DECIMAL(20,2) NOT NULL,
    match_required DECIMAL(20,2) DEFAULT 0,
    match_percentage DECIMAL(5,2),
    indirect_cost_rate DECIMAL(7,4),

    -- Period
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    closeout_deadline DATE,

    -- Execution
    amount_received DECIMAL(20,2) DEFAULT 0,
    amount_expended DECIMAL(20,2) DEFAULT 0,
    amount_remaining DECIMAL(20,2) GENERATED ALWAYS AS (award_amount - amount_expended) STORED,

    -- Compliance
    requires_audit BOOLEAN DEFAULT true,
    audit_threshold DECIMAL(20,2),
    reporting_frequency VARCHAR(20),  -- MONTHLY, QUARTERLY, ANNUAL
    last_report_date DATE,
    next_report_due DATE,

    -- Status
    status onyx.grant_status DEFAULT 'APPLIED',

    -- Risk
    risk_level VARCHAR(20),  -- LOW, MEDIUM, HIGH
    monitoring_notes TEXT,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT now(),

    UNIQUE(tenant_id, grant_number)
);

-- Grant budget by category
CREATE TABLE onyx.grant_budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    grant_id UUID NOT NULL REFERENCES onyx.grants(id) ON DELETE CASCADE,

    -- Category
    budget_category VARCHAR(50) NOT NULL,  -- PERSONNEL, SUPPLIES, TRAVEL, etc.
    budget_subcategory VARCHAR(50),

    -- Amounts
    original_budget DECIMAL(20,2) NOT NULL,
    amendments DECIMAL(20,2) DEFAULT 0,
    current_budget DECIMAL(20,2) GENERATED ALWAYS AS (original_budget + amendments) STORED,
    expended DECIMAL(20,2) DEFAULT 0,
    encumbered DECIMAL(20,2) DEFAULT 0,
    available DECIMAL(20,2) GENERATED ALWAYS AS (
        original_budget + amendments - expended - encumbered
    ) STORED,

    -- Flexibility
    is_flexible BOOLEAN DEFAULT false,  -- Can transfer between categories
    flexibility_limit_pct DECIMAL(5,2),

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),

    UNIQUE(grant_id, budget_category, budget_subcategory)
);

-- Grant drawdowns (reimbursement requests)
CREATE TABLE onyx.grant_drawdowns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    grant_id UUID NOT NULL REFERENCES onyx.grants(id),

    -- Identification
    drawdown_number VARCHAR(30) NOT NULL,
    request_date DATE NOT NULL,

    -- Amounts
    amount_requested DECIMAL(20,2) NOT NULL,
    amount_received DECIMAL(20,2),
    date_received DATE,

    -- Period covered
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,

    -- Supporting documentation
    expenditure_report_id UUID,
    supporting_documents JSONB DEFAULT '[]',

    -- Status
    status VARCHAR(20) DEFAULT 'DRAFT',  -- DRAFT, SUBMITTED, APPROVED, RECEIVED, REJECTED
    submitted_at TIMESTAMPTZ,
    approved_at TIMESTAMPTZ,

    -- Rejection
    rejection_reason TEXT,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    created_by UUID
);

-- ===========================================
-- SECTION 6: INTER-FUND TRANSFERS
-- ===========================================

CREATE TABLE onyx.fund_transfers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fiscal_year_id BIGINT NOT NULL REFERENCES client_demo.fiscal_exercises(id),

    -- Identification
    transfer_number VARCHAR(30) NOT NULL,
    description TEXT NOT NULL,

    -- Funds
    from_fund_id UUID NOT NULL REFERENCES onyx.funds(id),
    to_fund_id UUID NOT NULL REFERENCES onyx.funds(id),

    -- Appropriations (optional - for budget tracking)
    from_appropriation_id UUID REFERENCES onyx.appropriations(id),
    to_appropriation_id UUID REFERENCES onyx.appropriations(id),

    -- Amount
    amount DECIMAL(20,2) NOT NULL,

    -- Type
    transfer_type VARCHAR(20) NOT NULL,  -- ROUTINE, RESIDUAL, REIMBURSEMENT, LOAN

    -- For loans
    is_loan BOOLEAN DEFAULT false,
    loan_repayment_date DATE,
    interest_rate DECIMAL(7,4),

    -- Status
    status VARCHAR(20) DEFAULT 'PENDING',
    approved_at TIMESTAMPTZ,
    approved_by UUID,
    executed_at TIMESTAMPTZ,

    -- Journal entry reference
    journal_entry_id UUID,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    created_by UUID,

    UNIQUE(fiscal_year_id, transfer_number),
    CHECK(from_fund_id != to_fund_id)
);

-- ===========================================
-- SECTION 7: IPSAS COMPLIANCE
-- ===========================================

-- IPSAS account mappings
CREATE TABLE onyx.ipsas_mappings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),

    -- Local account
    local_account_code VARCHAR(20) NOT NULL,
    local_account_name VARCHAR(200),

    -- IPSAS mapping
    ipsas_standard VARCHAR(20) NOT NULL,  -- IPSAS 1, IPSAS 17, etc.
    ipsas_element VARCHAR(100) NOT NULL,  -- Asset, Liability, Revenue, etc.
    ipsas_category VARCHAR(100),
    ipsas_subcategory VARCHAR(100),

    -- Notes
    mapping_notes TEXT,

    -- State
    is_active BOOLEAN DEFAULT true,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),

    UNIQUE(tenant_id, local_account_code)
);

-- IPSAS adjustments
CREATE TABLE onyx.ipsas_adjustments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    fiscal_year_id BIGINT NOT NULL REFERENCES client_demo.fiscal_exercises(id),

    -- Identification
    adjustment_number VARCHAR(30) NOT NULL,
    adjustment_type VARCHAR(50) NOT NULL,  -- ACCRUAL, DEPRECIATION, REVALUATION, etc.
    description TEXT,

    -- IPSAS standard reference
    ipsas_standard VARCHAR(20),
    ipsas_paragraph VARCHAR(20),

    -- Status
    status VARCHAR(20) DEFAULT 'DRAFT',
    approved_at TIMESTAMPTZ,
    approved_by UUID,

    -- Journal entry
    journal_entry_id UUID,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    created_by UUID,

    UNIQUE(tenant_id, fiscal_year_id, adjustment_number)
);

-- ===========================================
-- SECTION 8: VIEWS
-- ===========================================

-- Fund summary view
CREATE OR REPLACE VIEW onyx.v_fund_summary AS
SELECT
    f.id AS fund_id,
    f.fund_code,
    f.fund_name,
    f.fund_type,
    f.fund_category,
    ffy.fiscal_year_id,
    ffy.original_budget,
    ffy.revised_budget,
    ffy.beginning_fund_balance,
    COALESCE(SUM(a.current_amount), 0) AS total_appropriations,
    COALESCE(SUM(a.encumbered), 0) AS total_encumbered,
    COALESCE(SUM(a.expended), 0) AS total_expended,
    COALESCE(SUM(a.available), 0) AS total_available,
    ROUND(100.0 * COALESCE(SUM(a.expended), 0) / NULLIF(COALESCE(SUM(a.current_amount), 0), 0), 2) AS execution_rate
FROM onyx.funds f
LEFT JOIN onyx.fund_fiscal_years ffy ON f.id = ffy.fund_id
LEFT JOIN onyx.appropriations a ON f.id = a.fund_id AND a.fiscal_year_id = ffy.fiscal_year_id
WHERE f.is_active = true
GROUP BY f.id, f.fund_code, f.fund_name, f.fund_type, f.fund_category,
         ffy.fiscal_year_id, ffy.original_budget, ffy.revised_budget, ffy.beginning_fund_balance;

-- Appropriation status view
CREATE OR REPLACE VIEW onyx.v_appropriation_status AS
SELECT
    a.id AS appropriation_id,
    a.appropriation_code,
    a.appropriation_name,
    a.appropriation_type,
    f.fund_code,
    f.fund_name,
    a.original_amount,
    a.amendments_amount,
    a.transfers_in,
    a.transfers_out,
    a.current_amount,
    a.encumbered,
    a.expended,
    a.available,
    ROUND(100.0 * a.expended / NULLIF(a.current_amount, 0), 2) AS expenditure_rate,
    ROUND(100.0 * (a.encumbered + a.expended) / NULLIF(a.current_amount, 0), 2) AS commitment_rate,
    CASE
        WHEN a.available < 0 THEN 'OVERSPENT'
        WHEN a.available < a.current_amount * 0.1 THEN 'LOW_BALANCE'
        WHEN a.expended / NULLIF(a.current_amount, 0) < 0.5 THEN 'UNDER_EXECUTED'
        ELSE 'NORMAL'
    END AS status_flag,
    a.status
FROM onyx.appropriations a
JOIN onyx.funds f ON a.fund_id = f.id;

-- Encumbrance aging view
CREATE OR REPLACE VIEW onyx.v_encumbrance_aging AS
SELECT
    e.id AS encumbrance_id,
    e.encumbrance_number,
    e.encumbrance_type,
    e.vendor_name,
    e.original_amount,
    e.outstanding_amount,
    e.encumbrance_date,
    e.expected_liquidation_date,
    CURRENT_DATE - e.encumbrance_date AS days_outstanding,
    CASE
        WHEN CURRENT_DATE - e.encumbrance_date <= 30 THEN '0-30 days'
        WHEN CURRENT_DATE - e.encumbrance_date <= 60 THEN '31-60 days'
        WHEN CURRENT_DATE - e.encumbrance_date <= 90 THEN '61-90 days'
        WHEN CURRENT_DATE - e.encumbrance_date <= 180 THEN '91-180 days'
        ELSE 'Over 180 days'
    END AS aging_bucket,
    e.status,
    a.appropriation_code,
    f.fund_code
FROM onyx.encumbrances e
JOIN onyx.appropriations a ON e.appropriation_id = a.id
JOIN onyx.funds f ON a.fund_id = f.id
WHERE e.status IN ('OPEN', 'PARTIALLY_LIQUIDATED');

-- Grant summary view
CREATE OR REPLACE VIEW onyx.v_grant_summary AS
SELECT
    g.id AS grant_id,
    g.grant_number,
    g.grant_name,
    g.grant_type,
    g.grantor_name,
    g.award_amount,
    g.match_required,
    g.amount_received,
    g.amount_expended,
    g.amount_remaining,
    ROUND(100.0 * g.amount_expended / NULLIF(g.award_amount, 0), 2) AS burn_rate,
    g.start_date,
    g.end_date,
    g.end_date - CURRENT_DATE AS days_remaining,
    CASE
        WHEN g.status != 'ACTIVE' THEN g.status::TEXT
        WHEN g.end_date < CURRENT_DATE THEN 'EXPIRED'
        WHEN g.end_date - CURRENT_DATE <= 30 THEN 'ENDING_SOON'
        WHEN g.amount_remaining / NULLIF(g.award_amount, 0) < 0.1 THEN 'LOW_FUNDS'
        ELSE 'ACTIVE'
    END AS status_flag,
    g.status,
    g.risk_level
FROM onyx.grants g;

-- Budget vs Actual comparison
CREATE OR REPLACE VIEW onyx.v_budget_vs_actual AS
SELECT
    a.fiscal_year_id,
    f.fund_code,
    f.fund_name,
    a.appropriation_type,
    SUM(a.original_amount) AS original_budget,
    SUM(a.current_amount) AS revised_budget,
    SUM(a.expended) AS actual_expenditure,
    SUM(a.current_amount) - SUM(a.expended) AS variance,
    ROUND(100.0 * SUM(a.expended) / NULLIF(SUM(a.current_amount), 0), 2) AS pct_spent
FROM onyx.appropriations a
JOIN onyx.funds f ON a.fund_id = f.id
GROUP BY a.fiscal_year_id, f.fund_code, f.fund_name, a.appropriation_type;

-- ===========================================
-- SECTION 9: RPC FUNCTIONS
-- ===========================================

-- Check appropriation availability
CREATE OR REPLACE FUNCTION onyx.rpc_check_appropriation(
    p_appropriation_id UUID,
    p_amount DECIMAL
) RETURNS JSONB LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_appropriation RECORD;
    v_result JSONB;
BEGIN
    SELECT * INTO v_appropriation
    FROM onyx.appropriations
    WHERE id = p_appropriation_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Appropriation not found');
    END IF;

    IF v_appropriation.status != 'ACTIVE' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Appropriation not active',
            'status', v_appropriation.status
        );
    END IF;

    IF NOT v_appropriation.allotment_control THEN
        RETURN jsonb_build_object('success', true, 'message', 'No allotment control');
    END IF;

    IF p_amount > v_appropriation.available THEN
        IF v_appropriation.allow_overspend THEN
            DECLARE
                v_max_overspend DECIMAL;
            BEGIN
                v_max_overspend := v_appropriation.current_amount * v_appropriation.overspend_limit_pct / 100;
                IF p_amount <= v_appropriation.available + v_max_overspend THEN
                    RETURN jsonb_build_object(
                        'success', true,
                        'warning', 'Overspend within limit',
                        'available', v_appropriation.available,
                        'requested', p_amount
                    );
                END IF;
            END;
        END IF;
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient appropriation',
            'available', v_appropriation.available,
            'requested', p_amount,
            'shortfall', p_amount - v_appropriation.available
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'available', v_appropriation.available,
        'requested', p_amount,
        'remaining_after', v_appropriation.available - p_amount
    );
END;
$$;

-- Create encumbrance
CREATE OR REPLACE FUNCTION onyx.rpc_create_encumbrance(
    p_appropriation_id UUID,
    p_encumbrance_type onyx.encumbrance_type,
    p_amount DECIMAL,
    p_vendor_name VARCHAR,
    p_description TEXT,
    p_reference_id UUID,
    p_user_id UUID
) RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
    v_check JSONB;
    v_enc_number VARCHAR;
    v_enc_id UUID;
BEGIN
    -- Check availability
    v_check := onyx.rpc_check_appropriation(p_appropriation_id, p_amount);
    IF NOT (v_check->>'success')::BOOLEAN THEN
        RETURN v_check;
    END IF;

    -- Generate encumbrance number
    SELECT 'ENC-' || to_char(now(), 'YYYYMMDD') || '-' ||
           LPAD((COUNT(*) + 1)::TEXT, 5, '0')
    INTO v_enc_number
    FROM onyx.encumbrances
    WHERE encumbrance_date = CURRENT_DATE;

    -- Create encumbrance
    INSERT INTO onyx.encumbrances (
        appropriation_id, encumbrance_number, encumbrance_type,
        description, vendor_name, original_amount, encumbrance_date,
        purchase_order_id, contract_id, created_by
    ) VALUES (
        p_appropriation_id, v_enc_number, p_encumbrance_type,
        p_description, p_vendor_name, p_amount, CURRENT_DATE,
        CASE WHEN p_encumbrance_type = 'PURCHASE_ORDER' THEN p_reference_id END,
        CASE WHEN p_encumbrance_type = 'CONTRACT' THEN p_reference_id END,
        p_user_id
    ) RETURNING id INTO v_enc_id;

    -- Update appropriation
    UPDATE onyx.appropriations
    SET encumbered = encumbered + p_amount,
        updated_at = now()
    WHERE id = p_appropriation_id;

    RETURN jsonb_build_object(
        'success', true,
        'encumbrance_id', v_enc_id,
        'encumbrance_number', v_enc_number,
        'amount', p_amount
    );
END;
$$;

-- Liquidate encumbrance
CREATE OR REPLACE FUNCTION onyx.rpc_liquidate_encumbrance(
    p_encumbrance_id UUID,
    p_amount DECIMAL,
    p_invoice_id UUID,
    p_is_final BOOLEAN,
    p_user_id UUID
) RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
    v_encumbrance RECORD;
    v_variance DECIMAL;
BEGIN
    SELECT * INTO v_encumbrance
    FROM onyx.encumbrances
    WHERE id = p_encumbrance_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Encumbrance not found');
    END IF;

    IF v_encumbrance.status IN ('FULLY_LIQUIDATED', 'CANCELLED') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Encumbrance already closed');
    END IF;

    IF p_amount > v_encumbrance.outstanding_amount THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Liquidation exceeds outstanding amount',
            'outstanding', v_encumbrance.outstanding_amount,
            'requested', p_amount
        );
    END IF;

    -- Calculate variance if final
    IF p_is_final THEN
        v_variance := v_encumbrance.outstanding_amount - p_amount;
    END IF;

    -- Record liquidation
    INSERT INTO onyx.encumbrance_liquidations (
        encumbrance_id, liquidation_amount, liquidation_date,
        invoice_id, is_final_liquidation, variance_amount, created_by
    ) VALUES (
        p_encumbrance_id, p_amount, CURRENT_DATE,
        p_invoice_id, p_is_final, v_variance, p_user_id
    );

    -- Update encumbrance
    UPDATE onyx.encumbrances
    SET liquidated_amount = liquidated_amount + p_amount,
        status = CASE
            WHEN p_is_final THEN 'FULLY_LIQUIDATED'
            WHEN liquidated_amount + p_amount >= original_amount THEN 'FULLY_LIQUIDATED'
            ELSE 'PARTIALLY_LIQUIDATED'
        END,
        cancelled_amount = CASE WHEN p_is_final THEN COALESCE(v_variance, 0) ELSE cancelled_amount END,
        updated_at = now()
    WHERE id = p_encumbrance_id;

    -- Update appropriation
    UPDATE onyx.appropriations
    SET encumbered = encumbered - p_amount - COALESCE(v_variance, 0),
        expended = expended + p_amount,
        updated_at = now()
    WHERE id = v_encumbrance.appropriation_id;

    RETURN jsonb_build_object(
        'success', true,
        'liquidated', p_amount,
        'variance', v_variance,
        'is_final', p_is_final
    );
END;
$$;

-- Process fiscal year carry-forward
CREATE OR REPLACE FUNCTION onyx.rpc_process_carry_forward(
    p_from_fiscal_year_id UUID,
    p_to_fiscal_year_id UUID,
    p_user_id UUID
) RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
    v_enc RECORD;
    v_cf_count INT := 0;
    v_cf_amount DECIMAL := 0;
BEGIN
    -- Process eligible encumbrances
    FOR v_enc IN (
        SELECT e.*, a.carry_forward_eligible, a.carry_forward_percentage, a.carry_forward_max_amount
        FROM onyx.encumbrances e
        JOIN onyx.appropriations a ON e.appropriation_id = a.id
        WHERE a.fiscal_year_id = p_from_fiscal_year_id
          AND e.status IN ('OPEN', 'PARTIALLY_LIQUIDATED')
          AND a.carry_forward_eligible = true
    ) LOOP
        -- Calculate carry-forward amount
        DECLARE
            v_cf_enc_amount DECIMAL;
        BEGIN
            v_cf_enc_amount := v_enc.outstanding_amount * v_enc.carry_forward_percentage / 100;
            IF v_enc.carry_forward_max_amount IS NOT NULL THEN
                v_cf_enc_amount := LEAST(v_cf_enc_amount, v_enc.carry_forward_max_amount);
            END IF;

            -- Mark original as carried forward
            UPDATE onyx.encumbrances
            SET status = 'CARRIED_FORWARD',
                updated_at = now()
            WHERE id = v_enc.id;

            -- Create new encumbrance in new year
            -- (Would need to find/create corresponding appropriation in new year)
            -- Simplified: just track the amounts

            v_cf_count := v_cf_count + 1;
            v_cf_amount := v_cf_amount + v_cf_enc_amount;
        END;
    END LOOP;

    -- Update fund fiscal year records
    UPDATE onyx.fund_fiscal_years
    SET encumbrances_carried_forward = v_cf_amount,
        is_closed = true,
        closed_at = now(),
        closed_by = p_user_id
    WHERE fiscal_year_id = p_from_fiscal_year_id;

    RETURN jsonb_build_object(
        'success', true,
        'encumbrances_carried', v_cf_count,
        'amount_carried', v_cf_amount,
        'from_year', p_from_fiscal_year_id,
        'to_year', p_to_fiscal_year_id
    );
END;
$$;

-- Grant expenditure tracking
CREATE OR REPLACE FUNCTION onyx.rpc_record_grant_expenditure(
    p_grant_id UUID,
    p_budget_category VARCHAR,
    p_amount DECIMAL,
    p_description TEXT,
    p_user_id UUID
) RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
    v_budget RECORD;
BEGIN
    -- Get budget line
    SELECT * INTO v_budget
    FROM onyx.grant_budgets
    WHERE grant_id = p_grant_id AND budget_category = p_budget_category;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Budget category not found');
    END IF;

    -- Check availability
    IF p_amount > v_budget.available THEN
        -- Check flexibility
        IF v_budget.is_flexible THEN
            -- Could allow with warning
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Exceeds category budget (flexibility may apply)',
                'available', v_budget.available,
                'requested', p_amount
            );
        END IF;
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient budget in category',
            'available', v_budget.available,
            'requested', p_amount
        );
    END IF;

    -- Update budget
    UPDATE onyx.grant_budgets
    SET expended = expended + p_amount,
        updated_at = now()
    WHERE id = v_budget.id;

    -- Update grant total
    UPDATE onyx.grants
    SET amount_expended = amount_expended + p_amount,
        updated_at = now()
    WHERE id = p_grant_id;

    RETURN jsonb_build_object(
        'success', true,
        'category', p_budget_category,
        'expended', p_amount,
        'remaining_in_category', v_budget.available - p_amount
    );
END;
$$;

-- Public sector dashboard
CREATE OR REPLACE FUNCTION onyx.rpc_get_public_sector_dashboard(
    p_tenant_id UUID,
    p_fiscal_year_id UUID
) RETURNS JSONB LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'funds', (
            SELECT jsonb_agg(jsonb_build_object(
                'fund_code', fund_code,
                'fund_name', fund_name,
                'fund_type', fund_type,
                'total_appropriations', total_appropriations,
                'total_expended', total_expended,
                'execution_rate', execution_rate
            ))
            FROM onyx.v_fund_summary
            WHERE fiscal_year_id = p_fiscal_year_id
        ),
        'appropriation_summary', (
            SELECT jsonb_build_object(
                'total_budget', SUM(current_amount),
                'total_encumbered', SUM(encumbered),
                'total_expended', SUM(expended),
                'total_available', SUM(available),
                'avg_execution_rate', ROUND(AVG(expenditure_rate), 2)
            )
            FROM onyx.v_appropriation_status
            WHERE appropriation_id IN (
                SELECT id FROM onyx.appropriations WHERE fiscal_year_id = p_fiscal_year_id
            )
        ),
        'encumbrance_aging', (
            SELECT jsonb_object_agg(aging_bucket, cnt)
            FROM (
                SELECT aging_bucket, COUNT(*) AS cnt
                FROM onyx.v_encumbrance_aging
                GROUP BY aging_bucket
            ) sub
        ),
        'grants', (
            SELECT jsonb_build_object(
                'total_awards', SUM(award_amount),
                'total_expended', SUM(amount_expended),
                'total_remaining', SUM(amount_remaining),
                'active_count', COUNT(*) FILTER (WHERE status = 'ACTIVE'),
                'ending_soon', COUNT(*) FILTER (WHERE status_flag = 'ENDING_SOON')
            )
            FROM onyx.v_grant_summary
            WHERE grant_id IN (
                SELECT id FROM onyx.grants WHERE tenant_id = p_tenant_id
            )
        ),
        'alerts', (
            SELECT jsonb_agg(jsonb_build_object(
                'type', 'LOW_BALANCE',
                'appropriation', appropriation_code,
                'available', available
            ))
            FROM onyx.v_appropriation_status
            WHERE status_flag IN ('OVERSPENT', 'LOW_BALANCE')
            LIMIT 10
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$;

-- ===========================================
-- SECTION 10: INDEXES
-- ===========================================

CREATE INDEX idx_funds_tenant ON onyx.funds(tenant_id);
CREATE INDEX idx_funds_type ON onyx.funds(fund_type);
CREATE INDEX idx_fund_fy_fund ON onyx.fund_fiscal_years(fund_id);
CREATE INDEX idx_fund_fy_year ON onyx.fund_fiscal_years(fiscal_year_id);
CREATE INDEX idx_appropriations_fund ON onyx.appropriations(fund_id);
CREATE INDEX idx_appropriations_fy ON onyx.appropriations(fiscal_year_id);
CREATE INDEX idx_appropriations_status ON onyx.appropriations(status);
CREATE INDEX idx_amendments_fy ON onyx.budget_amendments(fiscal_year_id);
CREATE INDEX idx_encumbrances_approp ON onyx.encumbrances(appropriation_id);
CREATE INDEX idx_encumbrances_status ON onyx.encumbrances(status);
CREATE INDEX idx_encumbrances_date ON onyx.encumbrances(encumbrance_date);
CREATE INDEX idx_enc_liquidations_enc ON onyx.encumbrance_liquidations(encumbrance_id);
CREATE INDEX idx_grants_tenant ON onyx.grants(tenant_id);
CREATE INDEX idx_grants_status ON onyx.grants(status);
CREATE INDEX idx_grants_dates ON onyx.grants(start_date, end_date);
CREATE INDEX idx_grant_budgets_grant ON onyx.grant_budgets(grant_id);
CREATE INDEX idx_fund_transfers_fy ON onyx.fund_transfers(fiscal_year_id);

-- ===========================================
-- SECTION 11: COMMENTS
-- ===========================================

COMMENT ON TABLE onyx.funds IS 'Government fund definitions (general, special revenue, enterprise, etc.)';
COMMENT ON TABLE onyx.appropriations IS 'Budget appropriations with allotment control';
COMMENT ON TABLE onyx.encumbrances IS 'Commitment accounting - encumbrances from POs and contracts';
COMMENT ON TABLE onyx.grants IS 'Grant management with compliance tracking';
COMMENT ON TABLE onyx.fund_transfers IS 'Inter-fund transfer tracking';
COMMENT ON TABLE onyx.ipsas_mappings IS 'Mapping local accounts to IPSAS standards';

COMMENT ON FUNCTION onyx.rpc_check_appropriation IS 'Check if appropriation has sufficient funds';
COMMENT ON FUNCTION onyx.rpc_create_encumbrance IS 'Create encumbrance and update appropriation';
COMMENT ON FUNCTION onyx.rpc_liquidate_encumbrance IS 'Liquidate encumbrance against actual expenditure';
COMMENT ON FUNCTION onyx.rpc_process_carry_forward IS 'Process fiscal year-end encumbrance carry-forward';
COMMENT ON FUNCTION onyx.rpc_record_grant_expenditure IS 'Record expenditure against grant budget';
COMMENT ON FUNCTION onyx.rpc_get_public_sector_dashboard IS 'Get public sector financial dashboard';
