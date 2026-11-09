-- ============================================================================
-- EDENFIN JASPE — SCRIPT 05 : VUES DASHBOARD + POLITIQUES RLS
-- À exécuter APRÈS le script 04
-- Source consolidée : 05_rls_policies.sql (archive)
-- ============================================================================

-- ────────────────────────────────────────────────────────────────────────────
-- A. VUES ANALYTIQUES DASHBOARD (requises par rpc_dashboard_kpi et la UI)
-- ────────────────────────────────────────────────────────────────────────────

-- Vue : synthèse mensuelle CA (attendue par le composant KpiGrid)
CREATE OR REPLACE VIEW client_demo.v_monthly_sales AS
SELECT
  fp.fiscal_year,
  fp.period_number,
  fp.start_date,
  fp.end_date,
  COALESCE(SUM(
    CASE WHEN coa.account_type = 'REVENUE'
         THEN jel.credit_amount - jel.debit_amount ELSE 0 END
  ), 0) AS ca_ht,
  COALESCE(SUM(
    CASE WHEN coa.account_type = 'EXPENSE'
         THEN jel.debit_amount - jel.credit_amount ELSE 0 END
  ), 0) AS charges,
  COALESCE(SUM(
    CASE WHEN coa.account_type = 'REVENUE'
         THEN jel.credit_amount - jel.debit_amount
         WHEN coa.account_type = 'EXPENSE'
         THEN -(jel.debit_amount - jel.credit_amount) ELSE 0 END
  ), 0) AS resultat_mensuel
FROM client_demo.fiscal_periods fp
LEFT JOIN client_demo.journal_entries je ON je.fiscal_period_id = fp.id
  AND je.status IN ('POSTED', 'VALIDATED') AND je.deleted_at IS NULL
LEFT JOIN client_demo.journal_entry_lines jel ON jel.journal_entry_id = je.id
LEFT JOIN client_demo.chart_of_accounts coa ON coa.id = jel.account_id
  AND coa.account_type IN ('REVENUE', 'EXPENSE')
GROUP BY fp.fiscal_year, fp.period_number, fp.start_date, fp.end_date
ORDER BY fp.fiscal_year, fp.period_number;

COMMENT ON VIEW client_demo.v_monthly_sales IS 'Évolution mensuelle CA / Charges / Résultat — utilisée par le Dashboard';

-- Vue : KPIs de synthèse annuelle (attendue par le composant Dashboard)
CREATE OR REPLACE VIEW client_demo.v_kpi_summary AS
SELECT
  fp.fiscal_year,
  COALESCE(SUM(
    CASE WHEN coa.account_type = 'REVENUE' THEN jel.credit_amount - jel.debit_amount ELSE 0 END
  ), 0) AS ca_annuel,
  COALESCE(SUM(
    CASE WHEN coa.account_type = 'EXPENSE' THEN jel.debit_amount - jel.credit_amount ELSE 0 END
  ), 0) AS charges_annuelles,
  COALESCE(SUM(
    CASE WHEN coa.account_type = 'REVENUE' THEN jel.credit_amount - jel.debit_amount
         WHEN coa.account_type = 'EXPENSE' THEN -(jel.debit_amount - jel.credit_amount)
         ELSE 0 END
  ), 0) AS resultat_net,
  (SELECT COALESCE(SUM(current_balance), 0)
   FROM client_demo.bank_accounts WHERE is_active = TRUE) AS tresorerie,
  -- Fix déploiement : l'effectif actif provient du CROSS JOIN `e(cnt)` ci-dessous
  -- (COUNT(*) des employés actifs). L'ancienne expression référençait e.is_active/e.id,
  -- colonnes inexistantes sur cet alias de sous-requête. ROLLBACK : rétablir l'ancien
  -- COUNT(DISTINCT CASE WHEN e.is_active ...) si le FROM réintroduit la table employees.
  e.cnt AS effectif_actif
