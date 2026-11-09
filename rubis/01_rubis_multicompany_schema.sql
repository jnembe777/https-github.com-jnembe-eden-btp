-- ============================================================================
-- EDENFIN RUBIS — SCRIPT 01 : MULTI-COMPANY ARCHITECTURE
-- PostgreSQL 15+ (Supabase)
-- ============================================================================
-- Tier RUBIS : PME (10-50 employés)
-- Fonctionnalités ajoutées :
--   - Multi-entités juridiques complètes
--   - Comptabilité analytique (centres de coûts, axes)
--   - Transactions inter-sociétés
--   - Budgets par entité et centre analytique
--   - Reporting consolidé
-- ============================================================================

-- Extension du schéma sys pour RUBIS
-- (Les tables de base viennent de JASPE, on ajoute les extensions RUBIS)

-- ============================================================================
-- 1. CENTRES ANALYTIQUES (Cost Centers)
-- ============================================================================

-- Axes analytiques (dimensions d'analyse)
CREATE TABLE IF NOT EXISTS sys.analytical_axes (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
  axis_code VARCHAR(20) NOT NULL,
  axis_name VARCHAR(100) NOT NULL,
  axis_type VARCHAR(30) NOT NULL CHECK (axis_type IN (
    'COST_CENTER',      -- Centre de coûts
    'PROFIT_CENTER',    -- Centre de profit
    'PROJECT',          -- Projet
    'DEPARTMENT',       -- Département
    'PRODUCT_LINE',     -- Ligne de produits
    'REGION',           -- Région géographique
    'CUSTOMER_SEGMENT', -- Segment client
    'CUSTOM'            -- Personnalisé
  )),
  is_mandatory BOOLEAN NOT NULL DEFAULT FALSE,
  display_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  description TEXT,
  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  deleted_at TIMESTAMPTZ,
  deleted_by BIGINT,
  version_number INT NOT NULL DEFAULT 1,
  UNIQUE(tenant_id, axis_code)
);

CREATE INDEX idx_analytical_axes_tenant ON sys.analytical_axes(tenant_id, is_active);
COMMENT ON TABLE sys.analytical_axes IS 'Axes analytiques pour la comptabilité analytique (RUBIS+)';

-- Valeurs des axes analytiques
CREATE TABLE IF NOT EXISTS sys.analytical_values (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
  axis_id BIGINT NOT NULL REFERENCES sys.analytical_axes(id),
  entity_id BIGINT REFERENCES sys.tenant_entities(id), -- NULL = toutes entités
  value_code VARCHAR(30) NOT NULL,
  value_name VARCHAR(200) NOT NULL,
  parent_value_id BIGINT REFERENCES sys.analytical_values(id),
  level INT NOT NULL DEFAULT 1,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
  valid_to DATE,
  -- Budget tracking
  has_budget BOOLEAN NOT NULL DEFAULT FALSE,
  budget_responsible_id BIGINT REFERENCES sys.users(id),
  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  deleted_at TIMESTAMPTZ,
  deleted_by BIGINT,
  version_number INT NOT NULL DEFAULT 1,
  UNIQUE(tenant_id, axis_id, value_code)
);

CREATE INDEX idx_analytical_values_axis ON sys.analytical_values(axis_id, is_active);
CREATE INDEX idx_analytical_values_entity ON sys.analytical_values(entity_id);
CREATE INDEX idx_analytical_values_parent ON sys.analytical_values(parent_value_id);
COMMENT ON TABLE sys.analytical_values IS 'Valeurs des axes analytiques (centres de coûts, projets, etc.)';

-- ============================================================================
-- 2. INTER-COMPANY RELATIONSHIPS
-- ============================================================================

-- Relations inter-sociétés (pour éliminations en consolidation)
CREATE TABLE IF NOT EXISTS sys.intercompany_relationships (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
  source_entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),
  target_entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),
  relationship_type VARCHAR(30) NOT NULL CHECK (relationship_type IN (
    'PARENT_SUBSIDIARY',    -- Mère-fille
    'SISTER_COMPANY',       -- Sociétés sœurs
    'BRANCH',               -- Succursale
    'JOINT_VENTURE',        -- Co-entreprise
    'ASSOCIATE'             -- Entreprise associée
  )),
  ownership_percentage DECIMAL(5,2) CHECK (ownership_percentage >= 0 AND ownership_percentage <= 100),
  control_type VARCHAR(20) CHECK (control_type IN ('FULL', 'JOINT', 'SIGNIFICANT_INFLUENCE', 'NONE')),
  -- Comptes inter-sociétés pour lettrage automatique
  ic_receivable_account VARCHAR(20), -- Compte clients inter-co
  ic_payable_account VARCHAR(20),    -- Compte fournisseurs inter-co
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
  end_date DATE,
  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  UNIQUE(tenant_id, source_entity_id, target_entity_id),
  CHECK (source_entity_id != target_entity_id)
);

