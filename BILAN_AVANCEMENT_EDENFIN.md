# 📊 BILAN D'AVANCEMENT — Projet EdenFin
## État au 9 février 2026

---

# PARTIE 1 — GAMME JASPE : CE QUI A ÉTÉ RÉALISÉ

## 1.1 Documentation & Spécifications

### ✅ Phase 1 — Cahier des charges
- Périmètre défini : TPE (<10 salariés, <500M XAF CA)
- 6 modules identifiés : Comptabilité, Paie, Immobilisations, Trésorerie, Tiers, Fiscal
- Cible OHADA/CEMAC (Gabon) avec devises XAF
- Stack technique arrêté : React + Supabase (PostgreSQL)
- **Livrable** : `PROJET_EDENFIN_LIVRABLES_COMPLETS.md` (21 KB)

### ✅ Phase 2 — Spécifications fonctionnelles générales
- 8 modules spécifiés avec sous-modules
- Cas d'usage numérotés par module (CU-COMPTA-xxx, CU-PAIE-xxx, etc.)
- 5 rôles définis : ADMIN, COMPTABLE, RH_PAIE, TRESORIER, DIRECTEUR
- Règles métier codifiées (RG-COMPTA-001 à RG-IMMO-002)
- **Livrables** : `SFD_EDENFIN_PARTIE1.md` (139 KB), `SFD_EDENFIN_SYNTHESE.md` (19 KB), `SFD_EDENFIN_CAS_USAGE.md` (36 KB), `SFD_EDENFIN_UX_UI.md` (113 KB)

### ✅ Phase 3 — MCD & MCT
- Modèle conceptuel de données : 42 entités identifiées (31 métier + 11 paramétrage)
- Modèle conceptuel de traitements : 13 traitements catalogués (T1→T13)
- Associations et cardinalités définies
- Diagrammes Mermaid produits
- **Livrables** : `MCT_EDENFIN.md` (34 KB), `MCT_EDENFIN_DIAGRAMMES.md` (39 KB)

### ✅ Phase 4 — MLD, MPD, MOT
- Transformation MCD→MLD réalisée (42 tables relationnelles)
- Typage PostgreSQL complet (numeric(15,2) pour montants, varchar(20) pour codes, etc.)
- Schéma dual : `common` (partagé) + `client_demo` (par tenant)
- Modèle opérationnel : mapping MCT→fonctions RPC PostgreSQL
- **Livrables** : `MOT_EDENFIN_DIAGRAMMES_OUTILS.md` (92 KB), `STD_EDENFIN.md` (70 KB)

### ✅ Phase 6 — Spécifications détaillées (partiel)
- Workflows d'état documentés : écriture (DRAFT→POSTED), bulletin (OPEN→CLOSED), période fiscale (OPEN→LOCKED)
- Fiches écran pour les pages SmartGrid (11 entités)
- Types de formulaires définis : EntityFormDrawer (Type A), RPCDialog (Type B), JournalEntryForm (Type C)
- **Livrable** : `SFD_EDENFIN_UX_UI.md`

---

## 1.2 Base de données

### ✅ Phase 8 — Base de données physique (complet)
10 scripts SQL de migration séquentiels, prêts à déployer sur Supabase :

| Script | Contenu | Statut |
|--------|---------|--------|
| `00_extensions.sql` | uuid-ossp, pgcrypto, pg_trgm | ✅ Prêt |
| `01_schema_common.sql` | 14 tables partagées (companies, currencies, users, roles, audit_log, etc.) | ✅ Prêt |
| `02_schema_system.sql` | Tables système (auth integration, séquences) | ✅ Prêt |
| `03_schema_jaspe_demo.sql` | 17 tables métier (accounts, journals, entries, employees, payslips, assets, etc.) | ✅ Prêt |
| `04_seed_ohada.sql` | Plan comptable OHADA (~50 comptes essentiels), journaux, exercice fiscal | ✅ Prêt |
| `05_rls_policies.sql` | Row Level Security par tenant (company_id) sur toutes les tables | ✅ Prêt |
| `06_rpc_business_functions.sql` | 13 fonctions RPC métier (T1→T13) | ✅ Prêt |
| `07_payroll_parameter_tables.sql` | 8 tables paramétrage paie (rubrics, rates, variables, periods, absences, leaves, cumuls) | ✅ Prêt |
| `08_asset_and_accounting_tables.sql` | 3 tables (asset_categories, reconciliation_groups, fiscal_exercises) | ✅ Prêt |
| `09_seed_parameter_data.sql` | Données CEMAC/Gabon : 28 rubriques paie, 9 barèmes cotisations, 12 types absences, 12 catégories immo, périodes 2026 | ✅ Prêt |

