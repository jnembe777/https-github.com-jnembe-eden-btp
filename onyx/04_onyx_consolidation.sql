-- =====================================================
-- EdenFin ONYX Tier: Advanced Group Consolidation
-- Target: GE (250+ employees, multi-entity groups)
-- =====================================================
-- Features:
--   - Consolidation scope management
--   - Ownership structure & control analysis
--   - Full/Proportional/Equity consolidation methods
--   - Elimination entries (IC, dividends, unrealized P&L)
--   - Currency translation (current rate, temporal)
--   - Minority/Non-controlling interests (NCI)
--   - Consolidation packages & data collection
--   - Goodwill & purchase price allocation
--   - Multi-level consolidation (sub-groups)
-- =====================================================

-- Fix déploiement (Sprint 2) : onyx/04 et onyx/05 utilisent le schéma `onyx`
-- sans le créer (seuls onyx/06 et onyx/07 le créaient). On le crée ici, en tête
-- du premier consommateur. Idempotent. ROLLBACK : DROP SCHEMA IF EXISTS onyx CASCADE;
CREATE SCHEMA IF NOT EXISTS onyx;

-- ===========================================
-- SECTION 1: ENUMS
-- ===========================================

CREATE TYPE onyx.consolidation_method AS ENUM (
    'FULL',              -- 100% consolidation (>50% control)
    'PROPORTIONAL',      -- Pro-rata consolidation (joint ventures)
    'EQUITY',            -- One-line consolidation (20-50% influence)
    'COST',              -- At cost (no significant influence)
    'EXCLUDED'           -- Not consolidated
);

CREATE TYPE onyx.control_type AS ENUM (
    'EXCLUSIVE',         -- >50% voting rights or de facto control
    'JOINT',             -- Joint control with other parties
    'SIGNIFICANT_INFLUENCE', -- 20-50% or board representation
    'NO_CONTROL'         -- <20% passive investment
);

CREATE TYPE onyx.translation_method AS ENUM (
    'CURRENT_RATE',      -- All items at closing rate (IFRS standard)
    'TEMPORAL',          -- Monetary at closing, non-monetary at historical
    'MONETARY_NONMONETARY' -- Alternative temporal approach
);

CREATE TYPE onyx.elimination_type AS ENUM (
    'IC_SALES',          -- Intercompany sales elimination
    'IC_RECEIVABLE',     -- IC receivables/payables
    'IC_DIVIDEND',       -- Dividend elimination
    'IC_INVENTORY_PROFIT', -- Unrealized profit in inventory
    'IC_FIXED_ASSET_PROFIT', -- Unrealized profit in fixed assets
    'IC_LOAN',           -- IC loans
    'IC_INTEREST',       -- IC interest income/expense
    'INVESTMENT_EQUITY', -- Investment vs equity elimination
    'GOODWILL_AMORT',    -- Goodwill amortization/impairment
    'NCI_ADJUSTMENT'     -- Non-controlling interest adjustments
);

CREATE TYPE onyx.package_status AS ENUM (
    'NOT_STARTED',
    'IN_PROGRESS',
    'SUBMITTED',
    'UNDER_REVIEW',
    'APPROVED',
    'REJECTED',
    'LOCKED'
);

CREATE TYPE onyx.conso_period_status AS ENUM (
    'OPEN',
    'DATA_COLLECTION',
    'CONSOLIDATION',
    'REVIEW',
    'CLOSED',
    'PUBLISHED'
);

-- ===========================================
-- SECTION 2: CONSOLIDATION SCOPE
-- ===========================================

-- Consolidation perimeter definition
CREATE TABLE onyx.consolidation_scopes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),

    -- Identification
    code VARCHAR(20) NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT,

    -- Type
    scope_type VARCHAR(20) DEFAULT 'LEGAL', -- LEGAL, MANAGEMENT, REGULATORY

    -- Parent group
    parent_scope_id UUID REFERENCES onyx.consolidation_scopes(id),

    -- Settings
    base_currency VARCHAR(3) NOT NULL DEFAULT 'XAF',
    translation_method onyx.translation_method DEFAULT 'CURRENT_RATE',

    -- IFRS vs Local GAAP
    accounting_framework VARCHAR(20) DEFAULT 'IFRS', -- IFRS, LOCAL_GAAP, BOTH

    -- State
    is_active BOOLEAN DEFAULT true,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT now(),

    UNIQUE(tenant_id, code)
);

-- Entities in scope
CREATE TABLE onyx.scope_entities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scope_id UUID NOT NULL REFERENCES onyx.consolidation_scopes(id) ON DELETE CASCADE,
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),

    -- Consolidation method
    method onyx.consolidation_method NOT NULL,
    control_type onyx.control_type NOT NULL,

    -- Ownership
    direct_ownership_pct DECIMAL(7,4) NOT NULL DEFAULT 100.0000, -- Direct %
    indirect_ownership_pct DECIMAL(7,4) DEFAULT 0, -- Through subsidiaries
    total_ownership_pct DECIMAL(7,4) GENERATED ALWAYS AS (
        direct_ownership_pct + COALESCE(indirect_ownership_pct, 0)
    ) STORED,

    -- Voting rights (may differ from ownership)
    voting_rights_pct DECIMAL(7,4),

    -- Integration percentage (for proportional)
    integration_pct DECIMAL(7,4) DEFAULT 100.0000,

    -- Functional currency
    functional_currency VARCHAR(3) NOT NULL DEFAULT 'XAF',

    -- Entry date
    acquisition_date DATE,
    first_consolidation_date DATE,

    -- Exit
    disposal_date DATE,
    last_consolidation_date DATE,

    -- Flags
    is_parent BOOLEAN DEFAULT false,
    is_sub_group_parent BOOLEAN DEFAULT false,

    -- State
    is_active BOOLEAN DEFAULT true,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),

    UNIQUE(scope_id, entity_id)
);

-- Ownership structure (investment relationships)
CREATE TABLE onyx.ownership_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scope_id UUID NOT NULL REFERENCES onyx.consolidation_scopes(id),

    -- Investor -> Investee
    investor_entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),
    investee_entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),

    -- Ownership details
    ownership_pct DECIMAL(7,4) NOT NULL,
    voting_rights_pct DECIMAL(7,4),

    -- Dates
    acquisition_date DATE NOT NULL,
    disposal_date DATE,

    -- Investment account (in investor's books)
    investment_account_id UUID, -- Link to chart of accounts
    investment_cost DECIMAL(20,2),
    investment_currency VARCHAR(3),

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),

    UNIQUE(scope_id, investor_entity_id, investee_entity_id, acquisition_date),
    CHECK(investor_entity_id != investee_entity_id)
);

