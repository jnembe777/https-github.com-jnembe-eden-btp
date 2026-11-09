# EdenFin ONYX — Enterprise Group Architecture

## Overview

ONYX is the fourth and final tier of EdenFin ERP, targeting GE (Grandes Entreprises) and multinational groups with 250+ employees. It provides world-class capabilities for complex corporate structures.

### Tier Progression

| Tier | Target | Max Entities | Max Countries | Key Features |
|------|--------|--------------|---------------|--------------|
| JASPE | TPE (<10) | 1 | 1 | Single entity, basic accounting |
| RUBIS | PME (10-50) | 5 | 1 | Multi-entity, analytical, budgets |
| SAPHIR | ETI (50-250) | 20 | 3 | Multi-currency, IFRS, workflows |
| **ONYX** | GE (250+) | **Unlimited** | **Unlimited** | **Multi-country, full consolidation, treasury** |

---

## ONYX Feature Matrix

### 1. Multi-Country/Multi-Jurisdiction

| Feature | Description |
|---------|-------------|
| Country configurations | Legal, tax, labor per country |
| Multi-GAAP | OHADA + IFRS + Local GAAP simultaneously |
| Statutory reporting | Country-specific financial statements |
| Tax compliance | VAT, withholding, corporate tax per jurisdiction |
| Legal entity structure | Complex holding structures |

**New Tables**: `countries`, `jurisdictions`, `legal_entity_registry`, `statutory_reporting_config`

### 2. Advanced Treasury Management

| Feature | Description |
|---------|-------------|
| Cash pooling | Notional and physical pooling |
| Cash forecasting | ML-based cash flow predictions |
| FX hedging | Forward contracts, options tracking |
| Bank connectivity | SWIFT, EBICS, local formats |
| Working capital | DSO/DPO optimization |

**New Tables**: `cash_pools`, `cash_forecasts`, `fx_hedges`, `bank_connections`, `netting_runs`

### 3. Transfer Pricing

| Feature | Description |
|---------|-------------|
| IC pricing policies | Cost-plus, resale, TNMM |
| Documentation | Master file, local files |
| Benchmarking | Comparable analysis |
| Adjustments | Year-end TP adjustments |
| CbCR support | Country-by-Country Reporting |

**New Tables**: `transfer_pricing_policies`, `tp_documentation`, `tp_adjustments`, `cbcr_reports`

### 4. Multi-Hierarchy Consolidation

| Feature | Description |
|---------|-------------|
| Multiple hierarchies | Legal, management, segment |
| Sub-consolidations | Regional roll-ups |
| Dynamic perimeter | Acquisition/disposal handling |
| Parallel consolidations | OHADA + IFRS parallel |
| Equity pickup | Complex minority chains |

**New Tables**: `consolidation_hierarchies`, `subgroup_definitions`, `parallel_consolidations`, `equity_chains`

### 5. Public Sector Capabilities

| Feature | Description |
|---------|-------------|
| Fund accounting | Government fund tracking |
| Budget control | Appropriation management |
| Grant management | Grant lifecycle |
| Public procurement | Tender integration |
| IPSAS compliance | Public sector IFRS |

**New Tables**: `funds`, `appropriations`, `grants`, `procurement_contracts`, `ipsas_mappings`

### 6. Advanced Intercompany

| Feature | Description |
|---------|-------------|
| IC netting | Multilateral netting |
| IC reconciliation | Real-time matching |
| Settlement automation | Payment instructions |
| Dispute management | IC dispute workflow |
| IC margin analysis | Profit attribution |

**New Tables**: `ic_netting_runs`, `ic_disputes`, `ic_settlements`, `ic_margin_analysis`

### 7. Regulatory & Compliance

| Feature | Description |
|---------|-------------|
| XBRL reporting | iXBRL taxonomy support |
| Audit trail | Tamper-proof audit log |
| SOX compliance | Control documentation |
| eInvoicing | PEPPOL, Factur-X, UBL |
| Tax digital | MTD (UK), SII (Spain), SAF-T |

**New Tables**: `xbrl_taxonomies`, `xbrl_filings`, `sox_controls`, `einvoice_formats`, `tax_digital_submissions`

### 8. Integration Hub

