# STANDARD UI — Patron de conception à 3 niveaux (T/P/D) et pipeline MERISE → UI
**Version : 1.1 — Juillet 2026**
**Portée : tous les projets du programme** (Portail citoyen/RNP-RNO, SIGFIP Gabon, SIGFIP++, EdenFin, suite GRH, suite BTP)
**Kit de référence : `rnp-rno-ui-kit/` (skills `smartgrid-ui`, `merise-to-ui`, `app-shell` + `AGENT_WORKFLOW.md`)**

> Ce document est le second pilier normatif du programme, aux côtés de `NOYAU-NORMATIF.md` (règles métier finances publiques). Il définit COMMENT les interfaces des applications de gestion sont produites. Tout agent générant de l'UI applicative DOIT appliquer ce standard.

---

## 1. Patron de conception fondateur — l'architecture à 3 niveaux

Toute application du programme est conçue selon trois niveaux, qui structurent à la fois le modèle de données, les services et les interfaces. C'est le patron de conception officiel : chaque module, chaque écran, chaque service se rattache explicitement à un niveau.

| Niveau | Finalité | Objets techniques | Vocabulaire UI de référence |
|---|---|---|---|
| **T — Transactionnel** | Opérations courantes : saisie, consultation, actions unitaires et de masse | Tables normalisées, RPC, contraintes d'intégrité, journalisation | **Grilles intelligentes** (5 types) + menus contextuels + formulaires RPC |
| **P — Processus** | Automatisation des tâches, circuits multi-acteurs, approche qualité | Moteur BPM/workflows, états et transitions, règles BRMS, files de tâches, SLA | **Cartes de processus et graphiques spécialisés** : kanban d'étapes, diagrammes BPMN, timelines/frises d'instance, swimlanes, corbeilles de tâches, cartes de dossier |
| **D — Décisionnel** | Reporting, tableaux de bord, requêtes intelligentes, optimisation, IA | Vues matérialisées, DWH/datalake, requêtes pré-paramétrées, modèles IA | **Indicateurs et graphiques** : KPI, jauges, courbes/barres/aires, heatmaps, AnalyticsGrid (pivot), assistants IA en langage naturel |

**Principe d'affectation** : le choix de l'interface découle du niveau, jamais l'inverse. Une donnée se *manipule* en grille (T), un flux se *suit* en carte/diagramme (P), une performance se *lit* en indicateur/graphique (D).

**Règles d'exclusion croisées** :
1. Les cartes sont **interdites au niveau T** : un module métier s'ouvre sur une grille, pas sur des tuiles. Les cartes de navigation (`CarteApp.jsx`) restent réservées aux écrans d'accueil et portails.
2. Les grilles ne sont pas l'interface de pilotage : au niveau D, la grille n'apparaît que sous sa forme AnalyticsGrid (pivot/groupement) ou en drill-down depuis un indicateur.
3. Au niveau P, la carte représente une **instance de processus** (un dossier, une tâche, une étape) — jamais une donnée brute. Le clic sur une carte P mène soit à la grille T (les données), soit au détail d'instance (l'historique du circuit).

**Navigation inter-niveaux canonique** : D → T (drill-down d'un indicateur vers les lignes qui le composent), P → T (d'une tâche vers les données à traiter), T → P (d'une ligne vers l'état de son circuit — colonne type `workflow-status`), T/P → D (agrégation). Chaque écran généré déclare son niveau (`level: "T" | "P" | "D"`) et ses cibles de navigation.

Les trois modes de fonctionnement (transactionnel, décisionnel, processus) évoqués dans les visions produit correspondent exactement à ces trois niveaux.

## 2. La chaîne de production — pipeline MERISE → UI

Toute interface applicative est **générée**, pas dessinée à la main, à partir des quatre artefacts de base du module :

```
INPUT_MCD.md       (obligatoire)  entités, attributs, cardinalités
INPUT_MCT.md       (obligatoire)  opérations OP-XX-NN, synchronisations, résultats
INPUT_SQL.sql      (obligatoire)  DDL : CHECK, NOT NULL, UNIQUE, FK, GENERATED
INPUT_CLASSES.*    (recommandé)   classes service (méthodes → actions, exceptions → messages)
                          │
                          ▼   Pipeline agent 6 phases (AGENT_WORKFLOW.md)
   Phase 0  Inventaire des artefacts (bloquant si MCD ou MCT absent)
   Phase 1  Analyse : MCD→colonnes · MCT→traitements · SQL→types/contraintes · Classes→actions
   Phase 2  Génération des ColumnDef[]
   Phase 3  Génération des menus (GridCtxMenu, RowCtxMenu, TOP_MENU)
   Phase 4  Assemblage du composant React
   Phase 5  Validation par checklists (MCD→UI, MCT→Menus, Sécurité, Ergonomie)
                          │
                          ▼
OUTPUT_GRID.jsx    Composant React autonome (200-400 lignes)
```

