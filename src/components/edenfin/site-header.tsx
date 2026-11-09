import { Link } from "@tanstack/react-router";
import { Button } from "@/components/ui/button";

export function SiteHeader() {
  return (
    <header className="sticky top-0 z-40 w-full border-b border-border/60 bg-background/85 backdrop-blur supports-[backdrop-filter]:bg-background/60">
      <div className="container mx-auto flex h-16 items-center justify-between px-6">
        <Link to="/" className="flex items-center gap-2.5 group">
          <span className="grid h-9 w-9 place-items-center rounded-md bg-prestige text-primary-foreground shadow-prestige transition-transform group-hover:scale-105">
            <span className="font-display text-base font-bold leading-none">E</span>
          </span>
          <div className="flex flex-col leading-none">
            <span className="font-display text-lg font-bold tracking-tight">EdenFin</span>
            <span className="text-[10px] uppercase tracking-[0.18em] text-muted-foreground">
              Suite financière
            </span>
          </div>
        </Link>

        <nav className="hidden items-center gap-8 md:flex">
          <Link
            to="/"
            activeOptions={{ exact: true }}
            activeProps={{ className: "text-foreground" }}
            inactiveProps={{ className: "text-muted-foreground hover:text-foreground" }}
            className="text-sm font-medium transition-colors"
          >
            Suite
          </Link>
          <Link
            to="/jaspe"
            activeProps={{ className: "text-foreground" }}
            inactiveProps={{ className: "text-muted-foreground hover:text-foreground" }}
            className="text-sm font-medium transition-colors"
          >
            JASPE
          </Link>
        </nav>

        <div className="flex items-center gap-2">
          <Button asChild variant="ghost" size="sm" className="hidden sm:inline-flex">
            <Link to="/console">Console</Link>
          </Button>
          <Button asChild variant="prestige" size="sm">
            <Link to="/jaspe">Découvrir JASPE</Link>
          </Button>
        </div>
      </div>
    </header>
  );
}
