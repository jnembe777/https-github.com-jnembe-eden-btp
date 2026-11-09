#!/usr/bin/env bash
# ============================================================================
# EDENFIN JASPE — BOOTSTRAP COMPLET
# Lance tout le système en mode développement local
# ============================================================================
# Usage:
#   chmod +x bootstrap.sh
#   ./bootstrap.sh
#
# Prérequis:
#   - Node.js 18+ (https://nodejs.org)
#   - npm 9+
#   - (Optionnel) Un projet Supabase pour la base de données
# ============================================================================

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         EDENFIN JASPE — Bootstrap Console           ║${NC}"
echo -e "${CYAN}║     ERP Comptable OHADA/CEMAC · Gamme JASPE         ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# ── Vérifier Node.js ──
if ! command -v node &> /dev/null; then
    echo -e "${RED}✖ Node.js non trouvé. Installez-le depuis https://nodejs.org${NC}"
    exit 1
fi
NODE_VER=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VER" -lt 18 ]; then
    echo -e "${RED}✖ Node.js 18+ requis (trouvé: $(node -v))${NC}"
    exit 1
fi
echo -e "${GREEN}✔ Node.js $(node -v)${NC}"

# ── Créer le projet Vite + React ──
PROJECT_DIR="edenfin-jaspe"

if [ -d "$PROJECT_DIR" ]; then
    echo -e "${YELLOW}⚠ Le dossier '$PROJECT_DIR' existe déjà.${NC}"
    read -p "  Supprimer et recréer ? (o/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        rm -rf "$PROJECT_DIR"
    else
        echo -e "${BLUE}→ Lancement du projet existant...${NC}"
        cd "$PROJECT_DIR"
        npm run dev
        exit 0
    fi
fi

echo -e "${BLUE}→ Création du projet Vite + React...${NC}"
npm create vite@latest "$PROJECT_DIR" -- --template react 2>/dev/null
cd "$PROJECT_DIR"

# ── Installer les dépendances ──
echo -e "${BLUE}→ Installation des dépendances...${NC}"
npm install

# Tailwind CSS + plugins
npm install -D tailwindcss @tailwindcss/vite

# Dépendances runtime
npm install lucide-react @supabase/supabase-js recharts

echo -e "${GREEN}✔ Dépendances installées${NC}"

# ── Configurer Tailwind ──
cat > tailwind.config.js << 'TAILWIND_EOF'
/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        gold: { 50: '#FFF9E6', 100: '#FFF0BF', 200: '#FFE080', 300: '#FFD040', 400: '#D4A853', 500: '#B8922E', 600: '#8B6914', 700: '#5C4A10', 800: '#3D310A', 900: '#1E1805' },
        eden: { 50: '#F0F4F8', 100: '#D9E2EC', 200: '#BCCCDC', 300: '#9FB3C8', 400: '#829AB1', 500: '#627D98', 600: '#486581', 700: '#334E68', 800: '#243B53', 900: '#102A43' }
      },
      fontFamily: {
        display: ['"DM Serif Display"', 'Georgia', 'serif'],
        sans: ['"DM Sans"', 'system-ui', 'sans-serif']
      }
    }
  },
  plugins: []
}
TAILWIND_EOF

# ── Configurer Vite ──
cat > vite.config.js << 'VITE_EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    port: 3000,
    open: true
  }
})
VITE_EOF

# ── CSS global ──
cat > src/index.css << 'CSS_EOF'
@import "tailwindcss";

@import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@300;400;500;600;700&family=DM+Serif+Display&display=swap');

:root {
  --gold-primary: #D4A853;
  --eden-dark: #102A43;
  --eden-mid: #334E68;
}

body {
  font-family: 'DM Sans', system-ui, sans-serif;
  -webkit-font-smoothing: antialiased;
}

