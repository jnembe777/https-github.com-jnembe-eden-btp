# EdenFin SAPHIR — Enterprise Architecture

## Overview

SAPHIR is the third tier of EdenFin ERP, targeting ETI (Entreprises de Taille Intermédiaire) with 50-250 employees. It adds enterprise-grade capabilities on top of RUBIS.

### Tier Progression

| Tier | Target | Max Entities | Key Features |
|------|--------|--------------|--------------|
| JASPE | TPE (<10) | 1 | Single entity, basic accounting |
| RUBIS | PME (10-50) | 5 | Multi-entity, analytical, budgets |
| **SAPHIR** | ETI (50-250) | **20** | **Multi-currency, IFRS, workflows** |
| ONYX | GE (250+) | Unlimited | Multi-country, full consolidation |

---

## SAPHIR Feature Matrix

### 1. Multi-Currency Management

| Feature | Description |
|---------|-------------|
| Transaction currencies | Record transactions in any currency |
| Functional currency | Each entity has a functional currency |
| Exchange rates | Daily/monthly rates from ECB, BEAC, XE |
| Revaluation | Month-end FX gain/loss posting |
| Translation | Convert to group reporting currency |

**Tables**: `currencies_extended`, `exchange_rates`, `fx_revaluation_runs`

### 2. IFRS Compliance

| Standard | Implementation |
|----------|----------------|
| IFRS 9 | Expected credit loss (ECL) model |
| IFRS 15 | Revenue recognition (POC, milestones) |
| IFRS 16 | Lease accounting (ROU assets, liabilities) |
| IAS 21 | Foreign currency translation |
| IAS 36 | Impairment testing |

**Tables**: `ifrs_standards`, `revenue_contracts`, `lease_contracts`, `ecl_models`

### 3. Advanced Consolidation

| Feature | Description |
|---------|-------------|
| Full consolidation | 100% subsidiaries |
| Proportional | Joint ventures by % |
| Equity method | Associates (20-50%) |
| Eliminations | Automatic intercompany elimination |
| Minority interest | Non-controlling interests |

**Tables**: `consolidation_rules`, `elimination_entries`, `minority_interests`

### 4. Workflow Engine

| Feature | Description |
|---------|-------------|
| Approval workflows | Multi-level, amount-based |
| Delegation | Out-of-office delegation |
| Escalation | Time-based escalation |
| Audit trail | Full workflow history |
| Notifications | Email/SMS on pending tasks |

**Tables**: `workflow_definitions`, `workflow_steps`, `workflow_instances`, `approvals`

### 5. Business Intelligence

| Feature | Description |
|---------|-------------|
| Financial reports | P&L, Balance Sheet, Cash Flow |
| KPIs | Configurable KPI dashboard |
| Drill-down | Account → Transaction → Document |
| Exports | Excel, PDF, CSV |
| Scheduling | Automated report distribution |

**Tables**: `bi_reports`, `bi_dimensions`, `bi_measures`, `report_schedules`

---

## Schema Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                    SAPHIR LAYER                                      │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────────┐       │
│  │  MULTI-CURRENCY      │  │  IFRS COMPLIANCE     │  │  WORKFLOW ENGINE     │       │
│  │                      │  │                      │  │                      │       │
│  │  • currencies_ext    │  │  • ifrs_standards    │  │  • workflow_defs     │       │
│  │  • exchange_rates    │  │  • revenue_contracts │  │  • workflow_steps    │       │
│  │  • fx_positions      │  │  • lease_contracts   │  │  • workflow_inst     │       │
│  │  • fx_revaluations   │  │  • ecl_models        │  │  • approvals         │       │
│  │  • translation_adj   │  │  • impairment_tests  │  │  • delegations       │       │
│  └──────────────────────┘  └──────────────────────┘  └──────────────────────┘       │
│                                                                                      │
│  ┌──────────────────────┐  ┌──────────────────────┐                                 │
│  │  ADV. CONSOLIDATION  │  │  BI / REPORTING      │                                 │
│  │                      │  │                      │                                 │
│  │  • consol_rules      │  │  • bi_reports        │                                 │
│  │  • consol_methods    │  │  • bi_dimensions     │                                 │
│  │  • elimination_rules │  │  • bi_measures       │                                 │
│  │  • minority_interest │  │  • report_schedules  │                                 │
│  │  • consol_packages   │  │  • saved_filters     │                                 │
│  └──────────────────────┘  └──────────────────────┘                                 │
│                                                                                      │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                    RUBIS LAYER                                       │
│  (Multi-entity, Analytical accounting, Budgets, Intercompany, Invoicing)            │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                    JASPE LAYER                                       │
│  (Core accounting, Payroll, Assets, Inventory, Common/OHADA)                        │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## New Tables (SAPHIR)

