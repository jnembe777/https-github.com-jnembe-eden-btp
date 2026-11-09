-- ============================================================================
-- Fix déploiement (Sprint 1) : FK -> common.currencies(code) (et non currency_code,
-- colonne inexistante). ROLLBACK : rétablir common.currencies(currency_code) si
-- la colonne de référence est renommée. Voir SPRINT1_GAMMES_BUILD.md.
-- EdenFin ONYX - Module 02: Treasury Management
-- ============================================================================
-- Version: 1.0.0
-- Date: 2026-02-11
-- Description: Advanced treasury management - cash pooling, FX hedging,
--              netting, forecasting, bank connectivity
-- Dependencies: JASPE (00-09), RUBIS (01-03), SAPHIR (01-05), ONYX (01)
-- ============================================================================

-- ============================================================================
-- SECTION 1: ENUMS
-- ============================================================================

-- Cash pool types
CREATE TYPE sys.cash_pool_type AS ENUM (
    'NOTIONAL',         -- Interest optimization only, no physical movements
    'PHYSICAL',         -- ZBA (Zero Balance Account) - actual sweeps
    'HYBRID',           -- Combination of both
    'TARGET_BALANCE',   -- Maintain target balance in each account
    'THRESHOLD'         -- Sweep when threshold exceeded
);

-- Cash flow categories (IAS 7)
CREATE TYPE sys.cash_flow_category AS ENUM (
    'OPERATING',        -- Day-to-day business activities
    'INVESTING',        -- CapEx, acquisitions, disposals
    'FINANCING'         -- Debt, equity, dividends
);

-- Cash forecast sources
CREATE TYPE sys.forecast_source AS ENUM (
    'MANUAL',           -- User entered
    'AR_AGING',         -- From accounts receivable
    'AP_AGING',         -- From accounts payable
    'BUDGET',           -- From budget module
    'ML_PREDICTED',     -- Machine learning prediction
    'RECURRING',        -- Recurring pattern
    'CONTRACT'          -- Contract-based (leases, loans)
);

-- Hedge instrument types
CREATE TYPE sys.hedge_instrument_type AS ENUM (
    'FORWARD',          -- FX Forward contract
    'OPTION_CALL',      -- Call option
    'OPTION_PUT',       -- Put option
    'SWAP',             -- Currency swap
    'COLLAR',           -- Collar (cap + floor)
    'NDF',              -- Non-deliverable forward
    'CROSS_CURRENCY_SWAP'
);

-- Hedge relationship types (IFRS 9)
CREATE TYPE sys.hedge_relationship_type AS ENUM (
    'CASH_FLOW',        -- Hedge of cash flow variability
    'FAIR_VALUE',       -- Hedge of fair value changes
    'NET_INVESTMENT'    -- Hedge of net investment in foreign operation
);

-- Hedge status
CREATE TYPE sys.hedge_status AS ENUM (
    'DRAFT',            -- Being prepared
    'DESIGNATED',       -- Designated as hedge
    'ACTIVE',           -- Currently in effect
    'MATURED',          -- Reached maturity
    'TERMINATED',       -- Early termination
    'DE_DESIGNATED'     -- No longer qualifies
);

-- Bank connection protocols
CREATE TYPE sys.bank_protocol AS ENUM (
    'SWIFT',            -- SWIFT MT messages
    'EBICS',            -- EBICS (European)
    'HOST_TO_HOST',     -- Direct connection
    'API',              -- Open Banking API
    'SFTP',             -- File transfer
    'ISO20022',         -- ISO 20022 messages
    'MANUAL'            -- Manual import
);

-- Bank message types
CREATE TYPE sys.bank_message_type AS ENUM (
    -- Payments
    'MT101',            -- Request for Transfer
    'MT103',            -- Single Customer Credit Transfer
    'MT202',            -- General Financial Institution Transfer
    'PAIN001',          -- ISO20022 Payment Initiation
    -- Statements
    'MT940',            -- Customer Statement
    'MT942',            -- Interim Transaction Report
    'CAMT052',          -- ISO20022 Bank to Customer Report
    'CAMT053',          -- ISO20022 Bank to Customer Statement
    'CAMT054'           -- ISO20022 Bank to Customer Debit/Credit Notification
);

-- Netting run status
CREATE TYPE sys.netting_status AS ENUM (
    'DRAFT',            -- Being prepared
    'PROPOSED',         -- Sent to participants
    'CONFIRMED',        -- All parties confirmed
    'SETTLED',          -- Settlement complete
    'CANCELLED'         -- Cancelled
);

-- Sweep frequency
CREATE TYPE sys.sweep_frequency AS ENUM (
    'INTRADAY',         -- Multiple times per day
    'DAILY',            -- End of day
    'WEEKLY',           -- Once per week
    'MONTHLY',          -- Month end
    'ON_DEMAND'         -- Manual trigger
);

-- ============================================================================
-- SECTION 2: CASH POOLING TABLES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 2.1 Cash Pool Structures
-- ----------------------------------------------------------------------------
CREATE TABLE sys.cash_pools (
    pool_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pool_code VARCHAR(20) NOT NULL,
    pool_name VARCHAR(100) NOT NULL,
    pool_type sys.cash_pool_type NOT NULL DEFAULT 'NOTIONAL',

    -- Header/master account entity
    header_entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(entity_id),
    header_bank_account_id BIGINT REFERENCES client_demo.bank_accounts(bank_account_id),

    -- Pool currency
    pool_currency VARCHAR(3) NOT NULL REFERENCES common.currencies(code),

    -- Interest configuration (for notional pooling)
    interest_calculation_method VARCHAR(20) DEFAULT 'DAILY_BALANCE',  -- DAILY_BALANCE, TIERED
    credit_interest_rate DECIMAL(8,4),      -- Interest paid on credit balances
    debit_interest_rate DECIMAL(8,4),       -- Interest charged on debit balances
    interest_spread DECIMAL(8,4),           -- Spread over/under base rate
    base_rate_reference VARCHAR(50),        -- EURIBOR, SOFR, etc.

    -- Physical pooling configuration
    sweep_frequency sys.sweep_frequency DEFAULT 'DAILY',
    target_balance DECIMAL(18,2) DEFAULT 0,
    minimum_sweep_amount DECIMAL(18,2) DEFAULT 0,

    -- Settings
    allow_overdraft BOOLEAN DEFAULT FALSE,
    overdraft_limit DECIMAL(18,2),

    -- Validity
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE,

    -- Status
    is_active BOOLEAN DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,

    UNIQUE (pool_code)
);

