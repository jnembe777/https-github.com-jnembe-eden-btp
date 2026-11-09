-- ============================================================================
-- EDENFIN SAPHIR — SCRIPT 04 : ADVANCED CONSOLIDATION
-- PostgreSQL 15+ (Supabase)
-- ============================================================================
-- Tier SAPHIR : ETI (50-250 employés)
-- Fonctionnalités ajoutées :
--   - Consolidation intégrale (100% subsidiaires)
--   - Consolidation proportionnelle (joint ventures)
--   - Mise en équivalence (participations 20-50%)
--   - Éliminations inter-compagnies automatiques
--   - Intérêts minoritaires (NCI)
--   - Packages de consolidation
-- ============================================================================
-- Dépend de : JASPE (00-09), RUBIS (01-03), SAPHIR 01 (multicurrency)
-- ============================================================================

-- ============================================================================
-- 1. ENUM TYPES
-- ============================================================================

-- Consolidation method
DO $$ BEGIN
    CREATE TYPE sys.consolidation_method AS ENUM (
        'FULL',             -- 100% integration (>50% control)
        'PROPORTIONAL',     -- Joint venture (proportional %)
        'EQUITY',           -- Associate (20-50%, significant influence)
        'EXCLUDED'          -- Not consolidated
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Consolidation scope
DO $$ BEGIN
    CREATE TYPE sys.consolidation_scope AS ENUM (
        'STATUTORY',        -- Legal entity view
        'MANAGEMENT',       -- Management reporting view
        'IFRS',             -- IFRS consolidated view
        'TAX'               -- Tax consolidation view
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Elimination type
DO $$ BEGIN
    CREATE TYPE sys.elimination_type AS ENUM (
        'IC_RECEIVABLE',        -- Intercompany receivables
        'IC_PAYABLE',           -- Intercompany payables
        'IC_REVENUE',           -- Intercompany revenue
        'IC_EXPENSE',           -- Intercompany expenses
        'IC_DIVIDEND',          -- Intercompany dividends
        'IC_INVESTMENT',        -- Investment in subsidiary
        'IC_EQUITY',            -- Subsidiary equity
        'UNREALIZED_PROFIT',    -- Unrealized profit in inventory
        'UNREALIZED_GAIN',      -- Unrealized gain on asset transfer
        'GOODWILL_IMPAIRMENT'   -- Goodwill impairment
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Consolidation run status
DO $$ BEGIN
    CREATE TYPE sys.consolidation_status AS ENUM (
        'DRAFT',            -- In preparation
        'COLLECTING',       -- Collecting data from entities
        'VALIDATING',       -- Validation in progress
        'ELIMINATING',      -- Eliminations running
        'ADJUSTING',        -- Manual adjustments
        'COMPLETED',        -- Completed
        'PUBLISHED',        -- Published/locked
        'ARCHIVED'          -- Archived
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Package status
DO $$ BEGIN
    CREATE TYPE sys.package_status AS ENUM (
        'NOT_STARTED',      -- Not yet opened
        'IN_PROGRESS',      -- Data entry in progress
        'SUBMITTED',        -- Submitted for validation
        'VALIDATED',        -- Validated by parent
        'REJECTED',         -- Rejected, needs correction
        'LOCKED'            -- Locked, no changes allowed
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- NCI calculation method
DO $$ BEGIN
    CREATE TYPE sys.nci_method AS ENUM (
        'PROPORTIONATE',    -- NCI = % of net assets
        'FULL_GOODWILL'     -- NCI includes share of goodwill
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================================
-- 2. CONSOLIDATION GROUP STRUCTURE
-- ============================================================================

-- 2.1 Consolidation Groups (top-level groupings)
CREATE TABLE IF NOT EXISTS sys.consolidation_groups (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),

    -- Identification
    group_code VARCHAR(20) NOT NULL,
    group_name VARCHAR(200) NOT NULL,
    description TEXT,

    -- Configuration
    scope sys.consolidation_scope NOT NULL DEFAULT 'IFRS',
    reporting_currency VARCHAR(3) NOT NULL DEFAULT 'XAF',
    parent_entity_id BIGINT REFERENCES sys.tenant_entities(id),  -- Ultimate parent

    -- Settings
    nci_method sys.nci_method NOT NULL DEFAULT 'PROPORTIONATE',
    goodwill_amortization_years INT,  -- NULL = no amortization (IFRS)
    negative_goodwill_treatment VARCHAR(30) DEFAULT 'P&L',  -- P&L or EQUITY

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_conso_group UNIQUE (tenant_id, group_code)
);

CREATE INDEX idx_conso_group_tenant ON sys.consolidation_groups(tenant_id);

COMMENT ON TABLE sys.consolidation_groups IS 'Consolidation group definitions';

-- 2.2 Consolidation Perimeter (entities in scope)
CREATE TABLE IF NOT EXISTS sys.consolidation_perimeter (
    id BIGSERIAL PRIMARY KEY,
    group_id BIGINT NOT NULL REFERENCES sys.consolidation_groups(id) ON DELETE CASCADE,
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),

    -- Ownership structure
    direct_parent_id BIGINT REFERENCES sys.tenant_entities(id),
    ownership_percentage DECIMAL(5, 2) NOT NULL CHECK (ownership_percentage BETWEEN 0 AND 100),
    voting_rights_percentage DECIMAL(5, 2) CHECK (voting_rights_percentage BETWEEN 0 AND 100),

    -- Consolidation method
    consolidation_method sys.consolidation_method NOT NULL,

    -- Effective dates
    effective_from DATE NOT NULL,
    effective_to DATE,  -- NULL = current

    -- Acquisition details (for full consolidation)
    acquisition_date DATE,
    acquisition_cost DECIMAL(18, 2),
    goodwill DECIMAL(18, 2),
    bargain_purchase_gain DECIMAL(18, 2),

    -- Control indicators
    has_control BOOLEAN GENERATED ALWAYS AS (ownership_percentage > 50) STORED,
    has_significant_influence BOOLEAN GENERATED ALWAYS AS (
        ownership_percentage >= 20 AND ownership_percentage <= 50
    ) STORED,

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_perimeter_entity UNIQUE (group_id, entity_id, effective_from)
);

CREATE INDEX idx_perimeter_group ON sys.consolidation_perimeter(group_id);
CREATE INDEX idx_perimeter_entity ON sys.consolidation_perimeter(entity_id);
CREATE INDEX idx_perimeter_active ON sys.consolidation_perimeter(is_active) WHERE is_active;

COMMENT ON TABLE sys.consolidation_perimeter IS 'Entities within consolidation perimeter with ownership details';

-- ============================================================================
-- 3. INTERCOMPANY RELATIONSHIPS
-- ============================================================================

-- 3.1 Intercompany Account Mapping
CREATE TABLE IF NOT EXISTS sys.ic_account_mapping (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),

    -- Account identification
    account_code VARCHAR(20) NOT NULL,
    account_name VARCHAR(200) NOT NULL,

    -- Mapping
    elimination_type sys.elimination_type NOT NULL,
    contra_account_code VARCHAR(20),  -- Elimination contra account

    -- Matching
    is_ic_account BOOLEAN NOT NULL DEFAULT TRUE,
    requires_partner_match BOOLEAN NOT NULL DEFAULT TRUE,
    tolerance_amount DECIMAL(18, 2) DEFAULT 0,
    tolerance_percentage DECIMAL(5, 2) DEFAULT 0,

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT uq_ic_account UNIQUE (tenant_id, account_code)
);

CREATE INDEX idx_ic_account_tenant ON sys.ic_account_mapping(tenant_id);
CREATE INDEX idx_ic_account_type ON sys.ic_account_mapping(elimination_type);

COMMENT ON TABLE sys.ic_account_mapping IS 'Mapping of accounts for intercompany elimination';

-- 3.2 Intercompany Balances (reported by entities)
CREATE TABLE IF NOT EXISTS sys.ic_balances (
    id BIGSERIAL PRIMARY KEY,
    consolidation_run_id BIGINT NOT NULL,  -- FK added after consolidation_runs created

    -- Reporting entity
    reporting_entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),

    -- Counterparty
    counterparty_entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),

    -- Account
    account_code VARCHAR(20) NOT NULL,
    elimination_type sys.elimination_type NOT NULL,

    -- Amounts
    amount_local DECIMAL(18, 2) NOT NULL,
    currency_local VARCHAR(3) NOT NULL,
    amount_group DECIMAL(18, 2) NOT NULL,  -- In group currency

    -- Period
    period_date DATE NOT NULL,

    -- Matching
    is_matched BOOLEAN NOT NULL DEFAULT FALSE,
    matched_balance_id BIGINT REFERENCES sys.ic_balances(id),
    difference_amount DECIMAL(18, 2),

    -- Status
    is_eliminated BOOLEAN NOT NULL DEFAULT FALSE,
    elimination_entry_id BIGINT,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0
);

CREATE INDEX idx_ic_balances_run ON sys.ic_balances(consolidation_run_id);
CREATE INDEX idx_ic_balances_reporting ON sys.ic_balances(reporting_entity_id);
CREATE INDEX idx_ic_balances_counterparty ON sys.ic_balances(counterparty_entity_id);
CREATE INDEX idx_ic_balances_period ON sys.ic_balances(period_date);

COMMENT ON TABLE sys.ic_balances IS 'Intercompany balances reported by entities for matching';

-- ============================================================================
-- 4. CONSOLIDATION RUNS
-- ============================================================================

-- 4.1 Consolidation Runs
CREATE TABLE IF NOT EXISTS sys.consolidation_runs (
    id BIGSERIAL PRIMARY KEY,
    group_id BIGINT NOT NULL REFERENCES sys.consolidation_groups(id),

    -- Period
    period_year INT NOT NULL,
    period_month INT NOT NULL CHECK (period_month BETWEEN 1 AND 12),
    period_end_date DATE NOT NULL,
    is_year_end BOOLEAN GENERATED ALWAYS AS (period_month = 12) STORED,

    -- Type
    scope sys.consolidation_scope NOT NULL,
    is_restatement BOOLEAN NOT NULL DEFAULT FALSE,
    restatement_reason TEXT,

    -- Status
    status sys.consolidation_status NOT NULL DEFAULT 'DRAFT',

    -- Progress
    entities_total INT NOT NULL DEFAULT 0,
    entities_collected INT NOT NULL DEFAULT 0,
    entities_validated INT NOT NULL DEFAULT 0,
    progress_percentage DECIMAL(5, 2) GENERATED ALWAYS AS (
        CASE WHEN entities_total > 0
             THEN ROUND((entities_validated::DECIMAL / entities_total) * 100, 2)
             ELSE 0 END
    ) STORED,

    -- Totals (populated during consolidation)
    total_assets DECIMAL(18, 2),
    total_liabilities DECIMAL(18, 2),
    total_equity DECIMAL(18, 2),
    total_revenue DECIMAL(18, 2),
    net_income DECIMAL(18, 2),
    nci_equity DECIMAL(18, 2),
    nci_income DECIMAL(18, 2),

    -- Eliminations summary
    eliminations_count INT DEFAULT 0,
    eliminations_amount DECIMAL(18, 2) DEFAULT 0,

    -- Dates
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    published_at TIMESTAMPTZ,

    -- Notes
    notes TEXT,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_conso_run UNIQUE (group_id, period_year, period_month, scope)
);

-- Add FK constraint to ic_balances now
ALTER TABLE sys.ic_balances
    ADD CONSTRAINT fk_ic_balances_run
    FOREIGN KEY (consolidation_run_id) REFERENCES sys.consolidation_runs(id);

CREATE INDEX idx_conso_run_group ON sys.consolidation_runs(group_id);
CREATE INDEX idx_conso_run_period ON sys.consolidation_runs(period_year, period_month);
CREATE INDEX idx_conso_run_status ON sys.consolidation_runs(status);

COMMENT ON TABLE sys.consolidation_runs IS 'Consolidation run instances by period';

-- 4.2 Entity Packages (data collection from entities)
CREATE TABLE IF NOT EXISTS sys.consolidation_packages (
    id BIGSERIAL PRIMARY KEY,
    run_id BIGINT NOT NULL REFERENCES sys.consolidation_runs(id) ON DELETE CASCADE,
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),

    -- Method
    consolidation_method sys.consolidation_method NOT NULL,
    ownership_percentage DECIMAL(5, 2) NOT NULL,

    -- Status
    status sys.package_status NOT NULL DEFAULT 'NOT_STARTED',

    -- Progress
    trial_balance_loaded BOOLEAN NOT NULL DEFAULT FALSE,
    ic_balances_loaded BOOLEAN NOT NULL DEFAULT FALSE,
    adjustments_complete BOOLEAN NOT NULL DEFAULT FALSE,

    -- Amounts (entity level)
    total_assets DECIMAL(18, 2),
    total_liabilities DECIMAL(18, 2),
    total_equity DECIMAL(18, 2),
    total_revenue DECIMAL(18, 2),
    net_income DECIMAL(18, 2),

    -- Contributed amounts (after ownership %)
    contributed_assets DECIMAL(18, 2),
    contributed_liabilities DECIMAL(18, 2),
    contributed_equity DECIMAL(18, 2),
    contributed_revenue DECIMAL(18, 2),
    contributed_income DECIMAL(18, 2),

    -- Dates
    opened_at TIMESTAMPTZ,
    submitted_at TIMESTAMPTZ,
    validated_at TIMESTAMPTZ,
    validated_by BIGINT,

    -- Comments
    submission_comment TEXT,
    validation_comment TEXT,
    rejection_reason TEXT,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_package UNIQUE (run_id, entity_id)
);

