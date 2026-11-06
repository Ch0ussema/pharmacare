import type { Metadata } from "next";
import { ShoppingCartIcon } from "lucide-react";

import { EmptyState } from "@/components/layout/empty-state";
import { PageHeader } from "@/components/layout/page-header";
import { t } from "@/lib/i18n";

export const metadata: Metadata = {
  title: t.pages.pos.title,
};

export default function CaissePage() {
  const page = t.pages.pos;

  return (
    <div className="space-y-6">
      <PageHeader title={page.title} description={page.description} />
      <EmptyState
        icon={ShoppingCartIcon}
        title={page.emptyTitle}
        description={page.emptyDescription}
      />
    </div>
  );
}
