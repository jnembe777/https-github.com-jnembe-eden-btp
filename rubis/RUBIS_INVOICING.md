# EdenFin RUBIS — Invoicing Module

## Overview

The RUBIS Invoicing module provides comprehensive sales and purchase invoice management with analytical distribution for PME businesses (10-50 employees).

**File**: `03_rubis_invoicing.sql`
**Lines**: ~1,180
**Dependencies**:
- `01_rubis_multicompany_schema.sql` (entity structure)
- `02_rubis_analytical_rpc.sql` (analytical axes and distribution templates)

---

## Features

### Core Capabilities

| Feature | Description |
|---------|-------------|
| Multi-type invoices | Sales, Purchase, Credit Notes, Debit Notes, Proforma |
| Multi-currency | XAF default, automatic base currency conversion |
| Analytical distribution | Cost center allocation per line or via templates |
| Payment tracking | Partial payments, automatic status updates |
| Aging analysis | Overdue tracking with 0-30/31-60/61-90/90+ buckets |
| Automatic numbering | Per entity/type/year sequences |
| Tax summary | Grouped by VAT rate |
| Reminders | Up to 3 levels of customer reminders |

### Invoice Workflow

```
DRAFT → VALIDATED → SENT → PARTIALLY_PAID → PAID
           ↓
       CANCELLED

OVERDUE: Triggered when due_date < current_date and amount_remaining > 0
DISPUTED: Manual status for contested invoices
```

---

## Schema

### Tables (6 tables)

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `sys.invoices` | Invoice headers | type, status, amounts, partner, currency |
| `sys.invoice_lines` | Invoice line items | description, qty, price, tax, analytics |
| `sys.invoice_tax_summary` | Tax breakdown by rate | tax_rate, base_amount, tax_amount |
| `sys.invoice_payments` | Payment records | method, amount, bank_reference |
| `sys.invoice_reminders` | Collection reminders | level (1-3), sent_at, late_fees |
| `sys.invoice_sequences` | Auto-numbering | prefix, current_number, format |

### Enum Types

```sql
-- Invoice types
sys.invoice_type: SALES, PURCHASE, CREDIT_NOTE, DEBIT_NOTE, PROFORMA

-- Invoice status
sys.invoice_status: DRAFT, VALIDATED, SENT, PARTIALLY_PAID, PAID, OVERDUE, CANCELLED, DISPUTED

-- Payment methods
sys.payment_method: CASH, BANK_TRANSFER, CHECK, MOBILE_MONEY, CARD, DIRECT_DEBIT, COMPENSATION
```

### Generated Columns

| Column | Formula |
|--------|---------|
| `invoices.amount_remaining` | `total_ttc - amount_paid` |
| `invoice_lines.line_total_ht` | `line_subtotal_ht - discount_amount` |
| `invoice_lines.line_total_ttc` | `line_subtotal_ht - discount_amount + tax_amount` |

---

## Analytical Distribution

### Three Integration Modes

1. **Single analytical value** - 100% allocation to one cost center
   ```sql
   analytical_value_id = 123  -- e.g., "CC-MARKETING"
   ```

2. **Distribution template** - Predefined percentage splits
   ```sql
   distribution_template_id = 5  -- e.g., "SHARED-SERVICES-50-30-20"
   ```

3. **Invoice default** - Applied to lines without explicit allocation
   ```sql
   default_analytical_value_id = 100  -- e.g., "CC-GENERAL"
   ```

### Stored Distribution Format

The `analytical_distribution` JSONB column stores resolved allocations:

```json
[
  {"axis_id": 1, "value_id": 10, "value_code": "CC-SALES", "percentage": 60, "amount": 600000},
  {"axis_id": 1, "value_id": 11, "value_code": "CC-MARKETING", "percentage": 40, "amount": 400000}
]
```

---

## RPC Functions (6 functions)

### 1. `rpc_create_invoice`

Creates a complete invoice with lines.

