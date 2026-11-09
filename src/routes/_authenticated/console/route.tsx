import { createFileRoute, Link, Outlet } from "@tanstack/react-router";

import { SidebarProvider, SidebarTrigger } from "@/components/ui/sidebar";
import { ConsoleSidebar } from "@/components/edenfin/console-sidebar";

export const Route = createFileRoute("/_authenticated/console")({
  head: () => ({
    meta: [
      { title: "Console JASPE · EdenFin" },
      {
        name: "description",
        content: "Console de pilotage JASPE : comptabilité, trésorerie, paie, fiscal, analyse.",
      },
    ],
  }),
  component: ConsoleLayout,
});

function ConsoleLayout() {
  return (
    <SidebarProvider>
      <div className="flex min-h-screen w-full bg-background">
        <ConsoleSidebar />

        <div className="flex flex-1 flex-col">
          <header className="flex h-14 items-center gap-3 border-b border-border bg-card/60 px-4 backdrop-blur">
            <SidebarTrigger />
            <div className="flex items-center gap-2 text-sm">
              <Link
                to="/"
                className="text-muted-foreground transition-colors hover:text-foreground"
              >
                EdenFin
              </Link>
              <span className="text-muted-foreground/60">/</span>
              <span className="font-medium text-foreground">JASPE</span>
            </div>
            <div className="ml-auto flex items-center gap-3">
              <span className="hidden rounded-full border border-success/40 bg-success/10 px-2.5 py-0.5 text-[10px] font-semibold uppercase tracking-wider text-success sm:inline">
                Démo
              </span>
            </div>
          </header>

          <main className="flex-1 overflow-y-auto">
            <Outlet />
          </main>
        </div>
      </div>
    </SidebarProvider>
  );
}
