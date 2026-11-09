-- ============================================================================
-- ONYX O1 — Configuration fiscale multi-pays
-- Fonction : sys.rpc_get_country_tax_config(country_code, as_of_date) -> jsonb
-- Tests : 6
-- Invariant : le référentiel multi-pays ONYX (sys.countries) est correctement
--   ensemencé et exposé ; chaque pays renvoie son code, son nom et ses taux
--   (TVA, IS) conformes aux données CEMAC/OHADA + internationales.
-- Prérequis : base construite (JASPE + RUBIS + SAPHIR + ponts + ONYX 01-03).
-- Autonome : BEGIN/ROLLBACK, lecture seule (données de seed déjà présentes).
-- ============================================================================
BEGIN;
SELECT plan(6);

-- O1.1 — Gabon : code pays
SELECT is(
  sys.rpc_get_country_tax_config('GA') -> 'country' ->> 'code',
  'GA',
  'O1.1 rpc_get_country_tax_config : Gabon -> code = GA'
);

-- O1.2 — Gabon : nom
SELECT is(
  sys.rpc_get_country_tax_config('GA') -> 'country' ->> 'name',
  'Gabon',
  'O1.2 rpc_get_country_tax_config : Gabon -> nom = Gabon'
);

-- O1.3 — Gabon : TVA standard 18 %
SELECT is(
  (sys.rpc_get_country_tax_config('GA') -> 'country' ->> 'vat_standard_rate')::numeric,
  18.00::numeric,
  'O1.3 rpc_get_country_tax_config : Gabon -> TVA = 18 %'
);

-- O1.4 — Gabon : IS 30 %
SELECT is(
  (sys.rpc_get_country_tax_config('GA') -> 'country' ->> 'corporate_tax_rate')::numeric,
  30.00::numeric,
  'O1.4 rpc_get_country_tax_config : Gabon -> IS = 30 %'
);

-- O1.5 — Cameroun : TVA standard 19,25 % (donnée CEMAC distincte)
SELECT is(
  (sys.rpc_get_country_tax_config('CM') -> 'country' ->> 'vat_standard_rate')::numeric,
  19.25::numeric,
  'O1.5 rpc_get_country_tax_config : Cameroun -> TVA = 19,25 %'
);

-- O1.6 — Pays international ensemencé (France) accessible
SELECT is(
  sys.rpc_get_country_tax_config('FR') -> 'country' ->> 'name',
  'France',
  'O1.6 rpc_get_country_tax_config : France (hors OHADA) accessible'
);

SELECT * FROM finish();
ROLLBACK;
