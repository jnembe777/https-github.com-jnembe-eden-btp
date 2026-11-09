-- ============================================================================
-- MCT T4 — rpc_close_fiscal_period
-- Tests : 7
-- Invariants : blocage si écritures DRAFT, équilibre obligatoire, irréversibilité (NOYAU-NORMATIF §2)
-- ============================================================================
BEGIN;
SELECT plan(7);

-- ── Fixtures ─────────────────────────────────────────────────────────────────

INSERT INTO sys.tenants (
  tenant_code, company_name, legal_form, country_code, tier,
  subscription_level, subscription_start_date, database_schema, contact_email
) VALUES (
  'PGTAP_T05', 'Test T05 SARL', 'SARL', 'GA', 'JASPE',
  'ESSENTIEL', '2026-01-01', 'client_test_t05', 'test05@test.ga'
);

INSERT INTO client_demo.fiscal_exercises (fiscal_year, start_date, end_date, status)
VALUES (2026, '2026-01-01', '2026-12-31', 'OPEN');

-- Période 1 : vide, OPEN → peut être fermée
INSERT INTO client_demo.fiscal_periods (
  exercise_id, fiscal_year, period_number, start_date, end_date, status
) VALUES (
  (SELECT id FROM client_demo.fiscal_exercises WHERE fiscal_year = 2026),
  2026, 1, '2026-01-01', '2026-01-31', 'OPEN'
);

-- Période 2 : contient une écriture DRAFT → blocage
INSERT INTO client_demo.fiscal_periods (
  exercise_id, fiscal_year, period_number, start_date, end_date, status
) VALUES (
  (SELECT id FROM client_demo.fiscal_exercises WHERE fiscal_year = 2026),
  2026, 2, '2026-02-01', '2026-02-28', 'OPEN'
);

-- Période 3 : déjà CLOSED
INSERT INTO client_demo.fiscal_periods (
  exercise_id, fiscal_year, period_number, start_date, end_date, status
) VALUES (
  (SELECT id FROM client_demo.fiscal_exercises WHERE fiscal_year = 2026),
  2026, 3, '2026-03-01', '2026-03-31', 'CLOSED'
);

INSERT INTO client_demo.chart_of_accounts (account_number, account_label, account_type, level, normal_balance, is_active)
VALUES
  ('411000', 'Clients', 'ASSET', 1, 'DEBIT', TRUE),
  ('701000', 'Ventes', 'REVENUE', 1, 'CREDIT', TRUE);

INSERT INTO client_demo.journals (code, name, type, is_active)
VALUES ('OD05', 'Journal OD T05', 'GENERAL', TRUE);

-- Écriture DRAFT dans période 2
INSERT INTO client_demo.journal_entries (
  journal_id, entry_number, entry_date, posting_date, fiscal_period_id,
  description, status, total_debit, total_credit, created_by
) VALUES (
  (SELECT id FROM client_demo.journals WHERE code = 'OD05'),
  'OD05-000001', '2026-02-10', '2026-02-10',
  (SELECT id FROM client_demo.fiscal_periods WHERE fiscal_year = 2026 AND period_number = 2),
  'Écriture DRAFT en P2', 'DRAFT', 100000, 100000, 1
);

-- ── Tests ────────────────────────────────────────────────────────────────────

-- T5.1 / T5.2 — Cas nominal : période vide OPEN → CLOSED (une seule clôture, deux
-- champs vérifiés). La clôture est irréversible (§3, cf. T5.5) : on capture le
-- résultat de l'unique appel au lieu de reclôturer une période déjà CLOSED.
CREATE TEMP TABLE _t5_nominal AS
SELECT client_demo.rpc_close_fiscal_period(
  (SELECT id FROM client_demo.fiscal_periods WHERE fiscal_year = 2026 AND period_number = 1)
) AS r;

-- T5.1 — Cas nominal : période vide OPEN → fermeture réussie
SELECT is(
  (SELECT r ->> 'status' FROM _t5_nominal),
  'CLOSED',
  'T5.1 nominal : période vide OPEN fermée avec succès'
);

-- T5.2 — Cas nominal : success=true
SELECT is(
  (SELECT r ->> 'success' FROM _t5_nominal),
  'true',
  'T5.2 nominal : success=true sur clôture'
);

-- T5.3 — Blocage : écriture DRAFT → rejet
SELECT alike(
  (SELECT client_demo.rpc_close_fiscal_period(
    (SELECT id FROM client_demo.fiscal_periods WHERE fiscal_year = 2026 AND period_number = 2)
  )) ->> 'error',
  '%brouillon%',
  'T5.3 : écriture DRAFT bloque la clôture'
);

-- T5.4 — Blocage DRAFT : success=false
SELECT is(
  (SELECT client_demo.rpc_close_fiscal_period(
    (SELECT id FROM client_demo.fiscal_periods WHERE fiscal_year = 2026 AND period_number = 2)
  )) ->> 'success',
  'false',
  'T5.4 : success=false sur blocage DRAFT'
);

-- T5.5 — Irréversibilité : période déjà CLOSED → rejet
SELECT alike(
  (SELECT client_demo.rpc_close_fiscal_period(
    (SELECT id FROM client_demo.fiscal_periods WHERE fiscal_year = 2026 AND period_number = 3)
  )) ->> 'error',
  '%déjà fermée%',
  'T5.5 §3 irréversibilité : période CLOSED retourne erreur déjà fermée'
);

-- T5.6 — ID inexistant → rejet
SELECT alike(
  (SELECT client_demo.rpc_close_fiscal_period(999999999)) ->> 'error',
  '%introuvable%',
  'T5.6 : ID inexistant retourne erreur introuvable'
);

-- T5.7 — Vérification en base : statut mis à jour
SELECT is(
  (SELECT status FROM client_demo.fiscal_periods WHERE fiscal_year = 2026 AND period_number = 1),
  'CLOSED',
  'T5.7 : statut en base mis à jour à CLOSED'
);

SELECT * FROM finish();
ROLLBACK;