-- ===========================================
-- SECTION 3: CONSOLIDATION PERIODS
-- ===========================================

CREATE TABLE onyx.consolidation_periods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scope_id UUID NOT NULL REFERENCES onyx.consolidation_scopes(id),
    fiscal_year_id BIGINT NOT NULL REFERENCES client_demo.fiscal_exercises(id),

    -- Period
    period_type VARCHAR(20) NOT NULL, -- MONTHLY, QUARTERLY, ANNUAL
    period_number INT, -- 1-12 for monthly, 1-4 for quarterly
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,

    -- Rates
    closing_rate_date DATE NOT NULL,
    average_rate_start DATE,
    average_rate_end DATE,

    -- Status
    status onyx.conso_period_status DEFAULT 'OPEN',

    -- Deadlines
    package_deadline TIMESTAMPTZ,
    consolidation_deadline TIMESTAMPTZ,
    publication_deadline TIMESTAMPTZ,

    -- Completion tracking
    packages_total INT DEFAULT 0,
    packages_submitted INT DEFAULT 0,
    packages_approved INT DEFAULT 0,

    -- Lock
    locked_at TIMESTAMPTZ,
    locked_by UUID,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),

    UNIQUE(scope_id, fiscal_year_id, period_type, period_number)
);

-- Exchange rates for consolidation
CREATE TABLE onyx.consolidation_rates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    period_id UUID NOT NULL REFERENCES onyx.consolidation_periods(id),

    -- Currency pair
    from_currency VARCHAR(3) NOT NULL,
    to_currency VARCHAR(3) NOT NULL,

    -- Rates
    closing_rate DECIMAL(18,8) NOT NULL,
    average_rate DECIMAL(18,8) NOT NULL,
    opening_rate DECIMAL(18,8),

    -- Historical rates for specific items
    historical_rate DECIMAL(18,8), -- For equity items

    -- Source
    rate_source VARCHAR(50), -- BEAC, ECB, manual

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),

    UNIQUE(period_id, from_currency, to_currency)
);

-- ===========================================
-- SECTION 4: CONSOLIDATION PACKAGES
-- ===========================================

CREATE TABLE onyx.consolidation_packages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    period_id UUID NOT NULL REFERENCES onyx.consolidation_periods(id),
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),

    -- Status
    status onyx.package_status DEFAULT 'NOT_STARTED',

    -- Workflow
    assigned_to UUID,
    submitted_at TIMESTAMPTZ,
    submitted_by UUID,
    reviewed_at TIMESTAMPTZ,
    reviewed_by UUID,
    approved_at TIMESTAMPTZ,
    approved_by UUID,

    -- Rejection
    rejection_reason TEXT,
    rejection_count INT DEFAULT 0,

    -- Data completeness
    trial_balance_complete BOOLEAN DEFAULT false,
    ic_transactions_complete BOOLEAN DEFAULT false,
    adjustments_complete BOOLEAN DEFAULT false,
    notes_complete BOOLEAN DEFAULT false,

    -- Validation
    validation_errors JSONB DEFAULT '[]',
    validation_warnings JSONB DEFAULT '[]',
    last_validated_at TIMESTAMPTZ,

    -- Comments
    preparer_comments TEXT,
    reviewer_comments TEXT,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),

    UNIQUE(period_id, entity_id)
);

-- Package trial balance data
CREATE TABLE onyx.package_trial_balance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    package_id UUID NOT NULL REFERENCES onyx.consolidation_packages(id) ON DELETE CASCADE,

    -- Account
    account_code VARCHAR(20) NOT NULL,
    account_name VARCHAR(200),

    -- Amounts in local currency
    local_currency VARCHAR(3) NOT NULL,
    opening_balance_local DECIMAL(20,2) DEFAULT 0,
    debit_local DECIMAL(20,2) DEFAULT 0,
    credit_local DECIMAL(20,2) DEFAULT 0,
    closing_balance_local DECIMAL(20,2) GENERATED ALWAYS AS (
        opening_balance_local + debit_local - credit_local
    ) STORED,

    -- Amounts in group currency
    group_currency VARCHAR(3) NOT NULL,
    opening_balance_group DECIMAL(20,2) DEFAULT 0,
    debit_group DECIMAL(20,2) DEFAULT 0,
    credit_group DECIMAL(20,2) DEFAULT 0,
    closing_balance_group DECIMAL(20,2) GENERATED ALWAYS AS (
        opening_balance_group + debit_group - credit_group
    ) STORED,

    -- Translation adjustments
    cta_amount DECIMAL(20,2) DEFAULT 0, -- Cumulative Translation Adjustment

    -- Mapping to group chart
    group_account_code VARCHAR(20),

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),

    UNIQUE(package_id, account_code)
);

-- Intercompany declarations
CREATE TABLE onyx.package_ic_declarations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    package_id UUID NOT NULL REFERENCES onyx.consolidation_packages(id) ON DELETE CASCADE,

    -- Counterparty
    counterparty_entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),

    -- Transaction type
    ic_type VARCHAR(50) NOT NULL, -- TRADE, LOAN, DIVIDEND, MGMT_FEE, etc.

    -- Amounts (from this entity's perspective)
    local_currency VARCHAR(3) NOT NULL,
    receivable_local DECIMAL(20,2) DEFAULT 0,
    payable_local DECIMAL(20,2) DEFAULT 0,
    revenue_local DECIMAL(20,2) DEFAULT 0,
    expense_local DECIMAL(20,2) DEFAULT 0,

    -- Group currency
    group_currency VARCHAR(3) NOT NULL,
    receivable_group DECIMAL(20,2) DEFAULT 0,
    payable_group DECIMAL(20,2) DEFAULT 0,
    revenue_group DECIMAL(20,2) DEFAULT 0,
    expense_group DECIMAL(20,2) DEFAULT 0,

    -- Reference
    reference_number VARCHAR(50),
    description TEXT,

    -- Reconciliation status
    is_reconciled BOOLEAN DEFAULT false,
    reconciliation_diff DECIMAL(20,2),

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ===========================================
-- SECTION 5: ELIMINATION ENTRIES
-- ===========================================

CREATE TABLE onyx.elimination_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scope_id UUID NOT NULL REFERENCES onyx.consolidation_scopes(id),

    -- Rule identification
    code VARCHAR(30) NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT,

    -- Type
    elimination_type onyx.elimination_type NOT NULL,

    -- Automatic or manual
    is_automatic BOOLEAN DEFAULT true,

    -- Accounts involved
    source_account_pattern VARCHAR(50), -- Regex or range
    target_account_pattern VARCHAR(50),
    offset_account_code VARCHAR(20), -- For P&L to BS

    -- Percentage
    elimination_pct DECIMAL(7,4) DEFAULT 100.0000,

    -- Conditions
    applies_to_method onyx.consolidation_method[], -- Which methods
    min_ownership_pct DECIMAL(7,4),

    -- State
    is_active BOOLEAN DEFAULT true,
    priority INT DEFAULT 100,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),

    UNIQUE(scope_id, code)
);

