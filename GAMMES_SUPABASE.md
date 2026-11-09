# Branchement des pages de gammes sur Supabase

Les pages des gammes (RUBIS / SAPHIR / ONYX) sont branchées sur Supabase via le
hook `useGammeData` (`src/hooks/use-gamme-data.ts`) : chaque page interroge la
table/vue cible et **retombe sur des données de démonstration** si la requête
échoue ou ne renvoie rien. Un badge indique l'état :

- 🟠 **Mode démonstration** : pas de données réelles (schéma non déployé/exposé) → mock.
- 🟢 **Données Supabase** : données réelles servies par Supabase.

Tant que le backend des gammes n'est pas déployé sur l'instance Supabase, les
pages restent en « Mode démonstration » — c'est le comportement attendu.

## Pour afficher les vraies données

### 1. Déployer le schéma des gammes sur Supabase
Appliquer le pipeline unifié sur la base Supabase (nécessite l'URL de connexion
directe à la base, pas la clé anon) :

```bash
DATABASE_URL="$SUPABASE_DB_URL" EDENFIN_DB_SHIM=0 bash scripts/db-build.sh
```

`EDENFIN_DB_SHIM=0` : Supabase fournit déjà `auth.*`, les rôles et `extensions`.

### 2. Exposer les schémas à l'API (PostgREST)
Par défaut Supabase n'expose que `public`. Ajouter les schémas des gammes dans
**Project Settings → API → Exposed schemas** (ou `db-schemas`) :

```
public, graphql_public, common, sys, client_demo, onyx
```

Et donner les privilèges de lecture aux rôles `anon` / `authenticated` sur ces
schémas (via RLS + GRANT), selon votre politique de sécurité.

### 3. (Option) Ajouter des vues/colonnes dérivées
Certaines pages attendent des champs agrégés qui ne sont pas des colonnes brutes
(ex. `DistributionTemplate.is_valid` / `lines_count` / `total_percentage`,
`ConsolidationLine.contribution_result`). Prévoir des **vues** exposant ces
champs, ou enrichir les requêtes/hook, pour un rendu réel fidèle.

## Correspondance page → source

| Page | Table/vue interrogée | Schéma |
|---|---|---|
| RUBIS Analytique | `analytical_axes`, `analytical_distribution_templates` | `sys` |
| RUBIS Multi-sociétés | `tenant_entities` | `sys` |
| RUBIS Facturation | `invoices` | `sys` |
| SAPHIR Multi-devises | `exchange_rates` | `sys` |
| SAPHIR Consolidation | `consolidation_group_members` | `sys` |
| SAPHIR Workflows | `v_pending_approvals` | `sys` |
| ONYX Multi-pays | `countries` | `sys` |
| ONYX Trésorerie | `cash_pools` | `onyx` |
| ONYX Secteur public | `appropriations` | `onyx` |

> Le mapping des noms de table passe par `TABLES`/`SCHEMAS` de `src/lib/supabase.ts`.
