-- ============================================================================
-- Fix integration (Sprint 3) : modele de tenant harmonise sur le socle BIGINT.
--   tenant_id/fiscal_year_id UUID -> BIGINT ; common.tenants -> sys.tenants ;
--   common.fiscal_years -> client_demo.fiscal_exercises. Voir SPRINT3_ONYX.md.
-- ROLLBACK : retablir les types UUID et les references common.* d origine.
-- EDENFIN ONYX: INTEGRATION HUB MODULE
-- ============================================================================
-- Version: 1.0.0
-- Date: 2026-02-11
-- Description: Enterprise Integration Hub for connecting EdenFin to external systems
--   - API endpoints and webhook management
--   - Secure credential storage
--   - Data synchronization jobs
--   - BI/DWH exports
--   - EDI/B2B integrations
--   - Real-time event streaming
-- Dependencies: JASPE (00-09), RUBIS (01-03), SAPHIR (01-05), ONYX (01-06)
-- ============================================================================

-- Create ONYX schema if not exists
CREATE SCHEMA IF NOT EXISTS onyx;

-- ============================================================================
-- SECTION 1: ENUMERATIONS
-- ============================================================================

-- Integration types
CREATE TYPE onyx.integration_type AS ENUM (
    'REST_API',            -- REST API endpoint
    'SOAP_WS',             -- SOAP Web Service
    'GRAPHQL',             -- GraphQL API
    'SFTP',                -- Secure FTP
    'AS2',                 -- AS2 (EDI)
    'WEBHOOK',             -- Webhook (inbound/outbound)
    'DATABASE',            -- Direct database connection
    'MESSAGE_QUEUE',       -- MQ (RabbitMQ, Kafka, etc.)
    'FILE_SHARE',          -- Network file share
    'EMAIL',               -- Email integration (SMTP/IMAP)
    'CUSTOM'               -- Custom integration
);

-- Authentication methods
CREATE TYPE onyx.auth_method AS ENUM (
    'NONE',                -- No authentication
    'API_KEY',             -- API Key in header
    'BASIC',               -- Basic Auth (user:pass)
    'BEARER_TOKEN',        -- Bearer token
    'OAUTH2_CLIENT',       -- OAuth2 Client Credentials
    'OAUTH2_AUTH_CODE',    -- OAuth2 Authorization Code
    'CERTIFICATE',         -- Client certificate (mTLS)
    'HMAC',                -- HMAC signature
    'AWS_SIGV4',           -- AWS Signature V4
    'CUSTOM'               -- Custom authentication
);

-- Sync directions
CREATE TYPE onyx.sync_direction AS ENUM (
    'INBOUND',             -- External → EdenFin
    'OUTBOUND',            -- EdenFin → External
    'BIDIRECTIONAL'        -- Both directions
);

-- Sync status
CREATE TYPE onyx.sync_status AS ENUM (
    'PENDING',
    'RUNNING',
    'COMPLETED',
    'FAILED',
    'CANCELLED',
    'PARTIAL'
);

-- Data format
CREATE TYPE onyx.data_format AS ENUM (
    'JSON',
    'XML',
    'CSV',
    'EXCEL',
    'PDF',
    'EDIFACT',
    'X12',
    'FIXED_WIDTH',
    'PARQUET',
    'AVRO',
    'CUSTOM'
);

-- Webhook event types
CREATE TYPE onyx.webhook_event AS ENUM (
    -- Financial events
    'INVOICE_CREATED',
    'INVOICE_PAID',
    'INVOICE_OVERDUE',
    'PAYMENT_RECEIVED',
    'PAYMENT_FAILED',
    'JOURNAL_POSTED',
    'PERIOD_CLOSED',
    -- Entity events
    'CUSTOMER_CREATED',
    'CUSTOMER_UPDATED',
    'SUPPLIER_CREATED',
    'SUPPLIER_UPDATED',
    'PRODUCT_CREATED',
    'PRODUCT_UPDATED',
    -- HR events
    'EMPLOYEE_HIRED',
    'EMPLOYEE_TERMINATED',
    'PAYROLL_PROCESSED',
    -- Inventory events
    'STOCK_LOW',
    'STOCK_RECEIVED',
    'STOCK_SHIPPED',
    -- Custom
    'CUSTOM'
);

-- Export status
CREATE TYPE onyx.export_status AS ENUM (
    'SCHEDULED',
    'GENERATING',
    'COMPLETED',
    'FAILED',
    'EXPIRED'
);

-- ============================================================================
-- SECTION 2: INTEGRATION ENDPOINTS
-- ============================================================================

-- External system registry
CREATE TABLE onyx.external_systems (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),

    -- System identification
    system_code VARCHAR(50) NOT NULL,
    system_name VARCHAR(200) NOT NULL,
    vendor VARCHAR(200),
    system_type VARCHAR(100), -- ERP, CRM, Bank, Government, etc.

    -- Description
    description TEXT,
    documentation_url VARCHAR(500),

    -- Contact
    contact_name VARCHAR(200),
    contact_email VARCHAR(255),
    support_url VARCHAR(500),

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL,
    updated_at TIMESTAMPTZ,

    UNIQUE(tenant_id, system_code)
);

