/**
 * Formatage des montants et nombres pour EdenFin
 * Conformité OHADA/CEMAC avec devise XAF
 */

const numberFormatter = new Intl.NumberFormat("fr-FR", {
  maximumFractionDigits: 0,
});

const decimalFormatter = new Intl.NumberFormat("fr-FR", {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

/**
 * Formatte un montant en XAF (FCFA)
 * @param amount - Montant à formater
 * @param showCurrency - Afficher "XAF" à la fin (défaut: true)
 * @returns Montant formatté (ex: "1 250 000 XAF")
 */
export function formatXAF(
  amount: number | string | null | undefined,
  showCurrency = true
): string {
  const n = typeof amount === "string" ? Number(amount) : amount ?? 0;
  if (n === 0) return "—";
  const formatted = numberFormatter.format(n);
  return showCurrency ? `${formatted} XAF` : formatted;
}

/**
 * Formatte un nombre entier
 * @param value - Valeur à formater
 * @returns Nombre formatté (ex: "1 250")
 */
export function formatNumber(
  value: number | string | null | undefined
): string {
  const n = typeof value === "string" ? Number(value) : value ?? 0;
  if (n === 0) return "—";
  return numberFormatter.format(n);
}

/**
 * Formatte un montant avec décimales
 * @param amount - Montant à formater
 * @param showCurrency - Afficher "XAF" à la fin (défaut: true)
 * @returns Montant formatté (ex: "1 250 000,50 XAF")
 */
export function formatAmount(
  amount: number | string | null | undefined,
  showCurrency = true
): string {
  const n = typeof amount === "string" ? Number(amount) : amount ?? 0;
  if (n === 0) return "—";
  const formatted = decimalFormatter.format(n);
  return showCurrency ? `${formatted} XAF` : formatted;
}

/**
 * Formatte une date au format français
 * @param date - Date ISO ou objet Date
 * @param format - Format souhaité ("short" | "long")
 * @returns Date formatée (ex: "15/02/2026")
 */
export function formatDate(
  date: string | Date | null | undefined,
  format: "short" | "long" = "short"
): string {
  if (!date) return "—";
  const d = typeof date === "string" ? new Date(date) : date;
  if (Number.isNaN(d.getTime())) return "—";

  if (format === "long") {
    return d.toLocaleDateString("fr-FR", {
      day: "numeric",
      month: "long",
      year: "numeric",
    });
  }

  return d.toLocaleDateString("fr-FR");
}

/**
 * Formatte un pourcentage
 * @param value - Valeur à formater (0.15 = 15%)
 * @param decimals - Nombre de décimales (défaut: 1)
 * @returns Pourcentage formatté (ex: "15,0%")
 */
export function formatPercent(
  value: number | null | undefined,
  decimals = 1
): string {
  if (value === null || value === undefined) return "—";
  const formatter = new Intl.NumberFormat("fr-FR", {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  });
  return `${formatter.format(value * 100)}%`;
}

/**
 * Formatte une période comptable
 * @param fiscalYear - Année fiscale
 * @param period - Mois (1-12)
 * @returns Période formatée (ex: "Février 2026")
 */
export function formatPeriod(fiscalYear: number, period: number): string {
  const date = new Date(fiscalYear, period - 1, 1);
  return date
    .toLocaleDateString("fr-FR", { month: "long", year: "numeric" })
    .replace(/^./, (c) => c.toUpperCase());
}

/**
 * Formatte un numéro de compte OHADA
 * @param accountNumber - Numéro de compte (ex: "601200")
 * @returns Compte formatté (ex: "601 200")
 */
export function formatAccount(accountNumber: string): string {
  if (!accountNumber) return "—";
  // Formate par groupe de 3: 601200 → 601 200
  return accountNumber.replace(/(\d{3})(?=\d)/g, "$1 ");
}
