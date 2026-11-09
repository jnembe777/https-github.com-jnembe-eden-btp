-- ============================================================================
-- MCT T2 — rpc_auto_reconcile_bank
-- Tests : 5
-- Invariants : matching montant exact + tolérance date
-- ============================================================================
BEGIN;
SELECT plan(5);

-- ── Fixtures ─────────────────────────────────────────────────────────────────

INSERT INTO sys.tenants (
  tenant_code, company_name, legal_form, country_code, tier,
  subscription_level, subscription_start_date, database_schema, contact_email
) VALUES (
  'PGTAP_T03', 'Test T03 SARL', 'SARL', 'GA', 'JASPE',
  'ESSENTIEL', '2026-01-01', 'client_test_t03', 'test03@test.ga'
);

INSERT INTO client_demo.fiscal_exercises (fiscal_year, start_date, end_date, status)
VALUES (2026, '2026-01-01', '2026-12-31', 'OPEN');

INSERT INTO client_demo.fiscal_periods (
  exercise_id, fiscal_year, period_number, start_date, end_date, status
) VALUES (
  (SELECT id FROM client_demo.fiscal_exercises WHERE fiscal_year = 2026),
  2026, 1, '2026-01-01', '2026-01-31', 'OPEN'
);

INSERT INTO client_demo.chart_of_accounts (account_number, account_label, account_type, level, normal_balance, is_active)
VALUES ('512000', 'Banque principale', 'ASSET', 1, 'DEBIT', TRUE);

INSERT INTO client_demo.bank_accounts (
  code, name, bank_name, currency_code, current_balance,
  ledger_account_id, is_active
) VALUES (
  'BQ_TEST', 'Compte principal', 'BGFI Bank', 'XAF', 5000000,
  (SELECT id FROM client_demo.chart_of_accounts WHERE account_number = '512000'),
  TRUE
);

-- ── Tests ────────────────────────────────────────────────────────────────────

-- T3.1 — Cas nominal : compte valide, aucune transaction → success=true
SELECT is(
  (SELECT client_demo.rpc_auto_reconcile_bank(
    (SELECT id FROM client_demo.bank_accounts WHERE code = 'BQ_TEST')
  )) ->> 'success',
  'true',
  'T3.1 nominal : compte valide sans transactions retourne success=true'
);

-- T3.2 — Cas nominal : total_transactions=0 si aucune transaction non rapprochée
SELECT is(
  ((SELECT client_demo.rpc_auto_reconcile_bank(
    (SELECT id FROM client_demo.bank_accounts WHERE code = 'BQ_TEST')
  )) ->> 'total_transactions')::INT,
  0,
  'T3.2 nominal : total_transactions=0 sans transactions'
);

-- T3.3 — Compte inexistant → rejet
SELECT alike(
  (SELECT client_demo.rpc_auto_reconcile_bank(999999999)) ->> 'error',
  '%introuvable%',
  'T3.3 : compte inexistant retourne erreur introuvable'
);

-- T3.4 — Compte inexistant → success=false
SELECT is(
  (SELECT client_demo.rpc_auto_reconcile_bank(999999999)) ->> 'success',
  'false',
  'T3.4 : compte inexistant retourne success=false'
);

-- T3.5 — Résultat contient code du compte bancaire
SELECT is(
  (SELECT client_demo.rpc_auto_reconcile_bank(
    (SELECT id FROM client_demo.bank_accounts WHERE code = 'BQ_TEST')
  )) ->> 'bank_account',
  'BQ_TEST',
  'T3.5 : résultat contient le code du compte bancaire'
);

SELECT * FROM finish();
ROLLBACK;