CREATE INDEX idx_cash_pools_header_entity ON sys.cash_pools(header_entity_id);
CREATE INDEX idx_cash_pools_active ON sys.cash_pools(is_active) WHERE is_active = TRUE;

COMMENT ON TABLE sys.cash_pools IS 'Cash pool structures for notional and physical pooling';

-- ----------------------------------------------------------------------------
-- 2.2 Cash Pool Members
-- ----------------------------------------------------------------------------
CREATE TABLE sys.cash_pool_members (
    member_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pool_id BIGINT NOT NULL REFERENCES sys.cash_pools(pool_id) ON DELETE CASCADE,
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(entity_id),
    bank_account_id BIGINT REFERENCES client_demo.bank_accounts(bank_account_id),

    -- Member role
    is_header BOOLEAN DEFAULT FALSE,

    -- Interest allocation
    interest_allocation_method VARCHAR(20) DEFAULT 'PRO_RATA',  -- PRO_RATA, FIXED, TIERED
    interest_allocation_percentage DECIMAL(5,2),

    -- Sweep rules (for physical pooling)
    sweep_direction VARCHAR(10) DEFAULT 'BOTH',  -- TO_HEADER, FROM_HEADER, BOTH
    target_balance DECIMAL(18,2) DEFAULT 0,
    minimum_balance DECIMAL(18,2) DEFAULT 0,
    maximum_balance DECIMAL(18,2),

    -- Limits
    contribution_limit DECIMAL(18,2),
    withdrawal_limit DECIMAL(18,2),

    -- Validity
    joined_date DATE NOT NULL DEFAULT CURRENT_DATE,
    left_date DATE,

    -- Status
    is_active BOOLEAN DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,

    UNIQUE (pool_id, entity_id, bank_account_id)
);

CREATE INDEX idx_cash_pool_members_pool ON sys.cash_pool_members(pool_id);
CREATE INDEX idx_cash_pool_members_entity ON sys.cash_pool_members(entity_id);

COMMENT ON TABLE sys.cash_pool_members IS 'Entities/accounts participating in cash pools';

-- ----------------------------------------------------------------------------
-- 2.3 Sweep Instructions
-- ----------------------------------------------------------------------------
CREATE TABLE sys.sweep_instructions (
    instruction_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pool_id BIGINT NOT NULL REFERENCES sys.cash_pools(pool_id),
    member_id BIGINT NOT NULL REFERENCES sys.cash_pool_members(member_id),

    -- Sweep configuration
    sweep_type VARCHAR(20) NOT NULL DEFAULT 'ZBA',  -- ZBA, TBA (Target Balance), THRESHOLD
    sweep_priority INT DEFAULT 1,  -- Lower = higher priority

    -- Thresholds
    trigger_balance DECIMAL(18,2),      -- Balance that triggers sweep
    target_balance DECIMAL(18,2),       -- Balance to achieve
    minimum_sweep DECIMAL(18,2),        -- Don't sweep below this amount
    maximum_sweep DECIMAL(18,2),        -- Cap on single sweep

    -- Timing
    sweep_frequency sys.sweep_frequency DEFAULT 'DAILY',
    sweep_time TIME,                    -- Preferred time for sweep
    sweep_days VARCHAR(20),             -- 'MON,TUE,WED,THU,FRI' or 'ALL'

    -- Status
    is_active BOOLEAN DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,

    UNIQUE (pool_id, member_id)
);

COMMENT ON TABLE sys.sweep_instructions IS 'Rules for automatic cash sweeps';

-- ============================================================================
-- SECTION 3: CASH FORECASTING
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 3.1 Cash Forecasts
-- ----------------------------------------------------------------------------
CREATE TABLE sys.cash_forecasts (
    forecast_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(entity_id),
    bank_account_id BIGINT REFERENCES client_demo.bank_accounts(bank_account_id),

    -- Timing
    forecast_date DATE NOT NULL,
    forecast_week INT GENERATED ALWAYS AS (EXTRACT(WEEK FROM forecast_date)) STORED,
    forecast_month INT GENERATED ALWAYS AS (EXTRACT(MONTH FROM forecast_date)) STORED,

    -- Classification
    category sys.cash_flow_category NOT NULL,
    subcategory VARCHAR(50),            -- e.g., 'Customer Collections', 'Supplier Payments'
    description VARCHAR(200),

    -- Currency
    currency_code VARCHAR(3) NOT NULL REFERENCES common.currencies(code),

    -- Amounts
    amount_forecast DECIMAL(18,2) NOT NULL,
    amount_actual DECIMAL(18,2),
    variance DECIMAL(18,2) GENERATED ALWAYS AS (amount_actual - amount_forecast) STORED,
    variance_pct DECIMAL(8,2) GENERATED ALWAYS AS (
        CASE WHEN amount_forecast <> 0
             THEN ((amount_actual - amount_forecast) / ABS(amount_forecast)) * 100
             ELSE NULL
        END
    ) STORED,

    -- Confidence
    confidence_level DECIMAL(5,2),      -- 0-100%
    scenario VARCHAR(20) DEFAULT 'BASE', -- BASE, OPTIMISTIC, PESSIMISTIC

    -- Source
    source sys.forecast_source NOT NULL DEFAULT 'MANUAL',
    source_document_id BIGINT,          -- Reference to source (invoice, PO, etc.)
    source_document_type VARCHAR(50),

    -- Status
    is_locked BOOLEAN DEFAULT FALSE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT
);

CREATE INDEX idx_cash_forecasts_entity_date ON sys.cash_forecasts(entity_id, forecast_date);
CREATE INDEX idx_cash_forecasts_category ON sys.cash_forecasts(category);
CREATE INDEX idx_cash_forecasts_date_range ON sys.cash_forecasts(forecast_date);

COMMENT ON TABLE sys.cash_forecasts IS 'Cash flow forecasts for liquidity planning';

