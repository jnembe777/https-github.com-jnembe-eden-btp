/**
 * DataTable - Table de données en lecture seule pour rapports
 * Version simplifiée de SmartGrid sans fonctionnalités d'édition
 */

import { useMemo } from "react";
import { Download, Printer } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  TableFooter,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";

export interface DataTableColumn<T = any> {
  key: string;
  label: string;
  type?:
    | "text"
    | "number"
    | "currency"
    | "date"
    | "badge"
    | "boolean"
    | "custom";
  width?: string;
  align?: "left" | "center" | "right";
  render?: (value: any, row: T) => React.ReactNode;
  badgeMap?: Record<string, { label: string; variant: string }>;
  /** Afficher dans le footer */
  showTotal?: boolean;
  /** Format du total (sum, count, average) */
  totalType?: "sum" | "count" | "average";
  /** Classe CSS personnalisée pour la cellule */
  className?: string;
}

export interface DataTableProps<T = any> {
  /** Configuration des colonnes */
  columns: DataTableColumn<T>[];
  /** Données à afficher */
  data: T[];
  /** Titre du tableau */
  title?: string;
  /** Description du tableau */
  description?: string;
  /** Afficher le footer avec totaux */
  showFooter?: boolean;
  /** Afficher les boutons d'export */
  showExport?: boolean;
  /** État de chargement */
  loading?: boolean;
  /** Message quand aucune donnée */
  emptyMessage?: string;
  /** Classe CSS pour le container */
  className?: string;
  /** Ligne de footer personnalisée */
  customFooter?: React.ReactNode;
}

export function DataTable<T extends Record<string, any>>({
  columns,
  data,
  title,
  description,
  showFooter = false,
  showExport = true,
  loading = false,
  emptyMessage = "Aucune donnée disponible",
  className,
  customFooter,
}: DataTableProps<T>) {
  // Calcul des totaux pour le footer
  const totals = useMemo(() => {
    const result: Record<string, any> = {};

    columns.forEach((col) => {
      if (!col.showTotal) return;

      const values = data.map((row) => row[col.key]).filter((v) => v != null);

      switch (col.totalType) {
        case "sum":
          result[col.key] = values.reduce((sum, v) => sum + Number(v), 0);
          break;
        case "count":
          result[col.key] = values.length;
          break;
        case "average":
          result[col.key] =
            values.reduce((sum, v) => sum + Number(v), 0) / values.length || 0;
          break;
        default:
          result[col.key] = values.reduce((sum, v) => sum + Number(v), 0);
      }
    });

    return result;
  }, [data, columns]);

  const renderCellValue = (column: DataTableColumn<T>, row: T) => {
    const value = row[column.key];

    // Custom render
    if (column.render) {
      return column.render(value, row);
    }

    // Valeur vide
    if (value === null || value === undefined) {
      return <span className="text-muted-foreground">—</span>;
    }

    // Types spécifiques
    switch (column.type) {
      case "badge":
        const badgeInfo = column.badgeMap?.[value];
        return badgeInfo ? (
          <Badge variant={badgeInfo.variant as any}>{badgeInfo.label}</Badge>
        ) : (
          value
        );

      case "boolean":
        return value ? "Oui" : "Non";

      case "currency":
        return new Intl.NumberFormat("fr-FR").format(Number(value)) + " XAF";

      case "number":
        return new Intl.NumberFormat("fr-FR").format(Number(value));

      case "date":
        return new Date(value).toLocaleDateString("fr-FR");

      default:
        return String(value);
    }
  };

  const renderFooterCell = (column: DataTableColumn<T>) => {
    if (!column.showTotal) return null;

    const value = totals[column.key];

    switch (column.type) {
      case "currency":
        return new Intl.NumberFormat("fr-FR").format(Number(value)) + " XAF";
      case "number":
        return new Intl.NumberFormat("fr-FR").format(Number(value));
      default:
        return String(value);
    }
  };

  const handleExportCSV = () => {
    const headers = columns.map((col) => col.label).join(",");
    const rows = data
      .map((row) =>
        columns.map((col) => JSON.stringify(row[col.key] ?? "")).join(",")
      )
      .join("\n");

    const csv = `${headers}\n${rows}`;
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = `export_${Date.now()}.csv`;
    link.click();
  };

  const handlePrint = () => {
    window.print();
  };

  return (
    <div className={cn("space-y-4", className)}>
      {/* Header */}
      {(title || description || showExport) && (
        <div className="flex items-start justify-between">
          <div>
            {title && <h3 className="text-lg font-semibold">{title}</h3>}
            {description && (
              <p className="mt-1 text-sm text-muted-foreground">{description}</p>
            )}
          </div>

          {showExport && (
            <div className="flex items-center gap-2">
              <Button variant="outline" size="sm" onClick={handlePrint}>
                <Printer className="h-4 w-4" />
                Imprimer
              </Button>
              <Button variant="outline" size="sm" onClick={handleExportCSV}>
                <Download className="h-4 w-4" />
                Exporter CSV
              </Button>
            </div>
          )}
        </div>
      )}

      {/* Table */}
      <div className="rounded-md border">
        <Table>
          <TableHeader>
            <TableRow>
              {columns.map((column) => (
                <TableHead
                  key={column.key}
                  style={{ width: column.width }}
                  className={cn(
                    column.align === "right"
                      ? "text-right"
                      : column.align === "center"
                        ? "text-center"
                        : "",
                    column.className
                  )}
                >
                  {column.label}
                </TableHead>
              ))}
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell
                  colSpan={columns.length}
                  className="h-24 text-center"
                >
                  Chargement...
                </TableCell>
              </TableRow>
            ) : data.length === 0 ? (
              <TableRow>
                <TableCell
                  colSpan={columns.length}
                  className="h-24 text-center text-muted-foreground"
                >
                  {emptyMessage}
                </TableCell>
              </TableRow>
            ) : (
              data.map((row, idx) => (
                <TableRow key={idx}>
                  {columns.map((column) => (
                    <TableCell
                      key={column.key}
                      className={cn(
                        column.align === "right"
                          ? "text-right"
                          : column.align === "center"
                            ? "text-center"
                            : "",
                        column.className
                      )}
                    >
                      {renderCellValue(column, row)}
                    </TableCell>
                  ))}
                </TableRow>
              ))
            )}
          </TableBody>

          {/* Footer avec totaux */}
          {showFooter && data.length > 0 && (
            <TableFooter>
              {customFooter ? (
                <TableRow>{customFooter}</TableRow>
              ) : (
                <TableRow>
                  {columns.map((column, idx) => (
                    <TableCell
                      key={column.key}
                      className={cn(
                        "font-semibold",
                        column.align === "right"
                          ? "text-right"
                          : column.align === "center"
                            ? "text-center"
                            : "",
                        column.className
                      )}
                    >
                      {idx === 0 && !column.showTotal ? (
                        <span className="text-sm uppercase tracking-wider text-muted-foreground">
                          Total
                        </span>
                      ) : (
                        renderFooterCell(column)
                      )}
                    </TableCell>
                  ))}
                </TableRow>
              )}
            </TableFooter>
          )}
        </Table>
      </div>
    </div>
  );
}