**Total : 42 tables, 13 fonctions RPC, ~80 enregistrements de seed**

### ✅ Plan comptable OHADA complet
- `plan_comptable_ohada_complet.sql` : 1200+ comptes SYSCOHADA révisé (classes 1-9)
- Prêt à injection en complément du seed simplifié

---

## 1.3 Couche transactionnelle (RPC)

### ✅ Phase 9 — Connexion DB↔Traitements (complet)
13 fonctions RPC PostgreSQL implémentées :

| ID | Fonction RPC | Module | Statut | Paramétrage |
|----|-------------|--------|--------|-------------|
| T1 | `rpc_create_journal_entry` | Comptabilité | ✅ Implémentée | — |
| T2 | `rpc_validate_journal_entry` | Comptabilité | ✅ Implémentée | — |
| T3 | `rpc_auto_lettrage` | Comptabilité | ✅ Implémentée | — |
| T4 | `rpc_auto_reconcile_bank` | Trésorerie | ✅ Implémentée | — |
| T5 | `rpc_calculate_payroll` | Paie | ✅ Implémentée | ✅ Lit contribution_rates |
| T6 | `rpc_validate_payslip` | Paie | ✅ Implémentée | — |
| T7 | `rpc_generate_payroll_entries` | Paie→Compta | ✅ Implémentée | ✅ Lit payroll_rubrics |
| T8 | `rpc_generate_depreciation` | Immobilisations | ✅ Implémentée | ✅ Lit asset_categories |
| T9 | `rpc_generate_tva_declaration` | Fiscal | ✅ Implémentée | ✅ Lit tax_rates |
| T10 | `rpc_close_fiscal_period` | Comptabilité | ✅ Implémentée | — |
| T11 | `rpc_cash_forecast` | Trésorerie | ✅ Implémentée | — |
| T12 | `rpc_financial_ratios` | Reporting | ✅ Implémentée | — |
| T13 | `rpc_dashboard_kpi` | Dashboard | ✅ Implémentée | — |

**Correction critique réalisée** : les RPC lisent désormais les tables de paramétrage au lieu d'utiliser des constantes codées en dur (ex: taux CNSS 2.5% lu depuis `contribution_rates` au lieu de `v_brut * 0.025`).

### ✅ Phase 5 — Classes métier (partiel)
- 8 classes service JavaScript implémentées (~650 lignes)
- BaseService CRUD générique
- Services spécialisés : Account, Journal, Partner, Employee, Payroll, Asset, Treasury, Dashboard
- Mapping Service↔GRID_REGISTRY documenté
- **Livrable** : `edenfin-services.js`

### ✅ Matrice de traçabilité
- Mapping complet MCT→RPC→Service→UI
- **Livrable** : `MATRICE_TRACABILITE_JASPE.md`

---

## 1.4 Interface utilisateur (React)

### ✅ Phase 7 — Interfaces UI (avancé)
8 versions progressives du prototype React, aboutissant à une application fonctionnelle :

**Version courante : `EdenFin-SmartGrid-v3.jsx` (898 lignes)**

Fonctionnalités UI implémentées :

