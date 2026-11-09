-- ============================================================================
-- EDENFIN JASPE — Exécution de tous les tests pgTAP RPC
-- Issue #7 · P1 · Tests unitaires pgTAP pour les 13 fonctions RPC T1→T13
--
-- USAGE :
--   psql -U postgres -d edenfin_dev -f tests/rpc/run_all.sql
--   — ou —
--   pg_prove -U postgres -d edenfin_dev tests/rpc/
--
-- NB : chaque fichier de test est autonome et transactionnel (BEGIN ... ROLLBACK) ;
--      aucune donnée n'est persistée (rollback systématique en fin de test).
-- ============================================================================

\set QUIET 1
\pset format unaligned
\pset tuples_only true

CREATE EXTENSION IF NOT EXISTS pgtap;

\i tests/rpc/t01_create_journal_entry_test.sql
\i tests/rpc/t02_validate_journal_entry_test.sql
\i tests/rpc/t03_auto_reconcile_bank_test.sql
\i tests/rpc/t04_auto_lettrage_test.sql
\i tests/rpc/t05_close_fiscal_period_test.sql
\i tests/rpc/t06_calculate_payroll_test.sql
\i tests/rpc/t07_validate_payslip_test.sql
\i tests/rpc/t08_generate_payroll_entries_test.sql
\i tests/rpc/t09_cash_forecast_test.sql
\i tests/rpc/t10_generate_tva_declaration_test.sql
\i tests/rpc/t11_financial_ratios_test.sql
\i tests/rpc/t12_generate_depreciation_test.sql
\i tests/rpc/t13_dispose_asset_test.sql
\i tests/rpc/t14_trial_balance_test.sql
\i tests/rpc/t15_dashboard_kpi_test.sql

-- ── Gamme RUBIS (PME) ───────────────────────────────────────────────────────
\i tests/rpc/rubis/r01_analytical_distribution_test.sql

-- ── Gamme SAPHIR (ETI) ──────────────────────────────────────────────────────
\i tests/rpc/saphir/s01_fx_conversion_test.sql

-- ── Gamme ONYX (GE / secteur public) — modules 01-07 ────────────────────────
\i tests/rpc/onyx/o01_country_tax_config_test.sql
\i tests/rpc/onyx/o02_public_sector_audit_test.sql