CREATE INDEX idx_package_run ON sys.consolidation_packages(run_id);
CREATE INDEX idx_package_entity ON sys.consolidation_packages(entity_id);
CREATE INDEX idx_package_status ON sys.consolidation_packages(status);

COMMENT ON TABLE sys.consolidation_packages IS 'Data packages collected from each entity';

-- ============================================================================
-- 5. ELIMINATION ENTRIES
-- ============================================================================

-- 5.1 Elimination Entries
CREATE TABLE IF NOT EXISTS sys.elimination_entries (
    id BIGSERIAL PRIMARY KEY,
    run_id BIGINT NOT NULL REFERENCES sys.consolidation_runs(id) ON DELETE CASCADE,

    -- Identification
    entry_number VARCHAR(30) NOT NULL,
    description TEXT NOT NULL,
    elimination_type sys.elimination_type NOT NULL,

    -- Entities involved
    entity_1_id BIGINT REFERENCES sys.tenant_entities(id),
    entity_2_id BIGINT REFERENCES sys.tenant_entities(id),

    -- Auto or manual
    is_automatic BOOLEAN NOT NULL DEFAULT TRUE,
    source_balance_id BIGINT REFERENCES sys.ic_balances(id),

    -- Status
    is_posted BOOLEAN NOT NULL DEFAULT FALSE,
    is_reversed BOOLEAN NOT NULL DEFAULT FALSE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    posted_at TIMESTAMPTZ,
    posted_by BIGINT,

    CONSTRAINT uq_elim_entry UNIQUE (run_id, entry_number)
);

