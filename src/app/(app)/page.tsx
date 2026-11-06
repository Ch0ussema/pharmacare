import type { Metadata } from "next";
import { LayoutDashboardIcon } from "lucide-react";

import { EmptyState } from "@/components/layout/empty-state";
import { PageHeader } from "@/components/layout/page-header";
import { t } from "@/lib/i18n";

export const metadata: Metadata = {
  title: t.pages.dashboard.title,
};

export default function DashboardPage() {
  const page = t.pages.dashboard;

  return (
    <div className="space-y-6">
      <PageHeader title={page.title} description={page.description} />
      <EmptyState
        icon={LayoutDashboardIcon}
        title={page.emptyTitle}
        description={page.emptyDescription}
      />
    </div>
  );
}