CREATE TABLE onyx.elimination_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    period_id UUID NOT NULL REFERENCES onyx.consolidation_periods(id),

    -- Source
    rule_id UUID REFERENCES onyx.elimination_rules(id),
    is_manual BOOLEAN DEFAULT false,

    -- Entry identification
    entry_number VARCHAR(30) NOT NULL,
    elimination_type onyx.elimination_type NOT NULL,
    description TEXT,

    -- Entities involved
    entity1_id BIGINT REFERENCES sys.tenant_entities(id),
    entity2_id BIGINT REFERENCES sys.tenant_entities(id),

    -- Reference to IC declaration
    ic_declaration_id UUID REFERENCES onyx.package_ic_declarations(id),

    -- Status
    status VARCHAR(20) DEFAULT 'DRAFT', -- DRAFT, POSTED, REVERSED

    -- Audit
    posted_at TIMESTAMPTZ,
    posted_by UUID,
    reversed_at TIMESTAMPTZ,
    reversed_by UUID,
    created_at TIMESTAMPTZ DEFAULT now(),
    created_by UUID
);

CREATE TABLE onyx.elimination_entry_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_id UUID NOT NULL REFERENCES onyx.elimination_entries(id) ON DELETE CASCADE,

    -- Account
    account_code VARCHAR(20) NOT NULL,
    account_name VARCHAR(200),

    -- Entity (for tracking)
    entity_id BIGINT REFERENCES sys.tenant_entities(id),

    -- Amounts (in group currency)
    debit DECIMAL(20,2) DEFAULT 0,
    credit DECIMAL(20,2) DEFAULT 0,

    -- Line order
    line_number INT NOT NULL,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ===========================================
-- SECTION 6: NON-CONTROLLING INTERESTS
-- ===========================================

CREATE TABLE onyx.nci_calculations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    period_id UUID NOT NULL REFERENCES onyx.consolidation_periods(id),
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),

    -- Ownership
    group_ownership_pct DECIMAL(7,4) NOT NULL,
    nci_pct DECIMAL(7,4) GENERATED ALWAYS AS (100.0 - group_ownership_pct) STORED,

    -- Equity allocation
    total_equity DECIMAL(20,2) NOT NULL,
    nci_equity DECIMAL(20,2) GENERATED ALWAYS AS (
        total_equity * (100.0 - group_ownership_pct) / 100.0
    ) STORED,

    -- P&L allocation
    total_net_income DECIMAL(20,2) DEFAULT 0,
    nci_net_income DECIMAL(20,2) GENERATED ALWAYS AS (
        total_net_income * (100.0 - group_ownership_pct) / 100.0
    ) STORED,

    -- OCI allocation
    total_oci DECIMAL(20,2) DEFAULT 0,
    nci_oci DECIMAL(20,2) GENERATED ALWAYS AS (
        total_oci * (100.0 - group_ownership_pct) / 100.0
    ) STORED,

    -- Dividends to NCI
    dividends_to_nci DECIMAL(20,2) DEFAULT 0,

    -- Audit
    calculated_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ===========================================
-- SECTION 7: GOODWILL & ACQUISITIONS
-- ===========================================

CREATE TABLE onyx.acquisitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scope_id UUID NOT NULL REFERENCES onyx.consolidation_scopes(id),

    -- Acquirer & Target
    acquirer_entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),
    acquired_entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),

    -- Acquisition details
    acquisition_date DATE NOT NULL,
    ownership_acquired_pct DECIMAL(7,4) NOT NULL,

    -- Consideration
    consideration_currency VARCHAR(3) NOT NULL,
    cash_consideration DECIMAL(20,2) DEFAULT 0,
    share_consideration DECIMAL(20,2) DEFAULT 0, -- Fair value of shares issued
    contingent_consideration DECIMAL(20,2) DEFAULT 0,
    total_consideration DECIMAL(20,2) GENERATED ALWAYS AS (
        cash_consideration + share_consideration + contingent_consideration
    ) STORED,

    -- Fair value of net assets
    fv_net_assets DECIMAL(20,2) NOT NULL,

    -- Goodwill calculation
    goodwill DECIMAL(20,2) GENERATED ALWAYS AS (
        (cash_consideration + share_consideration + contingent_consideration) -
        (fv_net_assets * ownership_acquired_pct / 100.0)
    ) STORED,

    -- Bargain purchase (negative goodwill)
    is_bargain_purchase BOOLEAN GENERATED ALWAYS AS (
        (cash_consideration + share_consideration + contingent_consideration) <
        (fv_net_assets * ownership_acquired_pct / 100.0)
    ) STORED,

    -- Goodwill allocation to CGUs
    goodwill_allocation JSONB DEFAULT '{}',

    -- NCI at acquisition
    nci_at_acquisition DECIMAL(20,2),
    nci_measurement_method VARCHAR(20), -- FAIR_VALUE, PROPORTIONATE

    -- State
    is_finalized BOOLEAN DEFAULT false,
    measurement_period_end DATE, -- Up to 12 months from acquisition

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Purchase Price Allocation
CREATE TABLE onyx.ppa_adjustments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    acquisition_id UUID NOT NULL REFERENCES onyx.acquisitions(id) ON DELETE CASCADE,

    -- Asset/Liability
    item_type VARCHAR(20) NOT NULL, -- ASSET, LIABILITY, INTANGIBLE
    item_name VARCHAR(200) NOT NULL,

    -- Values
    book_value DECIMAL(20,2) NOT NULL,
    fair_value DECIMAL(20,2) NOT NULL,
    adjustment DECIMAL(20,2) GENERATED ALWAYS AS (fair_value - book_value) STORED,

    -- Accounts
    asset_account_code VARCHAR(20),
    adjustment_account_code VARCHAR(20),

    -- Useful life (for amortization)
    useful_life_months INT,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Goodwill impairment testing