/* Scrollbar custom */
::-webkit-scrollbar { width: 6px; height: 6px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: #94a3b8; border-radius: 3px; }
::-webkit-scrollbar-thumb:hover { background: #64748b; }
CSS_EOF

# ── Fichier .env ──
cat > .env << 'ENV_EOF'
# ============================================================================
# EDENFIN JASPE — Configuration
# ============================================================================
# Mode: "mock" (données locales) ou "supabase" (base réelle)
VITE_DATA_MODE=mock

# Supabase (remplir si VITE_DATA_MODE=supabase)
VITE_SUPABASE_URL=https://VOTRE_PROJET.supabase.co
VITE_SUPABASE_ANON_KEY=eyJ_VOTRE_CLE_ICI

# Tenant par défaut
VITE_DEFAULT_TENANT=DEMO_001
VITE_DEFAULT_CURRENCY=XAF
ENV_EOF

cat > .env.example << 'ENV_EOF'
VITE_DATA_MODE=mock
VITE_SUPABASE_URL=https://xxxxx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
VITE_DEFAULT_TENANT=DEMO_001
VITE_DEFAULT_CURRENCY=XAF
ENV_EOF

# ── Structure des dossiers ──
mkdir -p src/{components,pages,services,hooks,stores,data,utils}
mkdir -p src/components/{ui,grid,layout,forms,charts}
mkdir -p src/pages/{dashboard,comptabilite,tresorerie,paie,immobilisations,parametrage}
mkdir -p database/migrations

echo -e "${GREEN}✔ Structure créée${NC}"

# ── Supabase Client ──
cat > src/services/supabase.js << 'SUPA_EOF'
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || ''
const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY || ''
const dataMode = import.meta.env.VITE_DATA_MODE || 'mock'

export const isLive = dataMode === 'supabase' && supabaseUrl && supabaseKey
export const supabase = isLive ? createClient(supabaseUrl, supabaseKey) : null

console.log(`[EdenFin] Mode: ${isLive ? '🟢 SUPABASE LIVE' : '🟡 MOCK LOCAL'}`)
SUPA_EOF

# ── Données mock ──
cat > src/data/mock-data.js << 'MOCK_EOF'
// ============================================================================
// EDENFIN JASPE — Données Mock OHADA/CEMAC
// ============================================================================

export const JOURNAUX = [
  { code: 'VTE', libelle: 'Journal des Ventes', type: 'VENTE' },
  { code: 'ACH', libelle: 'Journal des Achats', type: 'ACHAT' },
  { code: 'BQ1', libelle: 'Banque SGBG', type: 'BANQUE' },
  { code: 'CAI', libelle: 'Caisse Siège', type: 'CAISSE' },
  { code: 'OD', libelle: 'Opérations Diverses', type: 'OD' },
  { code: 'PAI', libelle: 'Journal de Paie', type: 'PAIE' },
];

export const COMPTES_OHADA = [
  { numero: '101000', libelle: 'Capital social', classe: 1, type: 'BILAN', sens: 'C' },
  { numero: '121000', libelle: 'Report à nouveau créditeur', classe: 1, type: 'BILAN', sens: 'C' },
  { numero: '164000', libelle: 'Emprunts auprès des établissements de crédit', classe: 1, type: 'BILAN', sens: 'C' },
  { numero: '211000', libelle: 'Frais d\'établissement', classe: 2, type: 'BILAN', sens: 'D' },
  { numero: '241000', libelle: 'Matériel industriel', classe: 2, type: 'BILAN', sens: 'D' },
  { numero: '244000', libelle: 'Matériel et mobilier de bureau', classe: 2, type: 'BILAN', sens: 'D' },
  { numero: '245000', libelle: 'Matériel de transport', classe: 2, type: 'BILAN', sens: 'D' },
  { numero: '281000', libelle: 'Amortissements immobilisations corporelles', classe: 2, type: 'BILAN', sens: 'C' },
  { numero: '311000', libelle: 'Marchandises', classe: 3, type: 'BILAN', sens: 'D' },
  { numero: '401100', libelle: 'Fournisseurs locaux', classe: 4, type: 'BILAN', sens: 'C' },
  { numero: '411100', libelle: 'Clients locaux', classe: 4, type: 'BILAN', sens: 'D' },
  { numero: '421000', libelle: 'Personnel, rémunérations dues', classe: 4, type: 'BILAN', sens: 'C' },
  { numero: '431000', libelle: 'Sécurité sociale (CNSS)', classe: 4, type: 'BILAN', sens: 'C' },
  { numero: '443100', libelle: 'TVA facturée (18%)', classe: 4, type: 'BILAN', sens: 'C' },
  { numero: '445200', libelle: 'TVA récupérable', classe: 4, type: 'BILAN', sens: 'D' },
  { numero: '521100', libelle: 'Banque SGBG XAF', classe: 5, type: 'BILAN', sens: 'D' },
  { numero: '571000', libelle: 'Caisse siège', classe: 5, type: 'BILAN', sens: 'D' },
  { numero: '601100', libelle: 'Achats de marchandises', classe: 6, type: 'GESTION', sens: 'D' },
  { numero: '605000', libelle: 'Autres achats', classe: 6, type: 'GESTION', sens: 'D' },
  { numero: '613000', libelle: 'Locations et charges locatives', classe: 6, type: 'GESTION', sens: 'D' },
  { numero: '616000', libelle: 'Transports de biens', classe: 6, type: 'GESTION', sens: 'D' },
  { numero: '661000', libelle: 'Rémunérations du personnel', classe: 6, type: 'GESTION', sens: 'D' },
  { numero: '664100', libelle: 'Charges sociales patronales (CNSS)', classe: 6, type: 'GESTION', sens: 'D' },
  { numero: '671000', libelle: 'Intérêts des emprunts', classe: 6, type: 'GESTION', sens: 'D' },
  { numero: '701100', libelle: 'Ventes de marchandises', classe: 7, type: 'GESTION', sens: 'C' },
  { numero: '706000', libelle: 'Services vendus', classe: 7, type: 'GESTION', sens: 'C' },
  { numero: '758000', libelle: 'Produits divers', classe: 7, type: 'GESTION', sens: 'C' },
  { numero: '771000', libelle: 'Intérêts de prêts', classe: 7, type: 'GESTION', sens: 'C' },
];

const noms = ['MBARGA', 'NKOLO', 'ESSOMBA', 'ONDO', 'MBA', 'OBIANG', 'NZOGHE', 'MINTSA'];
const prenoms = ['Jean', 'Marie', 'Pierre', 'Aude', 'Paul', 'Claire', 'Serge', 'Béatrice'];

function rand(arr) { return arr[Math.floor(Math.random() * arr.length)]; }
function randInt(min, max) { return Math.floor(Math.random() * (max - min + 1)) + min; }
function fmtDate(d) { return d.toISOString().split('T')[0]; }
function fmtXAF(n) { return new Intl.NumberFormat('fr-FR').format(n) + ' XAF'; }

export function generateEcritures(count = 200) {
  const ecritures = [];
  const statuts = ['brouillon', 'validee', 'lettree'];
  for (let i = 0; i < count; i++) {
    const jour = randInt(1, 28);
    const mois = randInt(1, 12);
    const journal = rand(JOURNAUX);
    const compte = rand(COMPTES_OHADA);
    const isDebit = Math.random() > 0.5;
    const montant = randInt(5, 500) * 1000;
    ecritures.push({
      id: `ECR-${String(i+1).padStart(6,'0')}`,
      date: `2026-${String(mois).padStart(2,'0')}-${String(jour).padStart(2,'0')}`,
      journal: journal.code,
      piece: `${journal.code}-${String(randInt(1,999)).padStart(4,'0')}`,
      compte: compte.numero,
      libelleCompte: compte.libelle,
      libelle: `${journal.libelle} - ${compte.libelle}`,
      debit: isDebit ? montant : 0,
      credit: isDebit ? 0 : montant,
      statut: rand(statuts),
      utilisateur: `${rand(prenoms)} ${rand(noms)}`,
    });
  }
  return ecritures.sort((a,b) => a.date.localeCompare(b.date));
}

export function generateEmployes(count = 25) {
  return Array.from({ length: count }, (_, i) => ({
    id: `EMP-${String(i+1).padStart(4,'0')}`,
    matricule: `GA-${String(i+1).padStart(4,'0')}`,
    nom: rand(noms),
    prenom: rand(prenoms),
    poste: rand(['Comptable', 'Caissier', 'Commercial', 'Directeur', 'Secrétaire', 'Technicien', 'Chauffeur', 'Agent']),
    departement: rand(['Comptabilité', 'Commercial', 'Direction', 'RH', 'Logistique', 'Production']),
    salaireBase: randInt(150, 800) * 1000,
    dateEmbauche: `${randInt(2018, 2025)}-${String(randInt(1,12)).padStart(2,'0')}-01`,
    typeContrat: rand(['CDI', 'CDD', 'Stage']),
    statut: rand(['Actif', 'Actif', 'Actif', 'Congé', 'Suspendu']),
  }));
}

export function generateKPIs() {
  return {
    chiffreAffaires: { valeur: 487_500_000, variation: +12.3, label: 'CA Mensuel' },
    charges: { valeur: 312_000_000, variation: +5.1, label: 'Charges' },
    tresorerie: { valeur: 175_500_000, variation: -2.8, label: 'Trésorerie' },
    dso: { valeur: 45, variation: -3, label: 'DSO (jours)' },
    employes: { valeur: 25, variation: 0, label: 'Effectif' },
    masseSalariale: { valeur: 8_750_000, variation: +1.5, label: 'Masse Salariale' },
  };
}

export function generateCaMensuel() {
  const mois = ['Jan','Fév','Mar','Avr','Mai','Jun','Jul','Aoû','Sep','Oct','Nov','Déc'];
  return mois.map((m, i) => ({
    mois: m,
    ca: randInt(350, 550) * 1_000_000,
    charges: randInt(250, 380) * 1_000_000,
    resultat: randInt(50, 180) * 1_000_000,
  }));
}
MOCK_EOF

# ── App principale ──
cat > src/App.jsx << 'APP_EOF'
import React, { useState } from 'react'
import { Sidebar } from './components/layout/Sidebar'
import { Header } from './components/layout/Header'
import { DashboardPage } from './pages/dashboard/DashboardPage'
import { JournalPage } from './pages/comptabilite/JournalPage'
import { PlanComptablePage } from './pages/comptabilite/PlanComptablePage'
import { SmartGridPage } from './pages/comptabilite/SmartGridPage'

const PAGES = {
  dashboard: { component: DashboardPage, label: 'Tableau de bord' },
  journal: { component: JournalPage, label: 'Journal des écritures' },
  plan: { component: PlanComptablePage, label: 'Plan comptable OHADA' },
  smartgrid: { component: SmartGridPage, label: 'SmartGrid Écritures' },
}

export default function App() {
  const [page, setPage] = useState('dashboard')
  const [sidebarOpen, setSidebarOpen] = useState(true)
  const [dark, setDark] = useState(false)

  const PageComponent = PAGES[page]?.component || DashboardPage

  return (
    <div className={dark ? 'dark' : ''}>
      <div className="flex h-screen bg-slate-50 dark:bg-slate-900 text-slate-900 dark:text-slate-100">
        <Sidebar
          activePage={page}
          onNavigate={setPage}
          isOpen={sidebarOpen}
          onToggle={() => setSidebarOpen(!sidebarOpen)}
        />
        <div className="flex-1 flex flex-col overflow-hidden">
          <Header
            title={PAGES[page]?.label || ''}
            dark={dark}
            onToggleDark={() => setDark(!dark)}
            onToggleSidebar={() => setSidebarOpen(!sidebarOpen)}
          />
          <main className="flex-1 overflow-auto p-6">
            <PageComponent />
          </main>
        </div>
      </div>
    </div>
  )
}
APP_EOF

# ── main.jsx ──
cat > src/main.jsx << 'MAIN_EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
MAIN_EOF

# ── Sidebar ──
cat > src/components/layout/Sidebar.jsx << 'SIDEBAR_EOF'
import React from 'react'
import { LayoutDashboard, BookOpen, List, Grid3X3, ChevronLeft, ChevronRight, DollarSign, Users, Building2, Settings } from 'lucide-react'

const NAV = [
  { id: 'dashboard', label: 'Tableau de bord', icon: LayoutDashboard },
  { id: '_sep1', type: 'separator', label: 'COMPTABILITÉ' },
  { id: 'journal', label: 'Journal des écritures', icon: BookOpen },
  { id: 'plan', label: 'Plan comptable OHADA', icon: List },
  { id: 'smartgrid', label: 'SmartGrid', icon: Grid3X3 },
  { id: '_sep2', type: 'separator', label: 'GESTION' },
  { id: 'tresorerie', label: 'Trésorerie', icon: DollarSign, disabled: true },
  { id: 'paie', label: 'Paie & RH', icon: Users, disabled: true },
  { id: 'immo', label: 'Immobilisations', icon: Building2, disabled: true },
  { id: '_sep3', type: 'separator', label: 'SYSTÈME' },
  { id: 'param', label: 'Paramétrage', icon: Settings, disabled: true },
]

export function Sidebar({ activePage, onNavigate, isOpen, onToggle }) {
  return (
    <aside className={`${isOpen ? 'w-64' : 'w-16'} flex-shrink-0 bg-eden-900 text-white transition-all duration-300 flex flex-col`}>
      {/* Logo */}
      <div className="h-16 flex items-center px-4 border-b border-eden-700">
        {isOpen ? (
          <div>
            <span className="font-display text-xl text-gold-400">EdenFin</span>
            <span className="ml-2 text-xs bg-gold-400 text-eden-900 px-2 py-0.5 rounded font-semibold">JASPE</span>
          </div>
        ) : (
          <span className="font-display text-xl text-gold-400 mx-auto">E</span>
        )}
      </div>

      {/* Navigation */}
      <nav className="flex-1 py-4 overflow-y-auto">
        {NAV.map(item => {
          if (item.type === 'separator') {
            return isOpen ? (
              <div key={item.id} className="px-4 pt-6 pb-2 text-[10px] font-semibold tracking-widest text-eden-400">
                {item.label}
              </div>
            ) : <div key={item.id} className="my-2 border-t border-eden-700 mx-2" />
          }
          const Icon = item.icon
          const active = activePage === item.id
          return (
            <button
              key={item.id}
              onClick={() => !item.disabled && onNavigate(item.id)}
              disabled={item.disabled}
              className={`w-full flex items-center gap-3 px-4 py-2.5 text-sm transition-colors
                ${active ? 'bg-gold-400/20 text-gold-300 border-r-2 border-gold-400' : ''}
                ${item.disabled ? 'opacity-30 cursor-not-allowed' : 'hover:bg-eden-800 cursor-pointer'}
                ${!active && !item.disabled ? 'text-eden-200' : ''}
              `}
            >
              <Icon size={18} />
              {isOpen && <span>{item.label}</span>}
              {isOpen && item.disabled && <span className="ml-auto text-[9px] bg-eden-700 px-1.5 py-0.5 rounded">Bientôt</span>}
            </button>
          )
        })}
      </nav>

      {/* Footer */}
      <div className="p-4 border-t border-eden-700">
        {isOpen && (
          <div className="text-xs text-eden-400 mb-2">
            <div className="font-semibold text-eden-200">Entreprise Démo OHADA</div>
            <div>Libreville, Gabon · XAF</div>
          </div>
        )}
        <button onClick={onToggle} className="w-full flex items-center justify-center py-1 text-eden-400 hover:text-white">
          {isOpen ? <ChevronLeft size={16} /> : <ChevronRight size={16} />}
        </button>
      </div>
    </aside>
  )
}
SIDEBAR_EOF

# ── Header ──
cat > src/components/layout/Header.jsx << 'HEADER_EOF'
import React from 'react'
import { Menu, Sun, Moon, Bell, Search, User } from 'lucide-react'

export function Header({ title, dark, onToggleDark, onToggleSidebar }) {
  return (
    <header className="h-16 flex-shrink-0 bg-white dark:bg-slate-800 border-b border-slate-200 dark:border-slate-700 flex items-center justify-between px-6">
      <div className="flex items-center gap-4">
        <button onClick={onToggleSidebar} className="text-slate-500 hover:text-slate-700 dark:hover:text-white">
          <Menu size={20} />
        </button>
        <h1 className="text-lg font-semibold">{title}</h1>
      </div>
      <div className="flex items-center gap-3">
        <div className="relative hidden sm:block">
          <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
          <input
            type="text"
            placeholder="Rechercher..."
            className="pl-9 pr-4 py-1.5 text-sm border border-slate-200 dark:border-slate-600 rounded-lg bg-slate-50 dark:bg-slate-700 w-56 focus:outline-none focus:ring-2 focus:ring-gold-400"
          />
        </div>
        <button className="relative text-slate-500 hover:text-slate-700 dark:hover:text-white">
          <Bell size={18} />
          <span className="absolute -top-1 -right-1 w-2 h-2 bg-red-500 rounded-full" />
        </button>
        <button onClick={onToggleDark} className="text-slate-500 hover:text-slate-700 dark:hover:text-white">
          {dark ? <Sun size={18} /> : <Moon size={18} />}
        </button>
        <div className="w-8 h-8 bg-gold-400 rounded-full flex items-center justify-center text-eden-900 text-xs font-bold">
          JN
        </div>
      </div>
    </header>
  )
}
HEADER_EOF

# ── Dashboard Page ──
cat > src/pages/dashboard/DashboardPage.jsx << 'DASH_EOF'
import React from 'react'
import { TrendingUp, TrendingDown, DollarSign, CreditCard, Landmark, Clock, Users, Banknote } from 'lucide-react'
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, Legend } from 'recharts'
import { generateKPIs, generateCaMensuel } from '../../data/mock-data'

const ICONS = { 'CA Mensuel': DollarSign, 'Charges': CreditCard, 'Trésorerie': Landmark, 'DSO (jours)': Clock, 'Effectif': Users, 'Masse Salariale': Banknote }
const fmtXAF = (n) => new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 0 }).format(n)

