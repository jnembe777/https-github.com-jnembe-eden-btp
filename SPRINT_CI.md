# Mise au vert de la CI (`.github/workflows/ci.yml`)

La CI du dépôt n'avait **jamais été verte** (tous les runs en échec depuis la
création du workflow). Ce chantier corrige les 5 jobs.

## Corrections par job

| Job | Problème | Correction |
|---|---|---|
| **quality** | `setup-node` avec `cache: npm` échouait (dépôt sous bun, pas de `package-lock.json`) | Retrait de `cache: npm`. Typecheck 0 erreur, 9 tests vitest verts. |
| **souverainete** | Interdisait XOF/BCEAO/UEMOA partout, or OHADA couvre CEMAC+UEMOA (réfs légitimes) | Scopé au code applicatif `src/` (exclut référentiels/seed/gammes/mocks). Démos JASPE corrigées XOF→XAF. |
| **ohada-invariants** | `CNSS.*0.` matchait des libellés de seed (faux positif) | Cible l'arithmétique en dur ; exclut les données de seed. |
| **migrations** | — | ✅ déjà vert. |
| **pgtap** | Install + démarrage PostgreSQL non fiables sur le runner | Install PGDG ; création explicite du cluster `16/main` + **détection dynamique du port** (le runner expose déjà un PostgreSQL 18 sur 5432, donc le cluster 16 passe sur 5433). |

## Tests pgTAP exécutés

Le job `pgtap` :
1. construit la base via `scripts/db-build.sh` (JASPE + RUBIS + SAPHIR + ONYX)
   **sans les seeds** (`EDENFIN_SKIP="03b-client-seed,06-seed-data"`) : les tests
   sont autonomes et fournissent leurs propres fixtures (cf. `tests/rpc/00_setup.sql`),
   les données de démonstration/référence entreraient en conflit de clés ;
2. charge l'extension pgTAP ;
3. exécute **toute la suite** `pg_prove tests/rpc/*_test.sql tests/rpc/*/*_test.sql` :
   - **JASPE T1→T17** (15 tests, `t01..t15_*.sql`) — écritures, validation,
     lettrage, clôture, paie, TVA, ratios, immobilisations, balance, KPI ;
   - **gammes** `tests/rpc/<gamme>/*_test.sql` (RUBIS distribution analytique,
     SAPHIR conversion FX, ONYX fiscalité multi-pays + contrôle budgétaire /
     intégrité d'audit).

## Remise à niveau des tests JASPE hérités (fait)

Les 15 tests `tests/rpc/t01..t15_*.sql` (issus de la PR #13) étaient désynchronisés
du schéma courant et n'avaient jamais tourné en CI. Ils ont été remis à niveau et
sont désormais **tous verts**. Corrections apportées :

- **Build de test sans seeds** : les fixtures autonomes des tests n'entrent plus
  en conflit avec les données seedées (`fiscal_exercises` 2026, `pay_periods`,
  `asset_categories`…). Les données de démo ont été extraites de `03` vers
  `03b-client-seed.sql` pour pouvoir être sautées (`EDENFIN_SKIP`).
- **Assertion `alike()`** : les tests utilisaient `like(valeur, motif, desc)`, qui
  n'existe pas dans pgTAP (seul le `like(text,text)` natif à 2 arguments existe —
  d'où `function like(text, unknown, unknown) does not exist` et l'abandon du test).
  Remplacé par `alike()`, la fonction pgTAP de correspondance LIKE (18 appels).
- **Colonnes réalignées** : `asset_categories` (`label`, `default_useful_life_months`,
  `default_method`) et `fixed_assets.asset_account_id` dans `t12`/`t13`.
- **RPC à appel unique** : les assertions « nominales » qui réinvoquaient une RPC
  mutative irréversible (validation d'écriture/bulletin, clôture de période,
  cession d'immobilisation) capturent désormais le résultat du seul appel, ou
  utilisent une entité dédiée par scénario.
- **Fixture de lettrage** : écritures créées en `DRAFT` puis postées après insertion
  des lignes (l'insertion de ligne sur une écriture POSTED déclenchait le garde
  d'immuabilité).
- **Correctifs produit** révélés par les tests :
  - `rpc_generate_tva_declaration` rendue idempotente (régénération sans violation
    de clé sur `tax_return_data`) ;
  - trigger `update_journal_entry_totals` : ne recalcule plus les totaux quand ni
    les montants ni le rattachement ne changent — sans quoi le lettrage d'une
    écriture POSTED (cas d'usage normal) était bloqué par le garde d'immuabilité.
- **Syntaxe** : parenthèse déséquilibrée dans `t01` (T1.5), comparaison
  `DATE`/`TIMESTAMP` dans `t10` (T10.6).
