# Airtel Money — Client API (`src/lib/airtel.server.ts`)

This document is the contract reference for any server-side code that talks to
Airtel Money Africa. **All new code MUST go through `IAirtelClient` and the
typed request/response models** — never re-implement raw `fetch` calls and
never depend on the deprecated `airtel*` free functions.

> ⚠️ Server-only module. Do NOT import from client/browser bundles.

---

## 1. Public surface (overview)

| Symbol | Kind | Purpose |
| --- | --- | --- |
| `IAirtelClient` | `interface` | Stable contract every Airtel client (prod, UAT, mock) must implement |
| `AirtelClient` | `class implements IAirtelClient` | Default implementation (OAuth + REST against Airtel Open API) |
| `getAirtelClient()` | `() => IAirtelClient` | Returns the process-wide singleton — **the only accessor app code should use** |
| `setDefaultAirtelClient(client)` | test helper | Inject a custom/mock client; pass `null` to reset |
| `normalizeAirtelStatus(code)` | helper | Maps an `AirtelTransactionStatusCode` to `"succeeded" \| "failed" \| "pending"` |
| `AirtelCollectionInput` / `AirtelCollectionResponse` | types | Payment-initiation models |
| `AirtelStatusInput` / `AirtelStatusResponse` | types | Status-enquiry models |
| `AirtelTokenResponse`, `AirtelStatusBlock`, `AirtelCollectionTransaction`, `AirtelStatusTransaction` | types | Sub-shapes used by the responses |
| `AirtelCountry`, `AirtelCurrency`, `AirtelTransactionStatusCode`, `AirtelNormalizedStatus` | string-literal unions | Strongly-typed enums |
| `FetchLike` | type | `fetch`-compatible signature for dependency injection |
| `AirtelClientOptions` | type | Constructor options for `AirtelClient` |
| `getAirtelAccessToken` / `airtelInitiateCollection` / `airtelGetTransactionStatus` | `@deprecated` wrappers | Kept for backwards compatibility only — do not use in new code |

---

## 2. `IAirtelClient` — the contract

```ts
export interface IAirtelClient {
  getAccessToken(): Promise<string>;
  initiateCollection(input: AirtelCollectionInput): Promise<AirtelCollectionResponse>;
  getTransactionStatus(input: AirtelStatusInput): Promise<AirtelStatusResponse>;
}
```

Rules for implementers and consumers:

- **Implementers** (prod / UAT / mock) must implement all three methods and
  honour the documented error semantics:
  - `getAccessToken` throws `Error("Airtel non configuré …")` when credentials
    are missing, and `Error("Airtel OAuth: <reason>")` on HTTP failure.
  - `initiateCollection` throws `Error("Airtel Collection: <reason>")` when
    `status.success !== true` or HTTP is not OK. **On success it returns the
    full `AirtelCollectionResponse`** (never `void`).
  - `getTransactionStatus` does **not** throw on a non-success transaction
    code (`TF`, `TE`, `TA`, …). It only throws on transport/parse errors.
    Callers must inspect `data.transaction.status` and pass it through
    `normalizeAirtelStatus`.
- **Consumers** never construct `AirtelClient` directly outside tests. They
  obtain an instance via `getAirtelClient()` so the same singleton (and its
  token cache) is reused across the process.

---

## 3. `getAirtelClient()` — the only accessor

```ts
import { getAirtelClient } from "@/lib/airtel.server";

const client = getAirtelClient(); // typed as IAirtelClient
```

- Returns a lazily-instantiated singleton (`AirtelClient` by default).
- Reads `AIRTEL_CLIENT_ID`, `AIRTEL_CLIENT_SECRET`, and optionally
  `AIRTEL_BASE_URL` from `process.env` at construction time.
- Caches the OAuth token in-memory until 30 s before expiry — calling
  `getAccessToken()` repeatedly is cheap.
- The returned value is typed as `IAirtelClient`. App code MUST type its local
  variable the same way so the implementation stays swappable:

```ts
const client: IAirtelClient = getAirtelClient();
```

### Replacing the singleton in tests

```ts
import { setDefaultAirtelClient, type IAirtelClient } from "@/lib/airtel.server";

const mock: IAirtelClient = {
  getAccessToken: async () => "mock-token",
  initiateCollection: async () => ({ status: { success: true } }),
  getTransactionStatus: async () => ({
    data: { transaction: { status: "TS", airtel_money_id: "AM-1" } },
    status: { success: true },
  }),
};

beforeEach(() => setDefaultAirtelClient(mock));
afterEach(() => setDefaultAirtelClient(null)); // reset to default
```

### Custom instance (non-singleton)

For ad-hoc usage (e.g. a one-off cron with different credentials), instantiate
`AirtelClient` directly — but still type the variable as `IAirtelClient`:

```ts
import { AirtelClient, type IAirtelClient } from "@/lib/airtel.server";

const client: IAirtelClient = new AirtelClient({
  clientId: process.env.AIRTEL_CLIENT_ID_BACKOFFICE,
  clientSecret: process.env.AIRTEL_CLIENT_SECRET_BACKOFFICE,
  baseUrl: "https://openapi.airtel.africa", // prod
});
```