CREATE INDEX idx_elim_entry_run ON sys.elimination_entries(run_id);
CREATE INDEX idx_elim_entry_type ON sys.elimination_entries(elimination_type);

COMMENT ON TABLE sys.elimination_entries IS 'Consolidation elimination journal entries';

-- 5.2 Elimination Entry Lines
CREATE TABLE IF NOT EXISTS sys.elimination_entry_lines (
    id BIGSERIAL PRIMARY KEY,
    entry_id BIGINT NOT NULL REFERENCES sys.elimination_entries(id) ON DELETE CASCADE,

    -- Line details
    line_number INT NOT NULL,
    account_code VARCHAR(20) NOT NULL,
    account_name VARCHAR(200),

    -- Entity (which entity's balance is affected)
    entity_id BIGINT REFERENCES sys.tenant_entities(id),

    -- Amounts
    debit_amount DECIMAL(18, 2) NOT NULL DEFAULT 0,
    credit_amount DECIMAL(18, 2) NOT NULL DEFAULT 0,

    -- Reference
    reference TEXT,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_elim_line UNIQUE (entry_id, line_number),
    CONSTRAINT chk_debit_credit CHECK (
        (debit_amount > 0 AND credit_amount = 0) OR
        (credit_amount > 0 AND debit_amount = 0) OR
        (debit_amount = 0 AND credit_amount = 0)
    )
);

CREATE INDEX idx_elim_line_entry ON sys.elimination_entry_lines(entry_id);
CREATE INDEX idx_elim_line_account ON sys.elimination_entry_lines(account_code);

COMMENT ON TABLE sys.elimination_entry_lines IS 'Lines within elimination entries';

-- ============================================================================
-- 6. MINORITY INTERESTS (NON-CONTROLLING INTERESTS)
-- ============================================================================

CREATE TABLE IF NOT EXISTS sys.minority_interests (
    id BIGSERIAL PRIMARY KEY,
    run_id BIGINT NOT NULL REFERENCES sys.consolidation_runs(id) ON DELETE CASCADE,
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),

    -- Ownership
    nci_percentage DECIMAL(5, 2) NOT NULL,  -- Non-controlling %

    -- Opening balance
    opening_nci_equity DECIMAL(18, 2) NOT NULL DEFAULT 0,

    -- Movements
    share_of_profit_loss DECIMAL(18, 2) NOT NULL DEFAULT 0,
    share_of_oci DECIMAL(18, 2) NOT NULL DEFAULT 0,  -- Other comprehensive income
    dividends_to_nci DECIMAL(18, 2) NOT NULL DEFAULT 0,
    other_movements DECIMAL(18, 2) NOT NULL DEFAULT 0,

    -- Closing balance
    closing_nci_equity DECIMAL(18, 2) GENERATED ALWAYS AS (
        opening_nci_equity + share_of_profit_loss + share_of_oci - dividends_to_nci + other_movements
    ) STORED,

    -- Goodwill allocation (if full goodwill method)
    goodwill_allocated_to_nci DECIMAL(18, 2) DEFAULT 0,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_nci UNIQUE (run_id, entity_id)
);

