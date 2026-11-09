-- ============================================================================
-- EDENFIN SAPHIR — SCRIPT 03 : IFRS COMPLIANCE
-- PostgreSQL 15+ (Supabase)
-- ============================================================================
-- Tier SAPHIR : ETI (50-250 employés)
-- Fonctionnalités ajoutées :
--   - IFRS 9  : Expected Credit Loss (ECL)
--   - IFRS 15 : Revenue Recognition (5-step model)
--   - IFRS 16 : Lease Accounting (ROU assets)
--   - IAS 21  : Foreign Currency (via 01_multicurrency)
--   - IAS 36  : Impairment Testing
-- ============================================================================
-- Dépend de : JASPE (00-09), RUBIS (01-03), SAPHIR 01 (multicurrency)
-- ============================================================================

-- ============================================================================
-- 1. ENUM TYPES
-- ============================================================================

-- IFRS Standards
DO $$ BEGIN
    CREATE TYPE sys.ifrs_standard AS ENUM (
        'IFRS9',            -- Financial instruments
        'IFRS15',           -- Revenue from contracts
        'IFRS16',           -- Leases
        'IAS21',            -- Foreign currency
        'IAS36',            -- Impairment
        'IAS37',            -- Provisions
        'IAS38',            -- Intangible assets
        'IAS40'             -- Investment property
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Revenue recognition method (IFRS 15)
DO $$ BEGIN
    CREATE TYPE sys.revenue_recognition_method AS ENUM (
        'POINT_IN_TIME',    -- Revenue at delivery/transfer
        'OVER_TIME_OUTPUT', -- Output method (milestones)
        'OVER_TIME_INPUT',  -- Input method (cost incurred)
        'POC'               -- Percentage of completion
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Contract status
DO $$ BEGIN
    CREATE TYPE sys.contract_status AS ENUM (
        'DRAFT',
        'ACTIVE',
        'COMPLETED',
        'MODIFIED',
        'TERMINATED',
        'IMPAIRED'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Lease type (IFRS 16)
DO $$ BEGIN
    CREATE TYPE sys.lease_type AS ENUM (
        'FINANCE',          -- Finance lease (capitalize)
        'OPERATING_OLD',    -- Operating lease (pre-IFRS16)
        'SHORT_TERM',       -- <12 months exemption
        'LOW_VALUE'         -- Low value exemption
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ECL stage (IFRS 9)
DO $$ BEGIN
    CREATE TYPE sys.ecl_stage AS ENUM (
        'STAGE_1',          -- 12-month ECL
        'STAGE_2',          -- Lifetime ECL (not credit-impaired)
        'STAGE_3'           -- Lifetime ECL (credit-impaired)
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ECL methodology
DO $$ BEGIN
    CREATE TYPE sys.ecl_methodology AS ENUM (
        'SIMPLIFIED',       -- Trade receivables (always lifetime)
        'GENERAL'           -- General approach (3-stage)
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Impairment indicator
DO $$ BEGIN
    CREATE TYPE sys.impairment_indicator AS ENUM (
        'MARKET_VALUE_DECLINE',
        'ADVERSE_CHANGES',
        'INTEREST_RATE_INCREASE',
        'OBSOLESCENCE',
        'PHYSICAL_DAMAGE',
        'RESTRUCTURING',
        'WORSE_PERFORMANCE',
        'OTHER'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================================
-- 2. IFRS STANDARDS CONFIGURATION
-- ============================================================================

CREATE TABLE IF NOT EXISTS sys.ifrs_standards_config (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    entity_id BIGINT REFERENCES sys.tenant_entities(id),  -- NULL = all entities

    -- Standard
    standard sys.ifrs_standard NOT NULL,
    standard_version VARCHAR(20),           -- e.g., '2018', '2019 Amendment'

    -- Adoption
    is_adopted BOOLEAN NOT NULL DEFAULT FALSE,
    adoption_date DATE,
    first_application_date DATE,

    -- Configuration (standard-specific JSON)
    configuration JSONB NOT NULL DEFAULT '{}',

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_ifrs_config UNIQUE (tenant_id, entity_id, standard)
);

CREATE INDEX idx_ifrs_config_tenant ON sys.ifrs_standards_config(tenant_id);
CREATE INDEX idx_ifrs_config_standard ON sys.ifrs_standards_config(standard);

COMMENT ON TABLE sys.ifrs_standards_config IS 'IFRS standards configuration per entity';

-- ============================================================================
-- 3. IFRS 15 — REVENUE RECOGNITION
-- ============================================================================

-- 3.1 Revenue Contracts
CREATE TABLE IF NOT EXISTS sys.revenue_contracts (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),

    -- Identification
    contract_number VARCHAR(50) NOT NULL,
    contract_name VARCHAR(200) NOT NULL,
    description TEXT,

    -- Customer
    customer_id BIGINT NOT NULL,            -- References customer table
    customer_name VARCHAR(200),

    -- Contract details
    contract_date DATE NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,

    -- Value
    total_contract_value DECIMAL(18, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'XAF',

    -- Recognition
    recognition_method sys.revenue_recognition_method NOT NULL,

    -- Status
    status sys.contract_status NOT NULL DEFAULT 'DRAFT',

    -- Progress tracking
    recognized_revenue DECIMAL(18, 2) NOT NULL DEFAULT 0,
    deferred_revenue DECIMAL(18, 2) GENERATED ALWAYS AS (total_contract_value - recognized_revenue) STORED,
    completion_percentage DECIMAL(5, 2) NOT NULL DEFAULT 0,

    -- Variable consideration
    variable_consideration DECIMAL(18, 2) DEFAULT 0,
    constraint_applied BOOLEAN NOT NULL DEFAULT FALSE,

    -- Financing component
    has_financing_component BOOLEAN NOT NULL DEFAULT FALSE,
    financing_rate DECIMAL(8, 4),

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,
    deleted_at TIMESTAMPTZ,
    deleted_by BIGINT,
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_revenue_contract UNIQUE (entity_id, contract_number)
);

CREATE INDEX idx_revenue_contracts_entity ON sys.revenue_contracts(entity_id);
CREATE INDEX idx_revenue_contracts_customer ON sys.revenue_contracts(customer_id);
CREATE INDEX idx_revenue_contracts_status ON sys.revenue_contracts(status);

COMMENT ON TABLE sys.revenue_contracts IS 'IFRS 15 revenue contracts';

-- 3.2 Performance Obligations
CREATE TABLE IF NOT EXISTS sys.performance_obligations (
    id BIGSERIAL PRIMARY KEY,
    contract_id BIGINT NOT NULL REFERENCES sys.revenue_contracts(id) ON DELETE CASCADE,

    -- Identification
    obligation_number INT NOT NULL,
    obligation_name VARCHAR(200) NOT NULL,
    description TEXT,

    -- Standalone selling price
    standalone_price DECIMAL(18, 2) NOT NULL,
    allocated_price DECIMAL(18, 2) NOT NULL,    -- After allocation

    -- Recognition
    recognition_method sys.revenue_recognition_method NOT NULL,
    is_distinct BOOLEAN NOT NULL DEFAULT TRUE,

    -- Progress (for over-time)
    completion_percentage DECIMAL(5, 2) NOT NULL DEFAULT 0,
    recognized_amount DECIMAL(18, 2) NOT NULL DEFAULT 0,

    -- Satisfaction
    is_satisfied BOOLEAN NOT NULL DEFAULT FALSE,
    satisfaction_date DATE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_perf_obligation UNIQUE (contract_id, obligation_number)
);

CREATE INDEX idx_perf_obligations_contract ON sys.performance_obligations(contract_id);

COMMENT ON TABLE sys.performance_obligations IS 'IFRS 15 performance obligations within contracts';

-- 3.3 Revenue Recognition Events
CREATE TABLE IF NOT EXISTS sys.revenue_recognition_events (
    id BIGSERIAL PRIMARY KEY,
    contract_id BIGINT NOT NULL REFERENCES sys.revenue_contracts(id),
    obligation_id BIGINT REFERENCES sys.performance_obligations(id),

    -- Event
    event_date DATE NOT NULL,
    event_type VARCHAR(50) NOT NULL,        -- MILESTONE, PERIOD_END, DELIVERY, etc.

    -- Amount
    recognized_amount DECIMAL(18, 2) NOT NULL,
    cumulative_amount DECIMAL(18, 2) NOT NULL,

    -- Basis
    completion_before DECIMAL(5, 2),
    completion_after DECIMAL(5, 2),
    recognition_basis TEXT,                 -- Explanation

    -- Journal entry
    journal_entry_id BIGINT,
    is_posted BOOLEAN NOT NULL DEFAULT FALSE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0
);

CREATE INDEX idx_revenue_events_contract ON sys.revenue_recognition_events(contract_id);
CREATE INDEX idx_revenue_events_date ON sys.revenue_recognition_events(event_date);

COMMENT ON TABLE sys.revenue_recognition_events IS 'IFRS 15 revenue recognition journal';

-- ============================================================================
-- 4. IFRS 16 — LEASE ACCOUNTING
-- ============================================================================

-- 4.1 Lease Contracts
CREATE TABLE IF NOT EXISTS sys.lease_contracts (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),

    -- Identification
    lease_number VARCHAR(50) NOT NULL,
    lease_name VARCHAR(200) NOT NULL,
    description TEXT,

    -- Lessor
    lessor_name VARCHAR(200) NOT NULL,
    lessor_id BIGINT,                       -- References supplier if applicable

    -- Asset
    asset_description TEXT NOT NULL,
    asset_category VARCHAR(50),             -- PROPERTY, VEHICLE, EQUIPMENT, etc.
    asset_location VARCHAR(200),

    -- Lease terms
    lease_type sys.lease_type NOT NULL,
    commencement_date DATE NOT NULL,
    end_date DATE NOT NULL,
    lease_term_months INT GENERATED ALWAYS AS (
        (EXTRACT(YEAR FROM end_date) - EXTRACT(YEAR FROM commencement_date)) * 12 +
        (EXTRACT(MONTH FROM end_date) - EXTRACT(MONTH FROM commencement_date))
    ) STORED,

    -- Payments
    monthly_payment DECIMAL(18, 2) NOT NULL,
    payment_frequency VARCHAR(20) NOT NULL DEFAULT 'MONTHLY',
    payment_timing VARCHAR(20) NOT NULL DEFAULT 'END',  -- BEGIN or END of period
    currency VARCHAR(3) NOT NULL DEFAULT 'XAF',

    -- Variable payments
    variable_payments DECIMAL(18, 2) DEFAULT 0,
    residual_value_guarantee DECIMAL(18, 2) DEFAULT 0,
    purchase_option_price DECIMAL(18, 2),
    purchase_option_reasonably_certain BOOLEAN DEFAULT FALSE,

    -- Discount rate
    implicit_rate DECIMAL(8, 4),            -- Rate implicit in lease
    incremental_borrowing_rate DECIMAL(8, 4) NOT NULL,  -- Lessee's IBR
    discount_rate DECIMAL(8, 4) GENERATED ALWAYS AS (
        COALESCE(implicit_rate, incremental_borrowing_rate)
    ) STORED,

    -- Initial measurement
    lease_liability_initial DECIMAL(18, 2) NOT NULL,
    rou_asset_initial DECIMAL(18, 2) NOT NULL,
    initial_direct_costs DECIMAL(18, 2) DEFAULT 0,

    -- Current balances
    lease_liability_current DECIMAL(18, 2) NOT NULL,
    rou_asset_current DECIMAL(18, 2) NOT NULL,
    accumulated_depreciation DECIMAL(18, 2) NOT NULL DEFAULT 0,

    -- Depreciation
    depreciation_method VARCHAR(20) NOT NULL DEFAULT 'STRAIGHT_LINE',
    useful_life_months INT,                 -- If different from lease term

    -- Status
    status sys.contract_status NOT NULL DEFAULT 'ACTIVE',

    -- Modification tracking
    modification_date DATE,
    modification_type VARCHAR(50),

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,
    deleted_at TIMESTAMPTZ,
    deleted_by BIGINT,
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_lease_contract UNIQUE (entity_id, lease_number)
);

CREATE INDEX idx_lease_contracts_entity ON sys.lease_contracts(entity_id);
CREATE INDEX idx_lease_contracts_type ON sys.lease_contracts(lease_type);
CREATE INDEX idx_lease_contracts_status ON sys.lease_contracts(status);

COMMENT ON TABLE sys.lease_contracts IS 'IFRS 16 lease contracts';

-- 4.2 Lease Payment Schedule
CREATE TABLE IF NOT EXISTS sys.lease_payment_schedule (
    id BIGSERIAL PRIMARY KEY,
    lease_id BIGINT NOT NULL REFERENCES sys.lease_contracts(id) ON DELETE CASCADE,

    -- Period
    period_number INT NOT NULL,
    period_start_date DATE NOT NULL,
    period_end_date DATE NOT NULL,

    -- Payment
    payment_amount DECIMAL(18, 2) NOT NULL,
    payment_date DATE NOT NULL,

    -- Split
    interest_expense DECIMAL(18, 2) NOT NULL,
    principal_repayment DECIMAL(18, 2) NOT NULL,

    -- Balances
    opening_liability DECIMAL(18, 2) NOT NULL,
    closing_liability DECIMAL(18, 2) NOT NULL,

    -- Depreciation
    depreciation_expense DECIMAL(18, 2) NOT NULL,
    opening_rou_asset DECIMAL(18, 2) NOT NULL,
    closing_rou_asset DECIMAL(18, 2) NOT NULL,

    -- Status
    is_paid BOOLEAN NOT NULL DEFAULT FALSE,
    paid_date DATE,
    journal_entry_id BIGINT,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_lease_schedule UNIQUE (lease_id, period_number)
);

CREATE INDEX idx_lease_schedule_lease ON sys.lease_payment_schedule(lease_id);
CREATE INDEX idx_lease_schedule_date ON sys.lease_payment_schedule(payment_date);

COMMENT ON TABLE sys.lease_payment_schedule IS 'IFRS 16 lease amortization schedule';

-- ============================================================================
-- 5. IFRS 9 — EXPECTED CREDIT LOSS (ECL)
-- ============================================================================

-- 5.1 ECL Models
CREATE TABLE IF NOT EXISTS sys.ecl_models (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),

    -- Identification
    model_code VARCHAR(30) NOT NULL,
    model_name VARCHAR(200) NOT NULL,
    description TEXT,

    -- Scope
    portfolio_type VARCHAR(50) NOT NULL,    -- TRADE_RECEIVABLES, LOANS, INVESTMENTS
    methodology sys.ecl_methodology NOT NULL,

    -- Parameters
    pd_matrix JSONB NOT NULL DEFAULT '{}',  -- Probability of default by aging
    lgd_rate DECIMAL(5, 2) NOT NULL,        -- Loss given default (%)

    -- For simplified approach
    provision_matrix JSONB,                  -- Direct provision rates by aging

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    effective_date DATE NOT NULL,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_ecl_model UNIQUE (entity_id, model_code)
);

CREATE INDEX idx_ecl_models_entity ON sys.ecl_models(entity_id);

COMMENT ON TABLE sys.ecl_models IS 'IFRS 9 ECL model definitions';

-- 5.2 ECL Calculations
CREATE TABLE IF NOT EXISTS sys.ecl_calculations (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),
    model_id BIGINT NOT NULL REFERENCES sys.ecl_models(id),

    -- Calculation date
    calculation_date DATE NOT NULL,
    period_end DATE NOT NULL,

    -- Portfolio summary
    gross_carrying_amount DECIMAL(18, 2) NOT NULL,

    -- By stage (for general approach)
    stage1_exposure DECIMAL(18, 2) DEFAULT 0,
    stage1_ecl DECIMAL(18, 2) DEFAULT 0,
    stage2_exposure DECIMAL(18, 2) DEFAULT 0,
    stage2_ecl DECIMAL(18, 2) DEFAULT 0,
    stage3_exposure DECIMAL(18, 2) DEFAULT 0,
    stage3_ecl DECIMAL(18, 2) DEFAULT 0,

    -- Total
    total_ecl DECIMAL(18, 2) NOT NULL,
    ecl_coverage_ratio DECIMAL(5, 2) GENERATED ALWAYS AS (
        CASE WHEN gross_carrying_amount > 0
             THEN ROUND(total_ecl / gross_carrying_amount * 100, 2)
             ELSE 0 END
    ) STORED,

    -- Movement
    opening_provision DECIMAL(18, 2) NOT NULL DEFAULT 0,
    provision_charge DECIMAL(18, 2) GENERATED ALWAYS AS (total_ecl - opening_provision) STORED,

    -- Detail by aging bucket (JSON)
    aging_detail JSONB,

    -- Status
    is_posted BOOLEAN NOT NULL DEFAULT FALSE,
    journal_entry_id BIGINT,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_ecl_calculation UNIQUE (entity_id, model_id, period_end)
);

CREATE INDEX idx_ecl_calc_entity ON sys.ecl_calculations(entity_id);
CREATE INDEX idx_ecl_calc_date ON sys.ecl_calculations(period_end);

COMMENT ON TABLE sys.ecl_calculations IS 'IFRS 9 ECL calculation results';

-- ============================================================================
-- 6. IAS 36 — IMPAIRMENT TESTING
-- ============================================================================

CREATE TABLE IF NOT EXISTS sys.impairment_tests (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),

    -- Asset/CGU identification
    test_type VARCHAR(30) NOT NULL,         -- ASSET, CGU (Cash-Generating Unit)
    asset_id BIGINT,                        -- If single asset
    cgu_name VARCHAR(200),                  -- If CGU
    description TEXT,

    -- Test date
    test_date DATE NOT NULL,
    trigger_indicator sys.impairment_indicator,

    -- Carrying amount
    carrying_amount DECIMAL(18, 2) NOT NULL,

    -- Recoverable amount (higher of)
    fair_value_less_costs DECIMAL(18, 2),
    value_in_use DECIMAL(18, 2),
    recoverable_amount DECIMAL(18, 2) GENERATED ALWAYS AS (
        GREATEST(COALESCE(fair_value_less_costs, 0), COALESCE(value_in_use, 0))
    ) STORED,

    -- Impairment
    impairment_loss DECIMAL(18, 2) GENERATED ALWAYS AS (
        GREATEST(carrying_amount - GREATEST(COALESCE(fair_value_less_costs, 0), COALESCE(value_in_use, 0)), 0)
    ) STORED,

    -- VIU assumptions (JSON)
    viu_assumptions JSONB,                  -- discount_rate, growth_rate, projections

    -- Result
    is_impaired BOOLEAN GENERATED ALWAYS AS (
        carrying_amount > GREATEST(COALESCE(fair_value_less_costs, 0), COALESCE(value_in_use, 0))
    ) STORED,

    -- Posting
    is_posted BOOLEAN NOT NULL DEFAULT FALSE,
    journal_entry_id BIGINT,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    version_number INT NOT NULL DEFAULT 1
);

CREATE INDEX idx_impairment_entity ON sys.impairment_tests(entity_id);
CREATE INDEX idx_impairment_date ON sys.impairment_tests(test_date);

COMMENT ON TABLE sys.impairment_tests IS 'IAS 36 impairment testing records';

-- ============================================================================
-- 7. RPC FUNCTIONS
-- ============================================================================

-- 7.1 Calculate IFRS 15 Revenue Recognition
CREATE OR REPLACE FUNCTION sys.rpc_recognize_revenue(
    p_contract_id BIGINT,
    p_recognition_date DATE,
    p_completion_percentage DECIMAL(5, 2) DEFAULT NULL
)
RETURNS TABLE (
    obligation_id BIGINT,
    recognized_amount DECIMAL(18, 2),
    cumulative_amount DECIMAL(18, 2)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_contract RECORD;
    v_obligation RECORD;
    v_new_amount DECIMAL(18, 2);
    v_cumulative DECIMAL(18, 2);
BEGIN
    -- Get contract
    SELECT * INTO v_contract FROM sys.revenue_contracts WHERE id = p_contract_id;

    IF v_contract IS NULL THEN
        RAISE EXCEPTION 'Contract not found: %', p_contract_id;
    END IF;

    -- Process each unsatisfied obligation
    FOR v_obligation IN (
        SELECT * FROM sys.performance_obligations
        WHERE contract_id = p_contract_id AND NOT is_satisfied
        ORDER BY obligation_number
    ) LOOP
        -- Calculate based on method
        CASE v_obligation.recognition_method
            WHEN 'POINT_IN_TIME' THEN
                -- Full recognition on satisfaction
                IF p_completion_percentage >= 100 THEN
                    v_new_amount := v_obligation.allocated_price - v_obligation.recognized_amount;
                ELSE
                    v_new_amount := 0;
                END IF;

            WHEN 'OVER_TIME_OUTPUT', 'OVER_TIME_INPUT', 'POC' THEN
                -- Progressive recognition
                v_cumulative := v_obligation.allocated_price * COALESCE(p_completion_percentage, v_obligation.completion_percentage) / 100;
                v_new_amount := v_cumulative - v_obligation.recognized_amount;
        END CASE;

        IF v_new_amount > 0 THEN
            -- Update obligation
            UPDATE sys.performance_obligations
            SET recognized_amount = recognized_amount + v_new_amount,
                completion_percentage = COALESCE(p_completion_percentage, completion_percentage),
                is_satisfied = (COALESCE(p_completion_percentage, completion_percentage) >= 100)
            WHERE id = v_obligation.id;

            -- Record event
            INSERT INTO sys.revenue_recognition_events (
                contract_id, obligation_id, event_date, event_type,
                recognized_amount, cumulative_amount,
                completion_before, completion_after
            ) VALUES (
                p_contract_id, v_obligation.id, p_recognition_date, 'RECOGNITION',
                v_new_amount, v_obligation.recognized_amount + v_new_amount,
                v_obligation.completion_percentage, COALESCE(p_completion_percentage, v_obligation.completion_percentage)
            );

            RETURN QUERY SELECT v_obligation.id, v_new_amount, v_obligation.recognized_amount + v_new_amount;
        END IF;
    END LOOP;

    -- Update contract totals
    UPDATE sys.revenue_contracts
    SET recognized_revenue = (
            SELECT COALESCE(SUM(recognized_amount), 0) FROM sys.performance_obligations WHERE contract_id = p_contract_id
        ),
        completion_percentage = (
            SELECT COALESCE(AVG(completion_percentage), 0) FROM sys.performance_obligations WHERE contract_id = p_contract_id
        ),
        updated_at = NOW()
    WHERE id = p_contract_id;
END;
$$;

COMMENT ON FUNCTION sys.rpc_recognize_revenue IS 'IFRS 15 revenue recognition for a contract';

-- 7.2 Calculate IFRS 16 Lease
CREATE OR REPLACE FUNCTION sys.rpc_calculate_lease_schedule(
    p_lease_id BIGINT
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_lease RECORD;
    v_period INT := 1;
    v_current_date DATE;
    v_period_end DATE;
    v_payment_date DATE;
    v_liability DECIMAL(18, 2);
    v_rou_asset DECIMAL(18, 2);
    v_interest DECIMAL(18, 2);
    v_principal DECIMAL(18, 2);
    v_depreciation DECIMAL(18, 2);
    v_monthly_rate DECIMAL(12, 10);
    v_total_periods INT;
BEGIN
    -- Get lease
    SELECT * INTO v_lease FROM sys.lease_contracts WHERE id = p_lease_id;

    IF v_lease IS NULL THEN
        RAISE EXCEPTION 'Lease not found: %', p_lease_id;
    END IF;

    -- Clear existing schedule
    DELETE FROM sys.lease_payment_schedule WHERE lease_id = p_lease_id;

    -- Initialize
    v_liability := v_lease.lease_liability_initial;
    v_rou_asset := v_lease.rou_asset_initial;
    v_monthly_rate := v_lease.discount_rate / 12 / 100;
    v_total_periods := v_lease.lease_term_months;
    v_depreciation := v_lease.rou_asset_initial / v_total_periods;
    v_current_date := v_lease.commencement_date;

    -- Generate schedule
    WHILE v_period <= v_total_periods AND v_liability > 0.01 LOOP
        v_period_end := v_current_date + INTERVAL '1 month' - INTERVAL '1 day';
        v_payment_date := CASE v_lease.payment_timing
                              WHEN 'BEGIN' THEN v_current_date
                              ELSE v_period_end END;

        -- Calculate interest and principal
        v_interest := ROUND(v_liability * v_monthly_rate, 2);
        v_principal := v_lease.monthly_payment - v_interest;

        -- Insert schedule row
        INSERT INTO sys.lease_payment_schedule (
            lease_id, period_number, period_start_date, period_end_date,
            payment_amount, payment_date, interest_expense, principal_repayment,
            opening_liability, closing_liability,
            depreciation_expense, opening_rou_asset, closing_rou_asset
        ) VALUES (
            p_lease_id, v_period, v_current_date, v_period_end,
            v_lease.monthly_payment, v_payment_date, v_interest, v_principal,
            v_liability, v_liability - v_principal,
            v_depreciation, v_rou_asset, v_rou_asset - v_depreciation
        );

        -- Update for next period
        v_liability := v_liability - v_principal;
        v_rou_asset := v_rou_asset - v_depreciation;
        v_current_date := v_current_date + INTERVAL '1 month';
        v_period := v_period + 1;
    END LOOP;

    RETURN v_period - 1;
END;
$$;

COMMENT ON FUNCTION sys.rpc_calculate_lease_schedule IS 'Generate IFRS 16 lease amortization schedule';

-- 7.3 Calculate ECL
CREATE OR REPLACE FUNCTION sys.rpc_calculate_ecl(
    p_entity_id BIGINT,
    p_model_id BIGINT,
    p_period_end DATE
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_tenant_id BIGINT;
    v_model RECORD;
    v_calc_id BIGINT;
    v_gross_amount DECIMAL(18, 2);
    v_total_ecl DECIMAL(18, 2) := 0;
    v_opening DECIMAL(18, 2);
    v_aging_detail JSONB := '[]';
BEGIN
    -- Get model
    SELECT * INTO v_model FROM sys.ecl_models WHERE id = p_model_id;

    IF v_model IS NULL THEN
        RAISE EXCEPTION 'ECL model not found: %', p_model_id;
    END IF;

    v_tenant_id := v_model.tenant_id;

    -- Get gross carrying amount (would query receivables/loans)
    -- Simplified: use placeholder
    v_gross_amount := 0;

    -- Apply provision matrix (simplified approach)
    IF v_model.methodology = 'SIMPLIFIED' AND v_model.provision_matrix IS NOT NULL THEN
        -- Apply rates from provision matrix
        -- Example: {"0-30": 0.5, "31-60": 2, "61-90": 5, "91-180": 15, "180+": 50}
        v_total_ecl := v_gross_amount * 0.02;  -- Placeholder 2%
    END IF;

    -- Get opening provision
    SELECT COALESCE(total_ecl, 0) INTO v_opening
    FROM sys.ecl_calculations
    WHERE entity_id = p_entity_id
      AND model_id = p_model_id
      AND period_end < p_period_end
    ORDER BY period_end DESC
    LIMIT 1;

    -- Create calculation record
    INSERT INTO sys.ecl_calculations (
        tenant_id, entity_id, model_id, calculation_date, period_end,
        gross_carrying_amount, total_ecl, opening_provision, aging_detail
    ) VALUES (
        v_tenant_id, p_entity_id, p_model_id, CURRENT_DATE, p_period_end,
        v_gross_amount, v_total_ecl, COALESCE(v_opening, 0), v_aging_detail
    )
    RETURNING id INTO v_calc_id;

    RETURN v_calc_id;
END;
$$;

COMMENT ON FUNCTION sys.rpc_calculate_ecl IS 'Calculate IFRS 9 expected credit loss';

-- ============================================================================
-- 8. VIEWS
-- ============================================================================

-- 8.1 Revenue contracts summary
CREATE OR REPLACE VIEW sys.v_revenue_contracts_summary AS
SELECT
    rc.entity_id,
    te.entity_name,
    rc.status,
    COUNT(*) AS contract_count,
    SUM(rc.total_contract_value) AS total_value,
    SUM(rc.recognized_revenue) AS recognized,
    SUM(rc.deferred_revenue) AS deferred,
    AVG(rc.completion_percentage) AS avg_completion
FROM sys.revenue_contracts rc
JOIN sys.tenant_entities te ON te.id = rc.entity_id
WHERE rc.deleted_at IS NULL
GROUP BY rc.entity_id, te.entity_name, rc.status;

COMMENT ON VIEW sys.v_revenue_contracts_summary IS 'IFRS 15 revenue contracts summary by entity';

-- 8.2 Lease portfolio summary
CREATE OR REPLACE VIEW sys.v_lease_portfolio AS
SELECT
    lc.entity_id,
    te.entity_name,
    lc.lease_type,
    COUNT(*) AS lease_count,
    SUM(lc.lease_liability_current) AS total_liability,
    SUM(lc.rou_asset_current) AS total_rou_assets,
    SUM(lc.monthly_payment * 12) AS annual_payments
FROM sys.lease_contracts lc
JOIN sys.tenant_entities te ON te.id = lc.entity_id
WHERE lc.status = 'ACTIVE' AND lc.deleted_at IS NULL
GROUP BY lc.entity_id, te.entity_name, lc.lease_type;

COMMENT ON VIEW sys.v_lease_portfolio IS 'IFRS 16 lease portfolio summary';

-- 8.3 ECL summary
CREATE OR REPLACE VIEW sys.v_ecl_summary AS
SELECT
    ec.entity_id,
    te.entity_name,
    em.portfolio_type,
    ec.period_end,
    ec.gross_carrying_amount,
    ec.total_ecl,
    ec.ecl_coverage_ratio,
    ec.provision_charge
FROM sys.ecl_calculations ec
JOIN sys.tenant_entities te ON te.id = ec.entity_id
JOIN sys.ecl_models em ON em.id = ec.model_id
WHERE ec.period_end = (
    SELECT MAX(period_end) FROM sys.ecl_calculations WHERE entity_id = ec.entity_id
);

COMMENT ON VIEW sys.v_ecl_summary IS 'IFRS 9 ECL summary by entity';

-- ============================================================================
-- 9. SEED DATA
-- ============================================================================

-- Default ECL provision matrix for trade receivables
-- This would typically be inserted per tenant

COMMENT ON SCHEMA sys IS 'EdenFin System Schema - SAPHIR IFRS Compliance Extension';
