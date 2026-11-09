/**
 * SmartGrid - Composant de grille de données configurable pour EdenFin
 * Inspiré du prototype JASPE avec support TypeScript
 */

import { useState, useMemo } from "react";
import {
  Search,
  Filter,
  Download,
  Plus,
  MoreHorizontal,
  Edit,
  Trash2,
  Copy,
  ChevronLeft,
  ChevronRight,
} from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

export interface GridColumn<T = any> {
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
  sortable?: boolean;
  render?: (value: any, row: T) => React.ReactNode;
  badgeMap?: Record<string, { label: string; variant: string }>;
}

export interface SmartGridProps<T = any> {
  /** Configuration des colonnes */
  columns: GridColumn<T>[];
  /** Données à afficher */
  data: T[];
  /** Fonction de création d'un nouvel élément */
  onCreate?: () => void;
  /** Fonction d'édition d'un élément */
  onEdit?: (row: T) => void;
  /** Fonction de suppression d'un élément */
  onDelete?: (row: T) => void;
  /** Fonction de duplication d'un élément */
  onDuplicate?: (row: T) => void;
  /** Actions personnalisées dans le menu contextuel */
  customActions?: Array<{
    label: string;
    icon?: React.ReactNode;
    onClick: (row: T) => void;
  }>;
  /** Titre de la grille */
  title?: string;
  /** Description de la grille */
  description?: string;
  /** Afficher la barre de recherche */
  showSearch?: boolean;
  /** Afficher le bouton de création */
  showCreate?: boolean;
  /** Afficher le bouton d'export */
  showExport?: boolean;
  /** Afficher la pagination */
  showPagination?: boolean;
  /** Nombre d'éléments par page */
  pageSize?: number;
  /** État de chargement */
  loading?: boolean;
  /** Message quand aucune donnée */
  emptyMessage?: string;
}

