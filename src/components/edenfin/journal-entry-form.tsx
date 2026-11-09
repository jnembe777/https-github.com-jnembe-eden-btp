/**
 * JournalEntryForm - Formulaire de saisie d'écritures comptables multi-lignes
 * Conforme SYSCOHADA avec contrôle d'équilibre Débit = Crédit
 */

import { useState, useEffect, useMemo } from "react";
import { Plus, Trash2, AlertTriangle, CheckCircle, Save } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { formatXAF } from "@/lib/formatters";
import { useToast } from "@/hooks/use-toast";

export interface JournalEntryLine {
  id: string;
  account_number: string;
  account_label?: string;
  description: string;
  debit: number;
  credit: number;
}

export interface JournalEntryFormData {
  journal_code: string;
  entry_date: string;
  reference?: string;
  description: string;
  lines: JournalEntryLine[];
}

export interface JournalOption {
  code: string;
  label: string;
}

export interface AccountOption {
  account_number: string;
  account_label: string;
}

export interface JournalEntryFormProps {
  /** Journaux disponibles */
  journals: JournalOption[];
  /** Plan comptable pour l'autocomplete */
  accounts: AccountOption[];
  /** Données initiales (mode édition) */
  initialData?: Partial<JournalEntryFormData>;
  /** Callback de soumission */
  onSubmit: (data: JournalEntryFormData, isDraft: boolean) => Promise<void>;
  /** Callback d'annulation */
  onCancel?: () => void;
  /** État de chargement */
  loading?: boolean;
}