-- Integration endpoints
CREATE TABLE onyx.integration_endpoints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    external_system_id UUID REFERENCES onyx.external_systems(id),

    -- Endpoint identification
    endpoint_code VARCHAR(50) NOT NULL,
    endpoint_name VARCHAR(200) NOT NULL,
    integration_type onyx.integration_type NOT NULL,

    -- Connection details
    base_url VARCHAR(500),
    port INT,
    path VARCHAR(500),
    environment VARCHAR(50) NOT NULL DEFAULT 'PRODUCTION', -- SANDBOX, STAGING, PRODUCTION

    -- Authentication
    auth_method onyx.auth_method NOT NULL DEFAULT 'NONE',
    credential_id UUID, -- Reference to stored credentials

    -- TLS/SSL
    use_tls BOOLEAN NOT NULL DEFAULT true,
    verify_certificate BOOLEAN NOT NULL DEFAULT true,
    client_certificate_id UUID,

    -- Timeouts
    connection_timeout_ms INT NOT NULL DEFAULT 30000,
    read_timeout_ms INT NOT NULL DEFAULT 60000,
    retry_count INT NOT NULL DEFAULT 3,
    retry_delay_ms INT NOT NULL DEFAULT 1000,

    -- Rate limiting
    rate_limit_requests INT, -- Max requests per period
    rate_limit_period_seconds INT, -- Period duration

    -- Headers
    default_headers JSONB, -- {"Content-Type": "application/json", ...}

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_health_check TIMESTAMPTZ,
    health_status VARCHAR(50),

    -- Metadata
    tags JSONB,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL,
    updated_at TIMESTAMPTZ,

    UNIQUE(tenant_id, endpoint_code)
);

-- API operations for an endpoint
CREATE TABLE onyx.endpoint_operations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    endpoint_id UUID NOT NULL REFERENCES onyx.integration_endpoints(id) ON DELETE CASCADE,

    -- Operation details
    operation_code VARCHAR(50) NOT NULL,
    operation_name VARCHAR(200) NOT NULL,
    http_method VARCHAR(10), -- GET, POST, PUT, DELETE, etc.
    path VARCHAR(500), -- Relative path

    -- Request
    request_format onyx.data_format,
    request_schema JSONB, -- JSON Schema or XSD
    request_template TEXT, -- Template for request body

    -- Response
    response_format onyx.data_format,
    response_schema JSONB,

    -- Mapping
    field_mappings JSONB, -- Maps EdenFin fields to external fields

    -- Validation
    pre_validation_rules JSONB,
    post_validation_rules JSONB,

    -- Transformation
    request_transformer TEXT, -- JSONata or custom transform
    response_transformer TEXT,

    is_active BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(endpoint_id, operation_code)
);

CREATE INDEX idx_endpoints_tenant ON onyx.integration_endpoints(tenant_id);
CREATE INDEX idx_endpoints_active ON onyx.integration_endpoints(tenant_id, is_active);

-- ============================================================================
-- SECTION 3: CREDENTIAL MANAGEMENT
-- ============================================================================

-- Secure credential storage (encrypted at rest)
CREATE TABLE onyx.api_credentials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),

    -- Credential identification
    credential_name VARCHAR(200) NOT NULL,
    auth_method onyx.auth_method NOT NULL,

    -- Encrypted credentials (AES-256-GCM)
    -- In production, use proper key management (AWS KMS, HashiCorp Vault, etc.)
    credentials_encrypted BYTEA NOT NULL,
    encryption_key_id VARCHAR(100), -- Reference to encryption key

    -- OAuth2 specific
    oauth_client_id VARCHAR(255),
    oauth_token_url VARCHAR(500),
    oauth_scope VARCHAR(500),
    oauth_access_token_encrypted BYTEA,
    oauth_refresh_token_encrypted BYTEA,
    oauth_token_expires_at TIMESTAMPTZ,

    -- Certificate specific
    certificate_pem_encrypted BYTEA,
    private_key_encrypted BYTEA,
    certificate_expires_at DATE,

    -- Metadata
    last_used_at TIMESTAMPTZ,
    rotation_due_date DATE,

    is_active BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL,
    updated_at TIMESTAMPTZ,

    UNIQUE(tenant_id, credential_name)
);

-- Credential audit log
CREATE TABLE onyx.credential_audit_log (
    id BIGSERIAL PRIMARY KEY,
    credential_id UUID NOT NULL REFERENCES onyx.api_credentials(id),

    -- Event
    event_type VARCHAR(50) NOT NULL, -- CREATED, ACCESSED, ROTATED, REVOKED
    event_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Actor
    user_id UUID,
    ip_address INET,
    user_agent TEXT,

    -- Context
    endpoint_id UUID,
    operation_id UUID,
    request_id VARCHAR(100),

    -- Details
    details JSONB
);

CREATE INDEX idx_credential_audit_cred ON onyx.credential_audit_log(credential_id);
CREATE INDEX idx_credential_audit_time ON onyx.credential_audit_log(event_timestamp DESC);

-- ============================================================================
-- SECTION 4: SYNCHRONIZATION JOBS
-- ============================================================================

