-- ============================================================================
-- EDENFIN JASPE — Backend Comptabilité (Lot 2a)
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS sys;
CREATE SCHEMA IF NOT EXISTS client_demo;

-- TENANTS + USERS ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys.tenants (
  id BIGSERIAL PRIMARY KEY,
  tenant_code VARCHAR(20) NOT NULL UNIQUE,
  company_name VARCHAR(200) NOT NULL,
  legal_form VARCHAR(100),
  country_code CHAR(3) NOT NULL,
  tier VARCHAR(20) NOT NULL CHECK (tier IN ('JASPE','RUBIS','SAPHIR','ONYX')),
  subscription_level VARCHAR(30) NOT NULL,
  subscription_start_date DATE NOT NULL DEFAULT CURRENT_DATE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  database_schema VARCHAR(100) NOT NULL UNIQUE,
  contact_email VARCHAR(255) NOT NULL,
  default_currency CHAR(3) NOT NULL DEFAULT 'XAF',
  default_timezone VARCHAR(50) NOT NULL DEFAULT 'Africa/Libreville',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS sys.users (
  id BIGSERIAL PRIMARY KEY,
  auth_user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  tenant_id BIGINT NOT NULL REFERENCES sys.tenants(id),
  email VARCHAR(255) NOT NULL,
  first_name VARCHAR(100) NOT NULL DEFAULT '',
  last_name VARCHAR(100) NOT NULL DEFAULT '',
  role_code VARCHAR(30) NOT NULL DEFAULT 'COMPTABLE',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_sys_users_tenant ON sys.users(tenant_id, is_active);
CREATE INDEX IF NOT EXISTS idx_sys_users_auth ON sys.users(auth_user_id);

-- HELPERS --------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sys.get_current_tenant_id()
RETURNS BIGINT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, sys, auth AS $$
  SELECT tenant_id FROM sys.users
   WHERE auth_user_id = auth.uid() AND is_active = TRUE
   LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION sys.get_current_user_id()
RETURNS BIGINT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, sys, auth AS $$
  SELECT id FROM sys.users
   WHERE auth_user_id = auth.uid() AND is_active = TRUE
   LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION client_demo.user_has_access()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, sys, auth AS $$
  SELECT EXISTS (
    SELECT 1 FROM sys.users u
    JOIN sys.tenants t ON t.id = u.tenant_id
    WHERE u.auth_user_id = auth.uid()
      AND u.is_active = TRUE
      AND t.database_schema = 'client_demo'
      AND t.is_active = TRUE
  );
$$;

-- TABLES COMPTABILITÉ --------------------------------------------------------
CREATE TABLE IF NOT EXISTS client_demo.chart_of_accounts (
  id BIGSERIAL PRIMARY KEY,
  account_number VARCHAR(20) NOT NULL UNIQUE,
  account_label VARCHAR(500) NOT NULL,
  account_type VARCHAR(50) NOT NULL CHECK (account_type IN ('ASSET','LIABILITY','EQUITY','REVENUE','EXPENSE')),
  parent_account_id BIGINT REFERENCES client_demo.chart_of_accounts(id),
  level INT NOT NULL CHECK (level > 0),
  is_detail_account BOOLEAN NOT NULL DEFAULT TRUE,
  normal_balance VARCHAR(10) NOT NULL CHECK (normal_balance IN ('DEBIT','CREDIT')),
  financial_statement VARCHAR(50),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_cd_coa_type ON client_demo.chart_of_accounts(account_type, is_active);

CREATE TABLE IF NOT EXISTS client_demo.fiscal_periods (
  id BIGSERIAL PRIMARY KEY,
  fiscal_year INT NOT NULL,
  period_number INT NOT NULL CHECK (period_number BETWEEN 1 AND 13),
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','CLOSED','LOCKED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(fiscal_year, period_number),
  CHECK (end_date > start_date)
);

CREATE TABLE IF NOT EXISTS client_demo.journals (
  id BIGSERIAL PRIMARY KEY,
  code VARCHAR(10) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  type VARCHAR(30) NOT NULL CHECK (type IN ('SALES','PURCHASES','BANK','CASH','GENERAL','PAYROLL')),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS client_demo.partners (
  id BIGSERIAL PRIMARY KEY,
  code VARCHAR(20) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  type VARCHAR(30) NOT NULL CHECK (type IN ('CUSTOMER','SUPPLIER','BOTH','EMPLOYEE','OTHER')),
  email VARCHAR(255),
  phone VARCHAR(50),
  city VARCHAR(100),
  country_code CHAR(3) NOT NULL DEFAULT 'SN',
  payment_term_days INT DEFAULT 30,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS client_demo.journal_entries (
  id BIGSERIAL PRIMARY KEY,
  journal_id BIGINT NOT NULL REFERENCES client_demo.journals(id),
  entry_number VARCHAR(50) NOT NULL,
  entry_date DATE NOT NULL,
  fiscal_period_id BIGINT NOT NULL REFERENCES client_demo.fiscal_periods(id),
  reference VARCHAR(100),
  description VARCHAR(500) NOT NULL,
  total_debit DECIMAL(18,2) NOT NULL DEFAULT 0,
  total_credit DECIMAL(18,2) NOT NULL DEFAULT 0,
  status VARCHAR(20) NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','POSTED','VALIDATED','CANCELLED')),
  validated_by BIGINT,
  validated_at TIMESTAMPTZ,
  created_by BIGINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  UNIQUE(journal_id, entry_number)
);
CREATE INDEX IF NOT EXISTS idx_cd_je_date ON client_demo.journal_entries(entry_date DESC);
CREATE INDEX IF NOT EXISTS idx_cd_je_status ON client_demo.journal_entries(status);

CREATE TABLE IF NOT EXISTS client_demo.journal_entry_lines (
  id BIGSERIAL PRIMARY KEY,
  journal_entry_id BIGINT NOT NULL REFERENCES client_demo.journal_entries(id) ON DELETE CASCADE,
  line_number INT NOT NULL,
  account_id BIGINT NOT NULL REFERENCES client_demo.chart_of_accounts(id),
  debit_amount DECIMAL(18,2) NOT NULL DEFAULT 0,
  credit_amount DECIMAL(18,2) NOT NULL DEFAULT 0,
  description VARCHAR(500),
  partner_id BIGINT REFERENCES client_demo.partners(id),
  reconciliation_id BIGINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(journal_entry_id, line_number),
  CHECK ((debit_amount > 0 AND credit_amount = 0) OR (debit_amount = 0 AND credit_amount > 0))
);
CREATE INDEX IF NOT EXISTS idx_cd_jel_account ON client_demo.journal_entry_lines(account_id);
CREATE INDEX IF NOT EXISTS idx_cd_jel_partner ON client_demo.journal_entry_lines(partner_id);
CREATE INDEX IF NOT EXISTS idx_cd_jel_unrec ON client_demo.journal_entry_lines(account_id, partner_id) WHERE reconciliation_id IS NULL;

-- GRANTS ---------------------------------------------------------------------
GRANT USAGE ON SCHEMA sys TO authenticated, service_role;
GRANT USAGE ON SCHEMA client_demo TO authenticated, service_role;

GRANT SELECT ON sys.tenants, sys.users TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA sys TO service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA sys TO authenticated, service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA client_demo TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA client_demo TO service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA client_demo TO authenticated, service_role;

GRANT EXECUTE ON FUNCTION sys.get_current_tenant_id(), sys.get_current_user_id(), client_demo.user_has_access() TO authenticated, service_role;

-- RLS ------------------------------------------------------------------------
ALTER TABLE sys.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE sys.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_demo.chart_of_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_demo.fiscal_periods ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_demo.journals ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_demo.partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_demo.journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_demo.journal_entry_lines ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_self ON sys.tenants FOR SELECT TO authenticated USING (id = sys.get_current_tenant_id());
CREATE POLICY user_self ON sys.users FOR SELECT TO authenticated USING (tenant_id = sys.get_current_tenant_id());

CREATE POLICY coa_rw ON client_demo.chart_of_accounts FOR ALL TO authenticated USING (client_demo.user_has_access()) WITH CHECK (client_demo.user_has_access());
CREATE POLICY fp_rw  ON client_demo.fiscal_periods    FOR ALL TO authenticated USING (client_demo.user_has_access()) WITH CHECK (client_demo.user_has_access());
CREATE POLICY j_rw   ON client_demo.journals          FOR ALL TO authenticated USING (client_demo.user_has_access()) WITH CHECK (client_demo.user_has_access());
CREATE POLICY p_rw   ON client_demo.partners          FOR ALL TO authenticated USING (client_demo.user_has_access()) WITH CHECK (client_demo.user_has_access());
CREATE POLICY je_rw  ON client_demo.journal_entries   FOR ALL TO authenticated USING (client_demo.user_has_access()) WITH CHECK (client_demo.user_has_access());
CREATE POLICY jel_rw ON client_demo.journal_entry_lines FOR ALL TO authenticated USING (client_demo.user_has_access()) WITH CHECK (client_demo.user_has_access());

-- TRIGGER : provisioning user à l'inscription -------------------------------
CREATE OR REPLACE FUNCTION sys.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, sys, auth AS $$
DECLARE
  v_tenant_id BIGINT;
BEGIN
  SELECT id INTO v_tenant_id FROM sys.tenants WHERE database_schema = 'client_demo' LIMIT 1;
  IF v_tenant_id IS NULL THEN
    RETURN NEW;
  END IF;

  INSERT INTO sys.users (auth_user_id, tenant_id, email, first_name, last_name, role_code)
  VALUES (
    NEW.id,
    v_tenant_id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'first_name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'last_name', ''),
    'ADMIN'
  )
  ON CONFLICT (auth_user_id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION sys.handle_new_auth_user();

-- RPCs -----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION client_demo.rpc_create_journal_entry(
  p_journal_id BIGINT,
  p_entry_date DATE,
  p_description TEXT,
  p_reference TEXT DEFAULT NULL,
  p_lines JSONB DEFAULT '[]'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, client_demo, sys AS $$
DECLARE
  v_entry_id BIGINT;
  v_entry_number TEXT;
  v_period_id BIGINT;
  v_total_debit DECIMAL(18,2) := 0;
  v_total_credit DECIMAL(18,2) := 0;
  v_line JSONB;
  v_line_num INT := 0;
  v_journal RECORD;
  v_seq INT;
  v_user_id BIGINT := sys.get_current_user_id();
BEGIN
  IF NOT client_demo.user_has_access() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Accès refusé');
  END IF;

  SELECT * INTO v_journal FROM client_demo.journals WHERE id = p_journal_id AND is_active = TRUE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Journal introuvable');
  END IF;

  SELECT id INTO v_period_id FROM client_demo.fiscal_periods
   WHERE p_entry_date BETWEEN start_date AND end_date AND status = 'OPEN'
   LIMIT 1;
  IF v_period_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error',
      'Aucune période fiscale ouverte pour ' || p_entry_date::TEXT);
  END IF;

  FOR v_line IN SELECT * FROM jsonb_array_elements(p_lines) LOOP
    v_total_debit  := v_total_debit  + COALESCE((v_line->>'debit')::DECIMAL, 0);
    v_total_credit := v_total_credit + COALESCE((v_line->>'credit')::DECIMAL, 0);
  END LOOP;

  IF v_total_debit <> v_total_credit THEN
    RETURN jsonb_build_object('success', false, 'error',
      format('Écriture déséquilibrée : %s ≠ %s', v_total_debit, v_total_credit));
  END IF;
  IF v_total_debit = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Écriture vide');
  END IF;

  SELECT COALESCE(MAX(SUBSTRING(entry_number FROM '[0-9]+$')::INT), 0) + 1 INTO v_seq
    FROM client_demo.journal_entries WHERE journal_id = p_journal_id;
  v_entry_number := v_journal.code || '-' || LPAD(v_seq::TEXT, 6, '0');

  INSERT INTO client_demo.journal_entries
    (journal_id, fiscal_period_id, entry_number, entry_date, description, reference,
     status, total_debit, total_credit, created_by)
  VALUES
    (p_journal_id, v_period_id, v_entry_number, p_entry_date, p_description, p_reference,
     'DRAFT', v_total_debit, v_total_credit, v_user_id)
  RETURNING id INTO v_entry_id;

  FOR v_line IN SELECT * FROM jsonb_array_elements(p_lines) LOOP
    v_line_num := v_line_num + 1;
    INSERT INTO client_demo.journal_entry_lines
      (journal_entry_id, line_number, account_id, description,
       debit_amount, credit_amount, partner_id)
    VALUES
      (v_entry_id, v_line_num,
       (v_line->>'account_id')::BIGINT,
       COALESCE(v_line->>'description', p_description),
       COALESCE((v_line->>'debit')::DECIMAL, 0),
       COALESCE((v_line->>'credit')::DECIMAL, 0),
       NULLIF(v_line->>'partner_id','')::BIGINT);
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'entry_id', v_entry_id,
    'entry_number', v_entry_number,
    'total_debit', v_total_debit,
    'total_credit', v_total_credit
  );
END;
$$;

CREATE OR REPLACE FUNCTION client_demo.rpc_validate_journal_entry(p_entry_id BIGINT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, client_demo, sys AS $$
DECLARE
  v_entry RECORD;
  v_user_id BIGINT := sys.get_current_user_id();
BEGIN
  IF NOT client_demo.user_has_access() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Accès refusé');
  END IF;

  SELECT * INTO v_entry FROM client_demo.journal_entries WHERE id = p_entry_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Écriture introuvable');
  END IF;
  IF v_entry.status <> 'DRAFT' THEN
    RETURN jsonb_build_object('success', false, 'error',
      'Statut actuel : ' || v_entry.status);
  END IF;
  IF v_entry.total_debit <> v_entry.total_credit THEN
    RETURN jsonb_build_object('success', false, 'error', 'Écriture déséquilibrée');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM client_demo.fiscal_periods
                  WHERE id = v_entry.fiscal_period_id AND status = 'OPEN') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Période fiscale fermée');
  END IF;

  UPDATE client_demo.journal_entries
     SET status = 'POSTED', validated_at = NOW(), validated_by = v_user_id, updated_at = NOW()
   WHERE id = p_entry_id;

  RETURN jsonb_build_object('success', true, 'entry_number', v_entry.entry_number);
END;
$$;

CREATE OR REPLACE FUNCTION client_demo.rpc_trial_balance(
  p_fiscal_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INT,
  p_period_end INT DEFAULT 12
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, client_demo, sys AS $$
BEGIN
  IF NOT client_demo.user_has_access() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Accès refusé');
  END IF;
  RETURN (
    SELECT jsonb_build_object(
      'success', true,
      'fiscal_year', p_fiscal_year,
      'accounts', COALESCE(jsonb_agg(row_data ORDER BY account_number), '[]'::jsonb)
    )
    FROM (
      SELECT coa.account_number,
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
      WHERE fp.fiscal_year = p_fiscal_year
        AND fp.period_number <= p_period_end
        AND je.status IN ('POSTED','VALIDATED')
      GROUP BY coa.account_number, coa.account_label, coa.account_type
      HAVING SUM(jel.debit_amount) <> 0 OR SUM(jel.credit_amount) <> 0
    ) sub
  );
END;
$$;

CREATE OR REPLACE FUNCTION client_demo.rpc_auto_lettrage(
  p_account_id BIGINT,
  p_partner_id BIGINT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, client_demo, sys AS $$
DECLARE
  v_matched INT := 0;
  v_lettrage_id BIGINT;
  v_pair RECORD;
BEGIN
  IF NOT client_demo.user_has_access() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Accès refusé');
  END IF;

  FOR v_pair IN
    SELECT d.id AS debit_id, c.id AS credit_id, d.debit_amount AS amount
      FROM client_demo.journal_entry_lines d
      JOIN client_demo.journal_entry_lines c
        ON c.account_id = d.account_id
       AND COALESCE(c.partner_id,0) = COALESCE(d.partner_id,0)
       AND c.credit_amount = d.debit_amount
       AND c.reconciliation_id IS NULL
       AND c.id <> d.id
     WHERE d.account_id = p_account_id
       AND d.reconciliation_id IS NULL
       AND d.debit_amount > 0
       AND (p_partner_id IS NULL OR d.partner_id = p_partner_id)
     LIMIT 100
  LOOP
    v_lettrage_id := nextval('client_demo.journal_entry_lines_id_seq');
    UPDATE client_demo.journal_entry_lines
       SET reconciliation_id = v_lettrage_id
     WHERE id IN (v_pair.debit_id, v_pair.credit_id);
    v_matched := v_matched + 1;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'matched_pairs', v_matched);
END;
$$;

GRANT EXECUTE ON FUNCTION
  client_demo.rpc_create_journal_entry(BIGINT, DATE, TEXT, TEXT, JSONB),
  client_demo.rpc_validate_journal_entry(BIGINT),
  client_demo.rpc_trial_balance(INT, INT),
  client_demo.rpc_auto_lettrage(BIGINT, BIGINT)
TO authenticated, service_role;

-- SEED -----------------------------------------------------------------------
INSERT INTO sys.tenants
  (tenant_code, company_name, legal_form, country_code, tier, subscription_level,
   database_schema, contact_email, default_currency, default_timezone)
VALUES
  ('DEMO_001', 'Entreprise Démo OHADA', 'SARL', 'SEN', 'JASPE', 'PREMIUM',
   'client_demo', 'demo@edenfin.app', 'XOF', 'Africa/Dakar')
ON CONFLICT (tenant_code) DO NOTHING;

INSERT INTO client_demo.chart_of_accounts
  (account_number, account_label, account_type, level, is_detail_account, normal_balance, financial_statement)
VALUES
  ('10', 'CAPITAL', 'EQUITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('101300', 'Capital social', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('111000', 'Réserve légale', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('131000', 'Résultat net : bénéfice', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('215000', 'Logiciels', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('241000', 'Matériel et outillage', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('244000', 'Mobilier de bureau', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('245000', 'Matériel de transport', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('281500', 'Amort. logiciels', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('284400', 'Amort. mobilier', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('401100', 'Fournisseurs', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('411100', 'Clients', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('421000', 'Personnel — rémunérations dues', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('431000', 'CNSS / IPRES', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('441000', 'État — impôt sur bénéfice', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('443100', 'TVA facturée', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('445200', 'TVA récupérable', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('447000', 'État — autres impôts et taxes', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('521100', 'Banque CBAO', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('521200', 'Banque Ecobank', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('571000', 'Caisse siège', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('601000', 'Achats de marchandises', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('604000', 'Achats stockés de fournitures', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('622000', 'Locations', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('626000', 'Frais de télécommunications', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('627000', 'Services bancaires', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('641000', 'Impôts et taxes directs', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('661000', 'Rémunérations directes du personnel', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('664000', 'Charges sociales', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('681000', 'Dotations aux amortissements', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('701000', 'Ventes de marchandises', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('706000', 'Services vendus', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('707000', 'Produits accessoires', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('771000', 'Revenus de placements', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT')
ON CONFLICT (account_number) DO NOTHING;

INSERT INTO client_demo.journals (code, name, type) VALUES
  ('VTE', 'Journal des ventes', 'SALES'),
  ('ACH', 'Journal des achats', 'PURCHASES'),
  ('BNK', 'Journal de banque', 'BANK'),
  ('OD',  'Opérations diverses', 'GENERAL')
ON CONFLICT (code) DO NOTHING;

INSERT INTO client_demo.fiscal_periods (fiscal_year, period_number, start_date, end_date, status)
SELECT 2025, m,
       make_date(2025, m, 1),
       (make_date(2025, m, 1) + INTERVAL '1 month')::date,
       'OPEN'
  FROM generate_series(1, 12) AS m
ON CONFLICT (fiscal_year, period_number) DO NOTHING;

INSERT INTO client_demo.partners (code, name, type, email, city, country_code, payment_term_days) VALUES
  ('C-001', 'SONATEL SA', 'CUSTOMER', 'contact@sonatel.sn', 'Dakar', 'SEN', 45),
  ('C-002', 'BICIS', 'CUSTOMER', 'finance@bicis.sn', 'Dakar', 'SEN', 30),
  ('F-001', 'Orange Sénégal', 'SUPPLIER', 'b2b@orange.sn', 'Dakar', 'SEN', 30),
  ('F-002', 'CFAO Motors', 'SUPPLIER', 'compta@cfao.sn', 'Dakar', 'SEN', 30)
ON CONFLICT (code) DO NOTHING;

-- Écritures démo mars 2025
DO $seed$
DECLARE
  v_period_id BIGINT;
  v_je_id BIGINT;
  v_vte BIGINT; v_ach BIGINT; v_bnk BIGINT; v_od BIGINT;
  v_acc_411 BIGINT; v_acc_401 BIGINT; v_acc_521 BIGINT;
  v_acc_4431 BIGINT; v_acc_4452 BIGINT; v_acc_706 BIGINT;
  v_acc_626 BIGINT; v_acc_661 BIGINT; v_acc_421 BIGINT;
  v_acc_431 BIGINT; v_acc_664 BIGINT;
  v_p_son BIGINT; v_p_bic BIGINT; v_p_org BIGINT;
BEGIN
  SELECT id INTO v_period_id FROM client_demo.fiscal_periods WHERE fiscal_year = 2025 AND period_number = 3;
  IF EXISTS (SELECT 1 FROM client_demo.journal_entries WHERE fiscal_period_id = v_period_id) THEN
    RETURN;
  END IF;

  SELECT id INTO v_vte FROM client_demo.journals WHERE code='VTE';
  SELECT id INTO v_ach FROM client_demo.journals WHERE code='ACH';
  SELECT id INTO v_bnk FROM client_demo.journals WHERE code='BNK';
  SELECT id INTO v_od  FROM client_demo.journals WHERE code='OD';

  SELECT id INTO v_acc_411  FROM client_demo.chart_of_accounts WHERE account_number='411100';
  SELECT id INTO v_acc_401  FROM client_demo.chart_of_accounts WHERE account_number='401100';
  SELECT id INTO v_acc_521  FROM client_demo.chart_of_accounts WHERE account_number='521100';
  SELECT id INTO v_acc_4431 FROM client_demo.chart_of_accounts WHERE account_number='443100';
  SELECT id INTO v_acc_4452 FROM client_demo.chart_of_accounts WHERE account_number='445200';
  SELECT id INTO v_acc_706  FROM client_demo.chart_of_accounts WHERE account_number='706000';
  SELECT id INTO v_acc_626  FROM client_demo.chart_of_accounts WHERE account_number='626000';
  SELECT id INTO v_acc_661  FROM client_demo.chart_of_accounts WHERE account_number='661000';
  SELECT id INTO v_acc_421  FROM client_demo.chart_of_accounts WHERE account_number='421000';
  SELECT id INTO v_acc_431  FROM client_demo.chart_of_accounts WHERE account_number='431000';
  SELECT id INTO v_acc_664  FROM client_demo.chart_of_accounts WHERE account_number='664000';

  SELECT id INTO v_p_son FROM client_demo.partners WHERE code='C-001';
  SELECT id INTO v_p_bic FROM client_demo.partners WHERE code='C-002';
  SELECT id INTO v_p_org FROM client_demo.partners WHERE code='F-001';

  -- E1 Vente SONATEL 2 950 000 TTC
  INSERT INTO client_demo.journal_entries (journal_id, fiscal_period_id, entry_number, entry_date, description, reference, status, total_debit, total_credit)
  VALUES (v_vte, v_period_id, 'VTE-000001', '2025-03-12', 'Client SONATEL — Prestation conseil', 'FAC-1042', 'POSTED', 2950000, 2950000)
  RETURNING id INTO v_je_id;
  INSERT INTO client_demo.journal_entry_lines (journal_entry_id, line_number, account_id, debit_amount, credit_amount, partner_id, description) VALUES
    (v_je_id, 1, v_acc_411, 2950000, 0, v_p_son, 'Créance SONATEL'),
    (v_je_id, 2, v_acc_706, 0, 2500000, NULL, 'CA HT'),
    (v_je_id, 3, v_acc_4431, 0, 450000, NULL, 'TVA 18%');

  -- E2 Vente BICIS 1 800 000 TTC
  INSERT INTO client_demo.journal_entries (journal_id, fiscal_period_id, entry_number, entry_date, description, reference, status, total_debit, total_credit)
  VALUES (v_vte, v_period_id, 'VTE-000002', '2025-03-09', 'Client BICIS — Maintenance ERP', 'FAC-1041', 'POSTED', 1800000, 1800000)
  RETURNING id INTO v_je_id;
  INSERT INTO client_demo.journal_entry_lines (journal_entry_id, line_number, account_id, debit_amount, credit_amount, partner_id, description) VALUES
    (v_je_id, 1, v_acc_411, 1800000, 0, v_p_bic, 'Créance BICIS'),
    (v_je_id, 2, v_acc_706, 0, 1525424, NULL, 'CA HT'),
    (v_je_id, 3, v_acc_4431, 0, 274576, NULL, 'TVA 18%');

  -- E3 Achat Orange 385 200 TTC
  INSERT INTO client_demo.journal_entries (journal_id, fiscal_period_id, entry_number, entry_date, description, reference, status, total_debit, total_credit)
  VALUES (v_ach, v_period_id, 'ACH-000001', '2025-03-10', 'Fournisseur Orange — Téléphonie', 'FRS-0089', 'POSTED', 385200, 385200)
  RETURNING id INTO v_je_id;
  INSERT INTO client_demo.journal_entry_lines (journal_entry_id, line_number, account_id, debit_amount, credit_amount, partner_id, description) VALUES
    (v_je_id, 1, v_acc_626, 326441, 0, NULL, 'Téléphonie HT'),
    (v_je_id, 2, v_acc_4452, 58759, 0, NULL, 'TVA récup.'),
    (v_je_id, 3, v_acc_401, 0, 385200, v_p_org, 'Dette Orange');

  -- E4 Encaissement BICIS 1 240 000
  INSERT INTO client_demo.journal_entries (journal_id, fiscal_period_id, entry_number, entry_date, description, reference, status, total_debit, total_credit)
  VALUES (v_bnk, v_period_id, 'BNK-000001', '2025-03-11', 'Encaissement chèque BICIS', 'BNK-227', 'POSTED', 1240000, 1240000)
  RETURNING id INTO v_je_id;
  INSERT INTO client_demo.journal_entry_lines (journal_entry_id, line_number, account_id, debit_amount, credit_amount, partner_id, description) VALUES
    (v_je_id, 1, v_acc_521, 1240000, 0, NULL, 'Encaissement banque'),
    (v_je_id, 2, v_acc_411, 0, 1240000, v_p_bic, 'Règlement partiel BICIS');

  -- E5 OD paie mars (brut 4 820 000 = net 3 680 000 + CNSS 1 140 000)
  INSERT INTO client_demo.journal_entries (journal_id, fiscal_period_id, entry_number, entry_date, description, reference, status, total_debit, total_credit)
  VALUES (v_od, v_period_id, 'OD-000001', '2025-03-28', 'OD de paie mars 2025', 'PAIE-0325', 'POSTED', 5960000, 5960000)
  RETURNING id INTO v_je_id;
  INSERT INTO client_demo.journal_entry_lines (journal_entry_id, line_number, account_id, debit_amount, credit_amount, description) VALUES
    (v_je_id, 1, v_acc_661, 4820000, 0, 'Salaires bruts mars'),
    (v_je_id, 2, v_acc_664, 1140000, 0, 'Charges sociales patronales'),
    (v_je_id, 3, v_acc_421, 0, 3680000, 'Net à payer salariés'),
    (v_je_id, 4, v_acc_431, 0, 2280000, 'Cotisations CNSS/IPRES');
END;
$seed$;
