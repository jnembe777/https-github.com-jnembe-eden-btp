# 🚀 Guide de Démarrage Rapide - EdenFin JASPE

**TL;DR** : Serveur en cours ✅ | Supabase configuré ✅ | Base de données à initialiser ⏳

---

## 📍 Liens Rapides

| Ressource | URL/Commande |
|-----------|--------------|
| **Serveur local** | http://localhost:8084/ |
| **Dashboard** | http://localhost:8084/console/dashboard |
| **Plan Comptable** | http://localhost:8084/console/plan-comptable |
| **Fonctions RPC** | http://localhost:8084/console/rpc-functions |
| **Supabase Dashboard** | https://rijhgjnhkadmoyxaxtrd.supabase.co |
| **GitHub Repo** | https://github.com/jnembe777/edenfin-your-financial-garden |

---

## 🎯 Actions Immédiates

### 1️⃣ Tester l'Application (MAINTENANT)
```bash
# Le serveur est déjà en cours sur http://localhost:8084/
# Ouvrir dans le navigateur :
- Dashboard : http://localhost:8084/console/dashboard
- Plan Comptable : http://localhost:8084/console/plan-comptable
- RPC Functions : http://localhost:8084/console/rpc-functions
```

**Résultat attendu** :
- ✅ Dashboard affiche "Mode démonstration" avec données mock
- ⚠️ Plan Comptable peut afficher erreur (normal, base vide)
- ✅ RPC Functions affiche liste des fonctions

---

### 2️⃣ Initialiser la Base de Données Supabase (PRIORITÉ)

#### Étape A : Se connecter à Supabase
```
1. Ouvrir : https://supabase.com/dashboard
2. Se connecter avec compte
3. Sélectionner projet : rijhgjnhkadmoyxaxtrd
4. Cliquer sur "SQL Editor" dans le menu gauche
```

#### Étape B : Exécuter les migrations SQL (dans l'ordre)
```bash
# Dossier : EdenFin-JASPE-Archive-Complete/02-migrations-sql/

# Dans Supabase SQL Editor → "New Query" → Coller et exécuter :

1. 01-schemas-and-rbac.sql       # Crée les schémas common, sys, client_demo
2. 02-common-tables.sql          # Tables de référence (pays, devises, etc.)
3. 03-client-tables.sql          # Tables métier (plan comptable, écritures, etc.)
4. 04-rpc-functions.sql          # 50+ fonctions PostgreSQL
5. 05-views-and-policies.sql     # Vues et RLS policies
6. 06-seed-data.sql              # Données de démonstration
```

**Temps estimé** : 5-10 minutes

**Vérification** :
```sql
-- Dans Supabase SQL Editor, exécuter :
SELECT COUNT(*) FROM client_demo.chart_of_accounts;
-- Devrait retourner > 0 (ex: 18 comptes)
```

---

### 3️⃣ Vérifier la Connexion

#### Dans le navigateur (Console DevTools - F12)
```javascript
// Copier-coller dans la console :
const { data, error } = await supabase
  .from("chart_of_accounts")
  .select("*")
  .limit(5);

console.log(data); // Devrait afficher 5 comptes
```

#### Rafraîchir Plan Comptable
```
1. Ouvrir : http://localhost:8084/console/plan-comptable
2. Devrait maintenant afficher les comptes de la base
3. Tester "Créer un compte", "Modifier", "Supprimer"
```

---

## 🛠️ Commandes Utiles

### Serveur de Développement
```bash
# Démarrer le serveur (si arrêté)
cd "C:\Users\hp\desktop\claude\os\edenfin-your-financial-garden"
npm run dev

# Le serveur démarre automatiquement sur :
# http://localhost:8080 (ou 8081, 8082, 8083, 8084 si occupé)
```

### Git
```bash
# Voir les changements récents
git log --oneline -5

# Voir le statut
git status

# Derniers commits :
# 5642cd5 - Intégration Supabase
# 725153e - Migration prototypes
```

### Supabase
```bash
# Test de connexion (dans console navigateur)
import { checkConnection } from "./src/lib/supabase";
const status = await checkConnection();
console.log(status);
```

---

## 📂 Structure des Fichiers