| Feature | Description |
|---------|-------------|
| ERP connectors | SAP, Oracle, Microsoft |
| Banking APIs | Open Banking, PSD2 |
| Tax authority APIs | Direct filing |
| Document management | ECM integration |
| BI/Analytics | Data warehouse export |

**New Tables**: `integration_endpoints`, `api_credentials`, `sync_jobs`, `data_exports`

---

## Schema Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                                        ONYX LAYER                                            │
├─────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                              │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐                  │
│  │  MULTI-COUNTRY      │  │  TREASURY MGMT      │  │  TRANSFER PRICING   │                  │
│  │                     │  │                     │  │                     │                  │
│  │  • countries        │  │  • cash_pools       │  │  • tp_policies      │                  │
│  │  • jurisdictions    │  │  • cash_forecasts   │  │  • tp_documentation │                  │
│  │  • legal_registry   │  │  • fx_hedges        │  │  • tp_adjustments   │                  │
│  │  • statutory_config │  │  • bank_connections │  │  • cbcr_reports     │                  │
│  │  • multi_gaap       │  │  • netting_runs     │  │  • arm_length_tests │                  │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘                  │
│                                                                                              │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐                  │
│  │  ADV CONSOLIDATION  │  │  PUBLIC SECTOR      │  │  IC ADVANCED        │                  │
│  │                     │  │                     │  │                     │                  │
│  │  • hierarchies      │  │  • funds            │  │  • ic_netting       │                  │
│  │  • subgroups        │  │  • appropriations   │  │  • ic_disputes      │                  │
│  │  • parallel_consol  │  │  • grants           │  │  • ic_settlements   │                  │
│  │  • equity_chains    │  │  • ipsas_mappings   │  │  • ic_margin        │                  │
│  │  • acquisition_adj  │  │  • procurement      │  │  • ic_pricing       │                  │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘                  │
│                                                                                              │
│  ┌─────────────────────┐  ┌─────────────────────┐                                           │
│  │  REGULATORY         │  │  INTEGRATION HUB    │                                           │
│  │                     │  │                     │                                           │
│  │  • xbrl_filings     │  │  • endpoints        │                                           │
│  │  • sox_controls     │  │  • api_credentials  │                                           │
│  │  • einvoice_formats │  │  • sync_jobs        │                                           │
│  │  • tax_digital      │  │  • data_exports     │                                           │
│  │  • audit_archive    │  │  • webhook_config   │                                           │
│  └─────────────────────┘  └─────────────────────┘                                           │
│                                                                                              │
├─────────────────────────────────────────────────────────────────────────────────────────────┤
│                                       SAPHIR LAYER                                           │
│  (Multi-currency, IFRS compliance, Workflow engine, Basic consolidation, BI)                │
├─────────────────────────────────────────────────────────────────────────────────────────────┤
│                                        RUBIS LAYER                                           │
│  (Multi-entity, Analytical accounting, Budgets, Intercompany, Invoicing)                    │
├─────────────────────────────────────────────────────────────────────────────────────────────┤
│                                        JASPE LAYER                                           │
│  (Core accounting, Payroll, Assets, Inventory, Common/OHADA)                                │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Module Details

### 1. Multi-Country Module

#### 1.1 Country Configuration

```sql
-- Country master with legal requirements
sys.countries
├── country_code (ISO 3166-1 alpha-2)
├── country_name
├── currency_code (ISO 4217)
├── tax_identification_format (regex)
├── fiscal_year_start (month)
├── language_code
├── date_format
├── number_format
├── vat_standard_rate
├── corporate_tax_rate
├── withholding_tax_config (JSONB)
├── statutory_audit_required (BOOLEAN)
└── is_active
```

#### 1.2 Jurisdictions

```sql
-- Sub-national jurisdictions (states, provinces, zones)
sys.jurisdictions
├── jurisdiction_id
├── country_code
├── jurisdiction_code
├── jurisdiction_name
├── jurisdiction_type (STATE, PROVINCE, ZONE, MUNICIPALITY)
├── tax_authority
├── local_tax_rates (JSONB)
└── special_economic_zone (BOOLEAN)
```

#### 1.3 Legal Entity Registry