```sql
SELECT * FROM sys.rpc_create_invoice(
    p_entity_id := 1,
    p_invoice_type := 'SALES',
    p_partner_id := 42,
    p_invoice_date := '2026-02-11',
    p_due_date := '2026-03-13',
    p_lines := '[
        {"description": "Consulting services", "quantity": 10, "unit_price_ht": 150000, "tax_rate": 19.25, "account_number": "706100"},
        {"description": "Training workshop", "quantity": 2, "unit_price_ht": 500000, "tax_rate": 19.25, "account_number": "706200", "analytical_value_id": 15}
    ]'::JSONB,
    p_currency_code := 'XAF',
    p_default_analytical_value_id := 10
);

-- Returns: success, invoice_id, invoice_number, total_ttc, message
```

### 2. `rpc_validate_invoice`

Validates a draft invoice, making it official.

```sql
SELECT * FROM sys.rpc_validate_invoice(
    p_invoice_id := 123,
    p_user_id := 1
);
```

### 3. `rpc_record_payment`

Records a payment against an invoice.

```sql
SELECT * FROM sys.rpc_record_payment(
    p_invoice_id := 123,
    p_payment_method := 'BANK_TRANSFER',
    p_amount := 1000000.00,
    p_payment_date := '2026-02-15',
    p_bank_reference := 'VIR-2026-001234'
);

-- Returns: success, payment_id, payment_number, remaining_amount, message
```

### 4. `rpc_get_invoices_aging`

Returns aging analysis for receivables/payables.

```sql
SELECT * FROM sys.rpc_get_invoices_aging(
    p_entity_id := 1,
    p_invoice_type := 'SALES',
    p_as_of_date := '2026-02-11'
);

-- Returns: invoice details with days_overdue and aging_bucket (NOT_DUE, 0-30, 31-60, 61-90, 90+)
```

### 5. `rpc_get_invoice_analytical_summary`

Aggregates invoice amounts by analytical dimensions.

```sql
SELECT * FROM sys.rpc_get_invoice_analytical_summary(
    p_entity_id := 1,
    p_year := 2026,
    p_month_start := 1,
    p_month_end := 6,
    p_invoice_type := 'SALES'
);

-- Returns: axis_code, value_code, value_name, total_ht, total_tva, total_ttc, invoice_count
```

### 6. `rpc_post_invoice_to_accounting`

Marks invoice as posted (accounting journal entry creation pending).

```sql
SELECT * FROM sys.rpc_post_invoice_to_accounting(
    p_invoice_id := 123,
    p_user_id := 1
);
```

---

## Views (3 views)

| View | Purpose |
|------|---------|
| `sys.v_invoice_summary` | Complete invoice overview with entity name, days overdue |
| `sys.v_invoices_overdue` | Only overdue invoices with reminder level |
| `sys.v_invoice_analytics` | Monthly aggregations by entity and type |

### Example: Monthly Sales Dashboard

```sql
SELECT
    month,
    invoice_count,
    total_ttc,
    paid_count,
    overdue_count
FROM sys.v_invoice_analytics
WHERE entity_id = 1
  AND invoice_type = 'SALES'
  AND year = 2026
ORDER BY month;
```

---

## Triggers (6 triggers)

| Trigger | Table | Event | Purpose |
|---------|-------|-------|---------|
| `trg_invoice_number` | invoices | BEFORE INSERT | Auto-generate invoice number |
| `trg_payment_number` | invoice_payments | BEFORE INSERT | Auto-generate payment number |
| `trg_update_invoice_totals` | invoice_lines | AFTER INSERT/UPDATE/DELETE | Recalculate invoice amounts |
| `trg_update_invoice_paid` | invoice_payments | AFTER INSERT/UPDATE/DELETE | Update paid amount and status |
| `trg_apply_line_analytical` | invoice_lines | BEFORE INSERT/UPDATE | Resolve analytical distribution |
| `trg_invoice_timestamp` | invoices, payments | BEFORE UPDATE | Update timestamps and version |

---

## Invoice Numbering

### Format

Default format: `{PREFIX}-{YEAR}-{NUMBER:6}`

| Type | Prefix | Example |
|------|--------|---------|
| Sales | FV | FV-2026-000001 |
| Purchase | FA | FA-2026-000001 |
| Credit Note | AV | AV-2026-000001 |
| Debit Note | ND | ND-2026-000001 |
| Proforma | PF | PF-2026-000001 |

### Customization

Modify the `invoice_sequences` table to change prefixes or formats per entity.

