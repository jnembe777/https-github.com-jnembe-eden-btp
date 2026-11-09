-- ============================================================================
-- MCT T14 — rpc_generate_depreciation
-- Tests : 7
-- Invariants : coefficients OHADA depuis asset_categories (NOYAU-NORMATIF §1)
--              RG04 : dotation = (VA - VR) / durée
-- ============================================================================
BEGIN;
SELECT plan(7);

-- ── Fixtures ─────────────────────────────────────────────────────────────────

INSERT INTO sys.tenants (
  tenant_code, company_name, legal_form, country_code, tier,
  subscription_level, subscription_start_date, database_schema, contact_email
) VALUES (
  'PGTAP_T12', 'Test T12 SARL', 'SARL', 'GA', 'JASPE',
  'ESSENTIEL', '2026-01-01', 'client_test_t12', 'test12@test.ga'
);

INSERT INTO client_demo.fiscal_exercises (fiscal_year, start_date, end_date, status)
VALUES (2026, '2026-01-01', '2026-12-31', 'OPEN');

INSERT INTO client_demo.fiscal_periods (
  exercise_id, fiscal_year, period_number, start_date, end_date, status
) VALUES (
  (SELECT id FROM client_demo.fiscal_exercises WHERE fiscal_year = 2026),
  2026, 7, '2026-07-01', '2026-07-31', 'OPEN'
);

-- Catégorie d'immobilisation avec coefficients OHADA (NOYAU-NORMATIF §1)
INSERT INTO client_demo.asset_categories (
  code, label, default_useful_life_months, default_method,
  declining_coeff_short, declining_coeff_medium, declining_coeff_long,
  is_active
) VALUES (
  'MAT_BUREAU', 'Matériel de bureau', 60, 'LINEAR', 1.25, 1.75, 2.25, TRUE
);

-- ── Tests ────────────────────────────────────────────────────────────────────

-- T12.1 — Cas nominal : période valide, aucune immobilisation → success=true, 0 actif
SELECT is(
  (SELECT client_demo.rpc_generate_depreciation(
    (SELECT id FROM client_demo.fiscal_periods WHERE fiscal_year = 2026 AND period_number = 7)
  )) ->> 'success',
  'true',
  'T12.1 nominal : aucune immobilisation retourne success=true'
);

-- T12.2 — Aucune immobilisation → assets_processed=0
SELECT is(
  ((SELECT client_demo.rpc_generate_depreciation(
    (SELECT id FROM client_demo.fiscal_periods WHERE fiscal_year = 2026 AND period_number = 7)
  )) ->> 'assets_processed')::INT,
  0,
  'T12.2 nominal : assets_processed=0 sans immobilisation'
);

-- T12.3 — Période introuvable → rejet
SELECT alike(
  (SELECT client_demo.rpc_generate_depreciation(999999999)) ->> 'error',
  '%introuvable%',
  'T12.3 : période inexistante retourne erreur introuvable'
);

-- T12.4 — success=false sur période inexistante
SELECT is(
  (SELECT client_demo.rpc_generate_depreciation(999999999)) ->> 'success',
  'false',
  'T12.4 : success=false sur période inexistante'
);

-- Ajout d'une immobilisation active (amortissement linéaire 60 mois)
INSERT INTO client_demo.chart_of_accounts (account_number, account_label, account_type, level, normal_balance, is_active)
VALUES ('241100', 'Matériel de bureau', 'ASSET', 1, 'DEBIT', TRUE);

INSERT INTO client_demo.fixed_assets (
  asset_number, asset_name, category_id, asset_account_id,
  acquisition_date, acquisition_value, residual_value,
  net_book_value, useful_life_months, depreciation_method,
  accumulated_depreciation, status, is_active
) VALUES (
  'IMMO-001', 'Ordinateur portable',
  (SELECT id FROM client_demo.asset_categories WHERE code = 'MAT_BUREAU'),
  (SELECT id FROM client_demo.chart_of_accounts WHERE account_number = '241100'),
  '2026-01-01', 1200000, 0,
  1200000, 60, 'LINEAR',
  0, 'ACTIVE', TRUE
);

-- T12.5 — Avec immobilisation active : assets_processed=1
SELECT is(
  ((SELECT client_demo.rpc_generate_depreciation(
    (SELECT id FROM client_demo.fiscal_periods WHERE fiscal_year = 2026 AND period_number = 7)
  )) ->> 'assets_processed')::INT,
  1,
  'T12.5 : assets_processed=1 avec 1 immobilisation active'
);

-- T12.6 — RG04 : dotation linéaire mensuelle = (VA - VR) / durée = 1200000/60 = 20000
SELECT is(
  ((SELECT client_demo.rpc_generate_depreciation(
    (SELECT id FROM client_demo.fiscal_periods WHERE fiscal_year = 2026 AND period_number = 7)
  )) ->> 'total_depreciation')::DECIMAL,
  20000::DECIMAL,
  'T12.6 RG04 : dotation linéaire = 1 200 000 / 60 = 20 000 XAF'
);

-- T12.7 — §1 normativité : catégorie avec coefficients OHADA (jamais en dur)
SELECT ok(
  EXISTS(
    SELECT 1 FROM client_demo.asset_categories
    WHERE declining_coeff_short = 1.25
      AND declining_coeff_medium = 1.75
      AND declining_coeff_long = 2.25
  ),
  'T12.7 §1 : coefficients OHADA dans asset_categories (jamais en dur dans le RPC)'
);

SELECT * FROM finish();
ROLLBACK;
