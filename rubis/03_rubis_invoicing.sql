-- ============================================================================
-- EDENFIN RUBIS — SCRIPT 03 : INVOICING MODULE
-- PostgreSQL 15+ (Supabase)
-- ============================================================================
-- Invoicing system with analytical distribution for RUBIS tier
-- Depends on: 01_rubis_multicompany_schema.sql, 02_rubis_analytical_rpc.sql
-- ============================================================================

-- ============================================================================
-- 1. ENUM TYPES
-- ============================================================================

-- Invoice type
CREATE TYPE sys.invoice_type AS ENUM (
    'SALES',            -- Facture de vente
    'PURCHASE',         -- Facture d'achat
    'CREDIT_NOTE',      -- Avoir
    'DEBIT_NOTE',       -- Note de debit
    'PROFORMA'          -- Facture proforma
);

-- Invoice status
CREATE TYPE sys.invoice_status AS ENUM (
    'DRAFT',            -- Brouillon
    'VALIDATED',        -- Validee
    'SENT',             -- Envoyee
    'PARTIALLY_PAID',   -- Partiellement payee
    'PAID',             -- Payee
    'OVERDUE',          -- En retard
    'CANCELLED',        -- Annulee
    'DISPUTED'          -- Litige
);

-- Payment method
CREATE TYPE sys.payment_method AS ENUM (
    'CASH',             -- Especes
    'BANK_TRANSFER',    -- Virement bancaire
    'CHECK',            -- Cheque
    'MOBILE_MONEY',     -- Mobile Money
    'CARD',             -- Carte bancaire
    'DIRECT_DEBIT',     -- Prelevement
    'COMPENSATION'      -- Compensation
);

-- ============================================================================
-- 2. CORE INVOICE TABLES
-- ============================================================================

-- 2.1 INVOICES (Sales & Purchase)
CREATE TABLE sys.invoices (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),

    -- Invoice identification
    invoice_type sys.invoice_type NOT NULL,
    invoice_number VARCHAR(30) NOT NULL,
    invoice_date DATE NOT NULL,
    due_date DATE NOT NULL,
    reference VARCHAR(100),                 -- External reference (PO number, etc.)

    -- Partner
    partner_id BIGINT NOT NULL,             -- FK to partners table in client schema
    partner_name VARCHAR(200) NOT NULL,     -- Denormalized for history
    partner_address TEXT,
    partner_vat_number VARCHAR(50),

    -- Related documents
    original_invoice_id BIGINT REFERENCES sys.invoices(id),  -- For credit notes
    proforma_id BIGINT REFERENCES sys.invoices(id),          -- For invoices from proforma

    -- Currency
    currency_code CHAR(3) NOT NULL DEFAULT 'XAF',
    exchange_rate DECIMAL(12,6) NOT NULL DEFAULT 1.0,

    -- Amounts (in invoice currency)
    subtotal_ht DECIMAL(18,2) NOT NULL DEFAULT 0,
    discount_amount DECIMAL(18,2) NOT NULL DEFAULT 0,
    total_ht DECIMAL(18,2) NOT NULL DEFAULT 0,
    total_tva DECIMAL(18,2) NOT NULL DEFAULT 0,
    total_ttc DECIMAL(18,2) NOT NULL DEFAULT 0,

    -- Amounts (in base currency XAF)
    base_subtotal_ht DECIMAL(18,2) NOT NULL DEFAULT 0,
    base_total_tva DECIMAL(18,2) NOT NULL DEFAULT 0,
    base_total_ttc DECIMAL(18,2) NOT NULL DEFAULT 0,

    -- Payment tracking
    amount_paid DECIMAL(18,2) NOT NULL DEFAULT 0,
    amount_remaining DECIMAL(18,2) GENERATED ALWAYS AS (total_ttc - amount_paid) STORED,
    last_payment_date DATE,

    -- Status and workflow
    status sys.invoice_status NOT NULL DEFAULT 'DRAFT',
    validated_at TIMESTAMPTZ,
    validated_by BIGINT,
    sent_at TIMESTAMPTZ,
    sent_by BIGINT,
    cancelled_at TIMESTAMPTZ,
    cancelled_by BIGINT,
    cancellation_reason TEXT,

    -- Accounting
    journal_entry_id BIGINT,                -- FK to journal_entries when posted
    is_posted BOOLEAN NOT NULL DEFAULT FALSE,
    posted_at TIMESTAMPTZ,

    -- Analytical default (applied to all lines without specific allocation)
    default_analytical_value_id BIGINT REFERENCES sys.analytical_values(id),

    -- Terms and notes
    payment_terms TEXT,
    internal_notes TEXT,
    public_notes TEXT,

    -- Attachments (GED references)
    attachments JSONB DEFAULT '[]',

    -- Audit columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,
    deleted_at TIMESTAMPTZ,
    deleted_by BIGINT,
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_invoice_number UNIQUE (tenant_id, entity_id, invoice_type, invoice_number),
    CONSTRAINT chk_amounts_positive CHECK (
        subtotal_ht >= 0 AND
        total_ht >= 0 AND
        total_tva >= 0 AND
        total_ttc >= 0 AND
        amount_paid >= 0
    ),
    CONSTRAINT chk_due_date CHECK (due_date >= invoice_date)
);

