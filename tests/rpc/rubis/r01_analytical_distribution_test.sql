-- ============================================================================
-- RUBIS R1 — Distribution analytique (templates de ventilation)
-- Fonctions : sys.rpc_create_distribution_template, sys.rpc_add_template_line,
--             sys.validate_distribution_template, sys.apply_distribution_template
-- Tests : 8
-- Invariant métier : un template de ventilation analytique DOIT totaliser 100 %.
--                    Le garde-fou empêche tout dépassement ; une ventilation
--                    incomplète est signalée ; l'application répartit au prorata.
-- Prérequis : base construite via scripts/db-build.sh (JASPE + RUBIS).
-- Autonome : BEGIN/ROLLBACK, aucune donnée persistée.
-- ============================================================================
BEGIN;
SELECT plan(8);

-- ── Fixtures : utilisateur authentifié + tenant RUBIS + axe/valeurs ──────────
INSERT INTO auth.users (id, email)
VALUES ('a0000000-0000-0000-0000-000000000001', 'rubis.r1@test.ga');

INSERT INTO sys.tenants (
  tenant_code, company_name, country_code, tier,
  subscription_level, subscription_start_date, database_schema, contact_email
) VALUES (
  'PGTAP_R1', 'Rubis R1 SARL', 'GA', 'RUBIS',
  'PROFESSIONAL', '2026-01-01', 'client_test_r1', 'r1@test.ga'
);

INSERT INTO sys.users (tenant_id, email, first_name, last_name, auth_user_id)
VALUES (
  (SELECT id FROM sys.tenants WHERE tenant_code = 'PGTAP_R1'),
  'rubis.r1@test.ga', 'Rubis', 'Tester',
  'a0000000-0000-0000-0000-000000000001'
);

-- Établit le contexte authentifié (claim JWT « sub ») pour toute la transaction.
SELECT set_config(
  'request.jwt.claims',
  json_build_object('sub', 'a0000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text,
  false
);

INSERT INTO sys.analytical_axes (tenant_id, axis_code, axis_name, axis_type)
VALUES (
  (SELECT id FROM sys.tenants WHERE tenant_code = 'PGTAP_R1'),
  'CC', 'Centres de cout', 'COST_CENTER'
);

INSERT INTO sys.analytical_values (tenant_id, axis_id, value_code, value_name)
SELECT t.id, a.id, v.code, v.name
FROM (SELECT id FROM sys.tenants WHERE tenant_code = 'PGTAP_R1') t,
     (SELECT id FROM sys.analytical_axes WHERE axis_code = 'CC') a,
     (VALUES ('CC01', 'Administration'), ('CC02', 'Production')) v(code, name);

-- ── Tests ────────────────────────────────────────────────────────────────────

-- R1.1 — Contexte tenant résolu depuis le claim JWT
SELECT isnt(
  sys.get_current_tenant_id(), NULL,
  'R1.1 contexte authentifié : tenant courant résolu'
);

-- R1.2 — Création d'un template de ventilation (retourne un id > 0)
SELECT ok(
  sys.rpc_create_distribution_template(
    'TPL_6040', 'Admin/Prod 60-40', NULL, '6%',
    (SELECT id FROM sys.analytical_axes WHERE axis_code = 'CC'),
    FALSE, 'template 60/40 de test'
  ) > 0,
  'R1.2 rpc_create_distribution_template : id de template retourné'
);

-- Ajout des lignes 60 % (CC01) et 40 % (CC02)
SELECT sys.rpc_add_template_line(
  (SELECT id FROM sys.analytical_distribution_templates WHERE template_code = 'TPL_6040'),
  (SELECT id FROM sys.analytical_values WHERE value_code = 'CC01'), 60, 1
);
SELECT sys.rpc_add_template_line(
  (SELECT id FROM sys.analytical_distribution_templates WHERE template_code = 'TPL_6040'),
  (SELECT id FROM sys.analytical_values WHERE value_code = 'CC02'), 40, 2
);

-- R1.3 — Template complet => valide
SELECT ok(
  (SELECT is_valid FROM sys.validate_distribution_template(
    (SELECT id FROM sys.analytical_distribution_templates WHERE template_code = 'TPL_6040'))),
  'R1.3 validate_distribution_template : 60+40 = 100 %% => valide'
);

-- R1.4 — Total = 100.0000
SELECT is(
  (SELECT total_percentage FROM sys.validate_distribution_template(
    (SELECT id FROM sys.analytical_distribution_templates WHERE template_code = 'TPL_6040'))),
  100.0000::numeric,
  'R1.4 validate_distribution_template : total = 100.0000'
);

-- R1.5 — Application à 1000 : la part Administration (60 %) = 600
SELECT is(
  (SELECT distributed_amount FROM sys.apply_distribution_template(
     (SELECT id FROM sys.analytical_distribution_templates WHERE template_code = 'TPL_6040'),
     1000, TRUE)
   WHERE analytical_value_id = (SELECT id FROM sys.analytical_values WHERE value_code = 'CC01')),
  600.00::numeric,
  'R1.5 apply_distribution_template : 60 %% de 1000 = 600'
);

-- R1.6 — Application à 1000 : la part Production (40 %) = 400
SELECT is(
  (SELECT distributed_amount FROM sys.apply_distribution_template(
     (SELECT id FROM sys.analytical_distribution_templates WHERE template_code = 'TPL_6040'),
     1000, TRUE)
   WHERE analytical_value_id = (SELECT id FROM sys.analytical_values WHERE value_code = 'CC02')),
  400.00::numeric,
  'R1.6 apply_distribution_template : 40 %% de 1000 = 400'
);

-- R1.7 — Garde-fou : ajouter 10 % de plus (=> 110 %) doit lever une exception
SELECT throws_ok(
  $$ SELECT sys.rpc_add_template_line(
       (SELECT id FROM sys.analytical_distribution_templates WHERE template_code = 'TPL_6040'),
       (SELECT id FROM sys.analytical_values WHERE value_code = 'CC01'), 10, 3) $$,
  NULL,
  'R1.7 rpc_add_template_line : dépassement de 100 %% rejeté'
);

-- R1.8 — Ventilation incomplète (60 % seulement) => invalide + message explicite
SELECT sys.rpc_create_distribution_template(
  'TPL_INC', 'Incomplet 60', NULL, '6%',
  (SELECT id FROM sys.analytical_axes WHERE axis_code = 'CC'), FALSE, 'incomplet'
);
SELECT sys.rpc_add_template_line(
  (SELECT id FROM sys.analytical_distribution_templates WHERE template_code = 'TPL_INC'),
  (SELECT id FROM sys.analytical_values WHERE value_code = 'CC01'), 60, 1
);
SELECT ok(
  (SELECT is_valid = FALSE AND error_message LIKE 'Distribution incompl%'
     FROM sys.validate_distribution_template(
       (SELECT id FROM sys.analytical_distribution_templates WHERE template_code = 'TPL_INC'))),
  'R1.8 validate_distribution_template : 60 %% => invalide, message « incomplète »'
);

SELECT * FROM finish();
ROLLBACK;
