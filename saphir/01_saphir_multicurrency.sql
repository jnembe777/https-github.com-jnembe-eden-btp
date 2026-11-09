-- ============================================================================
-- EDENFIN SAPHIR — SCRIPT 01 : MULTI-CURRENCY MANAGEMENT
-- PostgreSQL 15+ (Supabase)
-- ============================================================================
-- Tier SAPHIR : ETI (50-250 employés)
-- Fonctionnalités ajoutées :
--   - Devises multiples par transaction
--   - Taux de change (spot, clôture, moyen, budget)
--   - Positions de change par entité
--   - Réévaluation de change mensuelle
--   - Conversion vers devise de reporting
-- ============================================================================
-- Dépend de : JASPE (00-09), RUBIS (01-03)
-- ============================================================================

-- ============================================================================
-- 1. ENUM TYPES
-- ============================================================================

-- Rate source
DO $$ BEGIN
    CREATE TYPE sys.fx_rate_source AS ENUM (
        'ECB',          -- European Central Bank
        'BEAC',         -- Banque des États de l'Afrique Centrale
        'BCEAO',        -- Banque Centrale des États de l'Afrique de l'Ouest
        'XE',           -- XE.com
        'OANDA',        -- OANDA
        'MANUAL'        -- Manual entry
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Rate type
DO $$ BEGIN
    CREATE TYPE sys.fx_rate_type AS ENUM (
        'SPOT',         -- Current market rate
        'CLOSING',      -- End of day/month closing rate
        'AVERAGE',      -- Period average rate
        'BUDGET',       -- Budgeted rate
        'HISTORICAL'    -- Rate at transaction date
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Revaluation status
DO $$ BEGIN
    CREATE TYPE sys.fx_reval_status AS ENUM (
        'DRAFT',        -- Calculated but not posted
        'POSTED',       -- Posted to ledger
        'REVERSED'      -- Reversed (correction)
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Translation method
DO $$ BEGIN
    CREATE TYPE sys.fx_translation_method AS ENUM (
        'CURRENT',      -- Current rate method (IAS 21)
        'TEMPORAL',     -- Temporal method
        'MONETARY'      -- Monetary/non-monetary method
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================================
-- 2. EXTENDED CURRENCY TABLE
-- ============================================================================

-- Extended currency information for SAPHIR
CREATE TABLE IF NOT EXISTS sys.currencies_extended (
    id BIGSERIAL PRIMARY KEY,
    currency_code VARCHAR(3) NOT NULL UNIQUE,   -- ISO 4217
    currency_name VARCHAR(100) NOT NULL,
    currency_name_fr VARCHAR(100),
    symbol VARCHAR(10),
    decimal_places INT NOT NULL DEFAULT 2,

    -- SAPHIR flags
    is_functional BOOLEAN NOT NULL DEFAULT FALSE,   -- Can be entity functional currency
    is_reporting BOOLEAN NOT NULL DEFAULT FALSE,    -- Can be group reporting currency
    is_trading BOOLEAN NOT NULL DEFAULT TRUE,       -- Can be used in transactions

    -- Rate management
    rate_source sys.fx_rate_source NOT NULL DEFAULT 'MANUAL',
    auto_update BOOLEAN NOT NULL DEFAULT FALSE,     -- Auto-fetch rates
    last_rate_date DATE,

    -- Regional
    cemac_member BOOLEAN NOT NULL DEFAULT FALSE,    -- XAF zone
    uemoa_member BOOLEAN NOT NULL DEFAULT FALSE,    -- XOF zone

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,
    version_number INT NOT NULL DEFAULT 1
);

CREATE INDEX idx_currencies_ext_active ON sys.currencies_extended(is_active);

COMMENT ON TABLE sys.currencies_extended IS 'Extended currency master for multi-currency (SAPHIR)';

-- ============================================================================
-- 3. EXCHANGE RATES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS sys.exchange_rates (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),

    -- Currency pair
    from_currency VARCHAR(3) NOT NULL,
    to_currency VARCHAR(3) NOT NULL,

    -- Rate information
    rate_date DATE NOT NULL,
    rate_type sys.fx_rate_type NOT NULL DEFAULT 'SPOT',
    rate DECIMAL(18, 10) NOT NULL,

    -- Source
    source sys.fx_rate_source NOT NULL DEFAULT 'MANUAL',
    source_reference VARCHAR(100),  -- External reference ID

    -- Inverse storage (optimization)
    is_inverted BOOLEAN NOT NULL DEFAULT FALSE,

    -- Validity for budget rates
    valid_from DATE,
    valid_to DATE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,
    version_number INT NOT NULL DEFAULT 1,

    -- Constraints
    CONSTRAINT chk_rate_positive CHECK (rate > 0),
    CONSTRAINT uq_exchange_rate UNIQUE (tenant_id, from_currency, to_currency, rate_date, rate_type)
);

CREATE INDEX idx_exchange_rates_tenant ON sys.exchange_rates(tenant_id);
CREATE INDEX idx_exchange_rates_date ON sys.exchange_rates(rate_date);
CREATE INDEX idx_exchange_rates_pair ON sys.exchange_rates(from_currency, to_currency);

COMMENT ON TABLE sys.exchange_rates IS 'Exchange rates by currency pair, date, and type (SAPHIR)';

-- ============================================================================
-- 4. ENTITY CURRENCY SETTINGS
-- ============================================================================

CREATE TABLE IF NOT EXISTS sys.entity_currency_settings (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),

    -- Currencies
    functional_currency VARCHAR(3) NOT NULL DEFAULT 'XAF',  -- Operating currency
    reporting_currency VARCHAR(3),                           -- Group reporting (if different)

    -- Translation settings
    translation_method sys.fx_translation_method NOT NULL DEFAULT 'CURRENT',

    -- Revaluation settings
    reval_gain_account VARCHAR(20),     -- Account for FX gains
    reval_loss_account VARCHAR(20),     -- Account for FX losses
    translation_reserve_account VARCHAR(20),  -- CTA account

    -- Preferences
    default_rate_type sys.fx_rate_type NOT NULL DEFAULT 'SPOT',

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_entity_currency UNIQUE (entity_id)
);

CREATE INDEX idx_entity_currency_tenant ON sys.entity_currency_settings(tenant_id);

COMMENT ON TABLE sys.entity_currency_settings IS 'Currency configuration per entity (SAPHIR)';

-- ============================================================================
-- 5. FX POSITIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS sys.fx_positions (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),

    -- Position date
    position_date DATE NOT NULL,

    -- Currency
    currency_code VARCHAR(3) NOT NULL,

    -- Position amounts (in foreign currency)
    monetary_assets DECIMAL(18, 2) NOT NULL DEFAULT 0,       -- Cash, receivables, etc.
    monetary_liabilities DECIMAL(18, 2) NOT NULL DEFAULT 0,  -- Payables, loans, etc.
    net_position DECIMAL(18, 2) GENERATED ALWAYS AS (monetary_assets - monetary_liabilities) STORED,

    -- Functional currency equivalent (at position date rate)
    functional_rate DECIMAL(18, 10) NOT NULL,
    functional_value DECIMAL(18, 2) GENERATED ALWAYS AS ((monetary_assets - monetary_liabilities) * functional_rate) STORED,

    -- Breakdown by account type (JSON)
    position_detail JSONB,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_fx_position UNIQUE (entity_id, currency_code, position_date)
);

CREATE INDEX idx_fx_positions_entity ON sys.fx_positions(entity_id);
CREATE INDEX idx_fx_positions_date ON sys.fx_positions(position_date);

COMMENT ON TABLE sys.fx_positions IS 'Daily FX position by currency (SAPHIR)';

-- ============================================================================
-- 6. FX REVALUATION RUNS
-- ============================================================================

CREATE TABLE IF NOT EXISTS sys.fx_revaluation_runs (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),

    -- Run identification
    run_number VARCHAR(30) NOT NULL,
    run_date DATE NOT NULL,               -- Revaluation date (month-end)

    -- Rate used
    rate_type sys.fx_rate_type NOT NULL DEFAULT 'CLOSING',

    -- Results (by currency - stored in detail)
    total_gain DECIMAL(18, 2) NOT NULL DEFAULT 0,
    total_loss DECIMAL(18, 2) NOT NULL DEFAULT 0,
    net_gain_loss DECIMAL(18, 2) GENERATED ALWAYS AS (total_gain - total_loss) STORED,

    -- Detail by currency
    currency_detail JSONB NOT NULL DEFAULT '[]',

    -- Status
    status sys.fx_reval_status NOT NULL DEFAULT 'DRAFT',

    -- Posted entry
    journal_entry_id BIGINT,
    posted_at TIMESTAMPTZ,
    posted_by BIGINT,

    -- Reversal
    reversed_at TIMESTAMPTZ,
    reversed_by BIGINT,
    reversal_entry_id BIGINT,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_fx_reval_run UNIQUE (entity_id, run_number)
);

