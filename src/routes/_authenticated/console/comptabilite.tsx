/**
 * Page Comptabilité — Niveau T (Transactionnel) + P (Processus partiel)
 * Tables: journal_entries, journals, chart_of_accounts, fiscal_periods
 * RPC: rpc_create_journal_entry, rpc_trial_balance
 * Connectée à Supabase (remplace les server functions avec rpc_journal_entries inexistante)
 */

import { useState, useMemo } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { createFileRoute } from "@tanstack/react-router";
import { BookOpen, Plus, Search, Filter, Download, Loader2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import {
  KpiCard,
  KpiGrid,
  ModuleCard,
  ModuleShell,
  StatusBadge,
} from "@/components/edenfin/module-shell";
import {
  JournalEntryForm,
  type JournalEntryFormData,
} from "@/components/edenfin/journal-entry-form";
import { formatXAF, formatDate, formatPeriod } from "@/lib/formatters";
import { supabase } from "@/lib/supabase";
import { useSupabaseQuery } from "@/hooks/use-supabase";
import { useToast } from "@/hooks/use-toast";
import type { TrialBalanceRow } from "@/lib/comptabilite.functions";

export const Route = createFileRoute("/_authenticated/console/comptabilite")({
  ssr: false,
  component: ComptabilitePage,
});

type EntryStatus = "DRAFT" | "POSTED" | "VALIDATED" | "CANCELLED";

const STATUS_LABEL: Record<EntryStatus, string> = {
  DRAFT: "Brouillard",
  POSTED: "Validée",
  VALIDATED: "Lettrée",
  CANCELLED: "Annulée",
};

const STATUS_TONE: Record<
  EntryStatus,
  "success" | "info" | "warning" | "default"
> = {
  DRAFT: "warning",
  POSTED: "success",
  VALIDATED: "info",
  CANCELLED: "default",
};

function ComptabilitePage() {
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const [formOpen, setFormOpen] = useState(false);
  const [entryCreating, setEntryCreating] = useState(false);
  const [searchTerm, setSearchTerm] = useState("");

  const period = useMemo(() => {
    const now = new Date();
    return { fiscalYear: now.getFullYear(), periodEnd: now.getMonth() + 1 };
  }, []);

  const periodStart = `${period.fiscalYear}-${String(period.periodEnd).padStart(2, "0")}-01`;
  const periodEndDate = new Date(period.fiscalYear, period.periodEnd, 0);
  const periodEndStr = `${period.fiscalYear}-${String(period.periodEnd).padStart(2, "0")}-${String(periodEndDate.getDate()).padStart(2, "0")}`;

  // Journal entries — requête Supabase directe (RLS: user_has_access())
  const entriesQuery = useQuery({
    queryKey: ["journal-entries", period],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("journal_entries")
        .select("*, journals(code, name)")
        .gte("entry_date", periodStart)
        .lte("entry_date", periodEndStr)
        .is("deleted_at", null)
        .order("entry_date", { ascending: false })
        .limit(100);
      if (error) throw new Error(error.message);
      return data ?? [];
    },
  });

  // Balance générale — RPC rpc_trial_balance (SECURITY DEFINER, authentifié requis)
  const balanceQuery = useQuery({
    queryKey: ["trial-balance", period],
    queryFn: async () => {
      const { data, error } = await supabase.rpc("rpc_trial_balance", {
        p_fiscal_year: period.fiscalYear,
        p_period_end: period.periodEnd,
      });
      if (error) throw new Error(error.message);
      return (data as { accounts: TrialBalanceRow[] }) ?? { accounts: [] };
    },
  });

  // Journaux — sans RLS, pour les listes déroulantes du formulaire
  const { data: journalsData = [] } = useSupabaseQuery<{
    id: number;
    code: string;
    name: string;
    is_active: boolean;
  }>("journals", {
    filters: { is_active: true },
    order: { column: "code", ascending: true },
  });

  // Plan comptable — sans RLS, pour l'autocomplete du formulaire
  const { data: accountsData = [] } = useSupabaseQuery<{
    id: number;
    account_number: string;
    account_label: string;
  }>("accounts", {
    filters: { is_active: true },
    order: { column: "account_number", ascending: true },
  });

  // Agrégats
  const entries = useMemo(() => {
    return (entriesQuery.data ?? []).map((e: any) => ({
      ...e,
      journal_code: (e.journals as any)?.code ?? String(e.journal_id),
      journal_label: (e.journals as any)?.name ?? "",
    }));
  }, [entriesQuery.data]);

  const filteredEntries = useMemo(() => {
    if (!searchTerm) return entries;
    const q = searchTerm.toLowerCase();
    return entries.filter(
      (e) =>
        e.entry_number?.toLowerCase().includes(q) ||
        e.description?.toLowerCase().includes(q) ||
        e.reference?.toLowerCase().includes(q)
    );
  }, [entries, searchTerm]);

  const totalDebit = entries.reduce(
    (sum: number, e: any) => sum + Number(e.total_debit ?? 0),
    0
  );
  const totalCredit = entries.reduce(
    (sum: number, e: any) => sum + Number(e.total_credit ?? 0),
    0
  );
  const balanced = totalDebit === totalCredit && totalDebit > 0;

  const balanceRows = (balanceQuery.data?.accounts ?? []) as TrialBalanceRow[];
  const drafts = entries.filter((e: any) => e.status === "DRAFT").length;
  const toReconcile = entries.filter((e: any) => e.status === "POSTED").length;

  const periodLabel = formatPeriod(period.fiscalYear, period.periodEnd);

  const isAuthError =
    entriesQuery.error?.message?.includes("permission") ||
    entriesQuery.error?.message?.includes("JWT") ||
    entriesQuery.error?.message?.includes("auth") ||
    entriesQuery.error?.message?.includes("row-level") ||
    (entriesQuery.isError && entries.length === 0);

  // Soumission du formulaire → rpc_create_journal_entry
  const handleEntrySubmit = async (
    formData: JournalEntryFormData,
    _isDraft: boolean
  ) => {
    setEntryCreating(true);
    try {
      const journal = journalsData.find((j) => j.code === formData.journal_code);
      if (!journal) throw new Error("Journal introuvable : " + formData.journal_code);

      const lines = formData.lines.map((line) => {
        const account = accountsData.find(
          (a) => a.account_number === line.account_number
        );
        if (!account)
          throw new Error(`Compte ${line.account_number} introuvable dans le plan comptable`);
        return {
          account_id: account.id,
          description: line.description || formData.description,
          debit: line.debit,
          credit: line.credit,
        };
      });

      const { data, error } = await supabase.rpc("rpc_create_journal_entry", {
        p_journal_id: journal.id,
        p_entry_date: formData.entry_date,
        p_description: formData.description,
        p_reference: formData.reference || null,
        p_lines: lines,
      });

      if (error) throw new Error(error.message);
      const result = data as any;
      if (result && result.success === false)
        throw new Error(result.error ?? "Erreur RPC inconnue");

      toast({
        title: "Écriture créée",
        description: `Écriture ${result?.entry_number ?? ""} enregistrée avec succès.`,
      });
      setFormOpen(false);
      queryClient.invalidateQueries({ queryKey: ["journal-entries"] });
      queryClient.invalidateQueries({ queryKey: ["trial-balance"] });
    } catch (err: any) {
      toast({
        title: "Erreur de saisie",
        description: err.message,
        variant: "destructive",
      });
      throw err;
    } finally {
      setEntryCreating(false);
    }
  };

  const journalOptions = journalsData.map((j) => ({
    code: j.code,
    label: j.name,
  }));

  const accountOptions = accountsData.map((a) => ({
    account_number: a.account_number,
    account_label: a.account_label,
  }));

  return (
    <>
      <ModuleShell
        icon={<BookOpen className="h-5 w-5" />}
        title="Comptabilité"
        subtitle="Saisie des écritures, lettrage, balance et clôture conformes SYSCOHADA."
        tabs={[
          { key: "ecritures", label: "Écritures", active: true },
          { key: "lettrage", label: "Lettrage" },
          { key: "balance", label: "Balance" },
          { key: "grand-livre", label: "Grand livre" },
          { key: "cloture", label: "Clôture" },
        ]}
        actions={
          <>
            <Button variant="outline" size="sm">
              <Download className="h-4 w-4" /> Exporter
            </Button>
            <Button
              variant="prestige"
              size="sm"
              onClick={() => setFormOpen(true)}
              disabled={journalOptions.length === 0}
            >
              <Plus className="h-4 w-4" /> Nouvelle écriture
            </Button>
          </>
        }
      >
        <div className="space-y-6">
          {isAuthError ? (
            <div className="rounded-md border border-destructive/40 bg-destructive/10 px-4 py-3 text-sm text-destructive">
              Accès restreint — connectez-vous avec un compte autorisé pour
              afficher les écritures comptables.
            </div>
          ) : null}

          <KpiGrid>
            <KpiCard
              label="Écritures (période)"
              value={
                entriesQuery.isLoading
                  ? "…"
                  : String(entries.length)
              }
              delta={`Exercice ${period.fiscalYear}`}
              tone="success"
            />
            <KpiCard
              label="À valider"
              value={entriesQuery.isLoading ? "…" : String(drafts)}
              hint="statut brouillard"
              tone="warning"
            />
            <KpiCard
              label="À lettrer"
              value={entriesQuery.isLoading ? "…" : String(toReconcile)}
              hint="postées non lettrées"
            />
            <KpiCard
              label="Période active"
              value={periodLabel}
              hint={`exercice ${period.fiscalYear} · ouverte`}
            />
          </KpiGrid>

          <ModuleCard
            title="Journal des écritures"
            description={`${periodLabel} · tous journaux`}
            action={
              <div className="flex items-center gap-2">
                <div className="relative">
                  <Search className="pointer-events-none absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted-foreground" />
                  <Input
                    placeholder="N° pièce, libellé…"
                    className="h-9 w-64 pl-8 text-sm"
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                  />
                </div>
                <Button variant="outline" size="sm">
                  <Filter className="h-4 w-4" /> Filtres
                </Button>
              </div>
            }
          >
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border text-left text-[11px] uppercase tracking-wider text-muted-foreground">
                    <th className="py-2 pr-3 font-medium">N°</th>
                    <th className="py-2 pr-3 font-medium">Date</th>
                    <th className="py-2 pr-3 font-medium">Journal</th>
                    <th className="py-2 pr-3 font-medium">Pièce</th>
                    <th className="py-2 pr-3 font-medium">Libellé</th>
                    <th className="py-2 pr-3 text-right font-medium">Débit</th>
                    <th className="py-2 pr-3 text-right font-medium">Crédit</th>
                    <th className="py-2 pr-3 font-medium">Statut</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {entriesQuery.isLoading ? (
                    <tr>
                      <td
                        colSpan={8}
                        className="py-10 text-center text-muted-foreground"
                      >
                        <Loader2 className="mx-auto h-4 w-4 animate-spin" />
                      </td>
                    </tr>
                  ) : filteredEntries.length === 0 ? (
                    <tr>
                      <td
                        colSpan={8}
                        className="py-10 text-center text-muted-foreground"
                      >
                        {isAuthError
                          ? "Authentification requise pour afficher les écritures."
                          : "Aucune écriture sur la période."}
                      </td>
                    </tr>
                  ) : (
                    filteredEntries.map((e: any) => (
                      <tr key={e.id} className="hover:bg-muted/40">
                        <td className="py-2.5 pr-3 font-mono text-xs text-foreground">
                          {e.entry_number}
                        </td>
                        <td className="py-2.5 pr-3 text-muted-foreground">
                          {formatDate(e.entry_date)}
                        </td>
                        <td className="py-2.5 pr-3">
                          <span className="rounded bg-muted px-1.5 py-0.5 font-mono text-[11px]">
                            {e.journal_code}
                          </span>
                        </td>
                        <td className="py-2.5 pr-3 text-muted-foreground">
                          {e.reference ?? "—"}
                        </td>
                        <td className="py-2.5 pr-3 text-foreground">
                          {e.description}
                        </td>
                        <td className="py-2.5 pr-3 text-right font-mono tabular-nums">
                          {formatXAF(e.total_debit, false)}
                        </td>
                        <td className="py-2.5 pr-3 text-right font-mono tabular-nums">
                          {formatXAF(e.total_credit, false)}
                        </td>
                        <td className="py-2.5 pr-3">
                          <StatusBadge tone={STATUS_TONE[e.status as EntryStatus]}>
                            {STATUS_LABEL[e.status as EntryStatus] ?? e.status}
                          </StatusBadge>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
                {filteredEntries.length > 0 ? (
                  <tfoot>
                    <tr className="border-t-2 border-border text-sm font-semibold">
                      <td
                        colSpan={5}
                        className="py-3 pr-3 text-right text-[11px] uppercase tracking-wider text-muted-foreground"
                      >
                        Totaux période
                      </td>
                      <td className="py-3 pr-3 text-right font-mono tabular-nums">
                        {formatXAF(totalDebit, false)}
                      </td>
                      <td className="py-3 pr-3 text-right font-mono tabular-nums">
                        {formatXAF(totalCredit, false)}
                      </td>
                      <td className="py-3 pr-3">
                        <StatusBadge tone={balanced ? "success" : "warning"}>
                          {balanced ? "Équilibré" : "Déséquilibré"}
                        </StatusBadge>
                      </td>
                    </tr>
                  </tfoot>
                ) : null}
              </table>
            </div>
          </ModuleCard>

          <ModuleCard
            title="Balance générale"
            description={`Cumul exercice ${period.fiscalYear} · jusqu'à ${periodLabel}`}
          >
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border text-left text-[11px] uppercase tracking-wider text-muted-foreground">
                    <th className="py-2 pr-3 font-medium">Compte</th>
                    <th className="py-2 pr-3 font-medium">Libellé</th>
                    <th className="py-2 pr-3 font-medium">Classe</th>
                    <th className="py-2 pr-3 text-right font-medium">Débit</th>
                    <th className="py-2 pr-3 text-right font-medium">Crédit</th>
                    <th className="py-2 pr-3 text-right font-medium">Solde</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {balanceQuery.isLoading ? (
                    <tr>
                      <td
                        colSpan={6}
                        className="py-10 text-center text-muted-foreground"
                      >
                        <Loader2 className="mx-auto h-4 w-4 animate-spin" />
                      </td>
                    </tr>
                  ) : balanceRows.length === 0 ? (
                    <tr>
                      <td
                        colSpan={6}
                        className="py-10 text-center text-muted-foreground"
                      >
                        Aucun mouvement validé sur la période.
                      </td>
                    </tr>
                  ) : (
                    balanceRows.map((r) => {
                      const bal = Number(r.balance);
                      return (
                        <tr
                          key={r.account_number}
                          className="hover:bg-muted/40"
                        >
                          <td className="py-2.5 pr-3 font-mono text-xs">
                            {r.account_number}
                          </td>
                          <td className="py-2.5 pr-3">{r.account_label}</td>
                          <td className="py-2.5 pr-3 text-muted-foreground">
                            {r.account_type}
                          </td>
                          <td className="py-2.5 pr-3 text-right font-mono tabular-nums">
                            {formatXAF(r.total_debit, false)}
                          </td>
                          <td className="py-2.5 pr-3 text-right font-mono tabular-nums">
                            {formatXAF(r.total_credit, false)}
                          </td>
                          <td
                            className={`py-2.5 pr-3 text-right font-mono tabular-nums ${
                              bal < 0 ? "text-destructive" : "text-foreground"
                            }`}
                          >
                            {formatXAF(Math.abs(bal), false)}
                            <span className="ml-1 text-[10px] text-muted-foreground">
                              {bal >= 0 ? "D" : "C"}
                            </span>
                          </td>
                        </tr>
                      );
                    })
                  )}
                </tbody>
              </table>
            </div>
          </ModuleCard>
        </div>
      </ModuleShell>

      {/* Formulaire de saisie d'écriture — Niveau T */}
      <Sheet open={formOpen} onOpenChange={setFormOpen}>
        <SheetContent className="w-full overflow-y-auto sm:max-w-2xl">
          <SheetHeader>
            <SheetTitle>Nouvelle écriture comptable</SheetTitle>
          </SheetHeader>
          <div className="mt-6">
            {journalOptions.length === 0 ? (
              <p className="text-sm text-muted-foreground">
                Chargement des journaux…
              </p>
            ) : (
              <JournalEntryForm
                journals={journalOptions}
                accounts={accountOptions}
                onSubmit={handleEntrySubmit}
                onCancel={() => setFormOpen(false)}
                loading={entryCreating}
              />
            )}
          </div>
        </SheetContent>
      </Sheet>
    </>
  );
}
