# EDEN BTP

Progiciel de gestion pour les entreprises du **BTP** (bâtiment et travaux publics)
en zone **OHADA / CEMAC**, construit sur le **socle EdenFin** (comptabilité
SYSCOHADA, trésorerie, paie, immobilisations, analytique) et selon la
**méthodologie ERP OHADA en 15 phases**.

## Principe d'intégration

EDEN BTP **réutilise le socle EdenFin existant** (vendorisé dans ce dépôt) et lui
**ajoute un noyau métier BTP** : chantiers, marchés/devis, situations de travaux,
sous-traitance, déboursés secs, cautions & retenue de garantie, coût de revient
par chantier (adossé à l'analytique RUBIS), approvisionnements.

Le socle n'est pas réécrit : il est repris tel quel (pipeline de base éprouvé et
vert en CI), puis spécialisé.

## Socle réutilisé (vendorisé)

| Couche | Contenu |
|---|---|
| **Base** | schémas `sys` / `common` / `client_demo`, RBAC/RLS, plan comptable SYSCOHADA, exercices/périodes, écritures + RPC comptables, tiers, trésorerie, immobilisations, paie, fiscal |
| **Gammes** | RUBIS (analytique, facturation, multi-sociétés), SAPHIR, ONYX — disponibles ; l'**analytique RUBIS** sert au coût de revient par chantier |
| **Pipeline** | `db/manifest.txt` + `scripts/db-build.sh` + shim Supabase + harness pgTAP + CI (5 garde-fous) |
| **Frontend** | TanStack Start + React 19 + `ModuleShell` / `SmartGrid` / `DataTable` / `RPCPanel` / `EntityFormDrawer` / KPI + auth + formatters XAF |
| **Méthodologie** | les 15 docs de phase (`01..15-*.md`) + templates SQL/RPC/grille/formulaire + `NOYAU-NORMATIF-EDENFIN.md` |

## Construire la base (local / CI)

```bash
# PostgreSQL « nu » (dev/CI) — le shim fournit auth.*/rôles/extensions
DATABASE_URL="postgres://user:pass@host:5432/edenbtp" \
  EDENFIN_DB_SHIM=1 bash scripts/db-build.sh

# Base de test autonome (sans seeds) pour pgTAP
DATABASE_URL="postgres://user:pass@host:5432/edenbtp_test" \
  EDENFIN_DB_SHIM=1 EDENFIN_SKIP="03b-client-seed,06-seed-data" \
  bash scripts/db-build.sh
pg_prove tests/rpc/*_test.sql tests/rpc/*/*_test.sql
```

## Feuille de route

- **Sprint 0 — Bootstrap (ce commit)** : socle EdenFin vendorisé, base verte,
  19 tests pgTAP au vert, CI reprise.
- **Sprint 1 — Noyau métier BTP (Phases 1–4)** : cahier des charges BTP, specs
  fonctionnelles, MCD/MCT, MLD (schéma `btp`). Élagage optionnel des gammes
  non-BTP (SAPHIR/ONYX).
- **Sprint 2 — Base physique + RPC BTP (Phases 8–9)** : schéma `btp` + RPC métier
  (situations de travaux, coût de revient par chantier).
- **Sprint 3 — Interfaces BTP (Phases 7/10)** : pages console sur `ModuleShell` /
  `SmartGrid`.
- **Sprint 4 — Tests (Phase 13)** : pgTAP des RPC BTP.

Voir `SPRINT0_BTP_BOOTSTRAP.md` pour le détail du bootstrap.