| Fonctionnalité | Statut | Détails |
|---------------|--------|---------|
| Navigation sidebar | ✅ | 7 modules avec sous-menus, icônes, badges SmartGrid/RPC |
| Dashboard KPIs | ✅ | 6 cartes (CA, Résultat, Trésorerie, Masse salariale, DSO, Marge nette) + graphique évolution |
| SmartGrid réutilisable | ✅ | Composant unique `<SmartGrid>` avec tri, filtre, groupement, recherche, pagination, sélection multiple, menu contextuel, ligne de totaux |
| 11 grilles configurées | ✅ | accounts, employees, partners, payroll_rubrics, contribution_rates, absence_types, asset_categories, fixed_assets, entries, bank_accounts, bank_transactions |
| GRID_REGISTRY | ✅ | Configuration déclarative des colonnes (type, width, editable, badgeMap, render) |
| EntityFormDrawer | ✅ | Formulaire auto-généré depuis GRID_REGISTRY, 7 types de champs (text, number, currency, percent, date, boolean, badge/select) |
| CRUD complet | ✅ | Créer (bouton Nouveau), Modifier (double-clic), Dupliquer (menu contextuel), Supprimer (menu contextuel) |
| Validation formulaire | ✅ | Champs requis, animation shake sur erreur |
| Toast notifications | ✅ | Succès/erreur/warning avec auto-dismiss |
| Thème clair/sombre | ✅ | Dual palette complète, toggle dans le header, tous composants thématisés |
| RPCPanel | ✅ | Exécution et affichage des résultats RPC (calcul paie, amortissements) avec panneau avant/après |
| Formatage OHADA | ✅ | Montants XAF avec séparateurs, dates DD/MM/YYYY, badges colorés pour statuts |
| Mock RPC Engine | ✅ | Simulation réaliste des 13 fonctions RPC avec données mock CEMAC/Gabon |

---

## 1.5 Architecture & Décisions techniques

### ✅ Documents d'architecture produits

| Document | Décision clé |
|----------|-------------|
| `ARCHITECTURE_SMARTGRID_RPC.md` | Deux couches : SmartGrid+DataAdapter pour CRUD, RPC pour traitements complexes |
| `ARCHITECTURE_3_NIVEAUX_UI.md` | DataTable (consultation) / SmartGrid (gestion) / Forms (traitements) — critères de choix |
| `AUDIT_TABLES_MANQUANTES.md` | Gap analysis : 11 tables paramétrage identifiées et corrigées |
| `GUIDE_DEPLOIEMENT_SUPABASE.md` | Procédure pas-à-pas de déploiement des migrations |
| `GUIDE_CONNEXION_SUPABASE_REACT.md` | Intégration frontend↔backend |

### ✅ Skill méthodologique
- 15 phases documentées en fichiers .md réutilisables
- 4 templates d'assets (migration SQL, RPC, GRID_REGISTRY, EntityForm)
- Package `.skill` prêt à importer
- **Livrable** : `erp-ohada-methodology.skill`

---

## 1.6 Synthèse JASPE — Taux de complétion par phase

| Phase | Intitulé | Complétion | Notes |
|-------|---------|-----------|-------|
| 1 | Cahier des charges | ✅ 100% | CDC complet |
| 2 | Spécifications fonctionnelles générales | ✅ 100% | 8 modules, cas d'usage, règles métier |
| 3 | MCD & MCT | ✅ 100% | 42 entités, 13 traitements |
| 4 | MLD, MPD, MOT | ✅ 100% | Schéma SQL complet, patron RPC |
| 5 | Classes métier | ⚠️ 70% | 8 services créés, manque tests + injection Supabase réelle |
| 6 | Spécifications détaillées | ⚠️ 60% | Workflows d'état OK, manque fiches écran exhaustives |
| 7 | Interfaces UI | ⚠️ 75% | SmartGrid+Forms+Thèmes OK, manque DataTable consultation et JournalEntryForm |
| 8 | Base de données physique | ✅ 100% | 10 migrations, 42 tables, seed CEMAC/Gabon |
| 9 | Connexion DB↔Traitements | ✅ 95% | 13 RPC, paramétrage corrigé, manque tests en base réelle |
| 10 | Connexion DB↔Interfaces | ⚠️ 40% | SupabaseDataAdapter conçu, hooks esquissés, non connecté en production |
| 11 | Authentification | 🔴 10% | Architecture RLS posée (migration 05), Auth non implémenté côté React |
| 12 | Backend finalization | 🔴 5% | Edge Functions et cron non développés |
| 13 | Tests unitaires | 🔴 0% | Aucun test pgTAP ni Vitest écrit |
| 14 | Tests des processus | 🔴 0% | Aucun test E2E écrit |
| 15 | Déploiement | 🔴 0% | Non déployé sur Supabase réel |