CREATE INDEX idx_fx_reval_entity ON sys.fx_revaluation_runs(entity_id);
CREATE INDEX idx_fx_reval_date ON sys.fx_revaluation_runs(run_date);
CREATE INDEX idx_fx_reval_status ON sys.fx_revaluation_runs(status);

COMMENT ON TABLE sys.fx_revaluation_runs IS 'FX revaluation runs for month-end (SAPHIR)';

-- ============================================================================
-- 7. TRANSLATION ADJUSTMENTS (CTA)
-- ============================================================================

CREATE TABLE IF NOT EXISTS sys.fx_translation_adjustments (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),

    -- Period
    fiscal_year INT NOT NULL,
    fiscal_period INT NOT NULL,     -- 1-12 for months, 13 for year-end

    -- From/To currencies
    from_currency VARCHAR(3) NOT NULL,  -- Functional
    to_currency VARCHAR(3) NOT NULL,    -- Reporting

    -- Rates used
    closing_rate DECIMAL(18, 10) NOT NULL,
    average_rate DECIMAL(18, 10) NOT NULL,
    opening_rate DECIMAL(18, 10) NOT NULL,

    -- Amounts
    assets_translated DECIMAL(18, 2) NOT NULL DEFAULT 0,
    liabilities_translated DECIMAL(18, 2) NOT NULL DEFAULT 0,
    equity_translated DECIMAL(18, 2) NOT NULL DEFAULT 0,
    income_translated DECIMAL(18, 2) NOT NULL DEFAULT 0,
    expense_translated DECIMAL(18, 2) NOT NULL DEFAULT 0,

    -- CTA movement
    cta_opening DECIMAL(18, 2) NOT NULL DEFAULT 0,
    cta_movement DECIMAL(18, 2) NOT NULL DEFAULT 0,
    cta_closing DECIMAL(18, 2) GENERATED ALWAYS AS (cta_opening + cta_movement) STORED,

    -- Status
    is_posted BOOLEAN NOT NULL DEFAULT FALSE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_fx_translation UNIQUE (entity_id, fiscal_year, fiscal_period)
);

