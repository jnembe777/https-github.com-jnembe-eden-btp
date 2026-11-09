-- ============================================================================
-- EdenFin — Pont d'intégration : comptes bancaires JASPE <-> ONYX
-- ----------------------------------------------------------------------------
-- La trésorerie ONYX (onyx/02) référence acc.bank_accounts(bank_account_id).
-- Les comptes bancaires existent en réalité dans client_demo.bank_accounts
-- (PK id). Ce pont réconcilie les deux SANS dupliquer la donnée :
--   1. expose une colonne stable bank_account_id (= id) sur
--      client_demo.bank_accounts, UNIQUE, pour servir de cible de FK ;
--   2. les scripts ONYX sont re-pointés acc.bank_accounts ->
--      client_demo.bank_accounts lors de l'intégration.
--
-- NB : acc.bank_account_balances n'est référencé que dans un COMMENTAIRE ONYX
--      (pas de code) — aucune table à créer.
--
-- À appliquer APRÈS le socle JASPE (client_demo.bank_accounts) et AVANT onyx/*.
-- Idempotent.
-- ============================================================================

ALTER TABLE client_demo.bank_accounts
  ADD COLUMN IF NOT EXISTS bank_account_id BIGINT GENERATED ALWAYS AS (id) STORED;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'client_demo.bank_accounts'::regclass
      AND conname = 'bank_accounts_bank_account_id_key'
  ) THEN
    ALTER TABLE client_demo.bank_accounts
      ADD CONSTRAINT bank_accounts_bank_account_id_key UNIQUE (bank_account_id);
  END IF;
END
$$;

-- ============================================================================
-- ROLLBACK :
--   ALTER TABLE client_demo.bank_accounts DROP CONSTRAINT IF EXISTS bank_accounts_bank_account_id_key;
--   ALTER TABLE client_demo.bank_accounts DROP COLUMN IF EXISTS bank_account_id;
-- ============================================================================