```sql
-- Comprehensive entity registration
sys.legal_entity_registry
├── entity_id (FK entities)
├── country_code
├── legal_name
├── trade_name
├── legal_form (SA, SARL, SAS, GmbH, Ltd, Inc)
├── registration_number
├── tax_id
├── vat_id
├── incorporation_date
├── registered_address
├── share_capital
├── functional_currency
├── reporting_currency
├── gaap_framework (OHADA, IFRS, LOCAL_GAAP)
├── auditor_name
├── fiscal_year_end
├── is_holding
├── parent_entity_id
├── ownership_percentage
└── consolidation_method
```

#### 1.4 Multi-GAAP Support

```sql
-- Parallel accounting under different GAAPs
sys.gaap_mappings
├── mapping_id
├── entity_id
├── source_gaap (OHADA, IFRS, etc.)
├── target_gaap
├── source_account_code
├── target_account_code
├── adjustment_type (RECLASSIFICATION, REVALUATION, TIMING)
├── adjustment_formula
└── is_active
```

### 2. Treasury Management Module

#### 2.1 Cash Pooling

```sql
-- Cash pool structures
sys.cash_pools
├── pool_id
├── pool_name
├── pool_type (NOTIONAL, PHYSICAL, HYBRID)
├── header_entity_id
├── pool_currency
├── interest_calculation_method
├── sweep_frequency
├── target_balance
└── is_active

sys.cash_pool_members
├── member_id
├── pool_id
├── entity_id
├── bank_account_id
├── contribution_percentage
├── interest_allocation_rule
└── is_header
```

#### 2.2 Cash Forecasting

```sql
-- Cash flow forecasts
sys.cash_forecasts
├── forecast_id
├── entity_id
├── forecast_date
├── forecast_type (DAILY, WEEKLY, MONTHLY)
├── category (OPERATING, INVESTING, FINANCING)
├── subcategory
├── currency_code
├── amount_original
├── amount_forecast
├── confidence_level (percentage)
├── source (MANUAL, ML_PREDICTED, BUDGET)
├── actual_amount
├── variance
└── created_at
```

#### 2.3 FX Hedging

```sql
-- Hedge instruments
sys.fx_hedges
├── hedge_id
├── entity_id
├── hedge_type (FORWARD, OPTION, SWAP, COLLAR)
├── hedge_relationship (CASH_FLOW, FAIR_VALUE, NET_INVESTMENT)
├── underlying_exposure_id
├── counterparty_bank
├── trade_date
├── settlement_date
├── notional_amount
├── strike_rate
├── premium
├── fair_value
├── effectiveness_ratio
├── is_designated
└── status

sys.hedge_effectiveness_tests
├── test_id
├── hedge_id
├── test_date
├── prospective_ratio
├── retrospective_ratio
├── is_effective
└── notes
```

### 3. Transfer Pricing Module

#### 3.1 TP Policies

```sql
-- Transfer pricing policies
sys.transfer_pricing_policies
├── policy_id
├── policy_name
├── entity_from_id
├── entity_to_id
├── transaction_type (GOODS, SERVICES, ROYALTIES, INTEREST)
├── pricing_method (CUP, COST_PLUS, RESALE_MINUS, TNMM, PSM)
├── markup_percentage
├── comparable_range_min
├── comparable_range_max
├── arm_length_range_median
├── effective_from
├── effective_to
├── documentation_reference
└── approved_by

sys.tp_transactions
├── transaction_id
├── policy_id
├── transaction_date
├── amount_charged
├── arm_length_amount
├── variance
├── adjustment_required
└── adjustment_amount
```

#### 3.2 Country-by-Country Reporting

```sql
-- CbCR data
sys.cbcr_reports
├── report_id
├── group_entity_id
├── reporting_year
├── submission_deadline
├── jurisdiction_code
├── revenues_unrelated
├── revenues_related
├── profit_before_tax
├── income_tax_paid
├── income_tax_accrued
├── stated_capital
├── accumulated_earnings
├── employees_count
├── tangible_assets
├── submission_status
└── submission_date
```

### 4. Advanced Consolidation Module

#### 4.1 Multiple Hierarchies

```sql
-- Consolidation hierarchies
sys.consolidation_hierarchies
├── hierarchy_id
├── hierarchy_name
├── hierarchy_type (LEGAL, MANAGEMENT, SEGMENT, REGIONAL)
├── purpose (STATUTORY, INTERNAL, REGULATORY)
├── base_currency
├── consolidation_gaap
├── parent_entity_id
└── is_active

sys.hierarchy_nodes
├── node_id
├── hierarchy_id
├── entity_id
├── parent_node_id
├── level_number
├── consolidation_method
├── ownership_direct
├── ownership_effective
├── voting_rights
├── integration_date
├── deconsolidation_date
└── is_active
```

