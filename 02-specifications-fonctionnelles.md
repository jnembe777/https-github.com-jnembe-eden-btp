# Phase 2 — Spécifications Fonctionnelles Générales (SFG)

## Objectif
Décomposer le CDC en modules fonctionnels, cas d'usage, règles métier et flux de données.

## Structure des SFG

### 1. Décomposition modulaire
Pour chaque module, documenter :
- **Code** : identifiant unique (ex: COMPTA, PAIE, IMMO, TRESO, TIERS, FISC)
- **Description** : périmètre fonctionnel en 2-3 phrases
- **Sous-modules** : décomposition de niveau 2
- **Dépendances** : modules prérequis

Exemple JASPE :
```
COMPTA (Comptabilité Générale)
├── COMPTA.PLAN   → Plan comptable OHADA
├── COMPTA.JOURN  → Gestion des journaux
├── COMPTA.ECRIT  → Saisie des écritures
├── COMPTA.LETTR  → Lettrage des comptes
├── COMPTA.CLOT   → Clôture périodique/annuelle
└── COMPTA.ETAT   → États financiers (Bilan, CR, TAFIRE)
```

### 2. Acteurs et rôles
Matrice RACI par module :

| Rôle | Description | Modules |
|------|-------------|---------|
| ADMIN | Administrateur système | Tous |
| COMPTABLE | Saisie et validation écritures | COMPTA, FISC |
| RH_PAIE | Gestion paie et personnel | PAIE |
| TRESORIER | Rapprochements bancaires | TRESO |
| DIRECTEUR | Consultation et validation | Tous (lecture) |

### 3. Cas d'usage
Format standardisé pour chaque cas d'usage :

```
CU-[MODULE]-[NNN] : [Titre]
Acteur principal : [Rôle]
Préconditions : [État initial requis]
Scénario nominal :
  1. L'utilisateur ...
  2. Le système ...
  3. ...
Scénarios alternatifs :
  3a. Si [condition] → [action]
Postconditions : [État final garanti]
Règles métier : RG-[NNN], RG-[NNN]
```

### 4. Règles métier
Codifier chaque règle avec un identifiant unique :

```
RG-COMPTA-001 : Toute écriture comptable doit être équilibrée (∑ débits = ∑ crédits)
RG-COMPTA-002 : Une écriture validée (POSTED) ne peut plus être modifiée, seulement contre-passée
RG-PAIE-001  : Le salaire brut = salaire de base + ∑ gains (primes, heures sup) - ∑ absences non payées
RG-PAIE-002  : Les cotisations salariales se calculent sur la base plafonnée (tranche A ≤ 1.500.000 XAF)
RG-IMMO-001  : L'amortissement linéaire mensuel = valeur d'acquisition / durée en mois
RG-IMMO-002  : Un terrain (catégorie TERRAIN) ne s'amortit jamais
```

### 5. Flux de données
Diagrammes de contexte montrant les échanges entre modules :

```
[Paie] →(OD de paie)→ [Comptabilité]
[Immobilisations] →(dotations)→ [Comptabilité]
[Trésorerie] →(rapprochement)→ [Comptabilité]
[Comptabilité] →(données fiscales)→ [Fiscal]
```

## Livrables
- Document SFG (50-100 pages selon gamme)
- Liste des cas d'usage numérotés
- Catalogue des règles métier
- Matrice de traçabilité CDC→SFG
