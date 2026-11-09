# Phase 10 — Connexion DB ↔ Interfaces

## Objectif
Connecter les composants React (SmartGrid, Forms, DataTable) à Supabase via un DataAdapter et la couche de services métier.

## Architecture de connexion

```
┌─────────────────────────────────────────────────┐
│ UI Layer (React)                                │
│  SmartGrid ←→ GRID_REGISTRY                    │
│  EntityFormDrawer ←→ GRID_REGISTRY.columns      │
│  RPCDialog ←→ service.rpcMethod()               │
│  DataTable ←→ service.list() (read-only)        │
├─────────────────────────────────────────────────┤
│ Service Layer (JavaScript)                      │
│  BaseService.list/create/update/delete          │
│  PayrollService.calculatePayroll (→ RPC)        │
│  AssetService.generateDepreciation (→ RPC)      │
├─────────────────────────────────────────────────┤
│ DataAdapter Layer                               │
│  SupabaseDataAdapter (CRUD générique)           │
│  RPCAdapter (appels fonctions RPC)              │
├─────────────────────────────────────────────────┤
│ Supabase Client                                │
│  @supabase/supabase-js                          │
│  URL + anon_key (env vars)                      │
└─────────────────────────────────────────────────┘
```

## SupabaseDataAdapter

```javascript
class SupabaseDataAdapter {
  constructor(supabase, tableName, schema = 'client_demo') {
    this.sb = supabase;
    this.table = tableName;
    this.schema = schema;
  }

  async fetchAll(options = {}) {
    let q = this.sb.schema(this.schema).from(this.table).select(options.select || '*', { count: 'exact' });
    if (options.filters) options.filters.forEach(f => { q = q[f.op](f.col, f.val); });
    if (options.orderBy) q = q.order(options.orderBy.col, { ascending: options.orderBy.asc });
    if (options.range) q = q.range(options.range[0], options.range[1]);
    return q;
  }

  async insert(record) {
    return this.sb.schema(this.schema).from(this.table).insert(record).select().single();
  }

  async update(id, changes) {
    return this.sb.schema(this.schema).from(this.table).update(changes).eq('id', id).select().single();
  }

  async remove(id) {
    return this.sb.schema(this.schema).from(this.table).delete().eq('id', id);
  }
}
```

## Connexion SmartGrid ↔ Adapter

```javascript
// Hook personnalisé pour chaque grille
function useGridData(tableName, gridConfig) {
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);
  const adapter = useMemo(() => new SupabaseDataAdapter(supabase, tableName), [tableName]);

  const refresh = async () => {
    setLoading(true);
    const { data, error } = await adapter.fetchAll();
    if (!error) setData(data);
    setLoading(false);
  };

  const handleAdd = async (record) => {
    const { data: created, error } = await adapter.insert(record);
    if (!error) { setData(prev => [...prev, created]); return created; }
    throw error;
  };

  const handleUpdate = async (id, changes) => { /* ... */ };
  const handleDelete = async (id) => { /* ... */ };

  useEffect(() => { refresh(); }, []);

  return { data, loading, refresh, handleAdd, handleUpdate, handleDelete };
}
```

## Connexion RPCDialog ↔ Supabase

```javascript
const runRPC = async (functionName, params) => {
  const { data, error } = await supabase.rpc(functionName, params);
  if (error) return { success: false, error: error.message };
  return data; // Le RPC retourne déjà { success: true, ... }
};
```

## Real-time Subscriptions (optionnel, Phase avancée)

```javascript
// Abonnement temps réel sur une table
supabase
  .channel('entries-changes')
  .on('postgres_changes', { event: '*', schema: 'client_demo', table: 'journal_entries' },
    payload => { refreshGrid(); }
  )
  .subscribe();
```

## Mapping complet

| UI Component | Data Source | Adapter Method | Refresh Trigger |
|-------------|------------|----------------|-----------------|
| SmartGrid accounts | accounts | fetchAll/insert/update/remove | CRUD local |
| SmartGrid employees | employees | fetchAll/insert/update/remove | CRUD local |
| DataTable grand_livre | rpc_grand_livre | supabase.rpc() | Paramètres filtre |
| RPCDialog calcul_paie | rpc_calculate_payroll | supabase.rpc() | Bouton "Lancer" |
| EntityFormDrawer | adapté au contexte | insert ou update | Bouton "Enregistrer" |

## Gestion d'erreurs

Toute erreur Supabase est interceptée et transformée en message utilisateur français :
```javascript
const ERROR_MAP = {
  '23505': 'Cet enregistrement existe déjà (doublon)',
  '23503': 'Impossible de supprimer : des données liées existent',
  '42501': 'Vous n\'avez pas les droits pour cette opération',
  'PGRST301': 'Session expirée, veuillez vous reconnecter',
};
```
