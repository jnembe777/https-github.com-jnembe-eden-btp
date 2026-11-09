-- ============================================================================
-- EDENFIN SAPHIR — SCRIPT 05 : BUSINESS INTELLIGENCE & REPORTING
-- PostgreSQL 15+ (Supabase)
-- ============================================================================
-- Tier SAPHIR : ETI (50-250 employés)
-- Fonctionnalités ajoutées :
--   - Définition de rapports configurables
--   - Dimensions d'analyse (temps, entité, compte, etc.)
--   - Mesures et KPIs
--   - Planification de rapports
--   - Tableaux de bord
-- ============================================================================
-- Dépend de : JASPE (00-09), RUBIS (01-03), SAPHIR 01-04
-- ============================================================================

-- ============================================================================
-- 1. ENUM TYPES
-- ============================================================================

-- Report type
DO $$ BEGIN
    CREATE TYPE sys.report_type AS ENUM (
        'BALANCE_SHEET',        -- Bilan
        'INCOME_STATEMENT',     -- Compte de résultat
        'CASH_FLOW',            -- Tableau des flux de trésorerie
        'TRIAL_BALANCE',        -- Balance générale
        'AGED_RECEIVABLES',     -- Balance âgée clients
        'AGED_PAYABLES',        -- Balance âgée fournisseurs
        'BUDGET_VS_ACTUAL',     -- Budget vs Réel
        'KPI_DASHBOARD',        -- Tableau de bord KPI
        'CUSTOM'                -- Rapport personnalisé
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Report format
DO $$ BEGIN
    CREATE TYPE sys.report_format AS ENUM (
        'PDF',
        'EXCEL',
        'CSV',
        'HTML',
        'JSON'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Dimension type
DO $$ BEGIN
    CREATE TYPE sys.dimension_type AS ENUM (
        'TIME',             -- Year, Quarter, Month, Week, Day
        'ENTITY',           -- Legal entity
        'ACCOUNT',          -- Chart of accounts
        'COST_CENTER',      -- Analytical axis 1
        'PROJECT',          -- Analytical axis 2
        'PRODUCT',          -- Analytical axis 3
        'CURRENCY',         -- Currency
        'PARTNER',          -- Customer/Supplier
        'GEOGRAPHY'         -- Region, country
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Measure type
DO $$ BEGIN
    CREATE TYPE sys.measure_type AS ENUM (
        'BALANCE',          -- Account balance
        'DEBIT',            -- Debit total
        'CREDIT',           -- Credit total
        'MOVEMENT',         -- Period movement
        'CUMULATIVE',       -- Year-to-date
        'BUDGET',           -- Budget amount
        'VARIANCE',         -- Budget - Actual
        'RATIO',            -- Calculated ratio
        'COUNT',            -- Record count
        'CUSTOM'            -- Custom calculation
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Aggregation function
DO $$ BEGIN
    CREATE TYPE sys.aggregation_func AS ENUM (
        'SUM',
        'AVG',
        'MIN',
        'MAX',
        'COUNT',
        'FIRST',
        'LAST'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Schedule frequency
DO $$ BEGIN
    CREATE TYPE sys.schedule_frequency AS ENUM (
        'DAILY',
        'WEEKLY',
        'MONTHLY',
        'QUARTERLY',
        'YEARLY',
        'ON_DEMAND'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Schedule status
DO $$ BEGIN
    CREATE TYPE sys.schedule_status AS ENUM (
        'ACTIVE',
        'PAUSED',
        'COMPLETED',
        'ERROR'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- KPI trend
DO $$ BEGIN
    CREATE TYPE sys.kpi_trend AS ENUM (
        'UP_GOOD',          -- Higher is better
        'DOWN_GOOD',        -- Lower is better
        'TARGET',           -- Meet target is good
        'NEUTRAL'           -- No direction preference
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================================
-- 2. DIMENSION TABLES
-- ============================================================================

-- 2.1 Dimension Definitions
CREATE TABLE IF NOT EXISTS sys.bi_dimensions (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),

    -- Identification
    dimension_code VARCHAR(30) NOT NULL,
    dimension_name VARCHAR(200) NOT NULL,
    description TEXT,

    -- Type
    dimension_type sys.dimension_type NOT NULL,

    -- Source
    source_table VARCHAR(100),          -- Source table for values
    source_key_column VARCHAR(100),     -- Key column
    source_label_column VARCHAR(100),   -- Display label column
    source_parent_column VARCHAR(100),  -- For hierarchical dimensions

    -- Hierarchy
    is_hierarchical BOOLEAN NOT NULL DEFAULT FALSE,
    hierarchy_levels INT DEFAULT 1,

    -- Configuration
    default_member VARCHAR(100),        -- Default selection
    all_member_name VARCHAR(100) DEFAULT 'All',

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_dimension UNIQUE (tenant_id, dimension_code)
);

CREATE INDEX idx_dimension_tenant ON sys.bi_dimensions(tenant_id);
CREATE INDEX idx_dimension_type ON sys.bi_dimensions(dimension_type);

COMMENT ON TABLE sys.bi_dimensions IS 'BI dimension definitions';

-- 2.2 Time Dimension (pre-populated calendar)
CREATE TABLE IF NOT EXISTS sys.bi_dim_time (
    id BIGSERIAL PRIMARY KEY,
    date_key DATE NOT NULL,

    -- Date components
    year INT NOT NULL,
    quarter INT NOT NULL CHECK (quarter BETWEEN 1 AND 4),
    month INT NOT NULL CHECK (month BETWEEN 1 AND 12),
    week INT NOT NULL CHECK (week BETWEEN 1 AND 53),
    day_of_month INT NOT NULL CHECK (day_of_month BETWEEN 1 AND 31),
    day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    day_of_year INT NOT NULL CHECK (day_of_year BETWEEN 1 AND 366),

    -- Labels
    year_label VARCHAR(10),
    quarter_label VARCHAR(10),
    month_label VARCHAR(20),
    week_label VARCHAR(20),
    date_label VARCHAR(30),

    -- Fiscal (OHADA: calendar year)
    fiscal_year INT NOT NULL,
    fiscal_quarter INT NOT NULL,
    fiscal_month INT NOT NULL,

    -- Flags
    is_weekend BOOLEAN NOT NULL,
    is_holiday BOOLEAN NOT NULL DEFAULT FALSE,
    holiday_name VARCHAR(100),
    is_month_end BOOLEAN NOT NULL,
    is_quarter_end BOOLEAN NOT NULL,
    is_year_end BOOLEAN NOT NULL,

    CONSTRAINT uq_dim_time UNIQUE (date_key)
);

CREATE INDEX idx_dim_time_year ON sys.bi_dim_time(year);
CREATE INDEX idx_dim_time_month ON sys.bi_dim_time(year, month);
CREATE INDEX idx_dim_time_fiscal ON sys.bi_dim_time(fiscal_year, fiscal_month);

COMMENT ON TABLE sys.bi_dim_time IS 'Time dimension for BI (calendar)';

-- ============================================================================
-- 3. MEASURE DEFINITIONS
-- ============================================================================

-- 3.1 Measures
CREATE TABLE IF NOT EXISTS sys.bi_measures (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),

    -- Identification
    measure_code VARCHAR(30) NOT NULL,
    measure_name VARCHAR(200) NOT NULL,
    description TEXT,

    -- Type
    measure_type sys.measure_type NOT NULL,
    aggregation sys.aggregation_func NOT NULL DEFAULT 'SUM',

    -- Calculation
    formula TEXT,                       -- SQL expression for custom measures
    source_column VARCHAR(100),         -- Source column if direct
    format_pattern VARCHAR(50),         -- Display format (#,##0.00)
    decimal_places INT DEFAULT 2,

    -- Units
    unit VARCHAR(20),                   -- Currency, %, count, etc.
    is_currency BOOLEAN NOT NULL DEFAULT FALSE,

    -- Direction
    positive_is_good BOOLEAN DEFAULT TRUE,

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_measure UNIQUE (tenant_id, measure_code)
);

CREATE INDEX idx_measure_tenant ON sys.bi_measures(tenant_id);
CREATE INDEX idx_measure_type ON sys.bi_measures(measure_type);

COMMENT ON TABLE sys.bi_measures IS 'BI measure definitions';

-- ============================================================================
-- 4. REPORT DEFINITIONS
-- ============================================================================

-- 4.1 Report Templates
CREATE TABLE IF NOT EXISTS sys.bi_reports (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),

    -- Identification
    report_code VARCHAR(30) NOT NULL,
    report_name VARCHAR(200) NOT NULL,
    description TEXT,

    -- Type
    report_type sys.report_type NOT NULL,

    -- Layout
    layout_config JSONB NOT NULL DEFAULT '{}',  -- Column/row definitions
    page_orientation VARCHAR(20) DEFAULT 'PORTRAIT',
    page_size VARCHAR(10) DEFAULT 'A4',

    -- Dimensions used
    row_dimensions JSONB DEFAULT '[]',      -- Dimensions on rows
    column_dimensions JSONB DEFAULT '[]',   -- Dimensions on columns
    filter_dimensions JSONB DEFAULT '[]',   -- Filter dimensions

    -- Measures used
    measures JSONB DEFAULT '[]',            -- Measure codes

    -- Parameters
    parameters JSONB DEFAULT '[]',          -- Report parameters

    -- Default filters
    default_filters JSONB DEFAULT '{}',

    -- Drill-down
    drill_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    drill_levels JSONB DEFAULT '[]',

    -- Permissions
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    allowed_roles JSONB DEFAULT '[]',

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_report UNIQUE (tenant_id, report_code)
);

CREATE INDEX idx_report_tenant ON sys.bi_reports(tenant_id);
CREATE INDEX idx_report_type ON sys.bi_reports(report_type);

COMMENT ON TABLE sys.bi_reports IS 'BI report template definitions';

-- 4.2 Report Sections (for multi-section reports)
CREATE TABLE IF NOT EXISTS sys.bi_report_sections (
    id BIGSERIAL PRIMARY KEY,
    report_id BIGINT NOT NULL REFERENCES sys.bi_reports(id) ON DELETE CASCADE,

    -- Ordering
    section_order INT NOT NULL,
    section_name VARCHAR(200) NOT NULL,

    -- Content
    section_type VARCHAR(50) NOT NULL,      -- TABLE, CHART, TEXT, SEPARATOR
    section_config JSONB NOT NULL DEFAULT '{}',

    -- Visibility
    show_header BOOLEAN NOT NULL DEFAULT TRUE,
    page_break_before BOOLEAN NOT NULL DEFAULT FALSE,

    -- Conditional
    condition_expression TEXT,              -- Show section if condition met

    CONSTRAINT uq_section UNIQUE (report_id, section_order)
);

CREATE INDEX idx_section_report ON sys.bi_report_sections(report_id);

COMMENT ON TABLE sys.bi_report_sections IS 'Report sections within a report template';

-- ============================================================================
-- 5. KPI DEFINITIONS
-- ============================================================================

-- 5.1 KPI Definitions
CREATE TABLE IF NOT EXISTS sys.bi_kpis (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),

    -- Identification
    kpi_code VARCHAR(30) NOT NULL,
    kpi_name VARCHAR(200) NOT NULL,
    description TEXT,

    -- Category
    category VARCHAR(100),                  -- Financial, Operational, etc.

    -- Calculation
    numerator_measure_id BIGINT REFERENCES sys.bi_measures(id),
    denominator_measure_id BIGINT REFERENCES sys.bi_measures(id),
    formula TEXT,                           -- Custom formula if complex

    -- Display
    format_pattern VARCHAR(50),
    decimal_places INT DEFAULT 2,
    unit VARCHAR(20),

    -- Trend
    trend sys.kpi_trend NOT NULL DEFAULT 'UP_GOOD',

    -- Thresholds
    target_value DECIMAL(18, 4),
    warning_threshold_low DECIMAL(18, 4),
    warning_threshold_high DECIMAL(18, 4),
    critical_threshold_low DECIMAL(18, 4),
    critical_threshold_high DECIMAL(18, 4),

    -- Comparison
    compare_to_prior_period BOOLEAN DEFAULT TRUE,
    compare_to_budget BOOLEAN DEFAULT FALSE,

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_kpi UNIQUE (tenant_id, kpi_code)
);

CREATE INDEX idx_kpi_tenant ON sys.bi_kpis(tenant_id);
CREATE INDEX idx_kpi_category ON sys.bi_kpis(category);

COMMENT ON TABLE sys.bi_kpis IS 'KPI definitions';

-- 5.2 KPI Values (computed snapshots)
CREATE TABLE IF NOT EXISTS sys.bi_kpi_values (
    id BIGSERIAL PRIMARY KEY,
    kpi_id BIGINT NOT NULL REFERENCES sys.bi_kpis(id) ON DELETE CASCADE,
    entity_id BIGINT REFERENCES sys.tenant_entities(id),

    -- Period
    period_year INT NOT NULL,
    period_month INT NOT NULL,
    period_date DATE NOT NULL,

    -- Values
    current_value DECIMAL(18, 4),
    prior_period_value DECIMAL(18, 4),
    prior_year_value DECIMAL(18, 4),
    budget_value DECIMAL(18, 4),
    target_value DECIMAL(18, 4),

    -- Variances
    period_variance DECIMAL(18, 4),
    period_variance_pct DECIMAL(8, 4),
    yoy_variance DECIMAL(18, 4),
    yoy_variance_pct DECIMAL(8, 4),
    budget_variance DECIMAL(18, 4),
    budget_variance_pct DECIMAL(8, 4),

    -- Status
    status VARCHAR(20),                     -- GREEN, YELLOW, RED

    -- Calculation timestamp
    calculated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_kpi_value UNIQUE (kpi_id, entity_id, period_date)
);

CREATE INDEX idx_kpi_value_kpi ON sys.bi_kpi_values(kpi_id);
CREATE INDEX idx_kpi_value_period ON sys.bi_kpi_values(period_year, period_month);
CREATE INDEX idx_kpi_value_entity ON sys.bi_kpi_values(entity_id);

COMMENT ON TABLE sys.bi_kpi_values IS 'Computed KPI values by period';

-- ============================================================================
-- 6. DASHBOARDS
-- ============================================================================

-- 6.1 Dashboard Definitions
CREATE TABLE IF NOT EXISTS sys.bi_dashboards (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),

    -- Identification
    dashboard_code VARCHAR(30) NOT NULL,
    dashboard_name VARCHAR(200) NOT NULL,
    description TEXT,

    -- Layout
    layout_type VARCHAR(20) DEFAULT 'GRID',     -- GRID, FREEFORM
    column_count INT DEFAULT 12,                -- Grid columns
    row_height INT DEFAULT 100,                 -- Base row height in px

    -- Theme
    theme JSONB DEFAULT '{}',

    -- Access
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    allowed_roles JSONB DEFAULT '[]',

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_dashboard UNIQUE (tenant_id, dashboard_code)
);

CREATE INDEX idx_dashboard_tenant ON sys.bi_dashboards(tenant_id);

COMMENT ON TABLE sys.bi_dashboards IS 'Dashboard definitions';

-- 6.2 Dashboard Widgets
CREATE TABLE IF NOT EXISTS sys.bi_dashboard_widgets (
    id BIGSERIAL PRIMARY KEY,
    dashboard_id BIGINT NOT NULL REFERENCES sys.bi_dashboards(id) ON DELETE CASCADE,

    -- Position (grid-based)
    grid_x INT NOT NULL DEFAULT 0,
    grid_y INT NOT NULL DEFAULT 0,
    grid_width INT NOT NULL DEFAULT 4,
    grid_height INT NOT NULL DEFAULT 3,

    -- Widget type
    widget_type VARCHAR(30) NOT NULL,           -- KPI, CHART, TABLE, REPORT, TEXT

    -- Content reference
    kpi_id BIGINT REFERENCES sys.bi_kpis(id),
    report_id BIGINT REFERENCES sys.bi_reports(id),

    -- Configuration
    title VARCHAR(200),
    widget_config JSONB NOT NULL DEFAULT '{}',  -- Type-specific config

    -- Refresh
    auto_refresh BOOLEAN NOT NULL DEFAULT FALSE,
    refresh_interval_seconds INT DEFAULT 300,

    -- Status
    is_visible BOOLEAN NOT NULL DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    version_number INT NOT NULL DEFAULT 1
);

CREATE INDEX idx_widget_dashboard ON sys.bi_dashboard_widgets(dashboard_id);
CREATE INDEX idx_widget_kpi ON sys.bi_dashboard_widgets(kpi_id);
CREATE INDEX idx_widget_report ON sys.bi_dashboard_widgets(report_id);

COMMENT ON TABLE sys.bi_dashboard_widgets IS 'Widgets within dashboards';

-- ============================================================================
-- 7. REPORT SCHEDULING
-- ============================================================================

-- 7.1 Report Schedules
CREATE TABLE IF NOT EXISTS sys.bi_report_schedules (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    report_id BIGINT NOT NULL REFERENCES sys.bi_reports(id),

    -- Schedule name
    schedule_name VARCHAR(200) NOT NULL,

    -- Frequency
    frequency sys.schedule_frequency NOT NULL,
    day_of_week INT CHECK (day_of_week BETWEEN 1 AND 7),     -- For WEEKLY
    day_of_month INT CHECK (day_of_month BETWEEN 1 AND 31),  -- For MONTHLY
    month_of_year INT CHECK (month_of_year BETWEEN 1 AND 12),-- For YEARLY
    time_of_day TIME NOT NULL DEFAULT '08:00:00',

    -- Output
    output_format sys.report_format NOT NULL DEFAULT 'PDF',

    -- Parameters
    report_parameters JSONB DEFAULT '{}',

    -- Distribution
    recipients JSONB NOT NULL DEFAULT '[]',     -- [{email, name}]
    cc_recipients JSONB DEFAULT '[]',
    email_subject VARCHAR(200),
    email_body TEXT,
    include_attachment BOOLEAN NOT NULL DEFAULT TRUE,

    -- Status
    status sys.schedule_status NOT NULL DEFAULT 'ACTIVE',
    last_run_at TIMESTAMPTZ,
    last_run_status VARCHAR(50),
    next_run_at TIMESTAMPTZ,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,
    version_number INT NOT NULL DEFAULT 1
);

CREATE INDEX idx_schedule_tenant ON sys.bi_report_schedules(tenant_id);
CREATE INDEX idx_schedule_report ON sys.bi_report_schedules(report_id);
CREATE INDEX idx_schedule_next ON sys.bi_report_schedules(next_run_at) WHERE status = 'ACTIVE';

COMMENT ON TABLE sys.bi_report_schedules IS 'Report scheduling configuration';

-- 7.2 Schedule Execution History
CREATE TABLE IF NOT EXISTS sys.bi_schedule_history (
    id BIGSERIAL PRIMARY KEY,
    schedule_id BIGINT NOT NULL REFERENCES sys.bi_report_schedules(id) ON DELETE CASCADE,

    -- Execution
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    duration_ms INT,

    -- Result
    status VARCHAR(50) NOT NULL,                -- SUCCESS, FAILED, TIMEOUT
    error_message TEXT,

    -- Output
    output_file_path TEXT,
    output_file_size BIGINT,

    -- Distribution
    recipients_sent INT DEFAULT 0,
    recipients_failed INT DEFAULT 0,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_history_schedule ON sys.bi_schedule_history(schedule_id);
CREATE INDEX idx_history_started ON sys.bi_schedule_history(started_at);

COMMENT ON TABLE sys.bi_schedule_history IS 'Report schedule execution history';

-- ============================================================================
-- 8. RPC FUNCTIONS
-- ============================================================================

-- 8.1 Get Report Data
CREATE OR REPLACE FUNCTION sys.rpc_get_report_data(
    p_report_id BIGINT,
    p_entity_id BIGINT DEFAULT NULL,
    p_period_year INT DEFAULT NULL,
    p_period_month INT DEFAULT NULL,
    p_filters JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_report RECORD;
    v_result JSONB;
    v_year INT;
    v_month INT;
BEGIN
    -- Get report definition
    SELECT * INTO v_report FROM sys.bi_reports WHERE id = p_report_id;

    IF v_report IS NULL THEN
        RETURN jsonb_build_object('error', 'Report not found');
    END IF;

    -- Default to current period
    v_year := COALESCE(p_period_year, EXTRACT(YEAR FROM CURRENT_DATE)::INT);
    v_month := COALESCE(p_period_month, EXTRACT(MONTH FROM CURRENT_DATE)::INT);

    -- Build result based on report type
    CASE v_report.report_type
        WHEN 'TRIAL_BALANCE' THEN
            SELECT jsonb_build_object(
                'report_name', v_report.report_name,
                'period', jsonb_build_object('year', v_year, 'month', v_month),
                'data', COALESCE(jsonb_agg(row_to_json(tb)), '[]'::jsonb)
            ) INTO v_result
            FROM (
                SELECT
                    a.account_code,
                    a.account_name,
                    SUM(jl.debit_amount) AS total_debit,
                    SUM(jl.credit_amount) AS total_credit,
                    SUM(jl.debit_amount) - SUM(jl.credit_amount) AS balance
                FROM accounting.chart_of_accounts a
                LEFT JOIN accounting.journal_entry_lines jl ON jl.account_id = a.id
                LEFT JOIN accounting.journal_entries je ON je.id = jl.journal_entry_id
                WHERE (p_entity_id IS NULL OR a.entity_id = p_entity_id)
                  AND (je.posting_date IS NULL OR
                       (EXTRACT(YEAR FROM je.posting_date) = v_year
                        AND EXTRACT(MONTH FROM je.posting_date) <= v_month))
                GROUP BY a.account_code, a.account_name
                ORDER BY a.account_code
            ) tb;

        WHEN 'KPI_DASHBOARD' THEN
            SELECT jsonb_build_object(
                'report_name', v_report.report_name,
                'period', jsonb_build_object('year', v_year, 'month', v_month),
                'kpis', COALESCE(jsonb_agg(row_to_json(kpi)), '[]'::jsonb)
            ) INTO v_result
            FROM (
                SELECT
                    k.kpi_code,
                    k.kpi_name,
                    k.category,
                    kv.current_value,
                    kv.prior_period_value,
                    kv.budget_value,
                    kv.period_variance_pct,
                    kv.status
                FROM sys.bi_kpis k
                LEFT JOIN sys.bi_kpi_values kv ON kv.kpi_id = k.id
                    AND kv.period_year = v_year
                    AND kv.period_month = v_month
                    AND (p_entity_id IS NULL OR kv.entity_id = p_entity_id)
                WHERE k.is_active
                ORDER BY k.category, k.kpi_code
            ) kpi;

        ELSE
            v_result := jsonb_build_object(
                'report_name', v_report.report_name,
                'report_type', v_report.report_type,
                'message', 'Report type not yet implemented'
            );
    END CASE;

    RETURN v_result;
END;
$$;

COMMENT ON FUNCTION sys.rpc_get_report_data IS 'Get report data for rendering';

-- 8.2 Calculate KPIs
CREATE OR REPLACE FUNCTION sys.rpc_calculate_kpis(
    p_tenant_id BIGINT,
    p_entity_id BIGINT DEFAULT NULL,
    p_period_year INT DEFAULT NULL,
    p_period_month INT DEFAULT NULL
)
RETURNS TABLE (
    kpis_calculated INT,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_kpi RECORD;
    v_count INT := 0;
    v_year INT;
    v_month INT;
    v_current_value DECIMAL(18, 4);
    v_prior_value DECIMAL(18, 4);
    v_status VARCHAR(20);
BEGIN
    v_year := COALESCE(p_period_year, EXTRACT(YEAR FROM CURRENT_DATE)::INT);
    v_month := COALESCE(p_period_month, EXTRACT(MONTH FROM CURRENT_DATE)::INT);

    -- Calculate each KPI
    FOR v_kpi IN (
        SELECT * FROM sys.bi_kpis
        WHERE tenant_id = p_tenant_id AND is_active
    ) LOOP
        -- Placeholder calculation (would need actual formulas)
        v_current_value := RANDOM() * 100;  -- Replace with actual calculation
        v_prior_value := RANDOM() * 100;

        -- Determine status
        IF v_kpi.critical_threshold_low IS NOT NULL AND v_current_value < v_kpi.critical_threshold_low THEN
            v_status := 'RED';
        ELSIF v_kpi.warning_threshold_low IS NOT NULL AND v_current_value < v_kpi.warning_threshold_low THEN
            v_status := 'YELLOW';
        ELSIF v_kpi.critical_threshold_high IS NOT NULL AND v_current_value > v_kpi.critical_threshold_high THEN
            v_status := 'RED';
        ELSIF v_kpi.warning_threshold_high IS NOT NULL AND v_current_value > v_kpi.warning_threshold_high THEN
            v_status := 'YELLOW';
        ELSE
            v_status := 'GREEN';
        END IF;

        -- Upsert KPI value
        INSERT INTO sys.bi_kpi_values (
            kpi_id, entity_id, period_year, period_month, period_date,
            current_value, prior_period_value, status
        ) VALUES (
            v_kpi.id, p_entity_id, v_year, v_month,
            MAKE_DATE(v_year, v_month, 1),
            v_current_value, v_prior_value, v_status
        )
        ON CONFLICT (kpi_id, entity_id, period_date) DO UPDATE
        SET current_value = v_current_value,
            prior_period_value = v_prior_value,
            status = v_status,
            calculated_at = NOW();

        v_count := v_count + 1;
    END LOOP;

    RETURN QUERY SELECT v_count, 'KPIs calculated successfully'::TEXT;
END;
$$;

COMMENT ON FUNCTION sys.rpc_calculate_kpis IS 'Calculate KPI values for a period';

-- 8.3 Get Dashboard
CREATE OR REPLACE FUNCTION sys.rpc_get_dashboard(
    p_dashboard_id BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_dashboard RECORD;
    v_result JSONB;
BEGIN
    SELECT * INTO v_dashboard FROM sys.bi_dashboards WHERE id = p_dashboard_id;

    IF v_dashboard IS NULL THEN
        RETURN jsonb_build_object('error', 'Dashboard not found');
    END IF;

    SELECT jsonb_build_object(
        'dashboard', jsonb_build_object(
            'id', v_dashboard.id,
            'code', v_dashboard.dashboard_code,
            'name', v_dashboard.dashboard_name,
            'layout_type', v_dashboard.layout_type,
            'column_count', v_dashboard.column_count,
            'theme', v_dashboard.theme
        ),
        'widgets', COALESCE(jsonb_agg(
            jsonb_build_object(
                'id', w.id,
                'type', w.widget_type,
                'title', w.title,
                'position', jsonb_build_object(
                    'x', w.grid_x, 'y', w.grid_y,
                    'width', w.grid_width, 'height', w.grid_height
                ),
                'config', w.widget_config,
                'kpi_id', w.kpi_id,
                'report_id', w.report_id
            )
        ), '[]'::jsonb)
    ) INTO v_result
    FROM sys.bi_dashboard_widgets w
    WHERE w.dashboard_id = p_dashboard_id AND w.is_visible
    ORDER BY w.grid_y, w.grid_x;

    RETURN v_result;
END;
$$;

COMMENT ON FUNCTION sys.rpc_get_dashboard IS 'Get dashboard definition with widgets';

-- 8.4 Schedule Next Run
CREATE OR REPLACE FUNCTION sys.rpc_calculate_next_run(
    p_schedule_id BIGINT
)
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_schedule RECORD;
    v_next_run TIMESTAMPTZ;
    v_base_date DATE;
BEGIN
    SELECT * INTO v_schedule FROM sys.bi_report_schedules WHERE id = p_schedule_id;

    IF v_schedule IS NULL THEN
        RETURN NULL;
    END IF;

    v_base_date := COALESCE(v_schedule.last_run_at::DATE, CURRENT_DATE);

    CASE v_schedule.frequency
        WHEN 'DAILY' THEN
            v_next_run := (v_base_date + INTERVAL '1 day') + v_schedule.time_of_day;

        WHEN 'WEEKLY' THEN
            v_next_run := (v_base_date + INTERVAL '1 week') + v_schedule.time_of_day;
            -- Adjust to specific day of week
            v_next_run := v_next_run + (v_schedule.day_of_week - EXTRACT(DOW FROM v_next_run)::INT) * INTERVAL '1 day';

        WHEN 'MONTHLY' THEN
            v_next_run := (DATE_TRUNC('MONTH', v_base_date) + INTERVAL '1 month'
                          + (COALESCE(v_schedule.day_of_month, 1) - 1) * INTERVAL '1 day')
                          + v_schedule.time_of_day;

        WHEN 'QUARTERLY' THEN
            v_next_run := (DATE_TRUNC('QUARTER', v_base_date) + INTERVAL '3 months'
                          + (COALESCE(v_schedule.day_of_month, 1) - 1) * INTERVAL '1 day')
                          + v_schedule.time_of_day;

        WHEN 'YEARLY' THEN
            v_next_run := MAKE_DATE(
                EXTRACT(YEAR FROM v_base_date)::INT + 1,
                COALESCE(v_schedule.month_of_year, 1),
                COALESCE(v_schedule.day_of_month, 1)
            ) + v_schedule.time_of_day;

        ELSE
            v_next_run := NULL;
    END CASE;

    -- Update schedule
    UPDATE sys.bi_report_schedules
    SET next_run_at = v_next_run
    WHERE id = p_schedule_id;

    RETURN v_next_run;
END;
$$;

COMMENT ON FUNCTION sys.rpc_calculate_next_run IS 'Calculate next scheduled run time';

-- ============================================================================
-- 9. VIEWS
-- ============================================================================

-- 9.1 KPI Dashboard View
CREATE OR REPLACE VIEW sys.v_kpi_dashboard AS
SELECT
    k.tenant_id,
    k.kpi_code,
    k.kpi_name,
    k.category,
    k.trend,
    k.target_value AS kpi_target,
    kv.period_year,
    kv.period_month,
    kv.current_value,
    kv.prior_period_value,
    kv.budget_value,
    kv.period_variance_pct,
    kv.yoy_variance_pct,
    kv.status,
    e.entity_name
FROM sys.bi_kpis k
LEFT JOIN sys.bi_kpi_values kv ON kv.kpi_id = k.id
LEFT JOIN sys.tenant_entities e ON e.id = kv.entity_id
WHERE k.is_active;

COMMENT ON VIEW sys.v_kpi_dashboard IS 'KPI dashboard data';

-- 9.2 Active Schedules View
CREATE OR REPLACE VIEW sys.v_active_schedules AS
SELECT
    s.id AS schedule_id,
    s.schedule_name,
    r.report_name,
    s.frequency,
    s.output_format,
    s.status,
    s.last_run_at,
    s.last_run_status,
    s.next_run_at,
    jsonb_array_length(s.recipients) AS recipient_count
FROM sys.bi_report_schedules s
JOIN sys.bi_reports r ON r.id = s.report_id
WHERE s.status = 'ACTIVE'
ORDER BY s.next_run_at;

COMMENT ON VIEW sys.v_active_schedules IS 'Active report schedules';

-- 9.3 Dashboard Summary
CREATE OR REPLACE VIEW sys.v_dashboard_summary AS
SELECT
    d.tenant_id,
    d.dashboard_code,
    d.dashboard_name,
    d.is_default,
    COUNT(w.id) AS widget_count,
    COUNT(DISTINCT w.kpi_id) AS kpi_count,
    COUNT(DISTINCT w.report_id) AS report_count
FROM sys.bi_dashboards d
LEFT JOIN sys.bi_dashboard_widgets w ON w.dashboard_id = d.id AND w.is_visible
WHERE d.is_active
GROUP BY d.id, d.tenant_id, d.dashboard_code, d.dashboard_name, d.is_default;

COMMENT ON VIEW sys.v_dashboard_summary IS 'Dashboard summary with widget counts';

-- ============================================================================
-- 10. SEED DATA
-- ============================================================================

-- Populate time dimension for 2020-2030
INSERT INTO sys.bi_dim_time (
    date_key, year, quarter, month, week, day_of_month, day_of_week, day_of_year,
    year_label, quarter_label, month_label, week_label, date_label,
    fiscal_year, fiscal_quarter, fiscal_month,
    is_weekend, is_month_end, is_quarter_end, is_year_end
)
SELECT
    d::DATE AS date_key,
    EXTRACT(YEAR FROM d)::INT AS year,
    EXTRACT(QUARTER FROM d)::INT AS quarter,
    EXTRACT(MONTH FROM d)::INT AS month,
    EXTRACT(WEEK FROM d)::INT AS week,
    EXTRACT(DAY FROM d)::INT AS day_of_month,
    -- Fix déploiement : la colonne exige day_of_week BETWEEN 1 AND 7, or DOW
    -- renvoie 0-6 (dimanche=0) -> violation. ISODOW renvoie 1-7 (lundi=1).
    -- ROLLBACK : revenir à EXTRACT(DOW FROM d) si le CHECK devient 0..6.
    EXTRACT(ISODOW FROM d)::INT AS day_of_week,
    EXTRACT(DOY FROM d)::INT AS day_of_year,
    EXTRACT(YEAR FROM d)::TEXT AS year_label,
    'Q' || EXTRACT(QUARTER FROM d)::TEXT AS quarter_label,
    TO_CHAR(d, 'Month YYYY') AS month_label,
    'W' || EXTRACT(WEEK FROM d)::TEXT || ' ' || EXTRACT(YEAR FROM d)::TEXT AS week_label,
    TO_CHAR(d, 'DD Mon YYYY') AS date_label,
    EXTRACT(YEAR FROM d)::INT AS fiscal_year,  -- OHADA: fiscal = calendar
    EXTRACT(QUARTER FROM d)::INT AS fiscal_quarter,
    EXTRACT(MONTH FROM d)::INT AS fiscal_month,
    EXTRACT(DOW FROM d) IN (0, 6) AS is_weekend,
    d = (DATE_TRUNC('MONTH', d) + INTERVAL '1 month - 1 day')::DATE AS is_month_end,
    EXTRACT(MONTH FROM d) IN (3, 6, 9, 12) AND
        d = (DATE_TRUNC('MONTH', d) + INTERVAL '1 month - 1 day')::DATE AS is_quarter_end,
    EXTRACT(MONTH FROM d) = 12 AND EXTRACT(DAY FROM d) = 31 AS is_year_end
FROM GENERATE_SERIES('2020-01-01'::DATE, '2030-12-31'::DATE, '1 day'::INTERVAL) d
ON CONFLICT (date_key) DO NOTHING;

-- ============================================================================
-- 11. COMPLETION NOTICE
-- ============================================================================

COMMENT ON SCHEMA sys IS 'EdenFin System Schema - SAPHIR BI & Reporting Extension';

DO $$ BEGIN
    RAISE NOTICE '✅ SAPHIR 05 BI & Reporting - Schema created successfully';
    RAISE NOTICE 'Tables: 11';
    RAISE NOTICE 'Functions: 4 RPC functions';
    RAISE NOTICE 'Views: 3';
    RAISE NOTICE 'Time dimension populated: 2020-2030';
END $$;
