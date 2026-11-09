# EdenFin JASPE — Guide de lancement console

## Prérequis

- **Node.js 18+** → `node -v` pour vérifier
- **npm 9+** → `npm -v`

Si non installé : https://nodejs.org (prendre la version LTS)

---

## Option A — Bootstrap automatique (recommandé)

```bash
# 1. Extraire l'archive
tar -xzf edenfin-jaspe-bootstrap.tar.gz

# 2. Rendre le script exécutable
chmod +x bootstrap.sh

# 3. Lancer (crée le projet + installe + démarre)
./bootstrap.sh
```

Le script va :
- Créer le dossier `edenfin-jaspe/`
- Initialiser Vite + React
- Installer Tailwind, Recharts, Lucide, Supabase client
- Copier le SmartGrid et le plan comptable SQL
- Créer toutes les pages (Dashboard, Journal, Plan comptable, SmartGrid)
- Ouvrir automatiquement http://localhost:3000

---

## Option B — Étape par étape (manuel)

```bash
# 1. Créer le projet
npm create vite@latest edenfin-jaspe -- --template react
cd edenfin-jaspe

# 2. Installer les dépendances
npm install
npm install -D tailwindcss @tailwindcss/vite
npm install lucide-react @supabase/supabase-js recharts

# 3. Copier SmartGrid-OHADA-Demo.jsx dans :
#    src/components/grid/SmartGrid.jsx

# 4. Lancer
npm run dev
```

---

## Commandes courantes

| Commande | Action |
|----------|--------|
| `npm run dev` | Serveur dev avec HMR (http://localhost:3000) |
| `npm run build` | Build production → dossier `dist/` |
| `npm run preview` | Prévisualiser le build production |
| `npx supabase start` | Lancer Supabase local (si installé) |

---

## Connexion à Supabase (optionnel)

Le système fonctionne **par défaut en mode mock** (données locales générées).
Pour passer en base réelle :

```bash
# 1. Éditer .env
VITE_DATA_MODE=supabase
VITE_SUPABASE_URL=https://votre-projet.supabase.co
VITE_SUPABASE_ANON_KEY=eyJ...votre_clé...

# 2. Dans Supabase SQL Editor, exécuter :
#    database/migrations/01_plan_comptable.sql

# 3. Relancer
npm run dev
```

---

## Structure du projet créé

```
edenfin-jaspe/
├── src/
│   ├── App.jsx                    ← App shell (routing, layout)
│   ├── main.jsx                   ← Point d'entrée
│   ├── index.css                  ← Tailwind + fonts
│   ├── components/
│   │   ├── layout/
│   │   │   ├── Sidebar.jsx        ← Navigation latérale
│   │   │   └── Header.jsx         ← Barre supérieure
│   │   └── grid/
│   │       └── SmartGrid.jsx      ← Grille avancée OHADA
│   ├── pages/
│   │   ├── dashboard/
│   │   │   └── DashboardPage.jsx  ← KPIs + graphiques
│   │   └── comptabilite/
│   │       ├── JournalPage.jsx    ← Journal des écritures
│   │       ├── PlanComptablePage.jsx ← Plan OHADA 7 classes
│   │       └── SmartGridPage.jsx  ← SmartGrid wrapper
│   ├── data/
│   │   └── mock-data.js           ← Données mock OHADA réalistes
│   └── services/
│       └── supabase.js            ← Client Supabase (auto-detect mode)
├── database/
│   └── migrations/
│       └── 01_plan_comptable.sql  ← 1200+ comptes SYSCOHADA
├── .env                           ← Configuration (mock/supabase)
├── tailwind.config.js
├── vite.config.js
└── package.json
```

---

## Pages disponibles

| Page | Navigation | Contenu |
|------|-----------|---------|
| **Tableau de bord** | Sidebar → 1er item | 6 KPIs, graphique CA/Charges/Résultat |
| **Journal des écritures** | Comptabilité → Journal | 200 écritures, filtres, recherche, totaux |
| **Plan comptable** | Comptabilité → Plan comptable | 7 classes OHADA, expansion/réduction |
| **SmartGrid** | Comptabilité → SmartGrid | Grille avancée (tri, filtre, pagination, thème) |

Les modules Trésorerie, Paie, Immobilisations sont en attente (badge "Bientôt").