CREATE INDEX idx_nci_run ON sys.minority_interests(run_id);
CREATE INDEX idx_nci_entity ON sys.minority_interests(entity_id);

COMMENT ON TABLE sys.minority_interests IS 'Non-controlling interests calculation per entity';

-- ============================================================================
-- 7. GOODWILL TRACKING
-- ============================================================================

CREATE TABLE IF NOT EXISTS sys.goodwill_register (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),

    -- Acquisition details
    acquisition_date DATE NOT NULL,

    -- Initial measurement
    consideration_transferred DECIMAL(18, 2) NOT NULL,
    fair_value_identifiable_assets DECIMAL(18, 2) NOT NULL,
    fair_value_liabilities DECIMAL(18, 2) NOT NULL,
    nci_at_acquisition DECIMAL(18, 2) NOT NULL DEFAULT 0,

    -- Goodwill calculation
    goodwill_initial DECIMAL(18, 2) GENERATED ALWAYS AS (
        consideration_transferred + nci_at_acquisition - fair_value_identifiable_assets + fair_value_liabilities
    ) STORED,

    -- Impairment history
    accumulated_impairment DECIMAL(18, 2) NOT NULL DEFAULT 0,

    -- Current balance
    goodwill_current DECIMAL(18, 2) GENERATED ALWAYS AS (
        GREATEST(consideration_transferred + nci_at_acquisition - fair_value_identifiable_assets + fair_value_liabilities - accumulated_impairment, 0)
    ) STORED,

    -- CGU assignment (for impairment testing)
    cgu_name VARCHAR(200),

    -- Status
    is_fully_impaired BOOLEAN GENERATED ALWAYS AS (
        consideration_transferred + nci_at_acquisition - fair_value_identifiable_assets + fair_value_liabilities <= accumulated_impairment
    ) STORED,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_goodwill UNIQUE (tenant_id, entity_id)
);