#### 4.2 Parallel Consolidations

```sql
-- Run consolidations under multiple GAAPs
sys.parallel_consolidations
├── parallel_id
├── hierarchy_id
├── period_id
├── gaap_framework
├── status (DRAFT, IN_PROGRESS, COMPLETED, PUBLISHED)
├── run_date
├── run_by
├── total_assets
├── total_liabilities
├── total_equity
├── net_income
├── nci_equity
├── nci_income
└── notes
```

### 5. Public Sector Module

#### 5.1 Fund Accounting

```sql
-- Government funds
sys.funds
├── fund_id
├── fund_code
├── fund_name
├── fund_type (GENERAL, SPECIAL_REVENUE, CAPITAL, DEBT_SERVICE, ENTERPRISE)
├── description
├── appropriation_authority
├── fiscal_year
├── opening_balance
├── total_revenues
├── total_expenditures
├── closing_balance
├── encumbrances
└── is_active

sys.appropriations
├── appropriation_id
├── fund_id
├── appropriation_code
├── description
├── original_amount
├── amendments
├── transfers_in
├── transfers_out
├── current_amount
├── expenditures
├── encumbrances
├── available_balance
└── expiration_date
```

#### 5.2 IPSAS Mappings

```sql
-- IPSAS standard mappings
sys.ipsas_mappings
├── mapping_id
├── entity_id
├── ipsas_standard
├── local_account_code
├── ipsas_account_code
├── ipsas_element (ASSET, LIABILITY, REVENUE, EXPENSE)
├── recognition_criteria
├── measurement_basis (HISTORICAL, FAIR_VALUE, PRESENT_VALUE)
└── disclosure_requirements
```

### 6. Regulatory & Compliance Module

#### 6.1 XBRL Reporting

```sql
-- XBRL taxonomies and filings
sys.xbrl_taxonomies
├── taxonomy_id
├── taxonomy_name
├── taxonomy_version
├── jurisdiction
├── valid_from
├── valid_to
├── schema_location
└── is_active

sys.xbrl_filings
├── filing_id
├── entity_id
├── taxonomy_id
├── period_id
├── filing_type (ANNUAL, INTERIM, AMENDMENT)
├── status (DRAFT, VALIDATED, SUBMITTED, ACCEPTED, REJECTED)
├── submission_date
├── authority_reference
├── xbrl_document (BYTEA)
├── ixbrl_document (BYTEA)
├── validation_errors (JSONB)
└── created_at
```

#### 6.2 Tax Digital Submissions

```sql
-- Digital tax compliance
sys.tax_digital_submissions
├── submission_id
├── entity_id
├── country_code
├── tax_type (VAT, CORPORATE, WITHHOLDING)
├── period_start
├── period_end
├── regime (MTD_UK, SII_ES, SAFT_PT, JPFAT_FR)
├── submission_data (JSONB)
├── submission_date
├── authority_response
├── reference_number
├── status
└── retry_count
```

### 7. Integration Hub Module

#### 7.1 Integration Endpoints

```sql
-- External system connections
sys.integration_endpoints
├── endpoint_id
├── endpoint_name
├── system_type (ERP, BANK, TAX_AUTHORITY, ECM, BI)
├── protocol (REST, SOAP, SFTP, AS2, SWIFT)
├── base_url
├── authentication_method (API_KEY, OAUTH2, CERTIFICATE, BASIC)
├── credentials_vault_ref
├── retry_policy (JSONB)
├── rate_limit
├── timeout_seconds
├── is_active
└── last_health_check

sys.sync_jobs
├── job_id
├── endpoint_id
├── direction (INBOUND, OUTBOUND)
├── entity_type
├── schedule_cron
├── last_run
├── last_status
├── records_processed
├── error_log
└── next_run
```

---

## Table Summary

| Module | New Tables | New Functions | New Views |
|--------|------------|---------------|-----------|
| Multi-Country | 8 | 6 | 4 |
| Treasury | 8 | 8 | 5 |
| Transfer Pricing | 6 | 5 | 3 |
| Advanced Consolidation | 6 | 6 | 4 |
| Public Sector | 8 | 6 | 4 |
| IC Advanced | 5 | 5 | 3 |
| Regulatory | 6 | 5 | 3 |
| Integration Hub | 5 | 6 | 2 |
| **Total ONYX** | **52** | **47** | **28** |

