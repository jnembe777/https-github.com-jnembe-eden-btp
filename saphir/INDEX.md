# EdenFin SAPHIR — Index

## Tier Overview

**SAPHIR** = ETI tier (50-250 employees)
- Up to 20 legal entities
- Multi-currency with FX management
- IFRS compliance (IFRS 9, 15, 16)
- Advanced consolidation
- Workflow approval engine
- BI/Reporting

## Files

| File | Description | Status |
|------|-------------|--------|
| `SAPHIR_ARCHITECTURE.md` | Architecture documentation | ✅ |
| `01_saphir_multicurrency.sql` | Multi-currency management | ✅ |
| `02_saphir_workflow.sql` | Workflow approval engine | ✅ |
| `03_saphir_ifrs.sql` | IFRS compliance | ✅ |
| `04_saphir_consolidation.sql` | Advanced consolidation | ✅ |
| `05_saphir_bi.sql` | BI/Reporting | ✅ |

## Schema Summary

### New Tables (SAPHIR)

#### Multi-Currency (01_)

| Table | Purpose |
|-------|---------|
| `sys.currencies_extended` | Extended currency master |
| `sys.exchange_rates` | FX rates by date/type |
| `sys.entity_currency_settings` | Per-entity currency config |
| `sys.fx_positions` | Daily FX positions |
| `sys.fx_revaluation_runs` | Month-end revaluation |
| `sys.fx_translation_adjustments` | CTA for consolidation |

#### Workflow (02_)

| Table | Purpose |
|-------|---------|
| `sys.workflow_definitions` | Workflow blueprints |
| `sys.workflow_steps` | Steps within workflows |
| `sys.workflow_instances` | Active workflow instances |
| `sys.approvals` | Individual approvals |
| `sys.workflow_delegations` | Out-of-office delegations |
| `sys.workflow_history` | Complete audit trail |

#### IFRS (03_)

| Table | Purpose |
|-------|---------|
| `sys.ifrs_standards_config` | IFRS standard configuration per entity |
| `sys.revenue_contracts` | IFRS 15 revenue contracts |
| `sys.performance_obligations` | IFRS 15 performance obligations |
| `sys.revenue_recognition_events` | IFRS 15 recognition events |
| `sys.lease_contracts` | IFRS 16 lease contracts |
| `sys.lease_payment_schedule` | IFRS 16 amortization schedule |
| `sys.ecl_models` | IFRS 9 ECL model definitions |
| `sys.ecl_calculations` | IFRS 9 ECL calculation results |
| `sys.impairment_tests` | IAS 36 impairment testing |

#### Consolidation (04_)

| Table | Purpose |
|-------|---------|
| `sys.consolidation_groups` | Consolidation group definitions |
| `sys.consolidation_perimeter` | Entities in scope with ownership |
| `sys.ic_account_mapping` | Intercompany account mapping |
| `sys.ic_balances` | Intercompany balance reporting |
| `sys.consolidation_runs` | Consolidation run instances |
| `sys.consolidation_packages` | Entity data packages |
| `sys.elimination_entries` | Elimination journal entries |
| `sys.elimination_entry_lines` | Elimination entry detail lines |
| `sys.minority_interests` | Non-controlling interests |
| `sys.goodwill_register` | Goodwill tracking per subsidiary |

#### BI (05_)

| Table | Purpose |
|-------|---------|
| `sys.bi_dimensions` | Dimension definitions |
| `sys.bi_dim_time` | Time dimension (calendar) |
| `sys.bi_measures` | Measure definitions |
| `sys.bi_reports` | Report template definitions |
| `sys.bi_report_sections` | Report sections |
| `sys.bi_kpis` | KPI definitions |
| `sys.bi_kpi_values` | Computed KPI values |
| `sys.bi_dashboards` | Dashboard definitions |
| `sys.bi_dashboard_widgets` | Dashboard widgets |
| `sys.bi_report_schedules` | Report scheduling |
| `sys.bi_schedule_history` | Schedule execution history |

### RPC Functions

#### Multi-Currency

| Function | Purpose |
|----------|---------|
| `sys.rpc_get_exchange_rate(...)` | Get rate for date |
| `sys.rpc_convert_amount(...)` | Convert amount |
| `sys.rpc_calculate_fx_position(...)` | Calculate positions |
| `sys.rpc_run_fx_revaluation(...)` | Month-end revaluation |

#### Workflow

| Function | Purpose |
|----------|---------|
| `sys.rpc_find_workflow(...)` | Find applicable workflow |
| `sys.rpc_start_workflow(...)` | Start workflow instance |
| `sys.rpc_approve(...)` | Record approval |
| `sys.rpc_get_pending_approvals(...)` | Get pending tasks |

#### IFRS

| Function | Purpose |
|----------|---------|
| `sys.rpc_recognize_revenue(...)` | IFRS 15 revenue recognition |
| `sys.rpc_calculate_lease_schedule(...)` | IFRS 16 lease amortization |
| `sys.rpc_calculate_ecl(...)` | IFRS 9 ECL calculation |

### Views

| View | Purpose |
|------|---------|
| `sys.v_exchange_rates_latest` | Latest rates per pair |
| `sys.v_fx_positions_summary` | Position summary |
| `sys.v_workflow_summary` | Workflow stats |
| `sys.v_pending_approvals` | Approvals by user |
| `sys.v_workflow_instances_detail` | Instance details |
| `sys.v_revenue_contracts_summary` | IFRS 15 contracts by entity |
| `sys.v_lease_portfolio` | IFRS 16 lease portfolio |
| `sys.v_ecl_summary` | IFRS 9 ECL summary |

### Permissions (Planned)

**Multi-Currency**:
- FX.RATES.VIEW/EDIT
- FX.REVALUATION.RUN/POST

**Workflow**:
- WORKFLOW.DEFINE
- WORKFLOW.APPROVE
- WORKFLOW.DELEGATE
- WORKFLOW.ADMIN

## Migration

To apply SAPHIR schema (in order):

```bash
# Requires JASPE (00-09) and RUBIS (01-03) first

# 1. Multi-currency
psql -h your-db-host -d your-db -f 01_saphir_multicurrency.sql

# 2. Workflow engine
psql -h your-db-host -d your-db -f 02_saphir_workflow.sql

# 3. IFRS (when available)
psql -h your-db-host -d your-db -f 03_saphir_ifrs.sql

# 4. Consolidation (when available)
psql -h your-db-host -d your-db -f 04_saphir_consolidation.sql

# 5. BI (when available)
psql -h your-db-host -d your-db -f 05_saphir_bi.sql
```

## Dependencies

- Requires JASPE schema (00-09)
- Requires RUBIS schema (01-03)
- Multi-currency is independent
- Workflow engine is independent
- IFRS depends on multi-currency
- Consolidation depends on multi-currency + RUBIS consolidation
- BI depends on all above

---

*Created: February 2026*
