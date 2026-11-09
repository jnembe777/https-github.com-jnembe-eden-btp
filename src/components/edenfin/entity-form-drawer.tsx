/**
 * EntityFormDrawer - Formulaire modal dynamique pour CRUD
 * Génère automatiquement les champs depuis la configuration de colonne
 */

import { useState, useEffect } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import { X, Save, Loader2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import {
  Form,
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Switch } from "@/components/ui/switch";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Calendar } from "@/components/ui/calendar";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import { cn } from "@/lib/utils";
import { format } from "date-fns";
import { fr } from "date-fns/locale";
import { CalendarIcon } from "lucide-react";

export interface FormFieldConfig {
  key: string;
  label: string;
  type:
    | "text"
    | "textarea"
    | "number"
    | "currency"
    | "percent"
    | "date"
    | "boolean"
    | "select"
    | "email";
  required?: boolean;
  placeholder?: string;
  description?: string;
  defaultValue?: any;
  options?: Array<{ value: string; label: string }>;
  min?: number;
  max?: number;
  disabled?: boolean;
  validation?: z.ZodType<any>;
}

export interface EntityFormDrawerProps {
  /** Ouvert/Fermé */
  open: boolean;
  /** Callback de fermeture */
  onClose: () => void;
  /** Titre du formulaire */
  title: string;
  /** Description du formulaire */
  description?: string;
  /** Configuration des champs */
  fields: FormFieldConfig[];
  /** Données initiales (mode édition) */
  initialData?: Record<string, any>;
  /** Callback de soumission */
  onSubmit: (data: Record<string, any>) => Promise<void> | void;
  /** État de chargement */
  loading?: boolean;
  /** Largeur du drawer */
  size?: "sm" | "md" | "lg" | "xl";
}

/**
 * Génère un schéma Zod depuis la configuration des champs
 */
function generateSchema(fields: FormFieldConfig[]): z.ZodObject<any> {
  const shape: Record<string, z.ZodType<any>> = {};

  fields.forEach((field) => {
    if (field.validation) {
      shape[field.key] = field.validation;
      return;
    }

    let schema: z.ZodType<any>;

    switch (field.type) {
      case "email":
        schema = z.string().email("Email invalide");
        break;
      case "number":
      case "currency":
      case "percent":
        schema = z.coerce.number();
        if (field.min !== undefined) schema = (schema as z.ZodNumber).min(field.min);
        if (field.max !== undefined) schema = (schema as z.ZodNumber).max(field.max);
        break;
      case "boolean":
        schema = z.boolean();
        break;
      case "date":
        schema = z.date();
        break;
      default:
        schema = z.string();
    }

    if (!field.required) {
      schema = schema.optional();
    }

    shape[field.key] = schema;
  });

  return z.object(shape);
}

