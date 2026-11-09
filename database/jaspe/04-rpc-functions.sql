-- ============================================================================
-- EDENFIN JASPE — SCRIPT 04 : FONCTIONS RPC MÉTIER (T1→T17)
-- À exécuter APRÈS le script 03
-- Source consolidée : 06_rpc_business_functions.sql (archive)
--
-- CORRECTIONS NORMATIVES APPLIQUÉES (NOYAU-NORMATIF §1, §5) :
--   • T5  : taux cotisations (CNSS/CRF/CNAMGS) lus depuis contribution_rates
--   • T5  : IRPP lu depuis common.tax_codes (code='IRPP_GA_STD')
--   • T10 : taux TVA lu depuis common.tax_codes (type='VAT', country='GA')
--   • Tous : colonnes audit_log corrigées (entity_type / entity_id / new_values)
--   • T10 : colonnes notifications corrigées (notification_type / category)
--   • T10 : colonne tax_return_data corrigée (field_value, fiscal_year)
--   • T15 : colonne asset_name corrigée
--   • T3  : lettrage reécrit pour reconciliation_groups
-- ============================================================================

-- ────────────────────────────────────────────────────────────────────────────
-- T1 — SAISIE COMPTABLE : créer une écriture avec ses lignes
-- RG01 : Débit = Crédit obligatoire
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION client_demo.rpc_create_journal_entry(
  p_journal_id  BIGINT,
  p_entry_date  DATE,
  p_description TEXT,
  p_reference   TEXT     DEFAULT NULL,
  p_lines       JSONB    DEFAULT '[]'::JSONB,
  p_user_id     BIGINT   DEFAULT 1
)
RETURNS JSONB AS $$
DECLARE
  v_entry_id     BIGINT;
  v_entry_number TEXT;
  v_period_id    BIGINT;
  v_total_debit  DECIMAL(18,2) := 0;
  v_total_credit DECIMAL(18,2) := 0;
  v_line         JSONB;
  v_journal      RECORD;
  v_seq          INT;
  v_lnum         INT := 1;
