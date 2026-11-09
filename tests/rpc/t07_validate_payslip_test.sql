-- ============================================================================
-- MCT T6 — rpc_validate_payslip
-- Tests : 6
-- Invariants : DRAFT→VALIDATED irréversible (NOYAU-NORMATIF §2/§3)
-- ============================================================================
BEGIN;
SELECT plan(6);

-- ── Fixtures ─────────────────────────────────────────────────────────────────

INSERT INTO sys.tenants (
  tenant_code, company_name, legal_form, country_code, tier,
  subscription_level, subscription_start_date, database_schema, contact_email
) VALUES (
  'PGTAP_T07', 'Test T07 SARL', 'SARL', 'GA', 'JASPE',
  'ESSENTIEL', '2026-01-01', 'client_test_t07', 'test07@test.ga'
);

INSERT INTO client_demo.partners (code, name, type, country_code)
VALUES ('EMP007', 'Employé T07', 'EMPLOYEE', 'GA');

INSERT INTO client_demo.employees (
  employee_number, partner_id, first_name, last_name,
  hire_date, contract_type, base_salary, salary_type, is_active
) VALUES (
  'EMP-007',
  (SELECT id FROM client_demo.partners WHERE code = 'EMP007'),
  'Test', 'T07',
  '2025-01-01', 'CDI', 400000, 'MONTHLY', TRUE
);

INSERT INTO client_demo.pay_periods (
  fiscal_year, period_month, start_date, end_date, status
) VALUES (2026, 7, '2026-07-01', '2026-07-31', 'OPEN');

-- Bulletin DRAFT
INSERT INTO client_demo.payslips (
  employee_id, period_start, period_end, payment_date,
  gross_salary, net_salary, net_taxable, employer_contributions, status, pay_period_id
) VALUES (
  (SELECT id FROM client_demo.employees WHERE employee_number = 'EMP-007'),
  '2026-07-01', '2026-07-31', '2026-07-31',
  400000, 360000, 380000, 80000, 'DRAFT',
  (SELECT id FROM client_demo.pay_periods WHERE fiscal_year = 2026 AND period_month = 7)
);

-- Bulletin déjà VALIDATED
INSERT INTO client_demo.payslips (
  employee_id, period_start, period_end, payment_date,
  gross_salary, net_salary, net_taxable, employer_contributions, status
) VALUES (
  (SELECT id FROM client_demo.employees WHERE employee_number = 'EMP-007'),
  '2026-06-01', '2026-06-30', '2026-06-30',
  400000, 360000, 380000, 80000, 'VALIDATED'
);

-- ── Tests ────────────────────────────────────────────────────────────────────

-- T7.1 / T7.2 — Cas nominal : DRAFT → VALIDATED (une seule validation, deux
-- champs vérifiés). La validation est irréversible (§3, cf. T7.3) : on capture le
-- résultat de l'unique appel au lieu de revalider un bulletin déjà VALIDATED.
CREATE TEMP TABLE _t7_nominal AS
SELECT client_demo.rpc_validate_payslip(
  (SELECT id FROM client_demo.payslips
   WHERE employee_id = (SELECT id FROM client_demo.employees WHERE employee_number = 'EMP-007')
     AND period_start = '2026-07-01')
) AS r;

-- T7.1 — Cas nominal : DRAFT → VALIDATED
SELECT is(
  (SELECT r ->> 'status' FROM _t7_nominal),
  'VALIDATED',
  'T7.1 nominal : DRAFT → VALIDATED avec succès'
);

-- T7.2 — success=true
SELECT is(
  (SELECT r ->> 'success' FROM _t7_nominal),
  'true',
  'T7.2 nominal : success=true'
);

-- T7.3 — Irréversibilité §3 : déjà VALIDATED → rejet
SELECT alike(
  (SELECT client_demo.rpc_validate_payslip(
    (SELECT id FROM client_demo.payslips
     WHERE employee_id = (SELECT id FROM client_demo.employees WHERE employee_number = 'EMP-007')
       AND period_start = '2026-06-01')
  )) ->> 'error',
  '%DRAFT%',
  'T7.3 §3 irréversibilité : bulletin VALIDATED retourne erreur DRAFT'
);

-- T7.4 — Irréversibilité : success=false
SELECT is(
  (SELECT client_demo.rpc_validate_payslip(
    (SELECT id FROM client_demo.payslips
     WHERE employee_id = (SELECT id FROM client_demo.employees WHERE employee_number = 'EMP-007')
       AND period_start = '2026-06-01')
  )) ->> 'success',
  'false',
  'T7.4 §3 irréversibilité : success=false sur bulletin déjà validé'
);

-- T7.5 — ID inexistant → rejet
SELECT alike(
  (SELECT client_demo.rpc_validate_payslip(999999999)) ->> 'error',
  '%introuvable%',
  'T7.5 : ID inexistant retourne erreur introuvable'
);

-- T7.6 — Vérification en base : statut mis à jour à VALIDATED
SELECT is(
  (SELECT status FROM client_demo.payslips
   WHERE employee_id = (SELECT id FROM client_demo.employees WHERE employee_number = 'EMP-007')
     AND period_start = '2026-07-01'),
  'VALIDATED',
  'T7.6 : statut en base mis à jour à VALIDATED'
);

SELECT * FROM finish();
ROLLBACK;
