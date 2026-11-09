# Phase 12 — Finalisation Backend

## Objectif
Compléter l'infrastructure Supabase : Edge Functions, cron jobs, storage, monitoring, optimisation.

## Edge Functions (Supabase)

Fonctions serverless pour traitements lourds ou intégrations externes :

| Fonction | Déclencheur | Description |
|----------|------------|-------------|
| `send-payslip-email` | Après validation bulletin | Envoie le PDF du bulletin par email |
| `generate-pdf-report` | À la demande | Génère Bilan/CR/TAFIRE en PDF |
| `import-bank-statement` | Upload fichier | Parse relevé bancaire (MT940/CSV) |
| `export-dgi` | Déclaration fiscale | Génère fichier XML pour la DGI |
| `scheduled-reminders` | Cron | Rappels échéances (clôtures, déclarations) |

### Structure d'une Edge Function
```typescript
// supabase/functions/send-payslip-email/index.ts
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const { payslip_id } = await req.json()
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )
  // Logique métier...
  return new Response(JSON.stringify({ success: true }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

## Cron Jobs (pg_cron ou Supabase Scheduler)

```sql
-- Clôture automatique des périodes de paie à J+5 du mois suivant
SELECT cron.schedule('close-pay-periods', '0 2 5 * *',
  $$SELECT rpc_auto_close_pay_periods()$$);

-- Rappel clôture comptable à J-3 de la fin du mois
SELECT cron.schedule('remind-closing', '0 8 28 * *',
  $$SELECT rpc_send_closing_reminders()$$);

-- Nettoyage audit_log > 2 ans
SELECT cron.schedule('clean-audit', '0 3 1 1 *',
  $$DELETE FROM common.audit_log WHERE created_at < NOW() - INTERVAL '2 years'$$);
```

## Storage Buckets

```sql
-- Bucket pour les pièces justificatives
INSERT INTO storage.buckets (id, name, public) VALUES ('attachments', 'attachments', false);

-- Bucket pour les rapports générés
INSERT INTO storage.buckets (id, name, public) VALUES ('reports', 'reports', false);

-- Politique RLS storage
CREATE POLICY "tenant_attachments" ON storage.objects FOR ALL
  USING (bucket_id = 'attachments' AND (storage.foldername(name))[1] = auth.jwt() ->> 'company_id');
```

## Optimisations de performance

### Vues matérialisées pour rapports
```sql
CREATE MATERIALIZED VIEW mv_trial_balance AS
SELECT account_number, account_label, account_type,
  SUM(debit) as total_debit, SUM(credit) as total_credit,
  SUM(debit) - SUM(credit) as balance
FROM journal_entry_lines jel
JOIN accounts a ON jel.account_id = a.id
JOIN journal_entries je ON jel.entry_id = je.id
WHERE je.status = 'POSTED'
GROUP BY account_number, account_label, account_type;

-- Rafraîchissement périodique
SELECT cron.schedule('refresh-balance', '*/15 * * * *',
  $$REFRESH MATERIALIZED VIEW CONCURRENTLY mv_trial_balance$$);
```

### Connection pooling
- Supabase utilise PgBouncer par défaut
- Pour les Edge Functions, utiliser le pool transactionnel (port 6543)
- Pour les migrations, utiliser la connexion directe (port 5432)

## Monitoring

### Métriques à surveiller
- Temps de réponse moyen des RPC (< 500ms)
- Nombre de connexions actives (< 80% du pool)
- Taille de la base de données
- Nombre d'erreurs 4xx/5xx par heure
- Utilisation storage (quotas Supabase)

### Alertes
- RPC > 2s → alerte performance
- Erreur RLS → alerte sécurité
- Espace disque > 80% → alerte capacité

## Hardening de sécurité
- Désactiver l'accès public aux tables (tout passe par RPC ou policies RLS)
- Activer la double authentification pour les comptes ADMIN
- Rotation des clés API tous les 90 jours
- Configurer les CORS pour le domaine de production uniquement
- Rate limiting sur les endpoints publics
