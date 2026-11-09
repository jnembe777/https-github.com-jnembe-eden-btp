
-- Wrapper RPCs in public schema so PostgREST can call them.
-- They proxy into client_demo while enforcing tenant access.

CREATE OR REPLACE FUNCTION public.rpc_journal_entries(
  p_fiscal_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INT,
  p_period_end INT DEFAULT 12,
  p_limit INT DEFAULT 100
)
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, client_demo, sys
AS $$
BEGIN
  IF NOT client_demo.user_has_access() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Accès refusé');
  END IF;

  RETURN (
    SELECT jsonb_build_object(
      'success', true,
      'fiscal_year', p_fiscal_year,
      'period_end', p_period_end,
      'entries', COALESCE(jsonb_agg(row_data ORDER BY entry_date DESC, entry_number DESC), '[]'::jsonb),
      'total_debit', COALESCE(SUM(td), 0),
      'total_credit', COALESCE(SUM(tc), 0)
    )
    FROM (
      SELECT
        je.entry_date,
        je.entry_number,
        je.total_debit AS td,
        je.total_credit AS tc,
        jsonb_build_object(
          'id', je.id,
          'entry_number', je.entry_number,
          'entry_date', je.entry_date,
          'journal_code', j.journal_code,
          'journal_label', j.journal_label,
          'reference', je.reference,
          'description', je.description,
          'total_debit', je.total_debit,
          'total_credit', je.total_credit,
          'status', je.status
        ) AS row_data
      FROM client_demo.journal_entries je
      JOIN client_demo.journals j ON j.id = je.journal_id
      JOIN client_demo.fiscal_periods fp ON fp.id = je.fiscal_period_id
      WHERE fp.fiscal_year = p_fiscal_year
        AND fp.period_number <= p_period_end
      ORDER BY je.entry_date DESC, je.entry_number DESC
      LIMIT GREATEST(p_limit, 1)
    ) sub
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_trial_balance(
  p_fiscal_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INT,
  p_period_end INT DEFAULT 12
)
RETURNS JSONB
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, client_demo, sys
AS $$
  SELECT client_demo.rpc_trial_balance(p_fiscal_year, p_period_end);
$$;

GRANT EXECUTE ON FUNCTION
  public.rpc_journal_entries(INT, INT, INT),
  public.rpc_trial_balance(INT, INT)
TO authenticated, service_role;