CREATE INDEX idx_intercompany_tenant ON sys.intercompany_relationships(tenant_id, is_active);
CREATE INDEX idx_intercompany_source ON sys.intercompany_relationships(source_entity_id);
CREATE INDEX idx_intercompany_target ON sys.intercompany_relationships(target_entity_id);
COMMENT ON TABLE sys.intercompany_relationships IS 'Relations entre entités du groupe pour consolidation';

-- Transactions inter-sociétés
CREATE TABLE IF NOT EXISTS sys.intercompany_transactions (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
  transaction_ref VARCHAR(50) NOT NULL,
  source_entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),
  target_entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),
  transaction_date DATE NOT NULL,
  transaction_type VARCHAR(30) NOT NULL CHECK (transaction_type IN (
    'SALE',           -- Vente inter-co
    'PURCHASE',       -- Achat inter-co
    'SERVICE',        -- Prestation de services
    'LOAN',           -- Prêt inter-co
    'DIVIDEND',       -- Dividende
    'MANAGEMENT_FEE', -- Frais de gestion
    'ROYALTY',        -- Redevance
    'OTHER'           -- Autre
  )),
  amount_source_currency DECIMAL(18,2) NOT NULL,
  source_currency CHAR(3) NOT NULL,
  amount_target_currency DECIMAL(18,2) NOT NULL,
  target_currency CHAR(3) NOT NULL,
  exchange_rate DECIMAL(18,8),
  -- Références aux écritures comptables
  source_journal_entry_id BIGINT,  -- FK vers client.journal_entries
  target_journal_entry_id BIGINT,
  -- Statut de réconciliation
  reconciliation_status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (
    reconciliation_status IN ('PENDING', 'MATCHED', 'PARTIAL', 'DISPUTED', 'ELIMINATED')
  ),
  reconciled_at TIMESTAMPTZ,
  reconciled_by BIGINT REFERENCES sys.users(id),
  -- Pour consolidation
  elimination_status VARCHAR(20) NOT NULL DEFAULT 'NOT_ELIMINATED' CHECK (
    elimination_status IN ('NOT_ELIMINATED', 'ELIMINATED', 'PARTIAL_ELIMINATION')
  ),
  elimination_amount DECIMAL(18,2),
  description TEXT,
  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  UNIQUE(tenant_id, transaction_ref)
);

CREATE INDEX idx_ic_transactions_tenant ON sys.intercompany_transactions(tenant_id);
CREATE INDEX idx_ic_transactions_date ON sys.intercompany_transactions(transaction_date DESC);
CREATE INDEX idx_ic_transactions_source ON sys.intercompany_transactions(source_entity_id);
CREATE INDEX idx_ic_transactions_target ON sys.intercompany_transactions(target_entity_id);
CREATE INDEX idx_ic_transactions_status ON sys.intercompany_transactions(reconciliation_status);
COMMENT ON TABLE sys.intercompany_transactions IS 'Transactions entre sociétés du groupe';

-- ============================================================================
-- 3. ENTITY-SPECIFIC CHART OF ACCOUNTS
-- ============================================================================

-- Plan comptable par entité (extension de common.chart_of_accounts_templates)
CREATE TABLE IF NOT EXISTS sys.entity_chart_of_accounts (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
  entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),
  base_template_id BIGINT NOT NULL REFERENCES common.chart_of_accounts_templates(id),
  coa_name VARCHAR(200) NOT NULL,
  fiscal_year_start VARCHAR(5) NOT NULL DEFAULT '01-01', -- MM-DD
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  deleted_at TIMESTAMPTZ,
  deleted_by BIGINT,
  version_number INT NOT NULL DEFAULT 1,
  UNIQUE(tenant_id, entity_id)
);

