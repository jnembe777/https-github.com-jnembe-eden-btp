# EdenFin RUBIS — Index

## Tier Overview

**RUBIS** = PME tier (10-50 employees)
- Multi-entity support (up to 5 entities)
- Analytical accounting (cost centers, projects)
- Budget management
- Inter-company transactions
- Consolidated reporting
- Full invoicing with payment tracking

## Files

| File | Description | Status |
|------|-------------|--------|
| `01_rubis_multicompany_schema.sql` | PostgreSQL schema extension for multi-company | ✅ |
| `02_rubis_analytical_rpc.sql` | Analytical distribution RPC functions | ✅ |
| `03_rubis_invoicing.sql` | Invoicing module with analytical distribution | ✅ |
| `RUBIS_MULTICOMPANY_ARCHITECTURE.md` | Architecture documentation | ✅ |
| `RUBIS_ANALYTICAL_RPC.md` | Analytical RPC documentation | ✅ |
| `RUBIS_INVOICING.md` | Invoicing module documentation | ✅ |

## Schema Summary

### New Tables (18 tables)

#### Multi-Company (01_)

| Table | Purpose |
|-------|---------|
| `sys.analytical_axes` | Analytical dimensions (CC, Project, Dept) |
| `sys.analytical_values` | Values within each axis |
| `sys.intercompany_relationships` | Entity relationships for consolidation |
| `sys.intercompany_transactions` | Transactions between entities |
| `sys.entity_chart_of_accounts` | Per-entity COA |
| `sys.entity_account_customizations` | Account customizations |
| `sys.consolidation_groups` | Consolidation perimeters |
| `sys.consolidation_group_members` | Group membership |
| `sys.consolidation_periods` | Reporting periods |
| `sys.budget_versions` | Budget versions |
| `sys.budget_lines` | Budget amounts |
| `sys.user_entity_access` | Per-entity user permissions |

#### Invoicing (03_)

| Table | Purpose |
|-------|---------|
| `sys.invoices` | Sales/Purchase invoice headers |
| `sys.invoice_lines` | Invoice line items with analytics |
| `sys.invoice_tax_summary` | Tax breakdown by rate |
| `sys.invoice_payments` | Payment records |
| `sys.invoice_reminders` | Collection reminders (3 levels) |
| `sys.invoice_sequences` | Auto-numbering per entity/type/year |

### RPC Functions (10 functions)

#### Multi-Company & Analytics

| Function | Purpose |
|----------|---------|
| `sys.get_user_accessible_entities()` | Get entities user can access |
| `sys.check_entity_access(entity, level)` | Verify access rights |
| `sys.get_analytical_hierarchy(axis)` | Get cost center tree |
| `sys.rpc_budget_vs_actual_dashboard(...)` | Budget vs actual |

#### Invoicing

| Function | Purpose |
|----------|---------|
| `sys.rpc_create_invoice(...)` | Create invoice with lines |
| `sys.rpc_validate_invoice(...)` | Validate draft invoice |
| `sys.rpc_record_payment(...)` | Record payment |
| `sys.rpc_get_invoices_aging(...)` | Aging analysis |
| `sys.rpc_get_invoice_analytical_summary(...)` | Analytics by cost center |
| `sys.rpc_post_invoice_to_accounting(...)` | Post to journal |

### Views (5 views)

| View | Purpose |
|------|---------|
| `sys.v_entity_hierarchy` | Recursive entity tree |
| `sys.v_intercompany_balances` | Intercompany summary |
| `sys.v_invoice_summary` | Invoice overview with days overdue |
| `sys.v_invoices_overdue` | Overdue invoices only |
| `sys.v_invoice_analytics` | Monthly aggregations |

### Permissions (27 new)

**Multi-Company**:
- MULTICOMPANY.ENTITIES.* (CREATE, UPDATE, DELETE)
- MULTICOMPANY.INTERCO.* (READ, CREATE, RECONCILE)
- CONSOLIDATION.* (READ, EXECUTE, VALIDATE)
- ANALYTIQUE.* (AXES.CREATE/UPDATE, VALUES.CREATE/UPDATE)

**Invoicing**:
- INVOICING.SALES.* (CREATE, READ, UPDATE, DELETE, VALIDATE)
- INVOICING.PURCHASE.* (CREATE, READ, UPDATE, DELETE, VALIDATE)
- INVOICING.PAYMENTS.* (CREATE, READ)
- INVOICING.REMINDERS.CREATE
- INVOICING.ANALYTICS.READ

## Migration

To apply RUBIS schema (in order):

```bash
# 1. Multi-company foundation
psql -h your-db-host -d your-db -f 01_rubis_multicompany_schema.sql

# 2. Analytical distribution (optional, requires 01_)
psql -h your-db-host -d your-db -f 02_rubis_analytical_rpc.sql

# 3. Invoicing module (requires 01_ and 02_)
psql -h your-db-host -d your-db -f 03_rubis_invoicing.sql
```

Or via Supabase SQL editor (apply files in order).

## Dependencies

- Requires JASPE schema (02_schema_system.sql) to be applied first
- Requires common schema (01_schema_common.sql)
- 03_rubis_invoicing.sql depends on 01_ and 02_

---

*Created: February 2026*
