# Phase 4 — MLD, MPD, MOT

## Modèle Logique de Données (MLD)

### Transformation MCD → MLD
1. Chaque entité MCD → table relationnelle
2. Association 1:N → FK dans la table côté N
3. Association N:M → table de jointure avec 2 FK
4. Héritage → table unique avec colonne discriminante (strategy: single table)

### Règles de typage Supabase/PostgreSQL

| Concept métier | Type PostgreSQL | Notes |
|---------------|----------------|-------|
| Identifiant | `uuid DEFAULT gen_random_uuid()` | PK technique |
| Montant XAF | `numeric(15,2)` | 15 chiffres, 2 décimales |
| Taux/pourcentage | `numeric(8,6)` | Ex: 0.025000 pour 2.5% |
| Code court | `varchar(20)` | Comptes, rubriques |
| Libellé | `varchar(255)` | Labels utilisateur |
| Date | `date` | Sans heure |
| Horodatage | `timestamptz DEFAULT now()` | Avec fuseau |
| Statut/enum | `varchar(20) CHECK(...)` | Pas de type ENUM PostgreSQL |
| Booléen | `boolean DEFAULT true` | Actif par défaut |
| Texte long | `text` | Notes, descriptions |

### Schéma dual obligatoire
```sql
-- Schéma common : données partagées (plan comptable template, devises, config pays)
CREATE SCHEMA IF NOT EXISTS common;

-- Schéma client : données spécifiques au tenant
CREATE SCHEMA IF NOT EXISTS client_demo;

-- Isolation : RLS filtre par company_id sur chaque table client
```

## Modèle Physique de Données (MPD)

### Structure des migrations
Numérotation stricte, exécution séquentielle :

```
migrations/
├── 00_extensions.sql        — uuid-ossp, pgcrypto, pg_trgm
├── 01_common_schema.sql     — Tables partagées (14 tables)
├── 02_client_schema.sql     — Tables métier client (17 tables)
├── 03_indexes.sql           — Index de performance
├── 04_triggers.sql          — updated_at, audit, séquences
├── 05_rls_policies.sql      — Row Level Security
├── 06_rpc_functions.sql     — Fonctions RPC métier (13 fonctions)
├── 07_payroll_params.sql    — Tables paramétrage paie (8 tables)
├── 08_asset_accounting.sql  — Catégories immo + exercices (3 tables)
├── 09_seed_data.sql         — Données initiales CEMAC/Gabon
```

### Index obligatoires
```sql
-- Sur chaque FK
CREATE INDEX idx_[table]_[fk_col] ON [table]([fk_col]);

-- Sur les colonnes de recherche fréquente
CREATE INDEX idx_accounts_number ON accounts(account_number);
CREATE INDEX idx_entries_date ON journal_entries(entry_date);
CREATE INDEX idx_employees_active ON employees(is_active) WHERE is_active = true;

-- Index GIN pour recherche plein texte
CREATE INDEX idx_entries_desc_gin ON journal_entries USING gin(to_tsvector('french', description));
```

### Triggers standards
```sql
-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_timestamp() RETURNS trigger AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$ LANGUAGE plpgsql;

-- Appliquer à toutes les tables
CREATE TRIGGER trg_[table]_updated BEFORE UPDATE ON [table]
FOR EACH ROW EXECUTE FUNCTION update_timestamp();
```

## Modèle Opérationnel de Traitements (MOT)

### Transformation MCT → MOT
Chaque traitement MCT se traduit en :
1. **Fonction RPC PostgreSQL** (logique transactionnelle)
2. **Classe service JavaScript** (orchestration côté client)
3. **Composant UI** (déclencheur utilisateur)

### Patron de conception RPC

```sql
CREATE OR REPLACE FUNCTION rpc_[nom_traitement](
  p_param1 type,
  p_param2 type
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = client_demo, common, public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  -- 1. Validation des entrées
  IF p_param1 IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Paramètre requis');
  END IF;

  -- 2. Lecture des tables de paramétrage (JAMAIS de constantes en dur)
  -- SELECT ... FROM contribution_rates WHERE ...

  -- 3. Logique métier dans une transaction
  -- INSERT / UPDATE multi-tables

  -- 4. Audit trail
  INSERT INTO audit_log(action, entity, entity_id, details, performed_by)
  VALUES ('TREATMENT_NAME', 'entity', v_id, v_result, auth.uid());

  -- 5. Retour structuré
  RETURN jsonb_build_object('success', true, ...);

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;
```

### Règle critique
**Aucune constante métier dans le code RPC.** Tous les taux, seuils, paramètres doivent être lus depuis les tables de paramétrage. Cela permet la mise à jour sans redéploiement quand la législation change.
