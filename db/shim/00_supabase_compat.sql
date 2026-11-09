-- ============================================================================
-- EdenFin — Shim de compatibilité Supabase (LOCAL / CI UNIQUEMENT)
-- ----------------------------------------------------------------------------
-- Les scripts de migration EdenFin sont écrits pour Supabase, qui fournit
-- nativement : le schéma `auth` (+ table `auth.users`), les fonctions
-- `auth.uid()` / `auth.role()` / `auth.jwt()`, le schéma `extensions`, et les
-- rôles `anon` / `authenticated` / `service_role` / `authenticator`.
--
-- Sur un PostgreSQL nu (poste de dev, runner CI) ces objets n'existent pas et
-- les migrations échouent (ex. « schema "auth" does not exist »). Ce shim les
-- recrée a minima pour rendre le pipeline DÉPLOYABLE ET TESTABLE hors Supabase.
--
-- ⚠️  NE JAMAIS exécuter ce fichier sur une base Supabase réelle : il n'est PAS
--     listé dans db/manifest.txt et n'est appliqué que par scripts/db-build.sh
--     lorsque EDENFIN_DB_SHIM=1 (valeur par défaut en local/CI).
-- ============================================================================

-- ── Rôles Supabase (NOLOGIN) ────────────────────────────────────────────────
-- Créés seulement s'ils n'existent pas, pour que les GRANT ... TO authenticated
-- des migrations passent.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN NOINHERIT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN NOINHERIT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN NOINHERIT BYPASSRLS;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticator') THEN
    CREATE ROLE authenticator NOINHERIT LOGIN;
    GRANT anon, authenticated, service_role TO authenticator;
  END IF;
END
$$;

-- ── Schémas fournis par Supabase ────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS extensions;

-- Extensions usuelles (Supabase les place dans `extensions`, PG nu dans public ;
-- on les rend disponibles des deux côtés de façon idempotente).
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ── Table auth.users (sous-ensemble du modèle Supabase) ─────────────────────
-- Seules les colonnes réellement référencées par les migrations sont utiles ;
-- on reproduit les principales pour rester proche du réel.
CREATE TABLE IF NOT EXISTS auth.users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email         VARCHAR(255),
  raw_app_meta_data  JSONB DEFAULT '{}'::jsonb,
  raw_user_meta_data JSONB DEFAULT '{}'::jsonb,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now()
);

-- ── Fonctions d'identité Supabase ───────────────────────────────────────────
-- Compatibles avec l'implémentation Supabase : elles lisent le claim JWT injecté
-- par PostgREST via le GUC `request.jwt.claims`. En test, on peut simuler un
-- utilisateur avec :
--   SELECT set_config('request.jwt.claims', json_build_object('sub', '<uuid>','role','authenticated')::text, true);
CREATE OR REPLACE FUNCTION auth.uid()
RETURNS UUID
LANGUAGE sql STABLE
AS $$
  SELECT NULLIF(
    current_setting('request.jwt.claims', true)::jsonb ->> 'sub',
    ''
  )::uuid;
$$;

CREATE OR REPLACE FUNCTION auth.role()
RETURNS TEXT
LANGUAGE sql STABLE
AS $$
  SELECT COALESCE(
    NULLIF(current_setting('request.jwt.claims', true)::jsonb ->> 'role', ''),
    'authenticated'
  );
$$;

CREATE OR REPLACE FUNCTION auth.jwt()
RETURNS JSONB
LANGUAGE sql STABLE
AS $$
  SELECT COALESCE(
    NULLIF(current_setting('request.jwt.claims', true), '')::jsonb,
    '{}'::jsonb
  );
$$;

-- ============================================================================
-- ROLLBACK (désinstallation du shim — local/CI uniquement)
-- ----------------------------------------------------------------------------
-- DROP FUNCTION IF EXISTS auth.jwt();
-- DROP FUNCTION IF EXISTS auth.role();
-- DROP FUNCTION IF EXISTS auth.uid();
-- DROP TABLE IF EXISTS auth.users CASCADE;
-- DROP SCHEMA IF EXISTS auth CASCADE;
-- DROP SCHEMA IF EXISTS extensions CASCADE;
-- Les rôles anon/authenticated/service_role/authenticator sont laissés en place
-- (potentiellement partagés). Les supprimer manuellement si nécessaire :
-- DROP OWNED BY authenticator; DROP ROLE IF EXISTS authenticator;
-- DROP ROLE IF EXISTS service_role; DROP ROLE IF EXISTS authenticated; DROP ROLE IF EXISTS anon;
-- ============================================================================