### Summary

| Module | Tables | Functions | Views |
|--------|--------|-----------|-------|
| Multi-Currency | 5 | 4 | 2 |
| IFRS Compliance | 6 | 5 | 3 |
| Consolidation | 5 | 4 | 2 |
| Workflow | 6 | 5 | 3 |
| BI/Reporting | 4 | 3 | 2 |
| **Total** | **26** | **21** | **12** |

---

## 1. Multi-Currency Module

### 1.1 Extended Currency Management

```sql
sys.currencies_extended
├── currency_code (ISO 4217)
├── currency_name
├── decimal_places
├── symbol
├── is_functional     -- Can be used as functional currency
├── is_reporting      -- Can be used as reporting currency
├── rate_source       -- ECB, BEAC, MANUAL
└── last_rate_date
```

### 1.2 Exchange Rates

```sql
sys.exchange_rates
├── from_currency
├── to_currency
├── rate_date
├── rate_type         -- SPOT, CLOSING, AVERAGE, BUDGET
├── rate
├── source            -- ECB, BEAC, XE, MANUAL
└── is_inverted       -- Stored as inverse
```

### 1.3 FX Positions

```sql
sys.fx_positions
├── entity_id
├── currency_code
├── position_date
├── monetary_assets   -- Cash, receivables
├── monetary_liabs    -- Payables, loans
├── net_position
└── functional_value  -- In functional currency
```

### 1.4 FX Revaluation

```sql
sys.fx_revaluation_runs
├── entity_id
├── run_date
├── rate_type
├── status            -- DRAFT, POSTED, REVERSED
├── total_gain_loss
└── journal_entry_id  -- Posted entry
```

---

## 2. IFRS Compliance Module

### 2.1 Standards Registry

```sql
sys.ifrs_standards
├── standard_code     -- IFRS9, IFRS15, IFRS16, IAS21, etc.
├── standard_name
├── effective_date
├── implementation_date
├── is_active
└── configuration     -- JSON config per standard
```

### 2.2 Revenue Contracts (IFRS 15)

```sql
sys.revenue_contracts
├── contract_number
├── customer_id
├── contract_type     -- FIXED_PRICE, TIME_MATERIAL, SUBSCRIPTION
├── recognition_method -- POINT_IN_TIME, OVER_TIME, POC
├── total_value
├── recognized_revenue
├── deferred_revenue
└── milestones[]      -- Array of milestones
```

### 2.3 Lease Contracts (IFRS 16)

```sql
sys.lease_contracts
├── contract_number
├── lessor_name
├── asset_description
├── lease_type        -- FINANCE, OPERATING (pre-IFRS16)
├── start_date
├── end_date
├── monthly_payment
├── discount_rate     -- Incremental borrowing rate
├── rou_asset_value   -- Right-of-use asset
├── lease_liability   -- Present value of payments
└── depreciation_method
```

### 2.4 Expected Credit Loss (IFRS 9)

