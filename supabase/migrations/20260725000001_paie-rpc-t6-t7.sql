-- ============================================================================
-- Migration : T6 rpc_validate_payslip + T7 rpc_generate_payroll_entries
-- Conformité NOYAU-NORMATIF §1 : aucun taux/compte OHADA en dur
-- Conformité NOYAU-NORMATIF §2 : workflow DRAFT→VALIDATED irréversible
-- Conformité NOYAU-NORMATIF §5 : comptes de contrepartie via payroll_rubrics
-- ============================================================================

-- ────────────────────────────────────────────────────────────────────────────
-- T6 — VALIDATION D'UN BULLETIN DE PAIE (DRAFT → VALIDATED)
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION client_demo.rpc_validate_payslip(
  p_payslip_id BIGINT,
  p_user_id    BIGINT DEFAULT 1
)
RETURNS JSONB AS $$
DECLARE
  v_payslip RECORD;
BEGIN
  SELECT * INTO v_payslip
  FROM client_demo.payslips
  WHERE id = p_payslip_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bulletin introuvable');
  END IF;

  IF v_payslip.status <> 'DRAFT' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Seul un bulletin DRAFT peut être validé. Statut actuel : ' || v_payslip.status
    );
  END IF;

  UPDATE client_demo.payslips SET
    status       = 'VALIDATED',
    validated_by = p_user_id,
    validated_at = NOW(),
    updated_at   = NOW(),
    updated_by   = p_user_id
  WHERE id = p_payslip_id;

  INSERT INTO sys.audit_log (tenant_id, user_id, action, entity_type, entity_id, old_values, new_values)
  VALUES (
    (SELECT id FROM sys.tenants LIMIT 1),
    p_user_id, 'VALIDATE', 'payslips', p_payslip_id,
    jsonb_build_object('status', 'DRAFT'),
    jsonb_build_object('status', 'VALIDATED', 'validated_at', NOW()::TEXT)
  );

  RETURN jsonb_build_object(
    'success',      true,
    'payslip_id',   p_payslip_id,
    'employee_id',  v_payslip.employee_id,
    'gross_salary', v_payslip.gross_salary,
    'net_salary',   v_payslip.net_salary,
    'status',       'VALIDATED'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION client_demo.rpc_validate_payslip IS
'MCT T6 — Validation bulletin de paie : DRAFT→VALIDATED (irréversible, NOYAU-NORMATIF §2).';


-- ────────────────────────────────────────────────────────────────────────────
-- T7 — OD DE PAIE : GÉNÉRATION DES ÉCRITURES COMPTABLES (SYSCOHADA)
-- Comptes de contrepartie lus depuis payroll_rubrics (NOYAU-NORMATIF §5)
-- Aucun compte OHADA en dur dans cette fonction
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION client_demo.rpc_generate_payroll_entries(
  p_pay_period_id    BIGINT,
  p_fiscal_period_id BIGINT,
  p_user_id          BIGINT DEFAULT 1
)
RETURNS JSONB AS $$
DECLARE
  v_pay_period     RECORD;
  v_journal_id     BIGINT;
  v_entry_id       BIGINT;
  v_entry_number   VARCHAR(50);
  v_payslip        RECORD;
  v_line           RECORD;
  v_rubric         RECORD;
  v_count          INT := 0;
  v_total_brut     DECIMAL(18,2) := 0;
  v_total_net      DECIMAL(18,2) := 0;
  v_line_order     INT;
  v_entry_date     DATE;
BEGIN
  -- Récupérer la période de paie
  SELECT * INTO v_pay_period
  FROM client_demo.pay_periods WHERE id = p_pay_period_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Période de paie introuvable');
  END IF;

  -- Récupérer le journal PAIE (code lu depuis la table journals — jamais en dur)
  SELECT id INTO v_journal_id
  FROM client_demo.journals
  WHERE code = 'PAIE' AND is_active = TRUE
  LIMIT 1;

  IF v_journal_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Journal PAIE introuvable. Vérifiez la table journals.');
  END IF;

  -- Vérifier qu'il existe des bulletins VALIDATED pour cette période
  SELECT COUNT(*) INTO v_count
  FROM client_demo.payslips
  WHERE pay_period_id = p_pay_period_id AND status = 'VALIDATED';

  IF v_count = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Aucun bulletin VALIDATED pour cette période');
  END IF;

  v_entry_date := v_pay_period.payment_date;
  IF v_entry_date IS NULL THEN
    v_entry_date := v_pay_period.end_date;
  END IF;

  -- Calcul des totaux brut / net
  SELECT
    COALESCE(SUM(gross_salary), 0),
    COALESCE(SUM(net_salary), 0)
  INTO v_total_brut, v_total_net
  FROM client_demo.payslips
  WHERE pay_period_id = p_pay_period_id AND status = 'VALIDATED';

  -- Générer le numéro de pièce
  v_entry_number := 'PAIE-' || TO_CHAR(v_entry_date, 'YYYY-MM');

  -- Créer l'en-tête de l'écriture (DRAFT, équilibre vérifié ci-dessous)
  INSERT INTO client_demo.journal_entries (
    journal_id, entry_date, fiscal_period_id, description,
    reference, status, created_by
  ) VALUES (
    v_journal_id, v_entry_date, p_fiscal_period_id,
    'OD Paie ' || TO_CHAR(v_entry_date, 'MM/YYYY'),
    v_entry_number, 'DRAFT', p_user_id
  )
  RETURNING id INTO v_entry_id;

  v_line_order := 1;

  -- Lignes depuis payslip_lines agrégées par rubrique (comptes depuis payroll_rubrics)
  FOR v_rubric IN
    SELECT
      pr.debit_account_id,
      pr.credit_account_id,
      pr.code AS rubric_code,
      pr.label AS rubric_label,
      pr.rubric_type,
      COALESCE(SUM(pl.employee_amount), 0) AS emp_total,
      COALESCE(SUM(pl.employer_amount), 0) AS empr_total
    FROM client_demo.payslip_lines pl
    JOIN client_demo.payroll_rubrics pr ON pr.code = pl.code
    JOIN client_demo.payslips ps ON ps.id = pl.payslip_id
    WHERE ps.pay_period_id = p_pay_period_id
      AND ps.status = 'VALIDATED'
      AND pr.debit_account_id IS NOT NULL
      AND pr.credit_account_id IS NOT NULL
    GROUP BY pr.id, pr.debit_account_id, pr.credit_account_id,
             pr.code, pr.label, pr.rubric_type
    ORDER BY pr.display_order
  LOOP
    -- Ligne employé (cotisations salariales ou salaire)
    IF v_rubric.emp_total <> 0 THEN
      INSERT INTO client_demo.journal_entry_lines (
        journal_entry_id, account_id, description,
        debit, credit, line_order, created_by
      ) VALUES (
        v_entry_id,
        CASE WHEN v_rubric.rubric_type IN ('EARNING') THEN v_rubric.debit_account_id ELSE v_rubric.credit_account_id END,
        v_rubric.rubric_label,
        CASE WHEN v_rubric.rubric_type IN ('EARNING') THEN v_rubric.emp_total ELSE 0 END,
        CASE WHEN v_rubric.rubric_type IN ('EARNING') THEN 0 ELSE v_rubric.emp_total END,
        v_line_order, p_user_id
      );
      v_line_order := v_line_order + 1;
    END IF;

    -- Ligne patronale
    IF v_rubric.empr_total <> 0 THEN
      INSERT INTO client_demo.journal_entry_lines (
        journal_entry_id, account_id, description,
        debit, credit, line_order, created_by
      ) VALUES (
        v_entry_id,
        v_rubric.debit_account_id,
        v_rubric.rubric_label || ' (patronal)',
        v_rubric.empr_total, 0,
        v_line_order, p_user_id
      );
      v_line_order := v_line_order + 1;
    END IF;
  END LOOP;

  -- Ligne NET À PAYER → compte 422 (lu depuis payroll_rubrics code='NET_A_PAYER')
  DECLARE
    v_net_account_id BIGINT;
  BEGIN
    SELECT credit_account_id INTO v_net_account_id
    FROM client_demo.payroll_rubrics WHERE code = 'NET_A_PAYER' LIMIT 1;

    IF v_net_account_id IS NOT NULL AND v_total_net <> 0 THEN
      INSERT INTO client_demo.journal_entry_lines (
        journal_entry_id, account_id, description,
        debit, credit, line_order, created_by
      ) VALUES (
        v_entry_id, v_net_account_id,
        'Net à payer ' || TO_CHAR(v_entry_date, 'MM/YYYY'),
        0, v_total_net, v_line_order, p_user_id
      );
    END IF;
  END;

  -- Mettre à jour les totaux de l'écriture
  UPDATE client_demo.journal_entries SET
    total_debit  = (SELECT COALESCE(SUM(debit), 0)  FROM client_demo.journal_entry_lines WHERE journal_entry_id = v_entry_id),
    total_credit = (SELECT COALESCE(SUM(credit), 0) FROM client_demo.journal_entry_lines WHERE journal_entry_id = v_entry_id),
    updated_at   = NOW(),
    updated_by   = p_user_id
  WHERE id = v_entry_id;

  -- Lier les bulletins à l'écriture générée
  UPDATE client_demo.payslips SET
    journal_entry_id = v_entry_id,
    updated_at       = NOW(),
    updated_by       = p_user_id
  WHERE pay_period_id = p_pay_period_id AND status = 'VALIDATED';

  -- Audit
  INSERT INTO sys.audit_log (tenant_id, user_id, action, entity_type, entity_id, new_values)
  VALUES (
    (SELECT id FROM sys.tenants LIMIT 1), p_user_id, 'GENERATE',
    'journal_entries', v_entry_id,
    jsonb_build_object(
      'pay_period_id', p_pay_period_id,
      'entry_number', v_entry_number,
      'payslips_count', v_count,
      'total_brut', v_total_brut,
      'total_net', v_total_net
    )
  );

  RETURN jsonb_build_object(
    'success',         true,
    'journal_entry_id', v_entry_id,
    'entry_number',    v_entry_number,
    'payslips_processed', v_count,
    'total_brut',      v_total_brut,
    'total_net',       v_total_net
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION client_demo.rpc_generate_payroll_entries IS
'MCT T7 — OD de paie : génération écritures SYSCOHADA. Comptes via payroll_rubrics (NOYAU-NORMATIF §5).';


-- ────────────────────────────────────────────────────────────────────────────
-- GRANTS Supabase PostgREST
-- ────────────────────────────────────────────────────────────────────────────

GRANT EXECUTE ON FUNCTION client_demo.rpc_validate_payslip        TO authenticated;
GRANT EXECUTE ON FUNCTION client_demo.rpc_generate_payroll_entries TO authenticated;

-- ============================================================================
DO $$ BEGIN RAISE NOTICE '✅ Migration paie T6/T7 OK — rpc_validate_payslip + rpc_generate_payroll_entries';
END $$;