-- Sync job definitions
CREATE TABLE onyx.sync_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    endpoint_id UUID NOT NULL REFERENCES onyx.integration_endpoints(id),

    -- Job identification
    job_code VARCHAR(50) NOT NULL,
    job_name VARCHAR(200) NOT NULL,
    description TEXT,

    -- Sync configuration
    direction onyx.sync_direction NOT NULL,
    entity_type VARCHAR(100) NOT NULL, -- customer, supplier, product, invoice, etc.

    -- Scheduling
    is_scheduled BOOLEAN NOT NULL DEFAULT false,
    cron_expression VARCHAR(100), -- Cron format
    timezone VARCHAR(50) DEFAULT 'UTC',
    next_run_at TIMESTAMPTZ,

    -- Filters
    filter_criteria JSONB, -- {"status": "active", "modified_since": "{{last_sync}}"}

    -- Mapping
    operation_id UUID REFERENCES onyx.endpoint_operations(id),
    field_mappings JSONB, -- Override endpoint operation mappings

    -- Options
    batch_size INT NOT NULL DEFAULT 100,
    fail_on_error BOOLEAN NOT NULL DEFAULT false,
    skip_duplicates BOOLEAN NOT NULL DEFAULT true,
    upsert_mode BOOLEAN NOT NULL DEFAULT true,

    -- Notifications
    notify_on_success BOOLEAN NOT NULL DEFAULT false,
    notify_on_failure BOOLEAN NOT NULL DEFAULT true,
    notification_emails TEXT[],

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_run_at TIMESTAMPTZ,
    last_run_status onyx.sync_status,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL,
    updated_at TIMESTAMPTZ,

    UNIQUE(tenant_id, job_code)
);

-- Sync job executions
CREATE TABLE onyx.sync_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES onyx.sync_jobs(id),

    -- Execution details
    execution_number BIGINT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,

    -- Status
    status onyx.sync_status NOT NULL DEFAULT 'RUNNING',
    status_message TEXT,

    -- Statistics
    records_processed INT NOT NULL DEFAULT 0,
    records_created INT NOT NULL DEFAULT 0,
    records_updated INT NOT NULL DEFAULT 0,
    records_skipped INT NOT NULL DEFAULT 0,
    records_failed INT NOT NULL DEFAULT 0,

    -- Errors
    errors JSONB, -- Array of error details
    error_count INT NOT NULL DEFAULT 0,

    -- Performance
    duration_ms BIGINT,
    api_calls_made INT NOT NULL DEFAULT 0,

    -- Checkpoint
    last_processed_id VARCHAR(255),
    checkpoint_data JSONB,

    -- Trigger
    triggered_by VARCHAR(50) NOT NULL DEFAULT 'SCHEDULE', -- SCHEDULE, MANUAL, WEBHOOK
    triggered_by_user UUID
);

-- Sync execution logs
CREATE TABLE onyx.sync_execution_logs (
    id BIGSERIAL PRIMARY KEY,
    execution_id UUID NOT NULL REFERENCES onyx.sync_executions(id) ON DELETE CASCADE,

    -- Log entry
    log_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    log_level VARCHAR(10) NOT NULL, -- DEBUG, INFO, WARN, ERROR
    message TEXT NOT NULL,

    -- Context
    record_id VARCHAR(255),
    entity_type VARCHAR(100),

    -- Data
    request_data JSONB,
    response_data JSONB,
    error_details JSONB
);

CREATE INDEX idx_sync_jobs_tenant ON onyx.sync_jobs(tenant_id);
CREATE INDEX idx_sync_jobs_next_run ON onyx.sync_jobs(next_run_at) WHERE is_active = true;
CREATE INDEX idx_sync_executions_job ON onyx.sync_executions(job_id);
CREATE INDEX idx_sync_executions_status ON onyx.sync_executions(status);
CREATE INDEX idx_sync_execution_logs_exec ON onyx.sync_execution_logs(execution_id);

-- ============================================================================
-- SECTION 5: WEBHOOKS
-- ============================================================================

-- Webhook configurations (outbound)
CREATE TABLE onyx.webhook_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),

    -- Webhook identification
    webhook_name VARCHAR(200) NOT NULL,
    description TEXT,

    -- Target
    target_url VARCHAR(500) NOT NULL,
    http_method VARCHAR(10) NOT NULL DEFAULT 'POST',

    -- Events
    events onyx.webhook_event[] NOT NULL,

    -- Authentication
    auth_method onyx.auth_method NOT NULL DEFAULT 'NONE',
    credential_id UUID REFERENCES onyx.api_credentials(id),

    -- Signing
    signing_secret_encrypted BYTEA, -- For HMAC signature
    signature_header VARCHAR(100) DEFAULT 'X-Signature-256',

    -- Headers
    custom_headers JSONB,

    -- Payload
    payload_template TEXT, -- Custom payload template
    include_full_entity BOOLEAN NOT NULL DEFAULT true,

    -- Retry
    retry_count INT NOT NULL DEFAULT 3,
    retry_delay_seconds INT NOT NULL DEFAULT 60,

    -- Filters
    filter_conditions JSONB, -- Only trigger when conditions match

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_triggered_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL,
    updated_at TIMESTAMPTZ
);

-- Webhook delivery log
CREATE TABLE onyx.webhook_deliveries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    webhook_id UUID NOT NULL REFERENCES onyx.webhook_configs(id),

    -- Event
    event_type onyx.webhook_event NOT NULL,
    event_id VARCHAR(100), -- ID of the triggering event
    entity_type VARCHAR(100),
    entity_id UUID,

    -- Request
    request_url VARCHAR(500) NOT NULL,
    request_headers JSONB,
    request_body TEXT,
    request_timestamp TIMESTAMPTZ NOT NULL,

    -- Response
    response_status INT,
    response_headers JSONB,
    response_body TEXT,
    response_timestamp TIMESTAMPTZ,

    -- Status
    delivery_status VARCHAR(50) NOT NULL, -- PENDING, DELIVERED, FAILED
    attempt_number INT NOT NULL DEFAULT 1,
    next_retry_at TIMESTAMPTZ,

    -- Error
    error_message TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Webhook subscriptions (inbound)
