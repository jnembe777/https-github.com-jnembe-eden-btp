# Phase 15 — Déploiement & Livraison

## Objectif
Mettre en production, documenter et former les utilisateurs.

## Checklist pré-déploiement

### Base de données
- [ ] Toutes les migrations exécutées dans l'ordre (00 → 09+)
- [ ] Seed data chargé (plan comptable, barèmes, catégories)
- [ ] RLS activé sur toutes les tables client
- [ ] Fonctions RPC testées individuellement
- [ ] Index de performance créés
- [ ] Backup automatique configuré

### Backend
- [ ] Edge Functions déployées et testées
- [ ] Cron jobs planifiés
- [ ] Storage buckets créés avec politiques RLS
- [ ] Variables d'environnement configurées
- [ ] CORS configuré pour le domaine de production

### Frontend
- [ ] Build de production sans erreurs (`npm run build`)
- [ ] Variables d'environnement production (VITE_SUPABASE_URL, etc.)
- [ ] Tests E2E passent en environnement staging
- [ ] Thème clair et sombre fonctionnels
- [ ] Responsive vérifié (tablette minimum)

### Sécurité
- [ ] Aucune clé API exposée côté client (seulement anon key)
- [ ] service_role_key uniquement dans les Edge Functions
- [ ] Rate limiting configuré
- [ ] Headers de sécurité (CSP, HSTS, X-Frame-Options)

## Procédure de déploiement

### 1. Environnement staging
```bash
# Créer projet Supabase staging
supabase link --project-ref [staging-ref]
supabase db push  # Applique les migrations

# Déployer le frontend sur Vercel/Netlify (preview)
npm run build
vercel deploy --previewe
```

### 2. Validation staging
- Exécuter les tests de processus (Phase 14) sur staging
- Validation fonctionnelle par le client
- Test de charge basique (50 utilisateurs simultanés)

### 3. Production
```bash
# Basculer sur le projet production
supabase link --project-ref [prod-ref]
supabase db push

# Edge Functions
supabase functions deploy send-payslip-email
supabase functions deploy generate-pdf-report

# Frontend en production
vercel deploy --prod
```

### 4. Post-déploiement
- Créer le compte ADMIN initial
- Charger les données de démarrage du client (exercice, plan comptable personnalisé)
- Vérifier les cron jobs
- Monitorer les métriques pendant 48h

## Livrables de documentation

| Document | Audience | Format |
|----------|----------|--------|
| Guide utilisateur | Utilisateurs finaux | PDF / aide en ligne |
| Manuel administrateur | Admin système | MD dans le repo |
| Documentation technique | Développeurs | MD + diagrammes Mermaid |
| Guide de déploiement | DevOps | MD step-by-step |
| Catalogue des RPC | Développeurs | MD avec exemples d'appel |
| Matrice de traçabilité | Chef de projet | MD (CDC→SFG→MCT→RPC→UI) |

## Formation

### Session 1 : Prise en main (2h)
- Navigation dans l'interface
- Thème clair / sombre
- Recherche et filtres dans les grilles
- Création et modification d'enregistrements

### Session 2 : Comptabilité (3h)
- Plan comptable OHADA
- Saisie d'écritures
- Validation et lettrage
- Clôture de période

### Session 3 : Paie (3h)
- Configuration des rubriques et barèmes
- Cycle mensuel de paie
- Lecture d'un bulletin
- Génération de l'OD de paie

### Session 4 : Administration (2h)
- Gestion des utilisateurs et rôles
- Configuration des paramètres
- Sauvegarde et restauration
- Résolution des problèmes courants

## Maintenance

### SLA proposé
- Correction bugs critiques : 24h
- Correction bugs majeurs : 72h
- Évolutions mineures : sprint suivant
- Mise à jour législative (nouveaux taux) : 48h via tables de paramétrage

### Mises à jour réglementaires
Les tables de paramétrage permettent la mise à jour sans redéploiement :
- Nouveaux taux CNSS → UPDATE contribution_rates
- Nouveau seuil d'imposition → UPDATE tax_rates
- Nouvelle catégorie d'immobilisation → INSERT asset_categories
- Nouveau type d'absence → INSERT absence_types
