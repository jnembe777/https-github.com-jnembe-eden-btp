import { useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { BookOpen } from "lucide-react";

import { ModuleShell } from "@/components/edenfin/module-shell";
import { SmartGrid, GridColumn } from "@/components/edenfin/smart-grid";
import {
  EntityFormDrawer,
  FormFieldConfig,
} from "@/components/edenfin/entity-form-drawer";
import { Account } from "@/lib/mock-data";
import {
  useSupabaseQuery,
  useSupabaseCreate,
  useSupabaseUpdate,
  useSupabaseDelete,
} from "@/hooks/use-supabase";
import { useToast } from "@/hooks/use-toast";

export const Route = createFileRoute(
  "/_authenticated/console/plan-comptable"
)({
  component: PlanComptablePage,
});

function PlanComptablePage() {
  const { toast } = useToast();
  const [formOpen, setFormOpen] = useState(false);
  const [editingAccount, setEditingAccount] = useState<Account | null>(null);

  // Fetch accounts from Supabase
  const { data: accounts = [], isLoading } = useSupabaseQuery<Account>(
    "accounts",
    {
      order: { column: "account_number", ascending: true },
    }
  );

  // Mutations
  const createMutation = useSupabaseCreate<Account>("accounts");
  const updateMutation = useSupabaseUpdate<Account>("accounts");
  const deleteMutation = useSupabaseDelete("accounts");

  const columns: GridColumn<Account>[] = [
    {
      key: "account_number",
      label: "Numéro",
      type: "text",
      width: "120px",
      render: (value) => (
        <span className="font-mono text-sm font-medium">{value}</span>
      ),
    },
    {
      key: "account_label",
      label: "Libellé",
      type: "text",
      width: "auto",
    },
    {
      key: "account_type",
      label: "Type",
      type: "badge",
      width: "150px",
      badgeMap: {
        CAPITAUX: { label: "Capitaux", variant: "default" },
        ACTIF: { label: "Actif", variant: "default" },
        PASSIF: { label: "Passif", variant: "default" },
        CHARGES: { label: "Charges", variant: "destructive" },
        PRODUITS: { label: "Produits", variant: "default" },
        DETTES: { label: "Dettes", variant: "secondary" },
      },
    },
    {
      key: "class",
      label: "Classe",
      type: "number",
      width: "80px",
      align: "center",
      render: (value) => (
        <span className="inline-flex h-7 w-7 items-center justify-center rounded-full bg-primary/10 text-sm font-semibold text-primary">
          {value}
        </span>
      ),
    },
    {
      key: "is_active",
      label: "Actif",
      type: "boolean",
      width: "80px",
      align: "center",
      render: (value) => (
        <span
          className={`inline-block h-2 w-2 rounded-full ${value ? "bg-green-500" : "bg-gray-300"}`}
        />
      ),
    },
  ];

  const formFields: FormFieldConfig[] = [
    {
      key: "account_number",
      label: "Numéro de compte",
      type: "text",
      required: true,
      placeholder: "411000",
    },
    {
      key: "account_label",
      label: "Libellé",
      type: "text",
      required: true,
      placeholder: "Clients",
    },
    {
      key: "account_type",
      label: "Type de compte",
      type: "select",
      required: true,
      options: [
        { value: "CAPITAUX", label: "Capitaux" },
        { value: "ACTIF", label: "Actif" },
        { value: "PASSIF", label: "Passif" },
        { value: "CHARGES", label: "Charges" },
        { value: "PRODUITS", label: "Produits" },
        { value: "DETTES", label: "Dettes" },
      ],
    },
    {
      key: "class",
      label: "Classe",
      type: "number",
      required: true,
      placeholder: "4",
    },
    {
      key: "is_active",
      label: "Compte actif",
      type: "boolean",
      defaultValue: true,
    },
  ];

  const handleCreate = () => {
    setEditingAccount(null);
    setFormOpen(true);
  };

  const handleEdit = (account: Account) => {
    setEditingAccount(account);
    setFormOpen(true);
  };

  const handleDelete = async (account: Account) => {
    if (
      confirm(`Êtes-vous sûr de vouloir supprimer le compte ${account.account_number} ?`)
    ) {
      await deleteMutation.mutateAsync(account.id);
    }
  };

  const handleDuplicate = (account: Account) => {
    const duplicate = {
      ...account,
      account_number: account.account_number + "_COPY",
      id: undefined,
    };
    setEditingAccount(duplicate as unknown as Account);
    setFormOpen(true);
  };

  const handleFormSubmit = async (data: any) => {
    try {
      if (editingAccount?.id) {
        // Update existing account
        await updateMutation.mutateAsync({
          id: editingAccount.id,
          data,
        });
      } else {
        // Create new account
        await createMutation.mutateAsync(data);
      }
      setFormOpen(false);
      setEditingAccount(null);
    } catch (error) {
      // Error handling is done in the mutation hooks
    }
  };

  return (
    <ModuleShell
      icon={<BookOpen className="h-5 w-5" />}
      title="Plan comptable"
      subtitle="Gestion du plan de comptes SYSCOHADA pour votre entreprise."
      tabs={[
        { key: "comptes", label: "Tous les comptes", active: true },
        { key: "classes", label: "Par classe" },
        { key: "import", label: "Import/Export" },
      ]}
    >
      <SmartGrid
        columns={columns}
        data={accounts}
        loading={isLoading}
        onCreate={handleCreate}
        onEdit={handleEdit}
        onDelete={handleDelete}
        onDuplicate={handleDuplicate}
        title="Liste des comptes"
        description={`${accounts.length} comptes dans le plan comptable`}
        showSearch
        showCreate
        showExport
        showPagination
        pageSize={15}
        emptyMessage="Aucun compte dans le plan comptable"
      />

      <EntityFormDrawer
        open={formOpen}
        onClose={() => {
          setFormOpen(false);
          setEditingAccount(null);
        }}
        title={editingAccount?.id ? "Modifier le compte" : "Créer un compte"}
        fields={formFields}
        initialData={editingAccount || undefined}
        onSubmit={handleFormSubmit}
        loading={createMutation.isPending || updateMutation.isPending}
      />
    </ModuleShell>
  );
}