**Taux de complétion global JASPE : ~55%**

---

# PARTIE 2 — GAMME JASPE : CE QUI RESTE À FAIRE

## 2.1 Priorité P0 — Connexion réelle Supabase (Semaines 1-3)

### Tâche J-01 : Déploiement base de données
- Créer un projet Supabase (région Europe)
- Exécuter les 10 scripts de migration (00→09) via SQL Editor
- Vérifier les 42 tables créées, les 13 RPC fonctionnelles
- Injecter le plan comptable OHADA complet (1200+ comptes)
- **Critère de succès** : `SELECT rpc_calculate_payroll(2, 2026)` retourne `success: true` avec source `contribution_rates`

### Tâche J-02 : SupabaseDataAdapter réel
- Implémenter `SupabaseDataAdapter` (CRUD générique) connecté au client Supabase JS
- Créer le hook `useGridData(tableName, gridConfig)` qui remplace les données mock
- Intégrer dans SmartGrid : les 11 grilles lisent/écrivent en base réelle
- Gérer les erreurs Supabase avec messages français (code 23505 → "doublon", etc.)
- **Critère de succès** : créer un employé via EntityFormDrawer → visible en base Supabase

### Tâche J-03 : Appels RPC réels
- Remplacer le Mock RPC Engine par `supabase.rpc('function_name', params)`
- Connecter RPCPanel → appels réels
- Afficher les résultats réels du calcul de paie et des amortissements
- **Critère de succès** : lancer le calcul de paie depuis l'UI → bulletins créés en base

---

## 2.2 Priorité P1 — Authentification & Sécurité (Semaines 3-5)

### Tâche J-04 : Module d'authentification React
- Page de login (email + mot de passe) avec Supabase Auth
- Page de réinitialisation de mot de passe
- AuthProvider React avec session management
- Protection des routes (redirect si non authentifié)
- Affichage du nom/rôle de l'utilisateur dans le header

### Tâche J-05 : RBAC côté frontend
- Hook `usePermission(requiredRole)` vérifiant `app_metadata.role`
- Masquer les menus/boutons selon le rôle (ex: COMPTABLE ne voit pas Paie)
- Désactiver les actions interdites (ex: AUDITEUR ne peut pas modifier)
- Page admin de gestion des utilisateurs (ADMIN seulement)

### Tâche J-06 : Vérification RLS
- Tester que chaque rôle ne voit que les données de sa company
- Tester que les politiques d'écriture/suppression sont respectées
- Documenter les résultats dans un rapport de tests de sécurité

---

## 2.3 Priorité P2 — Compléments UI (Semaines 5-8)

### Tâche J-07 : DataTable consultation (Tier 1)
- Composant `DataTable` en lecture seule pour les résultats RPC
- Grand livre : affichage des écritures validées par compte avec soldes
- Balance générale : tous les comptes avec débits/crédits/soldes
- Journal de paie : historique des bulletins validés
- Tableau d'amortissements : plan d'amortissement par immobilisation
- Export CSV et impression PDF

### Tâche J-08 : JournalEntryForm (Tier 3 — Type C)
- Formulaire multi-lignes pour saisie d'écritures comptables
- En-tête : journal, date, libellé
- Grille de lignes : compte (autocomplete), libellé ligne, débit, crédit
- Contrôle d'équilibre en temps réel (∑D = ∑C)
- Boutons : Enregistrer brouillon / Valider
- Appel RPC `rpc_create_journal_entry` puis optionnel `rpc_validate_journal_entry`

### Tâche J-09 : Améliorations SmartGrid
- Édition inline (double-clic sur cellule pour modifier en place)
- Opérations batch (sélection multiple → supprimer / exporter / changer statut)
- Redimensionnement des colonnes par drag
- Persistance des préférences utilisateur (largeurs, tri, filtres) en localStorage

### Tâche J-10 : États financiers
- Bilan OHADA : généré depuis les soldes des comptes (classes 1-5)
- Compte de résultat : classes 6-7
- TAFIRE (Tableau Financier des Ressources et Emplois) : flux de trésorerie OHADA
- Affichage en DataTable avec mise en forme comptable
- Export PDF formaté

