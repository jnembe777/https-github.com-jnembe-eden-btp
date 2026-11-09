# Phase 14 — Tests des Processus

## Objectif
Valider les workflows complets de bout en bout (E2E), depuis l'action utilisateur jusqu'au résultat en base de données, en suivant les scénarios MCT.

## Différence avec les tests unitaires

| Aspect | Test unitaire (Phase 13) | Test processus (Phase 14) |
|--------|--------------------------|---------------------------|
| Portée | 1 fonction / 1 composant | 1 workflow complet |
| Données | Mocks | Base de données de test réelle |
| Validation | Entrée → Sortie | État initial → Actions → État final |
| Outil | pgTAP, Vitest | Playwright + pgTAP transactionnel |

## Scénarios de test par module

### COMPTA — Cycle écriture comptable
```
PROC-COMPTA-001 : Cycle de vie complet d'une écriture

Précondition : Exercice 2026 ouvert, période Février ouverte, journal VTE actif

Étapes :
1. Créer une écriture dans le journal VTE
   → POST rpc_create_journal_entry(journal:'VTE', date:'2026-02-15', lignes:[
       {compte:'411100', débit:1180000, crédit:0},
       {compte:'701000', débit:0, crédit:1000000},
       {compte:'443100', débit:0, crédit:180000}
     ])
   ✓ entry créée, status=DRAFT
   ✓ ∑ débits = ∑ crédits = 1.180.000

2. Valider l'écriture
   → POST rpc_validate_journal_entry(entry_id)
   ✓ status passe à POSTED
   ✓ audit_log contient l'action

3. Tenter de modifier l'écriture validée
   → UPDATE journal_entries SET description='...' WHERE id=entry_id
   ✓ REJETÉ (trigger ou RLS empêche la modification)

4. Contre-passer l'écriture
   → POST rpc_reverse_journal_entry(entry_id)
   ✓ Nouvelle écriture créée avec montants inversés
   ✓ Les deux écritures sont liées
```

### PAIE — Cycle paie mensuel
```
PROC-PAIE-001 : Calcul et validation paie complète

Précondition : 4 employés actifs, barèmes CNSS/CRF/CNAMGS configurés, période Février OPEN

Étapes :
1. Lancer le calcul de paie
   → POST rpc_calculate_payroll(month:2, year:2026)
   ✓ 4 bulletins générés
   ✓ Cotisations calculées depuis contribution_rates (pas de constantes)
   ✓ CNSS vieillesse salariale plafonnée à 1.500.000 XAF
   ✓ Net imposable = Brut - cotisations salariales

2. Vérifier un bulletin spécifique (EMP-001, salaire 1.200.000)
   ✓ CNSS vieillesse sal. = min(1.200.000, 1.500.000) × 2.5% = 30.000
   ✓ CRF sal. = 1.200.000 × 3.6% = 43.200
   ✓ CNAMGS = 1.200.000 × 1% = 12.000
   ✓ Total cot. salariales = 85.200
   ✓ Net imposable = 1.114.800

3. Valider les bulletins
   → POST rpc_validate_payslip(payslip_id) pour chaque bulletin
   ✓ Status = VALIDATED

4. Générer l'OD de paie
   → POST rpc_generate_payroll_entries(payrun_id)
   ✓ Écriture comptable créée dans journal PAIE
   ✓ Débit 641000 (charges personnel) = ∑ bruts
   ✓ Crédit 421000 (personnel, rémunérations) = ∑ nets
   ✓ Crédit 431000 (sécurité sociale) = ∑ cotisations
```

### IMMO — Cycle amortissement
```
PROC-IMMO-001 : Calcul amortissements mensuels

Précondition : 3 immobilisations actives, catégories configurées

Étapes :
1. Lancer le calcul des dotations
   → POST rpc_generate_depreciation(month:2, year:2026)
   ✓ 3 dotations calculées
   ✓ Toyota Hilux : 18.000.000 / 60 mois = 300.000/mois
   ✓ Ordinateurs : 3.200.000 / 36 mois = 88.889/mois
   ✓ Mobilier : 2.800.000 / 120 mois = 23.333/mois
   ✓ Source = asset_categories

2. Vérifier la mise à jour des VNC
   ✓ accum_depr incrémenté du montant de la dotation
   ✓ nbv = acquisition_value - accum_depr

3. Vérifier l'écriture comptable
   ✓ Débit 681000 (dotations) = ∑ dotations
   ✓ Crédit 280000 (amortissements) = ∑ dotations
```

### FISC — Clôture de période
```
PROC-FISC-001 : Clôture période comptable

Précondition : Période Janvier 2026 ouverte, aucun brouillon restant

Étapes :
1. Vérifier les prérequis de clôture
   ✓ Aucune écriture en status DRAFT dans la période
   ✓ Rapprochement bancaire terminé
   ✓ Amortissements calculés

2. Lancer la clôture
   → POST rpc_close_fiscal_period(period_id)
   ✓ Status période = CLOSED
   ✓ Aucune nouvelle écriture possible dans cette période

3. Tenter d'insérer une écriture dans la période fermée
   ✓ REJETÉ avec message explicite
```

## Automatisation avec Playwright

```javascript
// tests/e2e/payroll-cycle.spec.js
import { test, expect } from '@playwright/test';

test('Cycle complet de paie', async ({ page }) => {
  await page.goto('/app/paie/calcul');
  
  // Lancer le calcul
  await page.click('button:has-text("Lancer")');
  await page.waitForSelector('text=Succès');
  
  // Vérifier le résultat
  const result = await page.textContent('[data-testid="rpc-result"]');
  expect(result).toContain('"success": true');
  expect(result).toContain('"employees_processed": 4');
  
  // Vérifier que la source est bien les tables de paramétrage
  expect(result).toContain('contribution_rates');
});
```

## Rapport de validation

Pour chaque scénario de processus, produire :
- ✅ PASS / ❌ FAIL pour chaque assertion
- Captures d'écran des résultats UI
- Dump des données avant/après en base
- Temps d'exécution du processus complet