-- ----------------------------------------------------------------------------
-- 3.2 Forecast Snapshots (for historical comparison)
-- ----------------------------------------------------------------------------
CREATE TABLE sys.cash_forecast_snapshots (
    snapshot_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(entity_id),
    snapshot_date DATE NOT NULL DEFAULT CURRENT_DATE,
    snapshot_name VARCHAR(100),

    -- Aggregated data
    forecast_horizon_days INT NOT NULL,
    total_inflows DECIMAL(18,2) NOT NULL,
    total_outflows DECIMAL(18,2) NOT NULL,
    net_position DECIMAL(18,2) GENERATED ALWAYS AS (total_inflows - total_outflows) STORED,

    -- Detail stored as JSONB
    forecast_detail JSONB NOT NULL,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0
);

CREATE INDEX idx_forecast_snapshots_entity ON sys.cash_forecast_snapshots(entity_id, snapshot_date);

COMMENT ON TABLE sys.cash_forecast_snapshots IS 'Point-in-time snapshots of cash forecasts';

-- ============================================================================
-- SECTION 4: FX HEDGING
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 4.1 FX Hedges
-- ----------------------------------------------------------------------------
CREATE TABLE sys.fx_hedges (
    hedge_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    hedge_reference VARCHAR(50) NOT NULL,
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(entity_id),

    -- Instrument details
    instrument_type sys.hedge_instrument_type NOT NULL,
    hedge_relationship sys.hedge_relationship_type,

    -- Counterparty
    counterparty_bank VARCHAR(100) NOT NULL,
    counterparty_bank_swift VARCHAR(11),
    deal_reference VARCHAR(50),         -- Bank's reference

    -- Currency pair
    buy_currency VARCHAR(3) NOT NULL REFERENCES common.currencies(code),
    sell_currency VARCHAR(3) NOT NULL REFERENCES common.currencies(code),

    -- Amounts
    notional_amount DECIMAL(18,2) NOT NULL,
    notional_currency VARCHAR(3) NOT NULL REFERENCES common.currencies(code),

    -- Rates
    strike_rate DECIMAL(18,8) NOT NULL,         -- Contracted rate
    spot_rate_at_inception DECIMAL(18,8),       -- Spot rate when deal was made
    current_forward_points DECIMAL(18,8),

    -- For options
    premium_amount DECIMAL(18,2),
    premium_currency VARCHAR(3) REFERENCES common.currencies(code),
    premium_paid_date DATE,
    option_style VARCHAR(10),           -- EUROPEAN, AMERICAN

    -- Dates
    trade_date DATE NOT NULL,
    value_date DATE,                    -- Settlement date for forwards
    maturity_date DATE NOT NULL,
    early_termination_date DATE,

    -- Underlying exposure
    underlying_exposure_type VARCHAR(50),       -- FORECAST_SALE, COMMITMENT, etc.
    underlying_exposure_id BIGINT,
    underlying_exposure_amount DECIMAL(18,2),
    underlying_exposure_currency VARCHAR(3) REFERENCES common.currencies(code),

    -- Valuation
    fair_value DECIMAL(18,2),
    fair_value_date DATE,
    fair_value_currency VARCHAR(3) REFERENCES common.currencies(code),
    mtm_gain_loss DECIMAL(18,2),        -- Mark-to-market

    -- Hedge accounting (IFRS 9)
    is_designated BOOLEAN DEFAULT FALSE,
    designation_date DATE,
    effectiveness_test_method VARCHAR(50),      -- DOLLAR_OFFSET, REGRESSION

    -- Status
    status sys.hedge_status NOT NULL DEFAULT 'DRAFT',

    -- Settlement
    settlement_method VARCHAR(20) DEFAULT 'GROSS',  -- GROSS, NET
    settlement_amount DECIMAL(18,2),
    settlement_date DATE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,

    UNIQUE (hedge_reference)
);

CREATE INDEX idx_fx_hedges_entity ON sys.fx_hedges(entity_id);
CREATE INDEX idx_fx_hedges_status ON sys.fx_hedges(status);
CREATE INDEX idx_fx_hedges_maturity ON sys.fx_hedges(maturity_date);
CREATE INDEX idx_fx_hedges_currencies ON sys.fx_hedges(buy_currency, sell_currency);

COMMENT ON TABLE sys.fx_hedges IS 'FX hedge instruments (forwards, options, swaps)';

-- ----------------------------------------------------------------------------
-- 4.2 Hedge Effectiveness Tests
-- ----------------------------------------------------------------------------
CREATE TABLE sys.hedge_effectiveness_tests (
    test_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    hedge_id BIGINT NOT NULL REFERENCES sys.fx_hedges(hedge_id),

    -- Test timing
    test_date DATE NOT NULL,
    test_type VARCHAR(20) NOT NULL,     -- PROSPECTIVE, RETROSPECTIVE
    test_method VARCHAR(50) NOT NULL,   -- DOLLAR_OFFSET, REGRESSION, VaR

    -- Test results
    hedge_change DECIMAL(18,2),         -- Change in hedge instrument value
    hedged_item_change DECIMAL(18,2),   -- Change in hedged item value

    -- Dollar offset method
    effectiveness_ratio DECIMAL(8,4),   -- Hedge change / Hedged item change

    -- Regression method
    r_squared DECIMAL(8,4),
    slope DECIMAL(8,4),

    -- Result
    is_effective BOOLEAN NOT NULL,
    ineffective_amount DECIMAL(18,2),   -- Amount to P&L

    -- IFRS 9 thresholds
    ratio_lower_bound DECIMAL(8,4) DEFAULT 0.80,
    ratio_upper_bound DECIMAL(8,4) DEFAULT 1.25,

    -- Documentation
    notes TEXT,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0
);

CREATE INDEX idx_hedge_tests_hedge ON sys.hedge_effectiveness_tests(hedge_id);
CREATE INDEX idx_hedge_tests_date ON sys.hedge_effectiveness_tests(test_date);

COMMENT ON TABLE sys.hedge_effectiveness_tests IS 'IFRS 9 / IAS 39 hedge effectiveness testing';