---

## Permissions (14 new)

| Permission | Description |
|------------|-------------|
| `INVOICING.SALES.CREATE` | Create sales invoices |
| `INVOICING.SALES.READ` | View sales invoices |
| `INVOICING.SALES.UPDATE` | Modify sales invoices |
| `INVOICING.SALES.DELETE` | Delete sales invoices |
| `INVOICING.SALES.VALIDATE` | Validate sales invoices |
| `INVOICING.PURCHASE.CREATE` | Create purchase invoices |
| `INVOICING.PURCHASE.READ` | View purchase invoices |
| `INVOICING.PURCHASE.UPDATE` | Modify purchase invoices |
| `INVOICING.PURCHASE.DELETE` | Delete purchase invoices |
| `INVOICING.PURCHASE.VALIDATE` | Validate purchase invoices |
| `INVOICING.PAYMENTS.CREATE` | Record payments |
| `INVOICING.PAYMENTS.READ` | View payments |
| `INVOICING.REMINDERS.CREATE` | Create customer reminders |
| `INVOICING.ANALYTICS.READ` | View invoicing analytics |

---

## Integration Points

### With RUBIS Multi-Company (01_)

- `tenant_id` / `entity_id` for multi-entity isolation
- RLS policies based on `sys.user_entity_access`
- Entity-specific invoice sequences

### With RUBIS Analytical (02_)

- `analytical_axes` and `analytical_values` for cost center allocation
- `analytical_distribution_templates` for recurring splits
- Automatic distribution resolution via triggers

### With JASPE Accounting

- `journal_entry_id` link for posted invoices
- OHADA account codes on invoice lines
- Tax codes from `common.tax_codes`

---

## Usage Examples

### Create and Validate Sales Invoice

```sql
-- 1. Create invoice
SELECT * FROM sys.rpc_create_invoice(
    p_entity_id := 1,
    p_invoice_type := 'SALES',
    p_partner_id := 100,
    p_invoice_date := CURRENT_DATE,
    p_due_date := CURRENT_DATE + 30,
    p_lines := '[
        {"description": "Service A", "quantity": 1, "unit_price_ht": 1000000, "tax_rate": 19.25, "account_number": "706100"}
    ]'::JSONB
);

-- Returns: invoice_id = 1, invoice_number = 'FV-2026-000001'

-- 2. Validate
SELECT * FROM sys.rpc_validate_invoice(1, 1);

-- 3. Record partial payment
SELECT * FROM sys.rpc_record_payment(1, 'BANK_TRANSFER', 500000, CURRENT_DATE);

-- Invoice status now: PARTIALLY_PAID

-- 4. Record final payment
SELECT * FROM sys.rpc_record_payment(1, 'MOBILE_MONEY', 692500, CURRENT_DATE);

-- Invoice status now: PAID
```

### Generate Aging Report

```sql
SELECT
    aging_bucket,
    COUNT(*) AS invoice_count,
    SUM(amount_remaining) AS total_outstanding
FROM sys.rpc_get_invoices_aging(1, 'SALES', CURRENT_DATE)
GROUP BY aging_bucket
ORDER BY
    CASE aging_bucket
        WHEN 'NOT_DUE' THEN 0
        WHEN '0-30' THEN 1
        WHEN '31-60' THEN 2
        WHEN '61-90' THEN 3
        ELSE 4
    END;
```

---

## OHADA Accounting Integration

### Standard Accounts (Plan Comptable OHADA)

| Account | Description | Used For |
|---------|-------------|----------|
| 411xxx | Clients | Sales invoice receivables |
| 401xxx | Fournisseurs | Purchase invoice payables |
| 70xxxx | Ventes | Revenue accounts on lines |
| 60xxxx | Achats | Expense accounts on lines |
| 4431xx | TVA facturee | Output VAT |
| 4451xx | TVA recuperable | Input VAT |

### Journal Entry Template (Sales Invoice)

```
Debit  411100  Client XYZ        1,192,500  (TTC)
Credit 706100  Ventes services   1,000,000  (HT)
Credit 443100  TVA collectee       192,500  (TVA 19.25%)
```

---

*EdenFin RUBIS Invoicing Module — February 2026*
