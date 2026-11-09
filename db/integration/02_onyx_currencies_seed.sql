-- ============================================================================
-- EdenFin — Seed d'intégration : devises requises par ONYX (multi-pays)
-- ----------------------------------------------------------------------------
-- La gamme ONYX ensemence un référentiel pays (sys.countries) dont la devise
-- référence common.currencies(code). Le seed JASPE ne charge que les devises
-- de la zone CEMAC/UEMOA + quelques majeures ; ONYX en requiert d'autres
-- (RD Congo, Comores, Guinée, Nigeria, Afrique du Sud, Chine, Émirats).
-- Ce seed complète common.currencies AVANT l'ensemencement ONYX.
--
-- À appliquer après le socle JASPE (common.currencies) et avant onyx/*.
-- Idempotent (ON CONFLICT (code) DO NOTHING).
-- ============================================================================

INSERT INTO common.currencies (code, name_fr, name_en, symbol, decimal_places, is_active, created_by)
VALUES
  ('AED', 'Dirham des Émirats arabes unis', 'UAE Dirham',        'د.إ', 2, TRUE, 0),
  ('CDF', 'Franc congolais',                'Congolese Franc',   'FC',  2, TRUE, 0),
  ('CNY', 'Yuan renminbi',                  'Chinese Yuan',      '¥',   2, TRUE, 0),
  ('GNF', 'Franc guinéen',                  'Guinean Franc',     'FG',  0, TRUE, 0),
  ('KMF', 'Franc comorien',                 'Comorian Franc',    'CF',  0, TRUE, 0),
  ('NGN', 'Naira',                          'Nigerian Naira',    '₦',   2, TRUE, 0),
  ('ZAR', 'Rand sud-africain',              'South African Rand','R',   2, TRUE, 0)
ON CONFLICT (code) DO NOTHING;

-- ============================================================================
-- ROLLBACK :
--   DELETE FROM common.currencies WHERE code IN ('AED','CDF','CNY','GNF','KMF','NGN','ZAR');
-- ============================================================================