CREATE TABLE onyx.webhook_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    external_system_id UUID REFERENCES onyx.external_systems(id),

    -- Subscription details
    subscription_name VARCHAR(200) NOT NULL,
    description TEXT,

    -- Endpoint
    endpoint_path VARCHAR(200) NOT NULL, -- /webhooks/stripe, /webhooks/bank
    verification_token VARCHAR(255),

    -- Validation
    signature_header VARCHAR(100),
    signature_algorithm VARCHAR(50), -- HMAC-SHA256, etc.
    signing_secret_encrypted BYTEA,

    -- Processing
    handler_function VARCHAR(200), -- Function to call for processing
    auto_acknowledge BOOLEAN NOT NULL DEFAULT true,

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_received_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL,

    UNIQUE(tenant_id, endpoint_path)
);

-- Inbound webhook log
CREATE TABLE onyx.webhook_received (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID NOT NULL REFERENCES onyx.webhook_subscriptions(id),

    -- Request
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    source_ip INET,
    request_headers JSONB,
    request_body TEXT,

    -- Validation
    signature_valid BOOLEAN,
    validation_error TEXT,

    -- Processing
    processing_status VARCHAR(50) NOT NULL DEFAULT 'PENDING',
    processed_at TIMESTAMPTZ,
    processing_result JSONB,
    error_message TEXT,

    -- Idempotency
    idempotency_key VARCHAR(255)
);

CREATE INDEX idx_webhook_configs_tenant ON onyx.webhook_configs(tenant_id);
CREATE INDEX idx_webhook_deliveries_webhook ON onyx.webhook_deliveries(webhook_id);
CREATE INDEX idx_webhook_deliveries_status ON onyx.webhook_deliveries(delivery_status) WHERE delivery_status = 'PENDING';
CREATE INDEX idx_webhook_received_sub ON onyx.webhook_received(subscription_id);

-- ============================================================================
-- SECTION 6: DATA EXPORTS
-- ============================================================================

-- Export definitions
CREATE TABLE onyx.export_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),

    -- Export identification
    export_code VARCHAR(50) NOT NULL,
    export_name VARCHAR(200) NOT NULL,
    description TEXT,

    -- Data source
    source_type VARCHAR(50) NOT NULL, -- TABLE, VIEW, QUERY
    source_name VARCHAR(200), -- Table or view name
    source_query TEXT, -- Custom SQL query

    -- Format
    output_format onyx.data_format NOT NULL,
    format_options JSONB, -- {"delimiter": ",", "quote": "\"", ...}

    -- Columns
    column_mappings JSONB, -- [{"source": "id", "target": "customer_id", "transform": "..."}, ...]
    include_headers BOOLEAN NOT NULL DEFAULT true,

    -- Filters
    filter_template TEXT, -- WHERE clause template
    default_filters JSONB,

    -- Scheduling
    is_scheduled BOOLEAN NOT NULL DEFAULT false,
    cron_expression VARCHAR(100),
    timezone VARCHAR(50) DEFAULT 'UTC',

    -- Destination
    destination_type VARCHAR(50) NOT NULL DEFAULT 'DOWNLOAD', -- DOWNLOAD, SFTP, S3, EMAIL
    destination_config JSONB,

    -- Retention
    retention_days INT NOT NULL DEFAULT 7,

    -- Notifications
    notify_emails TEXT[],

    is_active BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL,
    updated_at TIMESTAMPTZ,

    UNIQUE(tenant_id, export_code)
);

-- Export executions
CREATE TABLE onyx.export_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    definition_id UUID NOT NULL REFERENCES onyx.export_definitions(id),

    -- Execution
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    status onyx.export_status NOT NULL DEFAULT 'GENERATING',
    status_message TEXT,

    -- Parameters
    parameters JSONB, -- Runtime parameters
    filters_applied JSONB,

    -- Output
    file_name VARCHAR(255),
    file_size_bytes BIGINT,
    file_path VARCHAR(500),
    file_url VARCHAR(500), -- Signed URL for download
    file_url_expires_at TIMESTAMPTZ,
    file_checksum VARCHAR(128),

    -- Statistics
    record_count INT,
    duration_ms BIGINT,

    -- Trigger
    triggered_by VARCHAR(50) NOT NULL DEFAULT 'MANUAL',
    triggered_by_user UUID,

    -- Delivery
    delivered_to VARCHAR(500),
    delivered_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_export_definitions_tenant ON onyx.export_definitions(tenant_id);
CREATE INDEX idx_export_executions_def ON onyx.export_executions(definition_id);
CREATE INDEX idx_export_executions_status ON onyx.export_executions(status);

-- ============================================================================
-- SECTION 7: EVENT STREAMING
-- ============================================================================

