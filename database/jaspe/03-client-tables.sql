-- ============================================================================
-- EDENFIN JASPE — SCRIPT 03 : TABLES MÉTIER (schéma client_demo)
-- À exécuter APRÈS le script 02
-- Sources consolidées : 03_schema_jaspe_demo.sql + 07_payroll_parameter_tables.sql
--                       + 08_asset_and_accounting_tables.sql
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS client_demo;

-- ────────────────────────────────────────────────────────────────────────────
-- 1. CONFIGURATION CLIENT
-- ────────────────────────────────────────────────────────────────────────────

-- Plan comptable actif du client (copié depuis common.chart_of_accounts_details)
CREATE TABLE client_demo.chart_of_accounts (
  id BIGSERIAL PRIMARY KEY,
  template_id BIGINT,
  account_number VARCHAR(20) NOT NULL UNIQUE,
  account_label VARCHAR(500) NOT NULL,
  account_type VARCHAR(50) NOT NULL CHECK (account_type IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE')),
  parent_account_id BIGINT REFERENCES client_demo.chart_of_accounts(id),
  level INT NOT NULL CHECK (level > 0),
  is_detail_account BOOLEAN NOT NULL DEFAULT TRUE,
  normal_balance VARCHAR(10) NOT NULL CHECK (normal_balance IN ('DEBIT', 'CREDIT')),
  financial_statement VARCHAR(50) CHECK (financial_statement IN ('BALANCE_SHEET', 'INCOME_STATEMENT', 'CASH_FLOW')),
  reconciliation_required BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  deleted_at TIMESTAMPTZ,
  deleted_by BIGINT,
  version_number INT NOT NULL DEFAULT 1
);

CREATE INDEX idx_cd_coa_number ON client_demo.chart_of_accounts(account_number) WHERE deleted_at IS NULL;
CREATE INDEX idx_cd_coa_type ON client_demo.chart_of_accounts(account_type, is_active);
CREATE INDEX idx_cd_coa_parent ON client_demo.chart_of_accounts(parent_account_id);
COMMENT ON TABLE client_demo.chart_of_accounts IS 'Plan comptable OHADA actif du client';

-- Exercices comptables (conteneur parent des périodes)
CREATE TABLE client_demo.fiscal_exercises (
  id BIGSERIAL PRIMARY KEY,
  fiscal_year INT NOT NULL UNIQUE,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'OPEN' CHECK (status IN ('DRAFT', 'OPEN', 'CLOSING', 'CLOSED', 'LOCKED')),
  opening_entry_id BIGINT,
  closing_entry_id BIGINT,
  result_amount DECIMAL(18,2),
  result_type VARCHAR(10) CHECK (result_type IN ('PROFIT', 'LOSS')),
  opened_at TIMESTAMPTZ,
  closed_at TIMESTAMPTZ,
  locked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  CHECK (end_date > start_date)
);

COMMENT ON TABLE client_demo.fiscal_exercises IS 'Exercices comptables annuels (workflow OPEN→CLOSING→CLOSED→LOCKED)';

-- Périodes fiscales (mois)
CREATE TABLE client_demo.fiscal_periods (
  id BIGSERIAL PRIMARY KEY,
  exercise_id BIGINT REFERENCES client_demo.fiscal_exercises(id),
  fiscal_year INT NOT NULL,
  period_number INT NOT NULL CHECK (period_number BETWEEN 1 AND 13),
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'CLOSED', 'LOCKED')),
  is_adjustment_period BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  UNIQUE(fiscal_year, period_number),
  CHECK (end_date > start_date)
);

CREATE INDEX idx_cd_fiscal_periods_year ON client_demo.fiscal_periods(fiscal_year, period_number);
CREATE INDEX idx_cd_fiscal_periods_status ON client_demo.fiscal_periods(status);
COMMENT ON TABLE client_demo.fiscal_periods IS 'Périodes fiscales mensuelles (workflow OPEN→CLOSED→LOCKED)';

