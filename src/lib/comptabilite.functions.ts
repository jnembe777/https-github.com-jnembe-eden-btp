import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";

import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

const periodInput = z
  .object({
    fiscalYear: z.number().int().min(2000).max(2100).optional(),
    periodEnd: z.number().int().min(1).max(12).optional(),
    limit: z.number().int().min(1).max(500).optional(),
  })
  .optional();

export type JournalEntry = {
  id: number;
  entry_number: string;
  entry_date: string;
  journal_code: string;
  journal_label: string;
  reference: string | null;
  description: string;
  total_debit: number;
  total_credit: number;
  status: "DRAFT" | "POSTED" | "VALIDATED" | "CANCELLED";
};

export type JournalEntriesResult = {
  success: boolean;
  error?: string;
  fiscal_year: number;
  period_end: number;
  entries: JournalEntry[];
  total_debit: number;
  total_credit: number;
};

export type TrialBalanceRow = {
  account_number: string;
  account_label: string;
  account_type: string;
  total_debit: number;
  total_credit: number;
  balance: number;
};

export type TrialBalanceResult = {
  success: boolean;
  error?: string;
  fiscal_year: number;
  accounts: TrialBalanceRow[];
};

export const getJournalEntries = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .validator((data: unknown) => periodInput.parse(data) ?? {})
  .handler(async ({ data, context }): Promise<JournalEntriesResult> => {
    const { supabase } = context;
    const now = new Date();
    const { data: rpc, error } = await supabase.rpc("rpc_journal_entries", {
      p_fiscal_year: data.fiscalYear ?? now.getFullYear(),
      p_period_end: data.periodEnd ?? now.getMonth() + 1,
      p_limit: data.limit ?? 100,
    });
    if (error) throw new Error(error.message);
    return rpc as JournalEntriesResult;
  });

export const getTrialBalance = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .validator((data: unknown) => periodInput.parse(data) ?? {})
  .handler(async ({ data, context }): Promise<TrialBalanceResult> => {
    const { supabase } = context;
    const now = new Date();
    const { data: rpc, error } = await supabase.rpc("rpc_trial_balance", {
      p_fiscal_year: data.fiscalYear ?? now.getFullYear(),
      p_period_end: data.periodEnd ?? now.getMonth() + 1,
    });
    if (error) throw new Error(error.message);
    return rpc as TrialBalanceResult;
  });