```
edenfin-your-financial-garden/
├── src/
│   ├── components/edenfin/        # 7 composants réutilisables
│   │   ├── smart-grid.tsx         # Grille CRUD
│   │   ├── entity-form-drawer.tsx # Formulaire modal
│   │   ├── rpc-panel.tsx          # Interface RPC
│   │   ├── journal-entry-form.tsx # Saisie écritures
│   │   ├── data-table.tsx         # Table lecture seule
│   │   ├── dashboard-kpis.tsx     # Composants dashboard
│   │   └── module-shell.tsx       # Shell des pages
│   │
│   ├── hooks/
│   │   └── use-supabase.ts        # 5 hooks React Query
│   │
│   ├── lib/
│   │   ├── supabase.ts            # Client Supabase
│   │   ├── formatters.ts          # Formatage OHADA
│   │   └── mock-data.ts           # Données de test
│   │
│   └── routes/_authenticated/console/
│       ├── dashboard.tsx          # Tableau de bord
│       ├── plan-comptable.tsx     # Plan comptable (✅ Supabase)
│       ├── rpc-functions.tsx      # Fonctions RPC (✅ Supabase)
│       └── comptabilite.tsx       # À migrer
│
├── EdenFin-JASPE-Archive-Complete/
│   ├── 02-migrations-sql/         # ⭐ SQL à exécuter dans Supabase
│   └── 03-prototypes-react/       # Prototypes archivés
│
├── MIGRATION_COMPLETE.md          # Rapport migration
├── COMPONENTS_GUIDE.md            # Guide composants
├── SUPABASE_INTEGRATION.md        # Guide Supabase
├── CURRENT_STATUS.md              # Statut détaillé
└── QUICK_START.md                 # Ce fichier
```

---

## 🎓 Exemples Rapides

### Créer un Compte (Plan Comptable)
```typescript
import { useSupabaseCreate } from "@/hooks/use-supabase";

const createAccount = useSupabaseCreate("accounts");

await createAccount.mutateAsync({
  account_number: "411000",
  account_label: "Clients",
  account_type: "ACTIF",
  class: 4,
  is_active: true,
});
```

### Récupérer des Données
```typescript
import { useSupabaseQuery } from "@/hooks/use-supabase";

const { data: accounts, isLoading } = useSupabaseQuery("accounts", {
  filters: { is_active: true },
  order: { column: "account_number", ascending: true },
  limit: 50,
});
```

### Exécuter une Fonction RPC
```typescript
import { useSupabaseRPC } from "@/hooks/use-supabase";

const calculatePayroll = useSupabaseRPC("rpc_calculate_payroll");

const result = await calculatePayroll.mutateAsync({
  p_period_id: 42,
  p_fiscal_year: 2026,
});
```

---

## ❓ FAQ Rapide

### Q: Le Plan Comptable affiche "Aucune donnée"
**R**: Normal, la base Supabase est vide. Exécutez les migrations SQL (voir section 2️⃣)

### Q: Le Dashboard affiche "Mode démonstration"
**R**: Normal, il utilise des données mock en attendant que vous créiez les tables `kpis` et `monthly_sales`

### Q: Comment changer de port ?
**R**: Le serveur Vite cherche automatiquement un port libre (8080 → 8084). Pour forcer un port :
```json
// vite.config.ts
server: {
  port: 3000, // Votre port préféré
}
```

### Q: Erreur "Table does not exist"
**R**: Vérifiez :
1. Les migrations SQL sont exécutées
2. Le schéma est correct (`client_demo` par défaut)
3. La connexion Supabase fonctionne

### Q: Comment désactiver le mode mock ?
**R**: Une fois les données Supabase chargées, le Dashboard et RPC Functions basculent automatiquement sur les vraies données.

---

## 🚨 Dépannage

### Serveur ne démarre pas
```bash
# Vérifier Node.js
node --version  # Doit être >= 18

# Réinstaller dépendances
npm install --legacy-peer-deps

# Relancer
npm run dev
```

### Erreur Supabase "Invalid JWT"
```bash
# Vérifier .env
cat .env | grep SUPABASE
# VITE_SUPABASE_URL et VITE_SUPABASE_PUBLISHABLE_KEY doivent être définis

# Redémarrer le serveur après modification .env
```

### Erreur "Module not found"
```bash
# Cache Vite corrompu
rm -rf node_modules/.vite
npm run dev
```

---

## 📞 Support

### Documentation
- `CURRENT_STATUS.md` - État détaillé du projet
- `SUPABASE_INTEGRATION.md` - Guide complet Supabase
- `COMPONENTS_GUIDE.md` - API des composants
- `MIGRATION_COMPLETE.md` - Rapport de migration

### Ressources
- GitHub Issues : https://github.com/jnembe777/edenfin-your-financial-garden/issues
- Supabase Docs : https://supabase.com/docs
- React Query Docs : https://tanstack.com/query/latest

---

## ✅ Checklist de Démarrage

- [x] Serveur de développement en cours (http://localhost:8084/)
- [x] Variables d'environnement configurées (.env)
- [x] Composants migrés et fonctionnels
- [x] Hooks Supabase créés
- [ ] **Migrations SQL exécutées dans Supabase** ⭐ FAIRE MAINTENANT
- [ ] Plan Comptable connecté avec vraies données
- [ ] Dashboard avec vraies données (après création vues)
- [ ] Tests de connexion validés

---

**🎯 Action Immédiate : Exécuter les 6 fichiers SQL dans Supabase pour débloquer toutes les fonctionnalités !**

---

*Guide créé le 3 juillet 2026*
*Version 2.0*