-- Journaux comptables
CREATE TABLE client_demo.journals (
  id BIGSERIAL PRIMARY KEY,
  code VARCHAR(10) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  type VARCHAR(30) NOT NULL CHECK (type IN ('SALES', 'PURCHASES', 'BANK', 'CASH', 'GENERAL', 'PAYROLL')),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  default_debit_account_id BIGINT REFERENCES client_demo.chart_of_accounts(id),
  default_credit_account_id BIGINT REFERENCES client_demo.chart_of_accounts(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  deleted_at TIMESTAMPTZ,
  deleted_by BIGINT,
  version_number INT NOT NULL DEFAULT 1
);

CREATE INDEX idx_cd_journals_type ON client_demo.journals(type, is_active);
COMMENT ON TABLE client_demo.journals IS 'Journaux comptables (VTE, ACH, BQ, CAI, OD, PAIE)';

-- ────────────────────────────────────────────────────────────────────────────
-- 2. TIERS (Clients, Fournisseurs, Employés)
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE client_demo.partners (
  id BIGSERIAL PRIMARY KEY,
  code VARCHAR(20) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  type VARCHAR(30) NOT NULL CHECK (type IN ('CUSTOMER', 'SUPPLIER', 'BOTH', 'EMPLOYEE', 'OTHER')),
  legal_form VARCHAR(100),
  siret VARCHAR(14),
  vat_number VARCHAR(50),
  address_line1 VARCHAR(200),
  address_line2 VARCHAR(200),
  postal_code VARCHAR(20),
  city VARCHAR(100),
  country_code CHAR(3) NOT NULL DEFAULT 'GA',
  email VARCHAR(255),
  phone VARCHAR(50),
  mobile VARCHAR(50),
  website VARCHAR(255),
  payment_term_days INT DEFAULT 30,
  payment_method VARCHAR(50),
  credit_limit DECIMAL(18,2),
  discount_percentage DECIMAL(5,2),
  customer_account_id BIGINT REFERENCES client_demo.chart_of_accounts(id),
  supplier_account_id BIGINT REFERENCES client_demo.chart_of_accounts(id),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  deleted_at TIMESTAMPTZ,
  deleted_by BIGINT,
  version_number INT NOT NULL DEFAULT 1
);

CREATE INDEX idx_cd_partners_code ON client_demo.partners(code) WHERE deleted_at IS NULL;
CREATE INDEX idx_cd_partners_name ON client_demo.partners(name);
CREATE INDEX idx_cd_partners_type ON client_demo.partners(type, is_active);
COMMENT ON TABLE client_demo.partners IS 'Tiers : clients, fournisseurs, employés';

-- ────────────────────────────────────────────────────────────────────────────
-- 3. BANQUES
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE client_demo.bank_accounts (
  id BIGSERIAL PRIMARY KEY,
  code VARCHAR(20) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  bank_name VARCHAR(200),
  account_number VARCHAR(34),
  swift_bic VARCHAR(11),
  currency_code CHAR(3) NOT NULL DEFAULT 'XAF',
  initial_balance DECIMAL(18,2) NOT NULL DEFAULT 0,
  current_balance DECIMAL(18,2) NOT NULL DEFAULT 0,
  ledger_account_id BIGINT NOT NULL REFERENCES client_demo.chart_of_accounts(id),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  deleted_at TIMESTAMPTZ,
  deleted_by BIGINT,
  version_number INT NOT NULL DEFAULT 1
);

CREATE INDEX idx_cd_bank_accounts_code ON client_demo.bank_accounts(code) WHERE deleted_at IS NULL;
COMMENT ON TABLE client_demo.bank_accounts IS 'Comptes bancaires de l''entreprise';

CREATE TABLE client_demo.bank_transactions (
  id BIGSERIAL PRIMARY KEY,
  bank_account_id BIGINT NOT NULL REFERENCES client_demo.bank_accounts(id),
  transaction_date DATE NOT NULL,
  value_date DATE NOT NULL,
  description VARCHAR(500) NOT NULL,
  amount DECIMAL(18,2) NOT NULL,
  balance_after DECIMAL(18,2),
  reference VARCHAR(100),
  partner_id BIGINT REFERENCES client_demo.partners(id),
  journal_entry_id BIGINT,
  is_reconciled BOOLEAN NOT NULL DEFAULT FALSE,
  reconciled_at TIMESTAMPTZ,
  reconciled_by BIGINT,
  imported_from VARCHAR(100),
  import_reference VARCHAR(100),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT
);

CREATE INDEX idx_cd_bank_trans_account ON client_demo.bank_transactions(bank_account_id, transaction_date DESC);
CREATE INDEX idx_cd_bank_trans_reconciled ON client_demo.bank_transactions(is_reconciled) WHERE is_reconciled = FALSE;
COMMENT ON TABLE client_demo.bank_transactions IS 'Mouvements bancaires importés ou saisis';

-- ────────────────────────────────────────────────────────────────────────────
-- 4. GROUPES DE LETTRAGE (avant journal_entry_lines qui y fait référence)
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE client_demo.reconciliation_groups (
  id BIGSERIAL PRIMARY KEY,
  group_code VARCHAR(20) NOT NULL UNIQUE,
  account_id BIGINT NOT NULL REFERENCES client_demo.chart_of_accounts(id),
  partner_id BIGINT REFERENCES client_demo.partners(id),
  total_debit DECIMAL(18,2) NOT NULL DEFAULT 0,
  total_credit DECIMAL(18,2) NOT NULL DEFAULT 0,
  balance DECIMAL(18,2) GENERATED ALWAYS AS (total_debit - total_credit) STORED,
  is_balanced BOOLEAN GENERATED ALWAYS AS (ABS(total_debit - total_credit) < 0.01) STORED,
  reconciled_at TIMESTAMPTZ,
  reconciled_by BIGINT,
  auto_matched BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0
);

CREATE INDEX idx_reconciliation_account ON client_demo.reconciliation_groups(account_id);
CREATE INDEX idx_reconciliation_partner ON client_demo.reconciliation_groups(partner_id);
CREATE INDEX idx_reconciliation_balanced ON client_demo.reconciliation_groups(is_balanced);
COMMENT ON TABLE client_demo.reconciliation_groups IS 'Groupes de lettrage facture/règlement';

-- ────────────────────────────────────────────────────────────────────────────
-- 5. ÉCRITURES COMPTABLES
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE client_demo.journal_entries (
  id BIGSERIAL PRIMARY KEY,
  journal_id BIGINT NOT NULL REFERENCES client_demo.journals(id),
  entry_number VARCHAR(50) NOT NULL,
  entry_date DATE NOT NULL,
  posting_date DATE NOT NULL DEFAULT CURRENT_DATE,
  fiscal_period_id BIGINT NOT NULL REFERENCES client_demo.fiscal_periods(id),
  reference VARCHAR(100),
  description VARCHAR(500) NOT NULL,
  total_debit DECIMAL(18,2) NOT NULL DEFAULT 0,
  total_credit DECIMAL(18,2) NOT NULL DEFAULT 0,
  status VARCHAR(20) NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'POSTED', 'VALIDATED', 'CANCELLED')),
  validated_by BIGINT,
  validated_at TIMESTAMPTZ,
  source_document_type VARCHAR(50),
  source_document_id BIGINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  deleted_at TIMESTAMPTZ,
  deleted_by BIGINT,
  version_number INT NOT NULL DEFAULT 1,
  UNIQUE(journal_id, entry_number)
);

CREATE INDEX idx_cd_je_journal ON client_demo.journal_entries(journal_id, entry_date DESC);
CREATE INDEX idx_cd_je_date ON client_demo.journal_entries(entry_date DESC);
CREATE INDEX idx_cd_je_period ON client_demo.journal_entries(fiscal_period_id);
CREATE INDEX idx_cd_je_status ON client_demo.journal_entries(status);
COMMENT ON TABLE client_demo.journal_entries IS 'En-têtes des écritures comptables (workflow DRAFT→POSTED)';

CREATE TABLE client_demo.journal_entry_lines (
  id BIGSERIAL PRIMARY KEY,
  journal_entry_id BIGINT NOT NULL REFERENCES client_demo.journal_entries(id) ON DELETE CASCADE,
  line_number INT NOT NULL,
  account_id BIGINT NOT NULL REFERENCES client_demo.chart_of_accounts(id),
  debit_amount DECIMAL(18,2) NOT NULL DEFAULT 0,
  credit_amount DECIMAL(18,2) NOT NULL DEFAULT 0,
  description VARCHAR(500),
  partner_id BIGINT REFERENCES client_demo.partners(id),
  reconciliation_id BIGINT REFERENCES client_demo.reconciliation_groups(id),
  due_date DATE,
  cost_center_id BIGINT,
  project_id BIGINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  UNIQUE(journal_entry_id, line_number),
  CHECK ((debit_amount > 0 AND credit_amount = 0) OR (debit_amount = 0 AND credit_amount > 0))
);

CREATE INDEX idx_cd_jel_entry ON client_demo.journal_entry_lines(journal_entry_id);
CREATE INDEX idx_cd_jel_account ON client_demo.journal_entry_lines(account_id);
CREATE INDEX idx_cd_jel_partner ON client_demo.journal_entry_lines(partner_id);
CREATE INDEX idx_cd_jel_unreconciled ON client_demo.journal_entry_lines(account_id, partner_id) WHERE reconciliation_id IS NULL;
COMMENT ON TABLE client_demo.journal_entry_lines IS 'Lignes des écritures comptables';

