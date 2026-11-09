# Phase 1 — Cahier des Charges (CDC)

## Objectif
Formaliser le besoin client en un document contractuel définissant le périmètre, les contraintes et le planning du projet ERP.

## Structure du CDC

### 1. Contexte et enjeux
- Présentation de l'entreprise (secteur, taille, effectif, CA)
- Situation existante (outils actuels, douleurs, risques)
- Objectifs stratégiques de la solution

### 2. Périmètre fonctionnel
Définir les modules couverts par gamme :

```
JASPE (TPE): Comptabilité générale, Paie simplifiée, Trésorerie, Immobilisations, Tiers, Fiscal
RUBIS (PME): + Comptabilité analytique, Budgets, Multi-sociétés, Gestion commerciale
SAPHIR (ETI): + Consolidation, Audit, Workflow avancé, BI intégrée
ONYX (GE): + Multi-pays, IFRS, API ouvertes, Modules spécifiques
```

### 3. Exigences non fonctionnelles
- Performance : temps réponse < 2s pour 95% des opérations
- Disponibilité : 99.5% uptime
- Sécurité : RLS par tenant, chiffrement, audit trail
- Scalabilité : architecture multi-tenant Supabase
- Conformité : OHADA, CEMAC/UEMOA, Code du travail local

### 4. Contraintes techniques
- Stack imposé : React + Supabase (PostgreSQL 15+)
- Devise : XAF (CEMAC) ou XOF (UEMOA), pas de multi-devise en JASPE
- Langue : Français (interface et données)
- Navigateurs : Chrome, Firefox, Safari, Edge (dernières 2 versions)
- Mobile : responsive, pas d'app native en v1

### 5. Planning macro
Estimation par gamme :
- JASPE : 8 semaines (MVP) + 8 semaines (complet)
- RUBIS : +8 semaines sur base JASPE
- SAPHIR : +12 semaines sur base RUBIS
- ONYX : +16 semaines sur base SAPHIR

### 6. Livrables attendus
Liste exhaustive des documents et artefacts à produire à chaque phase.

## Processus de validation
1. Rédaction du CDC → revue interne
2. Présentation au client → collecte des amendements
3. Version finale signée → baseline du projet

## Checklist de complétude
- [ ] Tous les modules identifiés avec priorité (P0/P1/P2)
- [ ] Acteurs et rôles listés
- [ ] Volumétrie estimée (nb employés, écritures/mois, immobilisations)
- [ ] Interfaces externes identifiées (banques, DGI, CNSS)
- [ ] Critères d'acceptation définis
- [ ] Budget et ressources alloués
