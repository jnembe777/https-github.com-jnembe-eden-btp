-- ============================================================================
-- EDENFIN JASPE — SCRIPT 01 : EXTENSIONS + SCHÉMAS SYSTÈME + RBAC
-- À exécuter EN PREMIER dans Supabase SQL Editor
-- Sources consolidées : 00_extensions.sql + 02_schema_system.sql
-- ============================================================================

-- ============================================================================
-- EXTENSIONS
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================================
-- SCHÉMA SYS (Infrastructure Technique Multi-Tenant)
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS sys;

-- ────────────────────────────────────────────────────────────────────────────
-- 1. GESTION MULTI-TENANT
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE sys.tenants (
  id BIGSERIAL PRIMARY KEY,
  tenant_code VARCHAR(20) NOT NULL UNIQUE,
  company_name VARCHAR(200) NOT NULL,
  legal_form VARCHAR(100),
  siret VARCHAR(14) UNIQUE,
  vat_number VARCHAR(50),
  country_code CHAR(3) NOT NULL,
  industry_sector_id BIGINT,
  tier VARCHAR(20) NOT NULL CHECK (tier IN ('JASPE', 'RUBIS', 'SAPHIR', 'ONYX')),
  subscription_level VARCHAR(30) NOT NULL CHECK (subscription_level IN ('ESSENTIEL', 'STANDARD', 'PREMIUM', 'PROFESSIONAL', 'ENTERPRISE')),
  subscription_start_date DATE NOT NULL,
  subscription_end_date DATE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  max_users INT NOT NULL DEFAULT 3,
  max_entities INT NOT NULL DEFAULT 1,
  database_schema VARCHAR(100) NOT NULL UNIQUE,
  contact_email VARCHAR(255) NOT NULL,
  contact_phone VARCHAR(50),
  billing_email VARCHAR(255),
  default_language CHAR(2) NOT NULL DEFAULT 'fr',
  default_timezone VARCHAR(50) NOT NULL DEFAULT 'Africa/Libreville',
  default_currency CHAR(3) NOT NULL DEFAULT 'XAF',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  deleted_at TIMESTAMPTZ,
  deleted_by BIGINT,
  version_number INT NOT NULL DEFAULT 1
);

CREATE INDEX idx_tenants_code ON sys.tenants(tenant_code) WHERE deleted_at IS NULL;
CREATE INDEX idx_tenants_tier ON sys.tenants(tier, is_active);
CREATE INDEX idx_tenants_subscription ON sys.tenants(subscription_end_date) WHERE is_active = TRUE;
CREATE INDEX idx_tenants_country ON sys.tenants(country_code);
COMMENT ON TABLE sys.tenants IS 'Clients de la plateforme EdenFin (multi-tenant)';

