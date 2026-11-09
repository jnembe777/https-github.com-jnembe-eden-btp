-- ============================================================================
-- MCT T17 — rpc_dashboard_kpi
-- Tests : 5
-- Invariants : agrégation CA/charges/résultat/trésorerie/DSO
-- ============================================================================
BEGIN;
SELECT plan(5);

-- ── Fixtures ─────────────────────────────────────────────────────────────────

INSERT INTO sys.tenants (
  tenant_code, company_name, legal_form, country_code, tier,
  subscription_level, subscription_start_date, database_schema, contact_email
) VALUES (
  'PGTAP_T15', 'Test T15 SARL', 'SARL', 'GA', 'JASPE',
  'ESSENTIEL', '2026-01-01', 'client_test_t15', 'test15@test.ga'
);

-- ── Tests ────────────────────────────────────────────────────────────────────

-- T15.1 — Cas nominal : exercice vide → success=true
SELECT is(
  (SELECT client_demo.rpc_dashboard_kpi(2026)) ->> 'success',
  'true',
  'T15.1 nominal : exercice vide retourne success=true'
);

-- T15.2 — Clé kpi présente
SELECT ok(
  (SELECT client_demo.rpc_dashboard_kpi(2026)) -> 'kpi' IS NOT NULL,
  'T15.2 : résultat contient clé kpi'
);

-- T15.3 — KPI CA = 0 si aucune écriture REVENUE
SELECT is(
  ((SELECT client_demo.rpc_dashboard_kpi(2026)) -> 'kpi' ->> 'ca')::DECIMAL,
  0::DECIMAL,
  'T15.3 : kpi.ca = 0 sans écritures REVENUE'
);

-- T15.4 — Clé monthly présente
SELECT ok(
  (SELECT client_demo.rpc_dashboard_kpi(2026)) -> 'monthly' IS NOT NULL,
  'T15.4 : résultat contient clé monthly'
);

-- T15.5 — marge_pct = 0 si CA = 0
SELECT is(
  ((SELECT client_demo.rpc_dashboard_kpi(2026)) -> 'kpi' ->> 'marge_pct')::DECIMAL,
  0::DECIMAL,
  'T15.5 : kpi.marge_pct = 0 si CA = 0'
);

SELECT * FROM finish();
ROLLBACK;