CREATE INDEX idx_entity_coa_entity ON sys.entity_chart_of_accounts(entity_id);
COMMENT ON TABLE sys.entity_chart_of_accounts IS 'Plan comptable spécifique par entité';

-- Personnalisations de comptes par entité
CREATE TABLE IF NOT EXISTS sys.entity_account_customizations (
  id BIGSERIAL PRIMARY KEY,
  entity_coa_id BIGINT NOT NULL REFERENCES sys.entity_chart_of_accounts(id),
  base_account_id BIGINT REFERENCES common.chart_of_accounts_details(id),
  -- Champs personnalisables
  custom_account_number VARCHAR(20),
  custom_account_label VARCHAR(500),
  is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  is_detail_required BOOLEAN NOT NULL DEFAULT FALSE, -- Saisie détail obligatoire
  default_analytical_axis_id BIGINT REFERENCES sys.analytical_axes(id),
  default_analytical_value_id BIGINT REFERENCES sys.analytical_values(id),
  -- Contrôles de saisie
  min_amount DECIMAL(18,2),
  max_amount DECIMAL(18,2),
  requires_approval_above DECIMAL(18,2),
  -- Compte personnalisé (si pas basé sur template)
  is_custom_account BOOLEAN NOT NULL DEFAULT FALSE,
  account_type VARCHAR(50) CHECK (account_type IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE')),
  normal_balance VARCHAR(10) CHECK (normal_balance IN ('DEBIT', 'CREDIT')),
  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT
);

CREATE INDEX idx_entity_account_custom_coa ON sys.entity_account_customizations(entity_coa_id);
COMMENT ON TABLE sys.entity_account_customizations IS 'Personnalisations de comptes par entité';

-- ============================================================================
-- 4. CONSOLIDATED REPORTING STRUCTURE
-- ============================================================================

-- Groupes de consolidation
CREATE TABLE IF NOT EXISTS sys.consolidation_groups (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
  group_code VARCHAR(20) NOT NULL,
  group_name VARCHAR(200) NOT NULL,
  parent_entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),
  consolidation_currency CHAR(3) NOT NULL,
  consolidation_method VARCHAR(30) NOT NULL DEFAULT 'FULL' CHECK (
    consolidation_method IN ('FULL', 'PROPORTIONAL', 'EQUITY_METHOD')
  ),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  fiscal_year_end VARCHAR(5) NOT NULL DEFAULT '12-31',
  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  UNIQUE(tenant_id, group_code)
);

CREATE INDEX idx_consolidation_groups_tenant ON sys.consolidation_groups(tenant_id);
COMMENT ON TABLE sys.consolidation_groups IS 'Groupes de consolidation comptable';

-- Membres des groupes de consolidation
CREATE TABLE IF NOT EXISTS sys.consolidation_group_members (
  id BIGSERIAL PRIMARY KEY,
  consolidation_group_id BIGINT NOT NULL REFERENCES sys.consolidation_groups(id),
  entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),
  membership_type VARCHAR(30) NOT NULL CHECK (membership_type IN (
    'PARENT',             -- Société mère
    'SUBSIDIARY_FULL',    -- Filiale intégrée globalement
    'SUBSIDIARY_PROP',    -- Filiale intégrée proportionnellement
    'ASSOCIATE',          -- Entreprise associée (mise en équivalence)
    'JOINT_VENTURE'       -- Co-entreprise
  )),
  ownership_percentage DECIMAL(5,2) NOT NULL CHECK (ownership_percentage > 0 AND ownership_percentage <= 100),
  voting_rights_percentage DECIMAL(5,2) CHECK (voting_rights_percentage >= 0 AND voting_rights_percentage <= 100),
  entry_date DATE NOT NULL DEFAULT CURRENT_DATE,
  exit_date DATE,
  -- Valeurs de consolidation
  goodwill_amount DECIMAL(18,2) DEFAULT 0,
  minority_interest_percentage DECIMAL(5,2) DEFAULT 0,
  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  UNIQUE(consolidation_group_id, entity_id)
);

CREATE INDEX idx_consol_members_group ON sys.consolidation_group_members(consolidation_group_id);
CREATE INDEX idx_consol_members_entity ON sys.consolidation_group_members(entity_id);
COMMENT ON TABLE sys.consolidation_group_members IS 'Entités membres des groupes de consolidation';

