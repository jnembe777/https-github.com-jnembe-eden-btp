# Phase 8 — Base de Données Physique

## Structure des migrations Supabase

### Conventions
- Fichiers numérotés séquentiellement : `00_`, `01_`, ..., `09_`, `10_`...
- Chaque fichier est **idempotent** : `CREATE TABLE IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`
- Commentaires en français décrivant chaque table et colonne
- Exécution via SQL Editor Supabase ou `psql`

### Migration 00 — Extensions
```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";   -- Recherche fuzzy
```

### Migration 01 — Schéma common
Tables partagées entre tous les tenants : `companies`, `currencies`, `ohada_account_templates`, `tax_rates`, `country_config`, `users`, `roles`, `permissions`, `audit_log`, `sequences`, `notification_templates`, `exchange_rates`, `fiscal_years`, `fiscal_periods`.

### Migration 02 — Schéma client
Tables métier : `accounts`, `journals`, `journal_entries`, `journal_entry_lines`, `partners`, `employees`, `payroll_runs`, `payslips`, `payslip_lines`, `fixed_assets`, `depreciation_schedules`, `bank_accounts`, `bank_transactions`, `bank_reconciliations`, `tax_returns`, `tax_return_lines`.

### Migration 07-08 — Tables de paramétrage
**Critique** : ces tables doivent exister AVANT les fonctions RPC qui les lisent.

Paie : `payroll_rubrics`, `contribution_rates`, `payroll_variables`, `pay_periods`, `absence_types`, `absences`, `leave_balances`, `payroll_cumuls`

Immobilisations : `asset_categories`

Comptabilité : `reconciliation_groups`, `fiscal_exercises`

### Migration 09 — Données initiales (seed)
Données de référence pour contexte CEMAC/Gabon :
- Plan comptable OHADA (classes 1-9, ~50 comptes essentiels)
- Rubriques de paie (14 rubriques standard)
- Barèmes de cotisations (7 barèmes CNSS/CRF/CNAMGS)
- Types d'absences (7 types avec règles)
- Catégories d'immobilisations (8 catégories OHADA)
- Périodes de paie (12 mois de l'exercice courant)
- Exercice fiscal (en cours + précédent)

## Déploiement sur Supabase

### Procédure
1. Créer le projet Supabase (région : Europe — pas de région Afrique encore)
2. Récupérer URL + anon key + service_role key
3. Exécuter les migrations dans l'ordre via SQL Editor
4. Configurer RLS (migration 05)
5. Vérifier via `SELECT count(*) FROM information_schema.tables WHERE table_schema IN ('common','client_demo')`
6. Tester les RPC via l'interface Supabase

### Variables d'environnement
```env
VITE_SUPABASE_URL=https://[project-id].supabase.co
VITE_SUPABASE_ANON_KEY=[anon-key]
SUPABASE_SERVICE_ROLE_KEY=[service-role-key]  # Backend only, never exposed
```
