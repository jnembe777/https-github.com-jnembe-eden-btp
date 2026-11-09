## 📦 Guide des Composants EdenFin

Guide complet des composants React migrés et leur utilisation.

---

## 🎯 Composants Disponibles

### 1. **SmartGrid** - Grille de données CRUD

Grille configurable avec recherche, tri, pagination et actions CRUD.

**Fichier** : `src/components/edenfin/smart-grid.tsx`

**Usage** :
```typescript
import { SmartGrid, GridColumn } from "@/components/edenfin/smart-grid";

const columns: GridColumn<Account>[] = [
  { key: "account_number", label: "Numéro", type: "text" },
  { key: "account_label", label: "Libellé", type: "text" },
  { key: "is_active", label: "Actif", type: "boolean" },
];

<SmartGrid
  columns={columns}
  data={accounts}
  onCreate={() => setFormOpen(true)}
  onEdit={(row) => handleEdit(row)}
  onDelete={(row) => handleDelete(row)}
  showSearch
  showPagination
  pageSize={20}
/>
```

**Fonctionnalités** :
- ✅ Recherche full-text
- ✅ Tri multi-colonnes
- ✅ Pagination
- ✅ Actions CRUD (menu contextuel)
- ✅ Export CSV
- ✅ Types de colonnes : text, number, currency, date, badge, boolean, custom

---

### 2. **EntityFormDrawer** - Formulaire modal dynamique

Génère automatiquement un formulaire depuis la configuration des champs.

**Fichier** : `src/components/edenfin/entity-form-drawer.tsx`

**Usage** :
```typescript
import { EntityFormDrawer, FormFieldConfig } from "@/components/edenfin/entity-form-drawer";

const fields: FormFieldConfig[] = [
  {
    key: "account_number",
    label: "Numéro de compte",
    type: "text",
    required: true
  },
  {
    key: "account_label",
    label: "Libellé",
    type: "textarea"
  },
  {
    key: "balance",
    label: "Solde",
    type: "currency"
  },
  {
    key: "is_active",
    label: "Actif",
    type: "boolean",
    defaultValue: true
  },
];

<EntityFormDrawer
  open={formOpen}
  onClose={() => setFormOpen(false)}
  title="Ajouter un compte"
  fields={fields}
  onSubmit={async (data) => {
    await createAccount(data);
  }}
/>
```

**Types de champs supportés** :
- `text`, `textarea` - Texte
- `number`, `currency`, `percent` - Nombres
- `email` - Email avec validation
- `date` - Sélecteur de date
- `boolean` - Switch Oui/Non
- `select` - Liste déroulante

---

### 3. **RPCPanel** - Exécution de fonctions RPC

Panneau interactif pour exécuter des fonctions PostgreSQL RPC.

**Fichier** : `src/components/edenfin/rpc-panel.tsx`

**Usage** :
```typescript
import { RPCPanel, RPCFunction } from "@/components/edenfin/rpc-panel";

const rpcFunction: RPCFunction = {
  name: "rpc_calculate_payroll",
  label: "Calcul de paie",
  description: "Calcule les bulletins de paie mensuel",
  category: "Paie",
  parameters: [
    { name: "p_period_id", type: "number", label: "Période", required: true },
    { name: "p_fiscal_year", type: "number", label: "Année", defaultValue: 2026 },
  ],
};

<RPCPanel
  rpcFunction={rpcFunction}
  onExecute={async (params) => {
    const { data } = await supabase.rpc("rpc_calculate_payroll", params);
    return data;
  }}
  showResults
  showSQL
/>
```

**Fonctionnalités** :
- ✅ Interface graphique pour les paramètres
- ✅ Validation des champs requis
- ✅ Affichage des résultats JSON
- ✅ Génération SQL preview
- ✅ Gestion des erreurs

---

### 4. **JournalEntryForm** - Saisie d'écritures comptables

Formulaire multi-lignes pour la saisie d'écritures conformes SYSCOHADA.

**Fichier** : `src/components/edenfin/journal-entry-form.tsx`

**Usage** :
```typescript
import { JournalEntryForm } from "@/components/edenfin/journal-entry-form";

const journals = [
  { code: "VT", label: "Journal de vente" },
  { code: "AC", label: "Journal d'achat" },
  { code: "BQ", label: "Journal de banque" },
];

const accounts = [
  { account_number: "411000", account_label: "Clients" },
  { account_number: "701000", account_label: "Ventes" },
  // ... plan comptable
];

<JournalEntryForm
  journals={journals}
  accounts={accounts}
  onSubmit={async (data, isDraft) => {
    await createJournalEntry(data, isDraft);
  }}
/>
```

**Fonctionnalités** :
- ✅ Saisie multi-lignes (ajout/suppression)
- ✅ Autocomplete plan comptable
- ✅ Contrôle d'équilibre Débit = Crédit
- ✅ Enregistrement brouillon ou validation
- ✅ Calcul automatique des totaux

---

### 5. **DataTable** - Tableau de données en lecture seule

Table optimisée pour l'affichage de rapports sans édition.

**Fichier** : `src/components/edenfin/data-table.tsx`