FROM client_demo.fiscal_periods fp
LEFT JOIN client_demo.journal_entries je ON je.fiscal_period_id = fp.id
  AND je.status IN ('POSTED', 'VALIDATED') AND je.deleted_at IS NULL
LEFT JOIN client_demo.journal_entry_lines jel ON jel.journal_entry_id = je.id
LEFT JOIN client_demo.chart_of_accounts coa ON coa.id = jel.account_id
  AND coa.account_type IN ('REVENUE', 'EXPENSE')
CROSS JOIN (SELECT COUNT(*) AS cnt FROM client_demo.employees WHERE is_active = TRUE AND deleted_at IS NULL) e
GROUP BY fp.fiscal_year, e.cnt;

COMMENT ON VIEW client_demo.v_kpi_summary IS 'KPIs annuels de synthèse (CA, charges, résultat, trésorerie, effectif)';

-- Vue : encours créances clients par tiers
CREATE OR REPLACE VIEW client_demo.v_partner_balances AS
SELECT
  p.id AS partner_id,
  p.code, p.name, p.type,
  COALESCE(SUM(CASE WHEN coa.account_number LIKE '411%' THEN jel.debit_amount - jel.credit_amount ELSE 0 END), 0) AS creances_clients,
  COALESCE(SUM(CASE WHEN coa.account_number LIKE '401%' THEN jel.credit_amount - jel.debit_amount ELSE 0 END), 0) AS dettes_fournisseurs,
  COUNT(DISTINCT CASE WHEN jel.reconciliation_id IS NULL AND je.status IN ('POSTED','VALIDATED') THEN jel.id END) AS lignes_non_lettrees
FROM client_demo.partners p
LEFT JOIN client_demo.journal_entry_lines jel ON jel.partner_id = p.id
LEFT JOIN client_demo.journal_entries je ON je.id = jel.journal_entry_id
  AND je.status IN ('POSTED','VALIDATED') AND je.deleted_at IS NULL
LEFT JOIN client_demo.chart_of_accounts coa ON coa.id = jel.account_id
WHERE p.deleted_at IS NULL
GROUP BY p.id, p.code, p.name, p.type;

COMMENT ON VIEW client_demo.v_partner_balances IS 'Balance par tiers (créances clients + dettes fournisseurs)';

-- Vue : plan d'amortissement complet
CREATE OR REPLACE VIEW client_demo.v_depreciation_plan AS
SELECT
  fa.asset_number,
  fa.asset_name,
  fa.acquisition_value,
  fa.depreciation_method,
  fa.useful_life_months,
  fa.accumulated_depreciation,
  fa.net_book_value,
  fp.fiscal_year,
  fp.period_number,
  ds.depreciation_date,
  ds.depreciation_amount,
  ds.accumulated_depreciation AS cumul_at_period,
  ds.net_book_value AS vnc_at_period,
  ds.status AS schedule_status
FROM client_demo.fixed_assets fa
JOIN client_demo.depreciation_schedule ds ON ds.fixed_asset_id = fa.id
JOIN client_demo.fiscal_periods fp ON fp.id = ds.fiscal_period_id
WHERE fa.deleted_at IS NULL
ORDER BY fa.asset_number, fp.fiscal_year, fp.period_number;

COMMENT ON VIEW client_demo.v_depreciation_plan IS 'Plan d''amortissement complet toutes immobilisations';

-- Vue : bulletins de paie avec détail employé
CREATE OR REPLACE VIEW client_demo.v_payslip_summary AS
SELECT
  ps.id AS payslip_id,
  e.employee_number,
  e.first_name || ' ' || e.last_name AS employee_name,
  e.contract_type,
  ps.period_start,
  ps.period_end,
  ps.gross_salary,
  ps.net_salary,
  ps.net_taxable,
  ps.employer_contributions,
  ps.gross_salary - ps.net_salary AS employee_deductions,
  ps.gross_salary + ps.employer_contributions AS cout_total_employeur,
  ps.status,
  ps.payment_date
