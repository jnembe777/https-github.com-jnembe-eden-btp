# NOYAU NORMATIF EDENFIN — Source de vérité unique
**Version : 1.0 — Juillet 2026**
**Portée : toutes les gammes EdenFin (JASPE, RUBIS, SAPHIR, ONYX)**

> Référence normative du programme EdenFin. Tout agent travaillant sur ce dépôt DOIT s'y conformer. En cas de conflit avec tout autre document, CE DOCUMENT PRÉVAUT sauf décision explicite du propriétaire (Jocelyn Nembé) consignée dans l'historique.

---

## 1. Référentiel réglementaire

| Domaine | Référence | Remarque |
|---|---|---|
| Comptabilité | **SYSCOHADA révisé** | Plan comptable 9 classes, ~1200 comptes. Jamais de compte en dur — lire depuis `chart_of_accounts`. |
| Zone monétaire JASPE/RUBIS | **CEMAC / XAF** | Code ISO : XAF. Jamais XOF (UEMOA). |
| Zone monétaire SAPHIR/ONYX | Multi-devises | XAF par défaut. Autres devises via table `currencies`. |
| Charges sociales | **CNSS, CRF, CNAMGS** (Gabon) | Taux lus depuis `contribution_rates` — jamais en dur. |
| TVA | **DGI Gabon** | Taux lus depuis `tax_rates` — jamais en dur. |
| Amortissements | **OHADA** | Coefficients (1.25/1.75/2.25) lus depuis `asset_categories`. |
| Exercice fiscal | Année civile (01/01→31/12) | Journée complémentaire paramétrable. |
| Déclarations | Bilan, Compte de résultat, TAFIRE, Annexes | Obligatoires SYSCOHADA. |

**Règle d'implémentation absolue** : aucun taux, seuil, code comptable, ou paramètre réglementaire n'est codé en dur. Toute valeur susceptible de changer avec la législation est dans une table de paramétrage. Cette règle est vérifiée en code review.

## 2. Invariants comptables

1. **Équilibre Débit = Crédit** : toute écriture comptable validée doit être équilibrée. Contrôle obligatoire dans la RPC ET dans le formulaire. Échec bloquant.
2. **Irréversibilité des validations** : une écriture POSTED ne peut pas être supprimée ni modifiée — uniquement contre-passée. Un bulletin de paie CLOSED est immuable. Une période LOCKED est définitive.
3. **Séquentialité des numéros de pièce** : pas de trou dans la numérotation des pièces comptables par journal. Généré par séquence PostgreSQL, jamais côté client.
4. **Rattachement à la période** : toute écriture est rattachée à une période fiscale ouverte. Blocage si période LOCKED.
5. **Traçabilité** : toute opération sensible (validation, clôture, calcul paie) est journalisée dans `audit_log` avec user_id, timestamp, payload.

## 3. Workflows d'état (invariants)

```
Écriture comptable : DRAFT → POSTED (irréversible)
                             ↓ contre-passation uniquement
Bulletin de paie :   OPEN  → CLOSED (irréversible)
Période fiscale :    OPEN  → LOCKED (irréversible)
Immobilisation :     ACTIVE → DISPOSED (irréversible)
```

**Règle DELETE** : aucun DELETE sur les entités ci-dessus une fois validées. L'annulation se fait par transition d'état ou contre-passation. Cette règle est vérifiée en CI (pas de `DELETE FROM journal_entries WHERE status = 'POSTED'`).

## 4. Architecture multi-tenant

- Isolation par `company_id` via **RLS Supabase** sur toutes les tables métier.
- Un agent ne désactive jamais la RLS, ne contourne jamais `company_id`.
- Schéma `common` : référentiels partagés (plan comptable OHADA de base, devises, pays).
- Schéma par tenant : données isolées. Nommage : `client_<code>` ou schéma Supabase default avec RLS.
- Policy type : `USING (company_id = (auth.jwt() ->> 'company_id')::uuid)`.

## 5. Paramétrage — règles de qualité

| Paramètre | Table | Jamais en dur |
|---|---|---|
| Taux CNSS salarié/patronal | `contribution_rates` | ✅ |
| Taux CRF, CNAMGS | `contribution_rates` | ✅ |
| Taux TVA (18%, 0%, exonéré) | `tax_rates` | ✅ |
| Coefficients amortissement | `asset_categories` | ✅ |
| Comptes OHADA de contrepartie | `payroll_rubrics`, `asset_categories` | ✅ |
| Plafonds de cotisation | `contribution_rates` | ✅ |
| Journaux comptables | `journals` | ✅ |

Le CI (`grep` sur les RPC SQL) interdit : `* 0.025` (taux CNSS), `* 0.18` (TVA), `'604'` (comptes en dur), etc.

## 6. Conventions de code

1. **Montants** : `NUMERIC(15,2)` en base, `formatXAF()` à l'affichage — jamais de FLOAT.
2. **Dates** : UTC en base, `formatDate()` à l'affichage, `formatPeriod()` pour mois/année.
3. **Codes comptables** : `VARCHAR(20)`, référencés depuis `chart_of_accounts` — jamais de chaîne libre.
4. **IDs** : UUID v4 (`uuid_generate_v4()`) — jamais de SERIAL exposé en API.
5. **Nommage RPC** : `rpc_<verbe>_<objet>` (ex: `rpc_calculate_payroll`, `rpc_close_fiscal_period`).
6. **Nommage tables** : snake_case, pluriel (ex: `journal_entries`, `payroll_rubrics`).

## 7. Progression gammes (ne pas anticiper)

Un agent travaillant sur JASPE ne code jamais de fonctionnalité RUBIS/SAPHIR/ONYX, même si elle semble utile. La progression est :

- JASPE → RUBIS : ajouter `tenant_entities`, axes analytiques, budgets
- RUBIS → SAPHIR : ajouter multi-devises, IFRS, workflow d'approbation
- SAPHIR → ONYX : ajouter multi-pays, consolidation avancée, trésorerie groupe

Toute fonctionnalité inter-gamme nécessite une issue `architecture-decision` approuvée.

## 8. Procédure de modification

1. Toute modification requiert la validation du propriétaire (Jocelyn Nembé).
2. Les agents ne modifient jamais ce document — `normative-conflict` si contradiction détectée.
3. Chaque modification incrémente la version et est consignée ci-dessous.

## Historique

| Version | Date | Modification |
|---|---|---|
| 1.0 | 2026-07-07 | Création à partir du BILAN_AVANCEMENT et des architectures JASPE/RUBIS/SAPHIR/ONYX. |
