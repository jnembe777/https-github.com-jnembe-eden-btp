# Phase 13 — Tests Unitaires

## Objectif
Valider individuellement chaque fonction RPC, service JavaScript et composant UI.

## Tests PostgreSQL (pgTAP)

### Installation
```sql
CREATE EXTENSION IF NOT EXISTS pgtap;
```

### Structure de test RPC
```sql
BEGIN;
SELECT plan(5);

-- Test 1 : RPC retourne success=true
SELECT is(
  (rpc_calculate_payroll(2, 2026) ->> 'success')::boolean,
  true,
  'rpc_calculate_payroll retourne success'
);

-- Test 2 : Nombre d'employés traités correct
SELECT is(
  (rpc_calculate_payroll(2, 2026) ->> 'employees_processed')::integer,
  (SELECT count(*) FROM employees WHERE is_active = true)::integer,
  'Tous les employés actifs sont traités'
);

-- Test 3 : Cotisations salariales > 0
SELECT ok(
  (rpc_calculate_payroll(2, 2026) ->> 'cotSal')::numeric > 0,
  'Les cotisations salariales sont positives'
);

-- Test 4 : Source référencée
SELECT like(
  rpc_calculate_payroll(2, 2026) ->> 'source',
  'contribution_rates%',
  'La source contribution_rates est référencée'
);

-- Test 5 : Pas de constantes en dur (regression)
SELECT ok(
  NOT EXISTS(
    SELECT 1 FROM pg_proc WHERE proname = 'rpc_calculate_payroll'
    AND prosrc LIKE '%* 0.101%'
  ),
  'Aucune constante 0.101 codée en dur'
);

SELECT * FROM finish();
ROLLBACK;
```

### Matrice de tests RPC

| Fonction RPC | Tests positifs | Tests négatifs | Tests limites |
|-------------|---------------|---------------|---------------|
| rpc_calculate_payroll | Calcul correct, source ok | Mois invalide, aucun employé | Salaire=0, plafond dépassé |
| rpc_validate_journal_entry | Validation ok, status POSTED | Écriture déséquilibrée, période fermée | Montants=0 |
| rpc_generate_depreciation | Dotations correctes | Aucune immo active | Immo totalement amortie |
| rpc_close_fiscal_period | Clôture ok | Brouillons restants | Déjà clôturée |

## Tests JavaScript (Vitest)

### Configuration
```javascript
// vitest.config.js
export default {
  test: { environment: 'jsdom', globals: true, setupFiles: './tests/setup.js' }
};
```

### Tests de services
```javascript
// tests/services/PayrollService.test.js
import { describe, it, expect, vi } from 'vitest';
import { PayrollService } from '../../services/PayrollService';

describe('PayrollService', () => {
  const mockSupabase = {
    rpc: vi.fn(),
    schema: vi.fn(() => ({ from: vi.fn(() => ({ select: vi.fn() })) })),
  };

  it('calculatePayroll appelle le bon RPC avec les bons paramètres', async () => {
    mockSupabase.rpc.mockResolvedValue({ data: { success: true }, error: null });
    const service = new PayrollService(mockSupabase);
    const result = await service.calculatePayroll(2, 2026);
    expect(mockSupabase.rpc).toHaveBeenCalledWith('rpc_calculate_payroll', { p_month: 2, p_year: 2026 });
    expect(result.success).toBe(true);
  });

  it('gère les erreurs Supabase gracieusement', async () => {
    mockSupabase.rpc.mockResolvedValue({ data: null, error: { message: 'DB error' } });
    const service = new PayrollService(mockSupabase);
    await expect(service.calculatePayroll(2, 2026)).rejects.toThrow('PAYROLL_CALC_FAILED');
  });
});
```

### Tests de composants React
```javascript
// tests/components/SmartGrid.test.jsx
import { render, screen, fireEvent } from '@testing-library/react';
import SmartGrid from '../../components/SmartGrid';

describe('SmartGrid', () => {
  const config = {
    rowKey: 'id',
    columns: [
      { id: 'name', label: 'Nom', sortable: true, filterable: true, editable: true },
      { id: 'amount', label: 'Montant', type: 'currency', align: 'right' },
    ],
  };
  const data = [{ id: 1, name: 'Test', amount: 1000 }];

  it('affiche les données dans la grille', () => {
    render(<SmartGrid config={config} data={data} onAdd={() => {}} />);
    expect(screen.getByText('Test')).toBeInTheDocument();
  });

  it('appelle onAdd quand on clique Nouveau', () => {
    const onAdd = vi.fn();
    render(<SmartGrid config={config} data={data} onAdd={onAdd} />);
    fireEvent.click(screen.getByText('Nouveau'));
    expect(onAdd).toHaveBeenCalled();
  });

  it('filtre les données par recherche', () => {
    const data2 = [{ id: 1, name: 'Alpha', amount: 100 }, { id: 2, name: 'Beta', amount: 200 }];
    render(<SmartGrid config={config} data={data2} onAdd={() => {}} />);
    fireEvent.change(screen.getByPlaceholderText('Rechercher…'), { target: { value: 'Alpha' } });
    expect(screen.getByText('Alpha')).toBeInTheDocument();
    expect(screen.queryByText('Beta')).not.toBeInTheDocument();
  });
});
```

## Couverture minimale

| Couche | Couverture cible | Outil |
|--------|-----------------|-------|
| RPC PostgreSQL | 100% des fonctions | pgTAP |
| Services JS | 90% des méthodes publiques | Vitest |
| Composants React | 80% des interactions | @testing-library/react |
| Utilitaires (formatters) | 100% | Vitest |