function KPICard({ kpi }) {
  const Icon = ICONS[kpi.label] || DollarSign
  const isPositive = kpi.variation >= 0
  const isGood = kpi.label === 'Charges' || kpi.label === 'DSO (jours)' ? !isPositive : isPositive
  return (
    <div className="bg-white dark:bg-slate-800 rounded-xl p-5 border border-slate-200 dark:border-slate-700 hover:shadow-md transition-shadow">
      <div className="flex items-center justify-between mb-3">
        <span className="text-sm text-slate-500 dark:text-slate-400">{kpi.label}</span>
        <div className="w-10 h-10 bg-gold-50 dark:bg-gold-400/10 rounded-lg flex items-center justify-center">
          <Icon size={20} className="text-gold-500" />
        </div>
      </div>
      <div className="text-2xl font-bold mb-1">
        {kpi.label.includes('jours') ? kpi.valeur : kpi.label === 'Effectif' ? kpi.valeur : fmtXAF(kpi.valeur)}
        {!kpi.label.includes('jours') && kpi.label !== 'Effectif' && <span className="text-sm font-normal text-slate-400 ml-1">XAF</span>}
      </div>
      <div className={`flex items-center gap-1 text-sm ${isGood ? 'text-emerald-500' : 'text-red-500'}`}>
        {isPositive ? <TrendingUp size={14} /> : <TrendingDown size={14} />}
        <span>{isPositive ? '+' : ''}{kpi.variation}%</span>
        <span className="text-slate-400 ml-1">vs mois préc.</span>
      </div>
    </div>
  )
}