CREATE INDEX idx_invoices_tenant ON sys.invoices(tenant_id, entity_id);
CREATE INDEX idx_invoices_type ON sys.invoices(invoice_type);
CREATE INDEX idx_invoices_status ON sys.invoices(status);
CREATE INDEX idx_invoices_date ON sys.invoices(invoice_date);
CREATE INDEX idx_invoices_due_date ON sys.invoices(due_date) WHERE status NOT IN ('PAID', 'CANCELLED');
CREATE INDEX idx_invoices_partner ON sys.invoices(partner_id);
CREATE INDEX idx_invoices_number ON sys.invoices(invoice_number);
CREATE INDEX idx_invoices_overdue ON sys.invoices(due_date, amount_remaining)
    WHERE status NOT IN ('PAID', 'CANCELLED') AND amount_remaining > 0;

COMMENT ON TABLE sys.invoices IS 'Factures de vente et d''achat (RUBIS)';

-- 2.2 INVOICE_LINES
CREATE TABLE sys.invoice_lines (
    id BIGSERIAL PRIMARY KEY,
    invoice_id BIGINT NOT NULL REFERENCES sys.invoices(id) ON DELETE CASCADE,
    line_number INT NOT NULL,

    -- Product/Service
    product_id BIGINT,                      -- FK to products (if applicable)
    product_code VARCHAR(50),
    description TEXT NOT NULL,
    unit VARCHAR(20),

    -- Quantities and prices
    quantity DECIMAL(18,4) NOT NULL DEFAULT 1,
    unit_price_ht DECIMAL(18,4) NOT NULL,
    discount_percent DECIMAL(5,2) DEFAULT 0,
    discount_amount DECIMAL(18,2) DEFAULT 0,

    -- Calculated amounts
    line_subtotal_ht DECIMAL(18,2) NOT NULL,
    line_total_ht DECIMAL(18,2) GENERATED ALWAYS AS (
        line_subtotal_ht - discount_amount
    ) STORED,

    -- Tax
    tax_code_id BIGINT,                     -- FK to common.tax_codes
    tax_rate DECIMAL(5,2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(18,2) NOT NULL DEFAULT 0,
    line_total_ttc DECIMAL(18,2) GENERATED ALWAYS AS (
        line_subtotal_ht - discount_amount + tax_amount
    ) STORED,

    -- Accounting
    account_number VARCHAR(10) NOT NULL,    -- OHADA account
    account_id BIGINT,                      -- FK to chart_of_accounts

    -- Analytical distribution
    analytical_value_id BIGINT REFERENCES sys.analytical_values(id),
    distribution_template_id BIGINT REFERENCES sys.analytical_distribution_templates(id),
    analytical_distribution JSONB,          -- [{axis_id, value_id, percentage, amount}]

    -- Audit columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,

    CONSTRAINT uq_invoice_line UNIQUE (invoice_id, line_number),
    CONSTRAINT chk_line_amounts CHECK (
        quantity > 0 AND
        unit_price_ht >= 0 AND
        line_subtotal_ht >= 0
    )
);

CREATE INDEX idx_invoice_lines_invoice ON sys.invoice_lines(invoice_id);
CREATE INDEX idx_invoice_lines_product ON sys.invoice_lines(product_id) WHERE product_id IS NOT NULL;
CREATE INDEX idx_invoice_lines_account ON sys.invoice_lines(account_number);
CREATE INDEX idx_invoice_lines_analytical ON sys.invoice_lines(analytical_value_id) WHERE analytical_value_id IS NOT NULL;

COMMENT ON TABLE sys.invoice_lines IS 'Lignes de factures avec imputation analytique';

-- 2.3 INVOICE_TAX_SUMMARY
CREATE TABLE sys.invoice_tax_summary (
    id BIGSERIAL PRIMARY KEY,
    invoice_id BIGINT NOT NULL REFERENCES sys.invoices(id) ON DELETE CASCADE,
    tax_code_id BIGINT,
    tax_rate DECIMAL(5,2) NOT NULL,
    base_amount DECIMAL(18,2) NOT NULL,
    tax_amount DECIMAL(18,2) NOT NULL,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_invoice_tax UNIQUE (invoice_id, tax_rate)
);

CREATE INDEX idx_invoice_tax_invoice ON sys.invoice_tax_summary(invoice_id);

COMMENT ON TABLE sys.invoice_tax_summary IS 'Resume TVA par taux pour chaque facture';

-- 2.4 INVOICE_PAYMENTS
CREATE TABLE sys.invoice_payments (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),

    -- Payment identification
    payment_number VARCHAR(30) NOT NULL,
    payment_date DATE NOT NULL,
    value_date DATE,

    -- Invoice link
    invoice_id BIGINT NOT NULL REFERENCES sys.invoices(id),

    -- Payment details
    payment_method sys.payment_method NOT NULL,
    amount DECIMAL(18,2) NOT NULL CHECK (amount > 0),
    currency_code CHAR(3) NOT NULL DEFAULT 'XAF',
    exchange_rate DECIMAL(12,6) NOT NULL DEFAULT 1.0,
    base_amount DECIMAL(18,2) NOT NULL,     -- Amount in base currency

    -- Bank details
    bank_account_id BIGINT,                 -- FK to bank accounts
    bank_reference VARCHAR(100),
    check_number VARCHAR(50),
    mobile_reference VARCHAR(50),

    -- Accounting
    journal_entry_id BIGINT,
    is_posted BOOLEAN NOT NULL DEFAULT FALSE,
    posted_at TIMESTAMPTZ,

    -- Status
    is_cancelled BOOLEAN NOT NULL DEFAULT FALSE,
    cancelled_at TIMESTAMPTZ,
    cancelled_by BIGINT,
    cancellation_reason TEXT,

    -- Notes
    notes TEXT,

    -- Audit columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ,
    updated_by BIGINT,
    version_number INT NOT NULL DEFAULT 1,

    CONSTRAINT uq_payment_number UNIQUE (tenant_id, entity_id, payment_number)
);