CREATE TABLE onyx.goodwill_impairment_tests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    acquisition_id UUID NOT NULL REFERENCES onyx.acquisitions(id),
    period_id UUID NOT NULL REFERENCES onyx.consolidation_periods(id),

    -- CGU tested
    cgu_name VARCHAR(200) NOT NULL,

    -- Carrying amounts
    carrying_amount_goodwill DECIMAL(20,2) NOT NULL,
    carrying_amount_other_assets DECIMAL(20,2) NOT NULL,
    total_carrying_amount DECIMAL(20,2) GENERATED ALWAYS AS (
        carrying_amount_goodwill + carrying_amount_other_assets
    ) STORED,

    -- Recoverable amount
    recoverable_amount DECIMAL(20,2) NOT NULL,
    recoverable_amount_basis VARCHAR(20), -- FVLCS, VIU

    -- Impairment
    impairment_loss DECIMAL(20,2) GENERATED ALWAYS AS (
        GREATEST(0, (carrying_amount_goodwill + carrying_amount_other_assets) - recoverable_amount)
    ) STORED,

    -- Assumptions (for VIU)
    discount_rate DECIMAL(7,4),
    growth_rate DECIMAL(7,4),
    projection_years INT,

    -- Sensitivity analysis
    sensitivity_analysis JSONB,

    -- Approval
    approved_by UUID,
    approved_at TIMESTAMPTZ,

    -- Audit
    test_date DATE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ===========================================
-- SECTION 8: CONSOLIDATED RESULTS
-- ===========================================

CREATE TABLE onyx.consolidated_trial_balance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    period_id UUID NOT NULL REFERENCES onyx.consolidation_periods(id),

    -- Account
    account_code VARCHAR(20) NOT NULL,
    account_name VARCHAR(200),
    account_type VARCHAR(20), -- ASSET, LIABILITY, EQUITY, REVENUE, EXPENSE

    -- Amounts by layer
    local_entities_total DECIMAL(20,2) DEFAULT 0,     -- Sum of all entities
    currency_translation DECIMAL(20,2) DEFAULT 0,      -- CTA adjustments
    elimination_adjustments DECIMAL(20,2) DEFAULT 0,   -- IC eliminations
    nci_adjustments DECIMAL(20,2) DEFAULT 0,           -- NCI share
    other_adjustments DECIMAL(20,2) DEFAULT 0,         -- Manual adjustments

    -- Final consolidated
    consolidated_balance DECIMAL(20,2) GENERATED ALWAYS AS (
        local_entities_total + currency_translation + elimination_adjustments +
        nci_adjustments + other_adjustments
    ) STORED,

    -- Group share vs NCI
    group_share DECIMAL(20,2),
    nci_share DECIMAL(20,2),

    -- Prior period
    prior_period_balance DECIMAL(20,2),
    movement DECIMAL(20,2) GENERATED ALWAYS AS (
        (local_entities_total + currency_translation + elimination_adjustments +
         nci_adjustments + other_adjustments) - COALESCE(prior_period_balance, 0)
    ) STORED,

    -- Audit
    calculated_at TIMESTAMPTZ DEFAULT now(),

    UNIQUE(period_id, account_code)
);

-- Consolidation journal
CREATE TABLE onyx.consolidation_journal (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    period_id UUID NOT NULL REFERENCES onyx.consolidation_periods(id),

    -- Entry type
    entry_type VARCHAR(30) NOT NULL, -- TRANSLATION, ELIMINATION, NCI, GOODWILL, MANUAL

    -- Reference
    reference VARCHAR(50) NOT NULL,
    description TEXT,

    -- Source
    source_entity_id BIGINT REFERENCES sys.tenant_entities(id),
    elimination_entry_id UUID REFERENCES onyx.elimination_entries(id),

    -- Status
    status VARCHAR(20) DEFAULT 'DRAFT',

    -- Audit
    posted_at TIMESTAMPTZ,
    posted_by UUID,
    created_at TIMESTAMPTZ DEFAULT now(),
    created_by UUID
);

CREATE TABLE onyx.consolidation_journal_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    journal_id UUID NOT NULL REFERENCES onyx.consolidation_journal(id) ON DELETE CASCADE,

    -- Account
    account_code VARCHAR(20) NOT NULL,
    account_name VARCHAR(200),

    -- Amounts
    debit DECIMAL(20,2) DEFAULT 0,
    credit DECIMAL(20,2) DEFAULT 0,

    -- Line order
    line_number INT NOT NULL,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ===========================================
-- SECTION 9: VIEWS
-- ===========================================

-- Consolidation scope overview
CREATE OR REPLACE VIEW onyx.v_scope_overview AS
SELECT
    cs.id AS scope_id,
    cs.code AS scope_code,
    cs.name AS scope_name,
    cs.base_currency,
    COUNT(DISTINCT se.entity_id) AS entity_count,
    COUNT(DISTINCT CASE WHEN se.method = 'FULL' THEN se.entity_id END) AS full_conso_count,
    COUNT(DISTINCT CASE WHEN se.method = 'PROPORTIONAL' THEN se.entity_id END) AS proportional_count,
    COUNT(DISTINCT CASE WHEN se.method = 'EQUITY' THEN se.entity_id END) AS equity_count,
    COUNT(DISTINCT se.functional_currency) AS currency_count
FROM onyx.consolidation_scopes cs
LEFT JOIN onyx.scope_entities se ON cs.id = se.scope_id AND se.is_active = true
WHERE cs.is_active = true
GROUP BY cs.id, cs.code, cs.name, cs.base_currency;