export function JournalEntryForm({
  journals,
  accounts,
  initialData,
  onSubmit,
  onCancel,
  loading = false,
}: JournalEntryFormProps) {
  const { toast } = useToast();

  // État du header
  const [journalCode, setJournalCode] = useState(
    initialData?.journal_code || journals[0]?.code || ""
  );
  const [entryDate, setEntryDate] = useState(
    initialData?.entry_date || new Date().toISOString().split("T")[0]
  );
  const [reference, setReference] = useState(initialData?.reference || "");
  const [description, setDescription] = useState(initialData?.description || "");

  // État des lignes
  const [lines, setLines] = useState<JournalEntryLine[]>(
    initialData?.lines || [
      {
        id: crypto.randomUUID(),
        account_number: "",
        description: "",
        debit: 0,
        credit: 0,
      },
      {
        id: crypto.randomUUID(),
        account_number: "",
        description: "",
        debit: 0,
        credit: 0,
      },
    ]
  );

  // Calcul des totaux
  const totals = useMemo(() => {
    const totalDebit = lines.reduce((sum, line) => sum + (line.debit || 0), 0);
    const totalCredit = lines.reduce((sum, line) => sum + (line.credit || 0), 0);
    const isBalanced = totalDebit === totalCredit && totalDebit > 0;

    return { totalDebit, totalCredit, isBalanced };
  }, [lines]);

  const addLine = () => {
    setLines([
      ...lines,
      {
        id: crypto.randomUUID(),
        account_number: "",
        description: description, // Copie la description du header
        debit: 0,
        credit: 0,
      },
    ]);
  };

  const removeLine = (id: string) => {
    if (lines.length <= 2) {
      toast({
        title: "Impossible de supprimer",
        description: "Une écriture doit comporter au moins 2 lignes.",
        variant: "destructive",
      });
      return;
    }
    setLines(lines.filter((line) => line.id !== id));
  };

  const updateLine = (id: string, field: keyof JournalEntryLine, value: any) => {
    setLines(
      lines.map((line) => {
        if (line.id === id) {
          const updated = { ...line, [field]: value };

          // Si on change le compte, récupérer le libellé
          if (field === "account_number") {
            const account = accounts.find((a) => a.account_number === value);
            updated.account_label = account?.account_label || "";
          }

          // Si on met un débit, mettre le crédit à 0 et vice-versa
          if (field === "debit" && value > 0) {
            updated.credit = 0;
          }
          if (field === "credit" && value > 0) {
            updated.debit = 0;
          }

          return updated;
        }
        return line;
      })
    );
  };

  const handleSubmit = async (isDraft: boolean) => {
    // Validation
    if (!journalCode || !entryDate || !description) {
      toast({
        title: "Champs obligatoires",
        description: "Veuillez remplir tous les champs du header.",
        variant: "destructive",
      });
      return;
    }

    const validLines = lines.filter(
      (line) => line.account_number && (line.debit > 0 || line.credit > 0)
    );

    if (validLines.length < 2) {
      toast({
        title: "Lignes insuffisantes",
        description: "Une écriture doit comporter au moins 2 lignes valides.",
        variant: "destructive",
      });
      return;
    }

    if (!isDraft && !totals.isBalanced) {
      toast({
        title: "Écriture déséquilibrée",
        description: "Le total débit doit être égal au total crédit.",
        variant: "destructive",
      });
      return;
    }

    const data: JournalEntryFormData = {
      journal_code: journalCode,
      entry_date: entryDate,
      reference,
      description,
      lines: validLines,
    };

    try {
      await onSubmit(data, isDraft);
      toast({
        title: isDraft ? "Brouillon enregistré" : "Écriture validée",
        description: isDraft
          ? "L'écriture a été enregistrée en brouillon."
          : "L'écriture a été validée avec succès.",
      });
    } catch (error: any) {
      toast({
        title: "Erreur",
        description: error.message || "Erreur lors de l'enregistrement",
        variant: "destructive",
      });
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <Card>
        <CardHeader>
          <CardTitle>En-tête de l'écriture</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid gap-4 md:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="journal">
                Journal <span className="text-destructive">*</span>
              </Label>
              <Select value={journalCode} onValueChange={setJournalCode}>
                <SelectTrigger id="journal">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {journals.map((journal) => (
                    <SelectItem key={journal.code} value={journal.code}>
                      {journal.code} - {journal.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label htmlFor="date">
                Date <span className="text-destructive">*</span>
              </Label>
              <Input
                id="date"
                type="date"
                value={entryDate}
                onChange={(e) => setEntryDate(e.target.value)}
              />
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="reference">N° de pièce</Label>
            <Input
              id="reference"
              value={reference}
              onChange={(e) => setReference(e.target.value)}
              placeholder="FAC-2026-001"
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="description">
              Libellé <span className="text-destructive">*</span>
            </Label>
            <Input
              id="description"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Vente marchandises..."
            />
          </div>
        </CardContent>
      </Card>

      {/* Lignes d'écriture */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>Lignes d'écriture</CardTitle>
            <Button onClick={addLine} size="sm" variant="outline">
              <Plus className="mr-2 h-4 w-4" />
              Ajouter une ligne
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b">
                  <th className="pb-2 text-left font-medium">Compte</th>
                  <th className="pb-2 text-left font-medium">Libellé</th>
                  <th className="pb-2 text-right font-medium">Débit</th>
                  <th className="pb-2 text-right font-medium">Crédit</th>
                  <th className="w-12 pb-2"></th>
                </tr>
              </thead>
              <tbody>
                {lines.map((line, idx) => (
                  <tr key={line.id} className="border-b">
                    <td className="py-2 pr-2">
                      <Input
                        list={`accounts-${line.id}`}
                        value={line.account_number}
                        onChange={(e) =>
                          updateLine(line.id, "account_number", e.target.value)
                        }
                        placeholder="411000"
                        className="w-32 font-mono text-xs"
                      />
                      <datalist id={`accounts-${line.id}`}>
                        {accounts.map((acc) => (
                          <option
                            key={acc.account_number}
                            value={acc.account_number}
                          >
                            {acc.account_label}
                          </option>
                        ))}
                      </datalist>
                      {line.account_label && (
                        <div className="mt-1 text-xs text-muted-foreground">
                          {line.account_label}
                        </div>
                      )}
                    </td>
                    <td className="py-2 pr-2">
                      <Input
                        value={line.description}
                        onChange={(e) =>
                          updateLine(line.id, "description", e.target.value)
                        }
                        placeholder="Libellé ligne..."
                        className="text-xs"
                      />
                    </td>
                    <td className="py-2 pr-2">
                      <Input
                        type="number"
                        value={line.debit || ""}
                        onChange={(e) =>
                          updateLine(line.id, "debit", Number(e.target.value))
                        }
                        className="w-32 text-right font-mono text-xs"
                        min={0}
                        step={1}
                      />
                    </td>
                    <td className="py-2 pr-2">
                      <Input
                        type="number"
                        value={line.credit || ""}
                        onChange={(e) =>
                          updateLine(line.id, "credit", Number(e.target.value))
                        }
                        className="w-32 text-right font-mono text-xs"
                        min={0}
                        step={1}
                      />
                    </td>
                    <td className="py-2">
                      <Button
                        variant="ghost"
                        size="icon"
                        onClick={() => removeLine(line.id)}
                        disabled={lines.length <= 2}
                      >
                        <Trash2 className="h-4 w-4 text-destructive" />
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
              <tfoot>
                <tr className="border-t-2 font-semibold">
                  <td colSpan={2} className="py-3 text-right">
                    TOTAUX
                  </td>
                  <td className="py-3 text-right font-mono">
                    {formatXAF(totals.totalDebit, false)}
                  </td>
                  <td className="py-3 text-right font-mono">
                    {formatXAF(totals.totalCredit, false)}
                  </td>
                  <td></td>
                </tr>
              </tfoot>
            </table>
          </div>

          {/* Indicateur d'équilibre */}
          <div className="mt-4">
            {totals.totalDebit === 0 && totals.totalCredit === 0 ? (
              <Alert>
                <AlertTriangle className="h-4 w-4" />
                <AlertDescription>
                  Saisissez les montants pour équilibrer l'écriture
                </AlertDescription>
              </Alert>
            ) : totals.isBalanced ? (
              <Alert className="border-green-500 bg-green-50 dark:bg-green-950">
                <CheckCircle className="h-4 w-4 text-green-600" />
                <AlertDescription className="text-green-700 dark:text-green-300">
                  Écriture équilibrée : {formatXAF(totals.totalDebit)}
                </AlertDescription>
              </Alert>
            ) : (
              <Alert variant="destructive">
                <AlertTriangle className="h-4 w-4" />
                <AlertDescription>
                  Écart : {formatXAF(Math.abs(totals.totalDebit - totals.totalCredit))}
                  {totals.totalDebit > totals.totalCredit
                    ? " en faveur du débit"
                    : " en faveur du crédit"}
                </AlertDescription>
              </Alert>
            )}
          </div>
        </CardContent>
      </Card>

      {/* Actions */}
      <div className="flex gap-3">
        {onCancel && (
          <Button
            variant="outline"
            onClick={onCancel}
            disabled={loading}
            className="flex-1"
          >
            Annuler
          </Button>
        )}
        <Button
          variant="outline"
          onClick={() => handleSubmit(true)}
          disabled={loading}
          className="flex-1"
        >
          <Save className="mr-2 h-4 w-4" />
          Enregistrer brouillon
        </Button>
        <Button
          onClick={() => handleSubmit(false)}
          disabled={loading || !totals.isBalanced}
          className="flex-1"
        >
          <CheckCircle className="mr-2 h-4 w-4" />
          Valider l'écriture
        </Button>
      </div>
    </div>
  );
}