-- Périodes de consolidation
CREATE TABLE IF NOT EXISTS sys.consolidation_periods (
  id BIGSERIAL PRIMARY KEY,
  consolidation_group_id BIGINT NOT NULL REFERENCES sys.consolidation_groups(id),
  period_code VARCHAR(20) NOT NULL,
  period_name VARCHAR(100) NOT NULL,
  period_type VARCHAR(20) NOT NULL CHECK (period_type IN ('MONTHLY', 'QUARTERLY', 'YEARLY', 'CUSTOM')),
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'OPEN' CHECK (
    status IN ('OPEN', 'IN_PROGRESS', 'PENDING_REVIEW', 'CLOSED', 'LOCKED')
  ),
  -- Taux de change de clôture
  closing_exchange_rates JSONB, -- {EUR: 655.957, USD: 600.0, ...}
  average_exchange_rates JSONB,
  -- Statut de consolidation
  data_collected_at TIMESTAMPTZ,
  eliminations_completed_at TIMESTAMPTZ,
  validated_at TIMESTAMPTZ,
  validated_by BIGINT REFERENCES sys.users(id),
  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  UNIQUE(consolidation_group_id, period_code),
  CHECK (end_date >= start_date)
);

CREATE INDEX idx_consol_periods_group ON sys.consolidation_periods(consolidation_group_id);
CREATE INDEX idx_consol_periods_dates ON sys.consolidation_periods(start_date, end_date);
COMMENT ON TABLE sys.consolidation_periods IS 'Périodes de consolidation comptable';

-- ============================================================================
-- 5. BUDGETS MULTI-ENTITÉS ET ANALYTIQUES
-- ============================================================================

-- Versions de budget
CREATE TABLE IF NOT EXISTS sys.budget_versions (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
  version_code VARCHAR(30) NOT NULL,
  version_name VARCHAR(200) NOT NULL,
  version_type VARCHAR(30) NOT NULL CHECK (version_type IN (
    'INITIAL',      -- Budget initial
    'REVISED',      -- Budget révisé
    'FORECAST',     -- Prévision
    'ROLLING',      -- Budget glissant
    'WHAT_IF'       -- Simulation
  )),
  fiscal_year INT NOT NULL,
  entity_id BIGINT REFERENCES sys.tenant_entities(id), -- NULL = consolidated
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  is_approved BOOLEAN NOT NULL DEFAULT FALSE,
  approved_at TIMESTAMPTZ,
  approved_by BIGINT REFERENCES sys.users(id),
  status VARCHAR(20) NOT NULL DEFAULT 'DRAFT' CHECK (
    status IN ('DRAFT', 'SUBMITTED', 'UNDER_REVIEW', 'APPROVED', 'REJECTED', 'LOCKED')
  ),
  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  UNIQUE(tenant_id, version_code, fiscal_year)
);

CREATE INDEX idx_budget_versions_tenant ON sys.budget_versions(tenant_id, fiscal_year);
CREATE INDEX idx_budget_versions_entity ON sys.budget_versions(entity_id);
COMMENT ON TABLE sys.budget_versions IS 'Versions de budgets (initial, révisé, forecast)';

-- Lignes de budget
CREATE TABLE IF NOT EXISTS sys.budget_lines (
  id BIGSERIAL PRIMARY KEY,
  budget_version_id BIGINT NOT NULL REFERENCES sys.budget_versions(id),
  entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id),
  account_number VARCHAR(20) NOT NULL,
  -- Ventilation analytique (optionnelle)
  analytical_value_id BIGINT REFERENCES sys.analytical_values(id),
  -- Période
  period_month INT NOT NULL CHECK (period_month >= 1 AND period_month <= 12),
  -- Montants
  amount_debit DECIMAL(18,2) NOT NULL DEFAULT 0,
  amount_credit DECIMAL(18,2) NOT NULL DEFAULT 0,
  amount_net DECIMAL(18,2) GENERATED ALWAYS AS (amount_debit - amount_credit) STORED,
  currency_code CHAR(3) NOT NULL,
  -- Comparaison
  previous_year_actual DECIMAL(18,2),
  variance_to_previous DECIMAL(18,2) GENERATED ALWAYS AS (
    (amount_debit - amount_credit) - COALESCE(previous_year_actual, 0)
  ) STORED,
  notes TEXT,
  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT
);