export function SmartGrid<T extends Record<string, any>>({
  columns,
  data,
  onCreate,
  onEdit,
  onDelete,
  onDuplicate,
  customActions,
  title,
  description,
  showSearch = true,
  showCreate = true,
  showExport = true,
  showPagination = true,
  pageSize = 10,
  loading = false,
  emptyMessage = "Aucune donnée disponible",
}: SmartGridProps<T>) {
  const [searchTerm, setSearchTerm] = useState("");
  const [currentPage, setCurrentPage] = useState(1);
  const [sortColumn, setSortColumn] = useState<string | null>(null);
  const [sortDirection, setSortDirection] = useState<"asc" | "desc">("asc");

  // Filtrage par recherche
  const filteredData = useMemo(() => {
    if (!searchTerm) return data;

    const lowerSearch = searchTerm.toLowerCase();
    return data.filter((row) =>
      columns.some((col) => {
        const value = row[col.key];
        return String(value).toLowerCase().includes(lowerSearch);
      })
    );
  }, [data, searchTerm, columns]);

  // Tri
  const sortedData = useMemo(() => {
    if (!sortColumn) return filteredData;

    return [...filteredData].sort((a, b) => {
      const aVal = a[sortColumn];
      const bVal = b[sortColumn];

      if (aVal === bVal) return 0;
      const comparison = aVal < bVal ? -1 : 1;
      return sortDirection === "asc" ? comparison : -comparison;
    });
  }, [filteredData, sortColumn, sortDirection]);

  // Pagination
  const totalPages = Math.ceil(sortedData.length / pageSize);
  const startIndex = (currentPage - 1) * pageSize;
  const paginatedData = showPagination
    ? sortedData.slice(startIndex, startIndex + pageSize)
    : sortedData;

  const handleSort = (columnKey: string) => {
    if (sortColumn === columnKey) {
      setSortDirection(sortDirection === "asc" ? "desc" : "asc");
    } else {
      setSortColumn(columnKey);
      setSortDirection("asc");
    }
  };

  const renderCellValue = (column: GridColumn<T>, row: T) => {
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
          <Badge variant={badgeInfo.variant as any}>
            {badgeInfo.label}
          </Badge>
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

  const handleExport = () => {
    // Export CSV simple
    const headers = columns.map((col) => col.label).join(",");
    const rows = sortedData
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

  return (
    <div className="space-y-4">
      {/* Header */}
      {(title || description) && (
        <div>
          {title && <h3 className="text-lg font-semibold">{title}</h3>}
          {description && (
            <p className="text-sm text-muted-foreground">{description}</p>
          )}
        </div>
      )}

      {/* Toolbar */}
      <div className="flex items-center justify-between gap-4">
        <div className="flex flex-1 items-center gap-2">
          {showSearch && (
            <div className="relative flex-1 max-w-sm">
              <Search className="absolute left-2.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                placeholder="Rechercher..."
                value={searchTerm}
                onChange={(e) => {
                  setSearchTerm(e.target.value);
                  setCurrentPage(1);
                }}
                className="pl-8"
              />
            </div>
          )}
        </div>

        <div className="flex items-center gap-2">
          {showExport && (
            <Button variant="outline" size="sm" onClick={handleExport}>
              <Download className="h-4 w-4" />
              Exporter
            </Button>
          )}
          {showCreate && onCreate && (
            <Button size="sm" onClick={onCreate}>
              <Plus className="h-4 w-4" />
              Nouveau
            </Button>
          )}
        </div>
      </div>

      {/* Table */}
      <div className="rounded-md border">
        <Table>
          <TableHeader>
            <TableRow>
              {columns.map((column) => (
                <TableHead
                  key={column.key}
                  style={{ width: column.width }}
                  className={
                    column.align === "right"
                      ? "text-right"
                      : column.align === "center"
                        ? "text-center"
                        : ""
                  }
                >
                  {column.sortable !== false ? (
                    <button
                      onClick={() => handleSort(column.key)}
                      className="flex items-center gap-1 hover:text-foreground"
                    >
                      {column.label}
                      {sortColumn === column.key && (
                        <span className="text-xs">
                          {sortDirection === "asc" ? "↑" : "↓"}
                        </span>
                      )}
                    </button>
                  ) : (
                    column.label
                  )}
                </TableHead>
              ))}
              {(onEdit || onDelete || onDuplicate || customActions) && (
                <TableHead className="w-12"></TableHead>
              )}
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell
                  colSpan={columns.length + 1}
                  className="h-24 text-center"
                >
                  Chargement...
                </TableCell>
              </TableRow>
            ) : paginatedData.length === 0 ? (
              <TableRow>
                <TableCell
                  colSpan={columns.length + 1}
                  className="h-24 text-center text-muted-foreground"
                >
                  {emptyMessage}
                </TableCell>
              </TableRow>
            ) : (
              paginatedData.map((row, idx) => (
                <TableRow key={idx}>
                  {columns.map((column) => (
                    <TableCell
                      key={column.key}
                      className={
                        column.align === "right"
                          ? "text-right"
                          : column.align === "center"
                            ? "text-center"
                            : ""
                      }
                    >
                      {renderCellValue(column, row)}
                    </TableCell>
                  ))}
                  {(onEdit || onDelete || onDuplicate || customActions) && (
                    <TableCell>
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="icon">
                            <MoreHorizontal className="h-4 w-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          {onEdit && (
                            <DropdownMenuItem onClick={() => onEdit(row)}>
                              <Edit className="mr-2 h-4 w-4" />
                              Modifier
                            </DropdownMenuItem>
                          )}
                          {onDuplicate && (
                            <DropdownMenuItem onClick={() => onDuplicate(row)}>
                              <Copy className="mr-2 h-4 w-4" />
                              Dupliquer
                            </DropdownMenuItem>
                          )}
                          {customActions?.map((action, i) => (
                            <DropdownMenuItem
                              key={i}
                              onClick={() => action.onClick(row)}
                            >
                              {action.icon}
                              {action.label}
                            </DropdownMenuItem>
                          ))}
                          {onDelete && (
                            <DropdownMenuItem
                              onClick={() => onDelete(row)}
                              className="text-destructive"
                            >
                              <Trash2 className="mr-2 h-4 w-4" />
                              Supprimer
                            </DropdownMenuItem>
                          )}
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </TableCell>
                  )}
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>

      {/* Pagination */}
      {showPagination && totalPages > 1 && (
        <div className="flex items-center justify-between">
          <p className="text-sm text-muted-foreground">
            {startIndex + 1}-{Math.min(startIndex + pageSize, sortedData.length)}{" "}
            sur {sortedData.length}
          </p>
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
              disabled={currentPage === 1}
            >
              <ChevronLeft className="h-4 w-4" />
              Précédent
            </Button>
            <span className="text-sm">
              Page {currentPage} / {totalPages}
            </span>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
              disabled={currentPage === totalPages}
            >
              Suivant
              <ChevronRight className="h-4 w-4" />
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
