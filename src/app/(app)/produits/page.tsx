import type { Metadata } from "next";
import { PillIcon, PlusIcon } from "lucide-react";

import { EmptyState } from "@/components/layout/empty-state";
import { PageHeader } from "@/components/layout/page-header";
import { Button } from "@/components/ui/button";
import { t } from "@/lib/i18n";

export const metadata: Metadata = {
  title: t.pages.products.title,
};

export default function ProduitsPage() {
  const page = t.pages.products;

  return (
    <div className="space-y-6">
      <PageHeader
        title={page.title}
        description={page.description}
        actions={
          <>
            <Button
              type="button"
              disabled
              aria-describedby="new-product-availability"
            >
              <PlusIcon aria-hidden="true" />
              {t.common.actions.newProduct}
            </Button>
            <span id="new-product-availability" className="sr-only">
              {t.common.comingSoon}
            </span>
          </>
        }
      />
      <EmptyState
        icon={PillIcon}
        title={page.emptyTitle}
        description={page.emptyDescription}
      />
    </div>
  );
}