CREATE INDEX idx_fx_translation_entity ON sys.fx_translation_adjustments(entity_id);
CREATE INDEX idx_fx_translation_period ON sys.fx_translation_adjustments(fiscal_year, fiscal_period);

COMMENT ON TABLE sys.fx_translation_adjustments IS 'Currency translation adjustments for consolidation (SAPHIR)';

-- ============================================================================
-- 8. RPC FUNCTIONS
-- ============================================================================

-- 8.1 Get exchange rate
CREATE OR REPLACE FUNCTION sys.rpc_get_exchange_rate(
    p_tenant_id BIGINT,
    p_from_currency VARCHAR(3),
    p_to_currency VARCHAR(3),
    p_date DATE,
    p_rate_type sys.fx_rate_type DEFAULT 'SPOT'
)
RETURNS DECIMAL(18, 10)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_rate DECIMAL(18, 10);
    v_inverted_rate DECIMAL(18, 10);
BEGIN
    -- Same currency
    IF p_from_currency = p_to_currency THEN
        RETURN 1.0;
    END IF;

    -- Try direct rate
    SELECT rate INTO v_rate
    FROM sys.exchange_rates
    WHERE tenant_id = p_tenant_id
      AND from_currency = p_from_currency
      AND to_currency = p_to_currency
      AND rate_type = p_rate_type
      AND rate_date <= p_date
    ORDER BY rate_date DESC
    LIMIT 1;

    IF v_rate IS NOT NULL THEN
        RETURN v_rate;
    END IF;

    -- Try inverted rate
    SELECT rate INTO v_inverted_rate
    FROM sys.exchange_rates
    WHERE tenant_id = p_tenant_id
      AND from_currency = p_to_currency
      AND to_currency = p_from_currency
      AND rate_type = p_rate_type
      AND rate_date <= p_date
    ORDER BY rate_date DESC
    LIMIT 1;

    IF v_inverted_rate IS NOT NULL THEN
        RETURN 1.0 / v_inverted_rate;
    END IF;

    -- Try triangulation via EUR or USD
    DECLARE
        v_via_eur DECIMAL(18, 10);
        v_from_eur DECIMAL(18, 10);
        v_to_eur DECIMAL(18, 10);
    BEGIN
        SELECT sys.rpc_get_exchange_rate(p_tenant_id, p_from_currency, 'EUR', p_date, p_rate_type) INTO v_from_eur;
        SELECT sys.rpc_get_exchange_rate(p_tenant_id, 'EUR', p_to_currency, p_date, p_rate_type) INTO v_to_eur;

        IF v_from_eur IS NOT NULL AND v_to_eur IS NOT NULL THEN
            RETURN v_from_eur * v_to_eur;
        END IF;
    END;

    RETURN NULL;  -- Rate not found