---

## 2.4 Priorité P3 — Backend & Production (Semaines 8-12)

### Tâche J-11 : Edge Functions Supabase
- `send-payslip-email` : envoi bulletin PDF par email après validation
- `generate-pdf-report` : génération Bilan/CR/TAFIRE en PDF
- `import-bank-statement` : parsing relevé bancaire (CSV au minimum)

### Tâche J-12 : Cron jobs
- Rappels de clôture comptable (J-3 fin de mois)
- Clôture automatique des périodes de paie (J+5 mois suivant)
- Nettoyage audit_log > 2 ans

### Tâche J-13 : Real-time subscriptions
- Abonnement Supabase Realtime sur les tables critiques
- Notification quand une écriture est validée par un autre utilisateur
- Rafraîchissement automatique des grilles lors de modifications concurrentes

### Tâche J-14 : Hardening
- Configuration CORS pour le domaine de production uniquement
- Rate limiting sur les endpoints publics
- Rotation des clés API
- Headers de sécurité (CSP, HSTS, X-Frame-Options)

---

## 2.5 Priorité P4 — Tests & Qualité (Semaines 10-14)

### Tâche J-15 : Tests unitaires RPC (pgTAP)
- 1 suite de tests par fonction RPC (13 suites)
- Tests positifs (scénario nominal)
- Tests négatifs (paramètres invalides, données manquantes)
- Tests de non-régression (vérifier absence de constantes en dur)
- Couverture cible : 100% des fonctions RPC

### Tâche J-16 : Tests unitaires JavaScript (Vitest)
- Tests des 8 classes service (mocks Supabase)
- Tests des composants React critiques (SmartGrid, EntityFormDrawer)
- Tests des utilitaires (formatage montants, dates)
- Couverture cible : 80%

### Tâche J-17 : Tests de processus E2E (Playwright)
- PROC-COMPTA-001 : Cycle écriture comptable (créer → valider → contre-passer)
- PROC-PAIE-001 : Cycle paie mensuel (calculer → vérifier → valider → OD)
- PROC-IMMO-001 : Calcul amortissements (lancer → vérifier dotations → vérifier VNC)
- PROC-FISC-001 : Clôture période (vérifier prérequis → clôturer → tester verrouillage)
- Couverture cible : 4 processus complets validés

---

## 2.6 Priorité P5 — Déploiement (Semaine 14-16)

### Tâche J-18 : Environnement staging
- Projet Supabase staging avec migrations
- Frontend déployé sur Vercel (preview URL)
- Tests de processus exécutés sur staging
- Validation fonctionnelle

### Tâche J-19 : Mise en production
- Projet Supabase production
- Frontend production (domaine final)
- Création du compte ADMIN initial
- Chargement des données de démarrage client
- Monitoring 48h post-déploiement

### Tâche J-20 : Documentation utilisateur
- Guide utilisateur par module (PDF)
- Aide contextuelle intégrée dans l'application
- Sessions de formation (Prise en main, Comptabilité, Paie, Administration)

---

## 2.7 Estimation restante JASPE

| Priorité | Tâches | Effort estimé | Semaines |
|----------|--------|--------------|----------|
| P0 | Connexion Supabase réelle | Fort | Sem. 1-3 |
| P1 | Authentification & RBAC | Moyen | Sem. 3-5 |
| P2 | Compléments UI | Fort | Sem. 5-8 |
| P3 | Backend & production | Moyen | Sem. 8-12 |
| P4 | Tests & qualité | Moyen | Sem. 10-14 |
| P5 | Déploiement | Léger | Sem. 14-16 |

**Estimation totale : 14-16 semaines supplémentaires pour JASPE complet en production.**

---

# PARTIE 3 — GAMMES RUBIS, SAPHIR, ONYX : CE QUI RESTE À FAIRE

## 3.1 Vue d'ensemble des gammes

