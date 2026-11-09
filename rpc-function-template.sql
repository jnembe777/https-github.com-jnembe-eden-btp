-- ═══════════════════════════════════════════════════════════════════════
-- RPC Function Template — ERP OHADA
-- Pattern : Validation → Read Params → Process → Audit → Return
-- ═══════════════════════════════════════════════════════════════════════
--
-- RÈGLE CRITIQUE : Aucune constante métier en dur dans le code.
-- Tous les taux, seuils, durées doivent être lus depuis les tables
-- de paramétrage (contribution_rates, asset_categories, tax_rates, etc.)
--
-- Retour standardisé : jsonb avec TOUJOURS 'success' (boolean)
-- En cas de succès : + données métier + 'source' (table de paramétrage)
-- En cas d'erreur  : + 'error' (message en français)

CREATE OR REPLACE FUNCTION rpc_[nom_traitement](
  p_param1    integer,                -- Ex: mois
  p_param2    integer,                -- Ex: année
  p_company   uuid DEFAULT NULL       -- Tenant (optionnel si déduit du JWT)
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER                      -- S'exécute avec les droits du créateur
SET search_path = client_demo, common, public
AS $$
DECLARE
  v_company_id  uuid;
  v_count       integer := 0;
  v_total       numeric(15,2) := 0;
  v_result      jsonb;
  v_details     jsonb := '[]'::jsonb;
  v_source      text;
  -- Curseurs pour lecture paramétrage
  v_param       RECORD;
BEGIN
  -- ═══════════════════════════════════════════════════════════
  -- ① VALIDATION DES ENTRÉES
  -- ═══════════════════════════════════════════════════════════
  v_company_id := COALESCE(p_company, (auth.jwt() ->> 'company_id')::uuid);

  IF p_param1 IS NULL OR p_param2 IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Les paramètres mois et année sont obligatoires'
    );
  END IF;

  IF p_param1 < 1 OR p_param1 > 12 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Mois invalide : %s (attendu 1-12)', p_param1)
    );
  END IF;

  -- ═══════════════════════════════════════════════════════════
  -- ② LECTURE DES TABLES DE PARAMÉTRAGE
  --    ⚠️ JAMAIS de constantes en dur (0.101, 36, etc.)
  -- ═══════════════════════════════════════════════════════════
  v_source := '';

  -- Exemple : lecture des barèmes de cotisations
  /*
  FOR v_param IN
    SELECT * FROM contribution_rates
    WHERE effective <= make_date(p_param2, p_param1, 1)
    ORDER BY effective DESC
  LOOP
    -- v_param.emp_rate, v_param.empr_rate, v_param.ceiling
    v_source := format('contribution_rates (%s barèmes)', v_count);
  END LOOP;
  */

  -- Exemple : lecture des catégories d'immobilisations
  /*
  SELECT method, life_months INTO v_method, v_duree
  FROM asset_categories WHERE code = v_category_code;
  v_source := 'asset_categories';
  */

  -- ═══════════════════════════════════════════════════════════
  -- ③ TRAITEMENT TRANSACTIONNEL
  -- ═══════════════════════════════════════════════════════════

  -- Boucle de traitement principal
  /*
  FOR v_record IN SELECT * FROM [source_table] WHERE company_id = v_company_id AND ...
  LOOP
    -- Calculs métier utilisant les paramètres lus en ②
    -- INSERT / UPDATE dans les tables cibles

    v_count := v_count + 1;
    v_total := v_total + v_montant_calculé;

    -- Ajouter au détail
    v_details := v_details || jsonb_build_object(
      'id', v_record.id,
      'label', v_record.name,
      'amount', v_montant_calculé
    );
  END LOOP;
  */

  -- ═══════════════════════════════════════════════════════════
  -- ④ AUDIT TRAIL
  -- ═══════════════════════════════════════════════════════════
  INSERT INTO common.audit_log(action, entity, details, performed_by, company_id)
  VALUES (
    'RPC_[NOM_TRAITEMENT]',
    '[entity]',
    jsonb_build_object('period', format('%s/%s', p_param1, p_param2), 'count', v_count, 'total', v_total),
    auth.uid(),
    v_company_id
  );

  -- ═══════════════════════════════════════════════════════════
  -- ⑤ RETOUR STRUCTURÉ
  -- ═══════════════════════════════════════════════════════════
  RETURN jsonb_build_object(
    'success', true,
    'period', format('%s-%s', p_param2, lpad(p_param1::text, 2, '0')),
    'processed', v_count,
    'total', v_total,
    'details', v_details,
    'source', v_source
  );

EXCEPTION WHEN OTHERS THEN
  -- Log l'erreur mais ne bloque pas
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM,
    'detail', SQLSTATE
  );
END;
$$;

-- ── PERMISSIONS ──
-- Accessible à tous les utilisateurs authentifiés (RLS filtre les données)
GRANT EXECUTE ON FUNCTION rpc_[nom_traitement] TO authenticated;

-- ── TEST RAPIDE ──
-- SELECT rpc_[nom_traitement](2, 2026);
-- Attendu : {"success": true, "processed": N, "source": "table_name"}