-- ============================================================================
-- SECTION 5: BANK CONNECTIVITY
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 5.1 Bank Connections
-- ----------------------------------------------------------------------------
CREATE TABLE sys.bank_connections (
    connection_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    connection_name VARCHAR(100) NOT NULL,
    bank_name VARCHAR(100) NOT NULL,
    bank_swift VARCHAR(11),

    -- Protocol
    protocol sys.bank_protocol NOT NULL DEFAULT 'SWIFT',

    -- Connection details
    host_address VARCHAR(255),
    port INT,
    endpoint_url VARCHAR(500),

    -- Authentication
    auth_method VARCHAR(50),            -- API_KEY, OAUTH2, CERTIFICATE, BASIC
    credentials_vault_ref VARCHAR(100), -- Reference to secure vault
    client_id VARCHAR(100),

    -- Certificates
    cert_subject VARCHAR(255),
    cert_expiry DATE,

    -- Message configuration
    supported_message_types sys.bank_message_type[],
    default_format VARCHAR(20) DEFAULT 'MT',  -- MT, ISO20022

    -- Retry policy
    retry_count INT DEFAULT 3,
    retry_interval_seconds INT DEFAULT 60,

    -- Timeouts
    connection_timeout_ms INT DEFAULT 30000,
    read_timeout_ms INT DEFAULT 60000,

    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    last_connection_test TIMESTAMPTZ,
    last_connection_status VARCHAR(20),

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT
);

CREATE INDEX idx_bank_connections_bank ON sys.bank_connections(bank_swift);
CREATE INDEX idx_bank_connections_active ON sys.bank_connections(is_active) WHERE is_active = TRUE;

COMMENT ON TABLE sys.bank_connections IS 'Bank connectivity configuration (SWIFT, EBICS, API)';

-- ----------------------------------------------------------------------------
-- 5.2 Bank Messages (Sent/Received)
-- ----------------------------------------------------------------------------
CREATE TABLE sys.bank_messages (
    message_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    connection_id BIGINT NOT NULL REFERENCES sys.bank_connections(connection_id),
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(entity_id),
    bank_account_id BIGINT REFERENCES client_demo.bank_accounts(bank_account_id),

    -- Direction
    direction VARCHAR(10) NOT NULL,     -- OUTBOUND, INBOUND

    -- Message details
    message_type sys.bank_message_type NOT NULL,
    message_reference VARCHAR(50) NOT NULL,
    related_reference VARCHAR(50),      -- Reference to prior message

    -- Content
    message_content TEXT,               -- Raw message
    message_parsed JSONB,               -- Parsed content

    -- Timing
    created_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sent_timestamp TIMESTAMPTZ,
    received_timestamp TIMESTAMPTZ,
    processed_timestamp TIMESTAMPTZ,

    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',  -- PENDING, SENT, RECEIVED, PROCESSED, FAILED
    error_message TEXT,
    retry_count INT DEFAULT 0,

    -- Audit
    created_by BIGINT NOT NULL DEFAULT 0
);

CREATE INDEX idx_bank_messages_connection ON sys.bank_messages(connection_id);
CREATE INDEX idx_bank_messages_entity ON sys.bank_messages(entity_id);
CREATE INDEX idx_bank_messages_status ON sys.bank_messages(status);
CREATE INDEX idx_bank_messages_date ON sys.bank_messages(created_timestamp);

COMMENT ON TABLE sys.bank_messages IS 'Bank messages sent/received via connectivity channels';

-- ============================================================================
-- SECTION 6: INTERCOMPANY NETTING
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 6.1 Netting Runs
-- ----------------------------------------------------------------------------
CREATE TABLE sys.netting_runs (
    netting_run_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    netting_reference VARCHAR(50) NOT NULL,

    -- Netting center
    netting_center_entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(entity_id),
    netting_currency VARCHAR(3) NOT NULL REFERENCES common.currencies(code),

    -- Period
    netting_date DATE NOT NULL,
    cutoff_date DATE NOT NULL,          -- Transactions up to this date
    settlement_date DATE NOT NULL,

    -- Totals
    gross_payables DECIMAL(18,2) NOT NULL DEFAULT 0,
    gross_receivables DECIMAL(18,2) NOT NULL DEFAULT 0,
    net_settlement_amount DECIMAL(18,2) GENERATED ALWAYS AS (gross_receivables - gross_payables) STORED,
    settlement_reduction_pct DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE WHEN (gross_payables + gross_receivables) > 0
             THEN (1 - (ABS(gross_receivables - gross_payables) / (gross_payables + gross_receivables))) * 100
             ELSE 0
        END
    ) STORED,

    -- Participant count
    participant_count INT DEFAULT 0,
    transaction_count INT DEFAULT 0,

    -- Status
    status sys.netting_status NOT NULL DEFAULT 'DRAFT',

    -- Confirmation tracking
    proposals_sent_at TIMESTAMPTZ,
    confirmations_due_by TIMESTAMPTZ,
    all_confirmed_at TIMESTAMPTZ,

    -- Settlement
    settlement_instructions_generated BOOLEAN DEFAULT FALSE,
    settlement_completed_at TIMESTAMPTZ,

    -- Notes
    notes TEXT,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,

    UNIQUE (netting_reference)
);

CREATE INDEX idx_netting_runs_center ON sys.netting_runs(netting_center_entity_id);
CREATE INDEX idx_netting_runs_date ON sys.netting_runs(netting_date);
CREATE INDEX idx_netting_runs_status ON sys.netting_runs(status);

COMMENT ON TABLE sys.netting_runs IS 'Intercompany netting cycles';

