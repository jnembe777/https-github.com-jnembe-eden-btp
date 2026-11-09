/**
 * React Query hooks for Supabase operations
 * Type-safe CRUD operations with automatic caching and invalidation
 */

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { supabase, TABLES, SCHEMAS, getErrorMessage } from "@/lib/supabase";
import { useToast } from "./use-toast";

export interface QueryOptions {
  filters?: Record<string, any>;
  order?: { column: string; ascending?: boolean };
  limit?: number;
  offset?: number;
  select?: string;
}

export interface UseSupabaseTableOptions {
  schema?: keyof typeof SCHEMAS;
  primaryKey?: string;
  softDelete?: boolean;
}

/**
 * Hook for querying a Supabase table with React Query
 */
export function useSupabaseQuery<T = any>(
  tableName: keyof typeof TABLES | string,
  options: QueryOptions & UseSupabaseTableOptions = {}
) {
  const {
    filters = {},
    order,
    limit,
    offset,
    select = "*",
    schema = "CLIENT",
    softDelete = true,
  } = options;

  const table = TABLES[tableName as keyof typeof TABLES] || tableName;
  const schemaName = SCHEMAS[schema];

  return useQuery({
    queryKey: [table, filters, order, limit, offset, select],
    queryFn: async () => {
      let query = supabase.schema(schemaName).from(table).select(select);

      // Apply soft delete filter
      if (softDelete) {
        query = query.is("deleted_at", null);
      }

      // Apply filters
      Object.entries(filters).forEach(([column, value]) => {
        if (value === null || value === undefined) return;

        if (typeof value === "object" && "op" in value) {
          // Complex filter
          const { op, value: filterValue } = value as {
            op: string;
            value: any;
          };
          switch (op) {
            case "ilike":
              query = query.ilike(column, filterValue);
              break;
            case "gt":
              query = query.gt(column, filterValue);
              break;
            case "gte":
              query = query.gte(column, filterValue);
              break;
            case "lt":
              query = query.lt(column, filterValue);
              break;
            case "lte":
              query = query.lte(column, filterValue);
              break;
            case "in":
              query = query.in(column, filterValue);
              break;
            case "is":
              query = query.is(column, filterValue);
              break;
            default:
              query = query.eq(column, filterValue);
          }
        } else {
          // Simple equality filter
          query = query.eq(column, value);
        }
      });

      // Apply ordering
      if (order) {
        query = query.order(order.column, {
          ascending: order.ascending ?? true,
        });
      }

      // Apply pagination
      if (limit) {
        if (offset !== undefined) {
          query = query.range(offset, offset + limit - 1);
        } else {
          query = query.limit(limit);
        }
      }

      const { data, error } = await query;

      if (error) {
        throw new Error(getErrorMessage(error));
      }

      return (data || []) as T[];
    },
  });
}

/**
 * Hook for creating a record in a Supabase table
 */
export function useSupabaseCreate<T = any>(
  tableName: keyof typeof TABLES | string,
  options: UseSupabaseTableOptions = {}
) {
  const { toast } = useToast();
  const queryClient = useQueryClient();

  const table = TABLES[tableName as keyof typeof TABLES] || tableName;
  const schema = options.schema || "CLIENT";
  const schemaName = SCHEMAS[schema];

  return useMutation({
    mutationFn: async (data: Partial<T>) => {
      const { data: result, error } = await supabase
        .schema(schemaName)
        .from(table)
        .insert(data as never)
        .select()
        .single();

      if (error) {
        throw new Error(getErrorMessage(error));
      }

      return result as T;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [table] });
      toast({
        title: "Enregistrement créé",
        description: "L'enregistrement a été créé avec succès.",
      });
    },
    onError: (error: Error) => {
      toast({
        title: "Erreur de création",
        description: error.message,
        variant: "destructive",
      });
    },
  });
}

/**
 * Hook for updating a record in a Supabase table
 */
export function useSupabaseUpdate<T = any>(
  tableName: keyof typeof TABLES | string,
  options: UseSupabaseTableOptions = {}
) {
  const { toast } = useToast();
  const queryClient = useQueryClient();

  const table = TABLES[tableName as keyof typeof TABLES] || tableName;
  const schema = options.schema || "CLIENT";
  const schemaName = SCHEMAS[schema];
  const primaryKey = options.primaryKey || "id";

  return useMutation({
    mutationFn: async ({ id, data }: { id: any; data: Partial<T> }) => {
      const { data: result, error } = await supabase
        .schema(schemaName)
        .from(table)
        .update(data as never)
        .eq(primaryKey, id)
        .select()
        .single();

      if (error) {
        throw new Error(getErrorMessage(error));
      }

      return result as T;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [table] });
      toast({
        title: "Enregistrement modifié",
        description: "L'enregistrement a été modifié avec succès.",
      });
    },
    onError: (error: Error) => {
      toast({
        title: "Erreur de modification",
        description: error.message,
        variant: "destructive",
      });
    },
  });
}

/**
 * Hook for deleting a record from a Supabase table
 */
export function useSupabaseDelete(
  tableName: keyof typeof TABLES | string,
  options: UseSupabaseTableOptions = {}
) {
  const { toast } = useToast();
  const queryClient = useQueryClient();

  const table = TABLES[tableName as keyof typeof TABLES] || tableName;
  const schema = options.schema || "CLIENT";
  const schemaName = SCHEMAS[schema];
  const primaryKey = options.primaryKey || "id";
  const softDelete = options.softDelete ?? true;

  return useMutation({
    mutationFn: async (id: any) => {
      if (softDelete) {
        // Soft delete: set deleted_at timestamp
        const { error } = await supabase
          .schema(schemaName)
          .from(table)
          .update({ deleted_at: new Date().toISOString() })
          .eq(primaryKey, id);

        if (error) {
          throw new Error(getErrorMessage(error));
        }
      } else {
        // Hard delete
        const { error } = await supabase
          .schema(schemaName)
          .from(table)
          .delete()
          .eq(primaryKey, id);

        if (error) {
          throw new Error(getErrorMessage(error));
        }
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [table] });
      toast({
        title: "Enregistrement supprimé",
        description: "L'enregistrement a été supprimé avec succès.",
      });
    },
    onError: (error: Error) => {
      toast({
        title: "Erreur de suppression",
        description: error.message,
        variant: "destructive",
      });
    },
  });
}

/**
 * Hook for executing a Supabase RPC function
 */
export function useSupabaseRPC<T = any>(functionName: string) {
  const { toast } = useToast();

  return useMutation({
    mutationFn: async (params: Record<string, any> = {}) => {
      const { data, error } = await supabase.rpc(functionName, params);

      if (error) {
        throw new Error(getErrorMessage(error));
      }

      return data as T;
    },
    onError: (error: Error) => {
      toast({
        title: "Erreur d'exécution",
        description: error.message,
        variant: "destructive",
      });
    },
  });
}
