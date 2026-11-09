# Sprint 2 — Activation d'ONYX (modules 01→03)

Suite des Sprints 0 et 1. Objectif : débloquer et intégrer la gamme **ONYX**
(GE / secteur public) dans le pipeline. Les modules **01→03** sont désormais
activés, déployés de bout en bout et testés ; **04→07** restent cadrés pour un
sprint ultérieur (divergence de modèle documentée ci-dessous).

## Résultat

| Module ONYX | État |
|---|---|
| `01_multicountry` (multi-pays, GAAP, fiscalité pays) | ✅ activé |
| `02_treasury` (trésorerie, cash pooling, netting, FX hedges) | ✅ activé |
| `03_transfer_pricing` (prix de transfert, CbCR) | ✅ activé |
| `04_consolidation` | ⛔ bloqué (modèle de tenant UUID) |
| `05_public_sector` | ⛔ bloqué (idem) |
| `06_regulatory` / `07_integration` | ⏸️ non repris (après 04/05) |

Pipeline complet vérifié via `scripts/db-build.sh` : reconstruction **de zéro,
exit 0, 195 tables, 26 pays ensemencés**.

## Ponts d'intégration (nouveaux)

ONYX a été écrit contre un contrat de schéma antérieur. Trois ponts réconcilient
les gammes **sans dupliquer la donnée** (ajoutés au manifeste avant `onyx/*`) :

| Pont | Rôle |
|---|---|
| `db/integration/01_entities_bridge.sql` | Expose `sys.tenant_entities.entity_id` (ONYX réfère `sys.entities(entity_id)`, RUBIS fournit `tenant_entities(id)`). |
| `db/integration/02_onyx_currencies_seed.sql` | Devises multi-pays manquantes (AED, CDF, CNY, GNF, KMF, NGN, ZAR). |
| `db/integration/03_bank_accounts_bridge.sql` | Expose `client_demo.bank_accounts.bank_account_id` (ONYX réfère `acc.bank_accounts(bank_account_id)`). |

## Bugs de déploiement corrigés (modules 01→03)

1. **FK devises** — `common.currencies(currency_code)` → `common.currencies(code)` (15 réfs).
2. **UNIQUE sur expression** — `UNIQUE(… COALESCE …)` → index unique sur expression.
3. **CTE récursive** — `v_consolidation_hierarchy` : `numeric(5,2)` vs `numeric` → cast de l'ancrage.
4. **Schéma `acc`** — `acc.bank_accounts` → `client_demo.bank_accounts` (+ pont `bank_account_id`).
   `acc.bank_account_balances` n'apparaissait que dans un commentaire (aucune table à créer).
5. **Schéma `onyx`** — utilisé par `onyx/04`/`05` sans être créé (créé seulement par 06/07) ;
   `CREATE SCHEMA IF NOT EXISTS onyx` déplacé en tête du premier consommateur.
6. **Table `sys.permissions`** — les seeds ONYX (02, 03) utilisaient
   `(permission_code, permission_name, permission_category)` alors que la table a
   `(permission_code, module_code, resource, action, description)`. Les VALEURS
   d'origine sont enveloppées dans un `SELECT` qui dérive les colonnes, avec un
   mapping de `action` vers le vocabulaire autorisé (VIEW→READ, MANAGE→UPDATE,
   EXECUTE/SWEEP/CONFIRM/DESIGNATE→APPROVE, …).

## Test

`tests/rpc/onyx/o01_country_tax_config_test.sql` (6 assertions) —
`rpc_get_country_tax_config` : code/nom/TVA/IS pour le Gabon et le Cameroun
(données CEMAC/OHADA) + accès à un pays international (France).

## Blocage restant : modules 04→07 (Sprint 3)

`onyx/04_consolidation` et `onyx/05_public_sector` déclarent
`tenant_id UUID REFERENCES common.tenants(id)` et référencent `common.tenants` /
`common.fiscal_years`, **qui n'existent pas** — le socle utilise
`sys.tenants(id BIGINT)`. C'est une **divergence de modèle** (identifiant de
tenant UUID vs BIGINT), pas un simple correctif.

Deux options pour le Sprint 3 :
1. **Harmoniser ONYX sur BIGINT** : re-pointer `common.tenants` → `sys.tenants`,
   changer `tenant_id UUID` → `BIGINT` dans onyx/04–07, et fournir
   `common.fiscal_years` (vue sur `client_demo.fiscal_exercises`).
2. **Introduire un identifiant UUID de tenant** côté socle (colonne `uuid` sur
   `sys.tenants` + cible de FK), si le reste d'ONYX suppose des UUID.
L'option 1 est la plus cohérente avec le socle existant.

## Vérifications effectuées

- ✅ `scripts/db-build.sh` reconstruit JASPE+RUBIS+SAPHIR+ONYX(01-03) de zéro (exit 0, 195 tables).
- ✅ Tests pgTAP RUBIS + SAPHIR + ONYX au vert (harnais minimal ; vrai pgTAP en CI).