-- ----------------------------------------------------------------------------
-- 6.2 Netting Participants
-- ----------------------------------------------------------------------------
CREATE TABLE sys.netting_participants (
    participant_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    netting_run_id BIGINT NOT NULL REFERENCES sys.netting_runs(netting_run_id) ON DELETE CASCADE,
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(entity_id),

    -- Balances
    gross_payable DECIMAL(18,2) NOT NULL DEFAULT 0,
    gross_receivable DECIMAL(18,2) NOT NULL DEFAULT 0,
    net_position DECIMAL(18,2) GENERATED ALWAYS AS (gross_receivable - gross_payable) STORED,

    -- Settlement
    settlement_bank_account_id BIGINT REFERENCES client_demo.bank_accounts(bank_account_id),
    settlement_amount DECIMAL(18,2),    -- Positive = receive, Negative = pay

    -- Confirmation
    proposal_sent_at TIMESTAMPTZ,
    confirmed_at TIMESTAMPTZ,
    confirmed_by BIGINT,
    rejection_reason TEXT,

    -- Status
    status VARCHAR(20) DEFAULT 'PENDING',  -- PENDING, CONFIRMED, REJECTED

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_netting_participants_run ON sys.netting_participants(netting_run_id);
CREATE INDEX idx_netting_participants_entity ON sys.netting_participants(entity_id);

COMMENT ON TABLE sys.netting_participants IS 'Entities participating in a netting run';

-- ----------------------------------------------------------------------------
-- 6.3 Netting Transactions (IC transactions included in netting)
-- ----------------------------------------------------------------------------
CREATE TABLE sys.netting_transactions (
    netting_txn_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    netting_run_id BIGINT NOT NULL REFERENCES sys.netting_runs(netting_run_id) ON DELETE CASCADE,

    -- Counterparties
    debtor_entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(entity_id),
    creditor_entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(entity_id),

    -- Original transaction reference
    source_document_type VARCHAR(50),   -- INVOICE, DEBIT_NOTE, CREDIT_NOTE
    source_document_id BIGINT,
    source_document_ref VARCHAR(50),

    -- Amounts
    original_currency VARCHAR(3) NOT NULL REFERENCES common.currencies(code),
    original_amount DECIMAL(18,2) NOT NULL,
    netting_currency VARCHAR(3) NOT NULL REFERENCES common.currencies(code),
    netting_amount DECIMAL(18,2) NOT NULL,
    fx_rate DECIMAL(18,8) NOT NULL DEFAULT 1,

    -- Dates
    document_date DATE NOT NULL,
    due_date DATE NOT NULL,

    -- Status
    included_in_netting BOOLEAN DEFAULT TRUE,
    exclusion_reason VARCHAR(100),

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_netting_txn_run ON sys.netting_transactions(netting_run_id);
CREATE INDEX idx_netting_txn_debtor ON sys.netting_transactions(debtor_entity_id);
CREATE INDEX idx_netting_txn_creditor ON sys.netting_transactions(creditor_entity_id);

COMMENT ON TABLE sys.netting_transactions IS 'IC transactions included in netting runs';

-- ============================================================================
-- SECTION 7: VIEWS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 7.1 Cash Pool Summary
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW sys.v_cash_pool_summary AS
SELECT
    cp.pool_id,
    cp.pool_code,
    cp.pool_name,
    cp.pool_type,
    cp.pool_currency,
    he.entity_name AS header_entity,
    cp.credit_interest_rate,
    cp.debit_interest_rate,
    COUNT(cpm.member_id) AS member_count,
    COUNT(CASE WHEN cpm.is_active THEN 1 END) AS active_members,
    cp.is_active,
    cp.effective_from,
    cp.effective_to
FROM sys.cash_pools cp
JOIN sys.tenant_entities he ON cp.header_entity_id = he.entity_id
LEFT JOIN sys.cash_pool_members cpm ON cp.pool_id = cpm.pool_id
GROUP BY cp.pool_id, cp.pool_code, cp.pool_name, cp.pool_type, cp.pool_currency,
         he.entity_name, cp.credit_interest_rate, cp.debit_interest_rate,
         cp.is_active, cp.effective_from, cp.effective_to;

COMMENT ON VIEW sys.v_cash_pool_summary IS 'Summary of cash pool structures with member counts';

-- ----------------------------------------------------------------------------
-- 7.2 FX Hedge Portfolio
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW sys.v_fx_hedge_portfolio AS
SELECT
    h.hedge_id,
    h.hedge_reference,
    e.entity_code,
    e.entity_name,
    h.instrument_type,
    h.hedge_relationship,
    h.counterparty_bank,
    h.buy_currency,
    h.sell_currency,
    h.notional_amount,
    h.notional_currency,
    h.strike_rate,
    h.trade_date,
    h.maturity_date,
    h.maturity_date - CURRENT_DATE AS days_to_maturity,
    h.fair_value,
    h.mtm_gain_loss,
    h.is_designated,
    h.status,
    -- Latest effectiveness test
    het.test_date AS last_test_date,
    het.is_effective AS last_test_effective,
    het.effectiveness_ratio AS last_effectiveness_ratio
FROM sys.fx_hedges h
JOIN sys.tenant_entities e ON h.entity_id = e.entity_id
LEFT JOIN LATERAL (
    SELECT test_date, is_effective, effectiveness_ratio
    FROM sys.hedge_effectiveness_tests
    WHERE hedge_id = h.hedge_id
    ORDER BY test_date DESC
    LIMIT 1
) het ON TRUE;

COMMENT ON VIEW sys.v_fx_hedge_portfolio IS 'FX hedge portfolio with effectiveness status';

-- ----------------------------------------------------------------------------
-- 7.3 Cash Forecast Summary
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW sys.v_cash_forecast_summary AS
SELECT
    cf.entity_id,
    e.entity_code,
    e.entity_name,
    cf.currency_code,
    cf.forecast_date,
    cf.category,
    SUM(CASE WHEN cf.amount_forecast > 0 THEN cf.amount_forecast ELSE 0 END) AS forecast_inflows,
    SUM(CASE WHEN cf.amount_forecast < 0 THEN ABS(cf.amount_forecast) ELSE 0 END) AS forecast_outflows,
    SUM(cf.amount_forecast) AS forecast_net,
    SUM(cf.amount_actual) AS actual_net,
    SUM(cf.variance) AS total_variance,
    COUNT(*) AS line_count
FROM sys.cash_forecasts cf
JOIN sys.tenant_entities e ON cf.entity_id = e.entity_id
GROUP BY cf.entity_id, e.entity_code, e.entity_name, cf.currency_code, cf.forecast_date, cf.category;

COMMENT ON VIEW sys.v_cash_forecast_summary IS 'Aggregated cash forecast by entity, date, and category';

-- ----------------------------------------------------------------------------
-- 7.4 Netting Run Summary
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW sys.v_netting_run_summary AS
SELECT
    nr.netting_run_id,
    nr.netting_reference,
    nce.entity_code AS netting_center,
    nr.netting_currency,
    nr.netting_date,
    nr.settlement_date,
    nr.gross_payables,
    nr.gross_receivables,
    nr.net_settlement_amount,
    nr.settlement_reduction_pct,
    nr.participant_count,
    nr.transaction_count,
    nr.status,
    COUNT(CASE WHEN np.status = 'CONFIRMED' THEN 1 END) AS confirmed_count,
    COUNT(CASE WHEN np.status = 'REJECTED' THEN 1 END) AS rejected_count,
    COUNT(CASE WHEN np.status = 'PENDING' THEN 1 END) AS pending_count
FROM sys.netting_runs nr
JOIN sys.tenant_entities nce ON nr.netting_center_entity_id = nce.entity_id
LEFT JOIN sys.netting_participants np ON nr.netting_run_id = np.netting_run_id
GROUP BY nr.netting_run_id, nr.netting_reference, nce.entity_code, nr.netting_currency,
         nr.netting_date, nr.settlement_date, nr.gross_payables, nr.gross_receivables,
         nr.net_settlement_amount, nr.settlement_reduction_pct, nr.participant_count,
         nr.transaction_count, nr.status;

COMMENT ON VIEW sys.v_netting_run_summary IS 'Netting run overview with confirmation status';

-- ----------------------------------------------------------------------------
-- 7.5 Bank Connection Health
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW sys.v_bank_connection_health AS
SELECT
    bc.connection_id,
    bc.connection_name,
    bc.bank_name,
    bc.bank_swift,
    bc.protocol,
    bc.is_active,
    bc.last_connection_test,
    bc.last_connection_status,
    bc.cert_expiry,
    CASE WHEN bc.cert_expiry IS NOT NULL
         THEN bc.cert_expiry - CURRENT_DATE
         ELSE NULL
    END AS days_until_cert_expiry,
    -- Message stats (last 24 hours)
    COUNT(bm.message_id) FILTER (WHERE bm.created_timestamp > NOW() - INTERVAL '24 hours') AS messages_24h,
    COUNT(bm.message_id) FILTER (WHERE bm.created_timestamp > NOW() - INTERVAL '24 hours' AND bm.status = 'FAILED') AS failures_24h
FROM sys.bank_connections bc
LEFT JOIN sys.bank_messages bm ON bc.connection_id = bm.connection_id
GROUP BY bc.connection_id, bc.connection_name, bc.bank_name, bc.bank_swift,
         bc.protocol, bc.is_active, bc.last_connection_test, bc.last_connection_status,
         bc.cert_expiry;

COMMENT ON VIEW sys.v_bank_connection_health IS 'Bank connection status and health metrics';

-- ============================================================================
-- SECTION 8: RPC FUNCTIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 8.1 Run Cash Pool Sweep
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sys.rpc_run_cash_pool_sweep(
    p_pool_id BIGINT,
    p_sweep_date DATE DEFAULT CURRENT_DATE,
    p_user_id BIGINT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pool RECORD;
    v_member RECORD;
    v_header_balance DECIMAL(18,2);
    v_member_balance DECIMAL(18,2);
    v_sweep_amount DECIMAL(18,2);
    v_sweeps JSONB := '[]';
    v_total_swept DECIMAL(18,2) := 0;
    v_sweep_count INT := 0;
BEGIN
    -- Get pool configuration
    SELECT * INTO v_pool FROM sys.cash_pools WHERE pool_id = p_pool_id AND is_active = TRUE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Cash pool not found or inactive'
        );
    END IF;

    -- Only physical or hybrid pools can be swept
    IF v_pool.pool_type NOT IN ('PHYSICAL', 'HYBRID', 'TARGET_BALANCE', 'THRESHOLD') THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Cash pool type does not support sweeping'
        );
    END IF;

    -- Process each member
    FOR v_member IN
        SELECT cpm.*, si.target_balance AS sweep_target, si.minimum_sweep, si.maximum_sweep
        FROM sys.cash_pool_members cpm
        LEFT JOIN sys.sweep_instructions si ON cpm.member_id = si.member_id
        WHERE cpm.pool_id = p_pool_id
          AND cpm.is_active = TRUE
          AND cpm.is_header = FALSE
        ORDER BY si.sweep_priority NULLS LAST
    LOOP
        -- In a real implementation, get current balance from bank account
        -- Here we simulate with a placeholder
        v_member_balance := 0;  -- Would fetch from client_demo.bank_accounts (soldes calculés)

        -- Calculate sweep amount based on target balance
        v_sweep_amount := v_member_balance - COALESCE(v_member.sweep_target, v_pool.target_balance);

        -- Apply minimum/maximum constraints
        IF ABS(v_sweep_amount) < COALESCE(v_member.minimum_sweep, v_pool.minimum_sweep_amount) THEN
            v_sweep_amount := 0;
        END IF;

        IF v_member.maximum_sweep IS NOT NULL AND ABS(v_sweep_amount) > v_member.maximum_sweep THEN
            v_sweep_amount := SIGN(v_sweep_amount) * v_member.maximum_sweep;
        END IF;

        -- Record sweep if amount > 0
        IF v_sweep_amount <> 0 THEN
            v_sweeps := v_sweeps || jsonb_build_object(
                'member_id', v_member.member_id,
                'entity_id', v_member.entity_id,
                'bank_account_id', v_member.bank_account_id,
                'sweep_amount', v_sweep_amount,
                'direction', CASE WHEN v_sweep_amount > 0 THEN 'TO_HEADER' ELSE 'FROM_HEADER' END
            );
            v_total_swept := v_total_swept + ABS(v_sweep_amount);
            v_sweep_count := v_sweep_count + 1;
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', TRUE,
        'pool_id', p_pool_id,
        'sweep_date', p_sweep_date,
        'total_swept', v_total_swept,
        'sweep_count', v_sweep_count,
        'sweeps', v_sweeps
    );
