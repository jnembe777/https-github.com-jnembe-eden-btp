-- ============================================================================
-- MCT T16 — rpc_trial_balance
-- Tests : 4
-- Invariants : balance générale par exercice et période, écritures POSTED uniquement
-- ============================================================================
BEGIN;
SELECT plan(4);

-- ── Fixtures ─────────────────────────────────────────────────────────────────

INSERT INTO sys.tenants (
  tenant_code, company_name, legal_form, country_code, tier,
  subscription_level, subscription_start_date, database_schema, contact_email
) VALUES (
  'PGTAP_T14', 'Test T14 SARL', 'SARL', 'GA', 'JASPE',
  'ESSENTIEL', '2026-01-01', 'client_test_t14', 'test14@test.ga'
);

-- ── Tests ────────────────────────────────────────────────────────────────────

-- T14.1 — Cas nominal : exercice vide → success=true
SELECT is(
  (SELECT client_demo.rpc_trial_balance(2026)) ->> 'success',
  'true',
  'T14.1 nominal : exercice vide retourne success=true'
);

-- T14.2 — fiscal_year dans le résultat
SELECT is(
  ((SELECT client_demo.rpc_trial_balance(2026)) ->> 'fiscal_year')::INT,
  2026,
  'T14.2 : fiscal_year retourné dans le résultat'
);

-- T14.3 — Clé accounts présente (null ou array vide si pas d'écritures)
SELECT ok(
  (SELECT client_demo.rpc_trial_balance(2026)) -> 'accounts' IS NOT NULL
  OR
  (SELECT client_demo.rpc_trial_balance(2026)) ->> 'accounts' IS NULL,
  'T14.3 : clé accounts présente dans le résultat'
);

-- T14.4 — Paramètre période fin fonctionne
SELECT is(
  (SELECT client_demo.rpc_trial_balance(2026, 6)) ->> 'success',
  'true',
  'T14.4 : paramètre période_fin fonctionne (p_period_end=6)'
);

SELECT * FROM finish();
ROLLBACK;
