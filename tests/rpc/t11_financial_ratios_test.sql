-- ============================================================================
-- MCT T12 — rpc_financial_ratios
-- Tests : 5
-- Invariants : 12 ratios clés, alertes automatiques
-- ============================================================================
BEGIN;
SELECT plan(5);

-- ── Fixtures ─────────────────────────────────────────────────────────────────

INSERT INTO sys.tenants (
  tenant_code, company_name, legal_form, country_code, tier,
  subscription_level, subscription_start_date, database_schema, contact_email
) VALUES (
  'PGTAP_T11', 'Test T11 SARL', 'SARL', 'GA', 'JASPE',
  'ESSENTIEL', '2026-01-01', 'client_test_t11', 'test11@test.ga'
);

-- ── Tests ────────────────────────────────────────────────────────────────────

-- T11.1 — Cas nominal : sans données comptables → success=true
SELECT is(
  (SELECT client_demo.rpc_financial_ratios(2026)) ->> 'success',
  'true',
  'T11.1 nominal : sans données retourne success=true'
);

-- T11.2 — Structure ratios présente
SELECT ok(
  (SELECT client_demo.rpc_financial_ratios(2026)) -> 'ratios' IS NOT NULL,
  'T11.2 : résultat contient clé ratios'
);

-- T11.3 — Ratio marge_nette présent et vaut 0 (pas de CA)
SELECT is(
  ((SELECT client_demo.rpc_financial_ratios(2026)) -> 'ratios' ->> 'marge_nette')::DECIMAL,
  0::DECIMAL,
  'T11.3 : marge_nette = 0 sans CA'
);

-- T11.4 — Clé alerts présente
SELECT ok(
  (SELECT client_demo.rpc_financial_ratios(2026)) -> 'alerts' IS NOT NULL,
  'T11.4 : résultat contient clé alerts'
);

-- T11.5 — fiscal_year dans le résultat
SELECT is(
  ((SELECT client_demo.rpc_financial_ratios(2026)) ->> 'fiscal_year')::INT,
  2026,
  'T11.5 : fiscal_year retourné dans le résultat'
);

SELECT * FROM finish();
ROLLBACK;