-- Event stream configurations
CREATE TABLE onyx.event_streams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),

    -- Stream identification
    stream_name VARCHAR(200) NOT NULL,
    description TEXT,

    -- Target
    target_type VARCHAR(50) NOT NULL, -- KAFKA, RABBITMQ, AWS_KINESIS, AZURE_EVENTHUB
    target_config JSONB NOT NULL, -- Connection details

    -- Events
    event_types onyx.webhook_event[] NOT NULL,

    -- Serialization
    serialization_format onyx.data_format NOT NULL DEFAULT 'JSON',
    schema_registry_url VARCHAR(500),

    -- Partitioning
    partition_key VARCHAR(100), -- Field to use for partitioning

    -- Filtering
    filter_conditions JSONB,

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_event_at TIMESTAMPTZ,
    events_sent_count BIGINT NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL,
    updated_at TIMESTAMPTZ,

    UNIQUE(tenant_id, stream_name)
);

-- Event outbox (for reliable delivery)
CREATE TABLE onyx.event_outbox (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL,

    -- Event
    event_type onyx.webhook_event NOT NULL,
    event_id UUID NOT NULL DEFAULT gen_random_uuid(),
    event_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Aggregate
    aggregate_type VARCHAR(100) NOT NULL,
    aggregate_id UUID NOT NULL,

    -- Payload
    payload JSONB NOT NULL,

    -- Delivery
    delivered BOOLEAN NOT NULL DEFAULT false,
    delivered_at TIMESTAMPTZ,
    delivery_attempts INT NOT NULL DEFAULT 0,
    last_error TEXT
);

CREATE INDEX idx_event_outbox_pending ON onyx.event_outbox(tenant_id, delivered, event_timestamp)
    WHERE delivered = false;

-- ============================================================================
-- SECTION 8: API GATEWAY
-- ============================================================================

-- API keys for external access
CREATE TABLE onyx.api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),

    -- Key identification
    key_name VARCHAR(200) NOT NULL,
    description TEXT,

    -- Key value (hashed)
    key_prefix VARCHAR(10) NOT NULL, -- First 8 chars for identification
    key_hash VARCHAR(128) NOT NULL, -- SHA-512 hash of full key

    -- Permissions
    scopes TEXT[] NOT NULL, -- ["read:customers", "write:invoices", ...]
    allowed_ips INET[], -- IP whitelist

    -- Rate limiting
    rate_limit_requests INT,
    rate_limit_period_seconds INT,

    -- Validity
    expires_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT true,

    -- Usage
    last_used_at TIMESTAMPTZ,
    total_requests BIGINT NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL,

    UNIQUE(tenant_id, key_name)
);

-- API request log
CREATE TABLE onyx.api_request_log (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL,

    -- Request
    request_id VARCHAR(100) NOT NULL,
    request_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    api_key_id UUID REFERENCES onyx.api_keys(id),

    -- Endpoint
    method VARCHAR(10) NOT NULL,
    path VARCHAR(500) NOT NULL,
    query_params JSONB,

    -- Client
    client_ip INET,
    user_agent TEXT,

    -- Response
    response_status INT,
    response_time_ms INT,

    -- Metadata
    request_size_bytes INT,
    response_size_bytes INT
);

CREATE INDEX idx_api_keys_tenant ON onyx.api_keys(tenant_id);
CREATE INDEX idx_api_keys_prefix ON onyx.api_keys(key_prefix);
CREATE INDEX idx_api_request_log_tenant_time ON onyx.api_request_log(tenant_id, request_timestamp DESC);

-- ============================================================================
-- SECTION 9: VIEWS
-- ============================================================================

-- Integration health dashboard
CREATE OR REPLACE VIEW onyx.v_integration_health AS
SELECT
    e.tenant_id,
    e.endpoint_code,
    e.endpoint_name,
    es.system_name,
    e.integration_type,
    e.environment,
    e.is_active,
    e.health_status,
    e.last_health_check,
    COUNT(sj.id) AS sync_jobs_count,
    COUNT(sj.id) FILTER (WHERE sj.last_run_status = 'COMPLETED') AS successful_jobs,
    COUNT(sj.id) FILTER (WHERE sj.last_run_status = 'FAILED') AS failed_jobs,
    MAX(se.completed_at) AS last_sync_time
FROM onyx.integration_endpoints e
LEFT JOIN onyx.external_systems es ON e.external_system_id = es.id
LEFT JOIN onyx.sync_jobs sj ON e.id = sj.endpoint_id
LEFT JOIN onyx.sync_executions se ON sj.id = se.job_id
GROUP BY e.id, e.tenant_id, e.endpoint_code, e.endpoint_name, es.system_name,
         e.integration_type, e.environment, e.is_active, e.health_status, e.last_health_check;

-- Sync job status summary
CREATE OR REPLACE VIEW onyx.v_sync_job_status AS
SELECT
    sj.tenant_id,
    sj.job_code,
    sj.job_name,
    sj.direction,
    sj.entity_type,
    sj.is_scheduled,
    sj.next_run_at,
    sj.last_run_at,
    sj.last_run_status,
    latest.records_processed,
    latest.records_created,
    latest.records_updated,
    latest.records_failed,
    latest.duration_ms,
    latest.error_count,
    CASE
        WHEN sj.last_run_status = 'FAILED' THEN 'Error'
        WHEN sj.is_scheduled AND sj.next_run_at < NOW() THEN 'Overdue'
        WHEN sj.last_run_status = 'COMPLETED' THEN 'Healthy'
        ELSE 'Unknown'
    END AS health_status
FROM onyx.sync_jobs sj
LEFT JOIN LATERAL (
    SELECT *
    FROM onyx.sync_executions
    WHERE job_id = sj.id
    ORDER BY started_at DESC
    LIMIT 1
) latest ON TRUE;