FROM client_demo.payslips ps
JOIN client_demo.employees e ON e.id = ps.employee_id
WHERE ps.deleted_at IS NULL
ORDER BY ps.period_start DESC, e.last_name;

COMMENT ON VIEW client_demo.v_payslip_summary IS 'Synthèse des bulletins de paie avec coût employeur';

-- Vue : déclarations sociales agrégées par période
CREATE OR REPLACE VIEW client_demo.v_social_declarations AS
SELECT
  pp.fiscal_year, pp.period_month,
  pp.start_date, pp.end_date,
  COALESCE(SUM(ps.gross_salary),            0) AS masse_salariale_brute,
  COALESCE(SUM(ps.net_salary),              0) AS total_nets,
  COALESCE(SUM(ps.employer_contributions),  0) AS total_charges_patronales,
  COALESCE(SUM(ps.gross_salary - ps.net_salary), 0) AS total_cotis_salariales,
  COUNT(ps.id) AS nb_bulletins,
  pp.status AS period_status
FROM client_demo.pay_periods pp
LEFT JOIN client_demo.payslips ps ON ps.pay_period_id = pp.id
  AND ps.deleted_at IS NULL AND ps.status != 'CANCELLED'
GROUP BY pp.id, pp.fiscal_year, pp.period_month, pp.start_date, pp.end_date, pp.status
ORDER BY pp.fiscal_year DESC, pp.period_month DESC;

COMMENT ON VIEW client_demo.v_social_declarations IS 'Agrégation mensuelle masse salariale + charges sociales';

-- ────────────────────────────────────────────────────────────────────────────
-- B. ACTIVATION RLS — SCHÉMA SYS
-- (idempotent — peut être appelé même si déjà activé dans le script 01)
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE sys.tenants          ENABLE ROW LEVEL SECURITY;
ALTER TABLE sys.users            ENABLE ROW LEVEL SECURITY;
ALTER TABLE sys.tenant_modules   ENABLE ROW LEVEL SECURITY;
ALTER TABLE sys.notifications    ENABLE ROW LEVEL SECURITY;
ALTER TABLE sys.system_settings  ENABLE ROW LEVEL SECURITY;
ALTER TABLE sys.audit_log        ENABLE ROW LEVEL SECURITY;
ALTER TABLE sys.grid_configurations ENABLE ROW LEVEL SECURITY;

-- ────────────────────────────────────────────────────────────────────────────
-- C. POLITIQUES RLS — SCHÉMA SYS
-- ────────────────────────────────────────────────────────────────────────────

-- Nettoyer les politiques précédentes (idempotence)
DROP POLICY IF EXISTS tenant_isolation         ON sys.tenants;
DROP POLICY IF EXISTS user_tenant_isolation    ON sys.users;
DROP POLICY IF EXISTS modules_tenant_isolation ON sys.tenant_modules;
DROP POLICY IF EXISTS notification_user_isolation ON sys.notifications;
DROP POLICY IF EXISTS notification_insert      ON sys.notifications;
DROP POLICY IF EXISTS settings_tenant_isolation ON sys.system_settings;
DROP POLICY IF EXISTS audit_tenant_isolation   ON sys.audit_log;
DROP POLICY IF EXISTS audit_insert             ON sys.audit_log;
DROP POLICY IF EXISTS grid_tenant_isolation    ON sys.grid_configurations;

-- Tenants : un utilisateur ne voit que son propre tenant
CREATE POLICY tenant_isolation ON sys.tenants
  FOR ALL USING (id = sys.get_current_tenant_id());

-- Users : isolation par tenant
CREATE POLICY user_tenant_isolation ON sys.users
  FOR ALL USING (tenant_id = sys.get_current_tenant_id());

-- Tenant Modules : par tenant
CREATE POLICY modules_tenant_isolation ON sys.tenant_modules
  FOR ALL USING (tenant_id = sys.get_current_tenant_id());

