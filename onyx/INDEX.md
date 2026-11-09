# EdenFin ONYX — Index

## Tier Overview

**ONYX** = GE tier (250+ employees)
- Unlimited legal entities
- Unlimited countries
- Multi-GAAP (OHADA + IFRS + Local)
- Advanced treasury management
- Transfer pricing compliance
- Public sector capabilities
- Full regulatory compliance

## Files

| File | Description | Status |
|------|-------------|--------|
| `ONYX_ARCHITECTURE.md` | Architecture documentation | ✅ |
| `01_onyx_multicountry.sql` | Multi-country management | ✅ |
| `02_onyx_treasury.sql` | Treasury management | ✅ |
| `03_onyx_transfer_pricing.sql` | Transfer pricing | ✅ |
| `04_onyx_consolidation.sql` | Advanced consolidation | ✅ |
| `05_onyx_public_sector.sql` | Public sector/fund accounting | ✅ |
| `06_onyx_regulatory.sql` | Regulatory compliance | ✅ |
| `07_onyx_integration.sql` | Integration hub | ✅ |

## Schema Summary

### New Tables (ONYX) — Planned

#### Multi-Country (01_)

| Table | Purpose |
|-------|---------|
| `sys.countries` | Country configurations |
| `sys.jurisdictions` | Sub-national jurisdictions |
| `sys.legal_entity_registry` | Comprehensive entity registration |
| `sys.gaap_mappings` | Multi-GAAP account mappings |
| `sys.statutory_reporting_config` | Country-specific reporting |
| `sys.tax_regimes` | Tax regime configurations |
| `sys.labor_law_config` | Employment law per country |
| `sys.accounting_standards` | GAAP framework definitions |

#### Treasury (02_)

| Table | Purpose |
|-------|---------|
| `sys.cash_pools` | Cash pool structures |
| `sys.cash_pool_members` | Pool membership |
| `sys.cash_forecasts` | Cash flow forecasting |
| `sys.fx_hedges` | FX hedge instruments |
| `sys.hedge_effectiveness_tests` | IAS 39/IFRS 9 testing |
| `sys.bank_connections` | Bank connectivity config |
| `sys.netting_runs` | IC netting cycles |
| `sys.sweep_instructions` | Cash sweep rules |

#### Transfer Pricing (03_)

| Table | Purpose |
|-------|---------|
| `sys.transfer_pricing_policies` | TP policy definitions |
| `sys.tp_transactions` | TP transaction tracking |
| `sys.tp_documentation` | Master/local files |
| `sys.tp_comparables` | Benchmarking data |
| `sys.cbcr_reports` | Country-by-Country Reports |
| `sys.arm_length_tests` | TP validation results |

#### Advanced Consolidation (04_)

| Table | Purpose |
|-------|---------|
| `sys.consolidation_hierarchies` | Multiple hierarchy definitions |
| `sys.hierarchy_nodes` | Hierarchy structure |
| `sys.subgroup_definitions` | Sub-consolidation groups |
| `sys.parallel_consolidations` | Multi-GAAP consolidation runs |
| `sys.equity_chains` | Complex ownership chains |
| `sys.acquisition_adjustments` | Purchase price allocation |

#### Public Sector (05_)

| Table | Purpose |
|-------|---------|
| `sys.funds` | Government funds |
| `sys.appropriations` | Budget appropriations |
| `sys.grants` | Grant management |
| `sys.procurement_contracts` | Public procurement |
| `sys.ipsas_mappings` | IPSAS compliance |
| `sys.encumbrances` | Commitment tracking |
| `sys.fund_transfers` | Inter-fund transfers |
| `sys.budget_amendments` | Appropriation changes |

#### Regulatory (06_)

| Table | Purpose |
|-------|---------|
| `sys.xbrl_taxonomies` | XBRL taxonomy definitions |
| `sys.xbrl_filings` | XBRL/iXBRL submissions |
| `sys.sox_controls` | SOX control documentation |
| `sys.einvoice_formats` | eInvoicing configurations |
| `sys.tax_digital_submissions` | MTD/SII/SAF-T submissions |
| `sys.audit_archive` | Tamper-proof audit logs |

