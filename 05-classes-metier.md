# Phase 5 — Classes Métier

## Objectif
Créer une couche service JavaScript/TypeScript qui encapsule les appels Supabase (CRUD + RPC) et expose une API propre aux composants UI.

## Architecture des services

```
services/
├── SupabaseClient.js       — Singleton Supabase init
├── BaseService.js          — Classe abstraite CRUD générique
├── AccountService.js       — Plan comptable
├── JournalService.js       — Journaux et écritures
├── PartnerService.js       — Clients et fournisseurs
├── EmployeeService.js      — Registre du personnel
├── PayrollService.js       — Calcul paie (appel RPC)
├── AssetService.js         — Immobilisations et amortissements
├── TreasuryService.js      — Trésorerie et rapprochement
├── FiscalService.js        — Déclarations fiscales
└── DashboardService.js     — KPI et reporting
```

## BaseService — Patron CRUD générique

```javascript
class BaseService {
  constructor(tableName, schema = 'client_demo') {
    this.table = tableName;
    this.schema = schema;
  }

  async list(filters = {}, options = {}) {
    let query = supabase.schema(this.schema).from(this.table).select(options.select || '*');
    Object.entries(filters).forEach(([k, v]) => { query = query.eq(k, v); });
    if (options.orderBy) query = query.order(options.orderBy, { ascending: options.asc ?? true });
    if (options.limit) query = query.limit(options.limit);
    if (options.offset) query = query.range(options.offset, options.offset + (options.limit || 50) - 1);
    const { data, error, count } = await query;
    if (error) throw new ServiceError('LIST_FAILED', error.message);
    return { data, count };
  }

  async getById(id) { /* ... */ }
  async create(record) { /* ... with validation */ }
  async update(id, changes) { /* ... with optimistic locking */ }
  async delete(id) { /* ... soft delete preferred */ }
}
```

## Services métier — Encapsulation RPC

```javascript
class PayrollService extends BaseService {
  constructor() { super('employees'); }

  async calculatePayroll(month, year) {
    const { data, error } = await supabase.rpc('rpc_calculate_payroll', {
      p_month: month, p_year: year
    });
    if (error) throw new ServiceError('PAYROLL_CALC_FAILED', error.message);
    return data;
  }

  async validatePayslip(payslipId) {
    return supabase.rpc('rpc_validate_payslip', { p_payslip_id: payslipId });
  }

  async generatePayrollEntries(payrunId) {
    return supabase.rpc('rpc_generate_payroll_entries', { p_payrun_id: payrunId });
  }
}
```

## Mapping Service ↔ GRID_REGISTRY

Chaque entité SmartGrid doit avoir un service associé :

| GRID_REGISTRY key | Service | Table | Opérations |
|-------------------|---------|-------|------------|
| accounts | AccountService | accounts | CRUD |
| employees | EmployeeService | employees | CRUD |
| partners | PartnerService | partners | CRUD |
| payroll_rubrics | PayrollService | payroll_rubrics | CRUD |
| contribution_rates | PayrollService | contribution_rates | CRUD |
| absence_types | PayrollService | absence_types | CRUD |
| asset_categories | AssetService | asset_categories | CRUD |
| fixed_assets | AssetService | fixed_assets | CRUD |
| entries | JournalService | journal_entries | CRUD + RPC |

## Règles de conception
1. **Chaque service est testable isolément** (injection du client Supabase)
2. **Validation côté service** avant appel DB (fail fast, messages clairs en français)
3. **Gestion d'erreur structurée** : `ServiceError(code, message, details)`
4. **Pas de logique métier dans les composants UI** — tout passe par les services
5. **Les services RPC retournent toujours** `{ success: boolean, ...data }` — convention uniforme