export function EntityFormDrawer({
  open,
  onClose,
  title,
  description,
  fields,
  initialData,
  onSubmit,
  loading = false,
  size = "md",
}: EntityFormDrawerProps) {
  const [isSubmitting, setIsSubmitting] = useState(false);

  const schema = generateSchema(fields);

  const form = useForm({
    resolver: zodResolver(schema),
    defaultValues: initialData || {},
  });

  // Réinitialiser le formulaire quand les données initiales changent
  useEffect(() => {
    if (initialData) {
      form.reset(initialData);
    } else {
      const defaults: Record<string, any> = {};
      fields.forEach((field) => {
        defaults[field.key] = field.defaultValue ?? "";
      });
      form.reset(defaults);
    }
  }, [initialData, fields, form]);

  const handleSubmit = async (data: Record<string, any>) => {
    try {
      setIsSubmitting(true);
      await onSubmit(data);
      onClose();
      form.reset();
    } catch (error) {
      console.error("Erreur lors de la soumission:", error);
    } finally {
      setIsSubmitting(false);
    }
  };

  const renderField = (field: FormFieldConfig) => {
    return (
      <FormField
        key={field.key}
        control={form.control}
        name={field.key}
        render={({ field: formField }) => (
          <FormItem>
            <FormLabel>
              {field.label}
              {field.required && <span className="text-destructive ml-1">*</span>}
            </FormLabel>
            <FormControl>
              {field.type === "textarea" ? (
                <Textarea
                  {...formField}
                  placeholder={field.placeholder}
                  disabled={field.disabled || loading}
                  rows={4}
                />
              ) : field.type === "select" ? (
                <Select
                  onValueChange={formField.onChange}
                  defaultValue={formField.value}
                  disabled={field.disabled || loading}
                >
                  <SelectTrigger>
                    <SelectValue placeholder={field.placeholder || "Sélectionner..."} />
                  </SelectTrigger>
                  <SelectContent>
                    {field.options?.map((option) => (
                      <SelectItem key={option.value} value={option.value}>
                        {option.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              ) : field.type === "boolean" ? (
                <div className="flex items-center gap-2">
                  <Switch
                    checked={formField.value}
                    onCheckedChange={formField.onChange}
                    disabled={field.disabled || loading}
                  />
                  <span className="text-sm text-muted-foreground">
                    {formField.value ? "Oui" : "Non"}
                  </span>
                </div>
              ) : field.type === "date" ? (
                <Popover>
                  <PopoverTrigger asChild>
                    <Button
                      variant="outline"
                      className={cn(
                        "w-full justify-start text-left font-normal",
                        !formField.value && "text-muted-foreground"
                      )}
                      disabled={field.disabled || loading}
                    >
                      <CalendarIcon className="mr-2 h-4 w-4" />
                      {formField.value ? (
                        format(new Date(formField.value), "PPP", { locale: fr })
                      ) : (
                        <span>{field.placeholder || "Sélectionner une date"}</span>
                      )}
                    </Button>
                  </PopoverTrigger>
                  <PopoverContent className="w-auto p-0" align="start">
                    <Calendar
                      mode="single"
                      selected={formField.value ? new Date(formField.value) : undefined}
                      onSelect={formField.onChange}
                      locale={fr}
                      initialFocus
                    />
                  </PopoverContent>
                </Popover>
              ) : field.type === "currency" ? (
                <div className="relative">
                  <Input
                    {...formField}
                    type="number"
                    placeholder={field.placeholder}
                    disabled={field.disabled || loading}
                    className="pr-12"
                  />
                  <span className="absolute right-3 top-1/2 -translate-y-1/2 text-sm text-muted-foreground">
                    XAF
                  </span>
                </div>
              ) : field.type === "percent" ? (
                <div className="relative">
                  <Input
                    {...formField}
                    type="number"
                    placeholder={field.placeholder}
                    disabled={field.disabled || loading}
                    min={0}
                    max={100}
                    step={0.1}
                    className="pr-8"
                  />
                  <span className="absolute right-3 top-1/2 -translate-y-1/2 text-sm text-muted-foreground">
                    %
                  </span>
                </div>
              ) : (
                <Input
                  {...formField}
                  type={field.type === "number" ? "number" : field.type === "email" ? "email" : "text"}
                  placeholder={field.placeholder}
                  disabled={field.disabled || loading}
                  min={field.min}
                  max={field.max}
                />
              )}
            </FormControl>
            {field.description && (
              <FormDescription>{field.description}</FormDescription>
            )}
            <FormMessage />
          </FormItem>
        )}
      />
    );
  };

  const sizeClasses = {
    sm: "max-w-sm",
    md: "max-w-md",
    lg: "max-w-lg",
    xl: "max-w-xl",
  };

  return (
    <Sheet open={open} onOpenChange={onClose}>
      <SheetContent className={cn("overflow-y-auto", sizeClasses[size])}>
        <SheetHeader>
          <SheetTitle>{title}</SheetTitle>
          {description && <SheetDescription>{description}</SheetDescription>}
        </SheetHeader>

        <Form {...form}>
          <form
            onSubmit={form.handleSubmit(handleSubmit)}
            className="mt-6 space-y-6"
          >
            <div className="space-y-4">
              {fields.map((field) => renderField(field))}
            </div>

            <div className="flex gap-3 pt-4">
              <Button
                type="button"
                variant="outline"
                onClick={onClose}
                disabled={isSubmitting || loading}
                className="flex-1"
              >
                Annuler
              </Button>
              <Button
                type="submit"
                disabled={isSubmitting || loading}
                className="flex-1"
              >
                {isSubmitting || loading ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Enregistrement...
                  </>
                ) : (
                  <>
                    <Save className="mr-2 h-4 w-4" />
                    Enregistrer
                  </>
                )}
              </Button>
            </div>
          </form>
        </Form>
      </SheetContent>
    </Sheet>
  );
}