Ce pipeline correspond, dans les méthodologies 15 phases (ERP OHADA et SIGFIP), à l'industrialisation de la **Phase 7 (Interfaces UI)** : les phases 3-5 (MCD/MCT, MLD/MPD, classes métier) produisent les INPUT_*, la phase 7 exécute ce pipeline. Cohérence garantie par construction : l'UI ne peut pas diverger du modèle de données puisqu'elle en dérive.

**Extension du pipeline aux trois niveaux.** Les mêmes artefacts alimentent les trois familles d'écrans :

| Artefact | Niveau T | Niveau P | Niveau D |
|---|---|---|---|
| MCD/MPD | Colonnes, types de cellules | Entités porteuses d'état (attributs statut/étape) → cartes d'instance | Dimensions et mesures candidates |
| MCT | Actions de ligne, traitements de masse | **Source primaire** : opérations OP-XX-NN + synchronisations → kanban, BPMN, timeline, files de tâches | Événements comptables pour les indicateurs de flux (délais, volumes, taux de rejet) |
| SQL DDL | Contraintes, énumérations, colorMap | États `CHECK IN (...)` → colonnes kanban et statuts BPMN | Vues matérialisées, agrégats |
| Classes métier | Actions et messages d'erreur | Transitions autorisées, exceptions → règles qualité | Méthodes de calcul → définitions de KPI |

Les écrans **T** sortent en `OUTPUT_GRID.jsx` (pipeline actuel, inchangé). Les écrans **P** sortent en `OUTPUT_PROCESS.jsx` (kanban/timeline/corbeille dérivés du MCT). Les écrans **D** sortent en `OUTPUT_DASHBOARD.jsx` (KPI + graphiques adossés aux requêtes pré-paramétrées). Les gabarits P et D sont à ajouter au kit (`templates/ProcessBoard.jsx`, `templates/KpiDashboard.jsx`) — tâche P0 du dépôt du kit ; d'ici là, seul le niveau T est généré automatiquement et les écrans P/D font l'objet de PR `human-review-required`.

**Conséquence pour l'autonomie** : un agent ne "conçoit" jamais un écran de gestion librement. Il exécute le pipeline, au niveau déclaré de l'écran. Toute exigence UI non dérivable des artefacts est une lacune des artefacts → issue `spec-gap` sur le MCD/MCT, pas une improvisation UI.

## 3. La grille intelligente — 5 types

| Type | Cas d'usage | Sélection |
|---|---|---|
| **EditableGrid** | Entité plate, édition fréquente, volume faible | Référentiels vivants |
| **ConsultationGrid** | Entité plate, volume > 50-100k, lecture | Journaux, historiques, liaisons N-N |
| **MasterDetailGrid** | Entité avec enfants 1-N | Dossier → pièces, engagement → lignes |
| **TreeGrid** | Hiérarchie récursive | Nomenclatures budgétaires, organigrammes |
| **AnalyticsGrid** | Agrégats, groupement, pivot | Mode décisionnel |

Architecture : SmartGrid **headless maison** (React 18 + hooks, CSS-in-JS inline, zéro dépendance UI tierce). 18 types de cellules (`references/column-types.md`), dont les types de souveraineté : `currency` XAF, `encrypted` (BYTEA masqué 🔒), `computed` (GENERATED non éditable), `iup`/`iuo` épinglés à gauche.

## 4. Règles d'ergonomie non négociables (R1-R10)

| # | Règle |
|---|---|
| R1 | Clic droit sans sélection → menu grille (global) |
| R2 | Clic droit avec sélection → menu ligne (contextuel) |
| R3 | Bouton `···` → toujours menu ligne (force la sélection) |
| R4 | Clic droit zone vide → menu grille |
| R5 | Menu grille : Affichage · Filtres · Exporter · ⚡ Traitements · Grille |
| R6 | Menu ligne : Fiche · Actions · Filtrer par valeur |
| R7 | Sections sidebar non livrées = inactives (🚧 À venir), jamais masquées |
| R8 | Plein écran : F11 / bouton ↗ / menu grille → les 3 zones périphériques disparaissent |
| R9 | Menu flottant haut adapté à la grille ouverte (breadcrumb + 4 items contextuels) |
| R10 | Sidebar gauche blanche + filigrane identitaire (CSS pur, opacité 3-5%) |

## 5. Shell applicatif 4 zones

```
┌─────────────────────────────────────────────────────┐
│  Zone 3 — MENU FLOTTANT (44px · désactivable)       │
├──────────────┬──────────────────────────────────────┤
│  Zone 2      │   Zone 4 — CENTRALE                  │
│  SIDEBAR     │   Wallpaper si vide                   │
│  228/52px    │   SmartGrid si grille ouverte         │
├──────────────┴──────────────────────────────────────┤
│  Zone 1 — PIED SYSTÈME (28px · permanent)            │
│  Identité · Session · Durée · IP · MAC · ESB · ⏰    │
└──────────────────────────────────────────────────────┘
```

Le pied de page système (Zone 1) est permanent : il porte la traçabilité de session exigée par les invariants d'audit (NOYAU-NORMATIF §6). L'identité visuelle (couleurs, filigrane, wallpaper) est un **paramètre de thème par projet/pays** (`DESIGN_TOKENS.json`) : Gabon = vert `#009E60` / jaune `#FCD116` / bleu `#003189`. Jamais de couleur en dur dans les composants.