-- Notifications : par user ou par tenant (broadcast)
CREATE POLICY notification_user_isolation ON sys.notifications
  FOR SELECT USING (
    user_id = sys.get_current_user_id()
    OR (user_id IS NULL AND tenant_id = sys.get_current_tenant_id())
  );
CREATE POLICY notification_insert ON sys.notifications
  FOR INSERT WITH CHECK (tenant_id = sys.get_current_tenant_id());

-- System Settings : par tenant ou globaux
CREATE POLICY settings_tenant_isolation ON sys.system_settings
  FOR ALL USING (tenant_id = sys.get_current_tenant_id() OR tenant_id IS NULL);

-- Audit Log : par tenant (insert + lecture)
CREATE POLICY audit_tenant_isolation ON sys.audit_log
  FOR SELECT USING (tenant_id = sys.get_current_tenant_id());
CREATE POLICY audit_insert ON sys.audit_log
  FOR INSERT WITH CHECK (tenant_id = sys.get_current_tenant_id());

-- Grid Configurations : par tenant + niveau accès
CREATE POLICY grid_tenant_isolation ON sys.grid_configurations
  FOR ALL USING (
    tenant_id = sys.get_current_tenant_id()
    AND (
      user_id = sys.get_current_user_id()
      OR access_level IN ('TEAM', 'PUBLIC')
      OR is_default = TRUE
    )
  );

-- ────────────────────────────────────────────────────────────────────────────
-- D. FONCTION HELPER ACCÈS CLIENT_DEMO
-- Vérifie que l'utilisateur Supabase appartient au tenant du schéma
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION client_demo.user_has_access()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM sys.users u
    JOIN sys.tenants t ON t.id = u.tenant_id
    WHERE u.auth_user_id = auth.uid()
      AND u.is_active = TRUE
      AND u.deleted_at IS NULL
      AND t.database_schema = 'client_demo'
      AND t.is_active = TRUE
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ────────────────────────────────────────────────────────────────────────────
-- E. ACTIVATION RLS — SCHÉMA CLIENT_DEMO
-- (idempotent — peut être appelé même si déjà activé dans le script 03)
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
-- F. POLITIQUES RLS — SCHÉMA CLIENT_DEMO
-- ────────────────────────────────────────────────────────────────────────────

-- Supprimer les politiques précédentes (idempotence)
DROP POLICY IF EXISTS je_access             ON client_demo.journal_entries;
DROP POLICY IF EXISTS jel_access            ON client_demo.journal_entry_lines;
DROP POLICY IF EXISTS partners_access       ON client_demo.partners;
DROP POLICY IF EXISTS bank_accounts_access  ON client_demo.bank_accounts;
DROP POLICY IF EXISTS bank_transactions_access ON client_demo.bank_transactions;
DROP POLICY IF EXISTS employees_access      ON client_demo.employees;
DROP POLICY IF EXISTS employees_write       ON client_demo.employees;
DROP POLICY IF EXISTS payslips_access       ON client_demo.payslips;
DROP POLICY IF EXISTS payslips_write        ON client_demo.payslips;
DROP POLICY IF EXISTS payslip_lines_access  ON client_demo.payslip_lines;
DROP POLICY IF EXISTS fixed_assets_access   ON client_demo.fixed_assets;
DROP POLICY IF EXISTS payroll_rubrics_access ON client_demo.payroll_rubrics;
DROP POLICY IF EXISTS contribution_rates_access ON client_demo.contribution_rates;

-- Écritures comptables
CREATE POLICY je_access ON client_demo.journal_entries
  FOR ALL USING (client_demo.user_has_access());

CREATE POLICY jel_access ON client_demo.journal_entry_lines
  FOR ALL USING (client_demo.user_has_access());

-- Tiers
CREATE POLICY partners_access ON client_demo.partners
  FOR ALL USING (client_demo.user_has_access());