### Cumulative Totals

| Tier | Tables | Functions | Views |
|------|--------|-----------|-------|
| JASPE | 45 | 35 | 20 |
| RUBIS | +18 | +10 | +5 |
| SAPHIR | +26 | +21 | +12 |
| ONYX | +52 | +47 | +28 |
| **Total** | **141** | **113** | **65** |

---

## RPC Functions (Key)

### Multi-Country

| Function | Purpose |
|----------|---------|
| `rpc_get_entity_legal_config(entity_id)` | Get legal configuration |
| `rpc_calculate_statutory_statements(entity_id, period)` | Generate statutory reports |
| `rpc_convert_gaap(entity_id, source_gaap, target_gaap)` | GAAP conversion |

### Treasury

| Function | Purpose |
|----------|---------|
| `rpc_run_cash_pool_sweep(pool_id)` | Execute cash sweep |
| `rpc_generate_cash_forecast(entity_id, horizon_days)` | ML-based forecast |
| `rpc_calculate_hedge_effectiveness(hedge_id)` | Hedge testing |
| `rpc_execute_netting_run(netting_date)` | IC netting settlement |

### Transfer Pricing

| Function | Purpose |
|----------|---------|
| `rpc_validate_tp_transaction(transaction_id)` | Arm's length validation |
| `rpc_generate_tp_documentation(entity_id, year)` | TP documentation |
| `rpc_generate_cbcr_report(group_id, year)` | CbCR generation |

### Advanced Consolidation

| Function | Purpose |
|----------|---------|
| `rpc_run_parallel_consolidation(hierarchy_id, period, gaap)` | Multi-GAAP consolidation |
| `rpc_calculate_equity_chain(entity_id)` | Effective ownership |
| `rpc_process_acquisition(acquiring_id, acquired_id, date)` | Acquisition accounting |

### Regulatory

| Function | Purpose |
|----------|---------|
| `rpc_generate_xbrl_filing(entity_id, taxonomy_id, period)` | XBRL generation |
| `rpc_submit_tax_digital(entity_id, tax_type, period)` | Digital tax submission |
| `rpc_validate_xbrl(filing_id)` | XBRL validation |

---

## Implementation Roadmap

### Phase 1: Core Infrastructure (Sprint 11-12)
- [ ] Multi-country tables and configuration
- [ ] Legal entity registry
- [ ] Multi-GAAP mapping framework

### Phase 2: Treasury (Sprint 13-14)
- [ ] Cash pool management
- [ ] FX hedging
- [ ] Bank connectivity

### Phase 3: Transfer Pricing (Sprint 15)
- [ ] TP policy engine
- [ ] CbCR reporting

### Phase 4: Advanced Consolidation (Sprint 16-17)
- [ ] Multiple hierarchies
- [ ] Parallel consolidations
- [ ] Acquisition accounting

### Phase 5: Public Sector (Sprint 18)
- [ ] Fund accounting
- [ ] IPSAS mappings

### Phase 6: Regulatory (Sprint 19)
- [ ] XBRL generation
- [ ] Tax digital connectors

### Phase 7: Integration Hub (Sprint 20)
- [ ] ERP connectors
- [ ] Banking APIs

---

## Dependencies

```
ONYX requires:
├── SAPHIR tier (multi-currency, IFRS, workflows, consolidation)
├── RUBIS tier (multi-entity, analytical, budgets)
├── JASPE tier (core accounting, payroll, assets)
└── Common schemas (OHADA, tax codes, currencies)

ONYX enables:
├── Global corporate groups
├── Listed companies (regulatory compliance)
├── Public sector entities
└── Multinational operations
```

---

## Security Considerations

### Data Residency
- Support for data residency requirements per jurisdiction
- Regional deployments (EU, CEMAC, UEMOA)

### Access Control
- Country-level access restrictions
- Legal entity segregation
- Sensitive data masking (salaries, TP data)

### Audit
- Tamper-proof audit logs
- SOX compliance controls
- eIDAS electronic signatures

---

*EdenFin ONYX Architecture - February 2026*
*Version 1.0 - Initial Design*