CREATE INDEX idx_goodwill_tenant ON sys.goodwill_register(tenant_id);
CREATE INDEX idx_goodwill_entity ON sys.goodwill_register(entity_id);

COMMENT ON TABLE sys.goodwill_register IS 'Goodwill tracking per subsidiary';

-- ============================================================================
-- 8. RPC FUNCTIONS
-- ============================================================================

-- 8.1 Start Consolidation Run
CREATE OR REPLACE FUNCTION sys.rpc_start_consolidation_run(
    p_group_id BIGINT,
    p_period_year INT,
    p_period_month INT,
    p_scope sys.consolidation_scope DEFAULT 'IFRS'
)
RETURNS TABLE (
    run_id BIGINT,
    entities_count INT,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_run_id BIGINT;
    v_entity_count INT;
    v_period_end DATE;
    v_perimeter RECORD;
BEGIN
    -- Calculate period end
    v_period_end := (DATE_TRUNC('MONTH', MAKE_DATE(p_period_year, p_period_month, 1)) + INTERVAL '1 month - 1 day')::DATE;

    -- Check if run already exists
    IF EXISTS (
        SELECT 1 FROM sys.consolidation_runs
        WHERE group_id = p_group_id
          AND period_year = p_period_year
          AND period_month = p_period_month
          AND scope = p_scope
    ) THEN
        RETURN QUERY SELECT NULL::BIGINT, 0, 'Consolidation run already exists for this period'::TEXT;
        RETURN;
    END IF;

    -- Count entities in perimeter
    SELECT COUNT(*) INTO v_entity_count
    FROM sys.consolidation_perimeter
    WHERE group_id = p_group_id
      AND is_active
      AND consolidation_method != 'EXCLUDED';

    IF v_entity_count = 0 THEN
        RETURN QUERY SELECT NULL::BIGINT, 0, 'No entities in consolidation perimeter'::TEXT;
        RETURN;
    END IF;

    -- Create consolidation run
    INSERT INTO sys.consolidation_runs (
        group_id, period_year, period_month, period_end_date,
        scope, status, entities_total, started_at
    ) VALUES (
        p_group_id, p_period_year, p_period_month, v_period_end,
        p_scope, 'COLLECTING', v_entity_count, NOW()
    )
    RETURNING id INTO v_run_id;

    -- Create packages for each entity
    FOR v_perimeter IN (
        SELECT entity_id, consolidation_method, ownership_percentage
        FROM sys.consolidation_perimeter
        WHERE group_id = p_group_id
          AND is_active
          AND consolidation_method != 'EXCLUDED'
    ) LOOP
        INSERT INTO sys.consolidation_packages (
            run_id, entity_id, consolidation_method, ownership_percentage,
            status, opened_at
        ) VALUES (
            v_run_id, v_perimeter.entity_id, v_perimeter.consolidation_method,
            v_perimeter.ownership_percentage, 'NOT_STARTED', NOW()
        );
    END LOOP;

    RETURN QUERY SELECT v_run_id, v_entity_count, 'Consolidation run started successfully'::TEXT;
END;
$$;

COMMENT ON FUNCTION sys.rpc_start_consolidation_run IS 'Start a new consolidation run for a period';

-- 8.2 Submit Package
CREATE OR REPLACE FUNCTION sys.rpc_submit_package(
    p_package_id BIGINT,
    p_total_assets DECIMAL(18, 2),
    p_total_liabilities DECIMAL(18, 2),
    p_total_equity DECIMAL(18, 2),
    p_total_revenue DECIMAL(18, 2),
    p_net_income DECIMAL(18, 2),
    p_comment TEXT DEFAULT NULL
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_package RECORD;
BEGIN
    -- Get package
    SELECT * INTO v_package FROM sys.consolidation_packages WHERE id = p_package_id;

    IF v_package IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Package not found'::TEXT;
        RETURN;
    END IF;

    IF v_package.status NOT IN ('NOT_STARTED', 'IN_PROGRESS', 'REJECTED') THEN
        RETURN QUERY SELECT FALSE, 'Package cannot be submitted in current status'::TEXT;
        RETURN;
    END IF;

    -- Calculate contributed amounts based on ownership %
    UPDATE sys.consolidation_packages
    SET status = 'SUBMITTED',
        total_assets = p_total_assets,
        total_liabilities = p_total_liabilities,
        total_equity = p_total_equity,
        total_revenue = p_total_revenue,
        net_income = p_net_income,
        contributed_assets = CASE
            WHEN consolidation_method = 'FULL' THEN p_total_assets
            WHEN consolidation_method = 'PROPORTIONAL' THEN p_total_assets * ownership_percentage / 100
            ELSE 0 END,
        contributed_liabilities = CASE
            WHEN consolidation_method = 'FULL' THEN p_total_liabilities
            WHEN consolidation_method = 'PROPORTIONAL' THEN p_total_liabilities * ownership_percentage / 100
            ELSE 0 END,
        contributed_equity = CASE
            WHEN consolidation_method = 'FULL' THEN p_total_equity
            WHEN consolidation_method = 'PROPORTIONAL' THEN p_total_equity * ownership_percentage / 100
            WHEN consolidation_method = 'EQUITY' THEN p_total_equity * ownership_percentage / 100
            ELSE 0 END,
        contributed_revenue = CASE
            WHEN consolidation_method = 'FULL' THEN p_total_revenue
            WHEN consolidation_method = 'PROPORTIONAL' THEN p_total_revenue * ownership_percentage / 100
            ELSE 0 END,
        contributed_income = CASE
            WHEN consolidation_method = 'FULL' THEN p_net_income
            WHEN consolidation_method = 'PROPORTIONAL' THEN p_net_income * ownership_percentage / 100
            WHEN consolidation_method = 'EQUITY' THEN p_net_income * ownership_percentage / 100
            ELSE 0 END,
        trial_balance_loaded = TRUE,
        submitted_at = NOW(),
        submission_comment = p_comment,
        updated_at = NOW()
    WHERE id = p_package_id;

    -- Update run progress
    UPDATE sys.consolidation_runs
    SET entities_collected = (
        SELECT COUNT(*) FROM sys.consolidation_packages
        WHERE run_id = v_package.run_id AND status IN ('SUBMITTED', 'VALIDATED', 'LOCKED')
    ),
    updated_at = NOW()
    WHERE id = v_package.run_id;

    RETURN QUERY SELECT TRUE, 'Package submitted successfully'::TEXT;
END;
$$;

COMMENT ON FUNCTION sys.rpc_submit_package IS 'Submit entity package with financial data';

-- 8.3 Generate Elimination Entries
CREATE OR REPLACE FUNCTION sys.rpc_generate_eliminations(
    p_run_id BIGINT
)
RETURNS TABLE (
    entries_created INT,
    total_amount DECIMAL(18, 2),
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_run RECORD;
    v_balance RECORD;
    v_entry_id BIGINT;
    v_entry_count INT := 0;
    v_total DECIMAL(18, 2) := 0;
    v_entry_num INT := 1;
BEGIN
    -- Get run
    SELECT * INTO v_run FROM sys.consolidation_runs WHERE id = p_run_id;

    IF v_run IS NULL THEN
        RETURN QUERY SELECT 0, 0::DECIMAL(18,2), 'Consolidation run not found'::TEXT;
        RETURN;
    END IF;

    -- Update status
    UPDATE sys.consolidation_runs
    SET status = 'ELIMINATING', updated_at = NOW()
    WHERE id = p_run_id;

    -- Match IC balances and create eliminations
    FOR v_balance IN (
        SELECT b1.*, b2.id AS matched_id, b2.amount_group AS matched_amount
        FROM sys.ic_balances b1
        JOIN sys.ic_balances b2 ON
            b1.consolidation_run_id = b2.consolidation_run_id
            AND b1.reporting_entity_id = b2.counterparty_entity_id
            AND b1.counterparty_entity_id = b2.reporting_entity_id
            AND b1.elimination_type = b2.elimination_type
        WHERE b1.consolidation_run_id = p_run_id
          AND b1.is_eliminated = FALSE
          AND b1.id < b2.id  -- Avoid duplicates
    ) LOOP
        -- Create elimination entry
        INSERT INTO sys.elimination_entries (
            run_id, entry_number, description, elimination_type,
            entity_1_id, entity_2_id, is_automatic, source_balance_id
        ) VALUES (
            p_run_id,
            'ELIM-' || p_run_id || '-' || LPAD(v_entry_num::TEXT, 4, '0'),
            'Elimination: ' || v_balance.elimination_type,
            v_balance.elimination_type,
            v_balance.reporting_entity_id,
            v_balance.counterparty_entity_id,
            TRUE,
            v_balance.id
        )
        RETURNING id INTO v_entry_id;

        -- Create debit line
        INSERT INTO sys.elimination_entry_lines (
            entry_id, line_number, account_code, entity_id,
            debit_amount, credit_amount
        ) VALUES (
            v_entry_id, 1, v_balance.account_code, v_balance.reporting_entity_id,
            v_balance.amount_group, 0
        );

        -- Create credit line
        INSERT INTO sys.elimination_entry_lines (
            entry_id, line_number, account_code, entity_id,
            debit_amount, credit_amount
        ) VALUES (
            v_entry_id, 2, v_balance.account_code, v_balance.counterparty_entity_id,
            0, v_balance.amount_group
        );

        -- Mark balances as eliminated
        UPDATE sys.ic_balances
        SET is_eliminated = TRUE, elimination_entry_id = v_entry_id,
            is_matched = TRUE, matched_balance_id = v_balance.matched_id
        WHERE id = v_balance.id;

        UPDATE sys.ic_balances
        SET is_eliminated = TRUE, elimination_entry_id = v_entry_id,
            is_matched = TRUE, matched_balance_id = v_balance.id
        WHERE id = v_balance.matched_id;

        v_entry_count := v_entry_count + 1;
        v_total := v_total + v_balance.amount_group;
        v_entry_num := v_entry_num + 1;
    END LOOP;

    -- Update run
    UPDATE sys.consolidation_runs
    SET eliminations_count = v_entry_count,
        eliminations_amount = v_total,
        status = 'ADJUSTING',
        updated_at = NOW()
    WHERE id = p_run_id;

    RETURN QUERY SELECT v_entry_count, v_total, 'Eliminations generated successfully'::TEXT;
END;
$$;

COMMENT ON FUNCTION sys.rpc_generate_eliminations IS 'Generate automatic elimination entries';

-- 8.4 Calculate NCI
CREATE OR REPLACE FUNCTION sys.rpc_calculate_nci(
    p_run_id BIGINT
)
RETURNS TABLE (
    entities_processed INT,
    total_nci_equity DECIMAL(18, 2),
    total_nci_income DECIMAL(18, 2)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_package RECORD;
    v_count INT := 0;
    v_total_equity DECIMAL(18, 2) := 0;
    v_total_income DECIMAL(18, 2) := 0;
    v_nci_pct DECIMAL(5, 2);
    v_prior_nci RECORD;
BEGIN
    -- Process each entity with NCI (full consolidation with < 100% ownership)
    FOR v_package IN (
        SELECT p.*, pe.ownership_percentage
        FROM sys.consolidation_packages p
        JOIN sys.consolidation_perimeter pe ON pe.entity_id = p.entity_id
        WHERE p.run_id = p_run_id
          AND p.consolidation_method = 'FULL'
          AND pe.ownership_percentage < 100
          AND pe.is_active
    ) LOOP
        v_nci_pct := 100 - v_package.ownership_percentage;

        -- Try to get prior period NCI
        SELECT closing_nci_equity INTO v_prior_nci
        FROM sys.minority_interests mi
        JOIN sys.consolidation_runs r ON r.id = mi.run_id
        WHERE mi.entity_id = v_package.entity_id
          AND r.group_id = (SELECT group_id FROM sys.consolidation_runs WHERE id = p_run_id)
        ORDER BY r.period_year DESC, r.period_month DESC
        LIMIT 1;

        -- Insert/update NCI
        INSERT INTO sys.minority_interests (
            run_id, entity_id, nci_percentage,
            opening_nci_equity, share_of_profit_loss
        ) VALUES (
            p_run_id, v_package.entity_id, v_nci_pct,
            COALESCE(v_prior_nci.closing_nci_equity, 0),
            COALESCE(v_package.net_income, 0) * v_nci_pct / 100
        )
        ON CONFLICT (run_id, entity_id) DO UPDATE
        SET nci_percentage = v_nci_pct,
            share_of_profit_loss = COALESCE(v_package.net_income, 0) * v_nci_pct / 100,
            updated_at = NOW();

        v_count := v_count + 1;
        v_total_equity := v_total_equity + (COALESCE(v_package.total_equity, 0) * v_nci_pct / 100);
        v_total_income := v_total_income + (COALESCE(v_package.net_income, 0) * v_nci_pct / 100);
    END LOOP;

    -- Update run totals
    UPDATE sys.consolidation_runs
    SET nci_equity = v_total_equity,
        nci_income = v_total_income,
        updated_at = NOW()
    WHERE id = p_run_id;

    RETURN QUERY SELECT v_count, v_total_equity, v_total_income;
END;
$$;

COMMENT ON FUNCTION sys.rpc_calculate_nci IS 'Calculate non-controlling interests for consolidation';

-- 8.5 Complete Consolidation Run
CREATE OR REPLACE FUNCTION sys.rpc_complete_consolidation(
    p_run_id BIGINT
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_run RECORD;
BEGIN
    SELECT * INTO v_run FROM sys.consolidation_runs WHERE id = p_run_id;

    IF v_run IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Run not found'::TEXT;
        RETURN;
    END IF;

    -- Calculate consolidated totals
    UPDATE sys.consolidation_runs
    SET total_assets = (
            SELECT SUM(contributed_assets) FROM sys.consolidation_packages WHERE run_id = p_run_id
        ),
        total_liabilities = (
            SELECT SUM(contributed_liabilities) FROM sys.consolidation_packages WHERE run_id = p_run_id
        ),
        total_equity = (
            SELECT SUM(contributed_equity) FROM sys.consolidation_packages WHERE run_id = p_run_id
        ) - COALESCE(nci_equity, 0),
        total_revenue = (
            SELECT SUM(contributed_revenue) FROM sys.consolidation_packages WHERE run_id = p_run_id
        ),
        net_income = (
            SELECT SUM(contributed_income) FROM sys.consolidation_packages WHERE run_id = p_run_id
        ) - COALESCE(nci_income, 0),
        status = 'COMPLETED',
        completed_at = NOW(),
        updated_at = NOW()
    WHERE id = p_run_id;

    RETURN QUERY SELECT TRUE, 'Consolidation completed successfully'::TEXT;
END;
$$;

COMMENT ON FUNCTION sys.rpc_complete_consolidation IS 'Complete consolidation run and calculate final totals';

-- ============================================================================
-- 9. VIEWS
-- ============================================================================

-- 9.1 Consolidation Overview
CREATE OR REPLACE VIEW sys.v_consolidation_overview AS
SELECT
    r.id AS run_id,
    g.group_name,
    r.period_year,
    r.period_month,
    r.scope,
    r.status,
    r.entities_total,
    r.entities_validated,
    r.progress_percentage,
    r.total_assets,
    r.total_liabilities,
    r.total_equity,
    r.total_revenue,
    r.net_income,
    r.nci_equity,
    r.nci_income,
    r.eliminations_count,
    r.eliminations_amount,
    r.started_at,
    r.completed_at
FROM sys.consolidation_runs r
JOIN sys.consolidation_groups g ON g.id = r.group_id;

COMMENT ON VIEW sys.v_consolidation_overview IS 'Consolidation run summary';

-- 9.2 Package Status
CREATE OR REPLACE VIEW sys.v_package_status AS
SELECT
    p.run_id,
    r.period_year,
    r.period_month,
    e.entity_name,
    p.consolidation_method,
    p.ownership_percentage,
    p.status,
    p.trial_balance_loaded,
    p.ic_balances_loaded,
    p.total_assets,
    p.total_equity,
    p.net_income,
    p.contributed_assets,
    p.contributed_equity,
    p.contributed_income,
    p.submitted_at,
    p.validated_at
FROM sys.consolidation_packages p
JOIN sys.consolidation_runs r ON r.id = p.run_id
JOIN sys.tenant_entities e ON e.id = p.entity_id;

COMMENT ON VIEW sys.v_package_status IS 'Entity package collection status';

-- 9.3 IC Matching Summary
CREATE OR REPLACE VIEW sys.v_ic_matching AS
SELECT
    b.consolidation_run_id,
    e1.entity_name AS reporting_entity,
    e2.entity_name AS counterparty_entity,
    b.elimination_type,
    b.amount_group,
    b.is_matched,
    CASE WHEN b.matched_balance_id IS NOT NULL THEN
        (SELECT amount_group FROM sys.ic_balances WHERE id = b.matched_balance_id)
    END AS matched_amount,
    b.difference_amount,
    b.is_eliminated
FROM sys.ic_balances b
JOIN sys.tenant_entities e1 ON e1.id = b.reporting_entity_id
JOIN sys.tenant_entities e2 ON e2.id = b.counterparty_entity_id;

COMMENT ON VIEW sys.v_ic_matching IS 'Intercompany balance matching status';

-- 9.4 NCI Summary
CREATE OR REPLACE VIEW sys.v_nci_summary AS
SELECT
    nci.run_id,
    r.period_year,
    r.period_month,
    e.entity_name,
    nci.nci_percentage,
    nci.opening_nci_equity,
    nci.share_of_profit_loss,
    nci.share_of_oci,
    nci.dividends_to_nci,
    nci.closing_nci_equity
FROM sys.minority_interests nci
JOIN sys.consolidation_runs r ON r.id = nci.run_id
JOIN sys.tenant_entities e ON e.id = nci.entity_id;

COMMENT ON VIEW sys.v_nci_summary IS 'Non-controlling interests summary';

-- ============================================================================
-- 10. COMPLETION NOTICE
-- ============================================================================

COMMENT ON SCHEMA sys IS 'EdenFin System Schema - SAPHIR Consolidation Extension';

DO $$ BEGIN
    RAISE NOTICE '✅ SAPHIR 04 Consolidation - Schema created successfully';
    RAISE NOTICE 'Tables: 10';
    RAISE NOTICE 'Functions: 5 RPC functions';
    RAISE NOTICE 'Views: 4';
END $$;