-- Webhook delivery stats
CREATE OR REPLACE VIEW onyx.v_webhook_stats AS
SELECT
    wc.tenant_id,
    wc.id AS webhook_id,
    wc.webhook_name,
    wc.target_url,
    wc.is_active,
    COUNT(wd.id) AS total_deliveries,
    COUNT(wd.id) FILTER (WHERE wd.delivery_status = 'DELIVERED') AS successful,
    COUNT(wd.id) FILTER (WHERE wd.delivery_status = 'FAILED') AS failed,
    COUNT(wd.id) FILTER (WHERE wd.delivery_status = 'PENDING') AS pending,
    AVG(EXTRACT(EPOCH FROM (wd.response_timestamp - wd.request_timestamp)) * 1000)::INT AS avg_response_ms,
    MAX(wd.created_at) AS last_delivery_at
FROM onyx.webhook_configs wc
LEFT JOIN onyx.webhook_deliveries wd ON wc.id = wd.webhook_id
    AND wd.created_at >= NOW() - INTERVAL '7 days'
GROUP BY wc.id, wc.tenant_id, wc.webhook_name, wc.target_url, wc.is_active;

-- Export status summary
CREATE OR REPLACE VIEW onyx.v_export_status AS
SELECT
    ed.tenant_id,
    ed.export_code,
    ed.export_name,
    ed.output_format,
    ed.is_scheduled,
    ed.cron_expression,
    ee.status AS last_status,
    ee.completed_at AS last_completed,
    ee.record_count AS last_record_count,
    ee.file_size_bytes AS last_file_size,
    ee.file_url,
    ee.file_url_expires_at
FROM onyx.export_definitions ed
LEFT JOIN LATERAL (
    SELECT *
    FROM onyx.export_executions
    WHERE definition_id = ed.id
    ORDER BY started_at DESC
    LIMIT 1
) ee ON TRUE;

-- API usage summary
CREATE OR REPLACE VIEW onyx.v_api_usage AS
SELECT
    ak.tenant_id,
    ak.key_name,
    ak.key_prefix,
    ak.is_active,
    ak.expires_at,
    ak.total_requests,
    ak.last_used_at,
    COALESCE(daily.requests_today, 0) AS requests_today,
    COALESCE(daily.avg_response_ms, 0) AS avg_response_ms_today
FROM onyx.api_keys ak
LEFT JOIN LATERAL (
    SELECT
        COUNT(*) AS requests_today,
        AVG(response_time_ms)::INT AS avg_response_ms
    FROM onyx.api_request_log
    WHERE api_key_id = ak.id
      AND request_timestamp >= CURRENT_DATE
) daily ON TRUE;

-- ============================================================================
-- SECTION 10: RPC FUNCTIONS
-- ============================================================================

