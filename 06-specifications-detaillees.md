# Phase 6 — Spécifications Fonctionnelles Détaillées (SFD)

## Objectif
Spécifier écran par écran chaque interface, avec validation champ par champ, workflows d'état, et maquettes.

## Structure de spécification par écran

### Fiche écran standard

```
SFD-[MODULE]-[NNN] : [Titre de l'écran]

Type : SmartGrid | DataTable | Form-Entity | Form-RPC | Form-MultiLine
Module : [COMPTA|PAIE|IMMO|TRESO|TIERS|FISC]
Accès : [Rôles autorisés]
URL : /app/[module]/[sous-module]

Description :
  [But de l'écran en 2-3 phrases]

Données affichées :
  Table source : [nom_table]
  Colonnes : [voir GRID_REGISTRY]
  Filtres par défaut : [ex: is_active = true]
  Tri par défaut : [ex: account_number ASC]

Actions disponibles :
  - Nouveau (ouvre EntityFormDrawer)
  - Modifier (double-clic ou menu contextuel)
  - Supprimer (confirmation requise)
  - Exporter CSV
  - [Actions métier spécifiques]

Validations champ par champ :
  [champ] : [type] | [obligatoire?] | [format] | [règle]
```

### Exemple : Plan comptable

```
SFD-COMPTA-001 : Plan Comptable

Type : SmartGrid
Table : accounts
Colonnes :
  account_number : varchar(10) | requis | regex ^[1-9]\d{2,5}$ | unique
  account_label  : varchar(255) | requis | min 3 chars
  account_type   : enum | requis | ASSET|LIABILITY|EQUITY|REVENUE|EXPENSE
  level          : int | requis | 1-5
  is_active      : boolean | défaut true

Règles spécifiques :
  - Un compte de niveau N doit avoir un parent de niveau N-1
  - Les comptes de classe 1-5 sont au bilan, 6-7 au compte de résultat
  - Classe 8-9 réservées aux engagements hors bilan et analytique
  - La suppression est interdite si le compte a des écritures
```

## Workflows d'état

### Écriture comptable
```
DRAFT → POSTED → (contre-passée)
  │
  └→ CANCELLED (si jamais validée)

Transitions :
  DRAFT → POSTED : rpc_validate_journal_entry (vérifie équilibre, période ouverte)
  POSTED → contre-passée : rpc_reverse_journal_entry (crée écriture inverse)
  DRAFT → CANCELLED : suppression logique
```

### Bulletin de paie
```
OPEN → VARIABLES_CLOSED → CALCULATED → VALIDATED → PAID → CLOSED

Transitions :
  OPEN → VARIABLES_CLOSED : deadline J-20 du mois
  VARIABLES_CLOSED → CALCULATED : rpc_calculate_payroll
  CALCULATED → VALIDATED : vérification manuelle + approbation
  VALIDATED → PAID : confirmation virement
  PAID → CLOSED : clôture de la période de paie
```

### Période fiscale
```
OPEN → CLOSING → CLOSED → LOCKED

Transitions :
  OPEN → CLOSING : rpc_close_fiscal_period (vérifie 0 brouillons)
  CLOSING → CLOSED : génération des à-nouveaux
  CLOSED → LOCKED : verrouillage définitif (irréversible)
```

## Convention de nommage des écrans
- `SFD-COMPTA-001` à `SFD-COMPTA-099` : Comptabilité
- `SFD-PAIE-001` à `SFD-PAIE-099` : Paie
- `SFD-IMMO-001` à `SFD-IMMO-099` : Immobilisations
- `SFD-TRESO-001` à `SFD-TRESO-099` : Trésorerie
- `SFD-TIERS-001` à `SFD-TIERS-099` : Tiers
- `SFD-FISC-001` à `SFD-FISC-099` : Fiscal
