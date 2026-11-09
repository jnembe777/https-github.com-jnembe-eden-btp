# EdenFin RUBIS — Multi-Company Architecture

## Overview

RUBIS is the second tier of EdenFin ERP, targeting PME (10-50 employees) with enhanced multi-company capabilities.

### Tier Progression

| Tier | Target | Max Entities | Features |
|------|--------|--------------|----------|
| **JASPE** | TPE (<10) | 1 | Single entity, basic accounting |
| **RUBIS** | PME (10-50) | 5 | Multi-entity, analytical, budgets |
| SAPHIR | ETI (50-250) | 20 | Multi-currency, IFRS, workflows |
| ONYX | GE (250+) | Unlimited | Multi-country, full consolidation |

---

## Schema Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              sys.tenants                                     │
│  (Client platform - one tenant per customer organization)                   │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                    ┌─────────────────┼─────────────────┐
                    ▼                 ▼                 ▼
          ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
          │ tenant_entities │ │ analytical_axes │ │ budget_versions │
          │ (Legal entities)│ │ (Cost centers)  │ │ (Budget mgmt)   │
          └────────┬────────┘ └────────┬────────┘ └────────┬────────┘
                   │                   │                   │
       ┌───────────┼───────────┐       ▼                   ▼
       ▼           ▼           ▼  ┌─────────────────┐ ┌─────────────────┐
┌───────────┐ ┌─────────┐ ┌──────┐│analytical_values│ │ budget_lines    │
│intercompany│ │entity   │ │user  ││ (CC, Projects) │ │ (per account/   │
│relationships││chart_of │ │entity│└─────────────────┘ │  period/entity) │
│           │ │accounts │ │access│                    └─────────────────┘
└─────┬─────┘ └────┬────┘ └──┬───┘
      │            │         │
      ▼            ▼         │