END;
$$;

COMMENT ON FUNCTION sys.rpc_run_cash_pool_sweep IS 'Execute cash pool sweep for physical pooling';

-- ----------------------------------------------------------------------------
-- 8.2 Generate Cash Forecast
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sys.rpc_generate_cash_forecast(
    p_entity_id BIGINT,
    p_horizon_days INT DEFAULT 90,
    p_start_date DATE DEFAULT CURRENT_DATE,
    p_user_id BIGINT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_entity RECORD;
    v_forecast_date DATE;
    v_ar_forecast DECIMAL(18,2);
    v_ap_forecast DECIMAL(18,2);
    v_forecast_count INT := 0;
BEGIN
    -- Validate entity
    SELECT * INTO v_entity FROM sys.tenant_entities WHERE entity_id = p_entity_id AND is_active = TRUE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Entity not found or inactive'
        );
    END IF;

    -- Generate forecasts for each day in horizon
    FOR i IN 0..(p_horizon_days - 1) LOOP
        v_forecast_date := p_start_date + i;

        -- AR-based forecast (customer collections)
        -- In real implementation, this would analyze AR aging
        INSERT INTO sys.cash_forecasts (
            entity_id, forecast_date, category, subcategory,
            currency_code, amount_forecast, source
        )
        VALUES (
            p_entity_id, v_forecast_date, 'OPERATING', 'Customer Collections',
            v_entity.functional_currency, 0, 'AR_AGING'
        )
        ON CONFLICT DO NOTHING;

        -- AP-based forecast (supplier payments)
        INSERT INTO sys.cash_forecasts (
            entity_id, forecast_date, category, subcategory,
            currency_code, amount_forecast, source
        )
        VALUES (
            p_entity_id, v_forecast_date, 'OPERATING', 'Supplier Payments',
            v_entity.functional_currency, 0, 'AP_AGING'
        )
        ON CONFLICT DO NOTHING;

        v_forecast_count := v_forecast_count + 2;
    END LOOP;

    RETURN jsonb_build_object(
        'success', TRUE,
        'entity_id', p_entity_id,
        'horizon_days', p_horizon_days,
        'start_date', p_start_date,
        'end_date', p_start_date + p_horizon_days - 1,
        'forecasts_generated', v_forecast_count
    );