-- FK différée bank_transactions → journal_entries
ALTER TABLE client_demo.bank_transactions
  ADD CONSTRAINT fk_cd_bank_trans_je FOREIGN KEY (journal_entry_id) REFERENCES client_demo.journal_entries(id);

-- FK différée fiscal_exercises → journal_entries
ALTER TABLE client_demo.fiscal_exercises
  ADD CONSTRAINT fk_exercise_opening_je FOREIGN KEY (opening_entry_id) REFERENCES client_demo.journal_entries(id),
  ADD CONSTRAINT fk_exercise_closing_je FOREIGN KEY (closing_entry_id) REFERENCES client_demo.journal_entries(id);

-- ────────────────────────────────────────────────────────────────────────────
-- 6. PAIE — PARAMÉTRAGE
-- RÈGLE NORMATIVE : les taux CNSS/CRF/CNAMGS ne sont JAMAIS codés en dur.
-- Lire depuis client_demo.contribution_rates (seed dans le script 06).
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE client_demo.payroll_rubrics (
  id BIGSERIAL PRIMARY KEY,
  code VARCHAR(10) NOT NULL UNIQUE,
  label VARCHAR(200) NOT NULL,
  rubric_type VARCHAR(30) NOT NULL CHECK (rubric_type IN (
    'EARNING', 'DEDUCTION_EMP', 'DEDUCTION_EMPR', 'TAX', 'REIMBURSEMENT', 'NET_DEDUCTION'
  )),
  rubric_category VARCHAR(30) NOT NULL CHECK (rubric_category IN (
    'BASE', 'OVERTIME', 'BONUS', 'BENEFIT', 'SOCIAL', 'RETIREMENT', 'TAX', 'OTHER'
  )),
  calc_mode VARCHAR(20) NOT NULL CHECK (calc_mode IN (
    'FIXED', 'RATE_ON_BASE', 'RATE_ON_GROSS', 'QUANTITY_RATE', 'FORMULA', 'MANUAL'
  )),
  default_base VARCHAR(50),
  default_rate DECIMAL(8,4),
  debit_account_id BIGINT REFERENCES client_demo.chart_of_accounts(id),
  credit_account_id BIGINT REFERENCES client_demo.chart_of_accounts(id),
  bulletin_section VARCHAR(30) CHECK (bulletin_section IN (
    'GROSS', 'EMPLOYEE_CONTRIB', 'EMPLOYER_CONTRIB', 'NET', 'INFORMATIONAL'
  )),
  display_order INT NOT NULL DEFAULT 0,
  print_on_bulletin BOOLEAN NOT NULL DEFAULT TRUE,
  effective_date DATE NOT NULL DEFAULT '2025-01-01',
  end_date DATE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT
);

COMMENT ON TABLE client_demo.payroll_rubrics IS 'Rubriques de paie — source de vérité pour les calculs de cotisations';

-- Barèmes de cotisations (taux CNSS/CRF/CNAMGS — seed dans le script 06)
CREATE TABLE client_demo.contribution_rates (
  id BIGSERIAL PRIMARY KEY,
  rubric_id BIGINT NOT NULL REFERENCES client_demo.payroll_rubrics(id),
  organism_code VARCHAR(30) NOT NULL,
  organism_label VARCHAR(200) NOT NULL,
  bracket_code VARCHAR(10) NOT NULL DEFAULT 'A',
  bracket_floor DECIMAL(18,2) NOT NULL DEFAULT 0,
  bracket_ceiling DECIMAL(18,2),
  employee_rate DECIMAL(8,5) NOT NULL DEFAULT 0,
  employer_rate DECIMAL(8,5) NOT NULL DEFAULT 0,
  applies_to VARCHAR(30) NOT NULL DEFAULT 'ALL' CHECK (applies_to IN (
    'ALL', 'CDI', 'CDD', 'CADRE', 'NON_CADRE', 'APPRENTICE', 'INTERN'
  )),
  effective_date DATE NOT NULL,
  end_date DATE,
  legal_reference VARCHAR(500),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  UNIQUE(rubric_id, bracket_code, applies_to, effective_date)
);

CREATE INDEX idx_contribution_rates_rubric ON client_demo.contribution_rates(rubric_id, effective_date);
CREATE INDEX idx_contribution_rates_date ON client_demo.contribution_rates(effective_date, end_date);
COMMENT ON TABLE client_demo.contribution_rates IS 'Taux de cotisations sociales par barème — jamais hardcodés dans les RPC';

-- ────────────────────────────────────────────────────────────────────────────
-- 7. PAIE — PÉRIODES ET EMPLOYÉS
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE client_demo.pay_periods (
  id BIGSERIAL PRIMARY KEY,
  fiscal_year INT NOT NULL,
  period_month INT NOT NULL CHECK (period_month BETWEEN 1 AND 13),
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  payment_date DATE,
  status VARCHAR(20) NOT NULL DEFAULT 'OPEN' CHECK (status IN (
    'OPEN', 'VARIABLES_CLOSED', 'CALCULATED', 'VALIDATED', 'PAID', 'CLOSED'
  )),
  fiscal_period_id BIGINT REFERENCES client_demo.fiscal_periods(id),
  total_employees INT,
  total_gross DECIMAL(18,2),
  total_net DECIMAL(18,2),
  total_employer DECIMAL(18,2),
  variable_deadline DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  UNIQUE(fiscal_year, period_month),
  CHECK (end_date > start_date)
);

COMMENT ON TABLE client_demo.pay_periods IS 'Périodes de paie avec workflow propre';

CREATE TABLE client_demo.employees (
  id BIGSERIAL PRIMARY KEY,
  employee_number VARCHAR(20) NOT NULL UNIQUE,
  partner_id BIGINT REFERENCES client_demo.partners(id),
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  birth_date DATE,
  social_security_number VARCHAR(20),
  hire_date DATE NOT NULL,
  termination_date DATE,
  contract_type VARCHAR(30) NOT NULL CHECK (contract_type IN ('CDI', 'CDD', 'INTERIM', 'APPRENTICE', 'INTERN', 'FREELANCE')),
  position VARCHAR(200),
  department VARCHAR(100),
  base_salary DECIMAL(18,2) NOT NULL,
  salary_type VARCHAR(20) NOT NULL CHECK (salary_type IN ('HOURLY', 'DAILY', 'MONTHLY', 'ANNUAL')),
  hours_per_week DECIMAL(5,2),
  bank_account_number VARCHAR(34),
  bank_name VARCHAR(200),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  deleted_at TIMESTAMPTZ,
  deleted_by BIGINT,
  version_number INT NOT NULL DEFAULT 1,
  CHECK (termination_date IS NULL OR termination_date >= hire_date)
);

