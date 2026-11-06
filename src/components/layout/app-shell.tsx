"use client";

import {
  useCallback,
  useState,
  useSyncExternalStore,
  type ReactNode,
} from "react";

import type { CurrentUser } from "@/lib/auth";
import { t } from "@/lib/i18n";

import { AppSidebar } from "./app-sidebar";
import { AppTopbar } from "./app-topbar";

const SIDEBAR_STORAGE_KEY = "pharmacare.sidebar.collapsed";
const sidebarListeners = new Set<() => void>();

function subscribeToSidebar(listener: () => void): () => void {
  sidebarListeners.add(listener);
  window.addEventListener("storage", listener);

  return () => {
    sidebarListeners.delete(listener);
    window.removeEventListener("storage", listener);
  };
}

function getCollapsedSnapshot(): boolean {
  return window.localStorage.getItem(SIDEBAR_STORAGE_KEY) === "true";
}

function getCollapsedServerSnapshot(): boolean {
  return false;
}

function persistCollapsed(next: boolean): void {
  window.localStorage.setItem(SIDEBAR_STORAGE_KEY, String(next));
  sidebarListeners.forEach((listener) => listener());
}

interface AppShellProps {
  user: CurrentUser;
  children: ReactNode;
}

export function AppShell({ user, children }: AppShellProps) {
  const [mobileOpen, setMobileOpen] = useState(false);

  // useSyncExternalStore reads localStorage after hydration without SSR drift.
  const collapsed = useSyncExternalStore(
    subscribeToSidebar,
    getCollapsedSnapshot,
    getCollapsedServerSnapshot,
  );

  const toggleCollapsed = useCallback(() => {
    persistCollapsed(!getCollapsedSnapshot());
  }, []);

  const openNavigation = useCallback(() => {
    setMobileOpen(true);
  }, []);

  return (
    <div className="flex min-h-svh w-full bg-background">
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:fixed focus:top-4 focus:left-4 focus:z-50 focus:rounded-md focus:bg-card focus:px-3 focus:py-2 focus:text-sm focus:font-medium focus:text-foreground focus:shadow-md focus:ring-2 focus:ring-ring"
      >
        {t.common.skipToContent}
      </a>

      <AppSidebar
        collapsed={collapsed}
        onToggleCollapsed={toggleCollapsed}
        mobileOpen={mobileOpen}
        onMobileOpenChange={setMobileOpen}
      />

      <div className="flex min-w-0 flex-1 flex-col">
        <AppTopbar user={user} onOpenNavigation={openNavigation} />
        <main
          id="main-content"
          tabIndex={-1}
          className="flex-1 px-4 py-5 outline-none sm:px-6 sm:py-6 lg:px-8"
        >
          <div className="mx-auto w-full max-w-7xl">{children}</div>
        </main>
      </div>
    </div>
  );
}
