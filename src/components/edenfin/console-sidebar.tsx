import { Link, useRouterState, useNavigate } from "@tanstack/react-router";
import {
  LayoutDashboard,
  BookOpen,
  Wallet,
  Users,
  FileText,
  Building2,
  BarChart3,
  CreditCard,
  Layers,
  Coins,
  Globe2,
  Receipt,
  Network,
  GitPullRequestArrow,
  Landmark,
  Scale,
  Lock,
  LogOut,
} from "lucide-react";
import { useAuth } from "@/contexts/auth-context";
import { cn } from "@/lib/utils";
import { useGammeTier } from "@/hooks/use-gamme-tier";
import { hasTierAccess, type GammeTier } from "@/lib/gammes";
import { TierSwitcher } from "@/components/edenfin/gamme-gate";

import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar";

type NavItem = {
  title: string;
  url: string;
  icon: typeof LayoutDashboard;
  exact?: boolean;
};

type NavGroup = {
  label: string;
  /** Pastille de couleur de la gamme (classe de fond Tailwind). */
  dot?: string;
  /** Gamme requise pour accéder au groupe (gating par abonnement). */
  tier?: GammeTier;
  items: NavItem[];
};

const groups: NavGroup[] = [
  {
    label: "JASPE · TPE",
    dot: "bg-primary",
    items: [
      { title: "Tableau de bord", url: "/console", icon: LayoutDashboard, exact: true },
      { title: "Comptabilité", url: "/console/comptabilite", icon: BookOpen },
      { title: "Trésorerie", url: "/console/tresorerie", icon: Wallet },
      { title: "Paie", url: "/console/paie", icon: Users },
      { title: "Fiscal", url: "/console/fiscal", icon: FileText },
      { title: "Immobilisations", url: "/console/immobilisations", icon: Building2 },
      { title: "Analyse", url: "/console/analyse", icon: BarChart3 },
    ],
  },
  {
    label: "RUBIS · PME",
    dot: "bg-destructive",
    tier: "RUBIS",
    items: [
      { title: "Analytique", url: "/console/rubis-analytique", icon: Layers },
      { title: "Multi-sociétés", url: "/console/rubis-societes", icon: Building2 },
      { title: "Facturation", url: "/console/rubis-facturation", icon: Receipt },
    ],
  },
  {
    label: "SAPHIR · ETI",
    dot: "bg-chart-4",
    tier: "SAPHIR",
    items: [
      { title: "Multi-devises", url: "/console/saphir-devises", icon: Coins },
      { title: "Consolidation", url: "/console/saphir-consolidation", icon: Network },
      { title: "Workflows", url: "/console/saphir-workflow", icon: GitPullRequestArrow },
    ],
  },
  {
    label: "ONYX · GE / Public",
    dot: "bg-foreground",
    tier: "ONYX",
    items: [
      { title: "Multi-pays", url: "/console/onyx-pays", icon: Globe2 },
      { title: "Trésorerie", url: "/console/onyx-tresorerie", icon: Landmark },
      { title: "Secteur public", url: "/console/onyx-secteur-public", icon: Scale },
    ],
  },
  {
    label: "Compte",
    items: [
      { title: "Abonnement", url: "/console/abonnement", icon: CreditCard },
    ],
  },
];

export function ConsoleSidebar() {
  const currentPath = useRouterState({ select: (s) => s.location.pathname });
  const navigate = useNavigate();
  const { user, signOut } = useAuth();
  const { tier: currentTier } = useGammeTier();
  const isActive = (url: string, exact?: boolean) =>
    exact ? currentPath === url : currentPath === url || currentPath.startsWith(url + "/");

  async function handleSignOut() {
    await signOut();
    navigate({ to: "/login" });
  }

  return (
    <Sidebar collapsible="icon">
      <SidebarHeader className="border-b border-sidebar-border/60">
        <Link to="/" className="flex items-center gap-2.5 px-2 py-2">
          <span className="grid h-9 w-9 shrink-0 place-items-center rounded-md bg-gold text-gold-foreground shadow-gold">
            <span className="font-display text-base font-bold leading-none">E</span>
          </span>
          <div className="flex flex-col leading-none group-data-[collapsible=icon]:hidden">
            <span className="font-display text-base font-bold tracking-tight text-sidebar-foreground">
              EdenFin
            </span>
            <span className="text-[10px] uppercase tracking-[0.18em] text-sidebar-foreground/60">
              JASPE
            </span>
          </div>
        </Link>
      </SidebarHeader>

      <SidebarContent>
        {groups.map((group) => {
          const locked = group.tier ? !hasTierAccess(currentTier, group.tier) : false;
          return (
            <SidebarGroup key={group.label}>
              <SidebarGroupLabel className="flex items-center gap-1.5">
                {group.dot ? (
                  <span className={cn("h-1.5 w-1.5 shrink-0 rounded-full", group.dot)} />
                ) : null}
                {group.label}
                {locked ? <Lock className="ml-auto h-3 w-3 opacity-60" /> : null}
              </SidebarGroupLabel>
              <SidebarGroupContent>
                <SidebarMenu>
                  {group.items.map((item) =>
                    locked ? (
                      <SidebarMenuItem key={item.url}>
                        <SidebarMenuButton
                          asChild
                          tooltip={`Réservé à la gamme ${group.tier}`}
                        >
                          <a
                            href="/console/abonnement"
                            className="flex items-center gap-2 opacity-50"
                          >
                            <item.icon className="h-4 w-4" />
                            <span>{item.title}</span>
                            <Lock className="ml-auto h-3 w-3" />
                          </a>
                        </SidebarMenuButton>
                      </SidebarMenuItem>
                    ) : (
                      <SidebarMenuItem key={item.url}>
                        <SidebarMenuButton
                          asChild
                          isActive={isActive(item.url, item.exact)}
                          tooltip={item.title}
                        >
                          <a href={item.url} className="flex items-center gap-2">
                            <item.icon className="h-4 w-4" />
                            <span>{item.title}</span>
                          </a>
                        </SidebarMenuButton>
                      </SidebarMenuItem>
                    ),
                  )}
                </SidebarMenu>
              </SidebarGroupContent>
            </SidebarGroup>
          );
        })}
      </SidebarContent>

      <SidebarFooter className="border-t border-sidebar-border/60">
        <TierSwitcher />
        {user && (
          <div className="flex items-center justify-between gap-2 px-2 py-2">
            <div className="min-w-0 group-data-[collapsible=icon]:hidden">
              <p className="truncate text-xs font-medium text-sidebar-foreground">
                {user.user_metadata?.["full_name"] ?? user.email}
              </p>
              {user.email && user.user_metadata?.["full_name"] && (
                <p className="truncate text-[10px] text-sidebar-foreground/55">{user.email}</p>
              )}
            </div>
            <button
              onClick={handleSignOut}
              title="Se déconnecter"
              className="shrink-0 rounded-md p-1.5 text-sidebar-foreground/60 transition-colors hover:bg-sidebar-accent hover:text-sidebar-foreground"
            >
              <LogOut className="h-4 w-4" />
            </button>
          </div>
        )}
        <div className="px-2 pb-2 text-[10px] uppercase tracking-[0.18em] text-sidebar-foreground/55 group-data-[collapsible=icon]:hidden">
          Conforme SYSCOHADA · v1.0
        </div>
      </SidebarFooter>
    </Sidebar>
  );
}