-- Package status summary
CREATE OR REPLACE VIEW onyx.v_package_status AS
SELECT
    cp.id AS period_id,
    cp.period_type,
    cp.period_number,
    cp.period_start,
    cp.period_end,
    cp.status AS period_status,
    COUNT(pkg.id) AS total_packages,
    COUNT(CASE WHEN pkg.status = 'NOT_STARTED' THEN 1 END) AS not_started,
    COUNT(CASE WHEN pkg.status = 'IN_PROGRESS' THEN 1 END) AS in_progress,
    COUNT(CASE WHEN pkg.status = 'SUBMITTED' THEN 1 END) AS submitted,
    COUNT(CASE WHEN pkg.status = 'APPROVED' THEN 1 END) AS approved,
    COUNT(CASE WHEN pkg.status = 'REJECTED' THEN 1 END) AS rejected,
    ROUND(100.0 * COUNT(CASE WHEN pkg.status = 'APPROVED' THEN 1 END) /
          NULLIF(COUNT(pkg.id), 0), 1) AS completion_pct
FROM onyx.consolidation_periods cp
LEFT JOIN onyx.consolidation_packages pkg ON cp.id = pkg.period_id
GROUP BY cp.id, cp.period_type, cp.period_number, cp.period_start, cp.period_end, cp.status;

-- IC reconciliation status
CREATE OR REPLACE VIEW onyx.v_ic_reconciliation AS
WITH ic_pairs AS (
    SELECT
        LEAST(d1.package_id, d2.package_id) AS pkg1,
        GREATEST(d1.package_id, d2.package_id) AS pkg2,
        d1.ic_type,
        d1.receivable_group AS entity1_receivable,
        d2.payable_group AS entity2_payable,
        d1.revenue_group AS entity1_revenue,
        d2.expense_group AS entity2_expense,
        ABS(d1.receivable_group - d2.payable_group) AS balance_diff,
        ABS(d1.revenue_group - d2.expense_group) AS pl_diff
    FROM onyx.package_ic_declarations d1
    JOIN onyx.package_ic_declarations d2
        ON d1.counterparty_entity_id = (
            SELECT entity_id FROM onyx.consolidation_packages WHERE id = d2.package_id
        )
        AND d2.counterparty_entity_id = (
            SELECT entity_id FROM onyx.consolidation_packages WHERE id = d1.package_id
        )
        AND d1.ic_type = d2.ic_type
        AND d1.package_id < d2.package_id
)
SELECT
    pkg1,
    pkg2,
    ic_type,
    entity1_receivable,
    entity2_payable,
    balance_diff,
    entity1_revenue,
    entity2_expense,
    pl_diff,
    CASE
        WHEN balance_diff < 1 AND pl_diff < 1 THEN 'MATCHED'
        WHEN balance_diff < 1000 AND pl_diff < 1000 THEN 'MINOR_DIFF'
        ELSE 'UNRECONCILED'
    END AS status
FROM ic_pairs;

-- Consolidated P&L summary
CREATE OR REPLACE VIEW onyx.v_consolidated_pl AS
SELECT
    ctb.period_id,
    cp.period_type,
    cp.period_start,
    cp.period_end,
    SUM(CASE WHEN ctb.account_code LIKE '7%' THEN ctb.consolidated_balance ELSE 0 END) AS total_revenue,
    SUM(CASE WHEN ctb.account_code LIKE '6%' THEN ctb.consolidated_balance ELSE 0 END) AS total_expenses,
    SUM(CASE WHEN ctb.account_code LIKE '7%' THEN ctb.consolidated_balance ELSE 0 END) -
    SUM(CASE WHEN ctb.account_code LIKE '6%' THEN ctb.consolidated_balance ELSE 0 END) AS net_income,
    SUM(CASE WHEN ctb.account_code LIKE '7%' THEN ctb.group_share ELSE 0 END) -
    SUM(CASE WHEN ctb.account_code LIKE '6%' THEN ctb.group_share ELSE 0 END) AS net_income_group,
    SUM(CASE WHEN ctb.account_code LIKE '7%' THEN ctb.nci_share ELSE 0 END) -
    SUM(CASE WHEN ctb.account_code LIKE '6%' THEN ctb.nci_share ELSE 0 END) AS net_income_nci,
    SUM(ctb.elimination_adjustments) AS total_eliminations
FROM onyx.consolidated_trial_balance ctb
JOIN onyx.consolidation_periods cp ON ctb.period_id = cp.id
WHERE ctb.account_type IN ('REVENUE', 'EXPENSE')
GROUP BY ctb.period_id, cp.period_type, cp.period_start, cp.period_end;

-- Goodwill summary
CREATE OR REPLACE VIEW onyx.v_goodwill_summary AS
SELECT
    a.scope_id,
    a.acquired_entity_id,
    ge.entity_name AS entity_name,
    a.acquisition_date,
    a.total_consideration,
    a.fv_net_assets,
    a.goodwill AS initial_goodwill,
    COALESCE(SUM(git.impairment_loss), 0) AS cumulative_impairment,
    a.goodwill - COALESCE(SUM(git.impairment_loss), 0) AS carrying_value
FROM onyx.acquisitions a
JOIN sys.tenant_entities ge ON a.acquired_entity_id = ge.id
LEFT JOIN onyx.goodwill_impairment_tests git ON a.id = git.acquisition_id
WHERE a.is_finalized = true AND a.goodwill > 0
GROUP BY a.scope_id, a.acquired_entity_id, ge.entity_name,
         a.acquisition_date, a.total_consideration, a.fv_net_assets, a.goodwill;

-- ===========================================
-- SECTION 10: RPC FUNCTIONS
-- ===========================================

-- Calculate ownership structure
CREATE OR REPLACE FUNCTION onyx.rpc_calculate_ownership(
    p_scope_id UUID
) RETURNS TABLE (
    entity_id UUID,
    entity_name VARCHAR,
    direct_pct DECIMAL,
    indirect_pct DECIMAL,
    total_pct DECIMAL,
    control_type onyx.control_type,
    method onyx.consolidation_method
) LANGUAGE plpgsql AS $$
DECLARE
    v_max_iterations INT := 10;
    v_iteration INT := 0;
