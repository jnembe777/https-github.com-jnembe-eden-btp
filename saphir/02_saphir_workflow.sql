-- ============================================================================
-- EDENFIN SAPHIR — SCRIPT 02 : WORKFLOW ENGINE
-- PostgreSQL 15+ (Supabase)
-- ============================================================================
-- Tier SAPHIR : ETI (50-250 employés)
-- Fonctionnalités ajoutées :
--   - Définition de workflows d'approbation
--   - Multi-niveau avec seuils de montant
--   - Délégation et escalade
--   - Historique complet des approbations
--   - Notifications automatiques
-- ============================================================================
-- Dépend de : JASPE (00-09), RUBIS (01-03)
-- ============================================================================

-- ============================================================================
-- 1. ENUM TYPES
-- ============================================================================

-- Workflow status
DO $$ BEGIN
    CREATE TYPE sys.workflow_status AS ENUM (
        'DRAFT',            -- Definition not active
        'ACTIVE',           -- Ready for use
        'SUSPENDED',        -- Temporarily disabled
        'ARCHIVED'          -- No longer used
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Instance status
DO $$ BEGIN
    CREATE TYPE sys.workflow_instance_status AS ENUM (
        'PENDING',          -- Waiting for approval
        'IN_PROGRESS',      -- Some approvals received
        'APPROVED',         -- Fully approved
        'REJECTED',         -- Rejected at some step
        'CANCELLED',        -- Cancelled by initiator
        'EXPIRED'           -- Timed out
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Approval decision
DO $$ BEGIN
    CREATE TYPE sys.approval_decision AS ENUM (
        'PENDING',          -- Not yet decided
        'APPROVED',         -- Approved
        'REJECTED',         -- Rejected
        'DELEGATED',        -- Delegated to another user
        'ESCALATED',        -- Auto-escalated due to timeout
        'SKIPPED'           -- Skipped (optional step)
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Approver type
DO $$ BEGIN
    CREATE TYPE sys.approver_type AS ENUM (
        'USER',             -- Specific user
        'ROLE',             -- Any user with role
        'HIERARCHY',        -- Direct manager
        'DEPARTMENT_HEAD',  -- Department head
        'ENTITY_MANAGER',   -- Entity manager
        'CUSTOM'            -- Custom logic
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Approval rule
DO $$ BEGIN
    CREATE TYPE sys.approval_rule AS ENUM (
        'ANY',              -- Any one approver
        'ALL',              -- All approvers must approve
        'MAJORITY',         -- >50% must approve
        'FIRST'             -- First response wins
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Entity types for workflow
DO $$ BEGIN
    CREATE TYPE sys.workflow_entity_type AS ENUM (
        'INVOICE',          -- Customer/vendor invoice
        'PAYMENT',          -- Payment request
        'JOURNAL_ENTRY',    -- Manual journal entry
        'PURCHASE_ORDER',   -- Purchase order
        'EXPENSE_REPORT',   -- Employee expense
        'CONTRACT',         -- Contract approval
        'BUDGET_REQUEST',   -- Budget modification
        'LEAVE_REQUEST',    -- Employee leave
        'CUSTOM'            -- Custom entity
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================================
-- 2. WORKFLOW DEFINITIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS sys.workflow_definitions (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),

    -- Identification
    workflow_code VARCHAR(50) NOT NULL,
    workflow_name VARCHAR(200) NOT NULL,
    description TEXT,

    -- Scope
    entity_type sys.workflow_entity_type NOT NULL,
    entity_id BIGINT,                           -- NULL = all, or specific entity

    -- Trigger conditions (JSON)
    trigger_conditions JSONB NOT NULL DEFAULT '{}',
    -- Example: {"amount_min": 1000000, "amount_max": null, "type": ["STANDARD"]}

    -- Settings
    is_mandatory BOOLEAN NOT NULL DEFAULT TRUE, -- Must pass through workflow
    allow_self_approval BOOLEAN NOT NULL DEFAULT FALSE,
    parallel_steps BOOLEAN NOT NULL DEFAULT FALSE, -- Steps can run in parallel

    -- Timeouts
    timeout_hours INT NOT NULL DEFAULT 48,      -- Overall timeout
    reminder_hours INT NOT NULL DEFAULT 24,     -- Send reminder after X hours

    -- Status
    status sys.workflow_status NOT NULL DEFAULT 'DRAFT',
    version INT NOT NULL DEFAULT 1,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,
    deleted_at TIMESTAMPTZ,
    deleted_by BIGINT,
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_workflow_code UNIQUE (tenant_id, workflow_code)
);

CREATE INDEX idx_workflow_def_tenant ON sys.workflow_definitions(tenant_id);
CREATE INDEX idx_workflow_def_entity ON sys.workflow_definitions(entity_type);
CREATE INDEX idx_workflow_def_status ON sys.workflow_definitions(status);

COMMENT ON TABLE sys.workflow_definitions IS 'Workflow definitions for approval processes (SAPHIR)';

-- ============================================================================
-- 3. WORKFLOW STEPS
-- ============================================================================

CREATE TABLE IF NOT EXISTS sys.workflow_steps (
    id BIGSERIAL PRIMARY KEY,
    workflow_id BIGINT NOT NULL REFERENCES sys.workflow_definitions(id) ON DELETE CASCADE,

    -- Step order
    step_order INT NOT NULL,
    step_name VARCHAR(100) NOT NULL,
    description TEXT,

    -- Approver configuration
    approver_type sys.approver_type NOT NULL,
    approver_id BIGINT,                         -- User ID or Role ID depending on type
    approval_rule sys.approval_rule NOT NULL DEFAULT 'ANY',

    -- Conditions
    amount_threshold_min DECIMAL(18, 2),        -- Step applies if amount >= min
    amount_threshold_max DECIMAL(18, 2),        -- Step applies if amount <= max
    condition_expression JSONB,                 -- Additional conditions

    -- Timing
    sla_hours INT NOT NULL DEFAULT 24,          -- Expected completion time
    auto_escalate BOOLEAN NOT NULL DEFAULT TRUE,
    escalation_to BIGINT,                       -- User ID for escalation

    -- Options
    is_optional BOOLEAN NOT NULL DEFAULT FALSE, -- Can be skipped
    allow_delegation BOOLEAN NOT NULL DEFAULT TRUE,
    require_comments BOOLEAN NOT NULL DEFAULT FALSE,

    -- Notifications
    notify_on_pending BOOLEAN NOT NULL DEFAULT TRUE,
    notify_on_complete BOOLEAN NOT NULL DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_workflow_step UNIQUE (workflow_id, step_order)
);

CREATE INDEX idx_workflow_steps_workflow ON sys.workflow_steps(workflow_id);

COMMENT ON TABLE sys.workflow_steps IS 'Steps within workflow definitions';

-- ============================================================================
-- 4. WORKFLOW INSTANCES
-- ============================================================================

CREATE TABLE IF NOT EXISTS sys.workflow_instances (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    workflow_id BIGINT NOT NULL REFERENCES sys.workflow_definitions(id),

    -- Entity being approved
    entity_type sys.workflow_entity_type NOT NULL,
    entity_id BIGINT NOT NULL,
    entity_reference VARCHAR(100),              -- Human-readable reference

    -- Amount (for threshold checking)
    amount DECIMAL(18, 2),
    currency VARCHAR(3),

    -- Progress
    current_step_id BIGINT REFERENCES sys.workflow_steps(id),
    current_step_order INT NOT NULL DEFAULT 1,

    -- Status
    status sys.workflow_instance_status NOT NULL DEFAULT 'PENDING',

    -- Timing
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    due_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,

    -- Initiator
    started_by BIGINT NOT NULL,

    -- Final outcome
    final_decision sys.approval_decision,
    final_comments TEXT,

    -- Context (additional data)
    metadata JSONB DEFAULT '{}',

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    version_number INT NOT NULL DEFAULT 1
);

CREATE INDEX idx_workflow_inst_tenant ON sys.workflow_instances(tenant_id);
CREATE INDEX idx_workflow_inst_entity ON sys.workflow_instances(entity_type, entity_id);
CREATE INDEX idx_workflow_inst_status ON sys.workflow_instances(status);
CREATE INDEX idx_workflow_inst_started_by ON sys.workflow_instances(started_by);
CREATE INDEX idx_workflow_inst_current_step ON sys.workflow_instances(current_step_id);

COMMENT ON TABLE sys.workflow_instances IS 'Active workflow instances for documents';

-- ============================================================================
-- 5. APPROVALS
-- ============================================================================

CREATE TABLE IF NOT EXISTS sys.approvals (
    id BIGSERIAL PRIMARY KEY,
    workflow_instance_id BIGINT NOT NULL REFERENCES sys.workflow_instances(id) ON DELETE CASCADE,
    step_id BIGINT NOT NULL REFERENCES sys.workflow_steps(id),

    -- Approver
    approver_id BIGINT NOT NULL REFERENCES sys.users(id),
    approver_role_id BIGINT,                    -- If approved via role

    -- Decision
    decision sys.approval_decision NOT NULL DEFAULT 'PENDING',
    comments TEXT,

    -- Delegation
    delegated_from BIGINT REFERENCES sys.users(id),
    delegated_to BIGINT REFERENCES sys.users(id),

    -- Timing
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reminded_at TIMESTAMPTZ,
    decided_at TIMESTAMPTZ,
    due_at TIMESTAMPTZ,

    -- Audit trail
    ip_address INET,
    user_agent TEXT,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_approval UNIQUE (workflow_instance_id, step_id, approver_id)
);

CREATE INDEX idx_approvals_instance ON sys.approvals(workflow_instance_id);
CREATE INDEX idx_approvals_approver ON sys.approvals(approver_id);
CREATE INDEX idx_approvals_decision ON sys.approvals(decision);
CREATE INDEX idx_approvals_pending ON sys.approvals(approver_id, decision) WHERE decision = 'PENDING';

COMMENT ON TABLE sys.approvals IS 'Individual approval records within workflow instances';

-- ============================================================================
-- 6. DELEGATIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS sys.workflow_delegations (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),

    -- Delegator
    from_user_id BIGINT NOT NULL REFERENCES sys.users(id),

    -- Delegate
    to_user_id BIGINT NOT NULL REFERENCES sys.users(id),

    -- Scope
    workflow_id BIGINT REFERENCES sys.workflow_definitions(id),  -- NULL = all workflows
    entity_type sys.workflow_entity_type,                        -- NULL = all types

    -- Validity
    valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_to DATE NOT NULL,
    reason VARCHAR(500),

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT chk_delegation_dates CHECK (valid_to >= valid_from)
);

CREATE INDEX idx_delegations_from ON sys.workflow_delegations(from_user_id);
CREATE INDEX idx_delegations_to ON sys.workflow_delegations(to_user_id);
CREATE INDEX idx_delegations_active ON sys.workflow_delegations(is_active, valid_from, valid_to);

COMMENT ON TABLE sys.workflow_delegations IS 'Approval delegation (out of office)';

-- ============================================================================
-- 7. WORKFLOW HISTORY
-- ============================================================================

CREATE TABLE IF NOT EXISTS sys.workflow_history (
    id BIGSERIAL PRIMARY KEY,
    workflow_instance_id BIGINT NOT NULL REFERENCES sys.workflow_instances(id) ON DELETE CASCADE,

    -- Event
    event_type VARCHAR(50) NOT NULL,            -- STARTED, STEP_COMPLETED, APPROVED, REJECTED, etc.
    event_description TEXT,

    -- Step (if applicable)
    step_id BIGINT REFERENCES sys.workflow_steps(id),
    step_name VARCHAR(100),

    -- Actor
    actor_id BIGINT REFERENCES sys.users(id),
    actor_name VARCHAR(200),

    -- Before/After state
    old_status sys.workflow_instance_status,
    new_status sys.workflow_instance_status,

    -- Additional data
    event_data JSONB,

    -- Timing
    event_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_workflow_history_instance ON sys.workflow_history(workflow_instance_id);
CREATE INDEX idx_workflow_history_event ON sys.workflow_history(event_type);

COMMENT ON TABLE sys.workflow_history IS 'Complete audit trail of workflow events';

-- ============================================================================
-- 8. RPC FUNCTIONS
-- ============================================================================

-- 8.1 Find applicable workflow
CREATE OR REPLACE FUNCTION sys.rpc_find_workflow(
    p_tenant_id BIGINT,
    p_entity_type sys.workflow_entity_type,
    p_amount DECIMAL(18, 2) DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_workflow_id BIGINT;
BEGIN
    SELECT id INTO v_workflow_id
    FROM sys.workflow_definitions
    WHERE tenant_id = p_tenant_id
      AND entity_type = p_entity_type
      AND status = 'ACTIVE'
      AND deleted_at IS NULL
      AND (
          trigger_conditions IS NULL
          OR trigger_conditions = '{}'
          OR (
              (trigger_conditions->>'amount_min' IS NULL OR p_amount >= (trigger_conditions->>'amount_min')::DECIMAL)
              AND (trigger_conditions->>'amount_max' IS NULL OR p_amount <= (trigger_conditions->>'amount_max')::DECIMAL)
          )
      )
    ORDER BY
        CASE WHEN trigger_conditions->>'amount_min' IS NOT NULL THEN 1 ELSE 2 END,
        (trigger_conditions->>'amount_min')::DECIMAL DESC NULLS LAST
    LIMIT 1;

    RETURN v_workflow_id;
END;
$$;

COMMENT ON FUNCTION sys.rpc_find_workflow IS 'Find applicable workflow for entity type and amount';

-- 8.2 Start workflow
CREATE OR REPLACE FUNCTION sys.rpc_start_workflow(
    p_tenant_id BIGINT,
    p_entity_type sys.workflow_entity_type,
    p_entity_id BIGINT,
    p_entity_reference VARCHAR(100),
    p_amount DECIMAL(18, 2) DEFAULT NULL,
    p_currency VARCHAR(3) DEFAULT 'XAF',
    p_metadata JSONB DEFAULT '{}',
    p_started_by BIGINT DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_workflow_id BIGINT;
    v_instance_id BIGINT;
    v_first_step RECORD;
    v_due_at TIMESTAMPTZ;
    v_user_id BIGINT;
BEGIN
    v_user_id := COALESCE(p_started_by, current_setting('app.current_user_id', TRUE)::BIGINT);

    -- Find applicable workflow
    v_workflow_id := sys.rpc_find_workflow(p_tenant_id, p_entity_type, p_amount);

    IF v_workflow_id IS NULL THEN
        -- No workflow required
        RETURN NULL;
    END IF;

    -- Get first applicable step
    SELECT * INTO v_first_step
    FROM sys.workflow_steps
    WHERE workflow_id = v_workflow_id
      AND (amount_threshold_min IS NULL OR p_amount >= amount_threshold_min)
      AND (amount_threshold_max IS NULL OR p_amount <= amount_threshold_max)
    ORDER BY step_order
    LIMIT 1;

    IF v_first_step IS NULL THEN
        -- No applicable steps
        RETURN NULL;
    END IF;

    -- Calculate due date
    SELECT NOW() + (timeout_hours * INTERVAL '1 hour') INTO v_due_at
    FROM sys.workflow_definitions
    WHERE id = v_workflow_id;

    -- Create instance
    INSERT INTO sys.workflow_instances (
        tenant_id, workflow_id, entity_type, entity_id, entity_reference,
        amount, currency, current_step_id, current_step_order,
        status, due_at, started_by, metadata
    ) VALUES (
        p_tenant_id, v_workflow_id, p_entity_type, p_entity_id, p_entity_reference,
        p_amount, p_currency, v_first_step.id, v_first_step.step_order,
        'PENDING', v_due_at, v_user_id, p_metadata
    )
    RETURNING id INTO v_instance_id;

    -- Create approval requests for first step
    PERFORM sys.rpc_create_approval_requests(v_instance_id, v_first_step.id);

    -- Log history
    INSERT INTO sys.workflow_history (
        workflow_instance_id, event_type, event_description,
        step_id, step_name, actor_id, new_status, event_data
    ) VALUES (
        v_instance_id, 'STARTED', 'Workflow started',
        v_first_step.id, v_first_step.step_name, v_user_id, 'PENDING',
        jsonb_build_object('amount', p_amount, 'currency', p_currency)
    );

    RETURN v_instance_id;
END;
$$;

COMMENT ON FUNCTION sys.rpc_start_workflow IS 'Start a new workflow instance for an entity';

-- 8.3 Create approval requests
CREATE OR REPLACE FUNCTION sys.rpc_create_approval_requests(
    p_instance_id BIGINT,
    p_step_id BIGINT
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_step RECORD;
    v_instance RECORD;
    v_approvers BIGINT[];
    v_approver_id BIGINT;
    v_count INT := 0;
    v_due_at TIMESTAMPTZ;
BEGIN
    -- Get step and instance details
    SELECT * INTO v_step FROM sys.workflow_steps WHERE id = p_step_id;
    SELECT * INTO v_instance FROM sys.workflow_instances WHERE id = p_instance_id;

    -- Calculate due date for this step
    v_due_at := NOW() + (v_step.sla_hours * INTERVAL '1 hour');

    -- Determine approvers based on type
    CASE v_step.approver_type
        WHEN 'USER' THEN
            v_approvers := ARRAY[v_step.approver_id];

        WHEN 'ROLE' THEN
            SELECT ARRAY_AGG(ur.user_id) INTO v_approvers
            FROM sys.user_roles ur
            WHERE ur.role_id = v_step.approver_id
              AND ur.tenant_id = v_instance.tenant_id;

        WHEN 'HIERARCHY' THEN
            -- Get direct manager of initiator
            SELECT manager_id INTO v_approvers[1]
            FROM sys.users
            WHERE id = v_instance.started_by;

        ELSE
            -- Default to configured approver
            v_approvers := ARRAY[v_step.approver_id];
    END CASE;

    -- Check for delegations and create requests
    FOREACH v_approver_id IN ARRAY v_approvers
    LOOP
        -- Check for active delegation
        DECLARE
            v_delegate_id BIGINT;
        BEGIN
            SELECT to_user_id INTO v_delegate_id
            FROM sys.workflow_delegations
            WHERE from_user_id = v_approver_id
              AND is_active = TRUE
              AND CURRENT_DATE BETWEEN valid_from AND valid_to
              AND (workflow_id IS NULL OR workflow_id = v_instance.workflow_id)
            LIMIT 1;

            -- Use delegate if found
            IF v_delegate_id IS NOT NULL THEN
                INSERT INTO sys.approvals (
                    workflow_instance_id, step_id, approver_id,
                    delegated_from, due_at
                ) VALUES (
                    p_instance_id, p_step_id, v_delegate_id,
                    v_approver_id, v_due_at
                )
                ON CONFLICT DO NOTHING;
            ELSE
                INSERT INTO sys.approvals (
                    workflow_instance_id, step_id, approver_id, due_at
                ) VALUES (
                    p_instance_id, p_step_id, v_approver_id, v_due_at
                )
                ON CONFLICT DO NOTHING;
            END IF;

            v_count := v_count + 1;
        END;
    END LOOP;

    RETURN v_count;
END;
$$;

COMMENT ON FUNCTION sys.rpc_create_approval_requests IS 'Create approval requests for a workflow step';

-- 8.4 Record approval decision
CREATE OR REPLACE FUNCTION sys.rpc_approve(
    p_instance_id BIGINT,
    p_decision sys.approval_decision,
    p_comments TEXT DEFAULT NULL,
    p_approver_id BIGINT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id BIGINT;
    v_approval RECORD;
    v_step RECORD;
    v_instance RECORD;
    v_all_approved BOOLEAN;
    v_any_rejected BOOLEAN;
    v_next_step RECORD;
BEGIN
    v_user_id := COALESCE(p_approver_id, current_setting('app.current_user_id', TRUE)::BIGINT);

    -- Get pending approval for this user
    SELECT a.*, s.approval_rule, s.step_name
    INTO v_approval
    FROM sys.approvals a
    JOIN sys.workflow_steps s ON s.id = a.step_id
    WHERE a.workflow_instance_id = p_instance_id
      AND a.approver_id = v_user_id
      AND a.decision = 'PENDING';

    IF v_approval IS NULL THEN
        RAISE EXCEPTION 'No pending approval found for user %', v_user_id;
    END IF;

    -- Record decision
    UPDATE sys.approvals
    SET decision = p_decision,
        comments = p_comments,
        decided_at = NOW(),
        ip_address = inet_client_addr()
    WHERE id = v_approval.id;

    -- Log history
    INSERT INTO sys.workflow_history (
        workflow_instance_id, event_type, event_description,
        step_id, step_name, actor_id, event_data
    ) VALUES (
        p_instance_id,
        CASE p_decision WHEN 'APPROVED' THEN 'STEP_APPROVED' ELSE 'STEP_REJECTED' END,
        p_comments,
        v_approval.step_id, v_approval.step_name, v_user_id,
        jsonb_build_object('decision', p_decision)
    );

    -- Check if step is complete based on approval rule
    SELECT
        BOOL_AND(decision = 'APPROVED') FILTER (WHERE decision IN ('APPROVED', 'REJECTED')),
        BOOL_OR(decision = 'REJECTED')
    INTO v_all_approved, v_any_rejected
    FROM sys.approvals
    WHERE workflow_instance_id = p_instance_id
      AND step_id = v_approval.step_id;

    -- Handle rejection
    IF v_any_rejected AND v_approval.approval_rule != 'MAJORITY' THEN
        UPDATE sys.workflow_instances
        SET status = 'REJECTED',
            completed_at = NOW(),
            final_decision = 'REJECTED',
            final_comments = p_comments
        WHERE id = p_instance_id;

        INSERT INTO sys.workflow_history (
            workflow_instance_id, event_type, event_description,
            actor_id, old_status, new_status
        ) VALUES (
            p_instance_id, 'WORKFLOW_REJECTED', 'Workflow rejected',
            v_user_id, 'PENDING', 'REJECTED'
        );

        RETURN TRUE;
    END IF;

    -- Check if we can advance to next step
    IF (v_approval.approval_rule = 'ANY' AND p_decision = 'APPROVED')
       OR (v_approval.approval_rule = 'ALL' AND v_all_approved)
       OR (v_approval.approval_rule = 'FIRST' AND p_decision IN ('APPROVED', 'REJECTED'))
    THEN
        -- Get instance
        SELECT * INTO v_instance FROM sys.workflow_instances WHERE id = p_instance_id;

        -- Find next step
        SELECT * INTO v_next_step
        FROM sys.workflow_steps
        WHERE workflow_id = v_instance.workflow_id
          AND step_order > v_instance.current_step_order
          AND (amount_threshold_min IS NULL OR v_instance.amount >= amount_threshold_min)
          AND (amount_threshold_max IS NULL OR v_instance.amount <= amount_threshold_max)
        ORDER BY step_order
        LIMIT 1;

        IF v_next_step IS NOT NULL THEN
            -- Advance to next step
            UPDATE sys.workflow_instances
            SET current_step_id = v_next_step.id,
                current_step_order = v_next_step.step_order,
                status = 'IN_PROGRESS',
                updated_at = NOW()
            WHERE id = p_instance_id;

            -- Create approval requests for next step
            PERFORM sys.rpc_create_approval_requests(p_instance_id, v_next_step.id);

            INSERT INTO sys.workflow_history (
                workflow_instance_id, event_type, event_description,
                step_id, step_name, actor_id
            ) VALUES (
                p_instance_id, 'STEP_ADVANCED', 'Advanced to next step',
                v_next_step.id, v_next_step.step_name, v_user_id
            );
        ELSE
            -- No more steps - workflow complete
            UPDATE sys.workflow_instances
            SET status = 'APPROVED',
                completed_at = NOW(),
                final_decision = 'APPROVED'
            WHERE id = p_instance_id;

            INSERT INTO sys.workflow_history (
                workflow_instance_id, event_type, event_description,
                actor_id, old_status, new_status
            ) VALUES (
                p_instance_id, 'WORKFLOW_APPROVED', 'Workflow fully approved',
                v_user_id, 'IN_PROGRESS', 'APPROVED'
            );
        END IF;
    END IF;

    RETURN TRUE;
END;
$$;

COMMENT ON FUNCTION sys.rpc_approve IS 'Record approval decision for a workflow instance';

-- 8.5 Get pending approvals for user
CREATE OR REPLACE FUNCTION sys.rpc_get_pending_approvals(
    p_user_id BIGINT
)
RETURNS TABLE (
    approval_id BIGINT,
    instance_id BIGINT,
    workflow_name VARCHAR(200),
    entity_type sys.workflow_entity_type,
    entity_reference VARCHAR(100),
    amount DECIMAL(18, 2),
    currency VARCHAR(3),
    step_name VARCHAR(100),
    requested_at TIMESTAMPTZ,
    due_at TIMESTAMPTZ,
    is_overdue BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        a.id AS approval_id,
        wi.id AS instance_id,
        wd.workflow_name,
        wi.entity_type,
        wi.entity_reference,
        wi.amount,
        wi.currency,
        ws.step_name,
        a.requested_at,
        a.due_at,
        a.due_at < NOW() AS is_overdue
    FROM sys.approvals a
    JOIN sys.workflow_instances wi ON wi.id = a.workflow_instance_id
    JOIN sys.workflow_definitions wd ON wd.id = wi.workflow_id
    JOIN sys.workflow_steps ws ON ws.id = a.step_id
    WHERE a.approver_id = p_user_id
      AND a.decision = 'PENDING'
      AND wi.status IN ('PENDING', 'IN_PROGRESS')
    ORDER BY a.due_at ASC;
END;
$$;

COMMENT ON FUNCTION sys.rpc_get_pending_approvals IS 'Get list of pending approvals for a user';

-- ============================================================================
-- 9. VIEWS
-- ============================================================================

-- 9.1 Workflow summary
CREATE OR REPLACE VIEW sys.v_workflow_summary AS
SELECT
    wd.id AS workflow_id,
    wd.tenant_id,
    wd.workflow_code,
    wd.workflow_name,
    wd.entity_type,
    wd.status,
    COUNT(DISTINCT ws.id) AS step_count,
    COUNT(DISTINCT wi.id) FILTER (WHERE wi.status = 'PENDING') AS pending_count,
    COUNT(DISTINCT wi.id) FILTER (WHERE wi.status = 'APPROVED') AS approved_count,
    COUNT(DISTINCT wi.id) FILTER (WHERE wi.status = 'REJECTED') AS rejected_count
FROM sys.workflow_definitions wd
LEFT JOIN sys.workflow_steps ws ON ws.workflow_id = wd.id
LEFT JOIN sys.workflow_instances wi ON wi.workflow_id = wd.id
WHERE wd.deleted_at IS NULL
GROUP BY wd.id, wd.tenant_id, wd.workflow_code, wd.workflow_name, wd.entity_type, wd.status;

COMMENT ON VIEW sys.v_workflow_summary IS 'Summary of workflow definitions and instance counts';

-- 9.2 Pending approvals by user
CREATE OR REPLACE VIEW sys.v_pending_approvals AS
SELECT
    a.approver_id,
    -- Fix déploiement : sys.users n'a pas de colonne display_name (mais
    -- first_name/last_name). ROLLBACK : rétablir u.display_name si la colonne
    -- est réintroduite dans sys.users.
    (u.first_name || ' ' || u.last_name) AS approver_name,
    COUNT(*) AS pending_count,
    COUNT(*) FILTER (WHERE a.due_at < NOW()) AS overdue_count,
    MIN(a.due_at) AS earliest_due
FROM sys.approvals a
JOIN sys.users u ON u.id = a.approver_id
JOIN sys.workflow_instances wi ON wi.id = a.workflow_instance_id
WHERE a.decision = 'PENDING'
  AND wi.status IN ('PENDING', 'IN_PROGRESS')
GROUP BY a.approver_id, u.first_name, u.last_name;

COMMENT ON VIEW sys.v_pending_approvals IS 'Pending approval counts by user';

-- 9.3 Workflow instances detail
CREATE OR REPLACE VIEW sys.v_workflow_instances_detail AS
SELECT
    wi.id AS instance_id,
    wi.tenant_id,
    wd.workflow_name,
    wi.entity_type,
    wi.entity_id,
    wi.entity_reference,
    wi.amount,
    wi.currency,
    wi.status,
    ws.step_name AS current_step,
    wi.started_at,
    wi.due_at,
    wi.completed_at,
    (su.first_name || ' ' || su.last_name) AS started_by_name,
    EXTRACT(EPOCH FROM (COALESCE(wi.completed_at, NOW()) - wi.started_at)) / 3600 AS hours_elapsed
FROM sys.workflow_instances wi
JOIN sys.workflow_definitions wd ON wd.id = wi.workflow_id
JOIN sys.workflow_steps ws ON ws.id = wi.current_step_id
JOIN sys.users su ON su.id = wi.started_by;

COMMENT ON VIEW sys.v_workflow_instances_detail IS 'Detailed view of workflow instances';

-- ============================================================================
-- 10. SEED DATA - SAMPLE WORKFLOWS
-- ============================================================================

-- Note: In production, workflows are created per tenant via admin UI
-- This is just for demonstration

COMMENT ON TABLE sys.workflow_definitions IS 'SAPHIR Workflow Engine - Approval Workflows';
