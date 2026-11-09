# Plan — EdenFin Suite, gamme JASPE

L'archive `EdenFin-JASPE-Archive-Complete/` contient déjà tout l'ouvrage : 9 migrations SQL (≈4 400 lignes), 13 fonctions RPC métier, 8 classes de service JS (751 lignes) et un prototype React monolithique `EdenFin-JASPE-Complete.jsx` (1 025 lignes). On porte cet existant dans le template TanStack Start, sous identité visuelle **Emerald Prestige** (vert émeraude + or).

Le travail est trop volumineux pour un seul tour. On le découpe en 5 lots livrés successivement, chacun vérifié avant le suivant.

---

## Lot 1 — Fondations (ce tour)

1. **Design system Emerald Prestige** dans `src/styles.css`
   - Tokens OKLCH : émeraude foncé `#064e3b`, émeraude `#0d7a5f`, or `#c9a84c`, crème `#f5f0e0`
   - Paire typo Libre Baskerville (titres) + IBM Plex Sans (texte), chargées via `<link>` dans `__root.tsx`
   - Variantes Shadcn personnalisées : `button` (prestige/gold/outline-emerald), `card` (premium)
2. **Activer Lovable Cloud** (Supabase) — nécessaire pour les 13 RPC et l'auth multi-tenant
3. **Landing EdenFin** (`/`) : hero suite financière + 4 cartes de gammes (JASPE active, RUBIS/SAPHIR/ONYX "bientôt")
4. **Page gamme JASPE** (`/jaspe`) : présentation + bouton « Accéder à la console »
5. **Coquille console** (`/_authenticated/console`) : layout avec sidebar (Comptabilité, Trésorerie, Paie, Fiscal, Immo, Analyse) + page d'accueil KPI vide

À ce stade : navigation complète, design figé, backend prêt, mais modules métier vides.

## Lot 2 — Backend SQL

- Adapter les 9 migrations de l'archive au schéma Supabase de Lovable Cloud (passer de `client_demo` à `public`, ajouter les GRANTs requis, conserver RLS multi-tenant)
- Charger le plan comptable OHADA et les paramètres (taux CNSS, catégories d'amortissement)
- Porter les 13 fonctions RPC `rpc_*`
- Vérifier via `psql` que les RPC répondent

## Lot 3 — Module Comptabilité (pilote end-to-end)

- Service `comptabiliteService` (côté `lib/`) appelant les RPC via le client Supabase authentifié
- Routes : `/console/comptabilite/ecritures`, `/lettrage`, `/balance`, `/cloture`
- Composant SmartGrid réutilisable (table + filtres + actions) basé sur `tanstack-table`
- Formulaire de saisie d'écriture avec contrôle débit=crédit côté client

Ce lot sert de **patron** pour les modules suivants.

## Lot 4 — Trésorerie + Paie

- Rapprochement bancaire (`rpc_auto_reconcile_bank`) + prévisionnel (`rpc_cash_forecast`)
- Calcul de paie OHADA (`rpc_calculate_payroll`) + simulateur de bulletin

## Lot 5 — Fiscal + Immo + Analyse

- Déclaration TVA, amortissements, cession d'immobilisation
- Tableau de bord KPI avec graphiques (recharts) + ratios financiers + score de santé

---

## Notes techniques

- **Routage** : un fichier par section sous `src/routes/` (pas d'ancres). Layout protégé `_authenticated/console/route.tsx` pour la console.
- **Auth** : Supabase Auth email/password ; tables métier scopées par `tenant_id` via RLS (déjà prévu dans `05_rls_policies.sql`).
- **Appels RPC** : depuis `createServerFn` avec `requireSupabaseAuth` pour respecter la RLS de l'utilisateur connecté.
- **Multi-tenant** : un seul tenant de démo créé au seed pour ce lot ; la gestion multi-organisation viendra avec RUBIS.
- **Archive** : `EdenFin-JASPE-Archive-Complete/` est conservée comme référence ; rien n'y est modifié.

Je commence par le Lot 1 dès validation. Confirme (ou ajuste le découpage).
