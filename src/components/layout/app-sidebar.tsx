"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  CrossIcon,
  PanelLeftCloseIcon,
  PanelLeftOpenIcon,
  XIcon,
} from "lucide-react";
import type { ReactNode } from "react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetClose,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { t } from "@/lib/i18n";
import { cn } from "@/lib/utils";

import {
  NAV_ITEMS,
  isActivePath,
  type NavItem,
} from "./nav-config";

interface AppSidebarProps {
  collapsed: boolean;
  onToggleCollapsed: () => void;
  mobileOpen: boolean;
  onMobileOpenChange: (open: boolean) => void;
}

interface BrandProps {
  showWordmark: boolean;
  onNavigate?: () => void;
}

function Brand({ showWordmark, onNavigate }: BrandProps) {
  return (
    <Link
      href="/"
      onClick={onNavigate}
      className="flex min-w-0 items-center gap-2.5 rounded-lg outline-none focus-visible:ring-2 focus-visible:ring-sidebar-ring focus-visible:ring-offset-2 focus-visible:ring-offset-sidebar"
    >
      <span className="flex size-9 shrink-0 items-center justify-center rounded-xl bg-primary text-primary-foreground shadow-sm">
        <CrossIcon className="size-5" aria-hidden="true" />
      </span>
      {showWordmark ? (
        <span className="flex min-w-0 flex-col leading-tight">
          <span className="truncate font-heading text-base font-semibold text-sidebar-foreground">
            {t.app.name}
          </span>
          <span className="truncate text-xs text-muted-foreground">
            {t.app.tagline}
          </span>
        </span>
      ) : null}
    </Link>
  );
}

interface NavLinkProps {
  item: NavItem;
  active: boolean;
  collapsed: boolean;
  onNavigate?: () => void;
}

function NavLink({
  item,
  active,
  collapsed,
  onNavigate,
}: NavLinkProps) {
  const label = t.nav[item.key];
  const Icon = item.icon;

  const link = (
    <Link
      href={item.href}
      onClick={onNavigate}
      aria-current={active ? "page" : undefined}
      aria-label={collapsed ? label : undefined}
      className={cn(
        "group flex h-10 items-center gap-3 rounded-lg px-3 text-sm font-medium transition-colors outline-none",
        "focus-visible:ring-2 focus-visible:ring-sidebar-ring focus-visible:ring-offset-2 focus-visible:ring-offset-sidebar",
        active
          ? "bg-sidebar-accent text-sidebar-accent-foreground"
          : "text-muted-foreground hover:bg-sidebar-accent/60 hover:text-sidebar-foreground",
        collapsed && "justify-center px-0",
      )}
    >
      <Icon className="size-5 shrink-0" aria-hidden="true" />
      {collapsed ? null : <span className="truncate">{label}</span>}
      {!collapsed && active ? (
        <span
          aria-hidden="true"
          className="ml-auto size-1.5 shrink-0 rounded-full bg-primary"
        />
      ) : null}
    </Link>
  );

  if (!collapsed) {
    return link;
  }

  return (
    <Tooltip>
      <TooltipTrigger asChild>{link}</TooltipTrigger>
      <TooltipContent side="right">{label}</TooltipContent>
    </Tooltip>
  );
}

interface SidebarContentProps {
  collapsed: boolean;
  onToggleCollapsed?: () => void;
  onNavigate?: () => void;
  headerAction?: ReactNode;
}

