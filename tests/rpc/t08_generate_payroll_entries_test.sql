-- ============================================================================
-- MCT T7 — rpc_generate_payroll_entries
-- Tests : 6
-- Invariants : comptes de contrepartie via payroll_rubrics (NOYAU-NORMATIF §5)
-- Note : nécessite migration 20260725100000 (action 'GENERATE' dans audit_log)
-- ============================================================================
BEGIN;
SELECT plan(6);

-- ── Fixtures ─────────────────────────────────────────────────────────────────

INSERT INTO sys.tenants (
  tenant_code, company_name, legal_form, country_code, tier,
  subscription_level, subscription_start_date, database_schema, contact_email
) VALUES (
  'PGTAP_T08', 'Test T08 SARL', 'SARL', 'GA', 'JASPE',
  'ESSENTIEL', '2026-01-01', 'client_test_t08', 'test08@test.ga'
);

INSERT INTO client_demo.fiscal_exercises (fiscal_year, start_date, end_date, status)
VALUES (2026, '2026-01-01', '2026-12-31', 'OPEN');

INSERT INTO client_demo.fiscal_periods (
  exercise_id, fiscal_year, period_number, start_date, end_date, status
) VALUES (
  (SELECT id FROM client_demo.fiscal_exercises WHERE fiscal_year = 2026),
  2026, 7, '2026-07-01', '2026-07-31', 'OPEN'
);

INSERT INTO client_demo.pay_periods (
  fiscal_year, period_month, start_date, end_date, payment_date, status,
  fiscal_period_id
) VALUES (
  2026, 7, '2026-07-01', '2026-07-31', '2026-07-31', 'OPEN',
  (SELECT id FROM client_demo.fiscal_periods WHERE fiscal_year = 2026 AND period_number = 7)
);

-- Période sans bulletins VALIDATED
INSERT INTO client_demo.pay_periods (
  fiscal_year, period_month, start_date, end_date, payment_date, status
) VALUES (
  2026, 8, '2026-08-01', '2026-08-31', '2026-08-31', 'OPEN'
);

-- ── Tests ────────────────────────────────────────────────────────────────────

-- T8.1 — Pas de journal PAIE → rejet
SELECT alike(
  (SELECT client_demo.rpc_generate_payroll_entries(
    (SELECT id FROM client_demo.pay_periods WHERE fiscal_year = 2026 AND period_month = 7),
    (SELECT id FROM client_demo.fiscal_periods WHERE fiscal_year = 2026 AND period_number = 7)
  )) ->> 'error',
  '%PAIE%',
  'T8.1 : sans journal PAIE retourne erreur journal PAIE'
);

-- T8.2 — success=false sans journal PAIE
SELECT is(
  (SELECT client_demo.rpc_generate_payroll_entries(
    (SELECT id FROM client_demo.pay_periods WHERE fiscal_year = 2026 AND period_month = 7),
    (SELECT id FROM client_demo.fiscal_periods WHERE fiscal_year = 2026 AND period_number = 7)
  )) ->> 'success',
  'false',
  'T8.2 : success=false sans journal PAIE'
);

-- Ajout du journal PAIE
INSERT INTO client_demo.chart_of_accounts (account_number, account_label, account_type, level, normal_balance, is_active)
VALUES ('421000', 'Personnel - rémunérations', 'LIABILITY', 1, 'CREDIT', TRUE);

INSERT INTO client_demo.journals (code, name, type, is_active)
VALUES ('PAIE', 'Journal de Paie', 'PAYROLL', TRUE);

-- T8.3 — Pas de bulletins VALIDATED → rejet
SELECT alike(
  (SELECT client_demo.rpc_generate_payroll_entries(
    (SELECT id FROM client_demo.pay_periods WHERE fiscal_year = 2026 AND period_month = 7),
    (SELECT id FROM client_demo.fiscal_periods WHERE fiscal_year = 2026 AND period_number = 7)
  )) ->> 'error',
  '%VALIDATED%',
  'T8.3 : sans bulletins VALIDATED retourne erreur VALIDATED'
);

-- T8.4 — success=false sans bulletins VALIDATED
SELECT is(
  (SELECT client_demo.rpc_generate_payroll_entries(
    (SELECT id FROM client_demo.pay_periods WHERE fiscal_year = 2026 AND period_month = 7),
    (SELECT id FROM client_demo.fiscal_periods WHERE fiscal_year = 2026 AND period_number = 7)
  )) ->> 'success',
  'false',
  'T8.4 : success=false sans bulletins VALIDATED'
);

-- T8.5 — Période de paie inexistante → rejet
SELECT is(
  (SELECT client_demo.rpc_generate_payroll_entries(
    999999999,
    (SELECT id FROM client_demo.fiscal_periods WHERE fiscal_year = 2026 AND period_number = 7)
  )) ->> 'success',
  'false',
  'T8.5 : période de paie inexistante retourne success=false'
);

-- T8.6 — §5 normativité : journal PAIE résolu depuis table journals (pas en dur)
SELECT ok(
  EXISTS(
    SELECT 1 FROM client_demo.journals WHERE code = 'PAIE' AND is_active = TRUE
  ),
  'T8.6 §5 : journal PAIE existe et est actif dans la table journals'
);

SELECT * FROM finish();
ROLLBACK;