BEGIN
    -- Create temp table for calculations
    CREATE TEMP TABLE IF NOT EXISTS temp_ownership (
        entity_id UUID,
        direct_pct DECIMAL(7,4),
        indirect_pct DECIMAL(7,4),
        iteration INT
    );

    TRUNCATE temp_ownership;

    -- Initialize with direct ownership
    INSERT INTO temp_ownership (entity_id, direct_pct, indirect_pct, iteration)
    SELECT
        se.entity_id,
        se.direct_ownership_pct,
        0,
        0
    FROM onyx.scope_entities se
    WHERE se.scope_id = p_scope_id AND se.is_active = true;

    -- Iterate to calculate indirect ownership
    WHILE v_iteration < v_max_iterations LOOP
        v_iteration := v_iteration + 1;

        -- Calculate indirect through subsidiaries
        UPDATE temp_ownership t
        SET indirect_pct = (
            SELECT COALESCE(SUM(
                ol.ownership_pct * (t2.direct_pct + t2.indirect_pct) / 100.0
            ), 0)
            FROM onyx.ownership_links ol
            JOIN temp_ownership t2 ON ol.investor_entity_id = t2.entity_id
            WHERE ol.investee_entity_id = t.entity_id
              AND ol.scope_id = p_scope_id
              AND ol.disposal_date IS NULL
        ),
        iteration = v_iteration
        WHERE EXISTS (
            SELECT 1 FROM onyx.ownership_links ol
            WHERE ol.investee_entity_id = t.entity_id
              AND ol.scope_id = p_scope_id
        );

        -- Exit if no changes
        IF NOT FOUND THEN EXIT; END IF;
    END LOOP;

    -- Return results with method determination
    RETURN QUERY
    SELECT
        t.entity_id,
        ge.entity_name::VARCHAR AS entity_name,
        t.direct_pct,
        t.indirect_pct,
        (t.direct_pct + t.indirect_pct) AS total_pct,
        CASE
            WHEN t.direct_pct + t.indirect_pct > 50 THEN 'EXCLUSIVE'::onyx.control_type
            WHEN t.direct_pct + t.indirect_pct >= 20 THEN 'SIGNIFICANT_INFLUENCE'::onyx.control_type
            ELSE 'NO_CONTROL'::onyx.control_type
        END AS control_type,
        CASE
            WHEN t.direct_pct + t.indirect_pct > 50 THEN 'FULL'::onyx.consolidation_method
            WHEN t.direct_pct + t.indirect_pct >= 20 THEN 'EQUITY'::onyx.consolidation_method
            ELSE 'COST'::onyx.consolidation_method
        END AS method
    FROM temp_ownership t
    JOIN sys.tenant_entities ge ON t.entity_id = ge.id
    ORDER BY total_pct DESC;

    DROP TABLE IF EXISTS temp_ownership;
END;
$$;

-- Generate elimination entries
CREATE OR REPLACE FUNCTION onyx.rpc_generate_eliminations(
    p_period_id UUID
) RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
    v_scope_id UUID;
    v_entry_count INT := 0;
    v_ic RECORD;
    v_entry_id UUID;
    v_entry_number VARCHAR;
BEGIN
    -- Get scope
    SELECT scope_id INTO v_scope_id
    FROM onyx.consolidation_periods WHERE id = p_period_id;

    -- Process IC declarations
    FOR v_ic IN (
        SELECT
            d1.id AS decl1_id,
            d1.package_id AS pkg1_id,
            d2.id AS decl2_id,
            d2.package_id AS pkg2_id,
            d1.ic_type,
            d1.receivable_group,
            d2.payable_group,
            d1.revenue_group,
            d2.expense_group,
            p1.entity_id AS entity1_id,
            p2.entity_id AS entity2_id
        FROM onyx.package_ic_declarations d1
        JOIN onyx.consolidation_packages p1 ON d1.package_id = p1.id
        JOIN onyx.consolidation_packages p2 ON d1.counterparty_entity_id = p2.entity_id
        JOIN onyx.package_ic_declarations d2 ON d2.package_id = p2.id
            AND d2.counterparty_entity_id = p1.entity_id
            AND d2.ic_type = d1.ic_type
        WHERE p1.period_id = p_period_id
          AND p2.period_id = p_period_id
          AND d1.package_id < d2.package_id -- Avoid duplicates
    ) LOOP
        v_entry_count := v_entry_count + 1;
        v_entry_number := 'ELIM-' || to_char(now(), 'YYYYMMDD') || '-' || LPAD(v_entry_count::TEXT, 4, '0');

        -- Create elimination entry for receivables/payables
        IF v_ic.receivable_group > 0 OR v_ic.payable_group > 0 THEN
            INSERT INTO onyx.elimination_entries (
                period_id, entry_number, elimination_type, description,
                entity1_id, entity2_id, ic_declaration_id, status
            ) VALUES (
                p_period_id, v_entry_number, 'IC_RECEIVABLE',
                'IC Receivable/Payable elimination: ' || v_ic.ic_type,
                v_ic.entity1_id, v_ic.entity2_id, v_ic.decl1_id, 'DRAFT'
            ) RETURNING id INTO v_entry_id;

            -- Debit payable (reduce liability)
            INSERT INTO onyx.elimination_entry_lines (entry_id, account_code, account_name, debit, credit, line_number)
            VALUES (v_entry_id, '401000', 'Fournisseurs - IC', v_ic.payable_group, 0, 1);

            -- Credit receivable (reduce asset)
            INSERT INTO onyx.elimination_entry_lines (entry_id, account_code, account_name, debit, credit, line_number)
            VALUES (v_entry_id, '411000', 'Clients - IC', 0, v_ic.receivable_group, 2);
        END IF;

        -- Create elimination entry for revenue/expense
        IF v_ic.revenue_group > 0 OR v_ic.expense_group > 0 THEN
            v_entry_number := 'ELIM-' || to_char(now(), 'YYYYMMDD') || '-' || LPAD((v_entry_count + 1)::TEXT, 4, '0');

            INSERT INTO onyx.elimination_entries (
                period_id, entry_number, elimination_type, description,
                entity1_id, entity2_id, ic_declaration_id, status
            ) VALUES (
                p_period_id, v_entry_number, 'IC_SALES',
                'IC Revenue/Expense elimination: ' || v_ic.ic_type,
                v_ic.entity1_id, v_ic.entity2_id, v_ic.decl1_id, 'DRAFT'
            ) RETURNING id INTO v_entry_id;

            -- Debit revenue (reduce income)
            INSERT INTO onyx.elimination_entry_lines (entry_id, account_code, account_name, debit, credit, line_number)
            VALUES (v_entry_id, '706000', 'Ventes IC', v_ic.revenue_group, 0, 1);

            -- Credit expense (reduce cost)
            INSERT INTO onyx.elimination_entry_lines (entry_id, account_code, account_name, debit, credit, line_number)
            VALUES (v_entry_id, '606000', 'Achats IC', 0, v_ic.expense_group, 2);
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'entries_created', v_entry_count,
        'period_id', p_period_id
    );
