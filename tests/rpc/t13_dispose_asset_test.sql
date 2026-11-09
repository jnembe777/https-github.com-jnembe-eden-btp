-- ============================================================================
-- MCT T15 — rpc_dispose_asset
-- Tests : 7
-- Invariants : RG05 résultat = prix cession - VNC, workflow ACTIVE→DISPOSED
-- ============================================================================
BEGIN;
SELECT plan(7);

-- ── Fixtures ─────────────────────────────────────────────────────────────────

INSERT INTO sys.tenants (
  tenant_code, company_name, legal_form, country_code, tier,
  subscription_level, subscription_start_date, database_schema, contact_email
) VALUES (
  'PGTAP_T13', 'Test T13 SARL', 'SARL', 'GA', 'JASPE',
  'ESSENTIEL', '2026-01-01', 'client_test_t13', 'test13@test.ga'
);

INSERT INTO client_demo.chart_of_accounts (account_number, account_label, account_type, level, normal_balance, is_active)
VALUES ('241100', 'Matériel de bureau', 'ASSET', 1, 'DEBIT', TRUE);

INSERT INTO client_demo.asset_categories (
  code, label, default_useful_life_months, default_method,
  declining_coeff_short, declining_coeff_medium, declining_coeff_long, is_active
) VALUES (
  'VEHICULE', 'Véhicules', 60, 'LINEAR', 1.25, 1.75, 2.25, TRUE
);

-- Immobilisation ACTIVE avec VNC connue
INSERT INTO client_demo.fixed_assets (
  asset_number, asset_name, category_id, asset_account_id,
  acquisition_date, acquisition_value, residual_value,
  net_book_value, useful_life_months, depreciation_method,
  accumulated_depreciation, status, is_active
) VALUES (
  'VEH-001', 'Véhicule utilitaire',
  (SELECT id FROM client_demo.asset_categories WHERE code = 'VEHICULE'),
  (SELECT id FROM client_demo.chart_of_accounts WHERE account_number = '241100'),
  '2025-01-01', 8000000, 500000,
  5000000, 60, 'LINEAR',
  3000000, 'ACTIVE', TRUE
);

-- Immobilisation déjà DISPOSED
INSERT INTO client_demo.fixed_assets (
  asset_number, asset_name, category_id, asset_account_id,
  acquisition_date, acquisition_value, residual_value,
  net_book_value, useful_life_months, depreciation_method,
  accumulated_depreciation, status, is_active
) VALUES (
  'VEH-002', 'Ancien véhicule',
  (SELECT id FROM client_demo.asset_categories WHERE code = 'VEHICULE'),
  (SELECT id FROM client_demo.chart_of_accounts WHERE account_number = '241100'),
  '2023-01-01', 6000000, 0,
  0, 60, 'LINEAR',
  6000000, 'DISPOSED', FALSE
);

-- Immobilisation ACTIVE dédiée au scénario moins-value (même VNC que VEH-001) :
-- la cession est irréversible (ACTIVE→DISPOSED), chaque scénario nominal a donc
-- sa propre immobilisation pour ne jamais recéder un actif déjà cédé.
INSERT INTO client_demo.fixed_assets (
  asset_number, asset_name, category_id, asset_account_id,
  acquisition_date, acquisition_value, residual_value,
  net_book_value, useful_life_months, depreciation_method,
  accumulated_depreciation, status, is_active
) VALUES (
  'VEH-003', 'Véhicule utilitaire (moins-value)',
  (SELECT id FROM client_demo.asset_categories WHERE code = 'VEHICULE'),
  (SELECT id FROM client_demo.chart_of_accounts WHERE account_number = '241100'),
  '2025-01-01', 8000000, 500000,
  5000000, 60, 'LINEAR',
  3000000, 'ACTIVE', TRUE
);

-- ── Tests ────────────────────────────────────────────────────────────────────

-- T13.1 / T13.2 / T13.3 — Cas nominal PLUS_VALUE sur VEH-001 (une seule cession,
-- trois champs vérifiés). La cession est irréversible : on capture le résultat de
-- l'unique appel au lieu de recéder un actif déjà DISPOSED.
CREATE TEMP TABLE _t13_plus AS
SELECT client_demo.rpc_dispose_asset(
  (SELECT id FROM client_demo.fixed_assets WHERE asset_number = 'VEH-001'),
  '2026-07-01', 6000000, 'SALE'
) AS r;

-- T13.1 — Cas nominal PLUS_VALUE : prix cession > VNC → plus-value
SELECT is(
  (SELECT r ->> 'result_type' FROM _t13_plus),
  'PLUS_VALUE',
  'T13.1 RG05 : prix 6M > VNC 5M → PLUS_VALUE'
);

-- T13.2 — RG05 : résultat = prix - VNC = 6 000 000 - 5 000 000 = 1 000 000
SELECT is(
  (SELECT (r ->> 'result')::DECIMAL FROM _t13_plus),
  1000000::DECIMAL,
  'T13.2 RG05 : résultat cession = 1 000 000 XAF'
);

-- T13.3 — success=true
SELECT is(
  (SELECT r ->> 'success' FROM _t13_plus),
  'true',
  'T13.3 nominal : success=true'
);

-- T13.4 — MOINS_VALUE si prix < VNC (sur VEH-003, actif dédié au scénario)
SELECT is(
  (SELECT client_demo.rpc_dispose_asset(
    (SELECT id FROM client_demo.fixed_assets WHERE asset_number = 'VEH-003'),
    '2026-07-01', 3000000, 'SALE'
  )) ->> 'result_type',
  'MOINS_VALUE',
  'T13.4 RG05 : prix 3M < VNC 5M → MOINS_VALUE'
);

-- T13.5 — Immobilisation inexistante → rejet
SELECT alike(
  (SELECT client_demo.rpc_dispose_asset(
    999999999, '2026-07-01', 100000, 'SALE'
  )) ->> 'error',
  '%introuvable%',
  'T13.5 : immobilisation inexistante retourne erreur introuvable'
);

-- T13.6 — Immobilisation DISPOSED → rejet
SELECT alike(
  (SELECT client_demo.rpc_dispose_asset(
    (SELECT id FROM client_demo.fixed_assets WHERE asset_number = 'VEH-002'),
    '2026-07-01', 100000, 'SALE'
  )) ->> 'error',
  '%non active%',
  'T13.6 : immobilisation DISPOSED retourne erreur non active'
);

-- T13.7 — Vérification en base : statut mis à jour à DISPOSED
SELECT is(
  (SELECT status FROM client_demo.fixed_assets WHERE asset_number = 'VEH-001'),
  'DISPOSED',
  'T13.7 : statut en base mis à jour à DISPOSED'
);

SELECT * FROM finish();
ROLLBACK;
