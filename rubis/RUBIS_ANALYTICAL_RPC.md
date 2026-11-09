# EdenFin RUBIS — Analytical Distribution RPC

## Overview

The analytical distribution system enables splitting journal entries across multiple analytical dimensions (cost centers, projects, departments) for detailed cost analysis and reporting.

---

## Core Concepts

### Distribution Templates

Templates define how to split amounts across analytical values automatically.

```
┌─────────────────────────────────────────────────────────────────┐
│                    Distribution Template                         │
│  "CHARGES_ADMIN" - Applicable to accounts 6%                    │
├─────────────────────────────────────────────────────────────────┤
│  CC-ADMIN (Administration)     →  40%                           │
│  CC-COMM  (Commercial)         →  35%                           │
│  CC-PROD  (Production)         →  25%                           │
│                                   ────                           │
│                                   100%                           │
└─────────────────────────────────────────────────────────────────┘
```

### Analytical Entries

When a journal entry is created, analytical entries are generated:

```
Journal Entry Line:
  Account 6061 - Fournitures bureau: 10,000 XAF (Débit)

                    ↓ Distribution Template Applied

Analytical Entries:
  CC-ADMIN: 4,000 XAF (40%)
  CC-COMM:  3,500 XAF (35%)
  CC-PROD:  2,500 XAF (25%)
```

---

## New Tables

### `sys.analytical_distribution_templates`

Distribution templates for automatic allocation.

| Column | Type | Description |
|--------|------|-------------|
| template_code | VARCHAR(30) | Unique code |
| template_name | VARCHAR(200) | Display name |
| applicable_account_pattern | VARCHAR(20) | Account pattern (e.g., '6%') |
| applicable_axis_id | FK | Apply to this axis only |
| is_mandatory | BOOLEAN | Force distribution on matching accounts |

### `sys.analytical_distribution_lines`

Lines within each template.

| Column | Type | Description |
|--------|------|-------------|
| template_id | FK | Parent template |
| analytical_value_id | FK | Target cost center |
| distribution_percentage | DECIMAL(7,4) | Percentage (must total 100%) |
| distribution_order | INT | Order of application |

### `sys.analytical_entries`

Actual analytical allocations.

| Column | Type | Description |
|--------|------|-------------|
| journal_entry_id | BIGINT | Source journal entry |
| journal_entry_line_id | BIGINT | Source line |
| axis_id | FK | Analytical axis |
| analytical_value_id | FK | Cost center |
| amount_debit / credit | DECIMAL | Distributed amounts |
| distribution_percentage | DECIMAL | Percentage applied |
| distribution_source | ENUM | MANUAL, TEMPLATE, AUTOMATIC, IMPORT |

---

## RPC Functions

### Template Management

#### Create Distribution Template

```sql
SELECT sys.rpc_create_distribution_template(
  p_template_code := 'CHARGES_ADMIN',
  p_template_name := 'Répartition Charges Administratives',
  p_applicable_account_pattern := '6%',
  p_is_mandatory := TRUE
);
-- Returns: template_id (BIGINT)
```

#### Add Template Line

```sql
SELECT sys.rpc_add_template_line(
  p_template_id := 1,
  p_analytical_value_id := 10,  -- CC-ADMIN
  p_distribution_percentage := 40.00,
  p_distribution_order := 1
);
-- Returns: line_id (BIGINT)
```

#### Validate Template

```sql
SELECT * FROM sys.validate_distribution_template(p_template_id := 1);
```

| is_valid | total_percentage | error_message |
|----------|------------------|---------------|
| TRUE | 100.0000 | NULL |

### Creating Analytical Entries

#### Simple Entry (Manual)

```sql
SELECT sys.rpc_create_analytical_entry(
  p_entity_id := 1,
  p_journal_entry_id := 1001,
  p_journal_entry_line_id := 5001,
  p_axis_id := 1,                    -- Cost Center axis
  p_analytical_value_id := 10,       -- CC-ADMIN
  p_amount_debit := 10000.00,
  p_amount_credit := 0,
  p_entry_date := '2026-02-15'
);
-- Returns: entry_id (BIGINT)
```

#### Distribute by Template

```sql
SELECT * FROM sys.rpc_distribute_entry_by_template(
  p_entity_id := 1,
  p_journal_entry_id := 1001,
  p_journal_entry_line_id := 5001,
  p_template_id := 1,
  p_amount_debit := 10000.00,
  p_amount_credit := 0,
  p_entry_date := '2026-02-15'
);
```