```sql
sys.ecl_models
├── entity_id
├── model_name
├── portfolio_type    -- RECEIVABLES, LOANS, INVESTMENTS
├── methodology       -- SIMPLIFIED, GENERAL
├── pd_matrix         -- Probability of default (JSON)
├── lgd_rate          -- Loss given default
├── exposure_at_default
└── ecl_provision
```

---

## 3. Advanced Consolidation Module

### 3.1 Consolidation Methods

| Method | Ownership | Treatment |
|--------|-----------|-----------|
| FULL | >50% | 100% assets/liabilities, eliminate IC |
| PROPORTIONAL | Joint venture | % of assets/liabilities |
| EQUITY | 20-50% | Share of net assets on one line |

### 3.2 Tables

```sql
sys.consolidation_methods
├── method_code
├── method_name
├── ownership_min
├── ownership_max
├── treatment_rules   -- JSON rules

sys.consolidation_rules
├── parent_entity_id
├── child_entity_id
├── method_code
├── elimination_rules -- JSON: IC balances, transactions
├── translation_method -- CURRENT, TEMPORAL

sys.elimination_entries
├── consolidation_period_id
├── elimination_type  -- IC_RECEIVABLE, IC_PAYABLE, IC_REVENUE, DIVIDEND
├── dr_account
├── cr_account
├── amount
├── source_entity_id
├── target_entity_id
```

---

## 4. Workflow Engine

### 4.1 Workflow Definition

```sql
sys.workflow_definitions
├── workflow_code
├── workflow_name
├── entity_type       -- INVOICE, PAYMENT, JOURNAL, CONTRACT
├── trigger_condition -- JSON: amount > X, type = Y
├── is_active
└── timeout_hours     -- Auto-escalation timeout
```

### 4.2 Workflow Steps

```sql
sys.workflow_steps
├── workflow_id
├── step_order
├── step_name
├── approver_type     -- USER, ROLE, HIERARCHY
├── approver_id       -- Specific user or role
├── approval_rule     -- ANY, ALL, MAJORITY
├── amount_threshold  -- Step applies if amount > threshold
├── sla_hours         -- Expected completion time
└── escalation_to     -- Next approver if timeout
```

### 4.3 Workflow Instances

```sql
sys.workflow_instances
├── workflow_id
├── entity_type
├── entity_id         -- The document being approved
├── current_step
├── status            -- PENDING, APPROVED, REJECTED, CANCELLED
├── started_at
├── completed_at
├── started_by
└── metadata          -- JSON context
```

### 4.4 Approvals

```sql
sys.approvals
├── workflow_instance_id
├── step_id
├── approver_id
├── decision          -- APPROVED, REJECTED, DELEGATED
├── comments
├── decided_at
├── delegated_to      -- If delegated
└── ip_address        -- Audit
```

---

## 5. BI / Reporting Module

### 5.1 Report Definitions

```sql
sys.bi_reports
├── report_code
├── report_name
├── report_type       -- FINANCIAL, OPERATIONAL, CUSTOM
├── base_query        -- SQL or view name
├── dimensions[]      -- Available drill-down dimensions
├── measures[]        -- Available measures
├── default_filters   -- JSON default parameters
└── access_roles[]    -- Roles that can run this report
```

### 5.2 Report Schedules

```sql
sys.report_schedules
├── report_id
├── schedule_name
├── cron_expression   -- "0 8 * * 1" (Mondays 8am)
├── output_format     -- PDF, XLSX, CSV
├── recipients[]      -- Email addresses
├── parameters        -- JSON report parameters
├── last_run_at
├── next_run_at
└── is_active
```

---

## Migration Strategy

### From RUBIS to SAPHIR

1. **Prerequisites**:
   - JASPE schema (00-09)
   - RUBIS schema (01-03)

2. **SAPHIR Migration Order**:
   ```bash
   # Multi-currency (independent)
   psql -f 01_saphir_multicurrency.sql

   # IFRS (requires multi-currency)
   psql -f 02_saphir_ifrs.sql

   # Advanced consolidation (requires RUBIS consolidation)
   psql -f 03_saphir_consolidation.sql

   # Workflow engine (independent)
   psql -f 04_saphir_workflow.sql

   # BI/Reporting (requires all above)
   psql -f 05_saphir_bi.sql
   ```