CREATE INDEX idx_cd_employees_number ON client_demo.employees(employee_number) WHERE deleted_at IS NULL;
CREATE INDEX idx_cd_employees_active ON client_demo.employees(is_active);
COMMENT ON TABLE client_demo.employees IS 'Employés de l''entreprise';

CREATE TABLE client_demo.payslips (
  id BIGSERIAL PRIMARY KEY,
  employee_id BIGINT NOT NULL REFERENCES client_demo.employees(id),
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  payment_date DATE NOT NULL,
  gross_salary DECIMAL(18,2) NOT NULL,
  net_salary DECIMAL(18,2) NOT NULL,
  net_taxable DECIMAL(18,2) NOT NULL,
  employer_contributions DECIMAL(18,2) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'VALIDATED', 'PAID', 'CANCELLED')),
  validated_by BIGINT,
  validated_at TIMESTAMPTZ,
  journal_entry_id BIGINT REFERENCES client_demo.journal_entries(id),
  pay_period_id BIGINT REFERENCES client_demo.pay_periods(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  deleted_at TIMESTAMPTZ,
  deleted_by BIGINT,
  version_number INT NOT NULL DEFAULT 1,
  UNIQUE(employee_id, period_start, period_end),
  CHECK (period_end > period_start)
);

CREATE INDEX idx_cd_payslips_employee ON client_demo.payslips(employee_id, period_start DESC);
CREATE INDEX idx_cd_payslips_status ON client_demo.payslips(status);
COMMENT ON TABLE client_demo.payslips IS 'Bulletins de paie (workflow DRAFT→VALIDATED→PAID)';

CREATE TABLE client_demo.payslip_lines (
  id BIGSERIAL PRIMARY KEY,
  payslip_id BIGINT NOT NULL REFERENCES client_demo.payslips(id) ON DELETE CASCADE,
  line_type VARCHAR(30) NOT NULL CHECK (line_type IN ('SALARY', 'BONUS', 'DEDUCTION', 'EMPLOYER_CONTRIB', 'TAX', 'REIMBURSEMENT', 'NET')),
  code VARCHAR(20) NOT NULL,
  label VARCHAR(200) NOT NULL,
  base_amount DECIMAL(18,2),
  rate DECIMAL(8,4),
  employee_amount DECIMAL(18,2) NOT NULL DEFAULT 0,
  employer_amount DECIMAL(18,2) NOT NULL DEFAULT 0,
  line_order INT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0
);

CREATE INDEX idx_cd_payslip_lines_payslip ON client_demo.payslip_lines(payslip_id, line_order);
COMMENT ON TABLE client_demo.payslip_lines IS 'Lignes de détail des bulletins de paie';

-- Variables de paie mensuelles (heures sup, primes, absences)
CREATE TABLE client_demo.payroll_variables (
  id BIGSERIAL PRIMARY KEY,
  employee_id BIGINT NOT NULL REFERENCES client_demo.employees(id),
  pay_period_id BIGINT NOT NULL REFERENCES client_demo.pay_periods(id),
  rubric_id BIGINT NOT NULL REFERENCES client_demo.payroll_rubrics(id),
  quantity DECIMAL(10,2),
  amount DECIMAL(18,2),
  rate_override DECIMAL(8,4),
  comment TEXT,
  status VARCHAR(20) NOT NULL DEFAULT 'DRAFT' CHECK (status IN (
    'DRAFT', 'SUBMITTED', 'VALIDATED', 'REJECTED', 'INTEGRATED'
  )),
  submitted_by BIGINT,
  submitted_at TIMESTAMPTZ,
  validated_by BIGINT,
  validated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  UNIQUE(employee_id, pay_period_id, rubric_id)
);

CREATE INDEX idx_payroll_vars_emp_period ON client_demo.payroll_variables(employee_id, pay_period_id);
CREATE INDEX idx_payroll_vars_status ON client_demo.payroll_variables(status);
COMMENT ON TABLE client_demo.payroll_variables IS 'Variables de paie mensuelles (HS, primes, absences)';

-- Types d''absences
CREATE TABLE client_demo.absence_types (
  id BIGSERIAL PRIMARY KEY,
  code VARCHAR(10) NOT NULL UNIQUE,
  label VARCHAR(100) NOT NULL,
  is_paid BOOLEAN NOT NULL DEFAULT TRUE,
  deduction_method VARCHAR(30) CHECK (deduction_method IN ('NONE', 'CALENDAR_DAYS', 'WORKING_DAYS', 'HOURLY')),
  waiting_days INT NOT NULL DEFAULT 0,
  accrual_per_month DECIMAL(5,2) DEFAULT 0,
  max_balance DECIMAL(5,2),
  rubric_id BIGINT REFERENCES client_demo.payroll_rubrics(id),
  requires_justification BOOLEAN NOT NULL DEFAULT FALSE,
  requires_approval BOOLEAN NOT NULL DEFAULT TRUE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0
);

COMMENT ON TABLE client_demo.absence_types IS 'Types d''absences (CP, RTT, maladie, etc.)';

CREATE TABLE client_demo.absences (
  id BIGSERIAL PRIMARY KEY,
  employee_id BIGINT NOT NULL REFERENCES client_demo.employees(id),
  absence_type_id BIGINT NOT NULL REFERENCES client_demo.absence_types(id),
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  days_count DECIMAL(5,2) NOT NULL,
  reason TEXT,
  justification_file VARCHAR(500),
  status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED')),
  approved_by BIGINT,
  approved_at TIMESTAMPTZ,
  rejection_reason TEXT,
  pay_period_id BIGINT REFERENCES client_demo.pay_periods(id),
  payroll_integrated BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  CHECK (end_date >= start_date),
  CHECK (days_count > 0)
);

CREATE INDEX idx_absences_emp ON client_demo.absences(employee_id, start_date);
CREATE INDEX idx_absences_status ON client_demo.absences(status);
COMMENT ON TABLE client_demo.absences IS 'Absences par employé avec workflow d''approbation';

CREATE TABLE client_demo.leave_balances (
  id BIGSERIAL PRIMARY KEY,
  employee_id BIGINT NOT NULL REFERENCES client_demo.employees(id),
  absence_type_id BIGINT NOT NULL REFERENCES client_demo.absence_types(id),
  fiscal_year INT NOT NULL,
  acquired DECIMAL(6,2) NOT NULL DEFAULT 0,
  taken DECIMAL(6,2) NOT NULL DEFAULT 0,
  adjustment DECIMAL(6,2) NOT NULL DEFAULT 0,
  remaining DECIMAL(6,2) GENERATED ALWAYS AS (acquired - taken + adjustment) STORED,
  carried_over DECIMAL(6,2) NOT NULL DEFAULT 0,
  last_accrual_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  UNIQUE(employee_id, absence_type_id, fiscal_year)
);

