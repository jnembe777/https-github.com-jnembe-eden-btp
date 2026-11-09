# Phase 7 — Interfaces Utilisateur (3 Types)

## Architecture UI à 3 niveaux

### Niveau 1 : DataTable (consultation seule)
**Usage** : Afficher les résultats de traitements RPC, historiques, rapports
**Caractéristiques** : Lecture seule, pas d'édition inline, export CSV/PDF, pagination serveur
**Exemples** : Grand livre, balance, historique des bulletins, journal des écritures validées

### Niveau 2 : SmartGrid (données de gestion)
**Usage** : CRUD sur les entités de données maîtres
**Caractéristiques** : Tri, filtre, groupement, recherche, sélection multiple, menu contextuel, pagination, ligne de totaux, formulaire d'insertion/édition via drawer
**Exemples** : Plan comptable, employés, tiers, rubriques de paie, barèmes, catégories d'immobilisations

### Niveau 3 : Formulaires (traitements)
3 sous-types :

**Type A — EntityFormDrawer** : Formulaire auto-généré depuis GRID_REGISTRY pour insertion/édition
```
Déclencheur : bouton "Nouveau" ou double-clic dans SmartGrid
Génération : parcourt config.columns.filter(c => c.editable)
Champs : text, number, currency, percent, date, boolean (checkbox), badge (select)
Validation : champs requis, types numériques, plages
```

**Type B — RPCDialog** : Formulaire de paramétrage pour lancer un traitement RPC
```
Déclencheur : menu ou page dédiée
Structure : sélection de paramètres → bouton "Lancer" → affichage résultat
Exemples : Calcul de paie (mois, année), Génération amortissements (période)
```

**Type C — JournalEntryForm** : Formulaire multi-lignes spécialisé
```
Déclencheur : saisie d'écriture comptable
Structure : en-tête (journal, date, libellé) + grille de lignes (compte, débit, crédit)
Contrôle : équilibre D/C en temps réel, auto-complétion des comptes
```

## GRID_REGISTRY — Configuration déclarative

Chaque entité SmartGrid est définie par un objet de configuration :

```javascript
const GRID = {
  [entityKey]: {
    rowKey: "id",           // Clé primaire
    entityLabel: "Employé", // Label pour le formulaire
    columns: [
      {
        id: "field_name",       // Nom du champ dans la donnée
        label: "Libellé",       // Header de colonne
        width: 120,             // Largeur en px
        flex: 0,                // Flex-grow (1 pour colonnes extensibles)
        align: "left",          // left | center | right
        type: "text",           // text | currency | number | percent | date | badge | boolean
        sortable: true,         // Tri activé
        filterable: true,       // Filtre activé
        groupable: true,        // Groupement activé
        editable: true,         // Apparaît dans le formulaire
        badgeMap: {             // Pour type "badge" seulement
          VALUE: { color: "#hex", label: "Affiché" }
        },
        render: (value, row, theme) => JSX  // Rendu personnalisé (optionnel)
      }
    ]
  }
};
```

## FORM_REGISTRY — Génération automatique

Le formulaire EntityFormDrawer est auto-généré depuis GRID_REGISTRY :

| Type colonne | Composant formulaire | Props |
|-------------|---------------------|-------|
| text | `<input type="text">` | placeholder = label |
| currency | `<input type="number">` | font-mono |
| number | `<input type="number">` | step=1 |
| percent | `<input type="number" step="0.001">` | suffixe ×100% |
| date | `<input type="date">` | défaut = aujourd'hui |
| boolean | `<input type="checkbox">` | défaut = true |
| badge | `<select>` | options depuis badgeMap |

## Thème dual (clair/sombre)
Toute l'interface doit supporter un sélecteur de thème. Utiliser un Context React :

```javascript
const THEMES = {
  dark: { bg, sidebar, panel, card, border, text, textMuted, gold, green, accent, danger, ... },
  light: { bg, sidebar, panel, card, border, text, textMuted, gold, green, accent, danger, ... },
};
const ThemeCtx = createContext(THEMES.dark);
const useTheme = () => useContext(ThemeCtx);
```

Chaque composant lit `const t = useTheme()` et applique `t.bg`, `t.text`, etc.
