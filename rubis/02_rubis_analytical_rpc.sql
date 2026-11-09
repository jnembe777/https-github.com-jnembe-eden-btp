-- ============================================================================
-- EDENFIN RUBIS — SCRIPT 02 : ANALYTICAL DISTRIBUTION RPC
-- PostgreSQL 15+ (Supabase)
-- ============================================================================
-- Fonctionnalités :
--   - Distribution analytique des écritures comptables
--   - Modèles de répartition (templates)
--   - Calcul automatique des ventilations
--   - Reporting analytique multi-axes
--   - Budget vs Réel par centre analytique
-- ============================================================================

-- ============================================================================
-- 1. TABLES COMPLÉMENTAIRES POUR DISTRIBUTION ANALYTIQUE
-- ============================================================================

-- Modèles de répartition analytique
CREATE TABLE IF NOT EXISTS sys.analytical_distribution_templates (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
  entity_id BIGINT REFERENCES sys.tenant_entities(id), -- NULL = all entities
  template_code VARCHAR(30) NOT NULL,
  template_name VARCHAR(200) NOT NULL,
  description TEXT,
  -- Applicabilité
  applicable_account_pattern VARCHAR(20), -- Ex: '6%' pour tous les comptes de charges
  applicable_axis_id BIGINT REFERENCES sys.analytical_axes(id),
  is_mandatory BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  deleted_at TIMESTAMPTZ,
  deleted_by BIGINT,
  version_number INT NOT NULL DEFAULT 1,
  UNIQUE(tenant_id, template_code)
);

CREATE INDEX idx_distrib_templates_tenant ON sys.analytical_distribution_templates(tenant_id, is_active);
CREATE INDEX idx_distrib_templates_account ON sys.analytical_distribution_templates(applicable_account_pattern);
COMMENT ON TABLE sys.analytical_distribution_templates IS 'Modèles de répartition analytique';

-- Lignes des modèles de répartition
CREATE TABLE IF NOT EXISTS sys.analytical_distribution_lines (
  id BIGSERIAL PRIMARY KEY,
  template_id BIGINT NOT NULL REFERENCES sys.analytical_distribution_templates(id) ON DELETE CASCADE,
  analytical_value_id BIGINT NOT NULL REFERENCES sys.analytical_values(id),
  distribution_percentage DECIMAL(7,4) NOT NULL CHECK (distribution_percentage > 0 AND distribution_percentage <= 100),
  distribution_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
  valid_to DATE,
  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT
);

CREATE INDEX idx_distrib_lines_template ON sys.analytical_distribution_lines(template_id);
CREATE INDEX idx_distrib_lines_value ON sys.analytical_distribution_lines(analytical_value_id);
COMMENT ON TABLE sys.analytical_distribution_lines IS 'Lignes de répartition analytique';

-- Écritures analytiques (ventilation des écritures comptables)
CREATE TABLE IF NOT EXISTS sys.analytical_entries (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
  entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),
  -- Référence à l'écriture comptable source
  journal_entry_id BIGINT NOT NULL, -- FK vers client.journal_entries (schéma tenant)
  journal_entry_line_id BIGINT NOT NULL, -- FK vers client.journal_entry_lines
  -- Ventilation analytique
  axis_id BIGINT NOT NULL REFERENCES sys.analytical_axes(id),
  analytical_value_id BIGINT NOT NULL REFERENCES sys.analytical_values(id),
  -- Montants
  amount_debit DECIMAL(18,2) NOT NULL DEFAULT 0,
  amount_credit DECIMAL(18,2) NOT NULL DEFAULT 0,
  amount_net DECIMAL(18,2) GENERATED ALWAYS AS (amount_debit - amount_credit) STORED,
  distribution_percentage DECIMAL(7,4) NOT NULL DEFAULT 100.0000,
  -- Méta
  distribution_source VARCHAR(20) NOT NULL DEFAULT 'MANUAL' CHECK (
    distribution_source IN ('MANUAL', 'TEMPLATE', 'AUTOMATIC', 'IMPORT')
  ),
  template_id BIGINT REFERENCES sys.analytical_distribution_templates(id),
  -- Dates
  entry_date DATE NOT NULL,
  period_year INT NOT NULL,
  period_month INT NOT NULL,
  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT
);

