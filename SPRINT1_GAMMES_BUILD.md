# Sprint 1 — Intégration SAPHIR + amorçage ONYX

Suite du Sprint 0 (pipeline unifié). Objectif : faire entrer les gammes
supérieures dans le pipeline déployable/testable, dans l'ordre d'héritage
JASPE → RUBIS → **SAPHIR** → **ONYX**.

## Résultat

| Gamme | État après Sprint 1 |
|---|---|
| JASPE (TPE) | ✅ dans le pipeline (Sprint 0) |
| RUBIS (PME) | ✅ dans le pipeline (Sprint 0) |
| **SAPHIR (ETI)** | ✅ **intégrée, déployée de bout en bout, testée (pgTAP FX)** |
| **ONYX (GE/public)** | 🟡 **amorcée** — `onyx/01` déploie ; `onyx/02→07` à finaliser |

Pipeline complet (JASPE + RUBIS + SAPHIR) vérifié via `scripts/db-build.sh` :
reconstruction **de zéro, exit 0, 151 tables**.

## SAPHIR — intégré

Ajouté au manifeste (`saphir/01→05`). Bugs de déploiement corrigés (ils
échouaient aussi sur Supabase) :

1. `saphir/02_saphir_workflow.sql` — vues `v_pending_approvals` /
   `v_workflow_instances_detail` référençaient `users.display_name`
   (inexistant) → `first_name || ' ' || last_name`.
2. `saphir/05_saphir_bi.sql` — dimension temps : `day_of_week` seedé via
   `EXTRACT(DOW)` (0–6) viole le `CHECK (BETWEEN 1 AND 7)` → `EXTRACT(ISODOW)`.

**Test** : `tests/rpc/saphir/s01_fx_conversion_test.sql` (6 assertions) —
`rpc_get_exchange_rate` / `rpc_convert_amount` : taux direct, conversion
`ROUND(montant × taux, 2)`, même devise, paire inverse, aller-retour au centime.

## ONYX — amorcée (non activée dans le manifeste)

`onyx/01_onyx_multicountry.sql` déploie désormais sur JASPE+RUBIS+SAPHIR une
fois appliqués les **ponts d'intégration** créés dans ce sprint :

- `db/integration/01_entities_bridge.sql` — ONYX référence `sys.entities(entity_id)`
  alors que RUBIS matérialise les entités dans `sys.tenant_entities(id)`. Le pont
  expose une colonne stable `entity_id` (UNIQUE) sur `tenant_entities` ; les
  scripts ONYX sont re-pointés `sys.entities` → `sys.tenant_entities`.
- `db/integration/02_onyx_currencies_seed.sql` — complète `common.currencies`
  avec les devises multi-pays requises (AED, CDF, CNY, GNF, KMF, NGN, ZAR).

Bugs ONYX corrigés en passant :
- FK `common.currencies(currency_code)` → `common.currencies(code)` (15 réfs).
- `UNIQUE(… COALESCE …)` (interdit) → index unique sur expression.
- CTE récursive `v_consolidation_hierarchy` : type `numeric(5,2)` vs `numeric`
  → cast de l'ancrage en `numeric`.

### Reste à faire pour activer ONYX (Sprint 2)

`onyx/02_onyx_treasury.sql` et suivants sont bloqués par des **dépendances
structurelles manquantes** dans le schéma intégré :

1. **Schéma `acc`** — ONYX/02 référence `acc.bank_accounts` (×5) et
   `acc.bank_account_balances` (×1). Or les comptes bancaires vivent dans
   `client_demo.bank_accounts`, et **`bank_account_balances` n'existe nulle part**.
   → Décision à prendre : mapper `acc` → `client_demo`, et **créer la table
   `bank_account_balances`** (ou une vue d'agrégation des soldes) attendue par la
   trésorerie ONYX.
2. Rejouer ensuite `onyx/02→07` un à un (même méthode : déployer, corriger,
   vérifier), puis décommenter la section ONYX du manifeste et ajouter des tests
   pgTAP (trésorerie multi-pays, prix de transfert, secteur public).

## Vérifications effectuées (ce sprint)

- ✅ `scripts/db-build.sh` reconstruit JASPE + RUBIS + SAPHIR de zéro (exit 0, 151 tables).
- ✅ Test pgTAP SAPHIR (FX) : 6/6 (via harnais minimal ; le vrai pgTAP tourne en CI).
- ✅ `onyx/01` déploie sur la base intégrée + ponts (01 uniquement).

## Fichiers

```
db/integration/01_entities_bridge.sql        (nouveau)
db/integration/02_onyx_currencies_seed.sql   (nouveau)
tests/rpc/saphir/s01_fx_conversion_test.sql  (nouveau)
db/manifest.txt                              (SAPHIR activé, ONYX documenté)
tests/rpc/run_all.sql                        (+ test SAPHIR)
saphir/02, saphir/05                         (fixes de déploiement)
onyx/01, onyx/02, onyx/03                     (fixes + re-pointage entités)
```