CREATE INDEX idx_payments_tenant ON sys.invoice_payments(tenant_id, entity_id);
CREATE INDEX idx_payments_invoice ON sys.invoice_payments(invoice_id);
CREATE INDEX idx_payments_date ON sys.invoice_payments(payment_date);
CREATE INDEX idx_payments_method ON sys.invoice_payments(payment_method);

COMMENT ON TABLE sys.invoice_payments IS 'Paiements des factures';

-- 2.5 INVOICE_REMINDERS
CREATE TABLE sys.invoice_reminders (
    id BIGSERIAL PRIMARY KEY,
    invoice_id BIGINT NOT NULL REFERENCES sys.invoices(id),
    reminder_level INT NOT NULL CHECK (reminder_level BETWEEN 1 AND 3),
    reminder_date DATE NOT NULL,
    sent_at TIMESTAMPTZ,
    sent_by BIGINT,
    sent_method VARCHAR(20),                -- EMAIL, LETTER, PHONE
    response_date DATE,
    response_notes TEXT,
    next_action_date DATE,

    -- Fees
    late_fee_amount DECIMAL(18,2) DEFAULT 0,
    late_fee_posted BOOLEAN DEFAULT FALSE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL DEFAULT 0
);

CREATE INDEX idx_reminders_invoice ON sys.invoice_reminders(invoice_id);
CREATE INDEX idx_reminders_date ON sys.invoice_reminders(reminder_date);

COMMENT ON TABLE sys.invoice_reminders IS 'Relances clients';

-- ============================================================================
-- 3. SEQUENCES FOR INVOICE NUMBERS
-- ============================================================================

-- Sequence table for flexible numbering
CREATE TABLE sys.invoice_sequences (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
    entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),
    invoice_type sys.invoice_type NOT NULL,
    fiscal_year INT NOT NULL,
    prefix VARCHAR(10) NOT NULL,
    current_number BIGINT NOT NULL DEFAULT 0,
    number_format VARCHAR(50) NOT NULL DEFAULT '{PREFIX}{YEAR}-{NUMBER:6}',

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,

    CONSTRAINT uq_sequence UNIQUE (tenant_id, entity_id, invoice_type, fiscal_year)
);

COMMENT ON TABLE sys.invoice_sequences IS 'Sequences de numerotation des factures';

-- ============================================================================
-- 4. TRIGGERS AND FUNCTIONS
-- ============================================================================

-- 4.1 Generate invoice number
CREATE OR REPLACE FUNCTION sys.fn_generate_invoice_number()
RETURNS TRIGGER AS $$
DECLARE
    v_seq sys.invoice_sequences;
    v_year INT;
    v_number BIGINT;
    v_result VARCHAR(30);
BEGIN
    IF NEW.invoice_number IS NOT NULL THEN
        RETURN NEW;
    END IF;

    v_year := EXTRACT(YEAR FROM NEW.invoice_date);

    -- Get or create sequence
    INSERT INTO sys.invoice_sequences (tenant_id, entity_id, invoice_type, fiscal_year, prefix, current_number)
    VALUES (
        NEW.tenant_id,
        NEW.entity_id,
        NEW.invoice_type,
        v_year,
        CASE NEW.invoice_type
            WHEN 'SALES' THEN 'FV'
            WHEN 'PURCHASE' THEN 'FA'
            WHEN 'CREDIT_NOTE' THEN 'AV'
            WHEN 'DEBIT_NOTE' THEN 'ND'
            WHEN 'PROFORMA' THEN 'PF'
        END,
        0
    )
    ON CONFLICT (tenant_id, entity_id, invoice_type, fiscal_year)
    DO UPDATE SET current_number = sys.invoice_sequences.current_number + 1
    RETURNING * INTO v_seq;

    -- Update if we just inserted
    IF v_seq.current_number = 0 THEN
        UPDATE sys.invoice_sequences
        SET current_number = 1
        WHERE id = v_seq.id
        RETURNING current_number INTO v_number;
    ELSE
        v_number := v_seq.current_number;
    END IF;

    -- Format number
    NEW.invoice_number := v_seq.prefix || '-' || v_year || '-' || LPAD(v_number::TEXT, 6, '0');

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_invoice_number
    BEFORE INSERT ON sys.invoices
    FOR EACH ROW
    EXECUTE FUNCTION sys.fn_generate_invoice_number();

-- 4.2 Generate payment number
CREATE OR REPLACE FUNCTION sys.fn_generate_payment_number()
RETURNS TRIGGER AS $$
DECLARE
    v_year INT;
    v_seq INT;
BEGIN
    IF NEW.payment_number IS NOT NULL THEN
        RETURN NEW;
    END IF;

    v_year := EXTRACT(YEAR FROM NEW.payment_date);

    SELECT COALESCE(MAX(
        CAST(SUBSTRING(payment_number FROM 10) AS INT)
    ), 0) + 1
    INTO v_seq
    FROM sys.invoice_payments
    WHERE tenant_id = NEW.tenant_id
      AND entity_id = NEW.entity_id
      AND payment_number LIKE 'PAY-' || v_year || '-%';

    NEW.payment_number := 'PAY-' || v_year || '-' || LPAD(v_seq::TEXT, 6, '0');

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_payment_number
    BEFORE INSERT ON sys.invoice_payments
    FOR EACH ROW
    EXECUTE FUNCTION sys.fn_generate_payment_number();

