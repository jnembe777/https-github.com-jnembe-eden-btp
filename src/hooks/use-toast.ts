/**
 * Hook de notification (toast) — compatibilité API « shadcn » au-dessus de sonner.
 *
 * Le dépôt utilise sonner (`src/components/ui/sonner.tsx`) comme système de
 * toasts, mais plusieurs modules importaient `@/hooks/use-toast` (API shadcn :
 * `const { toast } = useToast(); toast({ title, description, variant })`) qui
 * n'existait pas — import cassé. Ce fichier fournit cette API en la mappant sur
 * sonner, sans changer les appels existants.
 */

import { toast as sonnerToast } from "sonner";

export interface ToastOptions {
  title?: string;
  description?: string;
  /** "destructive" => toast d'erreur ; sinon toast standard. */
  variant?: "default" | "destructive";
}

/** Déclenche un toast à partir des options façon shadcn. */
export function toast({ title, description, variant }: ToastOptions): void {
  const message = title ?? description ?? "";
  // sonner accepte une description secondaire quand un titre principal existe.
  const opts = title && description ? { description } : undefined;

  if (variant === "destructive") {
    sonnerToast.error(message, opts);
  } else {
    sonnerToast.success(message, opts);
  }
}

/**
 * Hook renvoyant l'API toast (titre/description/variant).
 * Conserve la signature attendue par les composants : `const { toast } = useToast();`
 */
export function useToast() {
  return { toast };
}

export default useToast;