| Gamme | Cible | CA max | Employés | Modules ajoutés vs gamme précédente |
|-------|-------|--------|----------|-------------------------------------|
| **JASPE** | TPE | <500M XAF | <10 | Comptabilité, Paie simplifiée, Immobilisations, Trésorerie, Tiers, Fiscal |
| **RUBIS** | PME | <2B XAF | 10-50 | + Comptabilité analytique, Budgets, Multi-sociétés, Gestion commerciale |
| **SAPHIR** | ETI | <10B XAF | 50-250 | + Consolidation, Multi-devises, Audit avancé, Workflow, BI intégrée |
| **ONYX** | GE / Public | >10B XAF | 250+ | + Multi-pays, IFRS, API ouvertes, Nomenclatures secteur public |

**Principe d'extension** : chaque gamme hérite de la précédente et ajoute des modules. Le code JASPE est le socle de tout.

---

## 3.2 RUBIS — PME (Estimation : 8-12 semaines sur base JASPE)

### 3.2.1 Schéma de données — Tables à ajouter (~15 tables)

| Table | Description | Complexité |
|-------|-------------|-----------|
| `analytical_plans` | Plans analytiques (5 axes max) | Moyenne |
| `analytical_axes` | Axes d'analyse (centre de coût, projet, produit) | Moyenne |
| `analytical_distributions` | Ventilation analytique des écritures | Forte |
| `budget_structures` | Structures budgétaires (par département, projet) | Moyenne |
| `budget_lines` | Lignes budgétaires (compte × axe × période) | Forte |
| `budget_revisions` | Historique des révisions budgétaires | Faible |
| `entities` | Entités juridiques (multi-sociétés) | Moyenne |
| `intercompany_transactions` | Transactions inter-sociétés | Forte |
| `consolidation_rules` | Règles d'élimination pour consolidation | Forte |
| `collective_agreements` | Conventions collectives intégrées | Moyenne |
| `payroll_grids` | Grilles salariales par convention | Moyenne |
| `sales_invoices` | Factures de vente | Moyenne |
| `purchase_invoices` | Factures d'achat | Moyenne |
| `products` | Catalogue produits/services | Faible |
| `commercial_conditions` | Conditions commerciales (remises, échéances) | Faible |

### 3.2.2 Fonctions RPC à ajouter (~10 fonctions)

| Fonction | Description |
|----------|-------------|
| `rpc_distribute_analytical` | Ventilation analytique d'une écriture sur plusieurs axes |
| `rpc_budget_vs_actual` | Calcul écarts budget vs réalisé par centre de coût |
| `rpc_budget_forecast` | Prévision atterrissage fin d'année |
| `rpc_consolidate_entities` | Consolidation inter-sociétés avec élimination |
| `rpc_intercompany_reconcile` | Rapprochement transactions inter-sociétés |
| `rpc_generate_sales_invoice` | Génération facture de vente avec écritures comptables |
| `rpc_generate_purchase_invoice` | Enregistrement facture d'achat avec écritures |
| `rpc_payroll_by_agreement` | Calcul paie avec grilles conventionnelles |
| `rpc_analytical_reporting` | Reporting analytique multi-axes |
| `rpc_budget_alerts` | Détection de dépassements budgétaires |

### 3.2.3 Interfaces UI à ajouter (~8 écrans)

| Écran | Type | Description |
|-------|------|-------------|
| Plan analytique | SmartGrid | CRUD des axes et centres analytiques |
| Saisie analytique | Form (Type C) | Ventilation multi-axes lors de la saisie d'écriture |
| Budget construction | Form + SmartGrid | Saisie budgétaire par axe/période |
| Budget suivi | DataTable | Écarts budget/réalisé avec drill-down |
| Consolidation | RPCDialog + DataTable | Lancement consolidation + bilan/CR consolidé |
| Factures vente | SmartGrid + Form | Gestion du cycle de facturation client |
| Factures achat | SmartGrid + Form | Enregistrement et suivi factures fournisseur |
| Reporting analytique | DataTable + Chart | Analyses croisées multi-axes |

### 3.2.4 Éléments non fonctionnels
- Multi-tenant : ajout de la notion d'entité (entity_id) en plus de company_id
- RLS étendu : politiques par entité pour isolation multi-sociétés
- Rôles supplémentaires : CONTRÔLEUR_GESTION, DIRECTEUR_FINANCIER
- Performance : vues matérialisées pour rapports analytiques
- Import Excel pour budgets

