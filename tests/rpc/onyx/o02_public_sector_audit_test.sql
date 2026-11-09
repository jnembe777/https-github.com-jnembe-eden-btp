-- ============================================================================
-- ONYX O2 — Secteur public (contrôle budgétaire) + intégrité d'audit
-- Fonctions : onyx.rpc_check_appropriation, onyx.fn_calculate_audit_hash
-- Tests : 5
-- Invariants :
--   - le contrôle d'engagement rejette une imputation sur un crédit inexistant ;
--   - le hachage d'audit est déterministe (même entrée => même empreinte),
--     sensible au chaînage (previous_hash différent => empreinte différente),
--     et de longueur SHA-512 (128 hex) — socle de la piste d'audit inaltérable.
-- Prérequis : base complète (JASPE + RUBIS + SAPHIR + ONYX 01-07).
-- Autonome : BEGIN/ROLLBACK, aucune donnée persistée ni requise.
-- ============================================================================
BEGIN;
SELECT plan(5);

-- ── Secteur public : contrôle d'engagement (onyx/05) ─────────────────────────

-- O2.1 — Crédit inexistant => success = false
SELECT is(
  (onyx.rpc_check_appropriation('00000000-0000-0000-0000-0000000000aa', 100))::jsonb ->> 'success',
  'false',
  'O2.1 rpc_check_appropriation : crédit inexistant => success=false'
);

-- O2.2 — Message d'erreur explicite
SELECT is(
  (onyx.rpc_check_appropriation('00000000-0000-0000-0000-0000000000aa', 100))::jsonb ->> 'error',
  'Appropriation not found',
  'O2.2 rpc_check_appropriation : message « Appropriation not found »'
);

-- ── Intégrité de la piste d'audit (onyx/06-07) ───────────────────────────────

-- O2.3 — Déterminisme : mêmes entrées => même empreinte
SELECT is(
  onyx.fn_calculate_audit_hash(
    '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b',
    '2026-01-01T00:00:00+00', 'CREATE', '00000000-0000-0000-0000-00000000000c',
    'INSERT', 'invoice', '00000000-0000-0000-0000-00000000000d',
    '{}'::jsonb, '{}'::jsonb, 'prev'),
  onyx.fn_calculate_audit_hash(
    '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b',
    '2026-01-01T00:00:00+00', 'CREATE', '00000000-0000-0000-0000-00000000000c',
    'INSERT', 'invoice', '00000000-0000-0000-0000-00000000000d',
    '{}'::jsonb, '{}'::jsonb, 'prev'),
  'O2.3 fn_calculate_audit_hash : déterministe (même entrée => même empreinte)'
);

-- O2.4 — Chaînage : previous_hash différent => empreinte différente
SELECT isnt(
  onyx.fn_calculate_audit_hash(
    '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b',
    '2026-01-01T00:00:00+00', 'CREATE', '00000000-0000-0000-0000-00000000000c',
    'INSERT', 'invoice', '00000000-0000-0000-0000-00000000000d',
    '{}'::jsonb, '{}'::jsonb, 'prev'),
  onyx.fn_calculate_audit_hash(
    '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b',
    '2026-01-01T00:00:00+00', 'CREATE', '00000000-0000-0000-0000-00000000000c',
    'INSERT', 'invoice', '00000000-0000-0000-0000-00000000000d',
    '{}'::jsonb, '{}'::jsonb, 'autre'),
  'O2.4 fn_calculate_audit_hash : sensible au chaînage (previous_hash)'
);

-- O2.5 — Longueur SHA-512 (128 caractères hexadécimaux)
SELECT is(
  length(onyx.fn_calculate_audit_hash(
    '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b',
    '2026-01-01T00:00:00+00', 'CREATE', '00000000-0000-0000-0000-00000000000c',
    'INSERT', 'invoice', '00000000-0000-0000-0000-00000000000d',
    '{}'::jsonb, '{}'::jsonb, 'prev')),
  128,
  'O2.5 fn_calculate_audit_hash : empreinte SHA-512 (128 hex)'
);

SELECT * FROM finish();
ROLLBACK;