CREATE INDEX idx_leave_balances_emp ON client_demo.leave_balances(employee_id, fiscal_year);
COMMENT ON TABLE client_demo.leave_balances IS 'Compteurs de congés par employé et type';

CREATE TABLE client_demo.payroll_cumuls (
  id BIGSERIAL PRIMARY KEY,
  employee_id BIGINT NOT NULL REFERENCES client_demo.employees(id),
  fiscal_year INT NOT NULL,
  period_month INT NOT NULL CHECK (period_month BETWEEN 1 AND 13),
  cum_gross DECIMAL(18,2) NOT NULL DEFAULT 0,
  cum_base_salary DECIMAL(18,2) NOT NULL DEFAULT 0,
  cum_overtime DECIMAL(18,2) NOT NULL DEFAULT 0,
  cum_bonuses DECIMAL(18,2) NOT NULL DEFAULT 0,
  cum_benefits DECIMAL(18,2) NOT NULL DEFAULT 0,
  cum_employee_contrib DECIMAL(18,2) NOT NULL DEFAULT 0,
  cum_employer_contrib DECIMAL(18,2) NOT NULL DEFAULT 0,
  cum_net_taxable DECIMAL(18,2) NOT NULL DEFAULT 0,
  cum_net_paid DECIMAL(18,2) NOT NULL DEFAULT 0,
  cum_tax_withheld DECIMAL(18,2) NOT NULL DEFAULT 0,
  cum_bracket_a DECIMAL(18,2) NOT NULL DEFAULT 0,
  cum_bracket_b DECIMAL(18,2) NOT NULL DEFAULT 0,
  cum_worked_days DECIMAL(6,2) NOT NULL DEFAULT 0,
  cum_absence_days DECIMAL(6,2) NOT NULL DEFAULT 0,
  cum_overtime_hours DECIMAL(8,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  UNIQUE(employee_id, fiscal_year, period_month)
);

CREATE INDEX idx_payroll_cumuls_emp_year ON client_demo.payroll_cumuls(employee_id, fiscal_year);
COMMENT ON TABLE client_demo.payroll_cumuls IS 'Cumuls annuels de paie (tranches, DSN)';

-- ────────────────────────────────────────────────────────────────────────────
-- 8. IMMOBILISATIONS
-- RÈGLE NORMATIVE : les coefficients d''amortissement (1.25/1.75/2.25) ne
-- sont JAMAIS codés en dur. Lire depuis client_demo.asset_categories.
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE client_demo.asset_categories (
  id BIGSERIAL PRIMARY KEY,
  code VARCHAR(20) NOT NULL UNIQUE,
  label VARCHAR(200) NOT NULL,
  default_method VARCHAR(30) NOT NULL DEFAULT 'LINEAR' CHECK (
    default_method IN ('LINEAR', 'DECLINING', 'EXCEPTIONAL', 'NONE')
  ),
  default_useful_life_months INT NOT NULL,
  default_residual_pct DECIMAL(5,2) NOT NULL DEFAULT 0,
  -- Coefficients dégressifs OHADA (lus ici, jamais hardcodés dans les RPC)
  declining_coeff_short DECIMAL(4,2) DEFAULT 1.25,   -- Durée 3-4 ans
  declining_coeff_medium DECIMAL(4,2) DEFAULT 1.75,  -- Durée 5-6 ans
  declining_coeff_long DECIMAL(4,2) DEFAULT 2.25,    -- Durée > 6 ans
  -- Comptes OHADA par défaut pour cette catégorie
  asset_account_id BIGINT REFERENCES client_demo.chart_of_accounts(id),
  depreciation_account_id BIGINT REFERENCES client_demo.chart_of_accounts(id),
  expense_account_id BIGINT REFERENCES client_demo.chart_of_accounts(id),
  disposal_income_account_id BIGINT REFERENCES client_demo.chart_of_accounts(id),
  disposal_expense_account_id BIGINT REFERENCES client_demo.chart_of_accounts(id),
  min_capitalization_amount DECIMAL(18,2) NOT NULL DEFAULT 500,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT
);

COMMENT ON TABLE client_demo.asset_categories IS 'Catégories d''immobilisations avec paramètres d''amortissement';

CREATE TABLE client_demo.fixed_assets (
  id BIGSERIAL PRIMARY KEY,
  asset_number VARCHAR(20) NOT NULL UNIQUE,
  asset_name VARCHAR(200) NOT NULL,
  category_id BIGINT REFERENCES client_demo.asset_categories(id),
  category VARCHAR(100),
  acquisition_date DATE NOT NULL,
  acquisition_value DECIMAL(18,2) NOT NULL,
  supplier_id BIGINT REFERENCES client_demo.partners(id),
  depreciation_method VARCHAR(30) NOT NULL CHECK (depreciation_method IN ('LINEAR', 'DECLINING', 'EXCEPTIONAL', 'NONE')),
  useful_life_years INT,
  useful_life_months INT,
  residual_value DECIMAL(18,2) DEFAULT 0,
  accumulated_depreciation DECIMAL(18,2) NOT NULL DEFAULT 0,
  net_book_value DECIMAL(18,2) NOT NULL,
  disposal_date DATE,
  disposal_value DECIMAL(18,2),
  disposal_type VARCHAR(30) CHECK (disposal_type IN ('SALE', 'SCRAP', 'DONATION', 'LOSS')),
  asset_account_id BIGINT NOT NULL REFERENCES client_demo.chart_of_accounts(id),
  depreciation_account_id BIGINT REFERENCES client_demo.chart_of_accounts(id),
  expense_account_id BIGINT REFERENCES client_demo.chart_of_accounts(id),
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'DISPOSED', 'SCRAPPED')),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  deleted_at TIMESTAMPTZ,
  deleted_by BIGINT,
  version_number INT NOT NULL DEFAULT 1,
  CHECK (disposal_date IS NULL OR disposal_date >= acquisition_date)
);

CREATE INDEX idx_cd_fixed_assets_number ON client_demo.fixed_assets(asset_number) WHERE deleted_at IS NULL;
CREATE INDEX idx_cd_fixed_assets_status ON client_demo.fixed_assets(status);
CREATE INDEX idx_cd_fixed_assets_category ON client_demo.fixed_assets(category_id);
COMMENT ON TABLE client_demo.fixed_assets IS 'Immobilisations (workflow ACTIVE→DISPOSED/SCRAPPED)';

