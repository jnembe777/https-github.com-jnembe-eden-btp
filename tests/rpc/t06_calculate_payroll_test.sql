-- ============================================================================
-- MCT T5 — rpc_calculate_payroll
-- Tests : 6
-- Invariants : taux cotisations lus depuis contribution_rates (NOYAU-NORMATIF §1)
--              IRPP lu depuis common.tax_codes (NOYAU-NORMATIF §5)
-- ============================================================================
BEGIN;
SELECT plan(6);

-- ── Fixtures ─────────────────────────────────────────────────────────────────

INSERT INTO sys.tenants (
  tenant_code, company_name, legal_form, country_code, tier,
  subscription_level, subscription_start_date, database_schema, contact_email
) VALUES (
  'PGTAP_T06', 'Test T06 SARL', 'SARL', 'GA', 'JASPE',
  'ESSENTIEL', '2026-01-01', 'client_test_t06', 'test06@test.ga'
);

-- IRPP depuis common.tax_codes (NOYAU-NORMATIF §5)
INSERT INTO common.tax_codes (
  country_code, code, name, rate, type, effective_date, is_default
) VALUES (
  'GA', 'IRPP_GA_STD', 'IRPP Gabon Standard', 5.00, 'PAYROLL', '2026-01-01', TRUE
);

-- ── Tests ────────────────────────────────────────────────────────────────────

-- T6.1 — Cas nominal : aucun employé actif → success=true, 0 employé
SELECT is(
  (SELECT client_demo.rpc_calculate_payroll(1, 2026)) ->> 'success',
  'true',
  'T6.1 nominal : aucun employé actif retourne success=true'
);

-- T6.2 — Aucun employé → employees_processed=0
SELECT is(
  ((SELECT client_demo.rpc_calculate_payroll(1, 2026)) ->> 'employees_processed')::INT,
  0,
  'T6.2 nominal : employees_processed=0 sans employé'
);

-- T6.3 — Avec un employé : bulletin créé et retourné
INSERT INTO client_demo.chart_of_accounts (account_number, account_label, account_type, level, normal_balance, is_active)
VALUES ('421000', 'Personnel - rémunérations dues', 'LIABILITY', 1, 'CREDIT', TRUE);

INSERT INTO client_demo.payroll_rubrics (
  code, label, rubric_type, rubric_category, calc_mode,
  display_order, is_active, effective_date
) VALUES (
  'SAL_BASE', 'Salaire de base', 'EARNING', 'BASE', 'FIXED', 1, TRUE, '2026-01-01'
);

INSERT INTO client_demo.contribution_rates (
  rubric_id, organism_code, organism_label,
  bracket_code, employee_rate, employer_rate,
  applies_to, effective_date
) VALUES (
  (SELECT id FROM client_demo.payroll_rubrics WHERE code = 'SAL_BASE'),
  'CNSS', 'Caisse Nationale de Sécurité Sociale',
  'A', 0.02500, 0.16000, 'ALL', '2026-01-01'
);

INSERT INTO client_demo.partners (code, name, type, country_code)
VALUES ('EMP001', 'Jean Dupont', 'EMPLOYEE', 'GA');

INSERT INTO client_demo.employees (
  employee_number, partner_id, first_name, last_name,
  hire_date, contract_type, base_salary, salary_type, is_active
) VALUES (
  'EMP-001',
  (SELECT id FROM client_demo.partners WHERE code = 'EMP001'),
  'Jean', 'Dupont',
  '2025-01-01', 'CDI', 500000, 'MONTHLY', TRUE
);

INSERT INTO client_demo.pay_periods (
  fiscal_year, period_month, start_date, end_date, status
) VALUES (2026, 7, '2026-07-01', '2026-07-31', 'OPEN');

SELECT is(
  (SELECT client_demo.rpc_calculate_payroll(7, 2026)) ->> 'success',
  'true',
  'T6.3 : avec 1 employé actif retourne success=true'
);

-- T6.4 — Avec employé : employees_processed=1
SELECT is(
  ((SELECT client_demo.rpc_calculate_payroll(7, 2026)) ->> 'employees_processed')::INT,
  1,
  'T6.4 : employees_processed=1 avec 1 employé'
);

-- T6.5 — Normativité §1 : bulletin créé avec lignes cotisations
SELECT ok(
  EXISTS(
    SELECT 1 FROM client_demo.payslip_lines pl
    JOIN client_demo.payslips ps ON ps.id = pl.payslip_id
    JOIN client_demo.employees e ON e.id = ps.employee_id
    WHERE e.employee_number = 'EMP-001'
      AND pl.line_type = 'DEDUCTION'
  ),
  'T6.5 §1 normativité : lignes de déduction cotisations créées'
);

-- T6.6 — Normativité §1 : ligne IRPP présente (lu depuis common.tax_codes)
SELECT ok(
  EXISTS(
    SELECT 1 FROM client_demo.payslip_lines pl
    JOIN client_demo.payslips ps ON ps.id = pl.payslip_id
    JOIN client_demo.employees e ON e.id = ps.employee_id
    WHERE e.employee_number = 'EMP-001'
      AND pl.code = 'IRPP'
  ),
  'T6.6 §5 normativité : ligne IRPP présente (taux depuis common.tax_codes)'
);

SELECT * FROM finish();
ROLLBACK;
