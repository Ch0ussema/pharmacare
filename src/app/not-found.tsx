import Link from "next/link";
import { CrossIcon, HomeIcon } from "lucide-react";

import { Button } from "@/components/ui/button";
import { t } from "@/lib/i18n";

export default function NotFound() {
  return (
    <main className="flex min-h-svh flex-col items-center justify-center gap-6 bg-background px-6 py-16 text-center">
      <div className="flex size-14 items-center justify-center rounded-2xl bg-primary/10 text-primary">
        <CrossIcon className="size-7" aria-hidden="true" />
      </div>

      <div className="space-y-2">
        <p className="text-sm font-medium text-primary">{t.notFound.code}</p>
        <h1 className="font-heading text-3xl font-semibold tracking-tight text-foreground">
          {t.notFound.title}
        </h1>
        <p className="mx-auto max-w-md text-sm text-muted-foreground">
          {t.notFound.description}
        </p>
      </div>

      <Button asChild size="lg">
        <Link href="/">
          <HomeIcon aria-hidden="true" />
          {t.notFound.action}
        </Link>
      </Button>
    </main>
  );
}