-- 4.3 Update invoice amounts on line change
CREATE OR REPLACE FUNCTION sys.fn_update_invoice_totals()
RETURNS TRIGGER AS $$
DECLARE
    v_invoice_id BIGINT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_invoice_id := OLD.invoice_id;
    ELSE
        v_invoice_id := NEW.invoice_id;
    END IF;

    -- Recalculate invoice totals
    UPDATE sys.invoices
    SET
        subtotal_ht = (
            SELECT COALESCE(SUM(line_subtotal_ht), 0)
            FROM sys.invoice_lines
            WHERE invoice_id = v_invoice_id
        ),
        discount_amount = (
            SELECT COALESCE(SUM(discount_amount), 0)
            FROM sys.invoice_lines
            WHERE invoice_id = v_invoice_id
        ),
        total_ht = (
            SELECT COALESCE(SUM(line_total_ht), 0)
            FROM sys.invoice_lines
            WHERE invoice_id = v_invoice_id
        ),
        total_tva = (
            SELECT COALESCE(SUM(tax_amount), 0)
            FROM sys.invoice_lines
            WHERE invoice_id = v_invoice_id
        ),
        total_ttc = (
            SELECT COALESCE(SUM(line_total_ttc), 0)
            FROM sys.invoice_lines
            WHERE invoice_id = v_invoice_id
        ),
        updated_at = NOW()
    WHERE id = v_invoice_id;

    -- Update base currency amounts
    UPDATE sys.invoices
    SET
        base_subtotal_ht = total_ht * exchange_rate,
        base_total_tva = total_tva * exchange_rate,
        base_total_ttc = total_ttc * exchange_rate
    WHERE id = v_invoice_id;

    -- Recalculate tax summary
    DELETE FROM sys.invoice_tax_summary WHERE invoice_id = v_invoice_id;

    INSERT INTO sys.invoice_tax_summary (invoice_id, tax_code_id, tax_rate, base_amount, tax_amount)
    SELECT
        invoice_id,
        tax_code_id,
        tax_rate,
        SUM(line_total_ht),
        SUM(tax_amount)
    FROM sys.invoice_lines
    WHERE invoice_id = v_invoice_id
    GROUP BY invoice_id, tax_code_id, tax_rate;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_invoice_totals
    AFTER INSERT OR UPDATE OR DELETE ON sys.invoice_lines
    FOR EACH ROW
    EXECUTE FUNCTION sys.fn_update_invoice_totals();

-- 4.4 Update invoice paid amount on payment
CREATE OR REPLACE FUNCTION sys.fn_update_invoice_paid()
RETURNS TRIGGER AS $$
DECLARE
    v_invoice_id BIGINT;
    v_total_paid DECIMAL(18,2);
    v_total_ttc DECIMAL(18,2);
    v_new_status sys.invoice_status;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_invoice_id := OLD.invoice_id;
    ELSE
        v_invoice_id := NEW.invoice_id;
    END IF;

    -- Calculate total paid
    SELECT COALESCE(SUM(amount), 0) INTO v_total_paid
    FROM sys.invoice_payments
    WHERE invoice_id = v_invoice_id
      AND is_cancelled = FALSE;

    -- Get invoice total
    SELECT total_ttc INTO v_total_ttc
    FROM sys.invoices
    WHERE id = v_invoice_id;

    -- Determine new status
    IF v_total_paid >= v_total_ttc THEN
        v_new_status := 'PAID';
    ELSIF v_total_paid > 0 THEN
        v_new_status := 'PARTIALLY_PAID';
    ELSE
        -- Keep current status if no payment
        SELECT status INTO v_new_status
        FROM sys.invoices
        WHERE id = v_invoice_id;
    END IF;

    -- Update invoice
    UPDATE sys.invoices
    SET
        amount_paid = v_total_paid,
        last_payment_date = (
            SELECT MAX(payment_date)
            FROM sys.invoice_payments
            WHERE invoice_id = v_invoice_id AND is_cancelled = FALSE
        ),
        status = v_new_status,
        updated_at = NOW()
    WHERE id = v_invoice_id;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_invoice_paid
    AFTER INSERT OR UPDATE OR DELETE ON sys.invoice_payments
    FOR EACH ROW
    EXECUTE FUNCTION sys.fn_update_invoice_paid();

-- 4.5 Apply analytical distribution on line insert/update
CREATE OR REPLACE FUNCTION sys.fn_apply_line_analytical()
RETURNS TRIGGER AS $$
DECLARE
    v_invoice sys.invoices;
    v_template sys.analytical_distribution_templates;
    v_lines RECORD;
    v_distribution JSONB := '[]';
