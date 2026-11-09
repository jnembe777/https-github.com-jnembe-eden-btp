# CLAUDE.md — EdenFin (`edenfin-your-financial-garden`)

> Constitution du dépôt pour les agents autonomes (Claude Code).
> Références normatives supérieures : `NOYAU-NORMATIF-EDENFIN.md` et `STANDARD-UI-TPD.md`.
> En cas de conflit avec toute autre spec : ne code pas, pose `normative-conflict`, suspends.

---

## 1. Identité du projet

**EdenFin** — Suite ERP OHADA/CEMAC pour entreprises africaines, déclinée en 4 gammes progressives. Dépôt unique, code organisé par gamme. Cible primaire : Gabon (CEMAC, XAF, SYSCOHADA révisé).

| Gamme | Cible | Max entités | État |
|---|---|---|---|
| **JASPE** | TPE <10 salariés, <500M XAF CA | 1 | **En cours — phases 1-10 avancées** |
| **RUBIS** | PME 10-50, <2B XAF | 5 | Spécifié, non implémenté |
| **SAPHIR** | ETI 50-250, <10B XAF | 20 | Spécifié, non implémenté |
| **ONYX** | GE 250+, multi-pays | Illimité | Spécifié, non implémenté |

**Repo GitHub** : https://github.com/jnembe777/Finsys

## 2. Stack technique (ne pas dévier)

| Couche | Technologie |
|---|---|
| Build | Vite |
| Frontend | React 18 + TypeScript |
| UI | Tailwind CSS + shadcn/ui |
| Routing | TanStack Router (`_authenticated`) |
| Data fetching | TanStack Query (React Query) |
| Backend | Supabase : PostgreSQL, RPC, RLS, Auth |
| Schémas DB | `common` (partagé multi-tenant) + `client_demo` (par tenant) |

Interdictions : pas de nouvelle librairie UI sans issue `architecture-decision`.

## 3. Architecture multi-tenant

Isolation par `company_id` via RLS Supabase. Schéma `common` = référentiels partagés (devises, pays, plan comptable OHADA). Schéma `client_demo` (ou par tenant) = données métier isolées.

**Règle absolue** : toute nouvelle table métier a sa policy RLS `company_id = auth.jwt() ->> 'company_id'` avant merge. Ne jamais bypasser la RLS.

## 4. Composants UI établis (ne pas réécrire)

| Composant | Fichier | Usage |
|---|---|---|
| `SmartGrid` | `src/components/edenfin/smart-grid.tsx` | CRUD référentiels (niveau T) |
| `EntityFormDrawer` | `src/components/edenfin/entity-form-drawer.tsx` | Formulaires dynamiques |
| `RPCPanel` | `src/components/edenfin/rpc-panel.tsx` | Exécution fonctions RPC |
| `JournalEntryForm` | `src/components/edenfin/journal-entry-form.tsx` | Saisie écritures SYSCOHADA |
| `DataTable` | `src/components/edenfin/data-table.tsx` | Rapports lecture seule |
| `KpiCard / KpiGrid` | `src/components/edenfin/dashboard-kpis.tsx` | Dashboard KPI (niveau D) |

**Patron T/P/D** (STANDARD-UI-TPD) :
- **T** : SmartGrid + EntityFormDrawer (référentiels, écritures)
- **P** : RPCPanel + workflows d'état (DRAFT→POSTED→LOCKED)
- **D** : DataTable + KpiGrid (rapports, dashboard)

## 5. État d'avancement JASPE (phase courante)

### Terminées ✅
- **Phase 1** CDC : 6 modules, cible OHADA/CEMAC Gabon
- **Phase 2** SFG : 8 modules, cas d'usage CU-COMPTA/PAIE/etc., 5 rôles
- **Phase 3** MCD/MCT : 42 entités, 13 traitements T1→T13
- **Phase 4** MLD/MPD/MOT : 42 tables PostgreSQL, schéma dual common/client
- **Phase 5** Classes métier : 8 services JS (~650 lignes)
- **Phase 8** Base de données : 10 scripts SQL, 42 tables, plan comptable 1200+ comptes
- **Phase 9** RPC T1→T13 : 13 fonctions implémentées, paramétrage externalisé ✅

### En cours 🔄
- **Phase 10** Connexion DB↔Interfaces : Plan comptable connecté, Dashboard mock→réel en cours
- **Phase 7** UI : SmartGrid/Forms/DataTable migrés, pages Comptabilité/Paie/Trésorerie à connecter

### À faire ⏳
- Phase 6 SFD (partiel) : fiches écran à compléter pour Paie, Trésorerie
- Phase 10 : connecter pages Comptabilité, Paie, Trésorerie à Supabase
- Phase 11 : authentification complète (LoginPage, AuthProvider, sessions)
- Phase 12 : backend finalization (edge functions, cron, hardening)
- Phase 13 : tests unitaires (pgTAP pour RPC, Vitest pour services)
- Phase 14 : tests processus E2E
- Phase 15 : déploiement Vercel + Supabase production