---

## 4. Request / response models

### 4.1 Initiate a collection (USSD push)

```ts
interface AirtelCollectionInput {
  msisdn: string;             // payer's phone, digits only, no country code
  amount: number;             // in major units (e.g. 1500 XAF)
  currency: AirtelCurrency;   // "XAF" | "XOF" | "KES" | ...
  country: AirtelCountry;     // "GA" | "CG" | "CM" | ...
  reference: string;          // human-readable label shown on the USSD prompt
  transactionId: string;      // YOUR unique merchant transaction id
}

interface AirtelCollectionResponse {
  data?: {
    message?: string;
    status?: string;
    transaction?: AirtelCollectionTransaction; // { id?, status?, airtel_money_id? }
  };
  status?: AirtelStatusBlock;                  // { code?, message?, success?, ... }
}
```

Example:

```ts
const client: IAirtelClient = getAirtelClient();
const input: AirtelCollectionInput = {
  msisdn: "074123456",
  amount: plan.amount_xaf,
  currency: "XAF",
  country: "GA",
  reference: `Abonnement ${plan.name}`,
  transactionId,
};
const resp: AirtelCollectionResponse = await client.initiateCollection(input);
```

### 4.2 Check a transaction status

```ts
interface AirtelStatusInput {
  transactionId: string;
  country: AirtelCountry;
  currency: AirtelCurrency;
}

interface AirtelStatusResponse {
  data?: { transaction?: AirtelStatusTransaction }; // { id?, status?, airtel_money_id?, message? }
  status?: AirtelStatusBlock;
}
```

Canonical polling pattern (matches `checkAirtelStatus` in
`src/lib/subscriptions.functions.ts`):

```ts
const client: IAirtelClient = getAirtelClient();
const res: AirtelStatusResponse = await client.getTransactionStatus({
  transactionId,
  country: "GA",
  currency: "XAF",
});

const tx = res.data?.transaction;
const code: AirtelTransactionStatusCode | null =
  (tx?.status as AirtelTransactionStatusCode | undefined) ?? null;
const mapped: AirtelNormalizedStatus = normalizeAirtelStatus(code);
// mapped is "succeeded" | "failed" | "pending" — safe to persist.
```

### 4.3 Status code reference

| Code  | Meaning                | Normalized |
| ----- | ---------------------- | ---------- |
| `TS`  | Transaction Success    | `succeeded` |
| `TF`  | Transaction Failed     | `failed`    |
| `TE`  | Transaction Expired    | `failed`    |
| `TA`  | Transaction Ambiguous  | `pending` (re-poll) |
| `TIP` | Transaction In Progress| `pending`   |
| `null`/unknown | —             | `pending`   |

Always go through `normalizeAirtelStatus()` — do not hand-roll the mapping.

---

## 4.4 End-to-end example: initiate then poll

The snippet below shows a complete merchant flow — **initiate a collection,
then poll the status until it resolves** — using `IAirtelClient` and
`getAirtelClient()` exclusively. It mirrors what
`initiateAirtelPayment` + `checkAirtelStatus` do in
`src/lib/subscriptions.functions.ts`, but stripped down to the Airtel calls
so it is reusable in scripts, cron jobs, or new server functions.