CREATE INDEX idx_analytical_entries_tenant ON sys.analytical_entries(tenant_id, entity_id);
CREATE INDEX idx_analytical_entries_journal ON sys.analytical_entries(journal_entry_id, journal_entry_line_id);
CREATE INDEX idx_analytical_entries_axis ON sys.analytical_entries(axis_id, analytical_value_id);
CREATE INDEX idx_analytical_entries_period ON sys.analytical_entries(period_year, period_month);
CREATE INDEX idx_analytical_entries_date ON sys.analytical_entries(entry_date DESC);
COMMENT ON TABLE sys.analytical_entries IS 'Écritures analytiques ventilées';

-- Contrainte: le total des % par ligne comptable doit être 100%
-- (vérifiée par trigger ou RPC)

-- ============================================================================
-- 2. FONCTIONS DE DISTRIBUTION ANALYTIQUE
-- ============================================================================

-- Valider un template de distribution (somme = 100%)
CREATE OR REPLACE FUNCTION sys.validate_distribution_template(
  p_template_id BIGINT
)
RETURNS TABLE (
  is_valid BOOLEAN,
  total_percentage DECIMAL,
  error_message TEXT
) AS $$
DECLARE
  v_total DECIMAL;
BEGIN
  SELECT COALESCE(SUM(distribution_percentage), 0)
  INTO v_total
  FROM sys.analytical_distribution_lines
  WHERE template_id = p_template_id
    AND is_active = TRUE
    AND (valid_to IS NULL OR valid_to >= CURRENT_DATE);

  IF v_total = 100.0000 THEN
    RETURN QUERY SELECT TRUE, v_total, NULL::TEXT;
  ELSIF v_total < 100.0000 THEN
    RETURN QUERY SELECT FALSE, v_total,
      'Distribution incomplète: ' || v_total || '% (manque ' || (100 - v_total) || '%)';
  ELSE
    RETURN QUERY SELECT FALSE, v_total,
      'Distribution excessive: ' || v_total || '% (excès de ' || (v_total - 100) || '%)';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION sys.validate_distribution_template IS 'Valide qu''un template de distribution totalise 100%';

-- Appliquer un template de distribution à un montant
CREATE OR REPLACE FUNCTION sys.apply_distribution_template(
  p_template_id BIGINT,
  p_amount DECIMAL,
  p_is_debit BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
  analytical_value_id BIGINT,
  value_code VARCHAR,
  value_name VARCHAR,
  distribution_percentage DECIMAL,
  distributed_amount DECIMAL
) AS $$
DECLARE
  v_validation RECORD;
BEGIN
  -- Valider le template
  SELECT * INTO v_validation FROM sys.validate_distribution_template(p_template_id);

  IF NOT v_validation.is_valid THEN
    RAISE EXCEPTION 'Template invalide: %', v_validation.error_message;
  END IF;

  RETURN QUERY
  SELECT
    dl.analytical_value_id,
    av.value_code,
    av.value_name,
    dl.distribution_percentage,
    ROUND(p_amount * dl.distribution_percentage / 100, 2) AS distributed_amount
  FROM sys.analytical_distribution_lines dl
  JOIN sys.analytical_values av ON av.id = dl.analytical_value_id
  WHERE dl.template_id = p_template_id
    AND dl.is_active = TRUE
    AND (dl.valid_to IS NULL OR dl.valid_to >= CURRENT_DATE)
  ORDER BY dl.distribution_order, av.value_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION sys.apply_distribution_template IS 'Applique un template de distribution à un montant';

