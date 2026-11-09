# Sprint 0 — Pipeline de migration unifié + CI pgTAP

Première brique de la finalisation des gammes (RUBIS → SAPHIR → ONYX) : rendre la
base **déployable et testable de façon reproductible**, du socle JASPE jusqu'à
RUBIS, en local comme en CI. C'est le prérequis P0 de tout le reste.

## Ce que ce sprint livre

| Livrable | Fichier |
|---|---|
| Manifeste de build (source de vérité de l'ordre d'application) | `db/manifest.txt` |
| Shim de compatibilité Supabase (local/CI uniquement) | `db/shim/00_supabase_compat.sql` |
| Runner de build (local + CI) | `scripts/db-build.sh` |
| Job CI pgTAP (build + exécution des tests RPC) | `.github/workflows/ci.yml` (job `pgtap`) |
| Tests pgTAP RUBIS — distribution analytique | `tests/rpc/rubis/r01_analytical_distribution_test.sql` |

## Pourquoi un « shim Supabase »

Les scripts SQL sont écrits pour Supabase, qui fournit nativement le schéma
`auth` (+ `auth.users`), les fonctions `auth.uid()` / `auth.role()` / `auth.jwt()`,
le schéma `extensions` et les rôles `anon` / `authenticated` / `service_role`.
Sur un PostgreSQL nu (poste de dev, runner CI) ces objets n'existent pas et le
déploiement échoue (« schema "auth" does not exist »). Le shim les recrée a
minima. Il n'est **jamais** appliqué sur Supabase (non listé dans le manifeste ;
piloté par `EDENFIN_DB_SHIM=1`, défaut en local/CI).

## Bugs de déploiement corrigés (le SQL de conception n'était pas déployable)

En déployant réellement le pipeline sur PostgreSQL 16, trois bugs bloquants ont
été trouvés et corrigés (ils échouaient aussi sur Supabase — c'est du PostgreSQL
standard) :

1. `database/jaspe/01-schemas-and-rbac.sql` — index partiel dont le prédicat
   utilisait `NOW()` (non-IMMUTABLE) : interdit sur un index. Prédicat simplifié.
2. `database/jaspe/05-views-and-policies.sql` — la vue `v_kpi_summary`
   référençait `e.is_active`/`e.id` sur un alias de sous-requête n'exposant que
   `cnt`. Corrigé en utilisant le compte déjà calculé.
3. `rubis/01_rubis_multicompany_schema.sql` — contrainte `UNIQUE(... COALESCE(...))`
   (expression interdite dans une contrainte de table) : convertie en index
   unique sur expression.

## Composition de la base (ordre du manifeste)

1. **Socle JASPE** : `database/jaspe/01→06` (schémas, référentiels OHADA, tables
   métier, RPC T1→T17, vues, seed CEMAC/Gabon).
2. **Compléments JASPE** : migrations paie T6/T7 et audit (`supabase/migrations/20260725*`).
3. **Gamme RUBIS** : `rubis/01→03` (multi-sociétés, distribution analytique, facturation).

> Les migrations Lovable antérieures (`supabase/migrations/20260607*`) suivent une
> lignée de schéma distincte et ne sont pas encore réconciliées dans ce manifeste
> — à traiter dans un sprint dédié (P0.1b). SAPHIR et ONYX seront ajoutés une fois
> leur build vérifié.

## Utilisation

### Construire la base en local
```bash
# PostgreSQL accessible via libpq (PGHOST/PGPORT/PGUSER…) ou DATABASE_URL
createdb edenfin_dev
DATABASE_URL="postgres://postgres@localhost:5432/edenfin_dev" \
  EDENFIN_DB_SHIM=1 bash scripts/db-build.sh
```

### Déployer sur Supabase (sans le shim)
```bash
DATABASE_URL="$SUPABASE_DB_URL" EDENFIN_DB_SHIM=0 bash scripts/db-build.sh
```

### Lancer les tests pgTAP (nécessite l'extension pgtap)
```bash
psql -d edenfin_dev -c "CREATE EXTENSION IF NOT EXISTS pgtap;"
pg_prove --recurse tests/rpc/
# ou : npm run test:pgtap
```

## Vérifications effectuées

- ✅ `scripts/db-build.sh` reconstruit toute la base **de zéro** sur PostgreSQL 16
  (socle JASPE + migrations + RUBIS), sortie 0.
- ✅ Les 15 fonctions RPC testées par la suite JASPE existent après build.
- ✅ Scénario analytique RUBIS validé fonctionnellement (template 60/40 : validation
  à 100 %, application 1000 → 600/400, garde-fou de dépassement, ventilation
  incomplète signalée).

> Le job CI `pgtap` installe le vrai pgTAP via PGDG sur le runner GitHub ; cette
> partie n'a pas pu être exécutée dans l'environnement de développement (réseau
> restreint aux registres de paquets), mais la logique des tests a été exécutée
> et validée via un harnais minimal équivalent.

## Suite immédiate (Sprint 1 proposé)

- Réconcilier la lignée `supabase/migrations/20260607*` (P0.1b).
- Étendre la couverture pgTAP RUBIS (facturation `rpc_create_invoice` /
  `rpc_record_payment`, consolidation inter-sociétés).
- Vérifier le build SAPHIR, puis l'ajouter au manifeste.