```ts
// src/lib/examples/airtel-end-to-end.ts (server-only)
import {
  getAirtelClient,
  normalizeAirtelStatus,
} from "@/lib/airtel.server";
import type {
  AirtelCollectionInput,
  AirtelCollectionResponse,
  AirtelNormalizedStatus,
  AirtelStatusInput,
  AirtelStatusResponse,
  AirtelTransactionStatusCode,
  IAirtelClient,
} from "@/lib/airtel.server";

export interface ChargeOutcome {
  transactionId: string;
  status: AirtelNormalizedStatus;            // "succeeded" | "failed" | "pending"
  airtelStatusCode: AirtelTransactionStatusCode | null;
  airtelMoneyId: string | null;
  message: string | null;
}

/**
 * Charge an Airtel Money subscriber end-to-end:
 *   1. push a USSD collection request,
 *   2. poll the status until it leaves the "pending" state (or attempts run out).
 *
 * Only depends on `IAirtelClient` — the concrete client comes from
 * `getAirtelClient()` and can be swapped in tests via `setDefaultAirtelClient`.
 */
export async function chargeAirtel(params: {
  msisdn: string;
  amountXaf: number;
  label: string;
  transactionId: string;
  /** Optional override — defaults to the process-wide singleton. */
  client?: IAirtelClient;
  /** Polling tuning. */
  maxAttempts?: number;
  delayMs?: number;
}): Promise<ChargeOutcome> {
  const client: IAirtelClient = params.client ?? getAirtelClient();

  // ---- 1) Initiate the collection ------------------------------------------
  const collectionInput: AirtelCollectionInput = {
    msisdn: params.msisdn,
    amount: params.amountXaf,
    currency: "XAF",
    country: "GA",
    reference: params.label,
    transactionId: params.transactionId,
  };

  // Throws on transport / "status.success !== true" — let the caller handle it.
  const initResp: AirtelCollectionResponse =
    await client.initiateCollection(collectionInput);

  // ---- 2) Poll the transaction status --------------------------------------
  const statusInput: AirtelStatusInput = {
    transactionId: params.transactionId,
    country: "GA",
    currency: "XAF",
  };

  const maxAttempts = params.maxAttempts ?? 6;
  const delayMs = params.delayMs ?? 3000;

  let last: AirtelStatusResponse | null = null;
  for (let i = 0; i < maxAttempts; i++) {
    if (i > 0) await new Promise((r) => setTimeout(r, delayMs));

    last = await client.getTransactionStatus(statusInput);
    const code = (last.data?.transaction?.status ??
      null) as AirtelTransactionStatusCode | null;
    const mapped: AirtelNormalizedStatus = normalizeAirtelStatus(code);

    if (mapped !== "pending") {
      return {
        transactionId: params.transactionId,
        status: mapped,
        airtelStatusCode: code,
        airtelMoneyId: last.data?.transaction?.airtel_money_id ?? null,
        message:
          last.data?.transaction?.message ?? last.status?.message ?? null,
      };
    }
  }

  // Timed out while still pending — surface what we have.
  const code = (last?.data?.transaction?.status ??
    null) as AirtelTransactionStatusCode | null;
  return {
    transactionId: params.transactionId,
    status: "pending",
    airtelStatusCode: code,
    airtelMoneyId: last?.data?.transaction?.airtel_money_id ?? null,
    message:
      last?.data?.transaction?.message ??
      last?.status?.message ??
      initResp.data?.message ??
      null,
  };
}
```

### Calling it

```ts
import { chargeAirtel } from "@/lib/examples/airtel-end-to-end";

const outcome = await chargeAirtel({
  msisdn: "074123456",
  amountXaf: 1500,
  label: "Abonnement EdenFin Pro",
  transactionId: `EFA-${userId.slice(0, 8)}-${Date.now()}`,
});

switch (outcome.status) {
  case "succeeded":
    // mark the payment as paid, provision the subscription, ...
    break;
  case "failed":
    // surface outcome.message to the user, log outcome.airtelStatusCode
    break;
  case "pending":
    // schedule a follow-up poll (webhook / cron / next page load)
    break;
}
```

### Testing it without the network

```ts
import { setDefaultAirtelClient, type IAirtelClient } from "@/lib/airtel.server";
import { chargeAirtel } from "@/lib/examples/airtel-end-to-end";

const mock: IAirtelClient = {
  getAccessToken: async () => "tok",
  initiateCollection: async () => ({ status: { success: true } }),
  getTransactionStatus: async () => ({
    data: { transaction: { status: "TS", airtel_money_id: "AM-1" } },
    status: { success: true },
  }),
};

setDefaultAirtelClient(mock);
const outcome = await chargeAirtel({
  msisdn: "074123456",
  amountXaf: 1500,
  label: "test",
  transactionId: "TX-1",
  delayMs: 0,
});
// outcome.status === "succeeded", outcome.airtelMoneyId === "AM-1"
setDefaultAirtelClient(null); // reset
```

---



## 5. Do / Don't

✅ **Do**
- `import { getAirtelClient, normalizeAirtelStatus } from "@/lib/airtel.server"`
- `import type { IAirtelClient, AirtelCollectionInput, ... } from "@/lib/airtel.server"`
- Type local variables as `IAirtelClient` / `AirtelCollectionResponse` / `AirtelStatusResponse`.
- Use `AirtelCountry` / `AirtelCurrency` literals (`"GA"`, `"XAF"`) instead of free-form strings.
- Inject mocks in tests via `setDefaultAirtelClient`.

❌ **Don't**
- Don't call `getAirtelAccessToken`, `airtelInitiateCollection`, or
  `airtelGetTransactionStatus` — they are `@deprecated` shims kept for one
  release window and will be removed.
- Don't construct `AirtelClient` inside request handlers (you'd lose the token cache).
- Don't compare raw status strings (`tx.status === "TS"`) — use `normalizeAirtelStatus`.
- Don't import `airtel.server.ts` from client/browser code or `*.functions.ts`
  module scope that ships to the browser.

---

## 6. Reference implementation in the codebase

- `src/lib/airtel.server.ts` — types, `AirtelClient`, `getAirtelClient`, helpers.
- `src/lib/subscriptions.functions.ts` — `initiateAirtelPayment` and
  `checkAirtelStatus` are the canonical consumers; mirror their typing when
  adding new server functions.
- `src/lib/airtel.server.test.ts` — shows the recommended mocking strategy via
  `AirtelClient({ fetch: vi.fn(...) })` and `setDefaultAirtelClient`.
- `src/routes/api/public/airtel-webhook.ts` — server route consuming the same
  types for webhook callbacks.
