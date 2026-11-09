export function SiteFooter() {
  return (
    <footer className="border-t border-border/60 bg-card/40">
      <div className="container mx-auto flex flex-col items-center justify-between gap-4 px-6 py-8 md:flex-row">
        <div className="flex items-center gap-2 text-sm text-muted-foreground">
          <span className="grid h-7 w-7 place-items-center rounded bg-prestige text-primary-foreground">
            <span className="font-display text-xs font-bold leading-none">E</span>
          </span>
          <span className="font-display font-semibold text-foreground">EdenFin</span>
          <span>· Suite financière OHADA · {new Date().getFullYear()}</span>
        </div>
        <p className="text-xs text-muted-foreground">
          Conforme SYSCOHADA révisé · CEMAC & UEMOA
        </p>
      </div>
    </footer>
  );
}
