# Sprint 3 — ONYX complet (modules 04→07) · les 4 gammes intégrées

Aboutissement du chantier d'intégration des gammes. Les modules ONYX **04→07**
(consolidation, secteur public, réglementaire, intégration) sont désormais
activés dans le pipeline. **Les 4 gammes — JASPE, RUBIS, SAPHIR, ONYX — se
déploient de bout en bout depuis un dépôt vierge.**

## Résultat

| Gamme | Backend dans le pipeline |
|---|---|
| JASPE (TPE) | ✅ complet |
| RUBIS (PME) | ✅ complet |
| SAPHIR (ETI) | ✅ complet |
| **ONYX (GE/public)** | ✅ **complet (01→07)** |

Pipeline intégral vérifié via `scripts/db-build.sh` : reconstruction **de zéro,
exit 0, 279 tables (dont 84 dans le schéma `onyx`)**.

## Réconciliation du modèle (le blocage du Sprint 2)

ONYX a été écrit contre un modèle **UUID** (identifiants de tenant/entité en
UUID) et des tables `common.tenants` / `common.fiscal_years` / `saphir.group_entities`
qui n'existent pas dans le schéma intégré. Le socle, lui, est **BIGINT**. ONYX a
été harmonisé sur le socle (option 1 du Sprint 2), car les colonnes concernées
sont des clés étrangères « feuilles » (jamais des PK référencées) :

| Avant (ONYX) | Après (socle) |
|---|---|
| `tenant_id UUID` | `tenant_id BIGINT` |
| `fiscal_year_id UUID` | `fiscal_year_id BIGINT` |
| `REFERENCES common.tenants(id)` | `REFERENCES sys.tenants(id)` |
| `REFERENCES common.fiscal_years(id)` | `REFERENCES client_demo.fiscal_exercises(id)` |
| `REFERENCES saphir.group_entities(id)` (UUID) | `REFERENCES sys.tenant_entities(id)` (BIGINT) |
| `ge.legal_name` | `ge.entity_name` |

Les PK internes d'ONYX restent en UUID (modèle cohérent, non touché).

## Autres bugs de déploiement corrigés (04→07)

- **Schéma `saphir`** inexistant (SAPHIR vit dans `sys`) : `saphir.group_entities`
  → `sys.tenant_entities` (15 réfs dans onyx/04, FK + jointures).
- **Mot réservé** : colonne `references` (onyx/06) → `"references"` (quotée).

## Test

`tests/rpc/onyx/o02_public_sector_audit_test.sql` (5 assertions) :
- `rpc_check_appropriation` (secteur public) : rejet d'une imputation sur un
  crédit inexistant ;
- `fn_calculate_audit_hash` (piste d'audit inaltérable) : déterminisme,
  sensibilité au chaînage (`previous_hash`), longueur SHA-512 (128 hex).

## État final du chantier gammes (Sprints 0→3)

```
Sprint 0 : pipeline unifié + CI pgTAP + RUBIS
Sprint 1 : SAPHIR intégré
Sprint 2 : ONYX 01→03
Sprint 3 : ONYX 04→07  ← les 4 gammes déploient de zéro (279 tables)
```

Tests pgTAP de gamme : RUBIS (distribution analytique), SAPHIR (conversion FX),
ONYX (fiscalité multi-pays, contrôle budgétaire + intégrité d'audit) — tous au
vert (harnais minimal ; le vrai pgTAP s'exécute dans le job CI `pgtap`).

## Suites possibles (hors pipeline backend)

- Réconcilier la lignée `supabase/migrations/20260607*` (Lovable) — P0.1b, encore ouvert.
- Étendre la couverture pgTAP (facturation RUBIS, consolidation SAPHIR/ONYX, workflow).
- Commencer les **frontends** RUBIS/SAPHIR/ONYX (le backend est désormais déployable).
