"use client";

import { useSyncExternalStore } from "react";
import { usePathname } from "next/navigation";
import { CalendarDaysIcon, MenuIcon, UserRoundIcon } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import type { CurrentUser } from "@/lib/auth";
import { formatDate } from "@/lib/format";
import { t } from "@/lib/i18n";

import { getNavItemForPath } from "./nav-config";

/**
 * Tiny clock store. `server` snapshot is `null`, so prerendered HTML has no
 * date and the client fills it in after hydration without a mismatch.
 */
let clockValue = new Date();
let clockTimer: ReturnType<typeof setInterval> | null = null;
const clockListeners = new Set<() => void>();

function subscribeToClock(listener: () => void): () => void {
  clockListeners.add(listener);

  if (clockTimer === null) {
    clockTimer = setInterval(() => {
      clockValue = new Date();
      clockListeners.forEach((notify) => notify());
    }, 60_000);
  }

  return () => {
    clockListeners.delete(listener);
    if (clockListeners.size === 0 && clockTimer !== null) {
      clearInterval(clockTimer);
      clockTimer = null;
    }
  };
}

function getClockSnapshot(): Date | null {
  return clockValue;
}

function getClockServerSnapshot(): Date | null {
  return null;
}

interface AppTopbarProps {
  user: CurrentUser;
  onOpenNavigation: () => void;
}

export function AppTopbar({ user, onOpenNavigation }: AppTopbarProps) {
  const pathname = usePathname();
  const today = useSyncExternalStore(
    subscribeToClock,
    getClockSnapshot,
    getClockServerSnapshot,
  );

  const currentNav = getNavItemForPath(pathname);
  const pageTitle = currentNav ? t.nav[currentNav.key] : t.app.name;

  return (
    <header className="sticky top-0 z-30 flex h-16 shrink-0 items-center gap-3 border-b border-border bg-background/85 px-4 backdrop-blur supports-[backdrop-filter]:bg-background/70 sm:px-6">
      <Button
        type="button"
        variant="ghost"
        size="icon"
        onClick={onOpenNavigation}
        aria-label={t.common.openNavigation}
        className="md:hidden"
      >
        <MenuIcon aria-hidden="true" />
      </Button>

      <div className="min-w-0">
        <div className="truncate font-heading text-sm font-semibold text-foreground sm:text-base">
          {pageTitle}
        </div>
        <div className="hidden text-xs text-muted-foreground sm:block">
          {t.app.tagline}
        </div>
      </div>

      <div className="ml-auto flex min-w-0 items-center gap-3">
        <div className="flex items-center gap-1.5 text-xs text-muted-foreground sm:text-sm">
          <CalendarDaysIcon className="size-4" aria-hidden="true" />
          {today ? (
            <time dateTime={today.toISOString()}>{formatDate(today)}</time>
          ) : (
            <span
              aria-hidden="true"
              className="inline-block h-4 w-24 rounded-sm bg-muted"
            />
          )}
        </div>

        <Separator orientation="vertical" className="hidden h-6 sm:block" />

        <div
          role="group"
          aria-label={t.common.currentUser}
          className="flex min-w-0 items-center gap-2"
        >
          <span className="flex size-8 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary">
            <UserRoundIcon className="size-4" aria-hidden="true" />
          </span>
          <span className="hidden min-w-0 flex-col leading-tight sm:flex">
            <span className="truncate text-sm font-medium text-foreground">
              {user.name}
            </span>
            <span className="truncate text-xs text-muted-foreground">
              {t.common.roles[user.role]}
            </span>
          </span>
          <span className="sr-only sm:hidden">
            {user.name}, {t.common.roles[user.role]}
          </span>
        </div>
      </div>
    </header>
  );
}
