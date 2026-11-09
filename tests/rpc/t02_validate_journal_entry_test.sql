-- ============================================================================
-- MCT T1b — rpc_validate_journal_entry
-- Tests : 6
-- Invariants : DRAFT→POSTED irréversible, période OPEN obligatoire (NOYAU-NORMATIF §2/§3)
-- ============================================================================
BEGIN;
SELECT plan(6);

-- ── Fixtures ─────────────────────────────────────────────────────────────────

INSERT INTO sys.tenants (
  tenant_code, company_name, legal_form, country_code, tier,
  subscription_level, subscription_start_date, database_schema, contact_email
) VALUES (
  'PGTAP_T02', 'Test T02 SARL', 'SARL', 'GA', 'JASPE',
  'ESSENTIEL', '2026-01-01', 'client_test_t02', 'test02@test.ga'
);

INSERT INTO client_demo.fiscal_exercises (fiscal_year, start_date, end_date, status)
VALUES (2026, '2026-01-01', '2026-12-31', 'OPEN');

INSERT INTO client_demo.fiscal_periods (
  exercise_id, fiscal_year, period_number, start_date, end_date, status
) VALUES (
  (SELECT id FROM client_demo.fiscal_exercises WHERE fiscal_year = 2026),
  2026, 1, '2026-01-01', '2026-01-31', 'OPEN'
);

INSERT INTO client_demo.fiscal_periods (
  exercise_id, fiscal_year, period_number, start_date, end_date, status
) VALUES (
  (SELECT id FROM client_demo.fiscal_exercises WHERE fiscal_year = 2026),
  2026, 2, '2026-02-01', '2026-02-28', 'CLOSED'
);

INSERT INTO client_demo.chart_of_accounts (account_number, account_label, account_type, level, normal_balance, is_active)
VALUES
  ('411000', 'Clients', 'ASSET', 1, 'DEBIT', TRUE),
  ('701000', 'Ventes', 'REVENUE', 1, 'CREDIT', TRUE);

INSERT INTO client_demo.journals (code, name, type, is_active)
VALUES ('OD02', 'Journal OD T02', 'GENERAL', TRUE);

-- Écriture DRAFT dans période OPEN
INSERT INTO client_demo.journal_entries (
  journal_id, entry_number, entry_date, posting_date, fiscal_period_id,
  description, status, total_debit, total_credit, created_by
) VALUES (
  (SELECT id FROM client_demo.journals WHERE code = 'OD02'),
  'OD02-000001', '2026-01-10', '2026-01-10',
  (SELECT id FROM client_demo.fiscal_periods WHERE fiscal_year = 2026 AND period_number = 1),
  'Écriture DRAFT test', 'DRAFT', 100000, 100000, 1
);

INSERT INTO client_demo.journal_entry_lines (
  journal_entry_id, line_number, account_id, debit_amount, credit_amount, created_by
) VALUES
  ((SELECT id FROM client_demo.journal_entries WHERE entry_number = 'OD02-000001'),
   1, (SELECT id FROM client_demo.chart_of_accounts WHERE account_number = '411000'), 100000, 0, 1),
  ((SELECT id FROM client_demo.journal_entries WHERE entry_number = 'OD02-000001'),
   2, (SELECT id FROM client_demo.chart_of_accounts WHERE account_number = '701000'), 0, 100000, 1);

-- Écriture déjà POSTED
INSERT INTO client_demo.journal_entries (
  journal_id, entry_number, entry_date, posting_date, fiscal_period_id,
  description, status, total_debit, total_credit, created_by
) VALUES (
  (SELECT id FROM client_demo.journals WHERE code = 'OD02'),
  'OD02-000002', '2026-01-10', '2026-01-10',
  (SELECT id FROM client_demo.fiscal_periods WHERE fiscal_year = 2026 AND period_number = 1),
  'Écriture déjà POSTED', 'POSTED', 50000, 50000, 1
);

-- ── Tests ────────────────────────────────────────────────────────────────────

-- T2.1 / T2.2 — Cas nominal : DRAFT → POSTED (une seule validation, deux champs
-- vérifiés). La validation est irréversible (§3, cf. T2.3) : on capture le
-- résultat de l'unique appel au lieu de revalider une écriture déjà POSTED.
CREATE TEMP TABLE _t2_nominal AS
SELECT client_demo.rpc_validate_journal_entry(
  (SELECT id FROM client_demo.journal_entries WHERE entry_number = 'OD02-000001')
) AS r;

-- T2.1 — Cas nominal : DRAFT → POSTED
SELECT is(
  (SELECT r ->> 'status' FROM _t2_nominal),
  'POSTED',
  'T2.1 nominal : DRAFT → POSTED avec succès'
);

-- T2.2 — Cas nominal : success=true
SELECT is(
  (SELECT r ->> 'success' FROM _t2_nominal),
  'true',
  'T2.2 nominal : success=true'
);

-- T2.3 — NOYAU-NORMATIF §3 irréversibilité : déjà POSTED → rejet
SELECT alike(
  (SELECT client_demo.rpc_validate_journal_entry(
    (SELECT id FROM client_demo.journal_entries WHERE entry_number = 'OD02-000002')
  )) ->> 'error',
  '%DRAFT%',
  'T2.3 §3 irréversibilité : écriture déjà POSTED retourne erreur DRAFT'
);

-- T2.4 — ID inexistant → rejet
SELECT alike(
  (SELECT client_demo.rpc_validate_journal_entry(999999999)) ->> 'error',
  '%introuvable%',
  'T2.4 : ID inexistant retourne erreur introuvable'
);

-- T2.5 — Période fermée → rejet (écriture dans période CLOSED)
INSERT INTO client_demo.journal_entries (
  journal_id, entry_number, entry_date, posting_date, fiscal_period_id,
  description, status, total_debit, total_credit, created_by
) VALUES (
  (SELECT id FROM client_demo.journals WHERE code = 'OD02'),
  'OD02-000003', '2026-02-10', '2026-02-10',
  (SELECT id FROM client_demo.fiscal_periods WHERE fiscal_year = 2026 AND period_number = 2),
  'Écriture période fermée', 'DRAFT', 20000, 20000, 1
);

SELECT alike(
  (SELECT client_demo.rpc_validate_journal_entry(
    (SELECT id FROM client_demo.journal_entries WHERE entry_number = 'OD02-000003')
  )) ->> 'error',
  '%Période fiscale fermée%',
  'T2.5 : période CLOSED retourne erreur période fermée'
);

-- T2.6 — Vérification en base : statut mis à jour en POSTED
SELECT is(
  (SELECT status FROM client_demo.journal_entries WHERE entry_number = 'OD02-000001'),
  'POSTED',
  'T2.6 : statut en base mis à jour à POSTED'
);

SELECT * FROM finish();
ROLLBACK;