| entry_id | analytical_value_id | value_code | distributed_debit | distributed_credit |
|----------|---------------------|------------|-------------------|-------------------|
| 101 | 10 | CC-ADMIN | 4000.00 | 0.00 |
| 102 | 11 | CC-COMM | 3500.00 | 0.00 |
| 103 | 12 | CC-PROD | 2500.00 | 0.00 |

#### Auto-Distribute (Find Template by Account)

```sql
SELECT * FROM sys.rpc_auto_distribute_entry(
  p_entity_id := 1,
  p_journal_entry_id := 1001,
  p_journal_entry_line_id := 5001,
  p_account_number := '6061',       -- System finds applicable template
  p_amount_debit := 10000.00,
  p_entry_date := '2026-02-15'
);
```

### Reporting Functions

#### Analytical Balance

```sql
SELECT * FROM sys.rpc_analytical_balance(
  p_entity_id := 1,
  p_axis_id := 1,           -- Cost Center
  p_year := 2026,
  p_month_start := 1,
  p_month_end := 3          -- Q1
);
```

| value_code | value_name | total_debit | total_credit | balance |
|------------|------------|-------------|--------------|---------|
| CC-ADMIN | Administration | 150000.00 | 5000.00 | 145000.00 |
| CC-COMM | Commercial | 200000.00 | 10000.00 | 190000.00 |
| CC-PROD | Production | 300000.00 | 25000.00 | 275000.00 |

#### Budget vs Actual (Analytical)

```sql
SELECT * FROM sys.rpc_budget_vs_actual_analytical(
  p_entity_id := 1,
  p_axis_id := 1,
  p_fiscal_year := 2026,
  p_month := 3              -- YTD through March
);
```

| value_code | value_name | budget_amount | actual_amount | variance_amount | variance_percentage | status |
|------------|------------|---------------|---------------|-----------------|---------------------|--------|
| CC-ADMIN | Administration | 140000.00 | 145000.00 | 5000.00 | 3.57 | ON_TRACK |
| CC-COMM | Commercial | 180000.00 | 190000.00 | 10000.00 | 5.56 | OVER_BUDGET |
| CC-PROD | Production | 280000.00 | 275000.00 | -5000.00 | -1.79 | UNDER_BUDGET |

**Status Values:**
- `ON_TRACK` — Variance ≤ 5%
- `OVER_BUDGET` — Actual > Budget by > 5%
- `UNDER_BUDGET` — Actual < Budget by > 5%
- `NO_BUDGET` — No budget defined

#### Monthly Evolution

```sql
SELECT * FROM sys.rpc_analytical_monthly_evolution(
  p_entity_id := 1,
  p_axis_id := 1,
  p_analytical_value_id := 10,   -- CC-ADMIN
  p_year := 2026
);
```

| month_number | month_name | total_debit | total_credit | balance | cumulative_balance |
|--------------|------------|-------------|--------------|---------|-------------------|
| 1 | January | 45000.00 | 2000.00 | 43000.00 | 43000.00 |
| 2 | February | 50000.00 | 1500.00 | 48500.00 | 91500.00 |
| 3 | March | 55000.00 | 1500.00 | 53500.00 | 145000.00 |
| ... | ... | ... | ... | ... | ... |

#### Income Statement by Cost Center

```sql
SELECT * FROM sys.rpc_analytical_income_statement(
  p_entity_id := 1,
  p_axis_id := 1,
  p_analytical_value_id := 10,   -- CC-ADMIN
  p_year := 2026,
  p_month_start := 1,
  p_month_end := 12
);
```

---

## Views

### `sys.v_analytical_summary`

Aggregated analytical data by entity, axis, value, and period.

```sql
SELECT * FROM sys.v_analytical_summary
WHERE tenant_id = 1 AND period_year = 2026
ORDER BY entity_name, axis_code, value_code, period_month;
```

### `sys.v_distribution_templates_status`

Template validation status.

```sql
SELECT * FROM sys.v_distribution_templates_status
WHERE tenant_id = 1;
```

| template_code | line_count | total_percentage | validation_status |
|---------------|------------|------------------|-------------------|
| CHARGES_ADMIN | 3 | 100.0000 | VALID |
| CHARGES_PROD | 2 | 75.0000 | INCOMPLETE |

---

## Example: Complete Workflow

### 1. Create Axes (done in schema setup)

```sql
-- Already created: CC (Cost Center), PROJ (Project), DEPT (Department)
```