┌───────────────────────────────────────────────────────────────────────────┐
│                     intercompany_transactions                              │
│  (Transactions between entities: sales, purchases, loans, dividends)      │
└───────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                     consolidation_groups / periods                         │
│  (Group structure for consolidated reporting)                             │
└───────────────────────────────────────────────────────────────────────────┘
```

---

## New Tables (RUBIS)

### 1. Analytical Accounting

#### `sys.analytical_axes`
Defines dimensions for cost/profit center analysis.

| Column | Type | Description |
|--------|------|-------------|
| axis_code | VARCHAR(20) | Unique code (e.g., 'CC', 'PROJ') |
| axis_name | VARCHAR(100) | Display name |
| axis_type | ENUM | COST_CENTER, PROFIT_CENTER, PROJECT, DEPARTMENT, etc. |
| is_mandatory | BOOLEAN | Required for journal entries? |

**Default axes created for RUBIS tenants:**
- `CC` — Cost Center
- `PROJ` — Project
- `DEPT` — Department

#### `sys.analytical_values`
Values within each axis (the actual cost centers, projects, etc.).

| Column | Type | Description |
|--------|------|-------------|
| axis_id | FK | Parent axis |
| entity_id | FK | Specific entity or NULL for all |
| value_code | VARCHAR(30) | Code (e.g., 'CC-ADMIN', 'PROJ-2024-001') |
| parent_value_id | FK | Hierarchical parent |
| has_budget | BOOLEAN | Can have budget allocations? |

---

### 2. Inter-Company

#### `sys.intercompany_relationships`
Defines relationships between entities in the group.

| Column | Type | Description |
|--------|------|-------------|
| source_entity_id | FK | Parent/source entity |
| target_entity_id | FK | Subsidiary/target entity |
| relationship_type | ENUM | PARENT_SUBSIDIARY, SISTER_COMPANY, BRANCH, etc. |
| ownership_percentage | DECIMAL | % ownership for consolidation |
| ic_receivable_account | VARCHAR | Account for interco receivables |
| ic_payable_account | VARCHAR | Account for interco payables |

#### `sys.intercompany_transactions`
Tracks transactions between group entities.

| Column | Type | Description |
|--------|------|-------------|
| transaction_ref | VARCHAR | Unique reference |
| source/target_entity_id | FK | Entities involved |
| transaction_type | ENUM | SALE, PURCHASE, SERVICE, LOAN, DIVIDEND, etc. |
| amount_source_currency | DECIMAL | Amount in source currency |
| reconciliation_status | ENUM | PENDING, MATCHED, DISPUTED, ELIMINATED |
| elimination_status | ENUM | For consolidation eliminations |

---

### 3. Entity-Specific Accounting

#### `sys.entity_chart_of_accounts`
Each entity can have its own chart of accounts based on a template.

| Column | Type | Description |
|--------|------|-------------|
| entity_id | FK | The entity |
| base_template_id | FK | Base template (OHADA, IFRS, etc.) |
| fiscal_year_start | VARCHAR | When FY starts (MM-DD) |

#### `sys.entity_account_customizations`
Customizations per entity (labels, controls, defaults).

| Column | Type | Description |
|--------|------|-------------|
| entity_coa_id | FK | Parent COA |
| custom_account_label | VARCHAR | Entity-specific label |
| default_analytical_axis_id | FK | Auto-assign to this axis |
| requires_approval_above | DECIMAL | Approval threshold |

---

### 4. Consolidation

#### `sys.consolidation_groups`
Defines consolidation perimeters.

| Column | Type | Description |
|--------|------|-------------|
| group_code | VARCHAR | Group identifier |
| parent_entity_id | FK | Consolidating entity (parent) |
| consolidation_currency | CHAR(3) | Reporting currency |
| consolidation_method | ENUM | FULL, PROPORTIONAL, EQUITY_METHOD |

#### `sys.consolidation_group_members`
Entities in each consolidation group.

| Column | Type | Description |
|--------|------|-------------|
| consolidation_group_id | FK | The group |
| entity_id | FK | Member entity |
| membership_type | ENUM | PARENT, SUBSIDIARY_FULL, ASSOCIATE, etc. |
| ownership_percentage | DECIMAL | % for consolidation calculation |
| goodwill_amount | DECIMAL | Goodwill on acquisition |
| minority_interest_percentage | DECIMAL | Non-controlling interest |

#### `sys.consolidation_periods`
Consolidation reporting periods.

| Column | Type | Description |
|--------|------|-------------|
| consolidation_group_id | FK | The group |
| period_type | ENUM | MONTHLY, QUARTERLY, YEARLY |
| closing_exchange_rates | JSONB | FX rates at period end |
| status | ENUM | OPEN, IN_PROGRESS, CLOSED, LOCKED |

---

### 5. Budgets

#### `sys.budget_versions`
Budget versions (initial, revised, forecast).

| Column | Type | Description |
|--------|------|-------------|
| version_type | ENUM | INITIAL, REVISED, FORECAST, ROLLING, WHAT_IF |
| fiscal_year | INT | Budget year |
| entity_id | FK | Specific entity or NULL for consolidated |
| status | ENUM | DRAFT, SUBMITTED, APPROVED, etc. |

#### `sys.budget_lines`
Budget amounts by account/period/entity.

| Column | Type | Description |
|--------|------|-------------|
| budget_version_id | FK | Budget version |
| entity_id | FK | Entity |
| account_number | VARCHAR | Account code |
| analytical_value_id | FK | Optional analytical dimension |
| period_month | INT | 1-12 |
| amount_net | DECIMAL | Generated: debit - credit |

---

### 6. User Access Control

#### `sys.user_entity_access`
Per-entity access rights for users.

| Column | Type | Description |
|--------|------|-------------|
| user_id | FK | User |
| entity_id | FK | Entity |
| access_level | ENUM | READ, WRITE, VALIDATE, ADMIN |
| can_view_salary_data | BOOLEAN | HR data access |
| can_approve_transactions | BOOLEAN | Approval rights |
| approval_limit | DECIMAL | Max amount can approve |

---

## RPC Functions

### Entity Access

```sql
-- Get entities user can access
SELECT * FROM sys.get_user_accessible_entities();