---

## 3.3 SAPHIR — ETI (Estimation : 12-16 semaines sur base RUBIS)

### 3.3.1 Schéma de données — Tables à ajouter (~20 tables)

| Table | Description | Complexité |
|-------|-------------|-----------|
| `currencies_extended` | Gestion multi-devises avec historique de taux | Forte |
| `forex_transactions` | Transactions en devises étrangères | Forte |
| `unrealized_gains_losses` | Écarts de conversion non réalisés | Forte |
| `consolidation_scopes` | Périmètres de consolidation (IG, IP, ME) | Forte |
| `consolidation_adjustments` | Écritures de consolidation | Forte |
| `ifrs_mappings` | Correspondance comptes OHADA ↔ IFRS | Forte |
| `ifrs_adjustments` | Ajustements IFRS (leases, fair value, etc.) | Forte |
| `audit_missions` | Missions d'audit interne | Moyenne |
| `audit_findings` | Constats d'audit et recommandations | Moyenne |
| `audit_action_plans` | Plans d'action correctifs | Moyenne |
| `workflow_definitions` | Définitions de workflows paramétrables | Forte |
| `workflow_steps` | Étapes de workflow | Moyenne |
| `workflow_instances` | Instances de workflow en cours | Moyenne |
| `workflow_approvals` | Approbations et signatures | Moyenne |
| `bi_dashboards` | Tableaux de bord BI personnalisables | Moyenne |
| `bi_widgets` | Widgets KPI configurables | Moyenne |
| `bi_data_sources` | Sources de données pour BI | Moyenne |
| `transfer_pricing` | Prix de transfert intra-groupe | Forte |
| `country_regulations` | Réglementations par pays | Moyenne |
| `multi_gaap_reports` | États financiers multi-référentiels | Forte |

### 3.3.2 Fonctions RPC à ajouter (~15 fonctions)
- Conversion multi-devises avec écarts de change
- Consolidation multi-niveaux (sous-groupes)
- Mapping OHADA→IFRS automatique
- Génération états financiers IFRS
- Workflow engine (avancement, validation, notification)
- Audit trail avancé avec piste d'audit NF 203
- Reporting BI dynamique
- Transfer pricing documentation
- Clôture multi-entités coordonnée

### 3.3.3 Interfaces UI à ajouter (~12 écrans)
- Gestion des devises et taux de change
- Saisie multi-devises avec conversion automatique
- Périmètre et règles de consolidation
- Bilan/CR consolidé multi-référentiels (OHADA + IFRS)
- Module d'audit (missions, constats, plans d'action)
- Éditeur de workflows visuels (drag & drop)
- Dashboard BI configurable (widgets, graphiques, KPIs)
- Reporting multi-pays
- Transfer pricing documentation

### 3.3.4 Éléments non fonctionnels
- Internationalisation (i18n) : interface FR/EN minimum
- Multi-devises : toutes les tables monétaires doivent supporter `currency_code` + `exchange_rate`
- Performance : partitionnement des tables de volumes (écritures, lignes)
- API REST publique documentée (OpenAPI)
- SSO (SAML/OIDC) pour intégration SI groupe
- SLA 99.9%

---

## 3.4 ONYX — Grandes entreprises / Secteur public (Estimation : 16+ semaines sur base SAPHIR)

### 3.4.1 Schéma de données — Tables à ajouter (~25 tables)

| Domaine | Tables | Description |
|---------|--------|-------------|
| Multi-pays | `country_chart_of_accounts`, `country_tax_configs`, `country_social_configs` | Plans comptables et réglementations par pays |
| IFRS avancé | `ifrs16_leases`, `ifrs9_financial_instruments`, `ifrs15_contracts` | Normes IFRS spécifiques |
| Secteur public | `nomenclatures_m14`, `nomenclatures_m52`, `ordonnateur_comptable`, `mandats`, `titres_recette` | Comptabilité publique CEMAC |
| API | `api_keys`, `api_logs`, `webhooks`, `integrations` | Ouverture API |
| Modules spécifiques | `project_accounting`, `grant_management`, `cost_allocation_rules` | Comptabilité de projet, subventions |