END;
$$;

COMMENT ON FUNCTION sys.rpc_generate_cash_forecast IS 'Generate cash flow forecasts from AR/AP aging';

-- ----------------------------------------------------------------------------
-- 8.3 Calculate Hedge Effectiveness
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sys.rpc_calculate_hedge_effectiveness(
    p_hedge_id BIGINT,
    p_test_date DATE DEFAULT CURRENT_DATE,
    p_user_id BIGINT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_hedge RECORD;
    v_hedge_change DECIMAL(18,2);
    v_hedged_item_change DECIMAL(18,2);
    v_effectiveness_ratio DECIMAL(8,4);
    v_is_effective BOOLEAN;
    v_ineffective_amount DECIMAL(18,2);
    v_test_id BIGINT;
BEGIN
    -- Get hedge details
    SELECT * INTO v_hedge FROM sys.fx_hedges WHERE hedge_id = p_hedge_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Hedge not found'
        );
    END IF;

    IF NOT v_hedge.is_designated THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Hedge is not designated for hedge accounting'
        );
    END IF;

    -- Calculate changes (simplified - would use actual market data)
    -- Change in hedge instrument value
    v_hedge_change := COALESCE(v_hedge.fair_value, 0) - COALESCE(v_hedge.mtm_gain_loss, 0);

    -- Change in hedged item value (underlying exposure)
    v_hedged_item_change := -v_hedge_change * 0.95;  -- Simplified approximation

    -- Calculate effectiveness ratio (dollar offset method)
    IF v_hedged_item_change <> 0 THEN
        v_effectiveness_ratio := ABS(v_hedge_change / v_hedged_item_change);
    ELSE
        v_effectiveness_ratio := 1.0;
    END IF;

    -- Determine if effective (IFRS 9: 80% to 125%)
    v_is_effective := v_effectiveness_ratio BETWEEN 0.80 AND 1.25;

    -- Calculate ineffective portion
    IF v_is_effective THEN
        v_ineffective_amount := 0;
    ELSE
        v_ineffective_amount := v_hedge_change - v_hedged_item_change;
    END IF;

    -- Record test result
    INSERT INTO sys.hedge_effectiveness_tests (
        hedge_id, test_date, test_type, test_method,
        hedge_change, hedged_item_change, effectiveness_ratio,
        is_effective, ineffective_amount
    )
    VALUES (
        p_hedge_id, p_test_date, 'RETROSPECTIVE', 'DOLLAR_OFFSET',
        v_hedge_change, v_hedged_item_change, v_effectiveness_ratio,
        v_is_effective, v_ineffective_amount
    )
    RETURNING test_id INTO v_test_id;

    -- Update hedge status if no longer effective
    IF NOT v_is_effective THEN
        UPDATE sys.fx_hedges
        SET status = 'DE_DESIGNATED', updated_at = NOW(), updated_by = p_user_id
        WHERE hedge_id = p_hedge_id;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'test_id', v_test_id,
        'hedge_id', p_hedge_id,
        'test_date', p_test_date,
        'hedge_change', v_hedge_change,
        'hedged_item_change', v_hedged_item_change,
        'effectiveness_ratio', v_effectiveness_ratio,
        'is_effective', v_is_effective,
        'ineffective_amount', v_ineffective_amount
    );
END;
$$;

COMMENT ON FUNCTION sys.rpc_calculate_hedge_effectiveness IS 'IFRS 9 hedge effectiveness testing';

-- ----------------------------------------------------------------------------
-- 8.4 Execute Netting Run
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sys.rpc_execute_netting_run(
    p_netting_center_entity_id BIGINT,
    p_netting_date DATE,
    p_cutoff_date DATE,
    p_settlement_date DATE,
    p_netting_currency VARCHAR(3) DEFAULT 'EUR',
    p_user_id BIGINT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_netting_run_id BIGINT;
    v_netting_reference VARCHAR(50);
    v_gross_payables DECIMAL(18,2) := 0;
    v_gross_receivables DECIMAL(18,2) := 0;
    v_participant_count INT := 0;
    v_transaction_count INT := 0;
BEGIN
    -- Validate netting center
    IF NOT EXISTS (SELECT 1 FROM sys.tenant_entities WHERE entity_id = p_netting_center_entity_id AND is_active = TRUE) THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Netting center entity not found or inactive'
        );
    END IF;

    -- Generate reference
    v_netting_reference := 'NET-' || TO_CHAR(p_netting_date, 'YYYYMMDD') || '-' || LPAD(NEXTVAL('sys.netting_ref_seq')::TEXT, 4, '0');

    -- Create netting run
    INSERT INTO sys.netting_runs (
        netting_reference, netting_center_entity_id, netting_currency,
        netting_date, cutoff_date, settlement_date,
        status, created_by
    )
    VALUES (
        v_netting_reference, p_netting_center_entity_id, p_netting_currency,
        p_netting_date, p_cutoff_date, p_settlement_date,
        'DRAFT', p_user_id
    )
    RETURNING netting_run_id INTO v_netting_run_id;

    -- In real implementation:
    -- 1. Gather all IC invoices up to cutoff_date
    -- 2. Convert to netting currency
    -- 3. Create netting_participants records
    -- 4. Create netting_transactions records
    -- 5. Calculate net positions

    -- Update totals (placeholder)
    UPDATE sys.netting_runs
    SET gross_payables = v_gross_payables,
        gross_receivables = v_gross_receivables,
        participant_count = v_participant_count,
        transaction_count = v_transaction_count
    WHERE netting_run_id = v_netting_run_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'netting_run_id', v_netting_run_id,
        'netting_reference', v_netting_reference,
        'netting_date', p_netting_date,
        'cutoff_date', p_cutoff_date,
        'settlement_date', p_settlement_date,
        'gross_payables', v_gross_payables,
        'gross_receivables', v_gross_receivables,
        'participant_count', v_participant_count,
        'transaction_count', v_transaction_count
    );
