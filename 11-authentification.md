# Phase 11 — Module d'Authentification

## Objectif
Implémenter l'authentification, l'autorisation (RBAC) et l'isolation des données (RLS) via Supabase Auth.

## Architecture Auth

```
Supabase Auth (JWT)
  ├── Inscription / Connexion (email + password)
  ├── JWT contient : user_id, email, app_metadata.company_id, app_metadata.role
  ├── RLS policies lisent auth.uid() et auth.jwt()
  └── Middleware React vérifie session avant chaque route
```

## Rôles RBAC

| Rôle | Code | Permissions |
|------|------|-------------|
| Administrateur | ADMIN | Tout : config, users, toutes données |
| Comptable | COMPTABLE | COMPTA (CRUD), FISC (lecture), IMMO (lecture) |
| Responsable paie | RH_PAIE | PAIE (CRUD), employés (CRUD) |
| Trésorier | TRESORIER | TRESO (CRUD), banques (CRUD) |
| Directeur | DIRECTEUR | Tout en lecture, validation |
| Auditeur | AUDITEUR | Tout en lecture seule, audit_log |

## Configuration Supabase Auth

```sql
-- Stocker le rôle et company dans app_metadata lors de l'inscription
UPDATE auth.users SET raw_app_meta_data = jsonb_set(
  raw_app_meta_data, '{role}', '"COMPTABLE"'
) WHERE id = 'user-uuid';

UPDATE auth.users SET raw_app_meta_data = jsonb_set(
  raw_app_meta_data, '{company_id}', '"company-uuid"'
) WHERE id = 'user-uuid';
```

## Row Level Security (RLS)

### Patron d'isolation par tenant
```sql
-- Activer RLS sur chaque table client
ALTER TABLE client_demo.accounts ENABLE ROW LEVEL SECURITY;

-- Politique : un utilisateur ne voit que les données de sa company
CREATE POLICY "tenant_isolation" ON client_demo.accounts
  FOR ALL
  USING (company_id = (auth.jwt() ->> 'company_id')::uuid)
  WITH CHECK (company_id = (auth.jwt() ->> 'company_id')::uuid);
```

### Patron de contrôle par rôle
```sql
-- Lecture pour tous les rôles authentifiés
CREATE POLICY "read_accounts" ON client_demo.accounts
  FOR SELECT
  USING (auth.role() = 'authenticated');

-- Écriture seulement pour ADMIN et COMPTABLE
CREATE POLICY "write_accounts" ON client_demo.accounts
  FOR INSERT
  USING ((auth.jwt() -> 'app_metadata' ->> 'role') IN ('ADMIN', 'COMPTABLE'));

CREATE POLICY "update_accounts" ON client_demo.accounts
  FOR UPDATE
  USING ((auth.jwt() -> 'app_metadata' ->> 'role') IN ('ADMIN', 'COMPTABLE'));

-- Suppression seulement pour ADMIN
CREATE POLICY "delete_accounts" ON client_demo.accounts
  FOR DELETE
  USING ((auth.jwt() -> 'app_metadata' ->> 'role') = 'ADMIN');
```

## Middleware React

```javascript
// AuthProvider.jsx
function AuthProvider({ children }) {
  const [session, setSession] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setLoading(false);
    });
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session);
    });
    return () => subscription.unsubscribe();
  }, []);

  if (loading) return <LoadingScreen />;
  if (!session) return <LoginPage />;
  return <AuthContext.Provider value={session}>{children}</AuthContext.Provider>;
}

// Hook de vérification des droits
function usePermission(requiredRole) {
  const session = useAuth();
  const userRole = session?.user?.app_metadata?.role;
  const HIERARCHY = { ADMIN: 5, DIRECTEUR: 4, COMPTABLE: 3, RH_PAIE: 3, TRESORIER: 3, AUDITEUR: 1 };
  return HIERARCHY[userRole] >= HIERARCHY[requiredRole];
}
```

## Pages d'authentification
- **Login** : email + mot de passe, lien "mot de passe oublié"
- **Reset password** : envoi email via Supabase
- **Profil** : changement mot de passe, infos utilisateur
- **Admin > Utilisateurs** : CRUD utilisateurs avec attribution de rôle (ADMIN seulement)

## Audit de sécurité
- Chaque action sensible est loguée dans `audit_log`
- Les tentatives de connexion échouées sont tracées
- Les fonctions RPC `SECURITY DEFINER` s'exécutent avec les droits du créateur mais vérifient auth.uid()
