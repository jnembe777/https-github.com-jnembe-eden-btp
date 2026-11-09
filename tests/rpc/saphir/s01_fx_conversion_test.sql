-- ============================================================================
-- SAPHIR S1 — Conversion multi-devises (FX)
-- Fonctions : sys.rpc_get_exchange_rate, sys.rpc_convert_amount
-- Tests : 6
-- Invariants : taux direct lu depuis sys.exchange_rates ; conversion =
--   ROUND(montant × taux, 2) ; même devise => taux 1 / montant inchangé ;
--   paire inverse => 1/taux (aller-retour cohérent au centime).
-- Prérequis : base construite (JASPE + RUBIS + SAPHIR) + devises EUR/XAF seedées.
-- Autonome : BEGIN/ROLLBACK, aucune donnée persistée.
-- ============================================================================
BEGIN;
SELECT plan(6);

-- ── Fixtures : tenant SAPHIR + un taux EUR->XAF (parité historique) ──────────
INSERT INTO sys.tenants (
  tenant_code, company_name, country_code, tier,
  subscription_level, subscription_start_date, database_schema, contact_email
) VALUES (
  'PGTAP_S1', 'Saphir S1 SA', 'GA', 'SAPHIR',
  'ENTERPRISE', '2026-01-01', 'client_test_s1', 's1@test.ga'
);

INSERT INTO sys.exchange_rates (tenant_id, from_currency, to_currency, rate_date, rate)
VALUES (
  (SELECT id FROM sys.tenants WHERE tenant_code = 'PGTAP_S1'),
  'EUR', 'XAF', '2026-01-01', 655.957
);

-- ── Tests ────────────────────────────────────────────────────────────────────

-- S1.1 — Taux direct lu depuis exchange_rates
SELECT is(
  sys.rpc_get_exchange_rate(
    (SELECT id FROM sys.tenants WHERE tenant_code = 'PGTAP_S1'),
    'EUR', 'XAF', '2026-06-01'),
  655.957::numeric,
  'S1.1 rpc_get_exchange_rate : taux direct EUR->XAF = 655.957'
);

-- S1.2 — Conversion : 100 EUR -> 65 595,70 XAF (ROUND(100 × 655.957, 2))
SELECT is(
  sys.rpc_convert_amount(
    (SELECT id FROM sys.tenants WHERE tenant_code = 'PGTAP_S1'),
    100, 'EUR', 'XAF', '2026-06-01'),
  65595.70::numeric,
  'S1.2 rpc_convert_amount : 100 EUR = 65 595,70 XAF'
);

-- S1.3 — Même devise : taux = 1
SELECT is(
  sys.rpc_get_exchange_rate(
    (SELECT id FROM sys.tenants WHERE tenant_code = 'PGTAP_S1'),
    'XAF', 'XAF', '2026-06-01'),
  1.0::numeric,
  'S1.3 rpc_get_exchange_rate : même devise => 1'
);

-- S1.4 — Même devise : montant inchangé
SELECT is(
  sys.rpc_convert_amount(
    (SELECT id FROM sys.tenants WHERE tenant_code = 'PGTAP_S1'),
    500, 'XAF', 'XAF', '2026-06-01'),
  500::numeric,
  'S1.4 rpc_convert_amount : même devise => montant inchangé'
);

-- S1.5 — Paire inverse disponible (taux dérivé 1/taux, non nul)
SELECT isnt(
  sys.rpc_get_exchange_rate(
    (SELECT id FROM sys.tenants WHERE tenant_code = 'PGTAP_S1'),
    'XAF', 'EUR', '2026-06-01'),
  NULL,
  'S1.5 rpc_get_exchange_rate : paire inverse XAF->EUR dérivée (1/taux)'
);

-- S1.6 — Aller-retour cohérent : 65 595,70 XAF reconverti en EUR ~ 100,00
SELECT is(
  sys.rpc_convert_amount(
    (SELECT id FROM sys.tenants WHERE tenant_code = 'PGTAP_S1'),
    65595.70, 'XAF', 'EUR', '2026-06-01'),
  100.00::numeric,
  'S1.6 rpc_convert_amount : aller-retour XAF->EUR = 100,00'
);

SELECT * FROM finish();
ROLLBACK;
