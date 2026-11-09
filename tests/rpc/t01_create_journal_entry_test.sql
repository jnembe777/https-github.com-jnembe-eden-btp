-- ============================================================================
-- MCT T1 — rpc_create_journal_entry
-- Tests : 8
-- Invariants : RG01 équilibre D=C, RG02 période OPEN obligatoire
-- ============================================================================
BEGIN;
SELECT plan(8);

-- ── Fixtures ─────────────────────────────────────────────────────────────────

INSERT INTO sys.tenants (
  tenant_code, company_name, legal_form, country_code, tier,
  subscription_level, subscription_start_date, database_schema, contact_email
) VALUES (
  'PGTAP_T01', 'Test T01 SARL', 'SARL', 'GA', 'JASPE',
  'ESSENTIEL', '2026-01-01', 'client_test_t01', 'test01@test.ga'
);

INSERT INTO client_demo.fiscal_exercises (
  fiscal_year, start_date, end_date, status
) VALUES (2026, '2026-01-01', '2026-12-31', 'OPEN');

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

INSERT INTO client_demo.chart_of_accounts (
  account_number, account_label, account_type, level, normal_balance, is_active
) VALUES
  ('411000', 'Clients', 'ASSET', 1, 'DEBIT', TRUE),
  ('701000', 'Ventes de marchandises', 'REVENUE', 1, 'CREDIT', TRUE);

INSERT INTO client_demo.journals (code, name, type, is_active)
VALUES ('VTE', 'Journal des ventes', 'SALES', TRUE);

INSERT INTO client_demo.journals (code, name, type, is_active)
VALUES ('INACT', 'Journal inactif', 'GENERAL', FALSE);

-- ── Tests ────────────────────────────────────────────────────────────────────

-- T1.1 — Cas nominal : écriture équilibrée dans période OPEN
SELECT ok(
  (SELECT client_demo.rpc_create_journal_entry(
    (SELECT id FROM client_demo.journals WHERE code = 'VTE'),
    '2026-01-15',
    'Vente client Test',
    'REF-001',
    jsonb_build_array(
      jsonb_build_object('account_id', (SELECT id FROM client_demo.chart_of_accounts WHERE account_number = '411000'), 'debit', 100000, 'credit', 0),
      jsonb_build_object('account_id', (SELECT id FROM client_demo.chart_of_accounts WHERE account_number = '701000'), 'debit', 0, 'credit', 100000)
    )
  )) ->> 'success' = 'true',
  'T1.1 nominal : écriture équilibrée créée avec succès'
);

-- T1.2 — Cas nominal : entry_id retourné non null
SELECT isnt(
  (SELECT (client_demo.rpc_create_journal_entry(
    (SELECT id FROM client_demo.journals WHERE code = 'VTE'),
    '2026-01-15',
    'Vente client Test 2',
    NULL,
    jsonb_build_array(
      jsonb_build_object('account_id', (SELECT id FROM client_demo.chart_of_accounts WHERE account_number = '411000'), 'debit', 50000, 'credit', 0),
      jsonb_build_object('account_id', (SELECT id FROM client_demo.chart_of_accounts WHERE account_number = '701000'), 'debit', 0, 'credit', 50000)
    )
  )) ->> 'entry_id')::BIGINT,
  NULL::BIGINT,
  'T1.2 nominal : entry_id est non null'
);

-- T1.3 — RG01 : déséquilibre débit ≠ crédit → rejet
SELECT alike(
  (SELECT client_demo.rpc_create_journal_entry(
    (SELECT id FROM client_demo.journals WHERE code = 'VTE'),
    '2026-01-15',
    'Écriture déséquilibrée',
    NULL,
    jsonb_build_array(
      jsonb_build_object('account_id', (SELECT id FROM client_demo.chart_of_accounts WHERE account_number = '411000'), 'debit', 100000, 'credit', 0),
      jsonb_build_object('account_id', (SELECT id FROM client_demo.chart_of_accounts WHERE account_number = '701000'), 'debit', 0, 'credit', 60000)
    )
  )) ->> 'error',
  '%déséquilibrée%',
  'T1.3 RG01 : déséquilibre D≠C retourne erreur déséquilibrée'
);

-- T1.4 — RG01 : montants nuls → rejet
SELECT alike(
  (SELECT client_demo.rpc_create_journal_entry(
    (SELECT id FROM client_demo.journals WHERE code = 'VTE'),
    '2026-01-15',
    'Écriture vide',
    NULL,
    jsonb_build_array(
      jsonb_build_object('account_id', (SELECT id FROM client_demo.chart_of_accounts WHERE account_number = '411000'), 'debit', 0, 'credit', 0),
      jsonb_build_object('account_id', (SELECT id FROM client_demo.chart_of_accounts WHERE account_number = '701000'), 'debit', 0, 'credit', 0)
    )
  )) ->> 'error',
  '%vide%',
  'T1.4 RG01 : montants nuls retournent erreur vide'
);

-- T1.5 — RG01 : success=false sur déséquilibre
SELECT is(
  (SELECT client_demo.rpc_create_journal_entry(
    (SELECT id FROM client_demo.journals WHERE code = 'VTE'),
    '2026-01-15',
    'Test déséquilibre',
    NULL,
    jsonb_build_array(
      jsonb_build_object('account_id', (SELECT id FROM client_demo.chart_of_accounts WHERE account_number = '411000'), 'debit', 999, 'credit', 0),
      jsonb_build_object('account_id', (SELECT id FROM client_demo.chart_of_accounts WHERE account_number = '701000'), 'debit', 0, 'credit', 1)
    )
  )) ->> 'success',
  'false',
  'T1.5 RG01 : success=false sur déséquilibre'
);

-- T1.6 — Journal inactif → rejet
SELECT alike(
  (SELECT client_demo.rpc_create_journal_entry(
    (SELECT id FROM client_demo.journals WHERE code = 'INACT'),
    '2026-01-15',
    'Test journal inactif',
    NULL,
    jsonb_build_array(
      jsonb_build_object('account_id', (SELECT id FROM client_demo.chart_of_accounts WHERE account_number = '411000'), 'debit', 100, 'credit', 0),
      jsonb_build_object('account_id', (SELECT id FROM client_demo.chart_of_accounts WHERE account_number = '701000'), 'debit', 0, 'credit', 100)
    )
  )) ->> 'error',
  '%Journal introuvable%',
  'T1.6 : journal inactif retourne erreur introuvable'
);

-- T1.7 — RG02 : date hors période OPEN (période CLOSED) → rejet
SELECT alike(
  (SELECT client_demo.rpc_create_journal_entry(
    (SELECT id FROM client_demo.journals WHERE code = 'VTE'),
    '2026-02-15',
    'Test période fermée',
    NULL,
    jsonb_build_array(
      jsonb_build_object('account_id', (SELECT id FROM client_demo.chart_of_accounts WHERE account_number = '411000'), 'debit', 100, 'credit', 0),
      jsonb_build_object('account_id', (SELECT id FROM client_demo.chart_of_accounts WHERE account_number = '701000'), 'debit', 0, 'credit', 100)
    )
  )) ->> 'error',
  '%Aucune période fiscale ouverte%',
  'T1.7 RG02 : période CLOSED retourne erreur période non ouverte'
);

-- T1.8 — Écriture créée : statut DRAFT
SELECT is(
  (SELECT status FROM client_demo.journal_entries
   WHERE description = 'Vente client Test' LIMIT 1),
  'DRAFT',
  'T1.8 : écriture créée en statut DRAFT'
);

SELECT * FROM finish();
ROLLBACK;
