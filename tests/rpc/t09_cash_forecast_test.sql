-- ============================================================================
-- MCT T8 — rpc_cash_forecast
-- Tests : 5
-- Invariants : prévisionnel J+30/60/90 avec alertes tension trésorerie
-- ============================================================================
BEGIN;
SELECT plan(5);

-- ── Fixtures ─────────────────────────────────────────────────────────────────

INSERT INTO sys.tenants (
  tenant_code, company_name, legal_form, country_code, tier,
  subscription_level, subscription_start_date, database_schema, contact_email
) VALUES (
  'PGTAP_T09', 'Test T09 SARL', 'SARL', 'GA', 'JASPE',
  'ESSENTIEL', '2026-01-01', 'client_test_t09', 'test09@test.ga'
);

INSERT INTO client_demo.chart_of_accounts (account_number, account_label, account_type, level, normal_balance, is_active)
VALUES ('512000', 'Banque', 'ASSET', 1, 'DEBIT', TRUE);

INSERT INTO client_demo.bank_accounts (
  code, name, currency_code, current_balance,
  ledger_account_id, is_active
) VALUES (
  'BQ_T09', 'Banque T09', 'XAF', 3000000,
  (SELECT id FROM client_demo.chart_of_accounts WHERE account_number = '512000'),
  TRUE
);

-- ── Tests ────────────────────────────────────────────────────────────────────

-- T9.1 — Cas nominal : sans prévisions → success=true
SELECT is(
  (SELECT client_demo.rpc_cash_forecast()) ->> 'success',
  'true',
  'T9.1 nominal : sans prévisions retourne success=true'
);

-- T9.2 — Solde actuel reflète les comptes bancaires actifs
SELECT is(
  ((SELECT client_demo.rpc_cash_forecast()) ->> 'current_cash')::DECIMAL,
  3000000::DECIMAL,
  'T9.2 : current_cash = somme des soldes bancaires actifs'
);

-- T9.3 — Structure forecast présente (J+30, J+60, J+90)
SELECT ok(
  (SELECT client_demo.rpc_cash_forecast()) -> 'forecast' -> 'j30' IS NOT NULL,
  'T9.3 : forecast contient clé j30'
);

-- T9.4 — Pas d'alerte si trésorerie positive
SELECT is(
  jsonb_array_length(
    (SELECT client_demo.rpc_cash_forecast()) -> 'alerts'
  ),
  0,
  'T9.4 : aucune alerte si trésorerie positive sans décaissements'
);

-- T9.5 — Horizon paramétrable : 30 jours ne change pas la structure
SELECT ok(
  (SELECT client_demo.rpc_cash_forecast(30)) -> 'forecast' -> 'j30' IS NOT NULL,
  'T9.5 : horizon paramétrable 30 jours retourne forecast j30'
);

SELECT * FROM finish();
ROLLBACK;