BEGIN
  SELECT * INTO v_journal FROM client_demo.journals WHERE id = p_journal_id AND is_active = TRUE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Journal introuvable ou inactif');
  END IF;

  SELECT id INTO v_period_id FROM client_demo.fiscal_periods
  WHERE p_entry_date BETWEEN start_date AND end_date AND status = 'OPEN' LIMIT 1;
  IF v_period_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error',
      'Aucune période fiscale ouverte pour la date ' || p_entry_date::TEXT);
  END IF;

  FOR v_line IN SELECT * FROM jsonb_array_elements(p_lines) LOOP
    v_total_debit  := v_total_debit  + COALESCE((v_line->>'debit')::DECIMAL, 0);
    v_total_credit := v_total_credit + COALESCE((v_line->>'credit')::DECIMAL, 0);
  END LOOP;

  IF v_total_debit != v_total_credit THEN
    RETURN jsonb_build_object('success', false, 'error',
      format('Écriture déséquilibrée: Débit=%s ≠ Crédit=%s', v_total_debit, v_total_credit));
  END IF;
  IF v_total_debit = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Écriture vide (montants = 0)');
  END IF;

  SELECT COALESCE(MAX(
    CASE WHEN entry_number ~ (v_journal.code || '-[0-9]+')
         THEN SUBSTRING(entry_number FROM '[0-9]+$')::INT ELSE 0 END
  ), 0) + 1 INTO v_seq
  FROM client_demo.journal_entries WHERE journal_id = p_journal_id;

  v_entry_number := v_journal.code || '-' || LPAD(v_seq::TEXT, 6, '0');

  INSERT INTO client_demo.journal_entries (
    journal_id, fiscal_period_id, entry_number, entry_date, posting_date,
    description, reference, status, total_debit, total_credit, created_by
  ) VALUES (
    p_journal_id, v_period_id, v_entry_number, p_entry_date, p_entry_date,
    p_description, p_reference, 'DRAFT', v_total_debit, v_total_credit, p_user_id
  ) RETURNING id INTO v_entry_id;

  FOR v_line IN SELECT * FROM jsonb_array_elements(p_lines) LOOP
    INSERT INTO client_demo.journal_entry_lines (
      journal_entry_id, line_number, account_id, description,
      debit_amount, credit_amount, partner_id, created_by
    ) VALUES (
      v_entry_id, v_lnum,
      (v_line->>'account_id')::BIGINT,
      COALESCE(v_line->>'description', p_description),
      COALESCE((v_line->>'debit')::DECIMAL, 0),
      COALESCE((v_line->>'credit')::DECIMAL, 0),
      (v_line->>'partner_id')::BIGINT,
      p_user_id
    );
    v_lnum := v_lnum + 1;
  END LOOP;

  INSERT INTO sys.audit_log (tenant_id, user_id, action, entity_type, entity_id, new_values)
  VALUES (
    (SELECT id FROM sys.tenants LIMIT 1), p_user_id, 'CREATE',
    'journal_entries', v_entry_id,
    jsonb_build_object('entry_number', v_entry_number, 'total', v_total_debit)
  );

  RETURN jsonb_build_object(
    'success', true,
    'entry_id', v_entry_id,
    'entry_number', v_entry_number,
    'total_debit', v_total_debit,
    'total_credit', v_total_credit,
    'lines_count', jsonb_array_length(p_lines)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION client_demo.rpc_create_journal_entry IS
'MCT T1 — Saisie comptable : crée une écriture équilibrée avec lignes. RG01 contrôlé.';


-- ────────────────────────────────────────────────────────────────────────────
-- T1b — VALIDATION D'ÉCRITURE : DRAFT → POSTED (irréversible)
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION client_demo.rpc_validate_journal_entry(
  p_entry_id BIGINT,
  p_user_id  BIGINT DEFAULT 1
)
RETURNS JSONB AS $$
DECLARE v_entry RECORD;
BEGIN
  SELECT * INTO v_entry FROM client_demo.journal_entries WHERE id = p_entry_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Écriture introuvable');
  END IF;
  IF v_entry.status != 'DRAFT' THEN
    RETURN jsonb_build_object('success', false, 'error',
      'Seules les écritures DRAFT peuvent être validées (statut: ' || v_entry.status || ')');
  END IF;
  IF v_entry.total_debit != v_entry.total_credit THEN
    RETURN jsonb_build_object('success', false, 'error', 'Écriture déséquilibrée');
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM client_demo.fiscal_periods WHERE id = v_entry.fiscal_period_id AND status = 'OPEN'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Période fiscale fermée');
  END IF;

  UPDATE client_demo.journal_entries
  SET status = 'POSTED', validated_at = NOW(), validated_by = p_user_id, updated_at = NOW()
  WHERE id = p_entry_id;

  RETURN jsonb_build_object('success', true, 'entry_number', v_entry.entry_number, 'status', 'POSTED');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION client_demo.rpc_validate_journal_entry IS
'MCT T1b — Validation : DRAFT → POSTED. Irréversible (NOYAU-NORMATIF §3).';


-- ────────────────────────────────────────────────────────────────────────────
-- T2 — RAPPROCHEMENT BANCAIRE AUTOMATIQUE
-- Matching par montant exact + fenêtre de date
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION client_demo.rpc_auto_reconcile_bank(
  p_bank_account_id BIGINT,
  p_tolerance_days  INT    DEFAULT 3,
  p_user_id         BIGINT DEFAULT 1
)
RETURNS JSONB AS $$
DECLARE
  v_txn          RECORD;
  v_match        RECORD;
  v_matched      INT := 0;
  v_total        INT := 0;
  v_bank_account RECORD;
BEGIN
  SELECT * INTO v_bank_account FROM client_demo.bank_accounts WHERE id = p_bank_account_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Compte bancaire introuvable');
  END IF;

  FOR v_txn IN
    SELECT bt.*
    FROM client_demo.bank_transactions bt
    WHERE bt.bank_account_id = p_bank_account_id AND bt.is_reconciled = FALSE
    ORDER BY bt.transaction_date
  LOOP
    v_total := v_total + 1;

    SELECT jel.id AS line_id, je.id AS entry_id, je.entry_number INTO v_match
    FROM client_demo.journal_entry_lines jel
    JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
    JOIN client_demo.chart_of_accounts coa ON coa.id = jel.account_id
    WHERE je.status IN ('POSTED', 'VALIDATED')
      AND je.deleted_at IS NULL
      AND coa.account_number LIKE '512%'
      AND jel.reconciliation_id IS NULL
      AND ABS(je.entry_date - v_txn.transaction_date) <= p_tolerance_days
      AND (
        (v_txn.amount > 0 AND jel.debit_amount = v_txn.amount)
        OR
        (v_txn.amount < 0 AND jel.credit_amount = ABS(v_txn.amount))
      )
    ORDER BY ABS(je.entry_date - v_txn.transaction_date)
    LIMIT 1;

    IF FOUND THEN
      UPDATE client_demo.bank_transactions
      SET is_reconciled = TRUE, reconciled_at = NOW(), reconciled_by = p_user_id, updated_at = NOW()
      WHERE id = v_txn.id;
      v_matched := v_matched + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'bank_account', v_bank_account.code,
    'total_transactions', v_total,
    'matched', v_matched,
    'unmatched', v_total - v_matched,
    'match_rate', CASE WHEN v_total > 0 THEN ROUND(v_matched::DECIMAL / v_total * 100, 1) ELSE 0 END
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION client_demo.rpc_auto_reconcile_bank IS
'MCT T2 — Rapprochement bancaire auto : matching montant exact + tolérance date.';


-- ────────────────────────────────────────────────────────────────────────────
-- T3 — LETTRAGE AUTOMATIQUE factures/règlements
-- Utilise reconciliation_groups (conforme schéma script 03)
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION client_demo.rpc_auto_lettrage(
  p_partner_id BIGINT,
  p_user_id    BIGINT DEFAULT 1
)
RETURNS JSONB AS $$
DECLARE
  v_debit_line   RECORD;
  v_credit_line  RECORD;
  v_group_id     BIGINT;
  v_group_code   TEXT;
  v_matched      INT := 0;
  v_seq          INT;
BEGIN
  -- Générer le prochain code de lettrage
  SELECT COALESCE(COUNT(*), 0) + 1 INTO v_seq
  FROM client_demo.reconciliation_groups rg
  JOIN client_demo.journal_entry_lines jel ON jel.reconciliation_id = rg.id
  WHERE jel.partner_id = p_partner_id;

  v_group_code := CHR(65 + (v_seq / 26) % 26) || CHR(65 + v_seq % 26);

  -- Trouver les paires débit/crédit de même montant par tiers
  FOR v_debit_line IN
    SELECT jel.id, jel.account_id, jel.debit_amount AS amount
    FROM client_demo.journal_entry_lines jel
    JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
    WHERE jel.partner_id = p_partner_id
      AND jel.debit_amount > 0
      AND jel.reconciliation_id IS NULL
      AND je.status IN ('POSTED', 'VALIDATED') AND je.deleted_at IS NULL
    ORDER BY jel.id
  LOOP
    SELECT jel.id INTO v_credit_line
    FROM client_demo.journal_entry_lines jel
    JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
    WHERE jel.partner_id = p_partner_id
      AND jel.account_id = v_debit_line.account_id
      AND jel.credit_amount = v_debit_line.amount
      AND jel.reconciliation_id IS NULL
      AND je.status IN ('POSTED', 'VALIDATED') AND je.deleted_at IS NULL
      AND jel.id != v_debit_line.id
    ORDER BY jel.id LIMIT 1;

    IF FOUND THEN
      -- Créer le groupe de lettrage
      INSERT INTO client_demo.reconciliation_groups (
        group_code, account_id, partner_id,
        total_debit, total_credit, reconciled_at, reconciled_by, auto_matched, created_by
      ) VALUES (
        v_group_code, v_debit_line.account_id, p_partner_id,
        v_debit_line.amount, v_debit_line.amount, NOW(), p_user_id, TRUE, p_user_id
      ) RETURNING id INTO v_group_id;

      -- Lier les deux lignes au groupe
      UPDATE client_demo.journal_entry_lines
      SET reconciliation_id = v_group_id, updated_at = NOW(), updated_by = p_user_id
      WHERE id IN (v_debit_line.id, v_credit_line.id);

      v_matched := v_matched + 1;
      v_seq := v_seq + 1;
      v_group_code := CHR(65 + (v_seq / 26) % 26) || CHR(65 + v_seq % 26);
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true, 'partner_id', p_partner_id,
    'pairs_matched', v_matched
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION client_demo.rpc_auto_lettrage IS
'MCT T3 — Lettrage auto : rapprochement factures/paiements via reconciliation_groups.';


-- ────────────────────────────────────────────────────────────────────────────
-- T4 — CLÔTURE COMPTABLE (période OPEN → CLOSED)
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION client_demo.rpc_close_fiscal_period(
  p_period_id BIGINT,
  p_user_id   BIGINT DEFAULT 1
)
RETURNS JSONB AS $$
DECLARE
  v_period      RECORD;
  v_draft_count INT;
  v_unbalanced  INT;
BEGIN
  SELECT * INTO v_period FROM client_demo.fiscal_periods WHERE id = p_period_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Période introuvable'); END IF;
  IF v_period.status != 'OPEN' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Période déjà fermée');
  END IF;

  SELECT COUNT(*) INTO v_draft_count
  FROM client_demo.journal_entries
  WHERE fiscal_period_id = p_period_id AND status = 'DRAFT' AND deleted_at IS NULL;
  IF v_draft_count > 0 THEN
    RETURN jsonb_build_object('success', false, 'error',
      format('%s écriture(s) en brouillon', v_draft_count), 'draft_count', v_draft_count);
  END IF;

  SELECT COUNT(*) INTO v_unbalanced
  FROM client_demo.journal_entries
  WHERE fiscal_period_id = p_period_id AND total_debit != total_credit AND deleted_at IS NULL;
  IF v_unbalanced > 0 THEN
    RETURN jsonb_build_object('success', false, 'error',
      format('%s écriture(s) déséquilibrée(s)', v_unbalanced));
  END IF;

  UPDATE client_demo.fiscal_periods
  SET status = 'CLOSED', updated_at = NOW(), updated_by = p_user_id
  WHERE id = p_period_id;

  INSERT INTO sys.audit_log (tenant_id, user_id, action, entity_type, entity_id, new_values)
  VALUES (
    (SELECT id FROM sys.tenants LIMIT 1), p_user_id, 'CLOSE_PERIOD',
    'fiscal_periods', p_period_id,
    jsonb_build_object('period', v_period.period_number, 'year', v_period.fiscal_year)
  );

  RETURN jsonb_build_object(
    'success', true, 'period', v_period.period_number,
    'fiscal_year', v_period.fiscal_year, 'status', 'CLOSED'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION client_demo.rpc_close_fiscal_period IS
'MCT T4 — Clôture comptable : vérifie brouillons + équilibre, ferme la période.';


-- ────────────────────────────────────────────────────────────────────────────
-- T5 — CALCUL DE LA PAIE (mois complet)
-- CORRECTION NORMATIVE : taux lus depuis contribution_rates (jamais en dur)
-- IRPP lu depuis common.tax_codes code='IRPP_GA_STD'
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION client_demo.rpc_calculate_payroll(
  p_month   INT,
  p_year    INT,
  p_user_id BIGINT DEFAULT 1
)
RETURNS JSONB AS $$
DECLARE
  v_emp             RECORD;
  v_rate            RECORD;
  v_count           INT := 0;
  v_total_brut      DECIMAL(18,2) := 0;
  v_total_net       DECIMAL(18,2) := 0;
  v_total_charges   DECIMAL(18,2) := 0;
  v_brut            DECIMAL(18,2);
  v_emp_contrib     DECIMAL(18,2);
  v_empr_contrib    DECIMAL(18,2);
  v_emp_line        DECIMAL(18,2);
  v_empr_line       DECIMAL(18,2);
  v_taxable_base    DECIMAL(18,2);
  v_net_imposable   DECIMAL(18,2);
  v_net_a_payer     DECIMAL(18,2);
  v_irpp_rate       DECIMAL(8,5) := 0;
  v_period_start    DATE;
  v_period_end      DATE;
  v_payslip_id      BIGINT;
  v_pay_period_id   BIGINT;
  v_lnum            INT;
BEGIN
  v_period_start := make_date(p_year, p_month, 1);
  v_period_end   := (v_period_start + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

  -- Trouver la période de paie
  SELECT id INTO v_pay_period_id
  FROM client_demo.pay_periods WHERE fiscal_year = p_year AND period_month = p_month;

  -- Lire le taux IRPP depuis la table de paramétrage (jamais en dur)
  SELECT COALESCE(rate, 0) / 100 INTO v_irpp_rate
  FROM common.tax_codes
  -- Fix : common.tax_codes n'a pas de colonne is_active ; la validité se gère
  -- via end_date. ROLLBACK : rétablir « AND is_active = TRUE » si la colonne existe.
  WHERE code = 'IRPP_GA_STD' AND (end_date IS NULL OR end_date >= CURRENT_DATE) LIMIT 1;

  FOR v_emp IN
    SELECT * FROM client_demo.employees
    WHERE is_active = TRUE AND deleted_at IS NULL
      AND hire_date <= v_period_end
      AND (termination_date IS NULL OR termination_date >= v_period_start)
  LOOP
    -- ── Calcul du BRUT ──
    v_brut := v_emp.base_salary;
    -- TODO sprint suivant : ajouter payroll_variables (HS, primes)

    v_emp_contrib  := 0;
    v_empr_contrib := 0;
    v_lnum         := 1;

    -- ── Créer/remettre à zéro le bulletin ──
    INSERT INTO client_demo.payslips (
      employee_id, period_start, period_end, payment_date,
      gross_salary, net_salary, net_taxable, employer_contributions,
      status, pay_period_id, created_by
    ) VALUES (
      v_emp.id, v_period_start, v_period_end, v_period_end,
      v_brut, 0, 0, 0,
      'DRAFT', v_pay_period_id, p_user_id
    )
    ON CONFLICT (employee_id, period_start, period_end) DO UPDATE SET
      gross_salary          = EXCLUDED.gross_salary,
      status                = 'DRAFT',
      updated_at            = NOW(),
      updated_by            = p_user_id
    RETURNING id INTO v_payslip_id;

    -- Purger les anciennes lignes
    DELETE FROM client_demo.payslip_lines WHERE payslip_id = v_payslip_id;

    -- Ligne salaire de base
    INSERT INTO client_demo.payslip_lines
      (payslip_id, line_type, code, label, base_amount, rate, employee_amount, employer_amount, line_order, created_by)
    VALUES
      (v_payslip_id, 'SALARY', 'SAL_BASE', 'Salaire de base', v_brut, 100, v_brut, 0, v_lnum, p_user_id);
    v_lnum := v_lnum + 1;

    -- ── Cotisations depuis la table de paramétrage (NOYAU-NORMATIF §1) ──
    FOR v_rate IN
      SELECT cr.employee_rate, cr.employer_rate,
             cr.bracket_floor, cr.bracket_ceiling, cr.organism_code,
             pr.code AS rubric_code, pr.label AS rubric_label,
             pr.rubric_type, pr.display_order
      FROM client_demo.contribution_rates cr
      JOIN client_demo.payroll_rubrics pr ON pr.id = cr.rubric_id
      WHERE (cr.end_date IS NULL OR cr.end_date >= v_period_start)
        AND cr.effective_date <= v_period_end
        AND pr.is_active = TRUE
        AND (cr.applies_to = 'ALL' OR cr.applies_to = v_emp.contract_type)
      ORDER BY pr.display_order
    LOOP
      -- Appliquer le plafond de tranche si défini
      IF v_rate.bracket_ceiling IS NOT NULL THEN
        v_taxable_base := GREATEST(
          LEAST(v_brut, v_rate.bracket_ceiling) - COALESCE(v_rate.bracket_floor, 0), 0
        );
      ELSE
        v_taxable_base := v_brut;
      END IF;

      v_emp_line  := ROUND(v_taxable_base * v_rate.employee_rate,  2);
      v_empr_line := ROUND(v_taxable_base * v_rate.employer_rate, 2);

      v_emp_contrib  := v_emp_contrib  + v_emp_line;
      v_empr_contrib := v_empr_contrib + v_empr_line;

      INSERT INTO client_demo.payslip_lines
        (payslip_id, line_type, code, label, base_amount, rate, employee_amount, employer_amount, line_order, created_by)
      VALUES (
        v_payslip_id,
        CASE WHEN v_rate.employer_rate > 0 AND v_rate.employee_rate = 0 THEN 'EMPLOYER_CONTRIB' ELSE 'DEDUCTION' END,
        v_rate.rubric_code, v_rate.rubric_label,
        v_taxable_base,
        GREATEST(v_rate.employee_rate, v_rate.employer_rate) * 100,
        v_emp_line, v_empr_line, v_lnum, p_user_id
      );
      v_lnum := v_lnum + 1;
    END LOOP;

    -- ── IRPP (taux lu depuis common.tax_codes) ──
    v_net_imposable := v_brut - v_emp_contrib;
    DECLARE v_irpp_amount DECIMAL(18,2);
    BEGIN
      v_irpp_amount := ROUND(v_net_imposable * v_irpp_rate, 2);
      v_emp_contrib := v_emp_contrib + v_irpp_amount;
      v_net_a_payer := v_net_imposable - v_irpp_amount;

      INSERT INTO client_demo.payslip_lines
        (payslip_id, line_type, code, label, base_amount, rate, employee_amount, employer_amount, line_order, created_by)
      VALUES
        (v_payslip_id, 'TAX', 'IRPP', 'IRPP (Prélèvement à la source)',
         v_net_imposable, ROUND(v_irpp_rate * 100, 4), v_irpp_amount, 0, v_lnum, p_user_id);
      v_lnum := v_lnum + 1;
    END;

    -- Ligne NET
    INSERT INTO client_demo.payslip_lines
      (payslip_id, line_type, code, label, base_amount, rate, employee_amount, employer_amount, line_order, created_by)
    VALUES
      (v_payslip_id, 'NET', 'NET_A_PAYER', 'Net à payer', 0, 0, v_net_a_payer, 0, v_lnum, p_user_id);

    -- Mettre à jour les totaux du bulletin
    UPDATE client_demo.payslips SET
      net_salary            = v_net_a_payer,
      net_taxable           = v_net_imposable,
      employer_contributions = v_empr_contrib,
      updated_at            = NOW(),
      updated_by            = p_user_id
    WHERE id = v_payslip_id;

    v_count         := v_count + 1;
    v_total_brut    := v_total_brut + v_brut;
    v_total_net     := v_total_net  + v_net_a_payer;
    v_total_charges := v_total_charges + v_empr_contrib;
  END LOOP;

  -- Journaliser le traitement
  INSERT INTO sys.audit_log (tenant_id, user_id, action, entity_type, entity_id, new_values)
  VALUES (
    (SELECT id FROM sys.tenants LIMIT 1), p_user_id, 'CALCULATE',
    'pay_periods', COALESCE(v_pay_period_id, 0),
    jsonb_build_object('year', p_year, 'month', p_month,
      'employees', v_count, 'total_brut', v_total_brut)
  );

  RETURN jsonb_build_object(
    'success', true,
    'period', p_year || '-' || LPAD(p_month::TEXT, 2, '0'),
    'employees_processed', v_count,
    'total_brut', v_total_brut,
    'total_net', v_total_net,
    'total_charges_patronales', v_total_charges,
    'cout_total_employeur', v_total_brut + v_total_charges
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION client_demo.rpc_calculate_payroll IS
'MCT T5 — Calcul paie mensuel : taux cotisations depuis contribution_rates (NOYAU-NORMATIF §1).';


-- ────────────────────────────────────────────────────────────────────────────
-- T8 — PRÉVISIONNEL TRÉSORERIE (J+30/60/90)
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION client_demo.rpc_cash_forecast(
  p_horizon_days INT DEFAULT 90
)
RETURNS JSONB AS $$
DECLARE
  v_current_cash DECIMAL(18,2);
  v_enc_30 DECIMAL(18,2) := 0; v_dec_30 DECIMAL(18,2) := 0;
  v_enc_60 DECIMAL(18,2) := 0; v_dec_60 DECIMAL(18,2) := 0;
  v_enc_90 DECIMAL(18,2) := 0; v_dec_90 DECIMAL(18,2) := 0;
BEGIN
  SELECT COALESCE(SUM(current_balance), 0) INTO v_current_cash
  FROM client_demo.bank_accounts WHERE is_active = TRUE AND deleted_at IS NULL;

  SELECT
    COALESCE(SUM(CASE WHEN forecast_date <= CURRENT_DATE + 30 THEN amount * COALESCE(probability,100)/100 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN forecast_date <= CURRENT_DATE + 60 THEN amount * COALESCE(probability,100)/100 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN forecast_date <= CURRENT_DATE + 90 THEN amount * COALESCE(probability,100)/100 ELSE 0 END), 0)
  INTO v_enc_30, v_enc_60, v_enc_90
  FROM client_demo.cash_flow_forecast
  WHERE forecast_type = 'RECEIPT' AND is_actual = FALSE
    AND forecast_date BETWEEN CURRENT_DATE AND CURRENT_DATE + p_horizon_days;

  SELECT
    COALESCE(SUM(CASE WHEN forecast_date <= CURRENT_DATE + 30 THEN amount * COALESCE(probability,100)/100 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN forecast_date <= CURRENT_DATE + 60 THEN amount * COALESCE(probability,100)/100 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN forecast_date <= CURRENT_DATE + 90 THEN amount * COALESCE(probability,100)/100 ELSE 0 END), 0)
  INTO v_dec_30, v_dec_60, v_dec_90
  FROM client_demo.cash_flow_forecast
  WHERE forecast_type = 'PAYMENT' AND is_actual = FALSE
    AND forecast_date BETWEEN CURRENT_DATE AND CURRENT_DATE + p_horizon_days;

  RETURN jsonb_build_object(
    'success', true,
    'current_cash', v_current_cash,
    'forecast', jsonb_build_object(
      'j30', jsonb_build_object('receipts', v_enc_30, 'payments', v_dec_30, 'balance', v_current_cash + v_enc_30 - v_dec_30),
      'j60', jsonb_build_object('receipts', v_enc_60, 'payments', v_dec_60, 'balance', v_current_cash + v_enc_60 - v_dec_60),
      'j90', jsonb_build_object('receipts', v_enc_90, 'payments', v_dec_90, 'balance', v_current_cash + v_enc_90 - v_dec_90)
    ),
    'alerts', CASE
      WHEN (v_current_cash + v_enc_30 - v_dec_30) < 0 THEN jsonb_build_array('CRITIQUE: Trésorerie négative sous 30 jours')
      WHEN (v_current_cash + v_enc_60 - v_dec_60) < 0 THEN jsonb_build_array('ALERTE: Trésorerie négative sous 60 jours')
      WHEN (v_current_cash + v_enc_90 - v_dec_90) < 0 THEN jsonb_build_array('ATTENTION: Trésorerie négative sous 90 jours')
      ELSE '[]'::JSONB
    END
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION client_demo.rpc_cash_forecast IS
'MCT T8 — Prévisionnel trésorerie J+30/60/90 avec alertes tension.';


-- ────────────────────────────────────────────────────────────────────────────
-- T10 — DÉCLARATION TVA (CA3)
-- CORRECTION NORMATIVE :
--   • Taux TVA lu depuis common.tax_codes (type='VAT', country='GA') — jamais en dur
--   • Colonnes sys.notifications corrigées (notification_type, category)
--   • Colonnes tax_return_data corrigées (field_value)
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION client_demo.rpc_generate_tva_declaration(
  p_start_date DATE,
  p_end_date   DATE,
  p_user_id    BIGINT DEFAULT 1
)
RETURNS JSONB AS $$
DECLARE
  v_tva_collectee  DECIMAL(18,2) := 0;
  v_tva_deductible DECIMAL(18,2) := 0;
  v_tva_due        DECIMAL(18,2);
  v_ca_ht          DECIMAL(18,2) := 0;
  v_tax_return_id  BIGINT;
  v_tva_rate       DECIMAL(8,5) := 0;
  v_tva_theorique  DECIMAL(18,2);
  v_ecart_pct      DECIMAL(8,4);
  v_fiscal_year    INT;
BEGIN
  v_fiscal_year := EXTRACT(YEAR FROM p_start_date)::INT;

  -- Lire le taux TVA depuis la table de paramétrage (NOYAU-NORMATIF §5)
  SELECT COALESCE(rate, 0) / 100 INTO v_tva_rate
  FROM common.tax_codes
  -- Fix : tax_codes n'a pas is_active (is_default suffit à cibler le taux courant).
  WHERE type = 'VAT' AND country_code = 'GA' AND is_default = TRUE
  LIMIT 1;

  -- TVA Collectée (comptes 4431x)
  SELECT COALESCE(SUM(jel.credit_amount - jel.debit_amount), 0)
  INTO v_tva_collectee
  FROM client_demo.journal_entry_lines jel
  JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
  JOIN client_demo.chart_of_accounts coa ON coa.id = jel.account_id
  WHERE coa.account_number LIKE '4431%'
    AND je.entry_date BETWEEN p_start_date AND p_end_date
    AND je.status IN ('POSTED', 'VALIDATED') AND je.deleted_at IS NULL;

  -- TVA Déductible (comptes 4451x)
  SELECT COALESCE(SUM(jel.debit_amount - jel.credit_amount), 0)
  INTO v_tva_deductible
  FROM client_demo.journal_entry_lines jel
  JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
  JOIN client_demo.chart_of_accounts coa ON coa.id = jel.account_id
  WHERE coa.account_number LIKE '4451%'
    AND je.entry_date BETWEEN p_start_date AND p_end_date
    AND je.status IN ('POSTED', 'VALIDATED') AND je.deleted_at IS NULL;

  -- CA HT (comptes 7xx)
  SELECT COALESCE(SUM(jel.credit_amount - jel.debit_amount), 0)
  INTO v_ca_ht
  FROM client_demo.journal_entry_lines jel
  JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
  JOIN client_demo.chart_of_accounts coa ON coa.id = jel.account_id
  WHERE coa.account_number LIKE '7%'
    AND je.entry_date BETWEEN p_start_date AND p_end_date
    AND je.status IN ('POSTED', 'VALIDATED') AND je.deleted_at IS NULL;

  v_tva_due := v_tva_collectee - v_tva_deductible;

  -- Créer la déclaration
  INSERT INTO client_demo.tax_returns (
    fiscal_year, return_type, period_start, period_end, due_date, status, created_by
  ) VALUES (
    v_fiscal_year, 'TVA', p_start_date, p_end_date,
    p_end_date + INTERVAL '25 days', 'DRAFT', p_user_id
  )
  -- Idempotent : une seule déclaration TVA par exercice ; la régénérer met à jour.
  -- ROLLBACK : retirer le bloc ON CONFLICT si la ré-exécution ne doit pas écraser.
  ON CONFLICT (fiscal_year, return_type) DO UPDATE SET
    period_start = EXCLUDED.period_start,
    period_end   = EXCLUDED.period_end,
    due_date     = EXCLUDED.due_date,
    status       = 'DRAFT',
    updated_at   = NOW()
  RETURNING id INTO v_tax_return_id;

  -- Idempotence des lignes CA3 : on repart d'un jeu propre à chaque régénération
  -- (sinon violation de la contrainte unique tax_return_id/form_code/field_code).
  DELETE FROM client_demo.tax_return_data WHERE tax_return_id = v_tax_return_id;

  INSERT INTO client_demo.tax_return_data
    (tax_return_id, form_code, field_code, field_label, field_value, field_type, created_by)
  VALUES
    (v_tax_return_id, 'CA3', 'CA_HT',         'Chiffre d''affaires HT',     v_ca_ht,          'AMOUNT', p_user_id),
    (v_tax_return_id, 'CA3', 'TVA_COLLECTEE',  'TVA collectée sur ventes',   v_tva_collectee,  'AMOUNT', p_user_id),
    (v_tax_return_id, 'CA3', 'TVA_DEDUCTIBLE', 'TVA déductible sur achats',  v_tva_deductible, 'AMOUNT', p_user_id),
    (v_tax_return_id, 'CA3', 'TVA_DUE',        'TVA nette à payer / crédit', v_tva_due,        'AMOUNT', p_user_id),
    (v_tax_return_id, 'CA3', 'TAUX_TVA',       'Taux TVA appliqué',          ROUND(v_tva_rate * 100, 2), 'RATE', p_user_id);

  -- Contrôle de cohérence (écart > 5% → alerte)
  IF v_tva_rate > 0 AND v_ca_ht > 0 THEN
    v_tva_theorique := ROUND(v_ca_ht * v_tva_rate, 2);
    v_ecart_pct     := ABS(v_tva_collectee - v_tva_theorique) / NULLIF(v_tva_theorique, 0);
    IF v_ecart_pct > 0.05 THEN
      INSERT INTO sys.notifications
        (tenant_id, user_id, notification_type, category, title, message)
      VALUES (
        (SELECT id FROM sys.tenants LIMIT 1), p_user_id,
        'WARNING', 'FISCAL',
        'Incohérence TVA détectée',
        format('Écart significatif TVA collectée vs CA×%s%%: Collectée=%s, Théorique=%s',
          ROUND(v_tva_rate * 100, 0), v_tva_collectee, v_tva_theorique)
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'tax_return_id', v_tax_return_id,
    'period', p_start_date || ' → ' || p_end_date,
    'ca_ht', v_ca_ht,
    'tva_rate_pct', ROUND(v_tva_rate * 100, 2),
    'tva_collectee', v_tva_collectee,
    'tva_deductible', v_tva_deductible,
    'tva_due', v_tva_due,
    'credit_tva', CASE WHEN v_tva_due < 0 THEN ABS(v_tva_due) ELSE 0 END,
    'due_date', (p_end_date + INTERVAL '25 days')::DATE
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION client_demo.rpc_generate_tva_declaration IS
'MCT T10 — Déclaration TVA CA3 : taux lu depuis common.tax_codes (NOYAU-NORMATIF §5).';


-- ────────────────────────────────────────────────────────────────────────────
-- T12 — RATIOS FINANCIERS (12 ratios clés)
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION client_demo.rpc_financial_ratios(
  p_fiscal_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INT
)
RETURNS JSONB AS $$
DECLARE
  v_actif_total      DECIMAL(18,2) := 0;
  v_capitaux_propres DECIMAL(18,2) := 0;
  v_ca               DECIMAL(18,2) := 0;
  v_charges          DECIMAL(18,2) := 0;
  v_resultat         DECIMAL(18,2) := 0;
  v_creances         DECIMAL(18,2) := 0;
  v_dettes_frs       DECIMAL(18,2) := 0;
  v_tresorerie       DECIMAL(18,2) := 0;
  v_dso              DECIMAL(10,2) := 0;
  v_dpo              DECIMAL(10,2) := 0;
BEGIN
  SELECT COALESCE(SUM(jel.debit_amount - jel.credit_amount), 0) INTO v_actif_total
  FROM client_demo.journal_entry_lines jel
  JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
  JOIN client_demo.chart_of_accounts coa ON coa.id = jel.account_id
  JOIN client_demo.fiscal_periods fp ON fp.id = je.fiscal_period_id
  WHERE coa.account_type = 'ASSET' AND fp.fiscal_year = p_fiscal_year
    AND je.status IN ('POSTED','VALIDATED') AND je.deleted_at IS NULL;

  SELECT COALESCE(SUM(jel.credit_amount - jel.debit_amount), 0) INTO v_capitaux_propres
  FROM client_demo.journal_entry_lines jel
  JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
  JOIN client_demo.chart_of_accounts coa ON coa.id = jel.account_id
  JOIN client_demo.fiscal_periods fp ON fp.id = je.fiscal_period_id
  WHERE coa.account_type = 'EQUITY' AND fp.fiscal_year = p_fiscal_year
    AND je.status IN ('POSTED','VALIDATED') AND je.deleted_at IS NULL;

  SELECT COALESCE(SUM(jel.credit_amount - jel.debit_amount), 0) INTO v_ca
  FROM client_demo.journal_entry_lines jel
  JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
  JOIN client_demo.chart_of_accounts coa ON coa.id = jel.account_id
  JOIN client_demo.fiscal_periods fp ON fp.id = je.fiscal_period_id
  WHERE coa.account_type = 'REVENUE' AND fp.fiscal_year = p_fiscal_year
    AND je.status IN ('POSTED','VALIDATED') AND je.deleted_at IS NULL;

  SELECT COALESCE(SUM(jel.debit_amount - jel.credit_amount), 0) INTO v_charges
  FROM client_demo.journal_entry_lines jel
  JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
  JOIN client_demo.chart_of_accounts coa ON coa.id = jel.account_id
  JOIN client_demo.fiscal_periods fp ON fp.id = je.fiscal_period_id
  WHERE coa.account_type = 'EXPENSE' AND fp.fiscal_year = p_fiscal_year
    AND je.status IN ('POSTED','VALIDATED') AND je.deleted_at IS NULL;

  v_resultat := v_ca - v_charges;

  SELECT COALESCE(SUM(jel.debit_amount - jel.credit_amount), 0) INTO v_creances
  FROM client_demo.journal_entry_lines jel
  JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
  JOIN client_demo.chart_of_accounts coa ON coa.id = jel.account_id
  WHERE coa.account_number LIKE '411%'
    AND je.status IN ('POSTED','VALIDATED') AND je.deleted_at IS NULL;

  SELECT COALESCE(SUM(jel.credit_amount - jel.debit_amount), 0) INTO v_dettes_frs
  FROM client_demo.journal_entry_lines jel
  JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
  JOIN client_demo.chart_of_accounts coa ON coa.id = jel.account_id
  WHERE coa.account_number LIKE '401%'
    AND je.status IN ('POSTED','VALIDATED') AND je.deleted_at IS NULL;

  SELECT COALESCE(SUM(current_balance), 0) INTO v_tresorerie
  FROM client_demo.bank_accounts WHERE is_active = TRUE;

  v_dso := client_demo.calculate_dso(p_fiscal_year);
  v_dpo := client_demo.calculate_dpo(p_fiscal_year);

  RETURN jsonb_build_object(
    'success', true,
    'fiscal_year', p_fiscal_year,
    'ratios', jsonb_build_object(
      'marge_nette',       CASE WHEN v_ca > 0 THEN ROUND(v_resultat / v_ca * 100, 2) ELSE 0 END,
      'roe',               CASE WHEN v_capitaux_propres > 0 THEN ROUND(v_resultat / v_capitaux_propres * 100, 2) ELSE 0 END,
      'autonomie_fin',     CASE WHEN v_actif_total > 0 THEN ROUND(v_capitaux_propres / v_actif_total * 100, 2) ELSE 0 END,
      'ratio_endettement', CASE WHEN v_capitaux_propres > 0 THEN ROUND((v_actif_total - v_capitaux_propres) / v_capitaux_propres * 100, 2) ELSE 0 END,
      'tresorerie_nette',  v_tresorerie,
      'ratio_liquidite',   CASE WHEN v_dettes_frs > 0 THEN ROUND((v_creances + v_tresorerie) / v_dettes_frs, 2) ELSE 0 END,
      'dso',               v_dso,
      'dpo',               v_dpo,
      'bfr',               v_creances - v_dettes_frs,
      'ca',                v_ca,
      'charges',           v_charges,
      'resultat_net',      v_resultat
    ),
    'alerts', (
      SELECT jsonb_agg(alert) FROM (
        SELECT 'Autonomie financière faible (<30%)' AS alert WHERE v_actif_total > 0 AND v_capitaux_propres / v_actif_total < 0.30
        UNION ALL SELECT 'DSO élevé (>60 jours)' WHERE v_dso > 60
        UNION ALL SELECT 'Résultat net négatif' WHERE v_resultat < 0
        UNION ALL SELECT 'Trésorerie critique (<0)' WHERE v_tresorerie < 0
      ) sub
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION client_demo.rpc_financial_ratios IS
'MCT T12 — Ratios financiers : rentabilité, solvabilité, liquidité, activité.';


-- ────────────────────────────────────────────────────────────────────────────
-- T14 — AMORTISSEMENTS (dotations mensuelles)
-- CORRECTION NORMATIVE : coefficient dégressif lu depuis asset_categories
-- RG04 : Dotation annuelle = (VA - VR) / Durée
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION client_demo.rpc_generate_depreciation(
  p_period_id BIGINT,
  p_user_id   BIGINT DEFAULT 1
)
RETURNS JSONB AS $$
DECLARE
  v_asset    RECORD;
  v_period   RECORD;
  v_category RECORD;
  v_amount   DECIMAL(18,2);
  v_coeff    DECIMAL(4,2);
  v_count    INT := 0;
  v_total    DECIMAL(18,2) := 0;
BEGIN
  SELECT * INTO v_period FROM client_demo.fiscal_periods WHERE id = p_period_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Période introuvable'); END IF;

  FOR v_asset IN
    SELECT fa.* FROM client_demo.fixed_assets fa
    WHERE fa.status = 'ACTIVE' AND fa.is_active = TRUE AND fa.deleted_at IS NULL
      AND fa.depreciation_method != 'NONE'
      AND fa.acquisition_date < v_period.end_date
      AND (fa.disposal_date IS NULL OR fa.disposal_date > v_period.start_date)
      AND fa.net_book_value > COALESCE(fa.residual_value, 0)
  LOOP
    -- Lire les coefficients depuis la catégorie (jamais en dur)
    IF v_asset.category_id IS NOT NULL THEN
      SELECT * INTO v_category FROM client_demo.asset_categories WHERE id = v_asset.category_id;
    END IF;

    IF v_asset.depreciation_method = 'LINEAR' THEN
      -- RG04 : amortissement linéaire mensuel
      v_amount := ROUND(
        (v_asset.acquisition_value - COALESCE(v_asset.residual_value, 0))
        / v_asset.useful_life_months, 2
      );
    ELSIF v_asset.depreciation_method = 'DECLINING' THEN
      -- Coefficient dégressif OHADA lu depuis asset_categories (NOYAU-NORMATIF §1)
      v_coeff := CASE
        WHEN v_asset.useful_life_months <= 48 THEN COALESCE(v_category.declining_coeff_short,  1.25)
        WHEN v_asset.useful_life_months <= 72 THEN COALESCE(v_category.declining_coeff_medium, 1.75)
        ELSE                                       COALESCE(v_category.declining_coeff_long,   2.25)
      END;
      v_amount := ROUND(
        v_asset.net_book_value * (v_coeff / (v_asset.useful_life_months / 12.0)) / 12.0, 2
      );
    ELSE
      v_amount := 0;
    END IF;

    -- Ne pas amortir au-delà de la valeur résiduelle
    IF (v_asset.accumulated_depreciation + v_amount)
       > (v_asset.acquisition_value - COALESCE(v_asset.residual_value, 0)) THEN
      v_amount := v_asset.acquisition_value - COALESCE(v_asset.residual_value, 0)
                  - v_asset.accumulated_depreciation;
    END IF;

    IF v_amount <= 0 THEN CONTINUE; END IF;

    INSERT INTO client_demo.depreciation_schedule (
      fixed_asset_id, fiscal_period_id, depreciation_date,
      depreciation_amount, accumulated_depreciation, net_book_value,
      status, created_by
    ) VALUES (
      v_asset.id, p_period_id, v_period.end_date,
      v_amount,
      v_asset.accumulated_depreciation + v_amount,
      v_asset.net_book_value - v_amount,
      'PLANNED', p_user_id
    ) ON CONFLICT (fixed_asset_id, fiscal_period_id) DO NOTHING;

    UPDATE client_demo.fixed_assets
    SET accumulated_depreciation = accumulated_depreciation + v_amount,
        net_book_value = net_book_value - v_amount,
        updated_at = NOW(), updated_by = p_user_id
    WHERE id = v_asset.id;

    v_count := v_count + 1;
    v_total := v_total + v_amount;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'period', v_period.period_number || '/' || v_period.fiscal_year,
    'assets_processed', v_count,
    'total_depreciation', v_total
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION client_demo.rpc_generate_depreciation IS
'MCT T14 — Amortissements : coefficients dégressifs lus depuis asset_categories (NOYAU-NORMATIF §1).';


-- ────────────────────────────────────────────────────────────────────────────
-- T15 — CESSION D'IMMOBILISATION
-- RG05 : Résultat = Prix cession - VNC
-- CORRECTION : v_asset.asset_name (pas v_asset.name) + audit_log corrigé
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION client_demo.rpc_dispose_asset(
  p_asset_id       BIGINT,
  p_disposal_date  DATE,
  p_disposal_price DECIMAL(18,2),
  p_disposal_type  TEXT    DEFAULT 'SALE',
  p_user_id        BIGINT  DEFAULT 1
)
RETURNS JSONB AS $$
DECLARE
  v_asset       RECORD;
  v_vnc         DECIMAL(18,2);
  v_result      DECIMAL(18,2);
  v_result_type TEXT;
BEGIN
  SELECT * INTO v_asset FROM client_demo.fixed_assets WHERE id = p_asset_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Immobilisation introuvable');
  END IF;
  IF v_asset.status != 'ACTIVE' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Immobilisation non active');
  END IF;

  v_vnc         := v_asset.net_book_value;
  v_result      := p_disposal_price - v_vnc;
  v_result_type := CASE WHEN v_result >= 0 THEN 'PLUS_VALUE' ELSE 'MOINS_VALUE' END;

  UPDATE client_demo.fixed_assets
  SET status = CASE p_disposal_type
        WHEN 'SALE'      THEN 'DISPOSED'
        WHEN 'SCRAPPING' THEN 'SCRAPPED'
        ELSE 'DISPOSED'
      END,
      disposal_date  = p_disposal_date,
      disposal_value = p_disposal_price,
      is_active      = FALSE,
      updated_at     = NOW(), updated_by = p_user_id
  WHERE id = p_asset_id;

  INSERT INTO sys.audit_log (tenant_id, user_id, action, entity_type, entity_id, new_values)
  VALUES (
    (SELECT id FROM sys.tenants LIMIT 1), p_user_id, 'DISPOSE_ASSET',
    'fixed_assets', p_asset_id,
    jsonb_build_object('type', p_disposal_type, 'price', p_disposal_price, 'vnc', v_vnc, 'result', v_result)
  );

  RETURN jsonb_build_object(
    'success', true,
    'asset_number', v_asset.asset_number,
    'asset_name', v_asset.asset_name,          -- correction : asset_name (pas name)
    'acquisition_value', v_asset.acquisition_value,
    'accumulated_depreciation', v_asset.accumulated_depreciation,
    'vnc_at_disposal', v_vnc,
    'disposal_price', p_disposal_price,
    'result', v_result,
    'result_type', v_result_type
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION client_demo.rpc_dispose_asset IS
'MCT T15 — Cession immobilisation : plus/moins-value. RG05.';


-- ────────────────────────────────────────────────────────────────────────────
-- T16 — BALANCE GÉNÉRALE
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION client_demo.rpc_trial_balance(
  p_fiscal_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INT,
  p_period_end  INT DEFAULT 12
)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object(
      'success', true, 'fiscal_year', p_fiscal_year,
      'accounts', jsonb_agg(row_data ORDER BY account_number)
    )
    FROM (
      SELECT
        coa.account_number, coa.account_label, coa.account_type,
        SUM(jel.debit_amount) AS total_debit,
        SUM(jel.credit_amount) AS total_credit,
        SUM(jel.debit_amount) - SUM(jel.credit_amount) AS balance,
        jsonb_build_object(
          'account_number', coa.account_number,
          'account_label', coa.account_label,
          'account_type', coa.account_type,
          'total_debit', SUM(jel.debit_amount),
          'total_credit', SUM(jel.credit_amount),
          'balance', SUM(jel.debit_amount) - SUM(jel.credit_amount)
        ) AS row_data
      FROM client_demo.journal_entry_lines jel
      JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
      JOIN client_demo.chart_of_accounts coa ON coa.id = jel.account_id
      JOIN client_demo.fiscal_periods fp ON fp.id = je.fiscal_period_id
      WHERE fp.fiscal_year = p_fiscal_year AND fp.period_number <= p_period_end
        AND je.status IN ('POSTED', 'VALIDATED') AND je.deleted_at IS NULL
      GROUP BY coa.account_number, coa.account_label, coa.account_type
      HAVING SUM(jel.debit_amount) != 0 OR SUM(jel.credit_amount) != 0
    ) sub
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION client_demo.rpc_trial_balance IS
'MCT T16 — Balance générale de vérification par exercice et période.';


-- ────────────────────────────────────────────────────────────────────────────
-- T17 — KPI DASHBOARD
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION client_demo.rpc_dashboard_kpi(
  p_fiscal_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INT
)
RETURNS JSONB AS $$
DECLARE
  v_ca      DECIMAL(18,2) := 0;
  v_charges DECIMAL(18,2) := 0;
  v_treso   DECIMAL(18,2) := 0;
  v_dso     DECIMAL(10,2) := 0;
  v_monthly JSONB;
BEGIN
  SELECT COALESCE(SUM(jel.credit_amount - jel.debit_amount), 0) INTO v_ca
  FROM client_demo.journal_entry_lines jel
  JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
  JOIN client_demo.chart_of_accounts coa ON coa.id = jel.account_id
  JOIN client_demo.fiscal_periods fp ON fp.id = je.fiscal_period_id
  WHERE coa.account_type = 'REVENUE' AND fp.fiscal_year = p_fiscal_year
    AND je.status IN ('POSTED','VALIDATED') AND je.deleted_at IS NULL;

  SELECT COALESCE(SUM(jel.debit_amount - jel.credit_amount), 0) INTO v_charges
  FROM client_demo.journal_entry_lines jel
  JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
  JOIN client_demo.chart_of_accounts coa ON coa.id = jel.account_id
  JOIN client_demo.fiscal_periods fp ON fp.id = je.fiscal_period_id
  WHERE coa.account_type = 'EXPENSE' AND fp.fiscal_year = p_fiscal_year
    AND je.status IN ('POSTED','VALIDATED') AND je.deleted_at IS NULL;

  SELECT COALESCE(SUM(current_balance), 0) INTO v_treso
  FROM client_demo.bank_accounts WHERE is_active = TRUE;

  v_dso := client_demo.calculate_dso(p_fiscal_year);

  -- Fix : un SUM() imbriqué dans jsonb_agg() provoque « aggregate function calls
  -- cannot be nested ». On agrège par mois dans une sous-requête, puis jsonb_agg.
  -- ROLLBACK : revenir au SUM() imbriqué dans jsonb_agg si besoin.
  SELECT jsonb_agg(
           jsonb_build_object('month', m.period_number, 'ca', m.ca, 'charges', m.charges)
           ORDER BY m.period_number
         ) INTO v_monthly
  FROM (
    SELECT fp.period_number,
      COALESCE(SUM(CASE WHEN coa.account_type = 'REVENUE' THEN jel.credit_amount - jel.debit_amount ELSE 0 END), 0) AS ca,
      COALESCE(SUM(CASE WHEN coa.account_type = 'EXPENSE' THEN jel.debit_amount - jel.credit_amount ELSE 0 END), 0) AS charges
    FROM client_demo.journal_entry_lines jel
    JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
    JOIN client_demo.chart_of_accounts coa ON coa.id = jel.account_id
    JOIN client_demo.fiscal_periods fp ON fp.id = je.fiscal_period_id
    WHERE fp.fiscal_year = p_fiscal_year
      AND je.status IN ('POSTED','VALIDATED') AND je.deleted_at IS NULL
    GROUP BY fp.period_number
  ) m;

  RETURN jsonb_build_object(
    'success', true,
    'kpi', jsonb_build_object(
      'ca', v_ca, 'charges', v_charges, 'resultat', v_ca - v_charges,
      'tresorerie', v_treso, 'dso', v_dso,
      'marge_pct', CASE WHEN v_ca > 0 THEN ROUND((v_ca - v_charges) / v_ca * 100, 1) ELSE 0 END
    ),
    'monthly', COALESCE(v_monthly, '[]'::JSONB)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION client_demo.rpc_dashboard_kpi IS
'MCT T17 — Dashboard KPI dirigeant : CA, charges, résultat, trésorerie, DSO, mensuel.';


-- ────────────────────────────────────────────────────────────────────────────
-- GRANTS Supabase PostgREST
-- ────────────────────────────────────────────────────────────────────────────

GRANT EXECUTE ON FUNCTION client_demo.rpc_create_journal_entry     TO authenticated;
GRANT EXECUTE ON FUNCTION client_demo.rpc_validate_journal_entry   TO authenticated;
GRANT EXECUTE ON FUNCTION client_demo.rpc_auto_reconcile_bank      TO authenticated;
GRANT EXECUTE ON FUNCTION client_demo.rpc_auto_lettrage            TO authenticated;
GRANT EXECUTE ON FUNCTION client_demo.rpc_close_fiscal_period      TO authenticated;
GRANT EXECUTE ON FUNCTION client_demo.rpc_calculate_payroll        TO authenticated;
GRANT EXECUTE ON FUNCTION client_demo.rpc_cash_forecast            TO authenticated;
GRANT EXECUTE ON FUNCTION client_demo.rpc_generate_tva_declaration TO authenticated;
GRANT EXECUTE ON FUNCTION client_demo.rpc_financial_ratios         TO authenticated;
GRANT EXECUTE ON FUNCTION client_demo.rpc_generate_depreciation    TO authenticated;
GRANT EXECUTE ON FUNCTION client_demo.rpc_dispose_asset            TO authenticated;
GRANT EXECUTE ON FUNCTION client_demo.rpc_trial_balance            TO authenticated;
GRANT EXECUTE ON FUNCTION client_demo.rpc_dashboard_kpi            TO authenticated;

-- ============================================================================
DO $$ BEGIN RAISE NOTICE '✅ Script 04 OK — Fonctions RPC T1→T17 créées (corrections normatives appliquées)';
END $$;
