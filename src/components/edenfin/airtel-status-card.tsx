import { cn } from "@/lib/utils";

export interface AirtelStatusCardProps {
  r: {
    transactionId: string;
    status: "succeeded" | "failed" | "pending";
    airtelStatusCode: string | null;
    airtelMoneyId: string | null;
    message: string | null;
  };
}

export function AirtelStatusCard({ r }: AirtelStatusCardProps) {
  const palette =
    r.status === "succeeded"
      ? "border-emerald-500/40 bg-emerald-500/10 text-emerald-700 dark:text-emerald-400"
      : r.status === "failed"
        ? "border-destructive/40 bg-destructive/10 text-destructive"
        : "border-amber-500/40 bg-amber-500/10 text-amber-700 dark:text-amber-400";
  const label =
    r.status === "succeeded"
      ? "SUCCESS"
      : r.status === "failed"
        ? "FAILED"
        : "PENDING";
  return (
    <div className={cn("space-y-2 rounded-md border p-3 text-sm", palette)}>
      <div className="flex items-center gap-2">
        <span className="rounded-full bg-background/60 px-2 py-0.5 text-xs font-bold tracking-wide">
          {label}
        </span>
        {r.airtelStatusCode ? (
          <span className="text-xs opacity-80">code Airtel : {r.airtelStatusCode}</span>
        ) : null}
      </div>
      {r.transactionId ? (
        <div>
          <span className="text-xs opacity-75">Transaction&nbsp;ID&nbsp;: </span>
          <span className="font-mono text-xs">{r.transactionId}</span>
        </div>
      ) : null}
      {r.airtelMoneyId ? (
        <div>
          <span className="text-xs opacity-75">Airtel&nbsp;Money&nbsp;ID&nbsp;: </span>
          <span className="font-mono text-xs">{r.airtelMoneyId}</span>
        </div>
      ) : null}
      {r.message ? <p className="text-xs opacity-90">{r.message}</p> : null}
    </div>
  );
}