-- Banque
CREATE POLICY bank_accounts_access ON client_demo.bank_accounts
  FOR ALL USING (client_demo.user_has_access());

CREATE POLICY bank_transactions_access ON client_demo.bank_transactions
  FOR ALL USING (client_demo.user_has_access());

-- Employés : lecture libre pour le tenant, écriture restreinte aux rôles RH/Admin
CREATE POLICY employees_access ON client_demo.employees
  FOR SELECT USING (client_demo.user_has_access());

CREATE POLICY employees_write ON client_demo.employees
  FOR INSERT WITH CHECK (
    client_demo.user_has_access()
    AND (
      sys.current_user_has_permission('PAIE.BULLETINS.CREATE')
      OR sys.current_user_has_permission('ADMIN.USERS.CREATE')
    )
  );

-- Bulletins de paie : lecture restreinte aux rôles paie
CREATE POLICY payslips_access ON client_demo.payslips
  FOR SELECT USING (
    client_demo.user_has_access()
    AND sys.current_user_has_permission('PAIE.BULLETINS.READ')
  );

CREATE POLICY payslips_write ON client_demo.payslips
  FOR INSERT WITH CHECK (
    client_demo.user_has_access()
    AND sys.current_user_has_permission('PAIE.BULLETINS.CREATE')
  );

-- Lignes bulletins : accès via payslip (permission paie)
CREATE POLICY payslip_lines_access ON client_demo.payslip_lines
  FOR ALL USING (
    client_demo.user_has_access()
    AND sys.current_user_has_permission('PAIE.BULLETINS.READ')
  );

-- Immobilisations
CREATE POLICY fixed_assets_access ON client_demo.fixed_assets
  FOR ALL USING (client_demo.user_has_access());

-- Rubriques de paie : lecture pour le tenant (paramétrage)
CREATE POLICY payroll_rubrics_access ON client_demo.payroll_rubrics
  FOR ALL USING (client_demo.user_has_access());

-- Taux de cotisations : lecture pour le tenant (paramétrage réglementaire)
CREATE POLICY contribution_rates_access ON client_demo.contribution_rates
  FOR ALL USING (client_demo.user_has_access());

-- ────────────────────────────────────────────────────────────────────────────
-- G. GRANTS SUR LES VUES
-- ────────────────────────────────────────────────────────────────────────────

GRANT SELECT ON client_demo.v_monthly_sales       TO authenticated;
GRANT SELECT ON client_demo.v_kpi_summary          TO authenticated;
GRANT SELECT ON client_demo.v_partner_balances     TO authenticated;
GRANT SELECT ON client_demo.v_depreciation_plan    TO authenticated;
GRANT SELECT ON client_demo.v_payslip_summary      TO authenticated;
GRANT SELECT ON client_demo.v_social_declarations  TO authenticated;

-- Vues créées dans script 03
GRANT SELECT ON client_demo.v_general_ledger      TO authenticated;
GRANT SELECT ON client_demo.v_aged_receivables    TO authenticated;
GRANT SELECT ON client_demo.v_aged_payables       TO authenticated;
GRANT SELECT ON client_demo.v_income_statement    TO authenticated;
GRANT SELECT ON client_demo.v_cash_forecast_summary TO authenticated;

-- Vues common (référentiel partagé — pas de RLS)
GRANT SELECT ON common.v_active_chart_templates    TO authenticated;
GRANT SELECT ON common.v_current_exchange_rates    TO authenticated;
GRANT SELECT ON common.v_active_tax_codes          TO authenticated;

-- Vues sys
GRANT SELECT ON sys.v_active_tenants        TO authenticated;
GRANT SELECT ON sys.v_user_permissions      TO authenticated;

-- ============================================================================
DO $$ BEGIN RAISE NOTICE '✅ Script 05 OK — Vues dashboard et politiques RLS configurées';
END $$;
