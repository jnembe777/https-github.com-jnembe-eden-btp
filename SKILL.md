---
name: erp-ohada-methodology
description: >
  Complete methodology for building OHADA/CEMAC-compliant ERP systems (accounting, payroll, 
  fixed assets, treasury). Use this skill when the user wants to design, specify, build, or 
  test any module of a multi-module ERP application targeting African OHADA zone enterprises.
  Triggers: requests to create an ERP, build accounting/payroll/HR/asset management software, 
  implement OHADA plan comptable, design a business management application for CEMAC/UEMOA 
  context, or follow a structured software engineering methodology for enterprise applications. 
  Also use when the user mentions EdenFin, JASPE, RUBIS, SAPHIR, ONYX gammes, SmartGrid, or 
  any reference to the 15-phase ERP development workflow. Covers: requirements → functional 
  specs → conceptual models (MCD/MCT) → logical/physical models (MLD/MPD/MOT) → business 
  classes → detailed specs → 3-tier UI (DataTable/SmartGrid/Forms) → database generation → 
  RPC functions → UI-DB integration → auth → backend → unit tests → process tests.
---

# ERP OHADA Methodology

Structured 15-phase methodology for building production-grade ERP systems compliant with OHADA accounting standards, CEMAC/UEMOA regulations, and African enterprise requirements.

## Architecture Principles

- **Multi-gamme**: JASPE (TPE), RUBIS (PME), SAPHIR (ETI), ONYX (GE) — progressive module addition
- **Backend**: Supabase (PostgreSQL + RLS + RPC + Auth + Realtime)
- **Frontend**: React + SmartGrid (data management) + Forms (treatments) + DataTable (consultation)
- **Two-layer data access**: SmartGrid CRUD for master data, RPC PostgreSQL for complex business treatments

## The 15 Phases

Execute sequentially. Each phase produces deliverables consumed by the next.

| # | Phase | Input | Output | Reference |
|---|-------|-------|--------|-----------|
| 1 | Cahier des charges | Client needs | CDC document | `references/01-cahier-charges.md` |
| 2 | Spécifications fonctionnelles générales | CDC | Modules, use cases, rules | `references/02-specifications-fonctionnelles.md` |
| 3 | MCD & MCT | SFG | Entity diagrams, treatment flows | `references/03-mcd-mct.md` |
| 4 | MLD, MPD, MOT | MCD/MCT | SQL schema, operational model | `references/04-mld-mpd-mot.md` |
| 5 | Classes métier | MLD/MPD | JS/TS service classes | `references/05-classes-metier.md` |
| 6 | Spécifications détaillées | SFG+MCD+MLD | Screen specs, field validation | `references/06-specifications-detaillees.md` |
| 7 | Interfaces UI (3 types) | SFD+Registries | React components | `references/07-interfaces-ui.md` |
| 8 | Base de données physique | MPD | SQL migrations, seed data | `references/08-base-donnees.md` |
| 9 | Connexion DB↔Traitements | MCT+MPD | RPC functions, traceability | `references/09-connexion-traitements.md` |
| 10 | Connexion DB↔Interfaces | Registry+RPC | DataAdapter, services | `references/10-connexion-interfaces.md` |
| 11 | Authentification | Actor roles | Auth, RLS, RBAC | `references/11-authentification.md` |
| 12 | Backend finalization | All outputs | Edge functions, cron, hardening | `references/12-backend.md` |
| 13 | Tests unitaires | RPC, services | pgTAP, Jest suites | `references/13-tests-unitaires.md` |
| 14 | Tests processus | MCT, SFD | E2E tests, validation | `references/14-tests-processus.md` |
| 15 | Déploiement | All validated | Production, docs, training | `references/15-deploiement.md` |

## Decision Rules

- **Gamme**: JASPE (<10 employees, <500M XAF CA), RUBIS (10-50, <2B), SAPHIR (50-250, <10B), ONYX (250+)
- **SmartGrid vs RPC**: Single-table CRUD → SmartGrid. Multi-table transaction/batch → RPC.
- **UI type**: Read-only → DataTable. Master data edit → SmartGrid. Treatment/wizard → Form/RPCDialog.

## Key Assets

- `assets/sql-migration-template.sql` — Numbered migration boilerplate
- `assets/grid-registry-template.js` — SmartGrid column config pattern
- `assets/rpc-function-template.sql` — RPC function boilerplate with audit trail
- `assets/entity-form-template.jsx` — Auto-generated form from grid config

## OHADA Regulatory Context

- Plan comptable SYSCOHADA révisé: 9 classes, ~1200 comptes
- Social contributions CEMAC: CNSS, CRF, CNAMGS with bracket ceilings
- Depreciation: linear (default), declining (coefficients 1.25/1.75/2.25), none (land)
- Currencies: XAF (CEMAC), XOF (UEMOA) — fixed parity 1 EUR = 655.957
- Fiscal year: 12 months, mandatory statements (Bilan, Compte de résultat, TAFIRE, annexes)
