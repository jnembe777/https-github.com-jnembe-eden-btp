-- ============================================================================
-- MCT T3 — rpc_auto_lettrage
-- Tests : 5
-- Invariants : matching factures/paiements par tiers + montant
-- ============================================================================
BEGIN;
SELECT plan(5);

-- ── Fixtures ─────────────────────────────────────────────────────────────────

INSERT INTO sys.tenants (
  tenant_code, company_name, legal_form, country_code, tier,
  subscription_level, subscription_start_date, database_schema, contact_email
) VALUES (
  'PGTAP_T04', 'Test T04 SARL', 'SARL', 'GA', 'JASPE',
  'ESSENTIEL', '2026-01-01', 'client_test_t04', 'test04@test.ga'
);

INSERT INTO client_demo.fiscal_exercises (fiscal_year, start_date, end_date, status)
VALUES (2026, '2026-01-01', '2026-12-31', 'OPEN');

INSERT INTO client_demo.fiscal_periods (
  exercise_id, fiscal_year, period_number, start_date, end_date, status
) VALUES (
  (SELECT id FROM client_demo.fiscal_exercises WHERE fiscal_year = 2026),
  2026, 1, '2026-01-01', '2026-01-31', 'OPEN'
);

INSERT INTO client_demo.chart_of_accounts (account_number, account_label, account_type, level, normal_balance, is_active)
VALUES ('411000', 'Clients', 'ASSET', 1, 'DEBIT', TRUE);

INSERT INTO client_demo.partners (code, name, type, country_code)
VALUES ('CUST001', 'Client Test', 'CUSTOMER', 'GA');

INSERT INTO client_demo.journals (code, name, type, is_active)
VALUES ('VTE04', 'Ventes T04', 'SALES', TRUE);

-- Écriture 1 : facture (débit 411000)
INSERT INTO client_demo.journal_entries (
  journal_id, entry_number, entry_date, posting_date, fiscal_period_id,
  description, status, total_debit, total_credit, created_by
) VALUES (
  (SELECT id FROM client_demo.journals WHERE code = 'VTE04'),
  'VTE04-000001', '2026-01-05', '2026-01-05',
  (SELECT id FROM client_demo.fiscal_periods WHERE fiscal_year = 2026 AND period_number = 1),
  'Facture client', 'DRAFT', 200000, 200000, 1
);

INSERT INTO client_demo.journal_entry_lines (
  journal_entry_id, line_number, account_id, debit_amount, credit_amount,
  partner_id, created_by
) VALUES (
  (SELECT id FROM client_demo.journal_entries WHERE entry_number = 'VTE04-000001'),
  1, (SELECT id FROM client_demo.chart_of_accounts WHERE account_number = '411000'),
  200000, 0,
  (SELECT id FROM client_demo.partners WHERE code = 'CUST001'), 1
);

-- Écriture 2 : règlement (crédit 411000 même montant)
INSERT INTO client_demo.journal_entries (
  journal_id, entry_number, entry_date, posting_date, fiscal_period_id,
  description, status, total_debit, total_credit, created_by
) VALUES (
  (SELECT id FROM client_demo.journals WHERE code = 'VTE04'),
  'VTE04-000002', '2026-01-20', '2026-01-20',
  (SELECT id FROM client_demo.fiscal_periods WHERE fiscal_year = 2026 AND period_number = 1),
  'Règlement client', 'DRAFT', 200000, 200000, 1
);

INSERT INTO client_demo.journal_entry_lines (
  journal_entry_id, line_number, account_id, debit_amount, credit_amount,
  partner_id, created_by
) VALUES (
  (SELECT id FROM client_demo.journal_entries WHERE entry_number = 'VTE04-000002'),
  1, (SELECT id FROM client_demo.chart_of_accounts WHERE account_number = '411000'),
  0, 200000,
  (SELECT id FROM client_demo.partners WHERE code = 'CUST001'), 1
);

-- Les écritures sont créées en DRAFT puis postées APRÈS insertion des lignes :
-- insérer une ligne dans une écriture déjà POSTED déclenche le trigger de
-- recalcul des totaux (UPDATE du parent), bloqué par le garde d'immuabilité
-- POSTED. On passe donc DRAFT → POSTED une fois les lignes en place.
UPDATE client_demo.journal_entries
   SET status = 'POSTED'
 WHERE entry_number IN ('VTE04-000001', 'VTE04-000002');

-- ── Tests ────────────────────────────────────────────────────────────────────

-- T4.1 — Cas nominal : partenaire sans lignes → success=true, 0 paire
SELECT is(
  (SELECT client_demo.rpc_auto_lettrage(99999999)) ->> 'success',
  'true',
  'T4.1 nominal : partenaire sans lignes retourne success=true'
);

-- T4.2 — Cas nominal : 0 paire si partenaire inconnu
SELECT is(
  ((SELECT client_demo.rpc_auto_lettrage(99999999)) ->> 'pairs_matched')::INT,
  0,
  'T4.2 nominal : 0 paire sur partenaire inconnu'
);

-- T4.3 — Cas nominal : 1 paire lettrée pour débit/crédit même montant
SELECT is(
  ((SELECT client_demo.rpc_auto_lettrage(
    (SELECT id FROM client_demo.partners WHERE code = 'CUST001')
  )) ->> 'pairs_matched')::INT,
  1,
  'T4.3 nominal : 1 paire lettrée débit/crédit même montant'
);

-- T4.4 — success=true sur lettrage réel
SELECT is(
  (SELECT client_demo.rpc_auto_lettrage(
    (SELECT id FROM client_demo.partners WHERE code = 'CUST001')
  )) ->> 'success',
  'true',
  'T4.4 nominal : success=true sur lettrage réel'
);

-- T4.5 — Lignes lettrées : reconciliation_id non null après lettrage
SELECT ok(
  EXISTS(
    SELECT 1 FROM client_demo.journal_entry_lines
    WHERE partner_id = (SELECT id FROM client_demo.partners WHERE code = 'CUST001')
      AND reconciliation_id IS NOT NULL
  ),
  'T4.5 : lignes ont reconciliation_id après lettrage'
);

SELECT * FROM finish();
ROLLBACK;
