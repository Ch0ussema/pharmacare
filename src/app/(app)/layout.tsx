import type { ReactNode } from "react";

import { AppShell } from "@/components/layout/app-shell";
import { getCurrentUser } from "@/lib/auth";

export default function AppLayout({ children }: { children: ReactNode }) {
  const user = getCurrentUser();

  return <AppShell user={user}>{children}</AppShell>;
}