## 6. Traitements métiers — approche transactionnelle

Chaque opération du MCT devient un traitement à **cycle de vie complet** :

```
Classification (Phase 1B) :
  déclencheur utilisateur direct → item menu ligne (+ condition visible())
  batch / masse                  → traitement menu grille (scope: selection|filtered|all)
  événement ESB entrant          → abonnement WebSocket (pas d'action utilisateur)

Cycle de vie : CONFIRMATION (comptage des lignes affectées TOUJOURS affiché)
             → PROGRESSION (si longue durée)
             → RÉSULTAT (toast | report ligne-par-ligne | highlight)
             → APPLICATION (mise à jour grille + événement ESB émis le cas échéant)

Sécurité : irréversible/WORM → dangerous:true + confirmation bouton rouge
           export distingue "filtré (N)" de "tout (M)"
           BYTEA jamais affiché en clair
```

Nommage : traitement `op-{module}-{nn}-{slug}` · événement ESB `{module}.{entité}.{action}`.

## 7. Déclinaison par projet

| Projet | Application du standard |
|---|---|
| **Portail citoyen / RNP-RNO (ANGTI)** | Application native du kit — 23 applications du catalogue, thème Gabon. Référence du programme pour le niveau T ; premiers gabarits P et D à valider ici. |
| **SIGFIP Gabon** | Niveau T : pipeline MERISE→SmartGrid pour les `XxxPage` (détail opérationnel). Niveau D : les `XxxMainPage` (synthèses) sont requalifiées écrans D — KPI + graphiques, plus de tuiles de données. Niveau P : signatures, workflow de suspens, chaîne des Règlements. Thème Gabon. |
| **SIGFIP++** | Correspondance directe : types A/B = niveau T (générés) ; type C = formulaires du niveau T ; type D (Workflow Camunda) = niveau P — corbeilles de tâches, BPMN, timeline d'instance ; TBPM tout entier = niveau D (requêtes pré-paramétrées, KPI ministériels, prospective IA). Type E (Import) = traitement de masse T à cycle de vie P. Thème = paramètre pays. |
| **EdenFin** | Couche 1 (modules) = T (agent E.3, GRID_REGISTRY) ; couche 2 (~190 requêtes décisionnelles, agent E.6) = D ; couche 3 (assistants IA, agent E.7) = D avancé (requêtes intelligentes en langage naturel) ; validations et clôtures = P. L'architecture EdenFin en 3 couches et le patron T/P/D coïncident — c'est la preuve de généralité du patron. |
| **Suites GRH et BTP** | Standard applicable dès la création des dépôts : produire MCD/MCT/SQL/Classes d'abord, déclarer le niveau de chaque écran, générer ensuite. GRH : paie=T, circuits de validation congés/évaluations=P, pilotage RH=D. BTP : chantiers/métrés=T, phasage travaux et jalons qualité=P, suivi budgétaire chantier=D. |

**Règle d'adoption** : pour les dépôts existants, aucune réécriture massive — le standard s'applique à tout **nouvel** écran opérationnel et à toute refonte d'écran, jamais en big-bang.

## 8. Intégration au workflow des agents

1. Avant toute tâche UI, l'agent lit : `AGENT_WORKFLOW.md`, le skill `smartgrid-ui`, `references/column-types.md`, les templates de menus, `DESIGN_TOKENS.json` du projet.
2. La **checklist Phase 5** (MCD→UI, MCT→Menus, Sécurité UI, Ergonomie R1-R10) est intégrée à la Définition de Terminé des PR UI.
3. La matrice de traçabilité s'étend : SF → UC → Règle → Table → RPC → **OUTPUT_GRID** (l'écran généré référence ses INPUT_*).
4. Artefacts d'entrée modifiés (MCD/MCT/SQL) → l'écran est **régénéré**, pas patché à la main. Les personnalisations durables se font dans les templates et tokens du kit, pas dans les sorties.

## 9. Gouvernance du standard

- Le kit `rnp-rno-ui-kit/` est versionné dans un dépôt dédié, consommé par les autres dépôts (submodule ou package).
- Les agents ne modifient pas le kit depuis un dépôt applicatif : amélioration du kit = PR sur le dépôt du kit, label `human-review-required`.
- Contradiction entre ce standard et une spec projet → issue `normative-conflict`, tâche suspendue (même mécanisme que le noyau normatif).

## Historique

| Version | Date | Modification |
|---|---|---|
| 1.0 | 2026-07-04 | Création à partir du kit RNP/RNO Gabon (ANGTI) ; élévation au rang de standard transversal du programme. |
| 1.1 | 2026-07-04 | Intégration du patron de conception à 3 niveaux T/P/D : vocabulaire UI par niveau (T=grilles, P=cartes de processus et graphiques spécialisés, D=indicateurs et graphiques), règles d'exclusion croisées, navigation inter-niveaux, extension du pipeline MERISE aux sorties P et D, déclinaisons par projet. |