function SidebarContent({
  collapsed,
  onToggleCollapsed,
  onNavigate,
  headerAction,
}: SidebarContentProps) {
  const pathname = usePathname();

  return (
    <div className="flex h-full min-h-0 flex-col">
      <div
        className={cn(
          "flex h-16 shrink-0 items-center gap-2 border-b border-sidebar-border",
          collapsed ? "justify-center px-2" : "px-4",
        )}
      >
        <Brand showWordmark={!collapsed} onNavigate={onNavigate} />
        {headerAction ? (
          <div className="ml-auto shrink-0">{headerAction}</div>
        ) : null}
      </div>

      <nav
        aria-label={t.nav.label}
        className={cn(
          "flex flex-1 flex-col gap-1 overflow-y-auto py-4",
          collapsed ? "items-center px-2" : "px-3",
        )}
      >
        {NAV_ITEMS.map((item) => (
          <NavLink
            key={item.key}
            item={item}
            active={isActivePath(pathname, item.href)}
            collapsed={collapsed}
            onNavigate={onNavigate}
          />
        ))}
      </nav>

      <div
        className={cn(
          "mt-auto flex shrink-0 flex-col gap-3 border-t border-sidebar-border p-3",
          collapsed && "items-center",
        )}
      >
        {collapsed ? (
          <Tooltip>
            <TooltipTrigger asChild>
              <Badge
                variant="secondary"
                className="size-6 justify-center rounded-full p-0"
              >
                <span
                  aria-hidden="true"
                  className="size-1.5 rounded-full bg-primary"
                />
                <span className="sr-only">{t.common.demoMode}</span>
              </Badge>
            </TooltipTrigger>
            <TooltipContent side="right">{t.common.demoMode}</TooltipContent>
          </Tooltip>
        ) : (
          <Badge
            variant="secondary"
            className="w-fit gap-1.5 rounded-full px-2.5 text-[0.7rem] font-medium text-secondary-foreground"
          >
            <span
              aria-hidden="true"
              className="size-1.5 rounded-full bg-primary"
            />
            {t.common.demoMode}
          </Badge>
        )}

        {onToggleCollapsed ? (
          <Button
            type="button"
            variant="ghost"
            size={collapsed ? "icon" : "sm"}
            onClick={onToggleCollapsed}
            aria-label={
              collapsed ? t.common.expandSidebar : t.common.collapseSidebar
            }
            className={cn(
              "text-muted-foreground",
              collapsed ? "justify-center" : "w-full justify-start gap-2",
            )}
          >
            {collapsed ? (
              <PanelLeftOpenIcon aria-hidden="true" />
            ) : (
              <PanelLeftCloseIcon aria-hidden="true" />
            )}
            {collapsed ? null : <span>{t.common.collapseSidebar}</span>}
          </Button>
        ) : null}
      </div>
    </div>
  );
}

export function AppSidebar({
  collapsed,
  onToggleCollapsed,
  mobileOpen,
  onMobileOpenChange,
}: AppSidebarProps) {
  const closeMobile = () => onMobileOpenChange(false);

  return (
    <>
      <aside
        data-collapsed={collapsed}
        className={cn(
          "sticky top-0 hidden h-svh shrink-0 border-r border-sidebar-border bg-sidebar text-sidebar-foreground transition-[width] duration-200 ease-out md:block",
          collapsed ? "w-[4.5rem]" : "w-64",
        )}
      >
        <SidebarContent
          collapsed={collapsed}
          onToggleCollapsed={onToggleCollapsed}
        />
      </aside>

      <Sheet open={mobileOpen} onOpenChange={onMobileOpenChange}>
        <SheetContent
          side="left"
          showCloseButton={false}
          className="w-72 gap-0 p-0"
        >
          <SheetHeader className="sr-only">
            <SheetTitle>{t.nav.label}</SheetTitle>
            <SheetDescription>{t.app.tagline}</SheetDescription>
          </SheetHeader>
          <SidebarContent
            collapsed={false}
            onNavigate={closeMobile}
            headerAction={
              <SheetClose asChild>
                <Button
                  type="button"
                  variant="ghost"
                  size="icon-sm"
                  aria-label={t.common.closeNavigation}
                >
                  <XIcon aria-hidden="true" />
                </Button>
              </SheetClose>
            }
          />
        </SheetContent>
      </Sheet>
    </>
  );
}