## 6. Modules JASPE et leur état

| Module | Pages | Supabase | Statut |
|---|---|---|---|
| Comptabilité | `/console/comptabilite` | ❌ mock | **P0 — à connecter** |
| Plan comptable | `/console/plan-comptable` | ✅ connecté | Fonctionnel |
| Dashboard | `/console/dashboard` | ⚠️ fallback mock | **P1 — vues SQL à créer** |
| Fonctions RPC | `/console/rpc-functions` | ✅ connecté | Fonctionnel |
| Paie | `/console/paie` | ❌ non implémenté | **P1 — sprint futur** |
| Trésorerie | `/console/tresorerie` | ❌ non implémenté | **P1 — sprint futur** |

## 7. Règles métier verrouillées (NOYAU-NORMATIF-EDENFIN)

1. **Aucune constante OHADA en dur** : taux CNSS, CRF, CNAMGS, taux TVA, coefficients amortissement → lus depuis tables de paramétrage (`contribution_rates`, `tax_rates`, `asset_categories`). Les 13 RPC T1→T13 appliquent déjà cette règle — ne jamais la régresser.
2. **Plan comptable SYSCOHADA** : 9 classes, ~1200 comptes, classes 1-8 actives, classe 9 analytique.
3. **Équilibre Débit = Crédit** : toute écriture validée doit être équilibrée — contrôle dans `rpc_create_journal_entry` ET dans `JournalEntryForm`.
4. **Workflows d'état immuables** : écriture DRAFT→POSTED (irréversible), bulletin OPEN→CLOSED, période OPEN→LOCKED. Pas de DELETE, uniquement des transitions de statut.
5. **Devise XAF exclusivement** pour JASPE et RUBIS. SAPHIR introduit le multi-devises — ne pas anticiper.
6. **Multi-tenant** : isolation par `company_id` via RLS — jamais contournable.
7. **Formatters obligatoires** : montants via `formatXAF()`, dates via `formatDate()`, périodes via `formatPeriod()` — jamais de format ad hoc.

## 8. Workflow des agents

1. Prendre l'issue `ready` prioritaire (`P0` > `P1` > `P2`).
2. Branche `feat/jaspe-<slug>` ou `fix/jaspe-<slug>` (préfixer par la gamme).
3. Implémenter selon §4-§7. Pour toute nouvelle page : déclarer le niveau T/P/D.
4. PR liée à l'issue : pages touchées, tables/RPC impliquées, checklist cochée.
5. `human-review-required` si : RLS modifiée · nouvelles migrations SQL · auth · GRID_REGISTRY modifié (impacte toutes les gammes).
6. Escalade : `normative-conflict` (constante OHADA en dur détectée), `business-question` (règle CEMAC ambiguë), `spec-gap` (cas d'usage non documenté).
7. Ne jamais merger. Finir par `agent-done`, retirer `ready`.

### Définition de terminé
- [ ] CI verte (quality, souverainete, validate-ui, migrations)
- [ ] RLS en place sur toute nouvelle table
- [ ] Zéro constante OHADA/CEMAC en dur (taux, codes, seuils)
- [ ] Formatters XAF/date utilisés partout
- [ ] Workflows d'état respectés (pas de DELETE sur entrées validées)
- [ ] Tests unitaires pour toute nouvelle fonction RPC (pgTAP)

## 9. Commandes

```bash
npm install          # dépendances
npm run dev          # serveur dev Vite (http://localhost:8084/)
npm run build        # build production
npm run lint         # ESLint
npm run typecheck    # tsc --noEmit
npm test             # Vitest
```

Scripts SQL (dans Supabase SQL Editor, dans l'ordre) :
```
01-schemas-and-rbac.sql → 02-common-tables.sql → 03-client-tables.sql
→ 04-rpc-functions.sql → 05-views-and-policies.sql → 06-seed-data.sql
```

## 10. Backlog actuel (à convertir en issues)

**P0 — Débloquer JASPE**
1. Connecter page Comptabilité à Supabase (remplacer mock par `useSupabaseQuery("entries")`)
2. Créer vues SQL dashboard (`monthly_sales`, `kpi_summary`) et connecter Dashboard
3. Implémenter page Paie (SmartGrid employés + RPCPanel T5/T6/T7)
4. Implémenter page Trésorerie (SmartGrid transactions + RPCPanel T4/T11)
5. Authentification : `LoginPage.tsx`, `AuthProvider`, protection routes `_authenticated`

**P1 — Qualité**
6. Tests unitaires pgTAP pour T1→T13
7. Tests Vitest pour les 8 services métier
8. Initialiser la base Supabase de développement (6 scripts SQL dans l'ordre)

**P2 — Gamme RUBIS**
9. Implémenter `sys.tenant_entities` (multi-entités)
10. Implémenter axes analytiques (`analytical_axes`, `analytical_values`)
