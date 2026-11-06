import {
  LayoutDashboardIcon,
  PillIcon,
  SettingsIcon,
  ShoppingCartIcon,
  type LucideIcon,
} from "lucide-react";

import { t } from "@/lib/i18n";

export type NavKey = Exclude<keyof typeof t.nav, "label">;

export interface NavItem {
  key: NavKey;
  href: string;
  icon: LucideIcon;
}

export const NAV_ITEMS: readonly NavItem[] = [
  { key: "dashboard", href: "/", icon: LayoutDashboardIcon },
  { key: "pos", href: "/caisse", icon: ShoppingCartIcon },
  { key: "products", href: "/produits", icon: PillIcon },
  { key: "settings", href: "/parametres", icon: SettingsIcon },
];

export function isActivePath(pathname: string, href: string): boolean {
  if (href === "/") {
    return pathname === "/";
  }
  return pathname === href || pathname.startsWith(`${href}/`);
}

export function getNavItemForPath(pathname: string): NavItem | undefined {
  return NAV_ITEMS.find((item) => isActivePath(pathname, item.href));
}