CREATE TABLE sys.tenant_modules (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
  module_code VARCHAR(50) NOT NULL,
  module_name VARCHAR(200) NOT NULL,
  is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  enabled_date DATE NOT NULL DEFAULT CURRENT_DATE,
  disabled_date DATE,
  max_records INT,
  feature_level VARCHAR(30) CHECK (feature_level IN ('ESSENTIEL', 'STANDARD', 'PREMIUM')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  UNIQUE(tenant_id, module_code)
);

CREATE INDEX idx_tenant_modules_tenant ON sys.tenant_modules(tenant_id, is_enabled);
COMMENT ON TABLE sys.tenant_modules IS 'Modules activés pour chaque client';

CREATE TABLE sys.tenant_entities (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
  entity_code VARCHAR(20) NOT NULL,
  entity_name VARCHAR(200) NOT NULL,
  legal_form VARCHAR(100),
  siret VARCHAR(14),
  vat_number VARCHAR(50),
  country_code CHAR(3) NOT NULL,
  currency_code CHAR(3) NOT NULL,
  fiscal_year_end VARCHAR(5) NOT NULL DEFAULT '12-31',
  is_consolidation_parent BOOLEAN NOT NULL DEFAULT FALSE,
  parent_entity_id BIGINT REFERENCES sys.tenant_entities(id),
  ownership_percentage DECIMAL(5,2) CHECK (ownership_percentage >= 0 AND ownership_percentage <= 100),
  consolidation_method VARCHAR(30) CHECK (consolidation_method IN ('FULL', 'PROPORTIONAL', 'EQUITY_METHOD', 'NONE')),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  deleted_at TIMESTAMPTZ,
  deleted_by BIGINT,
  version_number INT NOT NULL DEFAULT 1,
  UNIQUE(tenant_id, entity_code)
);

CREATE INDEX idx_tenant_entities_tenant ON sys.tenant_entities(tenant_id, is_active);
COMMENT ON TABLE sys.tenant_entities IS 'Entités juridiques (réservé RUBIS+)';

-- ────────────────────────────────────────────────────────────────────────────
-- 2. UTILISATEURS (liés à Supabase Auth)
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE sys.users (
  id BIGSERIAL PRIMARY KEY,
  auth_user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
  email VARCHAR(255) NOT NULL,
  username VARCHAR(100),
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  phone VARCHAR(50),
  language CHAR(2) NOT NULL DEFAULT 'fr',
  timezone VARCHAR(50) NOT NULL DEFAULT 'Africa/Libreville',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  is_locked BOOLEAN NOT NULL DEFAULT FALSE,
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  deleted_at TIMESTAMPTZ,
  deleted_by BIGINT,
  version_number INT NOT NULL DEFAULT 1
);

CREATE INDEX idx_users_tenant ON sys.users(tenant_id, is_active);
CREATE INDEX idx_users_auth ON sys.users(auth_user_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_email ON sys.users(email) WHERE deleted_at IS NULL;
COMMENT ON TABLE sys.users IS 'Utilisateurs EdenFin liés à Supabase Auth';

CREATE TABLE sys.roles (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT REFERENCES sys.tenants(id),
  role_code VARCHAR(50) NOT NULL,
  role_name VARCHAR(100) NOT NULL,
  description TEXT,
  is_system_role BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  deleted_at TIMESTAMPTZ,
  deleted_by BIGINT,
  version_number INT NOT NULL DEFAULT 1,
  UNIQUE(tenant_id, role_code)
);

CREATE INDEX idx_roles_tenant ON sys.roles(tenant_id);
CREATE INDEX idx_roles_system ON sys.roles(is_system_role);
COMMENT ON TABLE sys.roles IS 'Rôles utilisateurs (prédéfinis et personnalisés)';

CREATE TABLE sys.permissions (
  id BIGSERIAL PRIMARY KEY,
  permission_code VARCHAR(100) NOT NULL UNIQUE,
  module_code VARCHAR(50) NOT NULL,
  resource VARCHAR(100) NOT NULL,
  action VARCHAR(30) NOT NULL CHECK (action IN ('CREATE', 'READ', 'UPDATE', 'DELETE', 'VALIDATE', 'EXPORT', 'IMPORT', 'APPROVE')),
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0
);

CREATE INDEX idx_permissions_module ON sys.permissions(module_code);
COMMENT ON TABLE sys.permissions IS 'Permissions disponibles dans le système';

CREATE TABLE sys.role_permissions (
  id BIGSERIAL PRIMARY KEY,
  role_id BIGINT NOT NULL REFERENCES sys.roles(id) ON DELETE CASCADE,
  permission_id BIGINT NOT NULL REFERENCES sys.permissions(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  UNIQUE(role_id, permission_id)
);

CREATE INDEX idx_role_permissions_role ON sys.role_permissions(role_id);
COMMENT ON TABLE sys.role_permissions IS 'Permissions associées à chaque rôle';

CREATE TABLE sys.user_roles (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES sys.users(id) ON DELETE CASCADE,
  role_id BIGINT NOT NULL REFERENCES sys.roles(id) ON DELETE CASCADE,
  entity_id BIGINT REFERENCES sys.tenant_entities(id),
  valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
  valid_to DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  UNIQUE(user_id, role_id, entity_id),
  CHECK (valid_to IS NULL OR valid_to > valid_from)
);

CREATE INDEX idx_user_roles_user ON sys.user_roles(user_id);
COMMENT ON TABLE sys.user_roles IS 'Rôles attribués aux utilisateurs';

-- ────────────────────────────────────────────────────────────────────────────
-- 3. CONFIGURATION SMARTGRID
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE sys.grid_configurations (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
  user_id BIGINT REFERENCES sys.users(id),
  grid_code VARCHAR(100) NOT NULL,
  grid_name VARCHAR(200) NOT NULL,
  description TEXT,
  data_source VARCHAR(200) NOT NULL,
  is_shared BOOLEAN NOT NULL DEFAULT FALSE,
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  access_level VARCHAR(20) NOT NULL DEFAULT 'PRIVATE' CHECK (access_level IN ('PRIVATE', 'TEAM', 'PUBLIC')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  deleted_at TIMESTAMPTZ,
  deleted_by BIGINT,
  version_number INT NOT NULL DEFAULT 1
);

CREATE INDEX idx_grid_configs_tenant ON sys.grid_configurations(tenant_id);
COMMENT ON TABLE sys.grid_configurations IS 'Configurations des grilles SmartGrid';

CREATE TABLE sys.grid_columns (
  id BIGSERIAL PRIMARY KEY,
  grid_config_id BIGINT NOT NULL REFERENCES sys.grid_configurations(id) ON DELETE CASCADE,
  column_key VARCHAR(100) NOT NULL,
  column_label VARCHAR(200) NOT NULL,
  column_type VARCHAR(30) NOT NULL CHECK (column_type IN ('TEXT', 'NUMBER', 'DATE', 'DATETIME', 'BOOLEAN', 'CURRENCY', 'PERCENTAGE', 'EMAIL', 'PHONE', 'URL')),
  data_format VARCHAR(50),
  width INT,
  is_visible BOOLEAN NOT NULL DEFAULT TRUE,
  is_sortable BOOLEAN NOT NULL DEFAULT TRUE,
  is_filterable BOOLEAN NOT NULL DEFAULT TRUE,
  is_groupable BOOLEAN NOT NULL DEFAULT FALSE,
  is_editable BOOLEAN NOT NULL DEFAULT FALSE,
  is_frozen BOOLEAN NOT NULL DEFAULT FALSE,
  display_order INT NOT NULL,
  alignment VARCHAR(10) NOT NULL DEFAULT 'LEFT' CHECK (alignment IN ('LEFT', 'CENTER', 'RIGHT')),
  aggregation_function VARCHAR(20) CHECK (aggregation_function IN ('SUM', 'AVG', 'COUNT', 'MIN', 'MAX', 'COUNT_DISTINCT')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0
);

CREATE INDEX idx_grid_columns_config ON sys.grid_columns(grid_config_id, display_order);
COMMENT ON TABLE sys.grid_columns IS 'Définition des colonnes de grilles SmartGrid';

-- ────────────────────────────────────────────────────────────────────────────
-- 4. AUDIT TRAIL
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE sys.audit_log (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL,
  user_id BIGINT,
  entity_type VARCHAR(100) NOT NULL,
  entity_id BIGINT,
  action VARCHAR(30) NOT NULL CHECK (action IN (
    'CREATE', 'UPDATE', 'DELETE', 'VALIDATE', 'CANCEL',
    'EXPORT', 'IMPORT', 'LOGIN', 'LOGOUT', 'ACCESS',
    'CLOSE_PERIOD', 'DISPOSE_ASSET', 'CALCULATE'
  )),
  old_values JSONB,
  new_values JSONB,
  changed_fields TEXT[],
  ip_address INET,
  user_agent TEXT,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_log_tenant ON sys.audit_log(tenant_id, timestamp DESC);
CREATE INDEX idx_audit_log_user ON sys.audit_log(user_id, timestamp DESC);
CREATE INDEX idx_audit_log_entity ON sys.audit_log(entity_type, entity_id);
CREATE INDEX idx_audit_log_action ON sys.audit_log(action);
COMMENT ON TABLE sys.audit_log IS 'Log d''audit complet de toutes les opérations';

-- ────────────────────────────────────────────────────────────────────────────
-- 5. NOTIFICATIONS
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE sys.notifications (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
  user_id BIGINT REFERENCES sys.users(id),
  notification_type VARCHAR(50) NOT NULL CHECK (notification_type IN ('INFO', 'WARNING', 'ERROR', 'SUCCESS', 'ALERT')),
  category VARCHAR(50) NOT NULL,
  title VARCHAR(200) NOT NULL,
  message TEXT NOT NULL,
  action_url VARCHAR(500),
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  read_at TIMESTAMPTZ,
  priority VARCHAR(20) NOT NULL DEFAULT 'NORMAL' CHECK (priority IN ('LOW', 'NORMAL', 'HIGH', 'CRITICAL')),
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0
);

CREATE INDEX idx_notifications_user ON sys.notifications(user_id, is_read, created_at DESC);
-- Fix déploiement : NOW() (STABLE) est interdit dans un prédicat d'index partiel
-- (« functions in index predicate must be marked IMMUTABLE »). Le filtrage par
-- expiration se fait à la lecture ; l'index partiel ne porte que sur les non-lues.
-- ROLLBACK : DROP INDEX IF EXISTS sys.idx_notifications_unread;
CREATE INDEX idx_notifications_unread ON sys.notifications(user_id, created_at DESC)
  WHERE is_read = FALSE;
COMMENT ON TABLE sys.notifications IS 'Notifications système pour les utilisateurs';

-- ────────────────────────────────────────────────────────────────────────────
-- 6. PARAMÈTRES SYSTÈME
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE sys.system_settings (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT REFERENCES sys.tenants(id),
  setting_category VARCHAR(50) NOT NULL,
  setting_key VARCHAR(100) NOT NULL,
  setting_value TEXT NOT NULL,
  data_type VARCHAR(20) NOT NULL CHECK (data_type IN ('STRING', 'NUMBER', 'BOOLEAN', 'JSON', 'DATE')),
  is_encrypted BOOLEAN NOT NULL DEFAULT FALSE,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ,
  updated_by BIGINT,
  UNIQUE(tenant_id, setting_category, setting_key)
);

CREATE INDEX idx_system_settings_tenant ON sys.system_settings(tenant_id);
COMMENT ON TABLE sys.system_settings IS 'Paramètres de configuration système';

-- ────────────────────────────────────────────────────────────────────────────
-- 7. FONCTIONS UTILITAIRES SUPABASE
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION sys.get_current_tenant_id()
RETURNS BIGINT AS $$
  SELECT tenant_id FROM sys.users
  WHERE auth_user_id = auth.uid()
    AND deleted_at IS NULL AND is_active = TRUE
  LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION sys.get_current_user_id()
RETURNS BIGINT AS $$
  SELECT id FROM sys.users
  WHERE auth_user_id = auth.uid()
    AND deleted_at IS NULL AND is_active = TRUE
  LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION sys.current_user_has_permission(p_permission_code VARCHAR)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1
    FROM sys.users u
    JOIN sys.user_roles ur ON ur.user_id = u.id
    JOIN sys.roles r ON r.id = ur.role_id
    JOIN sys.role_permissions rp ON rp.role_id = r.id
    JOIN sys.permissions p ON p.id = rp.permission_id
    WHERE u.auth_user_id = auth.uid()
      AND u.deleted_at IS NULL AND u.is_active = TRUE
      AND p.permission_code = p_permission_code
      AND (ur.valid_to IS NULL OR ur.valid_to >= CURRENT_DATE)
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ────────────────────────────────────────────────────────────────────────────
-- 8. VUES UTILES
-- ────────────────────────────────────────────────────────────────────────────

CREATE VIEW sys.v_active_tenants AS
SELECT
  t.id, t.tenant_code, t.company_name, t.tier, t.subscription_level,
  t.is_active, t.max_users, t.max_entities,
  COUNT(DISTINCT u.id) AS active_users_count,
  COUNT(DISTINCT e.id) AS entities_count
FROM sys.tenants t
LEFT JOIN sys.users u ON u.tenant_id = t.id AND u.is_active = TRUE AND u.deleted_at IS NULL
LEFT JOIN sys.tenant_entities e ON e.tenant_id = t.id AND e.is_active = TRUE AND e.deleted_at IS NULL
WHERE t.deleted_at IS NULL AND t.is_active = TRUE
GROUP BY t.id;

CREATE VIEW sys.v_user_permissions AS
SELECT
  u.id AS user_id, u.email, u.tenant_id, u.auth_user_id,
  p.permission_code, p.module_code, p.resource, p.action,
  r.role_code, ur.entity_id
FROM sys.users u
JOIN sys.user_roles ur ON ur.user_id = u.id
JOIN sys.roles r ON r.id = ur.role_id
JOIN sys.role_permissions rp ON rp.role_id = r.id
JOIN sys.permissions p ON p.id = rp.permission_id
WHERE u.deleted_at IS NULL AND u.is_active = TRUE
  AND (ur.valid_to IS NULL OR ur.valid_to >= CURRENT_DATE);

-- ────────────────────────────────────────────────────────────────────────────
-- 9. DONNÉES INITIALES
-- ────────────────────────────────────────────────────────────────────────────

INSERT INTO sys.permissions (permission_code, module_code, resource, action, description) VALUES
  ('COMPTA.ECRITURES.CREATE',   'COMPTABILITE',    'ECRITURES', 'CREATE',   'Créer des écritures comptables'),
  ('COMPTA.ECRITURES.READ',     'COMPTABILITE',    'ECRITURES', 'READ',     'Consulter les écritures comptables'),
  ('COMPTA.ECRITURES.UPDATE',   'COMPTABILITE',    'ECRITURES', 'UPDATE',   'Modifier les écritures comptables'),
  ('COMPTA.ECRITURES.DELETE',   'COMPTABILITE',    'ECRITURES', 'DELETE',   'Supprimer les écritures comptables'),
  ('COMPTA.ECRITURES.VALIDATE', 'COMPTABILITE',    'ECRITURES', 'VALIDATE', 'Valider les écritures comptables'),
  ('COMPTA.ECRITURES.EXPORT',   'COMPTABILITE',    'ECRITURES', 'EXPORT',   'Exporter les écritures comptables'),
  ('TRESORERIE.READ',           'TRESORERIE',      'TRESORERIE','READ',     'Consulter la trésorerie'),
  ('TRESORERIE.FORECAST',       'TRESORERIE',      'TRESORERIE','CREATE',   'Créer des prévisions de trésorerie'),
  ('PAIE.BULLETINS.CREATE',     'PAIE',            'BULLETINS', 'CREATE',   'Créer des bulletins de paie'),
  ('PAIE.BULLETINS.VALIDATE',   'PAIE',            'BULLETINS', 'VALIDATE', 'Valider des bulletins de paie'),
  ('PAIE.BULLETINS.READ',       'PAIE',            'BULLETINS', 'READ',     'Consulter les bulletins de paie'),
  ('BUDGET.CREATE',             'BUDGET',          'BUDGETS',   'CREATE',   'Créer des budgets'),
  ('BUDGET.UPDATE',             'BUDGET',          'BUDGETS',   'UPDATE',   'Modifier des budgets'),
  ('BUDGET.APPROVE',            'BUDGET',          'BUDGETS',   'APPROVE',  'Approuver des budgets'),
  ('BUDGET.READ',               'BUDGET',          'BUDGETS',   'READ',     'Consulter les budgets'),
  ('IMMO.CREATE',               'IMMOBILISATIONS', 'ASSETS',    'CREATE',   'Créer des immobilisations'),
  ('IMMO.UPDATE',               'IMMOBILISATIONS', 'ASSETS',    'UPDATE',   'Modifier des immobilisations'),
  ('IMMO.DELETE',               'IMMOBILISATIONS', 'ASSETS',    'DELETE',   'Supprimer des immobilisations'),
  ('IMMO.READ',                 'IMMOBILISATIONS', 'ASSETS',    'READ',     'Consulter les immobilisations'),
  ('REPORTING.EXPORT',          'REPORTING',       'REPORTS',   'EXPORT',   'Exporter des rapports'),
  ('REPORTING.READ',            'REPORTING',       'REPORTS',   'READ',     'Consulter les rapports'),
  ('ADMIN.USERS.CREATE',        'ADMINISTRATION',  'USERS',     'CREATE',   'Créer des utilisateurs'),
  ('ADMIN.USERS.UPDATE',        'ADMINISTRATION',  'USERS',     'UPDATE',   'Modifier des utilisateurs'),
  ('ADMIN.USERS.DELETE',        'ADMINISTRATION',  'USERS',     'DELETE',   'Supprimer des utilisateurs'),
  ('ADMIN.ROLES.CREATE',        'ADMINISTRATION',  'ROLES',     'CREATE',   'Créer des rôles'),
  ('ADMIN.ROLES.UPDATE',        'ADMINISTRATION',  'ROLES',     'UPDATE',   'Modifier des rôles'),
  ('ADMIN.SETTINGS',            'ADMINISTRATION',  'SETTINGS',  'UPDATE',   'Modifier les paramètres système')
ON CONFLICT (permission_code) DO NOTHING;

INSERT INTO sys.roles (tenant_id, role_code, role_name, description, is_system_role) VALUES
  (NULL, 'SUPER_ADMIN', 'Super Administrateur',           'Accès complet à toutes les fonctionnalités',     TRUE),
  (NULL, 'ADMIN',       'Administrateur',                 'Administrateur tenant avec gestion utilisateurs', TRUE),
  (NULL, 'DAF',         'Directeur Administratif et Financier', 'Accès complet aux fonctionnalités financières', TRUE),
  (NULL, 'COMPTABLE',   'Comptable',                      'Gestion comptabilité et saisie écritures',       TRUE),
  (NULL, 'CONTROLEUR',  'Contrôleur de Gestion',          'Analyse financière et budgets',                  TRUE),
  (NULL, 'TRESORIER',   'Trésorier',                      'Gestion de la trésorerie',                       TRUE),
  (NULL, 'RH',          'Responsable RH',                 'Gestion de la paie et des employés',             TRUE),
  (NULL, 'CONSULTANT',  'Consultant',                     'Lecture seule sur toutes les données',           TRUE)
ON CONFLICT (tenant_id, role_code) DO NOTHING;

-- SUPER_ADMIN et ADMIN : toutes les permissions
INSERT INTO sys.role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM sys.roles r CROSS JOIN sys.permissions p
WHERE r.role_code IN ('SUPER_ADMIN', 'ADMIN') AND r.is_system_role = TRUE
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- COMPTABLE : comptabilité + immobilisations + reporting lecture
INSERT INTO sys.role_permissions (role_id, permission_id)
SELECT (SELECT id FROM sys.roles WHERE role_code = 'COMPTABLE' AND is_system_role = TRUE), p.id
FROM sys.permissions p
WHERE p.module_code IN ('COMPTABILITE', 'IMMOBILISATIONS')
   OR p.permission_code IN ('TRESORERIE.READ', 'REPORTING.READ', 'REPORTING.EXPORT')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- DAF : tout sauf administration
INSERT INTO sys.role_permissions (role_id, permission_id)
SELECT (SELECT id FROM sys.roles WHERE role_code = 'DAF' AND is_system_role = TRUE), p.id
FROM sys.permissions p WHERE p.module_code != 'ADMINISTRATION'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- CONSULTANT : lecture seule
INSERT INTO sys.role_permissions (role_id, permission_id)
SELECT (SELECT id FROM sys.roles WHERE role_code = 'CONSULTANT' AND is_system_role = TRUE), p.id
FROM sys.permissions p WHERE p.action = 'READ'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Tenant de démonstration JASPE
INSERT INTO sys.tenants (
  tenant_code, company_name, legal_form, country_code, tier,
  subscription_level, subscription_start_date, is_active,
  max_users, max_entities, database_schema,
  contact_email, default_currency, default_timezone
) VALUES (
  'DEMO_001', 'Entreprise Démo OHADA', 'SARL', 'GAB', 'JASPE',
  'PREMIUM', CURRENT_DATE, TRUE,
  5, 1, 'client_demo',
  'demo@edenfin.io', 'XAF', 'Africa/Libreville'
) ON CONFLICT (tenant_code) DO NOTHING;

INSERT INTO sys.tenant_modules (tenant_id, module_code, module_name, feature_level)
SELECT t.id, m.code, m.name, 'PREMIUM'
FROM sys.tenants t
CROSS JOIN (VALUES
  ('COMPTA_SIMPLIFIEE', 'Comptabilité Simplifiée'),
  ('TRESORERIE',        'Gestion de la Trésorerie'),
  ('TABLEAU_BORD',      'Tableau de Bord'),
  ('PAIE',              'Gestion de la Paie'),
  ('IMMOBILISATIONS',   'Gestion des Immobilisations')
) AS m(code, name)
WHERE t.tenant_code = 'DEMO_001'
ON CONFLICT (tenant_id, module_code) DO NOTHING;

-- ────────────────────────────────────────────────────────────────────────────
-- PERMISSIONS SUPABASE
-- ────────────────────────────────────────────────────────────────────────────

GRANT USAGE ON SCHEMA sys TO authenticated;
GRANT USAGE ON SCHEMA sys TO service_role;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA sys TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA sys TO service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA sys TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA sys TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA sys TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA sys TO service_role;

-- ============================================================================
DO $$ BEGIN RAISE NOTICE '✅ Script 01 OK — Schémas SYS + RBAC créés';
END $$;