**Usage** :
```typescript
import { DataTable, DataTableColumn } from "@/components/edenfin/data-table";

const columns: DataTableColumn[] = [
  {
    key: "account_number",
    label: "Compte",
    type: "text"
  },
  {
    key: "total_debit",
    label: "Débit",
    type: "currency",
    align: "right",
    showTotal: true,
    totalType: "sum"
  },
  {
    key: "total_credit",
    label: "Crédit",
    type: "currency",
    align: "right",
    showTotal: true,
    totalType: "sum"
  },
];

<DataTable
  columns={columns}
  data={balanceData}
  title="Balance générale"
  description="Exercice 2026"
  showFooter
  showExport
/>
```

**Fonctionnalités** :
- ✅ Affichage optimisé pour rapports
- ✅ Footer avec totaux automatiques
- ✅ Export CSV et impression
- ✅ Formats : sum, count, average

---

### 6. **Dashboard KPIs** - Composants de tableaux de bord

Composants pour créer des tableaux de bord élégants.

**Fichier** : `src/components/edenfin/dashboard-kpis.tsx`

**Usage** :
```typescript
import { KpiCard, KpiGrid, ModuleCard, StatusBadge } from "@/components/edenfin/dashboard-kpis";

<KpiGrid>
  <KpiCard
    label="CA mensuel"
    value={45200000}
    trend={12.5}
    unit="XAF"
    tone="success"
    icon={<DollarSign className="h-4 w-4" />}
  />
  <KpiCard
    label="Trésorerie"
    value={32100000}
    trend={-3.1}
    unit="XAF"
    tone="warning"
  />
</KpiGrid>

<ModuleCard
  title="Top 5 clients"
  description="Par chiffre d'affaires"
  action={<StatusBadge tone="success">5 clients</StatusBadge>}
>
  {/* Contenu */}
</ModuleCard>
```

**Composants** :
- `KpiCard` - Carte KPI avec tendance
- `KpiGrid` - Grille responsive (2-4 colonnes)
- `ModuleCard` - Carte de section
- `StatusBadge` - Badge coloré

---

## 📚 Utilitaires

### Formatters (`src/lib/formatters.ts`)

```typescript
import { formatXAF, formatDate, formatPercent } from "@/lib/formatters";

formatXAF(1250000);           // "1 250 000 XAF"
formatDate("2026-02-15");     // "15/02/2026"
formatPercent(0.125);         // "12,5%"
formatPeriod(2026, 2);        // "Février 2026"
formatAccount("601200");      // "601 200"
```

### Mock Data (`src/lib/mock-data.ts`)

```typescript
import { MOCK_KPI, MOCK_COA, MOCK_JOURNAL_ENTRIES } from "@/lib/mock-data";
```

---

## 🎨 Exemples de Pages

### Page avec SmartGrid
```typescript
// src/routes/_authenticated/console/plan-comptable.tsx
<SmartGrid
  columns={accountColumns}
  data={accounts}
  title="Plan comptable"
  onCreate={handleCreate}
  onEdit={handleEdit}
/>
```

### Page Dashboard
```typescript
// src/routes/_authenticated/console/dashboard.tsx
<KpiGrid>
  {MOCK_KPI.map(kpi => <KpiCard key={kpi.label} {...kpi} />)}
</KpiGrid>
```

### Page RPC
```typescript
// src/routes/_authenticated/console/rpc-functions.tsx
<RPCFunctionList
  functions={RPC_FUNCTIONS}
  onExecute={handleExecute}
/>
```

---

## 🔄 Workflow Typique

### 1. Liste + CRUD (SmartGrid + EntityFormDrawer)

```typescript
function AccountsPage() {
  const [formOpen, setFormOpen] = useState(false);
  const [editData, setEditData] = useState(null);

  return (
    <>
      <SmartGrid
        data={accounts}
        columns={columns}
        onCreate={() => setFormOpen(true)}
        onEdit={(row) => {
          setEditData(row);
          setFormOpen(true);
        }}
      />

      <EntityFormDrawer
        open={formOpen}
        onClose={() => {
          setFormOpen(false);
          setEditData(null);
        }}
        title={editData ? "Modifier" : "Créer"}
        fields={fields}
        initialData={editData}
        onSubmit={handleSave}
      />
    </>
  );
}
```

### 2. Rapport (DataTable)

```typescript
function BalancePage() {
  const { data } = useQuery({
    queryKey: ["balance"],
    queryFn: getTrialBalance,
  });

  return (
    <DataTable
      columns={balanceColumns}
      data={data?.accounts ?? []}
      title="Balance générale"
      showFooter
      showExport
    />
  );
}
```

### 3. Traitement (RPCPanel)

```typescript
function PayrollPage() {
  return (
    <RPCPanel
      rpcFunction={payrollRPC}
      onExecute={async (params) => {
        const { data } = await supabase.rpc("rpc_calculate_payroll", params);
        return data;
      }}
    />
  );
}
```

---

## 🎯 Checklist Migration

- [x] SmartGrid
- [x] EntityFormDrawer
- [x] RPCPanel
- [x] JournalEntryForm
- [x] DataTable
- [x] Dashboard KPIs
- [x] Formatters
- [x] Mock Data
- [ ] Connecter à Supabase réel
- [ ] Ajouter tests unitaires
- [ ] Documentation utilisateur

---

**Dernière mise à jour** : 1er juillet 2026
**Version** : 2.0