END;
$$;

-- Calculate NCI for all entities
CREATE OR REPLACE FUNCTION onyx.rpc_calculate_nci(
    p_period_id UUID
) RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
    v_scope_id UUID;
    v_entity RECORD;
    v_nci_count INT := 0;
BEGIN
    -- Get scope
    SELECT scope_id INTO v_scope_id
    FROM onyx.consolidation_periods WHERE id = p_period_id;

    -- Calculate NCI for each entity
    FOR v_entity IN (
        SELECT
            se.entity_id,
            se.total_ownership_pct,
            ptb.closing_balance_group AS equity,
            COALESCE(SUM(CASE WHEN ptb.account_code LIKE '7%' THEN ptb.closing_balance_group
                              WHEN ptb.account_code LIKE '6%' THEN -ptb.closing_balance_group
                              ELSE 0 END), 0) AS net_income
        FROM onyx.scope_entities se
        JOIN onyx.consolidation_packages pkg ON se.entity_id = pkg.entity_id
        LEFT JOIN onyx.package_trial_balance ptb ON pkg.id = ptb.package_id
        WHERE se.scope_id = v_scope_id
          AND pkg.period_id = p_period_id
          AND se.method = 'FULL'
          AND se.total_ownership_pct < 100
        GROUP BY se.entity_id, se.total_ownership_pct, ptb.closing_balance_group
    ) LOOP
        -- Insert or update NCI calculation
        INSERT INTO onyx.nci_calculations (
            period_id, entity_id, group_ownership_pct, total_equity, total_net_income
        ) VALUES (
            p_period_id, v_entity.entity_id, v_entity.total_ownership_pct,
            v_entity.equity, v_entity.net_income
        )
        ON CONFLICT (period_id, entity_id) DO UPDATE SET
            group_ownership_pct = EXCLUDED.group_ownership_pct,
            total_equity = EXCLUDED.total_equity,
            total_net_income = EXCLUDED.total_net_income,
            calculated_at = now();

        v_nci_count := v_nci_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'entities_processed', v_nci_count,
        'period_id', p_period_id
    );
END;
$$;

-- Run full consolidation
CREATE OR REPLACE FUNCTION onyx.rpc_run_consolidation(
    p_period_id UUID,
    p_user_id UUID
) RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
    v_scope_id UUID;
    v_base_currency VARCHAR(3);
    v_package RECORD;
    v_account RECORD;
    v_total_entities INT := 0;
    v_total_accounts INT := 0;
BEGIN
    -- Get scope and currency
    SELECT cs.id, cs.base_currency INTO v_scope_id, v_base_currency
    FROM onyx.consolidation_periods cp
    JOIN onyx.consolidation_scopes cs ON cp.scope_id = cs.id
    WHERE cp.id = p_period_id;

    -- Update period status
    UPDATE onyx.consolidation_periods
    SET status = 'CONSOLIDATION', updated_at = now()
    WHERE id = p_period_id;

    -- Clear previous consolidated data
    DELETE FROM onyx.consolidated_trial_balance WHERE period_id = p_period_id;

    -- Step 1: Aggregate all entity trial balances
    INSERT INTO onyx.consolidated_trial_balance (
        period_id, account_code, account_name, account_type,
        local_entities_total, currency_translation
    )
    SELECT
        p_period_id,
        ptb.group_account_code,
        MAX(ptb.account_name),
        CASE
            WHEN ptb.group_account_code LIKE '1%' OR ptb.group_account_code LIKE '2%' THEN 'ASSET'
            WHEN ptb.group_account_code LIKE '3%' OR ptb.group_account_code LIKE '4%' THEN 'LIABILITY'
            WHEN ptb.group_account_code LIKE '5%' THEN 'EQUITY'
            WHEN ptb.group_account_code LIKE '6%' THEN 'EXPENSE'
            WHEN ptb.group_account_code LIKE '7%' THEN 'REVENUE'
            ELSE 'OTHER'
        END,
        SUM(ptb.closing_balance_group * se.integration_pct / 100.0),
        SUM(ptb.cta_amount * se.integration_pct / 100.0)
    FROM onyx.consolidation_packages pkg
    JOIN onyx.package_trial_balance ptb ON pkg.id = ptb.package_id
    JOIN onyx.scope_entities se ON pkg.entity_id = se.entity_id AND se.scope_id = v_scope_id
    WHERE pkg.period_id = p_period_id
      AND pkg.status = 'APPROVED'
      AND ptb.group_account_code IS NOT NULL
    GROUP BY ptb.group_account_code
    ON CONFLICT (period_id, account_code) DO UPDATE SET
        local_entities_total = EXCLUDED.local_entities_total,
        currency_translation = EXCLUDED.currency_translation;

    GET DIAGNOSTICS v_total_accounts = ROW_COUNT;

    -- Step 2: Generate eliminations
    PERFORM onyx.rpc_generate_eliminations(p_period_id);

    -- Step 3: Apply eliminations
    UPDATE onyx.consolidated_trial_balance ctb
    SET elimination_adjustments = (
        SELECT COALESCE(SUM(eel.debit - eel.credit), 0)
        FROM onyx.elimination_entries ee
        JOIN onyx.elimination_entry_lines eel ON ee.id = eel.entry_id
        WHERE ee.period_id = p_period_id
          AND ee.status = 'POSTED'
          AND eel.account_code = ctb.account_code
    )
    WHERE ctb.period_id = p_period_id;

    -- Step 4: Calculate NCI
    PERFORM onyx.rpc_calculate_nci(p_period_id);

    -- Step 5: Apply NCI adjustments
    UPDATE onyx.consolidated_trial_balance ctb
    SET
        nci_adjustments = COALESCE((
            SELECT SUM(nci.nci_equity)
            FROM onyx.nci_calculations nci
            WHERE nci.period_id = p_period_id
        ), 0) * CASE WHEN ctb.account_type = 'EQUITY' THEN -0.01 ELSE 0 END,
        group_share = ctb.consolidated_balance * 0.99, -- Placeholder
        nci_share = ctb.consolidated_balance * 0.01    -- Placeholder
    WHERE ctb.period_id = p_period_id;

    -- Get entity count
    SELECT COUNT(*) INTO v_total_entities
    FROM onyx.consolidation_packages
    WHERE period_id = p_period_id AND status = 'APPROVED';

    RETURN jsonb_build_object(
        'success', true,
        'period_id', p_period_id,
        'entities_consolidated', v_total_entities,
        'accounts_processed', v_total_accounts,
        'base_currency', v_base_currency
    );
