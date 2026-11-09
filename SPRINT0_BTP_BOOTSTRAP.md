# Sprint 0 — Bootstrap EDEN BTP (socle EdenFin vendorisé)

## Objectif

Démarrer EDEN BTP sur une base **déjà éprouvée** en reprenant le socle EdenFin
(dépôt `finsys`) tel quel, pour ne pas réécrire la comptabilité, la paie, la
trésorerie, l'analytique ni le pipeline de build/CI. Le métier BTP sera ajouté
par-dessus (Sprints suivants).

## Ce qui a été vendorisé

Copie conforme du socle EdenFin, **hors** `node_modules`, `.git` et archives
lourdes :

- **Base & pipeline** : `database/jaspe/` (01→06 + 03b), `db/` (manifest, shim,
  intégration), `scripts/db-build.sh`, `supabase/migrations/`.
- **Gammes** : `rubis/`, `saphir/`, `onyx/` (RUBIS analytique = socle du coût de
  revient par chantier à venir).
- **Frontend** : `src/` (TanStack Start, composants `edenfin/`, hooks, lib,
  routes console), configs (`package.json`, `bun.lock`, `tsconfig`, `vite`,
  `vitest`, `eslint`, `components.json`).
- **Tests & CI** : `tests/rpc/` (15 tests JASPE + gammes), `.github/workflows/ci.yml`.
- **Méthodologie** : `01..15-*.md`, `NOYAU-NORMATIF-EDENFIN.md`, templates
  (`sql-migration-template.sql`, `rpc-function-template.sql`,
  `grid-registry-template.js`, `entity-form-template.jsx`).

## Vérification (local, PostgreSQL 16)

- `scripts/db-build.sh` (pipeline complet, shim activé) : **build OK**.
- Base de test autonome (`EDENFIN_SKIP="03b-client-seed,06-seed-data"`) +
  suite pgTAP (`tests/rpc/*_test.sql tests/rpc/*/*_test.sql`) : **19/19 au vert**
  (15 JASPE + 4 gammes).

La CI (`.github/workflows/ci.yml`) reprend les 5 garde-fous EdenFin (quality,
souverainete, ohada-invariants, migrations, pgtap) à l'identique.

## Convention de réutilisation

Le socle est repris **sans rebranding interne** : schémas (`sys`, `common`,
`client_demo`), noms de RPC et composants restent ceux d'EdenFin pour préserver
la réutilisation et la CI verte. L'identité BTP s'ajoute par la couche métier
(schéma `btp`, pages console dédiées) et le branding visuel.

## Suite

Sprint 1 — Noyau métier BTP (Phases 1→4) : cahier des charges, specs
fonctionnelles, MCD/MCT, MLD (schéma `btp`). Voir `README.md` pour la feuille de
route complète.