-- Fix déploiement : une contrainte UNIQUE de table n'accepte pas d'expression
-- (COALESCE) — « syntax error at or near "(" ». On utilise un index unique sur
-- expression, qui traite analytical_value_id NULL comme 0 pour l'unicité.
-- ROLLBACK : DROP INDEX IF EXISTS sys.uq_budget_lines;
CREATE UNIQUE INDEX uq_budget_lines ON sys.budget_lines (
  budget_version_id, entity_id, account_number, COALESCE(analytical_value_id, 0), period_month
);

CREATE INDEX idx_budget_lines_version ON sys.budget_lines(budget_version_id);
CREATE INDEX idx_budget_lines_entity ON sys.budget_lines(entity_id);
CREATE INDEX idx_budget_lines_account ON sys.budget_lines(account_number);
CREATE INDEX idx_budget_lines_analytical ON sys.budget_lines(analytical_value_id);
COMMENT ON TABLE sys.budget_lines IS 'Lignes de budget par compte et période';

-- ============================================================================
-- 6. USER ENTITY ACCESS (Multi-Entity Permissions)
-- ============================================================================

-- Accès utilisateur par entité
CREATE TABLE IF NOT EXISTS sys.user_entity_access (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES sys.users(id) ON DELETE CASCADE,
  entity_id BIGINT NOT NULL REFERENCES sys.tenant_entities(id) ON DELETE CASCADE,
  access_level VARCHAR(20) NOT NULL DEFAULT 'READ' CHECK (
    access_level IN ('READ', 'WRITE', 'VALIDATE', 'ADMIN')
  ),
  can_view_salary_data BOOLEAN NOT NULL DEFAULT FALSE,
  can_approve_transactions BOOLEAN NOT NULL DEFAULT FALSE,
  approval_limit DECIMAL(18,2),
  valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
  valid_to DATE,
  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  UNIQUE(user_id, entity_id),
  CHECK (valid_to IS NULL OR valid_to > valid_from)
);

CREATE INDEX idx_user_entity_access_user ON sys.user_entity_access(user_id);
CREATE INDEX idx_user_entity_access_entity ON sys.user_entity_access(entity_id);
COMMENT ON TABLE sys.user_entity_access IS 'Droits d''accès utilisateur par entité';

-- ============================================================================
-- 7. FONCTIONS RPC RUBIS
-- ============================================================================

