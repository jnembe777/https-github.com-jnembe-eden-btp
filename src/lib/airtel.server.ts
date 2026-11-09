/**
 * Airtel Money (Africa Open API) helpers — UAT/sandbox.
 *
 * Ce module expose :
 *   - Une **interface stable** (`IAirtelClient`) pour mocker / substituer
 *     facilement le client dans les tests ou dans une autre implémentation
 *     (par exemple un client de prod, un client offline, etc.).
 *   - Des **types de réponse précis** (codes pays, devises, statuts de
 *     transaction, codes Airtel) afin d'éviter les `string` opaques côté
 *     applicatif et de bénéficier de l'autocomplétion / vérification TS.
 *
 * Server-only : lit `AIRTEL_CLIENT_ID` / `AIRTEL_CLIENT_SECRET` depuis
 * `process.env` par défaut, mais tout peut être injecté via `AirtelClientOptions`.
 */

// =====================================================================
// Types publics (stables — utilisés par le code applicatif et les tests)
// =====================================================================

/** Implémentation `fetch` compatible (browser/Node/Workers). */
export type FetchLike = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

/** Pays supportés par Airtel Money Africa. */
export type AirtelCountry =
  | "GA" // Gabon
  | "CG" // Congo Brazzaville
  | "CD" // RDC
  | "CM" // Cameroun
  | "TD" // Tchad
  | "CF" // Centrafrique
  | "GQ" // Guinée Équatoriale
  | "GN" // Guinée
  | "KE" // Kenya
  | "TZ" // Tanzanie
  | "UG" // Ouganda
  | "RW" // Rwanda
  | "ZM" // Zambie
  | "MW" // Malawi
  | "MG" // Madagascar
  | "NE" // Niger
  | "NG"; // Nigeria

/** Devises Airtel Money (ISO 4217). */
export type AirtelCurrency =
  | "XAF"
  | "XOF"
  | "KES"
  | "TZS"
  | "UGX"
  | "RWF"
  | "ZMW"
  | "MWK"
  | "MGA"
  | "NGN"
  | "CDF";

/**
 * Codes de statut transaction Airtel.
 * - `TS` : Transaction Success
 * - `TF` : Transaction Failed
 * - `TA` : Transaction Ambiguous (à re-vérifier)
 * - `TIP` : Transaction In Progress
 * - `TE` : Transaction Expired
 */
export type AirtelTransactionStatusCode = "TS" | "TF" | "TA" | "TIP" | "TE";

/** Forme normalisée — utile côté applicatif pour mapper en `succeeded|failed|pending`. */
export type AirtelNormalizedStatus = "succeeded" | "failed" | "pending";

export interface AirtelClientOptions {
  /** Implémentation `fetch` à utiliser (par défaut : `globalThis.fetch`). */
  fetch?: FetchLike;
  /** Base URL de l'API Airtel (par défaut : env `AIRTEL_BASE_URL` ou UAT). */
  baseUrl?: string;
  /** Identifiants OAuth — par défaut lus dans `process.env`. */
  clientId?: string;
  clientSecret?: string;
  /** Horloge injectable (utile pour tester l'expiration du token). */
  now?: () => number;
}

export interface AirtelCollectionInput {
  /** Numéro de téléphone du payeur (sans indicatif, ex: 074123456). */
  msisdn: string;
  /** Montant en unité monétaire. */
  amount: number;
  /** Devise ISO. */
  currency: AirtelCurrency;
  /** Code pays Airtel. */
  country: AirtelCountry;
  /** Identifiant unique externe (apparaît côté Airtel). */
  reference: string;
  /** ID transaction côté marchand. */
  transactionId: string;
}

export interface AirtelStatusInput {
  transactionId: string;
  country: AirtelCountry;
  currency: AirtelCurrency;
}

/** Bloc `status` commun à toutes les réponses Airtel. */
export interface AirtelStatusBlock {
  code?: string;
  message?: string;
  success?: boolean;
  response_code?: string;
  result_code?: string;
}

/** Réponse OAuth Airtel. */
export interface AirtelTokenResponse {
  status?: string;
  access_token?: string;
  token_type?: string;
  expires_in?: number;
  error?: string;
}

/** Sous-objet `transaction` renvoyé par l'API Collection. */
export interface AirtelCollectionTransaction {
  id?: string;
  status?: string;
  airtel_money_id?: string;
}

export interface AirtelCollectionResponse {
  data?: {
    message?: string;
    status?: string;
    transaction?: AirtelCollectionTransaction;
  };
  status?: AirtelStatusBlock;
}

/** Sous-objet `transaction` renvoyé par l'API Enquiry / Status. */
export interface AirtelStatusTransaction {
  id?: string;
  status?: AirtelTransactionStatusCode | string;
  airtel_money_id?: string;
  message?: string;
}

export interface AirtelStatusResponse {
  data?: { transaction?: AirtelStatusTransaction };
  status?: AirtelStatusBlock;
}

/**
 * Contrat public stable du client Airtel.
 * Toute alternative (mock de test, client de prod custom, etc.) doit
 * implémenter cette interface.
 */