#### Integration Hub (07_)

| Table | Purpose |
|-------|---------|
| `sys.integration_endpoints` | External system connections |
| `sys.api_credentials` | Secure credential storage |
| `sys.sync_jobs` | Data synchronization jobs |
| `sys.data_exports` | BI/DWH exports |
| `sys.webhook_config` | Webhook configurations |

### RPC Functions (Planned)

#### Multi-Country

| Function | Purpose |
|----------|---------|
| `sys.rpc_get_entity_legal_config(...)` | Entity legal configuration |
| `sys.rpc_calculate_statutory_statements(...)` | Statutory reporting |
| `sys.rpc_convert_gaap(...)` | GAAP conversion |

#### Treasury

| Function | Purpose |
|----------|---------|
| `sys.rpc_run_cash_pool_sweep(...)` | Execute cash sweep |
| `sys.rpc_generate_cash_forecast(...)` | ML-based forecast |
| `sys.rpc_calculate_hedge_effectiveness(...)` | Hedge testing |
| `sys.rpc_execute_netting_run(...)` | IC netting |

#### Transfer Pricing

| Function | Purpose |
|----------|---------|
| `sys.rpc_validate_tp_transaction(...)` | Arm's length validation |
| `sys.rpc_generate_cbcr_report(...)` | CbCR generation |

#### Consolidation

| Function | Purpose |
|----------|---------|
| `sys.rpc_run_parallel_consolidation(...)` | Multi-GAAP consolidation |
| `sys.rpc_calculate_equity_chain(...)` | Effective ownership |

### Permissions (Planned)

**Multi-Country**:
- COUNTRY.CONFIG.VIEW/EDIT
- LEGAL_ENTITY.REGISTER
- GAAP.MAPPING.MANAGE

**Treasury**:
- CASH_POOL.VIEW/MANAGE
- FORECAST.VIEW/EDIT
- HEDGE.VIEW/MANAGE
- NETTING.EXECUTE

**Transfer Pricing**:
- TP.POLICY.VIEW/EDIT
- TP.DOCUMENTATION.VIEW/GENERATE
- CBCR.VIEW/SUBMIT

**Regulatory**:
- XBRL.VIEW/SUBMIT
- TAX_DIGITAL.VIEW/SUBMIT
- AUDIT.VIEW

## Migration

To apply ONYX schema (in order):

```bash
# Requires JASPE (00-09), RUBIS (01-03), and SAPHIR (01-05) first

# 1. Multi-country
psql -h your-db-host -d your-db -f 01_onyx_multicountry.sql

# 2. Treasury management
psql -h your-db-host -d your-db -f 02_onyx_treasury.sql

# 3. Transfer pricing
psql -h your-db-host -d your-db -f 03_onyx_transfer_pricing.sql

# 4. Advanced consolidation
psql -h your-db-host -d your-db -f 04_onyx_consolidation_adv.sql

# 5. Public sector
psql -h your-db-host -d your-db -f 05_onyx_public_sector.sql

# 6. Regulatory
psql -h your-db-host -d your-db -f 06_onyx_regulatory.sql

# 7. Integration hub
psql -h your-db-host -d your-db -f 07_onyx_integration.sql
```

## Dependencies

- Requires JASPE schema (00-09)
- Requires RUBIS schema (01-03)
- Requires SAPHIR schema (01-05)
- Multi-country is foundational (must be first)
- Treasury depends on multi-currency (SAPHIR)
- Transfer pricing depends on multi-entity (RUBIS)
- Advanced consolidation extends SAPHIR consolidation
- Public sector is independent
- Regulatory depends on all above
- Integration hub depends on all above

## Implementation Progress

| Module | Status | Sprint |
|--------|--------|--------|
| Architecture | ✅ Complete | 10 |
| Multi-Country | ✅ Complete | 11 |
| Treasury | ✅ Complete | 12 |
| Transfer Pricing | ✅ Complete | 13 |
| Adv. Consolidation | ✅ Complete | 14 |
| Public Sector | ✅ Complete | 15 |
| Regulatory | ✅ Complete | 16 |
| Integration Hub | ✅ Complete | 17 |

---

*Created: February 2026*
