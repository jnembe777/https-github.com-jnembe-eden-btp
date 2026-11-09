import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { AirtelStatusCard } from "./airtel-status-card";

const base = {
  transactionId: "EFA-abc-123",
  airtelStatusCode: "TS",
  airtelMoneyId: "amid-xyz",
  message: "Transaction Successfull",
};

describe("AirtelStatusCard", () => {
  it("renders SUCCESS state", () => {
    render(<AirtelStatusCard r={{ ...base, status: "succeeded" }} />);
    expect(screen.getByText("SUCCESS")).toBeInTheDocument();
    expect(screen.getByText("EFA-abc-123")).toBeInTheDocument();
    expect(screen.getByText("amid-xyz")).toBeInTheDocument();
    expect(screen.getByText(/code Airtel : TS/)).toBeInTheDocument();
  });

  it("renders FAILED state", () => {
    render(
      <AirtelStatusCard
        r={{ ...base, status: "failed", airtelStatusCode: "TF" }}
      />,
    );
    expect(screen.getByText("FAILED")).toBeInTheDocument();
    expect(screen.getByText(/code Airtel : TF/)).toBeInTheDocument();
  });

  it("renders PENDING state and omits optional fields when null", () => {
    render(
      <AirtelStatusCard
        r={{
          transactionId: "tx-1",
          status: "pending",
          airtelStatusCode: null,
          airtelMoneyId: null,
          message: null,
        }}
      />,
    );
    expect(screen.getByText("PENDING")).toBeInTheDocument();
    expect(screen.getByText("tx-1")).toBeInTheDocument();
    expect(screen.queryByText(/code Airtel/)).not.toBeInTheDocument();
    expect(screen.queryByText(/Airtel Money ID/i)).not.toBeInTheDocument();
  });
});
