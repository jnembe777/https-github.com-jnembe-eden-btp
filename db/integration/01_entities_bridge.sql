-- ============================================================================
-- EdenFin — Pont d'intégration : entités RUBIS <-> ONYX
-- ----------------------------------------------------------------------------
-- RUBIS matérialise les entités juridiques dans sys.tenant_entities (PK id).
-- ONYX (écrit contre un contrat antérieur) référence sys.entities(entity_id).
-- Ce pont réconcilie les deux SANS dupliquer la donnée :
--   1. expose une colonne stable entity_id (= id) sur sys.tenant_entities,
--      UNIQUE, afin que les clés étrangères ONYX ...(entity_id) résolvent ;
--   2. les scripts ONYX sont par ailleurs re-pointés vers sys.tenant_entities
--      (rename sys.entities -> sys.tenant_entities) lors de l'intégration.
--
-- À appliquer APRÈS rubis/01 (création de tenant_entities) et AVANT onyx/*.
-- Idempotent.
-- ============================================================================

-- 1. Colonne miroir stable (générée) + unicité pour servir de cible de FK.
ALTER TABLE sys.tenant_entities
  ADD COLUMN IF NOT EXISTS entity_id BIGINT GENERATED ALWAYS AS (id) STORED;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'sys.tenant_entities'::regclass
      AND conname = 'tenant_entities_entity_id_key'
  ) THEN
    ALTER TABLE sys.tenant_entities
      ADD CONSTRAINT tenant_entities_entity_id_key UNIQUE (entity_id);
  END IF;
END
$$;

-- ============================================================================
-- ROLLBACK :
--   ALTER TABLE sys.tenant_entities DROP CONSTRAINT IF EXISTS tenant_entities_entity_id_key;
--   ALTER TABLE sys.tenant_entities DROP COLUMN IF EXISTS entity_id;
-- ============================================================================