END;
$$;

COMMENT ON FUNCTION sys.rpc_get_exchange_rate IS 'Get exchange rate for currency pair at date';

-- 8.2 Convert amount
CREATE OR REPLACE FUNCTION sys.rpc_convert_amount(
    p_tenant_id BIGINT,
    p_amount DECIMAL(18, 2),
    p_from_currency VARCHAR(3),
    p_to_currency VARCHAR(3),
    p_date DATE,
    p_rate_type sys.fx_rate_type DEFAULT 'SPOT'
)
RETURNS DECIMAL(18, 2)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_rate DECIMAL(18, 10);
BEGIN
    IF p_from_currency = p_to_currency THEN
        RETURN p_amount;
    END IF;

    v_rate := sys.rpc_get_exchange_rate(p_tenant_id, p_from_currency, p_to_currency, p_date, p_rate_type);

    IF v_rate IS NULL THEN
        RAISE EXCEPTION 'Exchange rate not found for %/% on %', p_from_currency, p_to_currency, p_date;
    END IF;

    RETURN ROUND(p_amount * v_rate, 2);
END;
$$;

COMMENT ON FUNCTION sys.rpc_convert_amount IS 'Convert amount between currencies';

-- 8.3 Calculate FX position
CREATE OR REPLACE FUNCTION sys.rpc_calculate_fx_position(
    p_entity_id BIGINT,
    p_position_date DATE
)
RETURNS TABLE (
    currency_code VARCHAR(3),
    monetary_assets DECIMAL(18, 2),
    monetary_liabilities DECIMAL(18, 2),
    net_position DECIMAL(18, 2),
    functional_value DECIMAL(18, 2)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_tenant_id BIGINT;
    v_functional_currency VARCHAR(3);
BEGIN
    -- Get tenant and functional currency
    SELECT e.tenant_id, COALESCE(ecs.functional_currency, 'XAF')
    INTO v_tenant_id, v_functional_currency
    FROM sys.tenant_entities e
    LEFT JOIN sys.entity_currency_settings ecs ON ecs.entity_id = e.id
    WHERE e.id = p_entity_id;

    -- Calculate position per currency from balances
    -- This would aggregate monetary accounts (cash, receivables, payables)
    RETURN QUERY
    WITH monetary_balances AS (
        -- Placeholder: would query actual account balances
        -- For now, return from fx_positions if exists
        SELECT
            fp.currency_code,
            fp.monetary_assets,
            fp.monetary_liabilities,
            fp.net_position,
            fp.functional_value
        FROM sys.fx_positions fp
        WHERE fp.entity_id = p_entity_id
          AND fp.position_date = p_position_date
    )
    SELECT * FROM monetary_balances;
END;
$$;

COMMENT ON FUNCTION sys.rpc_calculate_fx_position IS 'Calculate FX position for entity at date';

-- 8.4 Run FX revaluation
CREATE OR REPLACE FUNCTION sys.rpc_run_fx_revaluation(
    p_entity_id BIGINT,
    p_reval_date DATE,
    p_rate_type sys.fx_rate_type DEFAULT 'CLOSING',
    p_auto_post BOOLEAN DEFAULT FALSE
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_tenant_id BIGINT;
    v_functional_currency VARCHAR(3);
    v_run_id BIGINT;
    v_run_number VARCHAR(30);
    v_total_gain DECIMAL(18, 2) := 0;
    v_total_loss DECIMAL(18, 2) := 0;
    v_currency_detail JSONB := '[]';
    v_position RECORD;
    v_new_rate DECIMAL(18, 10);
    v_old_rate DECIMAL(18, 10);
    v_gain_loss DECIMAL(18, 2);
BEGIN
    -- Get tenant and functional currency
    SELECT e.tenant_id, COALESCE(ecs.functional_currency, 'XAF')
    INTO v_tenant_id, v_functional_currency
    FROM sys.tenant_entities e
    LEFT JOIN sys.entity_currency_settings ecs ON ecs.entity_id = e.id
    WHERE e.id = p_entity_id;

    -- Generate run number
    v_run_number := 'FX-' || p_entity_id || '-' || TO_CHAR(p_reval_date, 'YYYYMM');

    -- Check for existing run
    IF EXISTS (SELECT 1 FROM sys.fx_revaluation_runs WHERE entity_id = p_entity_id AND run_number = v_run_number) THEN
        RAISE EXCEPTION 'FX revaluation already exists for this period: %', v_run_number;
    END IF;

    -- Process each foreign currency position
    FOR v_position IN (
        SELECT * FROM sys.fx_positions
        WHERE entity_id = p_entity_id
          AND position_date = (
              SELECT MAX(position_date)
              FROM sys.fx_positions
              WHERE entity_id = p_entity_id AND position_date <= p_reval_date
          )
          AND currency_code != v_functional_currency
    ) LOOP
        -- Get current rate
        v_new_rate := sys.rpc_get_exchange_rate(
            v_tenant_id,
            v_position.currency_code,
            v_functional_currency,
            p_reval_date,
            p_rate_type
        );

        IF v_new_rate IS NULL THEN
            CONTINUE;  -- Skip if no rate
        END IF;

        -- Old rate from position
        v_old_rate := v_position.functional_rate;

        -- Calculate gain/loss
        v_gain_loss := v_position.net_position * (v_new_rate - v_old_rate);

        -- Accumulate
        IF v_gain_loss > 0 THEN
            v_total_gain := v_total_gain + v_gain_loss;
        ELSE
            v_total_loss := v_total_loss + ABS(v_gain_loss);
        END IF;

        -- Add to detail
        v_currency_detail := v_currency_detail || jsonb_build_object(
            'currency', v_position.currency_code,
            'position', v_position.net_position,
            'old_rate', v_old_rate,
            'new_rate', v_new_rate,
            'gain_loss', v_gain_loss
        );
    END LOOP;

    -- Create run record
    INSERT INTO sys.fx_revaluation_runs (
        tenant_id, entity_id, run_number, run_date, rate_type,
        total_gain, total_loss, currency_detail, status
    ) VALUES (
        v_tenant_id, p_entity_id, v_run_number, p_reval_date, p_rate_type,
        v_total_gain, v_total_loss, v_currency_detail, 'DRAFT'
    )
    RETURNING id INTO v_run_id;

    -- Auto-post if requested (would create journal entry)
    IF p_auto_post AND (v_total_gain != 0 OR v_total_loss != 0) THEN
        UPDATE sys.fx_revaluation_runs
        SET status = 'POSTED',
            posted_at = NOW()
        WHERE id = v_run_id;
    END IF;

    RETURN v_run_id::TEXT::UUID;  -- Return as UUID for consistency
END;
$$;

COMMENT ON FUNCTION sys.rpc_run_fx_revaluation IS 'Run FX revaluation for entity at month-end';

-- ============================================================================
-- 9. VIEWS
-- ============================================================================

-- 9.1 Exchange rate summary
CREATE OR REPLACE VIEW sys.v_exchange_rates_latest AS
SELECT DISTINCT ON (er.tenant_id, er.from_currency, er.to_currency)
    er.tenant_id,
    er.from_currency,
    er.to_currency,
    er.rate_date,
    er.rate_type,
    er.rate,
    er.source,
    ce_from.currency_name AS from_currency_name,
    ce_to.currency_name AS to_currency_name
FROM sys.exchange_rates er
LEFT JOIN sys.currencies_extended ce_from ON ce_from.currency_code = er.from_currency
LEFT JOIN sys.currencies_extended ce_to ON ce_to.currency_code = er.to_currency
WHERE er.rate_type = 'SPOT'
ORDER BY er.tenant_id, er.from_currency, er.to_currency, er.rate_date DESC;

COMMENT ON VIEW sys.v_exchange_rates_latest IS 'Latest exchange rates per currency pair';

-- 9.2 FX position summary
CREATE OR REPLACE VIEW sys.v_fx_positions_summary AS
SELECT
    fp.entity_id,
    te.entity_name,
    fp.position_date,
    COUNT(DISTINCT fp.currency_code) AS currency_count,
    SUM(fp.monetary_assets) AS total_assets,
    SUM(fp.monetary_liabilities) AS total_liabilities,
    SUM(fp.net_position) AS total_net_position,
    SUM(fp.functional_value) AS total_functional_value
FROM sys.fx_positions fp
JOIN sys.tenant_entities te ON te.id = fp.entity_id
GROUP BY fp.entity_id, te.entity_name, fp.position_date;

COMMENT ON VIEW sys.v_fx_positions_summary IS 'FX position summary by entity and date';

-- ============================================================================
-- 10. SEED DATA
-- ============================================================================

-- Insert common currencies
INSERT INTO sys.currencies_extended (currency_code, currency_name, currency_name_fr, symbol, decimal_places, is_functional, is_reporting, cemac_member, uemoa_member, rate_source) VALUES
    ('XAF', 'CFA Franc BEAC', 'Franc CFA BEAC', 'FCFA', 0, TRUE, TRUE, TRUE, FALSE, 'BEAC'),
    ('XOF', 'CFA Franc BCEAO', 'Franc CFA BCEAO', 'FCFA', 0, TRUE, TRUE, FALSE, TRUE, 'BCEAO'),
    ('EUR', 'Euro', 'Euro', '€', 2, TRUE, TRUE, FALSE, FALSE, 'ECB'),
    ('USD', 'US Dollar', 'Dollar américain', '$', 2, TRUE, TRUE, FALSE, FALSE, 'ECB'),
    ('GBP', 'British Pound', 'Livre sterling', '£', 2, TRUE, TRUE, FALSE, FALSE, 'ECB'),
    ('CHF', 'Swiss Franc', 'Franc suisse', 'CHF', 2, TRUE, FALSE, FALSE, FALSE, 'ECB'),
    ('CNY', 'Chinese Yuan', 'Yuan chinois', '¥', 2, FALSE, FALSE, FALSE, FALSE, 'ECB'),
    ('JPY', 'Japanese Yen', 'Yen japonais', '¥', 0, FALSE, FALSE, FALSE, FALSE, 'ECB'),
    ('ZAR', 'South African Rand', 'Rand sud-africain', 'R', 2, TRUE, FALSE, FALSE, FALSE, 'MANUAL'),
    ('NGN', 'Nigerian Naira', 'Naira nigérian', '₦', 2, TRUE, FALSE, FALSE, FALSE, 'MANUAL'),
    ('GHS', 'Ghanaian Cedi', 'Cedi ghanéen', 'GH₵', 2, TRUE, FALSE, FALSE, FALSE, 'MANUAL'),
    ('MAD', 'Moroccan Dirham', 'Dirham marocain', 'DH', 2, TRUE, FALSE, FALSE, FALSE, 'MANUAL')
ON CONFLICT (currency_code) DO NOTHING;

-- Insert fixed parity rates (XAF/XOF to EUR)
-- Note: XAF and XOF have fixed parity with EUR at 655.957
-- These would be inserted per tenant in production

COMMENT ON SCHEMA sys IS 'EdenFin System Schema - SAPHIR Multi-Currency Extension';
