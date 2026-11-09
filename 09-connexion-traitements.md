# Phase 9 — Connexion DB ↔ Traitements (RPC)

## Objectif
Implémenter les fonctions RPC PostgreSQL qui exécutent les traitements métier identifiés au MCT, en lisant systématiquement les tables de paramétrage.

## Catalogue RPC JASPE

| ID | Fonction RPC | MCT | Entrée | Sortie |
|----|-------------|-----|--------|--------|
| T1 | `rpc_create_journal_entry` | Création écriture | journal, date, lignes[] | entry_id |
| T2 | `rpc_validate_journal_entry` | Validation écriture | entry_id | status=POSTED |
| T3 | `rpc_auto_lettrage` | Lettrage automatique | account_id | nb paires lettrées |
| T4 | `rpc_auto_reconcile_bank` | Rapprochement bancaire | bank_id, period | nb rapprochées |
| T5 | `rpc_calculate_payroll` | Calcul paie mensuel | month, year | bulletins[] |
| T6 | `rpc_validate_payslip` | Validation bulletin | payslip_id | status=VALIDATED |
| T7 | `rpc_generate_payroll_entries` | OD de paie | payrun_id | entry_ids[] |
| T8 | `rpc_generate_depreciation` | Amortissements mensuels | month, year | dotations[] |
| T9 | `rpc_generate_tva_declaration` | Déclaration TVA | period_id | declaration |
| T10 | `rpc_close_fiscal_period` | Clôture période | period_id | status=CLOSED |
| T11 | `rpc_cash_forecast` | Prévision trésorerie | horizon_months | projections[] |
| T12 | `rpc_financial_ratios` | Ratios financiers | year | ratios{} |
| T13 | `rpc_dashboard_kpi` | KPI tableau de bord | — | kpi{} |

## Patron RPC standard

```sql
CREATE OR REPLACE FUNCTION rpc_[name](
  p_param1 type,
  p_param2 type
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = client_demo, common, public
AS $$
DECLARE
  v_result jsonb;
  v_count integer := 0;
BEGIN
  -- ① VALIDATION
  IF p_param1 IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Paramètre obligatoire');
  END IF;

  -- ② LECTURE PARAMÉTRAGE (jamais de constantes en dur)
  FOR v_rate IN SELECT * FROM contribution_rates
    WHERE effective <= CURRENT_DATE ORDER BY effective DESC
  LOOP
    -- Utiliser v_rate.emp_rate, v_rate.empr_rate, v_rate.ceiling
  END LOOP;

  -- ③ TRAITEMENT TRANSACTIONNEL
  INSERT INTO target_table (...) VALUES (...);
  UPDATE related_table SET ... WHERE ...;
  v_count := v_count + 1;

  -- ④ AUDIT
  INSERT INTO common.audit_log(action, entity, entity_id, details, performed_by)
  VALUES ('RPC_NAME', 'entity', v_id, v_result, auth.uid());

  -- ⑤ RETOUR STRUCTURÉ
  RETURN jsonb_build_object(
    'success', true,
    'processed', v_count,
    'source', 'table_name (N enregistrements)'
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;
```

## Règle anti-constantes

**INTERDIT** :
```sql
v_cot_sal := v_brut * 0.101;  -- ❌ Taux codé en dur
v_duree := 36;                  -- ❌ Durée codée en dur
```

**OBLIGATOIRE** :
```sql
FOR v_rate IN SELECT * FROM contribution_rates WHERE ... LOOP
  v_base := LEAST(v_brut, COALESCE(v_rate.ceiling, v_brut));
  v_cot_sal := v_cot_sal + ROUND(v_base * v_rate.emp_rate, 2);
END LOOP;

SELECT life_months INTO v_duree FROM asset_categories WHERE code = v_cat_code;
```

## Matrice de traçabilité

Chaque ligne doit relier :
```
CU-[id] (cas d'usage SFG)
  → RG-[id] (règle métier)
    → T[n] (traitement MCT)
      → rpc_[name] (fonction PostgreSQL)
        → [ServiceClass].[method] (classe JS)
          → [Component] (composant UI)
```

Livrable : fichier MATRICE_TRACABILITE.md avec tableau complet.

## Tests de chaque RPC

Après création, chaque RPC doit être testée :
```sql
-- Test direct dans SQL Editor
SELECT rpc_calculate_payroll(2, 2026);
-- Vérifier : success=true, details non vide, source renseignée
```
