import { describe, it, expect, beforeEach, vi } from "vitest";
import { AirtelClient, type FetchLike } from "./airtel.server";

/**
 * Mocks de la réponse Airtel Money (UAT) pour stabiliser les tests
 * et supprimer toute dépendance réseau.
 */
export const airtelMocks = {
  oauthToken: {
    status: "Success",
    access_token: "mock-access-token",
    token_type: "Bearer",
    expires_in: 3600,
  },
  collectionSuccess: {
    data: {
      transaction: {
        id: "TestId24",
        status: "SUCCESS",
        airtel_money_id: "0d265a800cb14826add549d08fcadcd0",
      },
    },
    status: {
      response_code: "DP01000001001",
      code: "200",
      success: true,
      result_code: "ESB000010",
      message: "SUCCESS",
    },
  },
  collectionFailure: {
    data: { transaction: { id: "TestId25", status: "FAILED" } },
    status: {
      response_code: "DP00900001005",
      code: "200",
      success: false,
      message: "Transaction Failed",
    },
  },
  statusSuccess: {
    data: {
      transaction: {
        id: "TestId24",
        status: "TS",
        airtel_money_id: "0d265a800cb14826add549d08fcadcd0",
        message: "Transaction Successfull",
      },
    },
    status: { code: "200", message: "SUCCESS", success: true },
  },
  statusFailed: {
    data: {
      transaction: { id: "TestId25", status: "TF", message: "Failed" },
    },
    status: { code: "200", message: "SUCCESS", success: true },
  },
} as const;

function jsonResponse(body: unknown, ok = true) {
  return {
    ok,
    statusText: ok ? "OK" : "Error",
    json: async () => body,
  } as unknown as Response;
}

/** Construit un client Airtel équipé d'un `fetch` mocké et de credentials de test. */
function makeClient(fetchMock: ReturnType<typeof vi.fn>) {
  return new AirtelClient({
    fetch: fetchMock as unknown as FetchLike,
    baseUrl: "https://openapiuat.airtel.africa",
    clientId: "test-id",
    clientSecret: "test-secret",
  });
}

describe("AirtelClient (fetch injecté)", () => {
  let fetchMock: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    fetchMock = vi.fn();
  });

  it("récupère un token OAuth puis initie une collection avec succès", async () => {
    fetchMock
      .mockResolvedValueOnce(jsonResponse(airtelMocks.oauthToken))
      .mockResolvedValueOnce(jsonResponse(airtelMocks.collectionSuccess));

    const client = makeClient(fetchMock);
    const res = await client.initiateCollection({
      msisdn: "074123456",
      amount: 100,
      currency: "XAF",
      country: "GA",
      reference: "ref-1",
      transactionId: "TestId24",
    });

    expect(res.status?.success).toBe(true);
    expect(res.data?.transaction?.airtel_money_id).toBe(
      "0d265a800cb14826add549d08fcadcd0",
    );

    const [, collectCall] = fetchMock.mock.calls;
    expect(collectCall[0]).toContain("/merchant/v1/payments/");
    const headers = collectCall[1].headers as Record<string, string>;
    expect(headers["X-Country"]).toBe("GA");
    expect(headers["X-Currency"]).toBe("XAF");
    expect(headers.Authorization).toBe("Bearer mock-access-token");
  });

  it("propage une erreur quand Airtel renvoie un échec de collection", async () => {
    fetchMock
      .mockResolvedValueOnce(jsonResponse(airtelMocks.oauthToken))
      .mockResolvedValueOnce(jsonResponse(airtelMocks.collectionFailure));

    const client = makeClient(fetchMock);
    await expect(
      client.initiateCollection({
        msisdn: "074123456",
        amount: 100,
        currency: "XAF",
        country: "GA",
        reference: "ref-2",
        transactionId: "TestId25",
      }),
    ).rejects.toThrow(/Airtel Collection/);
  });

  it("renvoie le statut TS (succès) d'une transaction", async () => {
    fetchMock
      .mockResolvedValueOnce(jsonResponse(airtelMocks.oauthToken))
      .mockResolvedValueOnce(jsonResponse(airtelMocks.statusSuccess));

    const client = makeClient(fetchMock);
    const res = await client.getTransactionStatus({
      transactionId: "TestId24",
      country: "GA",
      currency: "XAF",
    });
    expect(res.data?.transaction?.status).toBe("TS");
    expect(res.data?.transaction?.airtel_money_id).toBe(
      "0d265a800cb14826add549d08fcadcd0",
    );
  });

  it("renvoie le statut TF (échec) d'une transaction", async () => {
    fetchMock
      .mockResolvedValueOnce(jsonResponse(airtelMocks.oauthToken))
      .mockResolvedValueOnce(jsonResponse(airtelMocks.statusFailed));

    const client = makeClient(fetchMock);
    const res = await client.getTransactionStatus({
      transactionId: "TestId25",
      country: "GA",
      currency: "XAF",
    });
    expect(res.data?.transaction?.status).toBe("TF");
  });

  it("met en cache le token OAuth entre deux appels", async () => {
    fetchMock
      .mockResolvedValueOnce(jsonResponse(airtelMocks.oauthToken))
      .mockResolvedValueOnce(jsonResponse(airtelMocks.statusSuccess))
      .mockResolvedValueOnce(jsonResponse(airtelMocks.statusFailed));

    const client = makeClient(fetchMock);
    await client.getTransactionStatus({
      transactionId: "TestId24",
      country: "GA",
      currency: "XAF",
    });
    await client.getTransactionStatus({
      transactionId: "TestId25",
      country: "GA",
      currency: "XAF",
    });
    // 1 appel OAuth + 2 appels status = 3
    expect(fetchMock).toHaveBeenCalledTimes(3);
  });

  it("échoue proprement si les identifiants OAuth sont absents", async () => {
    vi.stubEnv("AIRTEL_CLIENT_ID", "");
    vi.stubEnv("AIRTEL_CLIENT_SECRET", "");
    try {
      const client = new AirtelClient({
        fetch: fetchMock as unknown as FetchLike,
      });
      await expect(client.getAccessToken()).rejects.toThrow(/Airtel non configuré/);
      expect(fetchMock).not.toHaveBeenCalled();
    } finally {
      vi.unstubAllEnvs();
    }
  });
});
