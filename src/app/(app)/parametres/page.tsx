import type { Metadata } from "next";
import { SettingsIcon } from "lucide-react";

import { EmptyState } from "@/components/layout/empty-state";
import { PageHeader } from "@/components/layout/page-header";
import { t } from "@/lib/i18n";

export const metadata: Metadata = {
  title: t.pages.settings.title,
};

export default function ParametresPage() {
  const page = t.pages.settings;

  return (
    <div className="space-y-6">
      <PageHeader title={page.title} description={page.description} />
      <EmptyState
        icon={SettingsIcon}
        title={page.emptyTitle}
        description={page.emptyDescription}
      />
    </div>
  );
}