END;
$$;

COMMENT ON FUNCTION sys.rpc_execute_netting_run IS 'Create and execute IC netting run';

-- Create sequence for netting references
CREATE SEQUENCE IF NOT EXISTS sys.netting_ref_seq START 1;

-- ----------------------------------------------------------------------------
-- 8.5 Get Treasury Dashboard Data
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sys.rpc_get_treasury_dashboard(
    p_entity_id BIGINT,
    p_as_of_date DATE DEFAULT CURRENT_DATE,
    p_user_id BIGINT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_cash_pools JSONB;
    v_fx_exposure JSONB;
    v_forecast_summary JSONB;
    v_netting_summary JSONB;
BEGIN
    -- Cash pools summary
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'pool_code', pool_code,
        'pool_name', pool_name,
        'pool_type', pool_type,
        'member_count', member_count,
        'is_active', is_active
    )), '[]')
    INTO v_cash_pools
    FROM sys.v_cash_pool_summary
    WHERE header_entity = (SELECT entity_name FROM sys.tenant_entities WHERE entity_id = p_entity_id);

    -- FX hedge exposure
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'hedge_reference', hedge_reference,
        'instrument_type', instrument_type,
        'buy_currency', buy_currency,
        'sell_currency', sell_currency,
        'notional_amount', notional_amount,
        'days_to_maturity', days_to_maturity,
        'fair_value', fair_value,
        'status', status
    )), '[]')
    INTO v_fx_exposure
    FROM sys.v_fx_hedge_portfolio
    WHERE entity_code = (SELECT entity_code FROM sys.tenant_entities WHERE entity_id = p_entity_id)
      AND status IN ('DESIGNATED', 'ACTIVE');

    -- Cash forecast summary (next 30 days)
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'forecast_date', forecast_date,
        'category', category,
        'forecast_inflows', forecast_inflows,
        'forecast_outflows', forecast_outflows,
        'forecast_net', forecast_net
    )), '[]')
    INTO v_forecast_summary
    FROM sys.v_cash_forecast_summary
    WHERE entity_id = p_entity_id
      AND forecast_date BETWEEN p_as_of_date AND p_as_of_date + 30;

    -- Recent netting runs
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'netting_reference', netting_reference,
        'netting_date', netting_date,
        'net_settlement_amount', net_settlement_amount,
        'settlement_reduction_pct', settlement_reduction_pct,
        'status', status
    )), '[]')
    INTO v_netting_summary
    FROM sys.v_netting_run_summary
    WHERE netting_date >= p_as_of_date - 90
    ORDER BY netting_date DESC
    LIMIT 10;

    RETURN jsonb_build_object(
        'success', TRUE,
        'entity_id', p_entity_id,
        'as_of_date', p_as_of_date,
        'cash_pools', v_cash_pools,
        'fx_hedges', v_fx_exposure,
        'cash_forecast', v_forecast_summary,
        'netting_runs', v_netting_summary
    );
END;
$$;

COMMENT ON FUNCTION sys.rpc_get_treasury_dashboard IS 'Get treasury dashboard data for an entity';

-- ============================================================================
-- SECTION 9: PERMISSIONS
-- ============================================================================

-- Treasury permissions
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
    ('CASH_POOL.VIEW', 'View Cash Pools', 'TREASURY', 'View cash pool configurations and balances'),
    ('CASH_POOL.MANAGE', 'Manage Cash Pools', 'TREASURY', 'Create and modify cash pool configurations'),
    ('CASH_POOL.SWEEP', 'Execute Sweeps', 'TREASURY', 'Execute cash pool sweeps'),
    ('FORECAST.VIEW', 'View Cash Forecasts', 'TREASURY', 'View cash flow forecasts'),
    ('FORECAST.EDIT', 'Edit Cash Forecasts', 'TREASURY', 'Create and modify cash forecasts'),
    ('HEDGE.VIEW', 'View FX Hedges', 'TREASURY', 'View FX hedge instruments'),
    ('HEDGE.MANAGE', 'Manage FX Hedges', 'TREASURY', 'Create and modify FX hedge instruments'),
    ('HEDGE.DESIGNATE', 'Designate Hedges', 'TREASURY', 'Designate hedges for hedge accounting'),
    ('NETTING.VIEW', 'View Netting Runs', 'TREASURY', 'View IC netting runs'),
    ('NETTING.EXECUTE', 'Execute Netting', 'TREASURY', 'Create and execute IC netting runs'),
    ('NETTING.CONFIRM', 'Confirm Netting', 'TREASURY', 'Confirm participation in netting'),
    ('BANK.VIEW', 'View Bank Connections', 'TREASURY', 'View bank connectivity settings'),
    ('BANK.MANAGE', 'Manage Bank Connections', 'TREASURY', 'Configure bank connectivity')
) AS v(code, name, category, description)
ON CONFLICT (permission_code) DO NOTHING;

-- ============================================================================
-- SECTION 10: INDEXES AND CONSTRAINTS
-- ============================================================================

-- Additional performance indexes
CREATE INDEX idx_cash_forecasts_source ON sys.cash_forecasts(source);
CREATE INDEX idx_fx_hedges_designated ON sys.fx_hedges(is_designated) WHERE is_designated = TRUE;
CREATE INDEX idx_netting_txn_dates ON sys.netting_transactions(document_date, due_date);

-- ============================================================================
-- END OF ONYX TREASURY MODULE
-- ============================================================================

COMMENT ON SCHEMA sys IS 'EdenFin system schema with ONYX Treasury module';