BEGIN
    -- Get invoice
    SELECT * INTO v_invoice
    FROM sys.invoices
    WHERE id = NEW.invoice_id;

    -- Apply distribution template if specified
    IF NEW.distribution_template_id IS NOT NULL THEN
        SELECT * INTO v_template
        FROM sys.analytical_distribution_templates
        WHERE id = NEW.distribution_template_id;

        IF v_template IS NOT NULL THEN
            SELECT jsonb_agg(
                jsonb_build_object(
                    'axis_id', av.axis_id,
                    'value_id', dl.analytical_value_id,
                    'value_code', av.value_code,
                    'percentage', dl.distribution_percentage,
                    'amount', ROUND(NEW.line_total_ht * dl.distribution_percentage / 100, 2)
                )
            ) INTO v_distribution
            FROM sys.analytical_distribution_lines dl
            JOIN sys.analytical_values av ON av.id = dl.analytical_value_id
            WHERE dl.template_id = NEW.distribution_template_id;

            NEW.analytical_distribution := v_distribution;
        END IF;
    ELSIF NEW.analytical_value_id IS NOT NULL THEN
        -- Single analytical value - 100%
        SELECT jsonb_build_array(
            jsonb_build_object(
                'axis_id', av.axis_id,
                'value_id', NEW.analytical_value_id,
                'value_code', av.value_code,
                'percentage', 100,
                'amount', NEW.line_total_ht
            )
        ) INTO v_distribution
        FROM sys.analytical_values av
        WHERE av.id = NEW.analytical_value_id;

        NEW.analytical_distribution := v_distribution;
    ELSIF v_invoice.default_analytical_value_id IS NOT NULL THEN
        -- Use invoice default
        SELECT jsonb_build_array(
            jsonb_build_object(
                'axis_id', av.axis_id,
                'value_id', v_invoice.default_analytical_value_id,
                'value_code', av.value_code,
                'percentage', 100,
                'amount', NEW.line_total_ht
            )
        ) INTO v_distribution
        FROM sys.analytical_values av
        WHERE av.id = v_invoice.default_analytical_value_id;

        NEW.analytical_distribution := v_distribution;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_apply_line_analytical
    BEFORE INSERT OR UPDATE ON sys.invoice_lines
    FOR EACH ROW
    EXECUTE FUNCTION sys.fn_apply_line_analytical();

-- 4.6 Update timestamp
CREATE OR REPLACE FUNCTION sys.fn_invoice_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := NOW();
    NEW.version_number := OLD.version_number + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_invoice_timestamp
    BEFORE UPDATE ON sys.invoices
    FOR EACH ROW EXECUTE FUNCTION sys.fn_invoice_update_timestamp();

CREATE TRIGGER trg_payment_timestamp
    BEFORE UPDATE ON sys.invoice_payments
    FOR EACH ROW EXECUTE FUNCTION sys.fn_invoice_update_timestamp();

-- ============================================================================
-- 5. RPC FUNCTIONS
-- ============================================================================