END;
$$;

-- Get consolidation dashboard
CREATE OR REPLACE FUNCTION onyx.rpc_get_consolidation_dashboard(
    p_scope_id UUID,
    p_fiscal_year_id UUID
) RETURNS JSONB LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'scope', (
            SELECT jsonb_build_object(
                'code', cs.code,
                'name', cs.name,
                'base_currency', cs.base_currency,
                'entity_count', (SELECT COUNT(*) FROM onyx.scope_entities WHERE scope_id = p_scope_id AND is_active)
            )
            FROM onyx.consolidation_scopes cs WHERE id = p_scope_id
        ),
        'periods', (
            SELECT jsonb_agg(jsonb_build_object(
                'period_id', cp.id,
                'period_type', cp.period_type,
                'period_number', cp.period_number,
                'period_start', cp.period_start,
                'period_end', cp.period_end,
                'status', cp.status,
                'packages_total', cp.packages_total,
                'packages_approved', cp.packages_approved,
                'completion_pct', ROUND(100.0 * cp.packages_approved / NULLIF(cp.packages_total, 0), 1)
            ) ORDER BY cp.period_start)
            FROM onyx.consolidation_periods cp
            WHERE cp.scope_id = p_scope_id AND cp.fiscal_year_id = p_fiscal_year_id
        ),
        'entities_by_method', (
            SELECT jsonb_object_agg(method, cnt)
            FROM (
                SELECT method::TEXT, COUNT(*) AS cnt
                FROM onyx.scope_entities
                WHERE scope_id = p_scope_id AND is_active
                GROUP BY method
            ) sub
        ),
        'currencies', (
            SELECT jsonb_agg(DISTINCT functional_currency)
            FROM onyx.scope_entities
            WHERE scope_id = p_scope_id AND is_active
        ),
        'goodwill_total', (
            SELECT COALESCE(SUM(goodwill), 0)
            FROM onyx.acquisitions
            WHERE scope_id = p_scope_id AND is_finalized AND goodwill > 0
        ),
        'recent_activity', (
            SELECT jsonb_agg(jsonb_build_object(
                'entity_name', ge.entity_name,
                'package_status', pkg.status,
                'updated_at', pkg.updated_at
            ) ORDER BY pkg.updated_at DESC)
            FROM onyx.consolidation_packages pkg
            JOIN onyx.consolidation_periods cp ON pkg.period_id = cp.id
            JOIN sys.tenant_entities ge ON pkg.entity_id = ge.id
            WHERE cp.scope_id = p_scope_id AND cp.fiscal_year_id = p_fiscal_year_id
            LIMIT 10
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$;

-- ===========================================
-- SECTION 11: INDEXES
-- ===========================================

CREATE INDEX idx_scope_entities_scope ON onyx.scope_entities(scope_id);
CREATE INDEX idx_scope_entities_entity ON onyx.scope_entities(entity_id);
CREATE INDEX idx_ownership_links_scope ON onyx.ownership_links(scope_id);
CREATE INDEX idx_ownership_links_investor ON onyx.ownership_links(investor_entity_id);
CREATE INDEX idx_ownership_links_investee ON onyx.ownership_links(investee_entity_id);
CREATE INDEX idx_conso_periods_scope ON onyx.consolidation_periods(scope_id);
CREATE INDEX idx_conso_periods_fy ON onyx.consolidation_periods(fiscal_year_id);
CREATE INDEX idx_packages_period ON onyx.consolidation_packages(period_id);
CREATE INDEX idx_packages_entity ON onyx.consolidation_packages(entity_id);
CREATE INDEX idx_packages_status ON onyx.consolidation_packages(status);
CREATE INDEX idx_package_tb_package ON onyx.package_trial_balance(package_id);
CREATE INDEX idx_package_ic_package ON onyx.package_ic_declarations(package_id);
CREATE INDEX idx_elim_entries_period ON onyx.elimination_entries(period_id);
CREATE INDEX idx_elim_lines_entry ON onyx.elimination_entry_lines(entry_id);
CREATE INDEX idx_nci_period ON onyx.nci_calculations(period_id);
CREATE INDEX idx_conso_tb_period ON onyx.consolidated_trial_balance(period_id);
CREATE INDEX idx_conso_tb_account ON onyx.consolidated_trial_balance(account_code);

-- ===========================================
-- SECTION 12: COMMENTS
-- ===========================================

COMMENT ON TABLE onyx.consolidation_scopes IS 'Consolidation perimeter definitions';
COMMENT ON TABLE onyx.scope_entities IS 'Entities included in consolidation scope with ownership';
COMMENT ON TABLE onyx.ownership_links IS 'Investment relationships between entities';
COMMENT ON TABLE onyx.consolidation_periods IS 'Consolidation periods (monthly, quarterly, annual)';
COMMENT ON TABLE onyx.consolidation_packages IS 'Data packages submitted by subsidiaries';
COMMENT ON TABLE onyx.package_trial_balance IS 'Trial balance data from packages';
COMMENT ON TABLE onyx.package_ic_declarations IS 'Intercompany transaction declarations';
COMMENT ON TABLE onyx.elimination_entries IS 'Consolidation elimination entries';
COMMENT ON TABLE onyx.nci_calculations IS 'Non-controlling interest calculations';
COMMENT ON TABLE onyx.acquisitions IS 'Business combination and acquisition records';
COMMENT ON TABLE onyx.goodwill_impairment_tests IS 'Annual goodwill impairment test records';
COMMENT ON TABLE onyx.consolidated_trial_balance IS 'Final consolidated trial balance';

COMMENT ON FUNCTION onyx.rpc_calculate_ownership IS 'Calculate direct and indirect ownership percentages';
COMMENT ON FUNCTION onyx.rpc_generate_eliminations IS 'Auto-generate IC elimination entries';
COMMENT ON FUNCTION onyx.rpc_calculate_nci IS 'Calculate non-controlling interests';
COMMENT ON FUNCTION onyx.rpc_run_consolidation IS 'Execute full consolidation process';
COMMENT ON FUNCTION onyx.rpc_get_consolidation_dashboard IS 'Get consolidation status dashboard';