CREATE TABLE client_demo.depreciation_schedule (
  id BIGSERIAL PRIMARY KEY,
  fixed_asset_id BIGINT NOT NULL REFERENCES client_demo.fixed_assets(id) ON DELETE CASCADE,
  fiscal_period_id BIGINT NOT NULL REFERENCES client_demo.fiscal_periods(id),
  depreciation_date DATE NOT NULL,
  depreciation_amount DECIMAL(18,2) NOT NULL,
  accumulated_depreciation DECIMAL(18,2) NOT NULL,
  net_book_value DECIMAL(18,2) NOT NULL,
  journal_entry_id BIGINT REFERENCES client_demo.journal_entries(id),
  status VARCHAR(20) NOT NULL DEFAULT 'PLANNED' CHECK (status IN ('PLANNED', 'POSTED', 'CANCELLED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  UNIQUE(fixed_asset_id, fiscal_period_id)
);

CREATE INDEX idx_cd_depreciation_asset ON client_demo.depreciation_schedule(fixed_asset_id, depreciation_date);
COMMENT ON TABLE client_demo.depreciation_schedule IS 'Plan d''amortissement des immobilisations';

-- ────────────────────────────────────────────────────────────────────────────
-- 9. TRÉSORERIE
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE client_demo.cash_flow_forecast (
  id BIGSERIAL PRIMARY KEY,
  forecast_date DATE NOT NULL,
  forecast_type VARCHAR(20) NOT NULL CHECK (forecast_type IN ('RECEIPT', 'PAYMENT')),
  category VARCHAR(100) NOT NULL,
  amount DECIMAL(18,2) NOT NULL,
  description VARCHAR(500),
  probability DECIMAL(5,2) DEFAULT 100 CHECK (probability >= 0 AND probability <= 100),
  partner_id BIGINT REFERENCES client_demo.partners(id),
  invoice_id BIGINT,
  is_actual BOOLEAN NOT NULL DEFAULT FALSE,
  actual_date DATE,
  actual_amount DECIMAL(18,2),
  bank_account_id BIGINT REFERENCES client_demo.bank_accounts(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT
);

CREATE INDEX idx_cd_cash_forecast_date ON client_demo.cash_flow_forecast(forecast_date);
CREATE INDEX idx_cd_cash_forecast_type ON client_demo.cash_flow_forecast(forecast_type, is_actual);
COMMENT ON TABLE client_demo.cash_flow_forecast IS 'Prévisions de trésorerie';

CREATE TABLE client_demo.cash_positions (
  id BIGSERIAL PRIMARY KEY,
  position_date DATE NOT NULL UNIQUE,
  total_cash DECIMAL(18,2) NOT NULL,
  bank_balance DECIMAL(18,2) NOT NULL,
  petty_cash DECIMAL(18,2) NOT NULL DEFAULT 0,
  short_term_investments DECIMAL(18,2) NOT NULL DEFAULT 0,
  receivables_due DECIMAL(18,2) NOT NULL DEFAULT 0,
  payables_due DECIMAL(18,2) NOT NULL DEFAULT 0,
  net_position DECIMAL(18,2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0
);

CREATE INDEX idx_cd_cash_positions_date ON client_demo.cash_positions(position_date DESC);
COMMENT ON TABLE client_demo.cash_positions IS 'Snapshots quotidiens de la position de trésorerie';

-- ────────────────────────────────────────────────────────────────────────────
-- 10. LIASSE FISCALE
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE client_demo.tax_returns (
  id BIGSERIAL PRIMARY KEY,
  fiscal_year INT NOT NULL,
  return_type VARCHAR(50) NOT NULL,
  period_start DATE,
  period_end DATE,
  filing_date DATE,
  due_date DATE,
  status VARCHAR(20) NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'FILED', 'ACCEPTED', 'REJECTED', 'AMENDED')),
  filing_method VARCHAR(30) CHECK (filing_method IN ('PAPER', 'EDI_TDFC', 'PORTAL')),
  acknowledgment_number VARCHAR(100),
  filed_by BIGINT,
  filed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  UNIQUE(fiscal_year, return_type)
);

CREATE INDEX idx_cd_tax_returns_year ON client_demo.tax_returns(fiscal_year);
COMMENT ON TABLE client_demo.tax_returns IS 'Déclarations fiscales (TVA, IS, etc.)';

CREATE TABLE client_demo.tax_return_data (
  id BIGSERIAL PRIMARY KEY,
  tax_return_id BIGINT NOT NULL REFERENCES client_demo.tax_returns(id) ON DELETE CASCADE,
  form_code VARCHAR(20) NOT NULL DEFAULT 'CA3',
  field_code VARCHAR(50) NOT NULL,
  field_label VARCHAR(200),
  field_value DECIMAL(18,2),
  field_text VARCHAR(500),
  field_type VARCHAR(20) NOT NULL DEFAULT 'AMOUNT' CHECK (field_type IN ('AMOUNT', 'QUANTITY', 'RATE', 'TEXT', 'DATE', 'BOOLEAN')),
  calculation_formula TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  UNIQUE(tax_return_id, form_code, field_code)
);

COMMENT ON TABLE client_demo.tax_return_data IS 'Données détaillées des déclarations fiscales';

-- ────────────────────────────────────────────────────────────────────────────
-- 11. VUES MÉTIER
-- ────────────────────────────────────────────────────────────────────────────

CREATE VIEW client_demo.v_general_ledger AS
SELECT
  coa.account_number, coa.account_label, coa.account_type,
  fp.fiscal_year, fp.period_number,
  SUM(jel.debit_amount) AS total_debit,
  SUM(jel.credit_amount) AS total_credit,
  SUM(jel.debit_amount) - SUM(jel.credit_amount) AS balance
FROM client_demo.journal_entry_lines jel
JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
JOIN client_demo.chart_of_accounts coa ON coa.id = jel.account_id
JOIN client_demo.fiscal_periods fp ON fp.id = je.fiscal_period_id
WHERE je.status IN ('POSTED', 'VALIDATED') AND je.deleted_at IS NULL
GROUP BY coa.account_number, coa.account_label, coa.account_type, fp.fiscal_year, fp.period_number;

COMMENT ON VIEW client_demo.v_general_ledger IS 'Balance générale par compte et période';

CREATE VIEW client_demo.v_aged_receivables AS
SELECT
  p.id AS partner_id, p.code AS partner_code, p.name AS partner_name,
  jel.due_date,
  CURRENT_DATE - jel.due_date AS days_overdue,
  CASE
    WHEN jel.due_date >= CURRENT_DATE THEN 'CURRENT'
    WHEN CURRENT_DATE - jel.due_date <= 30 THEN '1_30_DAYS'
    WHEN CURRENT_DATE - jel.due_date <= 60 THEN '31_60_DAYS'
    WHEN CURRENT_DATE - jel.due_date <= 90 THEN '61_90_DAYS'
    ELSE 'OVER_90_DAYS'
  END AS aging_bucket,
  SUM(jel.debit_amount - jel.credit_amount) AS amount_due
FROM client_demo.journal_entry_lines jel
JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
JOIN client_demo.partners p ON p.id = jel.partner_id
JOIN client_demo.chart_of_accounts coa ON coa.id = jel.account_id
WHERE coa.account_number LIKE '411%'
  AND jel.reconciliation_id IS NULL
  AND je.status IN ('POSTED', 'VALIDATED') AND je.deleted_at IS NULL
GROUP BY p.id, p.code, p.name, jel.due_date
HAVING SUM(jel.debit_amount - jel.credit_amount) > 0;

COMMENT ON VIEW client_demo.v_aged_receivables IS 'Balance âgée des créances clients';

CREATE VIEW client_demo.v_aged_payables AS
SELECT
  p.id AS partner_id, p.code AS partner_code, p.name AS partner_name,
  jel.due_date,
  CURRENT_DATE - jel.due_date AS days_overdue,
  CASE
    WHEN jel.due_date >= CURRENT_DATE THEN 'CURRENT'
    WHEN CURRENT_DATE - jel.due_date <= 30 THEN '1_30_DAYS'
    WHEN CURRENT_DATE - jel.due_date <= 60 THEN '31_60_DAYS'
    WHEN CURRENT_DATE - jel.due_date <= 90 THEN '61_90_DAYS'
    ELSE 'OVER_90_DAYS'
  END AS aging_bucket,
  SUM(jel.credit_amount - jel.debit_amount) AS amount_due
FROM client_demo.journal_entry_lines jel
JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
JOIN client_demo.partners p ON p.id = jel.partner_id
JOIN client_demo.chart_of_accounts coa ON coa.id = jel.account_id
WHERE coa.account_number LIKE '401%'
  AND jel.reconciliation_id IS NULL
  AND je.status IN ('POSTED', 'VALIDATED') AND je.deleted_at IS NULL
GROUP BY p.id, p.code, p.name, jel.due_date
HAVING SUM(jel.credit_amount - jel.debit_amount) > 0;

COMMENT ON VIEW client_demo.v_aged_payables IS 'Balance âgée des dettes fournisseurs';

CREATE VIEW client_demo.v_income_statement AS
SELECT
  fp.fiscal_year,
  CASE
    WHEN coa.account_number LIKE '7%' THEN 'REVENUE'
    WHEN coa.account_number LIKE '6%' THEN 'EXPENSE'
    ELSE 'OTHER'
  END AS category,
  SUBSTRING(coa.account_number, 1, 2) AS account_class,
  SUM(CASE WHEN coa.account_type = 'REVENUE' THEN jel.credit_amount ELSE 0 END) AS revenue,
  SUM(CASE WHEN coa.account_type = 'EXPENSE' THEN jel.debit_amount ELSE 0 END) AS expense
FROM client_demo.journal_entry_lines jel
JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
JOIN client_demo.chart_of_accounts coa ON coa.id = jel.account_id
JOIN client_demo.fiscal_periods fp ON fp.id = je.fiscal_period_id
WHERE je.status IN ('POSTED', 'VALIDATED') AND je.deleted_at IS NULL
  AND coa.account_type IN ('REVENUE', 'EXPENSE')
GROUP BY fp.fiscal_year, category, account_class;

COMMENT ON VIEW client_demo.v_income_statement IS 'Compte de résultat simplifié';

CREATE VIEW client_demo.v_cash_forecast_summary AS
SELECT
  forecast_date,
  SUM(CASE WHEN forecast_type = 'RECEIPT' THEN amount ELSE 0 END) AS total_receipts,
  SUM(CASE WHEN forecast_type = 'PAYMENT' THEN amount ELSE 0 END) AS total_payments,
  SUM(CASE WHEN forecast_type = 'RECEIPT' THEN amount ELSE -amount END) AS net_flow,
  SUM(SUM(CASE WHEN forecast_type = 'RECEIPT' THEN amount ELSE -amount END))
    OVER (ORDER BY forecast_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_balance
FROM client_demo.cash_flow_forecast
WHERE is_actual = FALSE
GROUP BY forecast_date
ORDER BY forecast_date;

COMMENT ON VIEW client_demo.v_cash_forecast_summary IS 'Synthèse des prévisions de trésorerie';

-- ────────────────────────────────────────────────────────────────────────────
-- 12. FONCTIONS MÉTIER
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION client_demo.get_account_balance(
  p_account_id BIGINT,
  p_end_date DATE DEFAULT CURRENT_DATE
) RETURNS DECIMAL(18,2) AS $$
DECLARE v_balance DECIMAL(18,2);
BEGIN
  SELECT COALESCE(SUM(jel.debit_amount - jel.credit_amount), 0) INTO v_balance
  FROM client_demo.journal_entry_lines jel
  JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
  WHERE jel.account_id = p_account_id
    AND je.entry_date <= p_end_date
    AND je.status IN ('POSTED', 'VALIDATED') AND je.deleted_at IS NULL;
  RETURN v_balance;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION client_demo.calculate_dso(
  p_fiscal_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INT
) RETURNS DECIMAL(10,2) AS $$
DECLARE
  v_receivables DECIMAL(18,2);
  v_revenue DECIMAL(18,2);
BEGIN
  SELECT AVG(balance) INTO v_receivables FROM (
    SELECT SUM(jel.debit_amount - jel.credit_amount) AS balance
    FROM client_demo.journal_entry_lines jel
    JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
    JOIN client_demo.chart_of_accounts coa ON coa.id = jel.account_id
    JOIN client_demo.fiscal_periods fp ON fp.id = je.fiscal_period_id
    WHERE coa.account_number LIKE '411%' AND fp.fiscal_year = p_fiscal_year
      AND je.status IN ('POSTED', 'VALIDATED') AND je.deleted_at IS NULL
    GROUP BY fp.period_number
  ) AS monthly_balances;

  SELECT SUM(jel.credit_amount) INTO v_revenue
  FROM client_demo.journal_entry_lines jel
  JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
  JOIN client_demo.chart_of_accounts coa ON coa.id = jel.account_id
  JOIN client_demo.fiscal_periods fp ON fp.id = je.fiscal_period_id
  WHERE coa.account_number LIKE '7%' AND fp.fiscal_year = p_fiscal_year
    AND je.status IN ('POSTED', 'VALIDATED') AND je.deleted_at IS NULL;

  IF COALESCE(v_revenue, 0) > 0 THEN RETURN (v_receivables / v_revenue) * 360;
  ELSE RETURN 0; END IF;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION client_demo.calculate_dpo(
  p_fiscal_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INT
) RETURNS DECIMAL(10,2) AS $$
DECLARE
  v_payables DECIMAL(18,2);
  v_purchases DECIMAL(18,2);
BEGIN
  SELECT AVG(balance) INTO v_payables FROM (
    SELECT SUM(jel.credit_amount - jel.debit_amount) AS balance
    FROM client_demo.journal_entry_lines jel
    JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
    JOIN client_demo.chart_of_accounts coa ON coa.id = jel.account_id
    JOIN client_demo.fiscal_periods fp ON fp.id = je.fiscal_period_id
    WHERE coa.account_number LIKE '401%' AND fp.fiscal_year = p_fiscal_year
      AND je.status IN ('POSTED', 'VALIDATED') AND je.deleted_at IS NULL
    GROUP BY fp.period_number
  ) AS monthly_balances;

  SELECT SUM(jel.debit_amount) INTO v_purchases
  FROM client_demo.journal_entry_lines jel
  JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
  JOIN client_demo.chart_of_accounts coa ON coa.id = jel.account_id
  JOIN client_demo.fiscal_periods fp ON fp.id = je.fiscal_period_id
  WHERE coa.account_number LIKE '6%' AND fp.fiscal_year = p_fiscal_year
    AND je.status IN ('POSTED', 'VALIDATED') AND je.deleted_at IS NULL;

  IF COALESCE(v_purchases, 0) > 0 THEN RETURN (v_payables / v_purchases) * 360;
  ELSE RETURN 0; END IF;
END;
$$ LANGUAGE plpgsql STABLE;

-- ────────────────────────────────────────────────────────────────────────────
-- 13. TRIGGERS
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION client_demo.update_journal_entry_totals()
RETURNS TRIGGER AS $$
BEGIN
  -- Un UPDATE qui ne touche NI les montants NI le rattachement de ligne (ex. le
  -- lettrage, qui ne fait que renseigner reconciliation_id) n'a pas à recalculer
  -- les totaux. Sans ce court-circuit, l'UPDATE du parent se déclencherait aussi
  -- sur une écriture POSTED et serait bloqué par le garde d'immuabilité, rendant
  -- impossible le lettrage d'écritures validées (cas d'usage normal).
  IF TG_OP = 'UPDATE'
     AND NEW.debit_amount     IS NOT DISTINCT FROM OLD.debit_amount
     AND NEW.credit_amount    IS NOT DISTINCT FROM OLD.credit_amount
     AND NEW.journal_entry_id IS NOT DISTINCT FROM OLD.journal_entry_id THEN
    RETURN NEW;
  END IF;

  UPDATE client_demo.journal_entries
  SET
    total_debit  = (SELECT COALESCE(SUM(debit_amount), 0)  FROM client_demo.journal_entry_lines WHERE journal_entry_id = COALESCE(NEW.journal_entry_id, OLD.journal_entry_id)),
    total_credit = (SELECT COALESCE(SUM(credit_amount), 0) FROM client_demo.journal_entry_lines WHERE journal_entry_id = COALESCE(NEW.journal_entry_id, OLD.journal_entry_id)),
    updated_at = NOW()
  WHERE id = COALESCE(NEW.journal_entry_id, OLD.journal_entry_id);
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_cd_update_je_totals
AFTER INSERT OR UPDATE OR DELETE ON client_demo.journal_entry_lines
FOR EACH ROW EXECUTE FUNCTION client_demo.update_journal_entry_totals();

CREATE OR REPLACE FUNCTION client_demo.update_bank_account_balance()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE client_demo.bank_accounts SET current_balance = current_balance + NEW.amount, updated_at = NOW()
    WHERE id = NEW.bank_account_id;
  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE client_demo.bank_accounts SET current_balance = current_balance - OLD.amount + NEW.amount, updated_at = NOW()
    WHERE id = NEW.bank_account_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE client_demo.bank_accounts SET current_balance = current_balance - OLD.amount, updated_at = NOW()
    WHERE id = OLD.bank_account_id;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_cd_update_bank_balance
AFTER INSERT OR UPDATE OR DELETE ON client_demo.bank_transactions
FOR EACH ROW EXECUTE FUNCTION client_demo.update_bank_account_balance();

-- Protège les écritures POSTED contre toute modification (workflow irréversible)
CREATE OR REPLACE FUNCTION client_demo.prevent_posted_entry_modification()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.status = 'POSTED' AND TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'Impossible de modifier une écriture POSTED — créer une contre-passation';
  END IF;
  IF OLD.status IN ('POSTED', 'VALIDATED') AND TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Impossible de supprimer une écriture validée';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_cd_prevent_posted_modification
BEFORE UPDATE OR DELETE ON client_demo.journal_entries
FOR EACH ROW EXECUTE FUNCTION client_demo.prevent_posted_entry_modification();

-- ────────────────────────────────────────────────────────────────────────────
-- 14. ACTIVATION ROW LEVEL SECURITY
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE client_demo.journal_entries     ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_demo.journal_entry_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_demo.partners            ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_demo.bank_accounts       ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_demo.bank_transactions   ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_demo.employees           ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_demo.payslips            ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_demo.payslip_lines       ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_demo.fixed_assets        ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_demo.payroll_rubrics     ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_demo.contribution_rates  ENABLE ROW LEVEL SECURITY;

-- ────────────────────────────────────────────────────────────────────────────
-- 15. DONNÉES INITIALES
-- ────────────────────────────────────────────────────────────────────────────

-- Données de démonstration (exercices 2025/2026, périodes, journaux) déplacées
-- vers 03b-client-seed.sql — voir manifeste. Les tests pgTAP tournent sans ce
-- seed (ils fournissent leurs propres fixtures).
-- ROLLBACK : réintégrer le bloc « DONNÉES INITIALES » depuis 03b-client-seed.sql.

-- ────────────────────────────────────────────────────────────────────────────
-- PERMISSIONS SUPABASE
-- ────────────────────────────────────────────────────────────────────────────

GRANT USAGE ON SCHEMA client_demo TO authenticated;
GRANT USAGE ON SCHEMA client_demo TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA client_demo TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA client_demo TO service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA client_demo TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA client_demo TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA client_demo TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA client_demo TO service_role;

-- ============================================================================
DO $$ BEGIN RAISE NOTICE '✅ Script 03 OK — Tables métier JASPE créées';
END $$;