### 3.4.2 Fonctions RPC spécifiques (~20 fonctions)
- Reporting BEPS (Base Erosion and Profit Shifting)
- Country-by-Country Reporting (CbCR)
- Consolidation multi-pays avec réconciliation devise
- Comptabilité de projet (imputation, avancement, marge à terminaison)
- Gestion des subventions et financements publics
- Séparation ordonnateur/comptable (secteur public)
- Émission de mandats et titres de recette
- Interface PES (Protocole d'Échange Standard) pour Hélios
- Paie agents publics (grilles indiciaires, primes)

### 3.4.3 Interfaces UI à ajouter (~15 écrans)
- Configuration multi-pays (plans comptables, taxes, social par pays)
- Dashboard groupe international avec carte géographique
- Consolidation multi-niveaux multi-devises
- Reporting réglementaire par pays
- Module secteur public : mandatement, titrage, PES
- Gestion des API keys et webhooks
- Portail salariés (bulletins, demandes d'absence, attestations)
- Mobile app (consultation KPIs, validation workflows)

### 3.4.4 Éléments non fonctionnels
- Multi-tenant avancé : isolation par pays + par entité
- Conformité RGPD complète (droit à l'oubli, portabilité, DPO)
- Archivage à valeur probante (NF Z42-013)
- SLA 99.95% avec RPO 15 min
- Monitoring 24/7
- Documentation API publique (Swagger/OpenAPI)
- SDK pour intégrations tierces
- Support multilingue complet (FR, EN, ES, PT pour zone OHADA élargie)

---

## 3.5 Roadmap consolidée toutes gammes

```
2026
 S1  S4  S8  S12  S16  S20  S24  S28  S32  S36  S40  S44  S48  S52
  │───│───│───│────│────│────│────│────│────│────│────│────│────│
  │   JASPE MVP    │  JASPE Complet │                              │
  │ ██████████████ │ ███████████████│                              │
  │   (S1→S8)      │  (S9→S16)      │                              │
  │                │                │     RUBIS                    │
  │                │                │ ████████████████             │
  │                │                │   (S17→S28)                  │
  │                │                │                │   SAPHIR    │
  │                │                │                │ ████████████│███
  │                │                │                │  (S29→S44)  │
  │                │                │                │             │ ONYX
  │                │                │                │             │ ████████
  │                │                │                │             │(S45→S60)
```

| Gamme | Début | Fin | Prérequis | Livrables clés |
|-------|-------|-----|-----------|----------------|
| **JASPE MVP** | Sem. 1 | Sem. 8 | — | DB déployée, Auth, SmartGrid connecté, 6 modules fonctionnels |
| **JASPE Complet** | Sem. 9 | Sem. 16 | JASPE MVP | Tests, E2E, Edge Functions, production, documentation |
| **RUBIS** | Sem. 17 | Sem. 28 | JASPE Complet | Analytique, budgets, multi-sociétés, facturation |
| **SAPHIR** | Sem. 29 | Sem. 44 | RUBIS | Multi-devises, consolidation IFRS, BI, workflows, audit |
| **ONYX** | Sem. 45 | Sem. 60 | SAPHIR | Multi-pays, secteur public, API, mobile, conformité avancée |

---

## 3.6 Métriques cumulées estimées

| Métrique | JASPE | +RUBIS | +SAPHIR | +ONYX |
|----------|-------|--------|---------|-------|
| Tables PostgreSQL | 42 | ~57 | ~77 | ~102 |
| Fonctions RPC | 13 | ~23 | ~38 | ~58 |
| Classes service JS | 8 | ~14 | ~22 | ~30 |
| Écrans UI | 18 | ~26 | ~38 | ~53 |
| Grilles SmartGrid | 11 | ~16 | ~22 | ~28 |
| Migrations SQL | 10 | ~14 | ~20 | ~26 |
| Lignes de code estimées | ~5K | ~15K | ~35K | ~60K |
| Tests unitaires | ~50 | ~120 | ~250 | ~400 |
| Tests E2E | ~4 | ~10 | ~20 | ~35 |

---

*Document généré le 9 février 2026 — Projet EdenFin · ERP OHADA/CEMAC*