export function DashboardPage() {
  const kpis = generateKPIs()
  const caData = generateCaMensuel()

  return (
    <div className="space-y-6">
      {/* KPIs */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4">
        {Object.values(kpis).map(k => <KPICard key={k.label} kpi={k} />)}
      </div>

      {/* Graphique CA */}
      <div className="bg-white dark:bg-slate-800 rounded-xl p-6 border border-slate-200 dark:border-slate-700">
        <h3 className="font-semibold mb-4">Évolution CA / Charges / Résultat — Exercice 2026</h3>
        <ResponsiveContainer width="100%" height={320}>
          <BarChart data={caData}>
            <XAxis dataKey="mois" tick={{ fontSize: 12 }} />
            <YAxis tickFormatter={v => `${(v/1e6).toFixed(0)}M`} tick={{ fontSize: 12 }} />
            <Tooltip formatter={v => fmtXAF(v) + ' XAF'} />
            <Legend />
            <Bar dataKey="ca" name="Chiffre d'affaires" fill="#D4A853" radius={[4,4,0,0]} />
            <Bar dataKey="charges" name="Charges" fill="#334E68" radius={[4,4,0,0]} />
            <Bar dataKey="resultat" name="Résultat" fill="#10B981" radius={[4,4,0,0]} />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  )
}
DASH_EOF

# ── Journal Page ──
cat > src/pages/comptabilite/JournalPage.jsx << 'JOURNAL_EOF'
import React, { useState, useMemo } from 'react'
import { Search, Filter, Download } from 'lucide-react'
import { generateEcritures, JOURNAUX } from '../../data/mock-data'

const fmtXAF = (n) => n === 0 ? '' : new Intl.NumberFormat('fr-FR').format(n)
const STATUT_COLORS = { brouillon: 'bg-amber-100 text-amber-700', validee: 'bg-emerald-100 text-emerald-700', lettree: 'bg-blue-100 text-blue-700' }

export function JournalPage() {
  const [ecritures] = useState(() => generateEcritures(200))
  const [search, setSearch] = useState('')
  const [filtreJournal, setFiltreJournal] = useState('TOUS')

  const filtered = useMemo(() => {
    return ecritures.filter(e => {
      if (filtreJournal !== 'TOUS' && e.journal !== filtreJournal) return false
      if (search && !`${e.libelle} ${e.compte} ${e.piece}`.toLowerCase().includes(search.toLowerCase())) return false
      return true
    })
  }, [ecritures, search, filtreJournal])

  const totaux = useMemo(() => ({
    debit: filtered.reduce((s, e) => s + e.debit, 0),
    credit: filtered.reduce((s, e) => s + e.credit, 0),
  }), [filtered])

  return (
    <div className="space-y-4">
      {/* Toolbar */}
      <div className="flex flex-wrap items-center gap-3">
        <div className="relative flex-1 min-w-[200px] max-w-md">
          <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
          <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Rechercher par libellé, compte, pièce..."
            className="w-full pl-9 pr-4 py-2 text-sm border rounded-lg bg-white dark:bg-slate-800 dark:border-slate-600 focus:ring-2 focus:ring-gold-400 focus:outline-none" />
        </div>
        <select value={filtreJournal} onChange={e => setFiltreJournal(e.target.value)}
          className="text-sm border rounded-lg px-3 py-2 bg-white dark:bg-slate-800 dark:border-slate-600">
          <option value="TOUS">Tous les journaux</option>
          {JOURNAUX.map(j => <option key={j.code} value={j.code}>{j.code} — {j.libelle}</option>)}
        </select>
        <span className="text-sm text-slate-500">{filtered.length} écritures</span>
      </div>

      {/* Table */}
      <div className="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-slate-50 dark:bg-slate-700/50">
              <tr>
                {['Date','Journal','Pièce','Compte','Libellé','Débit','Crédit','Statut'].map(h => (
                  <th key={h} className="px-4 py-3 text-left font-semibold text-slate-600 dark:text-slate-300 whitespace-nowrap">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 dark:divide-slate-700">
              {filtered.slice(0, 100).map(e => (
                <tr key={e.id} className="hover:bg-slate-50 dark:hover:bg-slate-700/30 transition-colors">
                  <td className="px-4 py-2.5 whitespace-nowrap font-mono text-xs">{e.date}</td>
                  <td className="px-4 py-2.5"><span className="px-2 py-0.5 bg-eden-100 dark:bg-eden-700 text-eden-700 dark:text-eden-200 rounded text-xs font-semibold">{e.journal}</span></td>
                  <td className="px-4 py-2.5 font-mono text-xs">{e.piece}</td>
                  <td className="px-4 py-2.5 font-mono text-xs">{e.compte}</td>
                  <td className="px-4 py-2.5 max-w-[300px] truncate">{e.libelle}</td>
                  <td className="px-4 py-2.5 text-right font-mono">{fmtXAF(e.debit)}</td>
                  <td className="px-4 py-2.5 text-right font-mono">{fmtXAF(e.credit)}</td>
                  <td className="px-4 py-2.5">
                    <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${STATUT_COLORS[e.statut] || ''}`}>{e.statut}</span>
                  </td>
                </tr>
              ))}
            </tbody>
            <tfoot className="bg-slate-50 dark:bg-slate-700/50 font-semibold">
              <tr>
                <td colSpan={5} className="px-4 py-3 text-right">TOTAUX</td>
                <td className="px-4 py-3 text-right font-mono">{fmtXAF(totaux.debit)}</td>
                <td className="px-4 py-3 text-right font-mono">{fmtXAF(totaux.credit)}</td>
                <td className="px-4 py-3">
                  {totaux.debit === totaux.credit
                    ? <span className="text-emerald-500 text-xs">✓ Équilibré</span>
                    : <span className="text-red-500 text-xs">✗ Écart: {fmtXAF(Math.abs(totaux.debit - totaux.credit))}</span>}
                </td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>
    </div>
  )
}
JOURNAL_EOF

# ── Plan Comptable Page ──
cat > src/pages/comptabilite/PlanComptablePage.jsx << 'PLAN_EOF'
import React, { useState } from 'react'
import { ChevronRight, ChevronDown, Search } from 'lucide-react'
import { COMPTES_OHADA } from '../../data/mock-data'

const CLASSES = [
  { num: 1, libelle: 'Comptes de ressources durables', color: 'bg-blue-500' },
  { num: 2, libelle: 'Comptes d\'actif immobilisé', color: 'bg-indigo-500' },
  { num: 3, libelle: 'Comptes de stocks', color: 'bg-purple-500' },
  { num: 4, libelle: 'Comptes de tiers', color: 'bg-amber-500' },
  { num: 5, libelle: 'Comptes de trésorerie', color: 'bg-emerald-500' },
  { num: 6, libelle: 'Comptes de charges', color: 'bg-red-500' },
  { num: 7, libelle: 'Comptes de produits', color: 'bg-green-500' },
]

export function PlanComptablePage() {
  const [open, setOpen] = useState({})
  const [search, setSearch] = useState('')

  const toggle = (cl) => setOpen(prev => ({ ...prev, [cl]: !prev[cl] }))

  const comptesParClasse = CLASSES.map(c => ({
    ...c,
    comptes: COMPTES_OHADA.filter(cpt => cpt.classe === c.num && (!search || `${cpt.numero} ${cpt.libelle}`.toLowerCase().includes(search.toLowerCase())))
  }))

  return (
    <div className="space-y-4">
      <div className="relative max-w-md">
        <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
        <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Rechercher un compte..."
          className="w-full pl-9 pr-4 py-2 text-sm border rounded-lg bg-white dark:bg-slate-800 dark:border-slate-600 focus:ring-2 focus:ring-gold-400 focus:outline-none" />
      </div>

      <div className="space-y-2">
        {comptesParClasse.map(cl => (
          <div key={cl.num} className="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 overflow-hidden">
            <button onClick={() => toggle(cl.num)}
              className="w-full flex items-center gap-3 px-5 py-3 hover:bg-slate-50 dark:hover:bg-slate-700/30 transition-colors">
              <div className={`w-8 h-8 ${cl.color} rounded-lg flex items-center justify-center text-white font-bold text-sm`}>{cl.num}</div>
              <span className="font-semibold flex-1 text-left">Classe {cl.num} — {cl.libelle}</span>
              <span className="text-xs text-slate-400">{cl.comptes.length} comptes</span>
              {open[cl.num] ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
            </button>
            {open[cl.num] && cl.comptes.length > 0 && (
              <div className="border-t border-slate-100 dark:border-slate-700">
                {cl.comptes.map(cpt => (
                  <div key={cpt.numero} className="flex items-center px-5 py-2 hover:bg-slate-50 dark:hover:bg-slate-700/20 text-sm border-b border-slate-50 dark:border-slate-700/50 last:border-0">
                    <span className="w-24 font-mono text-xs text-slate-500">{cpt.numero}</span>
                    <span className="flex-1">{cpt.libelle}</span>
                    <span className="text-xs px-2 py-0.5 rounded bg-slate-100 dark:bg-slate-700 text-slate-500">{cpt.sens === 'D' ? 'Débiteur' : 'Créditeur'}</span>
                  </div>
                ))}
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  )
}
PLAN_EOF

# ── SmartGrid Page (intègre le composant du projet) ──
cat > src/pages/comptabilite/SmartGridPage.jsx << 'SG_EOF'
import React from 'react'
import SmartGrid from '../../components/grid/SmartGrid'

export function SmartGridPage() {
  return (
    <div className="h-[calc(100vh-8rem)]">
      <SmartGrid />
    </div>
  )
}
SG_EOF

# ── Copier le SmartGrid du projet ──
if [ -f "../SmartGrid-OHADA-Demo.jsx" ]; then
  cp "../SmartGrid-OHADA-Demo.jsx" src/components/grid/SmartGrid.jsx
  echo -e "${GREEN}✔ SmartGrid copié depuis le projet${NC}"
else
  echo -e "${YELLOW}⚠ SmartGrid-OHADA-Demo.jsx non trouvé à côté du bootstrap.${NC}"
  echo -e "${YELLOW}  Copiez-le manuellement dans src/components/grid/SmartGrid.jsx${NC}"
  # Créer un placeholder
  cat > src/components/grid/SmartGrid.jsx << 'PH_EOF'
import React from 'react'
export default function SmartGrid() {
  return (
    <div className="flex items-center justify-center h-full text-slate-400">
      <div className="text-center">
        <p className="text-lg font-semibold">SmartGrid</p>
        <p className="text-sm mt-2">Copiez SmartGrid-OHADA-Demo.jsx dans ce fichier</p>
      </div>
    </div>
  )
}
PH_EOF
fi

# ── Copier le SQL dans database/ ──
if [ -f "../plan_comptable_ohada_complet.sql" ]; then
  cp "../plan_comptable_ohada_complet.sql" database/migrations/01_plan_comptable.sql
  echo -e "${GREEN}✔ SQL Plan comptable copié${NC}"
fi

# ── Update index.html ──
cat > index.html << 'HTML_EOF'
<!DOCTYPE html>
<html lang="fr">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <link rel="icon" type="image/svg+xml" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>💰</text></svg>" />
    <title>EdenFin JASPE — Comptabilité OHADA</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
HTML_EOF

# ── README ──
cat > README.md << 'README_EOF'
# EdenFin JASPE — ERP Comptable OHADA/CEMAC

## Lancement rapide

```bash
npm run dev
```

Ouvre automatiquement http://localhost:3000

## Commandes

| Commande | Description |
|----------|-------------|
| `npm run dev` | Serveur de développement (HMR) |
| `npm run build` | Build production dans `dist/` |
| `npm run preview` | Prévisualiser le build |

## Structure

```
src/
├── components/         # Composants réutilisables
│   ├── layout/        # Sidebar, Header
│   ├── grid/          # SmartGrid OHADA
│   ├── forms/         # Formulaires métier
│   └── charts/        # Graphiques
├── pages/             # Pages par module
│   ├── dashboard/     # Tableau de bord
│   ├── comptabilite/  # Journal, Plan comptable, SmartGrid
│   ├── tresorerie/    # (à venir)
│   ├── paie/          # (à venir)
│   └── immobilisations/ # (à venir)
├── services/          # Supabase client, API
├── data/              # Données mock
├── hooks/             # Custom hooks
└── stores/            # State management
```

## Connexion Supabase

1. Créer un projet sur https://supabase.com
2. Exécuter les scripts SQL dans `database/migrations/`
3. Éditer `.env` :
   ```
   VITE_DATA_MODE=supabase
   VITE_SUPABASE_URL=https://xxxxx.supabase.co
   VITE_SUPABASE_ANON_KEY=eyJ...
   ```
4. Relancer `npm run dev`

## Stack

React 18 · Vite 5 · Tailwind CSS · Recharts · Supabase · Lucide Icons
README_EOF

# ── Fin ──
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          ✔ EDENFIN JASPE — PRÊT !                   ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Lancer le serveur :${NC}"
echo -e "    cd $PROJECT_DIR"
echo -e "    npm run dev"
echo ""
echo -e "  ${CYAN}Ouvre :${NC} http://localhost:3000"
echo ""
echo -e "  ${YELLOW}Mode actuel : MOCK (données locales)${NC}"
echo -e "  Pour connecter Supabase, éditez ${BLUE}.env${NC}"
echo ""