-- Récupérer les entités accessibles par l'utilisateur courant
CREATE OR REPLACE FUNCTION sys.get_user_accessible_entities()
RETURNS TABLE (
  entity_id BIGINT,
  entity_code VARCHAR,
  entity_name VARCHAR,
  access_level VARCHAR,
  can_approve BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    e.id AS entity_id,
    e.entity_code,
    e.entity_name,
    uea.access_level,
    uea.can_approve_transactions AS can_approve
  FROM sys.tenant_entities e
  JOIN sys.user_entity_access uea ON uea.entity_id = e.id
  JOIN sys.users u ON u.id = uea.user_id
  WHERE u.auth_user_id = auth.uid()
    AND u.is_active = TRUE
    AND e.is_active = TRUE
    AND e.deleted_at IS NULL
    AND (uea.valid_to IS NULL OR uea.valid_to >= CURRENT_DATE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION sys.get_user_accessible_entities IS 'Retourne les entités accessibles par l''utilisateur connecté';

-- Vérifier l'accès d'un utilisateur à une entité
CREATE OR REPLACE FUNCTION sys.check_entity_access(
  p_entity_id BIGINT,
  p_required_level VARCHAR DEFAULT 'READ'
)
RETURNS BOOLEAN AS $$
DECLARE
  v_access_level VARCHAR;
  v_level_order INT;
  v_required_order INT;
BEGIN
  -- Récupérer le niveau d'accès
  SELECT access_level INTO v_access_level
  FROM sys.user_entity_access uea
  JOIN sys.users u ON u.id = uea.user_id
  WHERE u.auth_user_id = auth.uid()
    AND uea.entity_id = p_entity_id
    AND (uea.valid_to IS NULL OR uea.valid_to >= CURRENT_DATE);

  IF v_access_level IS NULL THEN
    RETURN FALSE;
  END IF;

  -- Convertir en ordre numérique
  v_level_order := CASE v_access_level
    WHEN 'READ' THEN 1
    WHEN 'WRITE' THEN 2
    WHEN 'VALIDATE' THEN 3
    WHEN 'ADMIN' THEN 4
    ELSE 0
  END;

  v_required_order := CASE p_required_level
    WHEN 'READ' THEN 1
    WHEN 'WRITE' THEN 2
    WHEN 'VALIDATE' THEN 3
    WHEN 'ADMIN' THEN 4
    ELSE 0
  END;

  RETURN v_level_order >= v_required_order;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION sys.check_entity_access IS 'Vérifie si l''utilisateur a le niveau d''accès requis sur une entité';

-- Récupérer la hiérarchie analytique
CREATE OR REPLACE FUNCTION sys.get_analytical_hierarchy(
  p_axis_id BIGINT
)
RETURNS TABLE (
  value_id BIGINT,
  value_code VARCHAR,
  value_name VARCHAR,
  parent_id BIGINT,
  level INT,
  full_path TEXT
) AS $$
BEGIN
  RETURN QUERY
  WITH RECURSIVE hierarchy AS (
    -- Base: valeurs racines
    SELECT
      av.id,
      av.value_code,
      av.value_name,
      av.parent_value_id,
      av.level,
      av.value_code::TEXT AS full_path
    FROM sys.analytical_values av
    WHERE av.axis_id = p_axis_id
      AND av.parent_value_id IS NULL
      AND av.is_active = TRUE
      AND av.deleted_at IS NULL

    UNION ALL

    -- Récursion: enfants
    SELECT
      av.id,
      av.value_code,
      av.value_name,
      av.parent_value_id,
      av.level,
      h.full_path || ' > ' || av.value_code
    FROM sys.analytical_values av
    JOIN hierarchy h ON av.parent_value_id = h.id
    WHERE av.is_active = TRUE
      AND av.deleted_at IS NULL
  )
  SELECT
    h.id AS value_id,
    h.value_code,
    h.value_name,
    h.parent_value_id AS parent_id,
    h.level,
    h.full_path
  FROM hierarchy h
  ORDER BY h.full_path;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION sys.get_analytical_hierarchy IS 'Retourne la hiérarchie d''un axe analytique';

-- Dashboard budget vs réel par entité
CREATE OR REPLACE FUNCTION sys.rpc_budget_vs_actual_dashboard(
  p_entity_id BIGINT,
  p_fiscal_year INT,
  p_month INT DEFAULT NULL
)
RETURNS TABLE (
  account_number VARCHAR,
  account_label VARCHAR,
  budget_amount DECIMAL,
  actual_amount DECIMAL,
  variance_amount DECIMAL,
  variance_percentage DECIMAL,
  analytical_code VARCHAR,
  analytical_name VARCHAR
) AS $$
BEGIN
  -- Vérifier l'accès à l'entité
  IF NOT sys.check_entity_access(p_entity_id, 'READ') THEN
    RAISE EXCEPTION 'Accès non autorisé à cette entité';
  END IF;

  RETURN QUERY
  SELECT
    bl.account_number,
    COALESCE(cad.account_label, bl.account_number) AS account_label,
    SUM(bl.amount_net) AS budget_amount,
    0::DECIMAL AS actual_amount, -- À joindre avec les écritures réelles
    (0 - SUM(bl.amount_net))::DECIMAL AS variance_amount,
    CASE
      WHEN SUM(bl.amount_net) = 0 THEN 0
      ELSE ((0 - SUM(bl.amount_net)) / ABS(SUM(bl.amount_net)) * 100)::DECIMAL
    END AS variance_percentage,
    av.value_code AS analytical_code,
    av.value_name AS analytical_name
  FROM sys.budget_lines bl
  JOIN sys.budget_versions bv ON bv.id = bl.budget_version_id
  LEFT JOIN common.chart_of_accounts_details cad ON cad.account_number = bl.account_number
  LEFT JOIN sys.analytical_values av ON av.id = bl.analytical_value_id
  WHERE bl.entity_id = p_entity_id
    AND bv.fiscal_year = p_fiscal_year
    AND bv.is_approved = TRUE
    AND (p_month IS NULL OR bl.period_month <= p_month)
  GROUP BY bl.account_number, cad.account_label, av.value_code, av.value_name
  ORDER BY bl.account_number;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION sys.rpc_budget_vs_actual_dashboard IS 'Dashboard Budget vs Réel par entité';

-- ============================================================================
-- 8. VUES RUBIS
-- ============================================================================

CREATE OR REPLACE VIEW sys.v_entity_hierarchy AS
WITH RECURSIVE entity_tree AS (
  -- Racines (pas de parent)
  SELECT
    e.id, e.tenant_id, e.entity_code, e.entity_name,
    e.parent_entity_id, e.ownership_percentage, e.consolidation_method,
    1 AS level,
    e.entity_code::TEXT AS full_path,
    ARRAY[e.id] AS path_ids
  FROM sys.tenant_entities e
  WHERE e.parent_entity_id IS NULL
    AND e.deleted_at IS NULL
    AND e.is_active = TRUE

  UNION ALL

  -- Enfants
  SELECT
    e.id, e.tenant_id, e.entity_code, e.entity_name,
    e.parent_entity_id, e.ownership_percentage, e.consolidation_method,
    t.level + 1,
    t.full_path || ' > ' || e.entity_code,
    t.path_ids || e.id
  FROM sys.tenant_entities e
  JOIN entity_tree t ON e.parent_entity_id = t.id
  WHERE e.deleted_at IS NULL
    AND e.is_active = TRUE
)
SELECT * FROM entity_tree;

COMMENT ON VIEW sys.v_entity_hierarchy IS 'Hiérarchie des entités avec chemin complet';

CREATE OR REPLACE VIEW sys.v_intercompany_balances AS
SELECT
  t.tenant_id,
  t.source_entity_id,
  se.entity_name AS source_entity,
  t.target_entity_id,
  te.entity_name AS target_entity,
  t.transaction_type,
  SUM(CASE WHEN t.reconciliation_status = 'PENDING' THEN t.amount_source_currency ELSE 0 END) AS pending_amount,
  SUM(CASE WHEN t.reconciliation_status = 'MATCHED' THEN t.amount_source_currency ELSE 0 END) AS matched_amount,
  SUM(CASE WHEN t.reconciliation_status = 'DISPUTED' THEN t.amount_source_currency ELSE 0 END) AS disputed_amount,
  COUNT(*) AS transaction_count
FROM sys.intercompany_transactions t
JOIN sys.tenant_entities se ON se.id = t.source_entity_id
JOIN sys.tenant_entities te ON te.id = t.target_entity_id
GROUP BY t.tenant_id, t.source_entity_id, se.entity_name,
         t.target_entity_id, te.entity_name, t.transaction_type;

COMMENT ON VIEW sys.v_intercompany_balances IS 'Soldes inter-sociétés par paire d''entités';

-- ============================================================================
-- 9. DONNÉES INITIALES RUBIS
-- ============================================================================

-- Axes analytiques par défaut
INSERT INTO sys.analytical_axes (tenant_id, axis_code, axis_name, axis_type, is_mandatory, display_order)
SELECT
  t.id,
  'CC',
  'Centre de Coûts',
  'COST_CENTER',
  FALSE,
  1
FROM sys.tenants t
WHERE t.tier IN ('RUBIS', 'SAPHIR', 'ONYX')
ON CONFLICT (tenant_id, axis_code) DO NOTHING;

INSERT INTO sys.analytical_axes (tenant_id, axis_code, axis_name, axis_type, is_mandatory, display_order)
SELECT
  t.id,
  'PROJ',
  'Projet',
  'PROJECT',
  FALSE,
  2
FROM sys.tenants t
WHERE t.tier IN ('RUBIS', 'SAPHIR', 'ONYX')
ON CONFLICT (tenant_id, axis_code) DO NOTHING;

INSERT INTO sys.analytical_axes (tenant_id, axis_code, axis_name, axis_type, is_mandatory, display_order)
SELECT
  t.id,
  'DEPT',
  'Département',
  'DEPARTMENT',
  FALSE,
  3
FROM sys.tenants t
WHERE t.tier IN ('RUBIS', 'SAPHIR', 'ONYX')
ON CONFLICT (tenant_id, axis_code) DO NOTHING;

-- Permissions RUBIS additionnelles
INSERT INTO sys.permissions (permission_code, module_code, resource, action, description) VALUES
  -- Multi-entités
  ('MULTICOMPANY.ENTITIES.CREATE', 'MULTICOMPANY', 'ENTITIES', 'CREATE', 'Créer des entités'),
  ('MULTICOMPANY.ENTITIES.UPDATE', 'MULTICOMPANY', 'ENTITIES', 'UPDATE', 'Modifier des entités'),
  ('MULTICOMPANY.ENTITIES.DELETE', 'MULTICOMPANY', 'ENTITIES', 'DELETE', 'Supprimer des entités'),
  ('MULTICOMPANY.INTERCO.READ', 'MULTICOMPANY', 'INTERCOMPANY', 'READ', 'Consulter les transactions inter-sociétés'),
  ('MULTICOMPANY.INTERCO.CREATE', 'MULTICOMPANY', 'INTERCOMPANY', 'CREATE', 'Créer des transactions inter-sociétés'),
  ('MULTICOMPANY.INTERCO.RECONCILE', 'MULTICOMPANY', 'INTERCOMPANY', 'VALIDATE', 'Réconcilier les inter-sociétés'),
  -- Consolidation
  ('CONSOLIDATION.READ', 'CONSOLIDATION', 'CONSOLIDATED', 'READ', 'Consulter les données consolidées'),
  ('CONSOLIDATION.EXECUTE', 'CONSOLIDATION', 'CONSOLIDATED', 'CREATE', 'Exécuter une consolidation'),
  ('CONSOLIDATION.VALIDATE', 'CONSOLIDATION', 'CONSOLIDATED', 'VALIDATE', 'Valider une consolidation'),
  -- Analytique
  ('ANALYTIQUE.AXES.CREATE', 'ANALYTIQUE', 'AXES', 'CREATE', 'Créer des axes analytiques'),
  ('ANALYTIQUE.AXES.UPDATE', 'ANALYTIQUE', 'AXES', 'UPDATE', 'Modifier des axes analytiques'),
  ('ANALYTIQUE.VALUES.CREATE', 'ANALYTIQUE', 'VALUES', 'CREATE', 'Créer des centres de coûts'),
  ('ANALYTIQUE.VALUES.UPDATE', 'ANALYTIQUE', 'VALUES', 'UPDATE', 'Modifier des centres de coûts')
ON CONFLICT (permission_code) DO NOTHING;

-- ============================================================================
-- PERMISSIONS SUPABASE
-- ============================================================================

GRANT SELECT, INSERT, UPDATE ON sys.analytical_axes TO authenticated;
GRANT SELECT, INSERT, UPDATE ON sys.analytical_values TO authenticated;
GRANT SELECT, INSERT, UPDATE ON sys.intercompany_relationships TO authenticated;
GRANT SELECT, INSERT, UPDATE ON sys.intercompany_transactions TO authenticated;
GRANT SELECT, INSERT, UPDATE ON sys.entity_chart_of_accounts TO authenticated;
GRANT SELECT, INSERT, UPDATE ON sys.entity_account_customizations TO authenticated;
GRANT SELECT, INSERT, UPDATE ON sys.consolidation_groups TO authenticated;
GRANT SELECT, INSERT, UPDATE ON sys.consolidation_group_members TO authenticated;
GRANT SELECT, INSERT, UPDATE ON sys.consolidation_periods TO authenticated;
GRANT SELECT, INSERT, UPDATE ON sys.budget_versions TO authenticated;
GRANT SELECT, INSERT, UPDATE ON sys.budget_lines TO authenticated;
GRANT SELECT, INSERT, UPDATE ON sys.user_entity_access TO authenticated;

GRANT ALL ON sys.analytical_axes TO service_role;
GRANT ALL ON sys.analytical_values TO service_role;
GRANT ALL ON sys.intercompany_relationships TO service_role;
GRANT ALL ON sys.intercompany_transactions TO service_role;
GRANT ALL ON sys.entity_chart_of_accounts TO service_role;
GRANT ALL ON sys.entity_account_customizations TO service_role;
GRANT ALL ON sys.consolidation_groups TO service_role;
GRANT ALL ON sys.consolidation_group_members TO service_role;
GRANT ALL ON sys.consolidation_periods TO service_role;
GRANT ALL ON sys.budget_versions TO service_role;
GRANT ALL ON sys.budget_lines TO service_role;
GRANT ALL ON sys.user_entity_access TO service_role;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA sys TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA sys TO service_role;

-- ============================================================================
DO $$ BEGIN RAISE NOTICE '✅ RUBIS Multi-Company Schema créé avec succès'; END $$;