-- Trouver le template applicable pour un compte
CREATE OR REPLACE FUNCTION sys.find_applicable_template(
  p_tenant_id BIGINT,
  p_entity_id BIGINT,
  p_account_number VARCHAR,
  p_axis_id BIGINT DEFAULT NULL
)
RETURNS TABLE (
  template_id BIGINT,
  template_code VARCHAR,
  template_name VARCHAR,
  is_mandatory BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    t.id AS template_id,
    t.template_code,
    t.template_name,
    t.is_mandatory
  FROM sys.analytical_distribution_templates t
  WHERE t.tenant_id = p_tenant_id
    AND t.is_active = TRUE
    AND t.deleted_at IS NULL
    AND (t.entity_id IS NULL OR t.entity_id = p_entity_id)
    AND (t.applicable_axis_id IS NULL OR t.applicable_axis_id = p_axis_id)
    AND (
      t.applicable_account_pattern IS NULL
      OR p_account_number LIKE REPLACE(t.applicable_account_pattern, '%', '%')
    )
  ORDER BY
    -- Priorité: entity-specific > tenant-wide, specific pattern > generic
    CASE WHEN t.entity_id IS NOT NULL THEN 0 ELSE 1 END,
    CASE WHEN t.applicable_account_pattern IS NOT NULL THEN 0 ELSE 1 END,
    LENGTH(COALESCE(t.applicable_account_pattern, '')) DESC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION sys.find_applicable_template IS 'Trouve le template de distribution applicable pour un compte';

-- ============================================================================
-- 3. RPC CRÉATION D'ÉCRITURES ANALYTIQUES
-- ============================================================================

-- Créer une écriture analytique simple (un seul axe/valeur)
CREATE OR REPLACE FUNCTION sys.rpc_create_analytical_entry(
  p_entity_id BIGINT,
  p_journal_entry_id BIGINT,
  p_journal_entry_line_id BIGINT,
  p_axis_id BIGINT,
  p_analytical_value_id BIGINT,
  p_amount_debit DECIMAL DEFAULT 0,
  p_amount_credit DECIMAL DEFAULT 0,
  p_entry_date DATE DEFAULT CURRENT_DATE
)
RETURNS BIGINT AS $$
DECLARE
  v_tenant_id BIGINT;
  v_entry_id BIGINT;
BEGIN
  -- Récupérer le tenant
  v_tenant_id := sys.get_current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'Utilisateur non authentifié';
  END IF;

  -- Vérifier l'accès à l'entité
  IF NOT sys.check_entity_access(p_entity_id, 'WRITE') THEN
    RAISE EXCEPTION 'Accès en écriture non autorisé sur cette entité';
  END IF;

  -- Créer l'écriture analytique
  INSERT INTO sys.analytical_entries (
    tenant_id, entity_id,
    journal_entry_id, journal_entry_line_id,
    axis_id, analytical_value_id,
    amount_debit, amount_credit,
    distribution_percentage, distribution_source,
    entry_date, period_year, period_month,
    created_by
  ) VALUES (
    v_tenant_id, p_entity_id,
    p_journal_entry_id, p_journal_entry_line_id,
    p_axis_id, p_analytical_value_id,
    p_amount_debit, p_amount_credit,
    100.0000, 'MANUAL',
    p_entry_date, EXTRACT(YEAR FROM p_entry_date), EXTRACT(MONTH FROM p_entry_date),
    sys.get_current_user_id()
  )
  RETURNING id INTO v_entry_id;

  RETURN v_entry_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sys.rpc_create_analytical_entry IS 'Crée une écriture analytique simple';

-- Créer des écritures analytiques à partir d'un template
CREATE OR REPLACE FUNCTION sys.rpc_distribute_entry_by_template(
  p_entity_id BIGINT,
  p_journal_entry_id BIGINT,
  p_journal_entry_line_id BIGINT,
  p_template_id BIGINT,
  p_amount_debit DECIMAL DEFAULT 0,
  p_amount_credit DECIMAL DEFAULT 0,
  p_entry_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  entry_id BIGINT,
  analytical_value_id BIGINT,
  value_code VARCHAR,
  distributed_debit DECIMAL,
  distributed_credit DECIMAL
) AS $$
DECLARE
  v_tenant_id BIGINT;
  v_axis_id BIGINT;
  v_validation RECORD;
  v_line RECORD;
  v_entry_id BIGINT;
  v_dist_debit DECIMAL;
  v_dist_credit DECIMAL;
BEGIN
  -- Récupérer le tenant
  v_tenant_id := sys.get_current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'Utilisateur non authentifié';
  END IF;

  -- Vérifier l'accès
  IF NOT sys.check_entity_access(p_entity_id, 'WRITE') THEN
    RAISE EXCEPTION 'Accès en écriture non autorisé sur cette entité';
  END IF;

  -- Valider le template
  SELECT * INTO v_validation FROM sys.validate_distribution_template(p_template_id);
  IF NOT v_validation.is_valid THEN
    RAISE EXCEPTION 'Template invalide: %', v_validation.error_message;
  END IF;

  -- Récupérer l'axe du template
  SELECT applicable_axis_id INTO v_axis_id
  FROM sys.analytical_distribution_templates
  WHERE id = p_template_id;

  -- Si pas d'axe spécifié, prendre l'axe de la première ligne
  IF v_axis_id IS NULL THEN
    SELECT aa.id INTO v_axis_id
    FROM sys.analytical_distribution_lines dl
    JOIN sys.analytical_values av ON av.id = dl.analytical_value_id
    JOIN sys.analytical_axes aa ON aa.id = av.axis_id
    WHERE dl.template_id = p_template_id
    LIMIT 1;
  END IF;

  -- Créer les écritures distribuées
  FOR v_line IN
    SELECT
      dl.analytical_value_id,
      av.value_code,
      dl.distribution_percentage
    FROM sys.analytical_distribution_lines dl
    JOIN sys.analytical_values av ON av.id = dl.analytical_value_id
    WHERE dl.template_id = p_template_id
      AND dl.is_active = TRUE
      AND (dl.valid_to IS NULL OR dl.valid_to >= CURRENT_DATE)
    ORDER BY dl.distribution_order
  LOOP
    -- Calculer les montants distribués
    v_dist_debit := ROUND(p_amount_debit * v_line.distribution_percentage / 100, 2);
    v_dist_credit := ROUND(p_amount_credit * v_line.distribution_percentage / 100, 2);

    -- Créer l'écriture
    INSERT INTO sys.analytical_entries (
      tenant_id, entity_id,
      journal_entry_id, journal_entry_line_id,
      axis_id, analytical_value_id,
      amount_debit, amount_credit,
      distribution_percentage, distribution_source, template_id,
      entry_date, period_year, period_month,
      created_by
    ) VALUES (
      v_tenant_id, p_entity_id,
      p_journal_entry_id, p_journal_entry_line_id,
      v_axis_id, v_line.analytical_value_id,
      v_dist_debit, v_dist_credit,
      v_line.distribution_percentage, 'TEMPLATE', p_template_id,
      p_entry_date, EXTRACT(YEAR FROM p_entry_date), EXTRACT(MONTH FROM p_entry_date),
      sys.get_current_user_id()
    )
    RETURNING id INTO v_entry_id;

    -- Retourner la ligne
    entry_id := v_entry_id;
    analytical_value_id := v_line.analytical_value_id;
    value_code := v_line.value_code;
    distributed_debit := v_dist_debit;
    distributed_credit := v_dist_credit;
    RETURN NEXT;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sys.rpc_distribute_entry_by_template IS 'Distribue une écriture selon un template';

-- Distribution automatique basée sur le compte
CREATE OR REPLACE FUNCTION sys.rpc_auto_distribute_entry(
  p_entity_id BIGINT,
  p_journal_entry_id BIGINT,
  p_journal_entry_line_id BIGINT,
  p_account_number VARCHAR,
  p_amount_debit DECIMAL DEFAULT 0,
  p_amount_credit DECIMAL DEFAULT 0,
  p_entry_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  entry_id BIGINT,
  analytical_value_id BIGINT,
  value_code VARCHAR,
  distributed_debit DECIMAL,
  distributed_credit DECIMAL,
  template_used VARCHAR
) AS $$
DECLARE
  v_tenant_id BIGINT;
  v_template RECORD;
BEGIN
  v_tenant_id := sys.get_current_tenant_id();

  -- Chercher un template applicable
  SELECT * INTO v_template
  FROM sys.find_applicable_template(v_tenant_id, p_entity_id, p_account_number);

  IF v_template.template_id IS NULL THEN
    -- Pas de template, créer une entrée sans ventilation analytique
    RAISE NOTICE 'Aucun template de distribution trouvé pour le compte %', p_account_number;
    RETURN;
  END IF;

  -- Appliquer le template
  RETURN QUERY
  SELECT
    e.entry_id,
    e.analytical_value_id,
    e.value_code,
    e.distributed_debit,
    e.distributed_credit,
    v_template.template_code AS template_used
  FROM sys.rpc_distribute_entry_by_template(
    p_entity_id,
    p_journal_entry_id,
    p_journal_entry_line_id,
    v_template.template_id,
    p_amount_debit,
    p_amount_credit,
    p_entry_date
  ) e;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sys.rpc_auto_distribute_entry IS 'Distribution automatique basée sur le compte';

-- ============================================================================
-- 4. REPORTING ANALYTIQUE
-- ============================================================================

-- Balance analytique par axe et période
CREATE OR REPLACE FUNCTION sys.rpc_analytical_balance(
  p_entity_id BIGINT,
  p_axis_id BIGINT,
  p_year INT,
  p_month_start INT DEFAULT 1,
  p_month_end INT DEFAULT 12,
  p_account_pattern VARCHAR DEFAULT '%'
)
RETURNS TABLE (
  analytical_value_id BIGINT,
  value_code VARCHAR,
  value_name VARCHAR,
  parent_value_id BIGINT,
  level INT,
  total_debit DECIMAL,
  total_credit DECIMAL,
  balance DECIMAL
) AS $$
BEGIN
  -- Vérifier l'accès
  IF NOT sys.check_entity_access(p_entity_id, 'READ') THEN
    RAISE EXCEPTION 'Accès non autorisé à cette entité';
  END IF;

  RETURN QUERY
  WITH entry_totals AS (
    SELECT
      ae.analytical_value_id,
      SUM(ae.amount_debit) AS total_debit,
      SUM(ae.amount_credit) AS total_credit
    FROM sys.analytical_entries ae
    WHERE ae.entity_id = p_entity_id
      AND ae.axis_id = p_axis_id
      AND ae.period_year = p_year
      AND ae.period_month BETWEEN p_month_start AND p_month_end
    GROUP BY ae.analytical_value_id
  )
  SELECT
    av.id AS analytical_value_id,
    av.value_code,
    av.value_name,
    av.parent_value_id,
    av.level,
    COALESCE(et.total_debit, 0) AS total_debit,
    COALESCE(et.total_credit, 0) AS total_credit,
    COALESCE(et.total_debit, 0) - COALESCE(et.total_credit, 0) AS balance
  FROM sys.analytical_values av
  LEFT JOIN entry_totals et ON et.analytical_value_id = av.id
  WHERE av.axis_id = p_axis_id
    AND av.is_active = TRUE
    AND av.deleted_at IS NULL
  ORDER BY av.value_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION sys.rpc_analytical_balance IS 'Balance analytique par axe et période';

-- Compte de résultat analytique
CREATE OR REPLACE FUNCTION sys.rpc_analytical_income_statement(
  p_entity_id BIGINT,
  p_axis_id BIGINT,
  p_analytical_value_id BIGINT,
  p_year INT,
  p_month_start INT DEFAULT 1,
  p_month_end INT DEFAULT 12
)
RETURNS TABLE (
  account_class VARCHAR,
  account_number VARCHAR,
  account_label VARCHAR,
  total_debit DECIMAL,
  total_credit DECIMAL,
  balance DECIMAL
) AS $$
BEGIN
  -- Vérifier l'accès
  IF NOT sys.check_entity_access(p_entity_id, 'READ') THEN
    RAISE EXCEPTION 'Accès non autorisé à cette entité';
  END IF;

  RETURN QUERY
  SELECT
    CASE
      WHEN LEFT(cad.account_number, 1) = '6' THEN 'CHARGES'
      WHEN LEFT(cad.account_number, 1) = '7' THEN 'PRODUITS'
      ELSE 'AUTRES'
    END AS account_class,
    cad.account_number,
    cad.account_label,
    COALESCE(SUM(ae.amount_debit), 0) AS total_debit,
    COALESCE(SUM(ae.amount_credit), 0) AS total_credit,
    COALESCE(SUM(ae.amount_debit), 0) - COALESCE(SUM(ae.amount_credit), 0) AS balance
  FROM sys.analytical_entries ae
  JOIN common.chart_of_accounts_details cad ON cad.account_number = ae.journal_entry_line_id::VARCHAR -- Simplification
  WHERE ae.entity_id = p_entity_id
    AND ae.axis_id = p_axis_id
    AND ae.analytical_value_id = p_analytical_value_id
    AND ae.period_year = p_year
    AND ae.period_month BETWEEN p_month_start AND p_month_end
    AND LEFT(cad.account_number, 1) IN ('6', '7')
  GROUP BY cad.account_number, cad.account_label
  ORDER BY cad.account_number;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION sys.rpc_analytical_income_statement IS 'Compte de résultat par centre analytique';

-- Budget vs Réel analytique détaillé
CREATE OR REPLACE FUNCTION sys.rpc_budget_vs_actual_analytical(
  p_entity_id BIGINT,
  p_axis_id BIGINT,
  p_fiscal_year INT,
  p_month INT DEFAULT NULL,
  p_analytical_value_id BIGINT DEFAULT NULL
)
RETURNS TABLE (
  analytical_value_id BIGINT,
  value_code VARCHAR,
  value_name VARCHAR,
  account_number VARCHAR,
  budget_amount DECIMAL,
  actual_amount DECIMAL,
  variance_amount DECIMAL,
  variance_percentage DECIMAL,
  status VARCHAR
) AS $$
BEGIN
  -- Vérifier l'accès
  IF NOT sys.check_entity_access(p_entity_id, 'READ') THEN
    RAISE EXCEPTION 'Accès non autorisé à cette entité';
  END IF;

  RETURN QUERY
  WITH budget_data AS (
    SELECT
      bl.analytical_value_id,
      bl.account_number,
      SUM(bl.amount_net) AS budget_amount
    FROM sys.budget_lines bl
    JOIN sys.budget_versions bv ON bv.id = bl.budget_version_id
    WHERE bl.entity_id = p_entity_id
      AND bv.fiscal_year = p_fiscal_year
      AND bv.is_approved = TRUE
      AND (p_month IS NULL OR bl.period_month <= p_month)
      AND (p_analytical_value_id IS NULL OR bl.analytical_value_id = p_analytical_value_id)
    GROUP BY bl.analytical_value_id, bl.account_number
  ),
  actual_data AS (
    SELECT
      ae.analytical_value_id,
      NULL::VARCHAR AS account_number, -- À joindre avec les écritures réelles
      SUM(ae.amount_net) AS actual_amount
    FROM sys.analytical_entries ae
    WHERE ae.entity_id = p_entity_id
      AND ae.axis_id = p_axis_id
      AND ae.period_year = p_fiscal_year
      AND (p_month IS NULL OR ae.period_month <= p_month)
      AND (p_analytical_value_id IS NULL OR ae.analytical_value_id = p_analytical_value_id)
    GROUP BY ae.analytical_value_id
  )
  SELECT
    av.id AS analytical_value_id,
    av.value_code,
    av.value_name,
    COALESCE(bd.account_number, '') AS account_number,
    COALESCE(bd.budget_amount, 0) AS budget_amount,
    COALESCE(ad.actual_amount, 0) AS actual_amount,
    COALESCE(ad.actual_amount, 0) - COALESCE(bd.budget_amount, 0) AS variance_amount,
    CASE
      WHEN COALESCE(bd.budget_amount, 0) = 0 THEN 0
      ELSE ROUND(((COALESCE(ad.actual_amount, 0) - COALESCE(bd.budget_amount, 0)) / ABS(bd.budget_amount)) * 100, 2)
    END AS variance_percentage,
    CASE
      WHEN COALESCE(bd.budget_amount, 0) = 0 THEN 'NO_BUDGET'
      WHEN ABS(COALESCE(ad.actual_amount, 0) - COALESCE(bd.budget_amount, 0)) / ABS(bd.budget_amount) <= 0.05 THEN 'ON_TRACK'
      WHEN COALESCE(ad.actual_amount, 0) > COALESCE(bd.budget_amount, 0) THEN 'OVER_BUDGET'
      ELSE 'UNDER_BUDGET'
    END AS status
  FROM sys.analytical_values av
  LEFT JOIN budget_data bd ON bd.analytical_value_id = av.id
  LEFT JOIN actual_data ad ON ad.analytical_value_id = av.id
  WHERE av.axis_id = p_axis_id
    AND av.is_active = TRUE
    AND (p_analytical_value_id IS NULL OR av.id = p_analytical_value_id)
  ORDER BY av.value_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION sys.rpc_budget_vs_actual_analytical IS 'Comparaison Budget vs Réel par centre analytique';

-- Évolution mensuelle par centre analytique
CREATE OR REPLACE FUNCTION sys.rpc_analytical_monthly_evolution(
  p_entity_id BIGINT,
  p_axis_id BIGINT,
  p_analytical_value_id BIGINT,
  p_year INT
)
RETURNS TABLE (
  month_number INT,
  month_name VARCHAR,
  total_debit DECIMAL,
  total_credit DECIMAL,
  balance DECIMAL,
  cumulative_balance DECIMAL
) AS $$
BEGIN
  -- Vérifier l'accès
  IF NOT sys.check_entity_access(p_entity_id, 'READ') THEN
    RAISE EXCEPTION 'Accès non autorisé à cette entité';
  END IF;

  RETURN QUERY
  WITH monthly_data AS (
    SELECT
      ae.period_month,
      SUM(ae.amount_debit) AS total_debit,
      SUM(ae.amount_credit) AS total_credit
    FROM sys.analytical_entries ae
    WHERE ae.entity_id = p_entity_id
      AND ae.axis_id = p_axis_id
      AND ae.analytical_value_id = p_analytical_value_id
      AND ae.period_year = p_year
    GROUP BY ae.period_month
  ),
  all_months AS (
    SELECT generate_series(1, 12) AS month_num
  )
  SELECT
    am.month_num AS month_number,
    TO_CHAR(TO_DATE(am.month_num::TEXT, 'MM'), 'TMMonth') AS month_name,
    COALESCE(md.total_debit, 0) AS total_debit,
    COALESCE(md.total_credit, 0) AS total_credit,
    COALESCE(md.total_debit, 0) - COALESCE(md.total_credit, 0) AS balance,
    SUM(COALESCE(md.total_debit, 0) - COALESCE(md.total_credit, 0))
      OVER (ORDER BY am.month_num) AS cumulative_balance
  FROM all_months am
  LEFT JOIN monthly_data md ON md.period_month = am.month_num
  ORDER BY am.month_num;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION sys.rpc_analytical_monthly_evolution IS 'Évolution mensuelle par centre analytique';

-- ============================================================================
-- 5. GESTION DES TEMPLATES
-- ============================================================================

-- Créer un template de distribution
CREATE OR REPLACE FUNCTION sys.rpc_create_distribution_template(
  p_template_code VARCHAR,
  p_template_name VARCHAR,
  p_entity_id BIGINT DEFAULT NULL,
  p_applicable_account_pattern VARCHAR DEFAULT NULL,
  p_applicable_axis_id BIGINT DEFAULT NULL,
  p_is_mandatory BOOLEAN DEFAULT FALSE,
  p_description TEXT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
  v_tenant_id BIGINT;
  v_template_id BIGINT;
BEGIN
  v_tenant_id := sys.get_current_tenant_id();
  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'Utilisateur non authentifié';
  END IF;

  INSERT INTO sys.analytical_distribution_templates (
    tenant_id, entity_id, template_code, template_name,
    applicable_account_pattern, applicable_axis_id,
    is_mandatory, description, created_by
  ) VALUES (
    v_tenant_id, p_entity_id, p_template_code, p_template_name,
    p_applicable_account_pattern, p_applicable_axis_id,
    p_is_mandatory, p_description, sys.get_current_user_id()
  )
  RETURNING id INTO v_template_id;

  RETURN v_template_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sys.rpc_create_distribution_template IS 'Crée un template de distribution analytique';

-- Ajouter une ligne à un template
CREATE OR REPLACE FUNCTION sys.rpc_add_template_line(
  p_template_id BIGINT,
  p_analytical_value_id BIGINT,
  p_distribution_percentage DECIMAL,
  p_distribution_order INT DEFAULT 0
)
RETURNS BIGINT AS $$
DECLARE
  v_line_id BIGINT;
  v_current_total DECIMAL;
BEGIN
  -- Vérifier le total actuel
  SELECT COALESCE(SUM(distribution_percentage), 0)
  INTO v_current_total
  FROM sys.analytical_distribution_lines
  WHERE template_id = p_template_id AND is_active = TRUE;

  IF v_current_total + p_distribution_percentage > 100 THEN
    RAISE EXCEPTION 'Le total dépasserait 100%% (actuel: %, ajout: %)',
      v_current_total, p_distribution_percentage;
  END IF;

  INSERT INTO sys.analytical_distribution_lines (
    template_id, analytical_value_id,
    distribution_percentage, distribution_order,
    created_by
  ) VALUES (
    p_template_id, p_analytical_value_id,
    p_distribution_percentage, p_distribution_order,
    sys.get_current_user_id()
  )
  RETURNING id INTO v_line_id;

  RETURN v_line_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sys.rpc_add_template_line IS 'Ajoute une ligne à un template de distribution';

-- ============================================================================
-- 6. VUES ANALYTIQUES
-- ============================================================================

CREATE OR REPLACE VIEW sys.v_analytical_summary AS
SELECT
  ae.tenant_id,
  ae.entity_id,
  te.entity_name,
  ae.axis_id,
  aa.axis_code,
  aa.axis_name,
  ae.analytical_value_id,
  av.value_code,
  av.value_name,
  ae.period_year,
  ae.period_month,
  SUM(ae.amount_debit) AS total_debit,
  SUM(ae.amount_credit) AS total_credit,
  SUM(ae.amount_net) AS total_net,
  COUNT(*) AS entry_count
FROM sys.analytical_entries ae
JOIN sys.tenant_entities te ON te.id = ae.entity_id
JOIN sys.analytical_axes aa ON aa.id = ae.axis_id
JOIN sys.analytical_values av ON av.id = ae.analytical_value_id
GROUP BY
  ae.tenant_id, ae.entity_id, te.entity_name,
  ae.axis_id, aa.axis_code, aa.axis_name,
  ae.analytical_value_id, av.value_code, av.value_name,
  ae.period_year, ae.period_month;

COMMENT ON VIEW sys.v_analytical_summary IS 'Résumé analytique par entité, axe, valeur et période';

CREATE OR REPLACE VIEW sys.v_distribution_templates_status AS
SELECT
  t.id AS template_id,
  t.tenant_id,
  t.template_code,
  t.template_name,
  t.applicable_account_pattern,
  t.is_mandatory,
  t.is_active,
  COUNT(dl.id) AS line_count,
  COALESCE(SUM(dl.distribution_percentage), 0) AS total_percentage,
  CASE
    WHEN COALESCE(SUM(dl.distribution_percentage), 0) = 100 THEN 'VALID'
    WHEN COALESCE(SUM(dl.distribution_percentage), 0) < 100 THEN 'INCOMPLETE'
    ELSE 'OVER_100'
  END AS validation_status
FROM sys.analytical_distribution_templates t
LEFT JOIN sys.analytical_distribution_lines dl ON dl.template_id = t.id AND dl.is_active = TRUE
WHERE t.deleted_at IS NULL
GROUP BY t.id, t.tenant_id, t.template_code, t.template_name,
         t.applicable_account_pattern, t.is_mandatory, t.is_active;

COMMENT ON VIEW sys.v_distribution_templates_status IS 'Statut des templates de distribution';

-- ============================================================================
-- 7. PERMISSIONS SUPABASE
-- ============================================================================

GRANT SELECT, INSERT, UPDATE ON sys.analytical_distribution_templates TO authenticated;
GRANT SELECT, INSERT, UPDATE ON sys.analytical_distribution_lines TO authenticated;
GRANT SELECT, INSERT, UPDATE ON sys.analytical_entries TO authenticated;

GRANT ALL ON sys.analytical_distribution_templates TO service_role;
GRANT ALL ON sys.analytical_distribution_lines TO service_role;
GRANT ALL ON sys.analytical_entries TO service_role;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA sys TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA sys TO service_role;

-- ============================================================================
DO $$ BEGIN RAISE NOTICE '✅ RUBIS Analytical Distribution RPC créé avec succès'; END $$;
