-- ═══════════════════════════════════════════════════════════════════════
-- Migration: [NN]_[description].sql
-- ERP OHADA · Gamme [JASPE|RUBIS|SAPHIR|ONYX]
-- Date: [YYYY-MM-DD]
-- Auteur: [nom]
-- Description: [Ce que fait cette migration]
-- Dépendances: [NN-1]_[previous].sql
-- ═══════════════════════════════════════════════════════════════════════

-- ── EXTENSIONS (migration 00 uniquement) ──
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ── SCHEMA ──
-- CREATE SCHEMA IF NOT EXISTS client_demo;
-- SET search_path TO client_demo, common, public;

-- ═══════════════════════════════════════════════════════════════════════
-- TABLE: [nom_table]
-- Description: [description en français]
-- ═══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS [schema].[nom_table] (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Clés métier
  code          varchar(20) NOT NULL UNIQUE,
  label         varchar(255) NOT NULL,

  -- Clés étrangères
  -- parent_id  uuid REFERENCES [schema].[parent_table](id),

  -- Attributs métier
  -- amount     numeric(15,2) NOT NULL DEFAULT 0,
  -- rate       numeric(8,6),
  -- status     varchar(20) NOT NULL DEFAULT 'ACTIVE'
  --            CHECK(status IN ('ACTIVE','INACTIVE','ARCHIVED')),

  -- Isolation tenant
  company_id    uuid NOT NULL REFERENCES common.companies(id),

  -- Audit
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  created_by    uuid REFERENCES auth.users(id),

  -- Contraintes
  CONSTRAINT [nom_table]_code_company_unique UNIQUE(code, company_id)
);

-- ── COMMENTAIRES ──
COMMENT ON TABLE [schema].[nom_table] IS '[Description en français]';
COMMENT ON COLUMN [schema].[nom_table].code IS '[Description du code]';

-- ── INDEX ──
CREATE INDEX IF NOT EXISTS idx_[nom_table]_company ON [schema].[nom_table](company_id);
CREATE INDEX IF NOT EXISTS idx_[nom_table]_code ON [schema].[nom_table](code);

-- ── TRIGGER updated_at ──
CREATE TRIGGER trg_[nom_table]_updated
  BEFORE UPDATE ON [schema].[nom_table]
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ── RLS ──
ALTER TABLE [schema].[nom_table] ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tenant_isolation_[nom_table]" ON [schema].[nom_table]
  FOR ALL
  USING (company_id = (auth.jwt() ->> 'company_id')::uuid)
  WITH CHECK (company_id = (auth.jwt() ->> 'company_id')::uuid);