-- Check access level
SELECT sys.check_entity_access(entity_id, 'WRITE');
```

### Analytical Hierarchy

```sql
-- Get cost center tree
SELECT * FROM sys.get_analytical_hierarchy(axis_id);
```

### Budget Dashboard

```sql
-- Budget vs Actual comparison
SELECT * FROM sys.rpc_budget_vs_actual_dashboard(
  p_entity_id := 1,
  p_fiscal_year := 2026,
  p_month := 3  -- YTD through March
);
```

---

## Views

### `sys.v_entity_hierarchy`
Recursive view showing entity tree with full path.

```sql
SELECT * FROM sys.v_entity_hierarchy WHERE tenant_id = 1;
```

| entity_code | entity_name | level | full_path |
|-------------|-------------|-------|-----------|
| PARENT_CO | Parent Company | 1 | PARENT_CO |
| SUB_A | Subsidiary A | 2 | PARENT_CO > SUB_A |
| SUB_A_BR1 | Branch 1 | 3 | PARENT_CO > SUB_A > SUB_A_BR1 |

### `sys.v_intercompany_balances`
Aggregated intercompany balances by entity pair.

```sql
SELECT * FROM sys.v_intercompany_balances WHERE tenant_id = 1;
```

---

## Permissions (New for RUBIS)

| Permission Code | Description |
|-----------------|-------------|
| MULTICOMPANY.ENTITIES.* | Entity management |
| MULTICOMPANY.INTERCO.* | Intercompany transactions |
| CONSOLIDATION.* | Consolidation operations |
| ANALYTIQUE.AXES.* | Analytical axes management |
| ANALYTIQUE.VALUES.* | Cost center management |

---

## Migration Path

### From JASPE to RUBIS

1. **Upgrade tenant tier** in `sys.tenants`:
   ```sql
   UPDATE sys.tenants SET tier = 'RUBIS', max_entities = 5 WHERE id = ?;
   ```

2. **Create analytical axes** (auto-created on tier change)

3. **Add additional entities** to `sys.tenant_entities`

4. **Configure inter-company relationships** if needed

5. **Set up user entity access** for multi-entity users

6. **Create budget versions** for the fiscal year

---

## Example: Setting Up a PME with 3 Entities

```sql
-- 1. Create parent entity (already exists from JASPE)
-- Entity: MAISON_MERE

-- 2. Add subsidiary
INSERT INTO sys.tenant_entities (
  tenant_id, entity_code, entity_name, country_code, currency_code,
  parent_entity_id, ownership_percentage, consolidation_method
) VALUES (
  1, 'FILIALE_NORD', 'Filiale Nord', 'GAB', 'XAF',
  1, 100.00, 'FULL'
);

-- 3. Add branch
INSERT INTO sys.tenant_entities (
  tenant_id, entity_code, entity_name, country_code, currency_code,
  parent_entity_id, ownership_percentage, consolidation_method
) VALUES (
  1, 'AGENCE_SUD', 'Agence Sud', 'GAB', 'XAF',
  1, 100.00, 'FULL'
);

-- 4. Define intercompany relationship
INSERT INTO sys.intercompany_relationships (
  tenant_id, source_entity_id, target_entity_id,
  relationship_type, ownership_percentage,
  ic_receivable_account, ic_payable_account
) VALUES (
  1, 1, 2, 'PARENT_SUBSIDIARY', 100.00,
  '461100', '461200'  -- OHADA interco accounts
);

-- 5. Set up consolidation group
INSERT INTO sys.consolidation_groups (
  tenant_id, group_code, group_name, parent_entity_id,
  consolidation_currency, consolidation_method
) VALUES (
  1, 'GRP_PRINCIPAL', 'Groupe Principal', 1, 'XAF', 'FULL'
);

-- 6. Add members
INSERT INTO sys.consolidation_group_members (
  consolidation_group_id, entity_id, membership_type, ownership_percentage
) VALUES
  (1, 1, 'PARENT', 100.00),
  (1, 2, 'SUBSIDIARY_FULL', 100.00),
  (1, 3, 'SUBSIDIARY_FULL', 100.00);

-- 7. Create cost centers
INSERT INTO sys.analytical_values (
  tenant_id, axis_id, value_code, value_name, has_budget
)
SELECT 1, id, 'CC-ADMIN', 'Administration', TRUE
FROM sys.analytical_axes WHERE axis_code = 'CC' AND tenant_id = 1;

INSERT INTO sys.analytical_values (
  tenant_id, axis_id, value_code, value_name, has_budget
)
SELECT 1, id, 'CC-COMM', 'Commercial', TRUE
FROM sys.analytical_axes WHERE axis_code = 'CC' AND tenant_id = 1;

INSERT INTO sys.analytical_values (
  tenant_id, axis_id, value_code, value_name, has_budget
)
SELECT 1, id, 'CC-PROD', 'Production', TRUE
FROM sys.analytical_axes WHERE axis_code = 'CC' AND tenant_id = 1;
```

---

## Next Steps (Future Sprints)

1. **Sprint 4, Day 4**: Analytical distribution RPC functions
2. **SAPHIR**: Multi-currency with automatic FX conversion
3. **SAPHIR**: IFRS parallel accounting
4. **ONYX**: Multi-country with tax regime management

---

*EdenFin RUBIS — Multi-Company Architecture v1.0*
*February 2026*