### 2. Create Cost Centers

```sql
-- Add cost centers for axis CC
INSERT INTO sys.analytical_values (tenant_id, axis_id, value_code, value_name, has_budget)
VALUES
  (1, 1, 'CC-ADMIN', 'Administration', TRUE),
  (1, 1, 'CC-COMM', 'Commercial', TRUE),
  (1, 1, 'CC-PROD', 'Production', TRUE),
  (1, 1, 'CC-RD', 'R&D', TRUE);
```

### 3. Create Distribution Template

```sql
-- Create template for expense accounts
SELECT sys.rpc_create_distribution_template(
  p_template_code := 'CHARGES_STD',
  p_template_name := 'Répartition Standard des Charges',
  p_applicable_account_pattern := '6%',
  p_is_mandatory := FALSE
);

-- Add distribution lines (must total 100%)
SELECT sys.rpc_add_template_line(1, 10, 30.00, 1);  -- CC-ADMIN: 30%
SELECT sys.rpc_add_template_line(1, 11, 25.00, 2);  -- CC-COMM: 25%
SELECT sys.rpc_add_template_line(1, 12, 35.00, 3);  -- CC-PROD: 35%
SELECT sys.rpc_add_template_line(1, 13, 10.00, 4);  -- CC-RD: 10%

-- Validate
SELECT * FROM sys.validate_distribution_template(1);
```

### 4. Create Budget

```sql
-- Create budget version
INSERT INTO sys.budget_versions (tenant_id, version_code, version_name, version_type, fiscal_year, entity_id, status)
VALUES (1, 'BUD-2026-INIT', 'Budget Initial 2026', 'INITIAL', 2026, 1, 'APPROVED');

-- Add budget lines per cost center
INSERT INTO sys.budget_lines (budget_version_id, entity_id, account_number, analytical_value_id, period_month, amount_debit, currency_code)
VALUES
  (1, 1, '6061', 10, 1, 15000, 'XAF'),  -- CC-ADMIN, January
  (1, 1, '6061', 11, 1, 12500, 'XAF'),  -- CC-COMM, January
  (1, 1, '6061', 12, 1, 17500, 'XAF'),  -- CC-PROD, January
  -- ... etc for all months
```

### 5. Record Actual Expenses

```sql
-- When journal entry is created, auto-distribute
SELECT * FROM sys.rpc_auto_distribute_entry(
  p_entity_id := 1,
  p_journal_entry_id := 1001,
  p_journal_entry_line_id := 5001,
  p_account_number := '6061',
  p_amount_debit := 50000.00,
  p_entry_date := '2026-01-15'
);
```

### 6. Generate Reports

```sql
-- Monthly balance by cost center
SELECT * FROM sys.rpc_analytical_balance(1, 1, 2026, 1, 1);

-- Budget vs Actual
SELECT * FROM sys.rpc_budget_vs_actual_analytical(1, 1, 2026, 1);

-- Trend analysis
SELECT * FROM sys.rpc_analytical_monthly_evolution(1, 1, 10, 2026);
```

---

## Integration with Frontend

### React Component Example

```typescript
// Hook for analytical balance
const useAnalyticalBalance = (entityId: number, axisId: number, year: number) => {
  return useQuery(['analyticalBalance', entityId, axisId, year], async () => {
    const { data, error } = await supabase.rpc('rpc_analytical_balance', {
      p_entity_id: entityId,
      p_axis_id: axisId,
      p_year: year,
      p_month_start: 1,
      p_month_end: 12
    });
    if (error) throw error;
    return data;
  });
};

// Hook for budget vs actual
const useBudgetVsActual = (entityId: number, axisId: number, year: number, month: number) => {
  return useQuery(['budgetVsActual', entityId, axisId, year, month], async () => {
    const { data, error } = await supabase.rpc('rpc_budget_vs_actual_analytical', {
      p_entity_id: entityId,
      p_axis_id: axisId,
      p_fiscal_year: year,
      p_month: month
    });
    if (error) throw error;
    return data;
  });
};
```

---

## Best Practices

1. **Template Validation**: Always validate templates before use
2. **100% Rule**: Distribution percentages must sum to exactly 100%
3. **Mandatory Templates**: Use `is_mandatory` for accounts that require analytical tracking
4. **Budget Alignment**: Ensure budget structure matches analytical structure
5. **Audit Trail**: All entries track `distribution_source` for traceability

---

*EdenFin RUBIS — Analytical Distribution RPC v1.0*
*February 2026*
