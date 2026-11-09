-- ============================================================================
-- MCT T10 — rpc_generate_tva_declaration
-- Tests : 6
-- Invariants : taux TVA lu depuis common.tax_codes (NOYAU-NORMATIF §5)
--              RG06 : TVA due = TVA collectée - TVA déductible
-- ============================================================================
BEGIN;
SELECT plan(6);

-- ── Fixtures ─────────────────────────────────────────────────────────────────

INSERT INTO sys.tenants (
  tenant_code, company_name, legal_form, country_code, tier,
  subscription_level, subscription_start_date, database_schema, contact_email
) VALUES (
  'PGTAP_T10', 'Test T10 SARL', 'SARL', 'GA', 'JASPE',
  'ESSENTIEL', '2026-01-01', 'client_test_t10', 'test10@test.ga'
);

-- §5 Taux TVA depuis common.tax_codes (jamais en dur)
INSERT INTO common.tax_codes (
  country_code, code, name, rate, type, effective_date, is_default
) VALUES (
  'GA', 'TVA_GA_STD', 'TVA Gabon 18%', 18.00, 'VAT', '2026-01-01', TRUE
);

-- ── Tests ────────────────────────────────────────────────────────────────────

-- T10.1 — Cas nominal : période sans écritures TVA → success=true, TVA due = 0
SELECT is(
  (SELECT client_demo.rpc_generate_tva_declaration('2026-01-01', '2026-01-31')) ->> 'success',
  'true',
  'T10.1 nominal : période vide retourne success=true'
);

-- T10.2 — RG06 : TVA due = collectée - déductible = 0 si aucune écriture
SELECT is(
  ((SELECT client_demo.rpc_generate_tva_declaration('2026-01-01', '2026-01-31')) ->> 'tva_due')::DECIMAL,
  0::DECIMAL,
  'T10.2 RG06 : TVA due = 0 sur période sans écritures'
);

-- T10.3 — Déclaration créée en base
SELECT ok(
  EXISTS(
    SELECT 1 FROM client_demo.tax_returns
    WHERE return_type = 'TVA' AND fiscal_year = 2026
  ),
  'T10.3 : déclaration TVA créée en base'
);

-- T10.4 — §5 normativité : taux TVA dans le résultat = taux depuis common.tax_codes
SELECT is(
  ((SELECT client_demo.rpc_generate_tva_declaration('2026-01-01', '2026-01-31')) ->> 'tva_rate_pct')::DECIMAL,
  18.00::DECIMAL,
  'T10.4 §5 normativité : taux TVA = 18% (depuis common.tax_codes)'
);

-- T10.5 — Données CA3 insérées dans tax_return_data
SELECT ok(
  EXISTS(
    SELECT 1 FROM client_demo.tax_return_data td
    JOIN client_demo.tax_returns tr ON tr.id = td.tax_return_id
    WHERE tr.return_type = 'TVA' AND td.field_code = 'TVA_DUE'
  ),
  'T10.5 : ligne TVA_DUE présente dans tax_return_data'
);

-- T10.6 — Échéance = fin de période + 25 jours
SELECT is(
  ((SELECT client_demo.rpc_generate_tva_declaration('2026-01-01', '2026-01-31')) ->> 'due_date')::DATE,
  ('2026-01-31'::DATE + INTERVAL '25 days')::DATE,
  'T10.6 : due_date = fin_période + 25 jours'
);

SELECT * FROM finish();
ROLLBACK;