export interface IAirtelClient {
  /** Récupère (ou réutilise depuis le cache) un access token OAuth. */
  getAccessToken(): Promise<string>;
  /** Lance une demande de paiement (push USSD). */
  initiateCollection(
    input: AirtelCollectionInput,
  ): Promise<AirtelCollectionResponse>;
  /** Interroge le statut d'une transaction existante. */
  getTransactionStatus(input: AirtelStatusInput): Promise<AirtelStatusResponse>;
}

// =====================================================================
// Helpers
// =====================================================================

/** Convertit un code Airtel en statut applicatif normalisé. */
export function normalizeAirtelStatus(
  code: string | null | undefined,
): AirtelNormalizedStatus {
  if (code === "TS") return "succeeded";
  if (code === "TF" || code === "TE") return "failed";
  return "pending";
}

// =====================================================================
// Implémentation
// =====================================================================

export class AirtelClient implements IAirtelClient {
  private readonly fetchImpl: FetchLike;
  private readonly baseUrl: string;
  private readonly clientId?: string;
  private readonly clientSecret?: string;
  private readonly now: () => number;
  private tokenCache: { token: string; expiresAt: number } | null = null;

  constructor(options: AirtelClientOptions = {}) {
    this.fetchImpl = options.fetch ?? ((...args) => globalThis.fetch(...args));
    this.baseUrl =
      options.baseUrl ??
      process.env.AIRTEL_BASE_URL ??
      "https://openapiuat.airtel.africa";
    this.clientId = options.clientId ?? process.env.AIRTEL_CLIENT_ID;
    this.clientSecret =
      options.clientSecret ?? process.env.AIRTEL_CLIENT_SECRET;
    this.now = options.now ?? (() => Date.now());
  }

  async getAccessToken(): Promise<string> {
    if (!this.clientId || !this.clientSecret) {
      throw new Error(
        "Airtel non configuré : définissez AIRTEL_CLIENT_ID et AIRTEL_CLIENT_SECRET.",
      );
    }
    if (this.tokenCache && this.tokenCache.expiresAt > this.now() + 30_000) {
      return this.tokenCache.token;
    }

    const res = await this.fetchImpl(`${this.baseUrl}/auth/oauth2/token`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "*/*" },
      body: JSON.stringify({
        client_id: this.clientId,
        client_secret: this.clientSecret,
        grant_type: "client_credentials",
      }),
    });
    const body = (await res.json()) as AirtelTokenResponse;
    if (!res.ok || !body.access_token) {
      throw new Error(`Airtel OAuth: ${body.error ?? res.statusText}`);
    }
    this.tokenCache = {
      token: body.access_token,
      expiresAt: this.now() + (body.expires_in ?? 3600) * 1000,
    };
    return body.access_token;
  }

  async initiateCollection(
    input: AirtelCollectionInput,
  ): Promise<AirtelCollectionResponse> {
    const token = await this.getAccessToken();
    const res = await this.fetchImpl(`${this.baseUrl}/merchant/v1/payments/`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "*/*",
        "X-Country": input.country,
        "X-Currency": input.currency,
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        reference: input.reference,
        subscriber: { msisdn: input.msisdn },
        transaction: {
          amount: String(input.amount),
          id: input.transactionId,
        },
      }),
    });
    const body = (await res.json()) as AirtelCollectionResponse;
    if (!res.ok || !body.status?.success) {
      throw new Error(
        `Airtel Collection: ${body.status?.message ?? body.data?.message ?? res.statusText}`,
      );
    }
    return body;
  }

  async getTransactionStatus(
    input: AirtelStatusInput,
  ): Promise<AirtelStatusResponse> {
    const token = await this.getAccessToken();
    const res = await this.fetchImpl(
      `${this.baseUrl}/standard/v1/payments/${encodeURIComponent(input.transactionId)}`,
      {
        method: "GET",
        headers: {
          Accept: "*/*",
          "X-Country": input.country,
          "X-Currency": input.currency,
          Authorization: `Bearer ${token}`,
        },
      },
    );
    return (await res.json()) as AirtelStatusResponse;
  }
}

// =====================================================================
// Singleton process-wide + API rétrocompatible
// =====================================================================

let defaultClient: IAirtelClient | null = null;

/** Retourne le client Airtel partagé (singleton process-wide). */
export function getAirtelClient(): IAirtelClient {
  if (!defaultClient) defaultClient = new AirtelClient();
  return defaultClient;
}

/** Permet aux tests d'injecter un client custom (ou de reset avec `null`). */
export function setDefaultAirtelClient(client: IAirtelClient | null) {
  defaultClient = client;
}

// --- Wrappers rétrocompatibles (déprécié : préférer `getAirtelClient()`) ---

/** @deprecated utiliser `getAirtelClient().getAccessToken()`. */
export function getAirtelAccessToken(): Promise<string> {
  return getAirtelClient().getAccessToken();
}

/** @deprecated utiliser `getAirtelClient().initiateCollection(...)`. */
export function airtelInitiateCollection(
  input: AirtelCollectionInput,
): Promise<AirtelCollectionResponse> {
  return getAirtelClient().initiateCollection(input);
}

/** @deprecated utiliser `getAirtelClient().getTransactionStatus(...)`. */
export function airtelGetTransactionStatus(
  input: AirtelStatusInput,
): Promise<AirtelStatusResponse> {
  return getAirtelClient().getTransactionStatus(input);
}
