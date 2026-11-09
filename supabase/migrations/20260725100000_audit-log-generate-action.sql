-- ============================================================================
-- Migration : Ajout de l'action 'GENERATE' dans sys.audit_log
-- Contexte : rpc_generate_payroll_entries (MCT T7) insère action='GENERATE'
--            mais la contrainte CHECK ne l'incluait pas — provoque une erreur.
-- Conformité : ajout non destructif à la contrainte existante.
-- ============================================================================

-- Supprimer l'ancienne contrainte CHECK sur la colonne action
DO $$
DECLARE
  v_conname TEXT;
BEGIN
  SELECT conname INTO v_conname
  FROM pg_constraint
  WHERE conrelid = 'sys.audit_log'::regclass
    AND contype = 'c'
    AND pg_get_constraintdef(oid) LIKE '%action%';

  IF v_conname IS NOT NULL THEN
    EXECUTE 'ALTER TABLE sys.audit_log DROP CONSTRAINT ' || quote_ident(v_conname);
  END IF;
END;
$$;

-- Recréer la contrainte avec 'GENERATE' inclus
ALTER TABLE sys.audit_log
  ADD CONSTRAINT audit_log_action_check
  CHECK (action IN (
    'CREATE', 'UPDATE', 'DELETE', 'VALIDATE', 'CANCEL',
    'EXPORT', 'IMPORT', 'LOGIN', 'LOGOUT', 'ACCESS',
    'CLOSE_PERIOD', 'DISPOSE_ASSET', 'CALCULATE', 'GENERATE'
  ));

-- ROLLBACK (pour CI migrations check) :
-- ALTER TABLE sys.audit_log DROP CONSTRAINT IF EXISTS audit_log_action_check;
-- ALTER TABLE sys.audit_log ADD CONSTRAINT audit_log_action_check
--   CHECK (action IN (
--     'CREATE', 'UPDATE', 'DELETE', 'VALIDATE', 'CANCEL',
--     'EXPORT', 'IMPORT', 'LOGIN', 'LOGOUT', 'ACCESS',
--     'CLOSE_PERIOD', 'DISPOSE_ASSET', 'CALCULATE'
--   ));

DO $$ BEGIN RAISE NOTICE '✅ Migration 20260725100000 OK — action GENERATE ajoutée à sys.audit_log'; END $$;