-- Execute sync job
CREATE OR REPLACE FUNCTION onyx.rpc_execute_sync_job(
    p_job_id UUID,
    p_user_id UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_job RECORD;
    v_execution_id UUID;
    v_execution_number BIGINT;
BEGIN
    -- Get job
    SELECT * INTO v_job FROM onyx.sync_jobs WHERE id = p_job_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Sync job not found: %', p_job_id;
    END IF;

    IF NOT v_job.is_active THEN
        RAISE EXCEPTION 'Sync job is not active: %', v_job.job_code;
    END IF;

    -- Get next execution number
    SELECT COALESCE(MAX(execution_number), 0) + 1
    INTO v_execution_number
    FROM onyx.sync_executions
    WHERE job_id = p_job_id;

    -- Create execution record
    INSERT INTO onyx.sync_executions (
        job_id, execution_number, status,
        triggered_by, triggered_by_user
    ) VALUES (
        p_job_id, v_execution_number, 'RUNNING',
        CASE WHEN p_user_id IS NULL THEN 'SCHEDULE' ELSE 'MANUAL' END,
        p_user_id
    ) RETURNING id INTO v_execution_id;

    -- Update job last run
    UPDATE onyx.sync_jobs
    SET last_run_at = NOW(),
        last_run_status = 'RUNNING'
    WHERE id = p_job_id;

    -- Note: Actual sync logic would be implemented in application code
    -- This function just creates the execution record

    RETURN v_execution_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Complete sync execution
CREATE OR REPLACE FUNCTION onyx.rpc_complete_sync_execution(
    p_execution_id UUID,
    p_status onyx.sync_status,
    p_stats JSONB
) RETURNS VOID AS $$
DECLARE
    v_execution RECORD;
    v_duration_ms BIGINT;
BEGIN
    -- Get execution
    SELECT * INTO v_execution FROM onyx.sync_executions WHERE id = p_execution_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Sync execution not found: %', p_execution_id;
    END IF;

    -- Calculate duration
    v_duration_ms := EXTRACT(EPOCH FROM (NOW() - v_execution.started_at)) * 1000;

    -- Update execution
    UPDATE onyx.sync_executions
    SET completed_at = NOW(),
        status = p_status,
        records_processed = COALESCE((p_stats->>'records_processed')::INT, 0),
        records_created = COALESCE((p_stats->>'records_created')::INT, 0),
        records_updated = COALESCE((p_stats->>'records_updated')::INT, 0),
        records_skipped = COALESCE((p_stats->>'records_skipped')::INT, 0),
        records_failed = COALESCE((p_stats->>'records_failed')::INT, 0),
        errors = p_stats->'errors',
        error_count = COALESCE(jsonb_array_length(p_stats->'errors'), 0),
        duration_ms = v_duration_ms,
        api_calls_made = COALESCE((p_stats->>'api_calls')::INT, 0),
        checkpoint_data = p_stats->'checkpoint'
    WHERE id = p_execution_id;

    -- Update job status
    UPDATE onyx.sync_jobs
    SET last_run_status = p_status
    WHERE id = v_execution.job_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger webhook
CREATE OR REPLACE FUNCTION onyx.rpc_trigger_webhook(
    p_event_type onyx.webhook_event,
    p_entity_type VARCHAR,
    p_entity_id UUID,
    p_payload JSONB
) RETURNS INT AS $$
DECLARE
    v_webhook RECORD;
    v_delivery_count INT := 0;
BEGIN
    -- Find matching webhooks
    FOR v_webhook IN
        SELECT *
        FROM onyx.webhook_configs
        WHERE is_active = true
          AND p_event_type = ANY(events)
    LOOP
        -- Check filter conditions
        IF v_webhook.filter_conditions IS NOT NULL THEN
            -- Skip if filter doesn't match (simplified check)
            CONTINUE WHEN NOT (p_payload @> v_webhook.filter_conditions);
        END IF;

        -- Create delivery record
        INSERT INTO onyx.webhook_deliveries (
            webhook_id, event_type, event_id, entity_type, entity_id,
            request_url, request_body, request_timestamp, delivery_status
        ) VALUES (
            v_webhook.id, p_event_type, gen_random_uuid()::TEXT, p_entity_type, p_entity_id,
            v_webhook.target_url, p_payload::TEXT, NOW(), 'PENDING'
        );

        v_delivery_count := v_delivery_count + 1;
    END LOOP;

    -- Also add to event outbox for streaming
    INSERT INTO onyx.event_outbox (
        tenant_id, event_type, aggregate_type, aggregate_id, payload
    )
    SELECT DISTINCT
        wc.tenant_id, p_event_type, p_entity_type, p_entity_id, p_payload
    FROM onyx.webhook_configs wc
    WHERE wc.is_active = true
      AND p_event_type = ANY(wc.events)
    LIMIT 1;

    RETURN v_delivery_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Generate API key
CREATE OR REPLACE FUNCTION onyx.rpc_generate_api_key(
    p_tenant_id UUID,
    p_key_name VARCHAR,
    p_scopes TEXT[],
    p_expires_days INT DEFAULT NULL,
    p_user_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_key_id UUID;
    v_raw_key VARCHAR(64);
    v_key_prefix VARCHAR(10);
    v_key_hash VARCHAR(128);
BEGIN
    -- Generate random key
    v_raw_key := encode(gen_random_bytes(32), 'hex');
    v_key_prefix := substring(v_raw_key, 1, 8);
    v_key_hash := encode(sha512(v_raw_key::bytea), 'hex');

    -- Insert key record
    INSERT INTO onyx.api_keys (
        tenant_id, key_name, key_prefix, key_hash, scopes,
        expires_at, created_by
    ) VALUES (
        p_tenant_id, p_key_name, v_key_prefix, v_key_hash, p_scopes,
        CASE WHEN p_expires_days IS NOT NULL THEN NOW() + (p_expires_days || ' days')::INTERVAL END,
        COALESCE(p_user_id, '00000000-0000-0000-0000-000000000000'::UUID)
    ) RETURNING id INTO v_key_id;

    -- Return key details (raw key only shown once!)
    RETURN jsonb_build_object(
        'key_id', v_key_id,
        'api_key', v_raw_key,
        'key_prefix', v_key_prefix,
        'scopes', p_scopes,
        'expires_at', CASE WHEN p_expires_days IS NOT NULL
            THEN NOW() + (p_expires_days || ' days')::INTERVAL END,
        'warning', 'Store this key securely. It will not be shown again.'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Validate API key
CREATE OR REPLACE FUNCTION onyx.rpc_validate_api_key(
    p_api_key VARCHAR
) RETURNS JSONB AS $$
DECLARE
    v_key RECORD;
    v_key_hash VARCHAR(128);
BEGIN
    -- Calculate hash
    v_key_hash := encode(sha512(p_api_key::bytea), 'hex');

    -- Find key
    SELECT * INTO v_key
    FROM onyx.api_keys
    WHERE key_hash = v_key_hash;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('valid', false, 'error', 'Invalid API key');
    END IF;

    IF NOT v_key.is_active THEN
        RETURN jsonb_build_object('valid', false, 'error', 'API key is deactivated');
    END IF;

    IF v_key.expires_at IS NOT NULL AND v_key.expires_at < NOW() THEN
        RETURN jsonb_build_object('valid', false, 'error', 'API key has expired');
    END IF;

    -- Update usage
    UPDATE onyx.api_keys
    SET last_used_at = NOW(),
        total_requests = total_requests + 1
    WHERE id = v_key.id;

    RETURN jsonb_build_object(
        'valid', true,
        'key_id', v_key.id,
        'tenant_id', v_key.tenant_id,
        'scopes', v_key.scopes,
        'rate_limit', jsonb_build_object(
            'requests', v_key.rate_limit_requests,
            'period_seconds', v_key.rate_limit_period_seconds
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get integration dashboard
CREATE OR REPLACE FUNCTION onyx.rpc_get_integration_dashboard(
    p_tenant_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'endpoints', (
            SELECT jsonb_build_object(
                'total', COUNT(*),
                'active', COUNT(*) FILTER (WHERE is_active = true),
                'healthy', COUNT(*) FILTER (WHERE health_status = 'HEALTHY'),
                'unhealthy', COUNT(*) FILTER (WHERE health_status IN ('UNHEALTHY', 'ERROR'))
            )
            FROM onyx.integration_endpoints
            WHERE tenant_id = p_tenant_id
        ),
        'sync_jobs', (
            SELECT jsonb_build_object(
                'total', COUNT(*),
                'scheduled', COUNT(*) FILTER (WHERE is_scheduled = true),
                'last_24h_runs', (
                    SELECT COUNT(*) FROM onyx.sync_executions se
                    JOIN onyx.sync_jobs sj ON se.job_id = sj.id
                    WHERE sj.tenant_id = p_tenant_id
                      AND se.started_at >= NOW() - INTERVAL '24 hours'
                ),
                'failed_24h', (
                    SELECT COUNT(*) FROM onyx.sync_executions se
                    JOIN onyx.sync_jobs sj ON se.job_id = sj.id
                    WHERE sj.tenant_id = p_tenant_id
                      AND se.started_at >= NOW() - INTERVAL '24 hours'
                      AND se.status = 'FAILED'
                )
            )
            FROM onyx.sync_jobs
            WHERE tenant_id = p_tenant_id
        ),
        'webhooks', (
            SELECT jsonb_build_object(
                'outbound', (
                    SELECT COUNT(*) FROM onyx.webhook_configs
                    WHERE tenant_id = p_tenant_id AND is_active = true
                ),
                'inbound', (
                    SELECT COUNT(*) FROM onyx.webhook_subscriptions
                    WHERE tenant_id = p_tenant_id AND is_active = true
                ),
                'pending_deliveries', (
                    SELECT COUNT(*) FROM onyx.webhook_deliveries wd
                    JOIN onyx.webhook_configs wc ON wd.webhook_id = wc.id
                    WHERE wc.tenant_id = p_tenant_id
                      AND wd.delivery_status = 'PENDING'
                )
            )
        ),
        'api_keys', (
            SELECT jsonb_build_object(
                'total', COUNT(*),
                'active', COUNT(*) FILTER (WHERE is_active = true),
                'expiring_soon', COUNT(*) FILTER (
                    WHERE expires_at BETWEEN NOW() AND NOW() + INTERVAL '30 days'
                )
            )
            FROM onyx.api_keys
            WHERE tenant_id = p_tenant_id
        ),
        'exports', (
            SELECT jsonb_build_object(
                'definitions', COUNT(*),
                'scheduled', COUNT(*) FILTER (WHERE is_scheduled = true),
                'recent_exports', (
                    SELECT COUNT(*) FROM onyx.export_executions ee
                    JOIN onyx.export_definitions ed ON ee.definition_id = ed.id
                    WHERE ed.tenant_id = p_tenant_id
                      AND ee.started_at >= NOW() - INTERVAL '7 days'
                )
            )
            FROM onyx.export_definitions
            WHERE tenant_id = p_tenant_id
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- SECTION 11: TRIGGERS FOR EVENT OUTBOX
-- ============================================================================

-- Trigger function for automatic event publishing
CREATE OR REPLACE FUNCTION onyx.fn_publish_entity_event()
RETURNS TRIGGER AS $$
DECLARE
    v_event_type onyx.webhook_event;
    v_payload JSONB;
BEGIN
    -- Determine event type based on operation
    IF TG_OP = 'INSERT' THEN
        v_event_type := (TG_ARGV[0] || '_CREATED')::onyx.webhook_event;
        v_payload := to_jsonb(NEW);
    ELSIF TG_OP = 'UPDATE' THEN
        v_event_type := (TG_ARGV[0] || '_UPDATED')::onyx.webhook_event;
        v_payload := jsonb_build_object(
            'old', to_jsonb(OLD),
            'new', to_jsonb(NEW),
            'changed_fields', (
                SELECT jsonb_agg(key)
                FROM jsonb_each(to_jsonb(NEW))
                WHERE to_jsonb(NEW)->key != to_jsonb(OLD)->key
            )
        );
    END IF;

    -- Add to outbox
    INSERT INTO onyx.event_outbox (
        tenant_id, event_type, aggregate_type, aggregate_id, payload
    ) VALUES (
        NEW.tenant_id,
        v_event_type,
        TG_TABLE_NAME,
        NEW.id,
        v_payload
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- COMPLETION NOTICE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '================================================================';
    RAISE NOTICE 'EdenFin ONYX Integration Hub Module installed successfully';
    RAISE NOTICE '================================================================';
    RAISE NOTICE 'Tables created: 18';
    RAISE NOTICE '  - external_systems, integration_endpoints, endpoint_operations';
    RAISE NOTICE '  - api_credentials, credential_audit_log';
    RAISE NOTICE '  - sync_jobs, sync_executions, sync_execution_logs';
    RAISE NOTICE '  - webhook_configs, webhook_deliveries, webhook_subscriptions, webhook_received';
    RAISE NOTICE '  - export_definitions, export_executions';
    RAISE NOTICE '  - event_streams, event_outbox';
    RAISE NOTICE '  - api_keys, api_request_log';
    RAISE NOTICE 'Views created: 5';
    RAISE NOTICE 'RPC Functions created: 6';
    RAISE NOTICE '================================================================';
END $$;
