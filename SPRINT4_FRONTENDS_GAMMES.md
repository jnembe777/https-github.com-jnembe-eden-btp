# Sprint 4 — Frontends des gammes RUBIS · SAPHIR · ONYX

Après l'intégration backend des 4 gammes (Sprints 0→3), ce sprint amorce les
**interfaces** des gammes supérieures dans la console EdenFin, sur les mêmes
composants que JASPE (ModuleShell / SmartGrid / KpiCard), avec une navigation
groupée par gamme.

## Livré

| Gamme | Page | Route | Contenu |
|---|---|---|---|
| **RUBIS** | Comptabilité analytique | `/console/rubis-analytique` | KPIs, axes analytiques, modèles de ventilation (invariant 100 %, statut valide/incomplet) |
| **SAPHIR** | Gestion multi-devises | `/console/saphir-devises` | KPIs, convertisseur interactif (`rpc_convert_amount`), table des taux de change |
| **ONYX** | Configuration multi-pays | `/console/onyx-pays` | KPIs, référentiel pays CEMAC/OHADA + international (zones, GAAP, TVA, IS) |

- **Navigation groupée par gamme** : `console-sidebar.tsx` restructuré en
  sections JASPE · TPE / RUBIS · PME / SAPHIR · ETI / ONYX · GE, avec pastille
  de couleur par gamme.
- **Schéma `onyx`** ajouté à `SCHEMAS` (`src/lib/supabase.ts`) pour les futurs
  appels `useSupabaseQuery(..., { schema: "ONYX" })`.

## Données

Les pages s'appuient pour l'instant sur des **mock data réalistes**
(`src/lib/mock-gammes.ts`), cohérentes avec le backend intégré (parité EUR/XAF
655,957 ; données CEMAC/OHADA ; ventilation analytique). Elles sont structurées
pour basculer sur les hooks `useSupabaseQuery` / `useSupabaseRPC` (cf.
`plan-comptable.tsx`) une fois le backend déployé sur Supabase, sans changement
de structure — chaque grille indique déjà sa source (`sys.exchange_rates`,
`sys.countries`, etc.).

## Vérifications

- ✅ Routes générées (`routeTree.gen.ts`) incluent les 3 pages.
- ✅ `tsc --noEmit` : **0 erreur dans les nouveaux fichiers** (les erreurs
  pré-existantes du dépôt — import manquant `@/hooks/use-toast`, décalages d'API
  TanStack Start — sont antérieures et hors périmètre).
- ✅ Rendu vérifié via le serveur de dev (captures jointes) : les 3 pages
  s'affichent dans la console avec la navigation par gamme.

## Reste à faire (frontends — sprints suivants)

- Brancher les pages sur Supabase réel (remplacer les mocks par `useSupabase*`).
- Compléter chaque gamme : RUBIS (budgets, multi-sociétés, facturation) ;
  SAPHIR (consolidation IFRS, workflow, BI) ; ONYX (secteur public, trésorerie
  multi-pays, reporting réglementaire).
- Gating par abonnement : n'afficher les modules d'une gamme que selon le tier
  souscrit (le modèle de pricing/abonnement existe déjà).
- Formulaires de création/édition (EntityFormDrawer) et exécution des RPC
  (RPCPanel) pour les entités de chaque gamme.