3. **Data Migration**:
   - Set functional currency for each entity
   - Import historical exchange rates
   - Configure IFRS adoption dates
   - Define workflow rules
   - Create report templates

---

## RPC Functions (SAPHIR)

### Multi-Currency

| Function | Description |
|----------|-------------|
| `rpc_get_exchange_rate(from, to, date, type)` | Get rate for date |
| `rpc_convert_amount(amount, from, to, date)` | Convert amount |
| `rpc_run_fx_revaluation(entity_id, date)` | Month-end revaluation |
| `rpc_translate_to_reporting(entity_id, period)` | Translate to group currency |

### IFRS

| Function | Description |
|----------|-------------|
| `rpc_calculate_ecl(entity_id, portfolio)` | Calculate expected credit loss |
| `rpc_recognize_revenue(contract_id, period)` | IFRS 15 revenue recognition |
| `rpc_calculate_lease(contract_id)` | IFRS 16 ROU/liability |
| `rpc_post_ifrs_adjustments(entity_id, period)` | Post all IFRS adjustments |

### Consolidation

| Function | Description |
|----------|-------------|
| `rpc_run_consolidation(group_id, period)` | Run full consolidation |
| `rpc_generate_eliminations(group_id, period)` | Generate IC eliminations |
| `rpc_calculate_minority_interest(entity_id)` | Calculate NCI |

### Workflow

| Function | Description |
|----------|-------------|
| `rpc_start_workflow(entity_type, entity_id)` | Start approval workflow |
| `rpc_approve(instance_id, decision, comments)` | Record approval |
| `rpc_delegate(instance_id, to_user_id)` | Delegate approval |
| `rpc_get_pending_approvals(user_id)` | Get pending tasks |

---

## Permissions (SAPHIR)

### New Permission Codes

```
# Multi-Currency
FX.RATES.VIEW
FX.RATES.EDIT
FX.REVALUATION.RUN
FX.REVALUATION.POST

# IFRS
IFRS.CONFIG.VIEW
IFRS.CONFIG.EDIT
IFRS.ADJUSTMENTS.RUN
IFRS.ADJUSTMENTS.POST

# Consolidation
CONSOL.RUN
CONSOL.VALIDATE
CONSOL.ELIMINATIONS.VIEW
CONSOL.ELIMINATIONS.EDIT

# Workflow
WORKFLOW.DEFINE
WORKFLOW.APPROVE
WORKFLOW.DELEGATE
WORKFLOW.ADMIN

# BI
BI.REPORTS.VIEW
BI.REPORTS.CREATE
BI.REPORTS.SCHEDULE
BI.EXPORTS.EXCEL
BI.EXPORTS.PDF
```

---

## Configuration Parameters

### System Settings for SAPHIR

| Parameter | Default | Description |
|-----------|---------|-------------|
| `FX_RATE_SOURCE` | 'ECB' | Default rate source |
| `FX_RATE_TYPE_DEFAULT` | 'CLOSING' | Default rate type |
| `IFRS_ADOPTION_DATE` | NULL | IFRS adoption date |
| `CONSOLIDATION_METHOD` | 'FULL' | Default method |
| `WORKFLOW_TIMEOUT_HOURS` | 48 | Default approval timeout |
| `BI_CACHE_MINUTES` | 30 | Report cache duration |

---

## Integration Points

### External Systems

| System | Direction | Data |
|--------|-----------|------|
| ECB Rates API | Inbound | Daily EUR exchange rates |
| BEAC | Inbound | XAF/XOF rates |
| Email Server | Outbound | Workflow notifications |
| Document Store | Bidirectional | Supporting documents |

---

*EdenFin SAPHIR Architecture — February 2026*