-- 5.1 Create sales invoice
CREATE OR REPLACE FUNCTION sys.rpc_create_invoice(
    p_entity_id BIGINT,
    p_invoice_type sys.invoice_type,
    p_partner_id BIGINT,
    p_invoice_date DATE,
    p_due_date DATE,
    p_lines JSONB,                          -- [{description, quantity, unit_price_ht, tax_rate, account_number, analytical_value_id?}]
    p_currency_code CHAR(3) DEFAULT 'XAF',
    p_exchange_rate DECIMAL DEFAULT 1.0,
    p_reference VARCHAR DEFAULT NULL,
    p_default_analytical_value_id BIGINT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS TABLE (
    success BOOLEAN,
    invoice_id BIGINT,
    invoice_number VARCHAR,
    total_ttc DECIMAL,
    message TEXT
) AS $$
DECLARE
    v_tenant_id BIGINT;
    v_invoice_id BIGINT;
    v_invoice_number VARCHAR;
    v_total DECIMAL;
    v_partner RECORD;
    v_line JSONB;
    v_line_num INT := 0;
    v_line_subtotal DECIMAL;
    v_tax_amount DECIMAL;
BEGIN
    -- Get tenant from entity
    SELECT tenant_id INTO v_tenant_id
    FROM sys.tenant_entities
    WHERE id = p_entity_id;

    IF v_tenant_id IS NULL THEN
        RETURN QUERY SELECT FALSE, NULL::BIGINT, NULL::VARCHAR, NULL::DECIMAL, 'Entity not found'::TEXT;
        RETURN;
    END IF;

    -- Get partner info (assumes partners table exists in client schema)
    -- For now, we just validate it exists
    -- In real implementation, fetch from client_{schema}.partners

    -- Create invoice
    INSERT INTO sys.invoices (
        tenant_id,
        entity_id,
        invoice_type,
        invoice_date,
        due_date,
        partner_id,
        partner_name,
        currency_code,
        exchange_rate,
        reference,
        default_analytical_value_id,
        internal_notes
    ) VALUES (
        v_tenant_id,
        p_entity_id,
        p_invoice_type,
        p_invoice_date,
        p_due_date,
        p_partner_id,
        'Partner ' || p_partner_id,         -- Should fetch real name
        p_currency_code,
        p_exchange_rate,
        p_reference,
        p_default_analytical_value_id,
        p_notes
    )
    RETURNING id, invoice_number INTO v_invoice_id, v_invoice_number;

    -- Create lines
    FOR v_line IN SELECT * FROM jsonb_array_elements(p_lines)
    LOOP
        v_line_num := v_line_num + 1;
        v_line_subtotal := (v_line->>'quantity')::DECIMAL * (v_line->>'unit_price_ht')::DECIMAL;
        v_tax_amount := v_line_subtotal * COALESCE((v_line->>'tax_rate')::DECIMAL, 0) / 100;

        INSERT INTO sys.invoice_lines (
            invoice_id,
            line_number,
            description,
            quantity,
            unit_price_ht,
            line_subtotal_ht,
            tax_rate,
            tax_amount,
            account_number,
            analytical_value_id,
            distribution_template_id
        ) VALUES (
            v_invoice_id,
            v_line_num,
            v_line->>'description',
            (v_line->>'quantity')::DECIMAL,
            (v_line->>'unit_price_ht')::DECIMAL,
            v_line_subtotal,
            COALESCE((v_line->>'tax_rate')::DECIMAL, 0),
            v_tax_amount,
            v_line->>'account_number',
            (v_line->>'analytical_value_id')::BIGINT,
            (v_line->>'distribution_template_id')::BIGINT
        );
    END LOOP;

    -- Get final total
    SELECT total_ttc INTO v_total
    FROM sys.invoices
    WHERE id = v_invoice_id;

    RETURN QUERY SELECT TRUE, v_invoice_id, v_invoice_number, v_total, 'Invoice created successfully'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- 5.2 Validate invoice
CREATE OR REPLACE FUNCTION sys.rpc_validate_invoice(
    p_invoice_id BIGINT,
    p_user_id BIGINT
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT
) AS $$
DECLARE
    v_invoice sys.invoices;
BEGIN
    SELECT * INTO v_invoice
    FROM sys.invoices
    WHERE id = p_invoice_id;

    IF v_invoice IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Invoice not found'::TEXT;
        RETURN;
    END IF;

    IF v_invoice.status != 'DRAFT' THEN
        RETURN QUERY SELECT FALSE, ('Invoice not in DRAFT status: ' || v_invoice.status)::TEXT;
        RETURN;
    END IF;

    -- Check has lines
    IF NOT EXISTS (SELECT 1 FROM sys.invoice_lines WHERE invoice_id = p_invoice_id) THEN
        RETURN QUERY SELECT FALSE, 'Invoice has no lines'::TEXT;
        RETURN;
    END IF;

    -- Validate
    UPDATE sys.invoices
    SET status = 'VALIDATED',
        validated_at = NOW(),
        validated_by = p_user_id
    WHERE id = p_invoice_id;

    RETURN QUERY SELECT TRUE, 'Invoice validated'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- 5.3 Record payment
CREATE OR REPLACE FUNCTION sys.rpc_record_payment(
    p_invoice_id BIGINT,
    p_payment_method sys.payment_method,
    p_amount DECIMAL,
    p_payment_date DATE,
    p_bank_reference VARCHAR DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS TABLE (
    success BOOLEAN,
    payment_id BIGINT,
    payment_number VARCHAR,
    remaining_amount DECIMAL,
    message TEXT
) AS $$
DECLARE
    v_invoice sys.invoices;
    v_payment_id BIGINT;
    v_payment_number VARCHAR;
    v_remaining DECIMAL;
BEGIN
    SELECT * INTO v_invoice
    FROM sys.invoices
    WHERE id = p_invoice_id;

    IF v_invoice IS NULL THEN
        RETURN QUERY SELECT FALSE, NULL::BIGINT, NULL::VARCHAR, NULL::DECIMAL, 'Invoice not found'::TEXT;
        RETURN;
    END IF;

    IF v_invoice.status IN ('CANCELLED', 'DRAFT') THEN
        RETURN QUERY SELECT FALSE, NULL::BIGINT, NULL::VARCHAR, NULL::DECIMAL,
            ('Cannot pay invoice in status: ' || v_invoice.status)::TEXT;
        RETURN;
    END IF;

    IF p_amount > v_invoice.amount_remaining THEN
        RETURN QUERY SELECT FALSE, NULL::BIGINT, NULL::VARCHAR, NULL::DECIMAL,
            ('Amount exceeds remaining: ' || v_invoice.amount_remaining)::TEXT;
        RETURN;
    END IF;

    -- Create payment
    INSERT INTO sys.invoice_payments (
        tenant_id,
        entity_id,
        invoice_id,
        payment_method,
        amount,
        currency_code,
        exchange_rate,
        base_amount,
        payment_date,
        bank_reference,
        notes
    ) VALUES (
        v_invoice.tenant_id,
        v_invoice.entity_id,
        p_invoice_id,
        p_payment_method,
        p_amount,
        v_invoice.currency_code,
        v_invoice.exchange_rate,
        p_amount * v_invoice.exchange_rate,
        p_payment_date,
        p_bank_reference,
        p_notes
    )
    RETURNING id, payment_number INTO v_payment_id, v_payment_number;

    -- Get updated remaining
    SELECT amount_remaining INTO v_remaining
    FROM sys.invoices
    WHERE id = p_invoice_id;

    RETURN QUERY SELECT TRUE, v_payment_id, v_payment_number, v_remaining, 'Payment recorded'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- 5.4 Get invoices with aging
CREATE OR REPLACE FUNCTION sys.rpc_get_invoices_aging(
    p_entity_id BIGINT,
    p_invoice_type sys.invoice_type DEFAULT 'SALES',
    p_as_of_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    invoice_id BIGINT,
    invoice_number VARCHAR,
    partner_name VARCHAR,
    invoice_date DATE,
    due_date DATE,
    total_ttc DECIMAL,
    amount_paid DECIMAL,
    amount_remaining DECIMAL,
    days_overdue INT,
    aging_bucket VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        i.id,
        i.invoice_number,
        i.partner_name,
        i.invoice_date,
        i.due_date,
        i.total_ttc,
        i.amount_paid,
        i.amount_remaining,
        GREATEST(p_as_of_date - i.due_date, 0)::INT AS days_overdue,
        CASE
            WHEN i.due_date > p_as_of_date THEN 'NOT_DUE'
            WHEN p_as_of_date - i.due_date <= 30 THEN '0-30'
            WHEN p_as_of_date - i.due_date <= 60 THEN '31-60'
            WHEN p_as_of_date - i.due_date <= 90 THEN '61-90'
            ELSE '90+'
        END AS aging_bucket
    FROM sys.invoices i
    WHERE i.entity_id = p_entity_id
      AND i.invoice_type = p_invoice_type
      AND i.status NOT IN ('CANCELLED', 'DRAFT', 'PAID')
      AND i.amount_remaining > 0
      AND i.deleted_at IS NULL
    ORDER BY i.due_date;
END;
$$ LANGUAGE plpgsql STABLE;

-- 5.5 Invoice analytical summary
CREATE OR REPLACE FUNCTION sys.rpc_get_invoice_analytical_summary(
    p_entity_id BIGINT,
    p_year INT,
    p_month_start INT DEFAULT 1,
    p_month_end INT DEFAULT 12,
    p_invoice_type sys.invoice_type DEFAULT NULL
)
RETURNS TABLE (
    axis_code VARCHAR,
    value_code VARCHAR,
    value_name VARCHAR,
    total_ht DECIMAL,
    total_tva DECIMAL,
    total_ttc DECIMAL,
    invoice_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH line_analytics AS (
        SELECT
            il.invoice_id,
            (jsonb_array_elements(il.analytical_distribution)->>'axis_id')::BIGINT AS axis_id,
            (jsonb_array_elements(il.analytical_distribution)->>'value_id')::BIGINT AS value_id,
            (jsonb_array_elements(il.analytical_distribution)->>'amount')::DECIMAL AS amount,
            il.tax_amount * (jsonb_array_elements(il.analytical_distribution)->>'percentage')::DECIMAL / 100 AS tax_amount
        FROM sys.invoice_lines il
        JOIN sys.invoices i ON i.id = il.invoice_id
        WHERE i.entity_id = p_entity_id
          AND EXTRACT(YEAR FROM i.invoice_date) = p_year
          AND EXTRACT(MONTH FROM i.invoice_date) BETWEEN p_month_start AND p_month_end
          AND i.status NOT IN ('DRAFT', 'CANCELLED')
          AND (p_invoice_type IS NULL OR i.invoice_type = p_invoice_type)
          AND il.analytical_distribution IS NOT NULL
    )
    SELECT
        ax.axis_code,
        av.value_code,
        av.value_name,
        SUM(la.amount)::DECIMAL,
        SUM(la.tax_amount)::DECIMAL,
        SUM(la.amount + la.tax_amount)::DECIMAL,
        COUNT(DISTINCT la.invoice_id)
    FROM line_analytics la
    JOIN sys.analytical_values av ON av.id = la.value_id
    JOIN sys.analytical_axes ax ON ax.id = la.axis_id
    GROUP BY ax.axis_code, av.value_code, av.value_name
    ORDER BY ax.axis_code, av.value_code;
END;
$$ LANGUAGE plpgsql STABLE;

-- 5.6 Post invoice to accounting
CREATE OR REPLACE FUNCTION sys.rpc_post_invoice_to_accounting(
    p_invoice_id BIGINT,
    p_user_id BIGINT
)
RETURNS TABLE (
    success BOOLEAN,
    journal_entry_id BIGINT,
    message TEXT
) AS $$
DECLARE
    v_invoice sys.invoices;
    v_entry_id BIGINT;
BEGIN
    SELECT * INTO v_invoice
    FROM sys.invoices
    WHERE id = p_invoice_id;

    IF v_invoice IS NULL THEN
        RETURN QUERY SELECT FALSE, NULL::BIGINT, 'Invoice not found'::TEXT;
        RETURN;
    END IF;

    IF v_invoice.status = 'DRAFT' THEN
        RETURN QUERY SELECT FALSE, NULL::BIGINT, 'Invoice must be validated first'::TEXT;
        RETURN;
    END IF;

    IF v_invoice.is_posted THEN
        RETURN QUERY SELECT FALSE, NULL::BIGINT, 'Invoice already posted'::TEXT;
        RETURN;
    END IF;

    -- TODO: Create journal entry using OHADA accounts
    -- This would integrate with the accounting module
    -- For now, we just mark as posted

    UPDATE sys.invoices
    SET is_posted = TRUE,
        posted_at = NOW()
    WHERE id = p_invoice_id;

    RETURN QUERY SELECT TRUE, NULL::BIGINT, 'Invoice marked as posted (journal entry creation pending)'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 6. VIEWS
-- ============================================================================

-- 6.1 Invoice summary view
CREATE OR REPLACE VIEW sys.v_invoice_summary AS
SELECT
    i.id,
    i.tenant_id,
    i.entity_id,
    e.entity_name,
    i.invoice_type,
    i.invoice_number,
    i.invoice_date,
    i.due_date,
    i.partner_id,
    i.partner_name,
    i.currency_code,
    i.total_ht,
    i.total_tva,
    i.total_ttc,
    i.amount_paid,
    i.amount_remaining,
    i.status,
    CASE
        WHEN i.status IN ('PAID', 'CANCELLED') THEN NULL
        WHEN CURRENT_DATE <= i.due_date THEN 0
        ELSE CURRENT_DATE - i.due_date
    END AS days_overdue,
    i.is_posted,
    i.created_at
FROM sys.invoices i
JOIN sys.tenant_entities e ON e.id = i.entity_id
WHERE i.deleted_at IS NULL;

-- 6.2 Overdue invoices view
CREATE OR REPLACE VIEW sys.v_invoices_overdue AS
SELECT
    i.id,
    i.entity_id,
    e.entity_name,
    i.invoice_type,
    i.invoice_number,
    i.partner_name,
    i.due_date,
    i.total_ttc,
    i.amount_remaining,
    CURRENT_DATE - i.due_date AS days_overdue,
    COALESCE(
        (SELECT MAX(reminder_level) FROM sys.invoice_reminders WHERE invoice_id = i.id),
        0
    ) AS last_reminder_level
FROM sys.invoices i
JOIN sys.tenant_entities e ON e.id = i.entity_id
WHERE i.deleted_at IS NULL
  AND i.status NOT IN ('PAID', 'CANCELLED', 'DRAFT')
  AND i.amount_remaining > 0
  AND i.due_date < CURRENT_DATE
ORDER BY i.due_date;

-- 6.3 Invoice analytics view
CREATE OR REPLACE VIEW sys.v_invoice_analytics AS
SELECT
    i.entity_id,
    i.invoice_type,
    EXTRACT(YEAR FROM i.invoice_date)::INT AS year,
    EXTRACT(MONTH FROM i.invoice_date)::INT AS month,
    COUNT(*) AS invoice_count,
    SUM(i.total_ht) AS total_ht,
    SUM(i.total_tva) AS total_tva,
    SUM(i.total_ttc) AS total_ttc,
    SUM(i.amount_paid) AS total_paid,
    SUM(i.amount_remaining) AS total_remaining,
    COUNT(*) FILTER (WHERE i.status = 'PAID') AS paid_count,
    COUNT(*) FILTER (WHERE i.status = 'OVERDUE') AS overdue_count
FROM sys.invoices i
WHERE i.deleted_at IS NULL
  AND i.status != 'CANCELLED'
GROUP BY i.entity_id, i.invoice_type,
    EXTRACT(YEAR FROM i.invoice_date),
    EXTRACT(MONTH FROM i.invoice_date);

-- ============================================================================
-- 7. ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE sys.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE sys.invoice_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE sys.invoice_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE sys.invoice_reminders ENABLE ROW LEVEL SECURITY;

-- Policies will be created based on user entity access from 01_rubis_multicompany_schema.sql

-- ============================================================================
-- 8. PERMISSIONS
-- ============================================================================

-- New permissions for invoicing
INSERT INTO sys.permissions (permission_code, module_code, resource, action, description)
VALUES
    ('INVOICING.SALES.CREATE', 'INVOICING', 'SALES_INVOICE', 'CREATE', 'Creer des factures de vente'),
    ('INVOICING.SALES.READ', 'INVOICING', 'SALES_INVOICE', 'READ', 'Voir les factures de vente'),
    ('INVOICING.SALES.UPDATE', 'INVOICING', 'SALES_INVOICE', 'UPDATE', 'Modifier les factures de vente'),
    ('INVOICING.SALES.DELETE', 'INVOICING', 'SALES_INVOICE', 'DELETE', 'Supprimer les factures de vente'),
    ('INVOICING.SALES.VALIDATE', 'INVOICING', 'SALES_INVOICE', 'VALIDATE', 'Valider les factures de vente'),
    ('INVOICING.PURCHASE.CREATE', 'INVOICING', 'PURCHASE_INVOICE', 'CREATE', 'Creer des factures d''achat'),
    ('INVOICING.PURCHASE.READ', 'INVOICING', 'PURCHASE_INVOICE', 'READ', 'Voir les factures d''achat'),
    ('INVOICING.PURCHASE.UPDATE', 'INVOICING', 'PURCHASE_INVOICE', 'UPDATE', 'Modifier les factures d''achat'),
    ('INVOICING.PURCHASE.DELETE', 'INVOICING', 'PURCHASE_INVOICE', 'DELETE', 'Supprimer les factures d''achat'),
    ('INVOICING.PURCHASE.VALIDATE', 'INVOICING', 'PURCHASE_INVOICE', 'VALIDATE', 'Valider les factures d''achat'),
    ('INVOICING.PAYMENTS.CREATE', 'INVOICING', 'PAYMENT', 'CREATE', 'Enregistrer des paiements'),
    ('INVOICING.PAYMENTS.READ', 'INVOICING', 'PAYMENT', 'READ', 'Voir les paiements'),
    ('INVOICING.REMINDERS.CREATE', 'INVOICING', 'REMINDER', 'CREATE', 'Creer des relances'),
    ('INVOICING.ANALYTICS.READ', 'INVOICING', 'ANALYTICS', 'READ', 'Voir les analyses facturation')
ON CONFLICT (permission_code) DO NOTHING;

-- ============================================================================
-- COMPLETION NOTICE
-- ============================================================================

DO $$ BEGIN
    RAISE NOTICE '✅ EdenFin RUBIS Invoicing Module - Schema created successfully';
    RAISE NOTICE 'Tables: 5 (invoices, invoice_lines, invoice_tax_summary, invoice_payments, invoice_reminders)';
    RAISE NOTICE 'Functions: 6 RPC functions';
    RAISE NOTICE 'Views: 3';
    RAISE NOTICE 'Triggers: 6';
END $$;
