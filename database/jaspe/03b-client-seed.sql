-- ============================================================================
-- EDENFIN JASPE — SEED DÉMO client_demo (exercices, périodes, journaux)
-- Extrait de 03-client-tables.sql : données de DÉMONSTRATION, séparées du
-- schéma pour que les tests pgTAP (qui fournissent leurs propres fixtures)
-- tournent sur une base propre. Sauté par scripts/db-build.sh via
-- EDENFIN_SKIP lors du build de test.
-- ROLLBACK :
--   DELETE FROM client_demo.journals WHERE code IN ('VTE','ACH','BQ','CAI','OD','PAIE');
--   DELETE FROM client_demo.fiscal_periods WHERE fiscal_year = 2026;
--   DELETE FROM client_demo.fiscal_exercises WHERE fiscal_year IN (2025, 2026);
-- ============================================================================

-- Exercice comptable 2026
INSERT INTO client_demo.fiscal_exercises (fiscal_year, start_date, end_date, status, opened_at) VALUES
  (2025, '2025-01-01', '2025-12-31', 'CLOSED', '2025-01-01'::TIMESTAMPTZ),
  (2026, '2026-01-01', '2026-12-31', 'OPEN',   NOW())
ON CONFLICT (fiscal_year) DO NOTHING;

-- Périodes fiscales 2026 (12 mois)
INSERT INTO client_demo.fiscal_periods (exercise_id, fiscal_year, period_number, start_date, end_date, status)
SELECT
  (SELECT id FROM client_demo.fiscal_exercises WHERE fiscal_year = 2026),
  2026, n,
  ('2026-01-01'::DATE + ((n-1) || ' months')::INTERVAL)::DATE,
  ('2026-01-01'::DATE + (n || ' months')::INTERVAL - INTERVAL '1 day')::DATE,
  'OPEN'
FROM generate_series(1, 12) AS n
ON CONFLICT (fiscal_year, period_number) DO NOTHING;

-- Journaux de base
INSERT INTO client_demo.journals (code, name, type, is_active) VALUES
  ('VTE',  'Ventes',               'SALES',     TRUE),
  ('ACH',  'Achats',               'PURCHASES', TRUE),
  ('BQ',   'Banque',               'BANK',      TRUE),
  ('CAI',  'Caisse',               'CASH',      TRUE),
  ('OD',   'Opérations Diverses',  'GENERAL',   TRUE),
  ('PAIE', 'Paie',                 'PAYROLL',   TRUE)
ON CONFLICT (code) DO NOTHING;

