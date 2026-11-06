# Phase 0 — Foundation & Design System

| | |
| --- | --- |
| **Status** | Draft — awaiting approval |
| **Depends on** | — |
| **Blocks** | Phases 1–5 |
| **Engineer** | `ui-foundation` subagent + Lead review |

## 1. Goal

Turn the scaffolded Next.js app into a clean, French, pharmacy-branded application shell with a reusable design system, routing skeleton, formatting utilities, and project conventions — with **no database dependency**.

## 2. Scope

### In
- Remove the create-next-app landing page and unused assets.
- Fix `next.config.ts`: remove `cacheComponents` and `partialPrefetching`; keep Turbopack + Tailwind CSS loader.
- Initialize **shadcn/ui with Radix** and a pharmacy theme (emerald primary, neutral surfaces, sidebar tokens, radius).
- Global shell: collapsible sidebar, top bar, content container, mobile sheet navigation.
- Routes (placeholders, French labels): `Tableau de bord` (`/`), `Caisse` (`/caisse`), `Produits` (`/produits`), `Paramètres` (`/parametres`).
- French dictionary (`fr.ts`) + `t()` accessor; all copy routed through it.
- Formatters: `formatTND(millimes)`, `formatDate`, `formatDateTime`, `formatTime`.
- `src/lib/supabase/admin.ts` stub with `server-only` guard (env read at Phase 1).
- `.env.example`, README quick-start, `not-found.tsx`.
- Placeholder data-free pages with consistent page headers.

### Out
- Any Supabase queries, tables, or seed data.
- Business logic, hooks, or forms that persist.
- Auth, roles, Arabic/RTL, dark mode toggle (dark tokens may exist but no switcher).

## 3. User stories

| # | As | I want | So that |
| --- | --- | --- | --- |
| 0.1 | Cashier | to see a clear sidebar with Caisse first | I can start selling immediately |
| 0.2 | Owner | a professional dashboard shell in French | the product feels trustworthy |
| 0.3 | Any user | the app to work on a tablet | I can use it behind the counter |
| 0.4 | Developer | one place for strings and money formatting | features stay consistent |

## 4. UX specification

- **Layout:** fixed sidebar (desktop, 16 rem) + fluid content; top bar shows page title, pharmacy name, today's date in French.
- **Sidebar:** brand mark "PharmaCare" + three nav items with icons (`LayoutDashboard`, `ShoppingCart`, `Pill`, `Settings`). Active item highlighted. Collapses to icons; on `< md` becomes a sheet.
- **Page header component:** title, description, optional action slot.
- **Theme:** emerald/teal primary (`oklch` tokens), neutral background, white cards, subtle borders, radius `0.625rem`, system font stack via Geist.
- **States:** skeleton placeholders allowed; empty states use a shared `EmptyState` component.
- **Language:** `lang="fr"`, metadata `PharmaCare — Gestion de pharmacie`.

## 5. Technical design

```
src/
  app/
    (app)/
      layout.tsx              # shell (sidebar + topbar)
      page.tsx                # dashboard placeholder
      caisse/page.tsx
      produits/page.tsx
      parametres/page.tsx
    layout.tsx                # root: lang fr, fonts, Toaster
    globals.css               # Tailwind v4 + shadcn tokens + print base
    not-found.tsx
  components/
    layout/app-sidebar.tsx
    layout/app-topbar.tsx
    layout/page-header.tsx
    layout/empty-state.tsx
    ui/…                      # shadcn components
  lib/
    i18n/fr.ts, i18n/index.ts
    format.ts
    supabase/admin.ts
    utils.ts
```

Commands:

```bash
npx shadcn@latest init -y -b radix --no-monorepo
# If any prompt remains: template = Next.js, preset = Radix/Nova,
# base color = neutral, CSS variables = yes.
npx shadcn@latest add -y button card badge table input label dialog sheet \
  dropdown-menu select textarea separator skeleton sonner tabs tooltip \
  breadcrumb popover command
```

Notes:
- `init` overwrites `globals.css`; re-apply the pharmacy theme deliberately.
- Verify `components.json` records a Radix style (e.g. `radix-nova`), not `base-nova` (Base UI).
- Keep the `shadcn` runtime package installed (`shadcn/tailwind.css`).
- `formatTND` uses `Intl.NumberFormat("fr-TN", { style: "currency", currency: "TND" })` on `millimes / 1000`; verify the output uses 3 decimals and `DT`. Fallback: manual `12,500 DT` formatting.
- `getCurrentUser()` stub in `src/lib/auth.ts` returns `{ name: "Démo", role: "owner" }` — the future auth seam.

## 6. Acceptance criteria

- [ ] `npm run build` and `npm run lint` pass.
- [ ] `/`, `/caisse`, `/produits`, `/parametres` render with the shell and French copy; active nav state correct.
- [ ] Sidebar collapses on desktop and becomes a sheet on mobile; no horizontal scroll at 375 px.
- [ ] `formatTND(12500)` → `12,500 DT` (or locale-equivalent with 3 decimals); `formatTND(1000)` → `1,000 DT`.
- [ ] All visible strings come from `fr.ts` (grep for hard-coded French in components returns none).
- [ ] No server secret referenced in any client component; `supabase/admin.ts` imports `server-only`.
- [ ] 404 page is branded and French.
- [ ] No console errors or hydration warnings on the four routes.

## 7. Task breakdown

| # | Task | Owner |
| --- | --- | --- |
| 0.1 | Update `next.config.ts`, remove boilerplate, add route groups | `ui-foundation` |
| 0.2 | shadcn init (Radix) + theme tokens + component set | `ui-foundation` |
| 0.3 | Build sidebar/topbar/page-header/empty-state | `ui-foundation` |
| 0.4 | i18n dictionary + formatters + auth stub + env example | `ui-foundation` |
| 0.5 | Placeholder pages + 404 + metadata | `ui-foundation` |
| 0.6 | Review diff, verify acceptance, fix, commit `phase-0` | Lead |

## 8. Risks

| Risk | Mitigation |
| --- | --- |
| shadcn init rewrites `globals.css` and font tokens | Commit boilerplate first; review diff; re-apply theme |
| Radix vs Base UI component API drift | Use `-b radix` explicitly; don't copy Base UI snippets |
| Theme inaccessible (contrast) | Check emerald on white/neutral; keep AA contrast |
