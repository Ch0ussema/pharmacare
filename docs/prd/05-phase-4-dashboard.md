# Phase 4 — Dashboard & Reports

| | |
| --- | --- |
| **Status** | Draft — awaiting approval |
| **Depends on** | Phases 0, 1, 3 (sales data) |
| **Blocks** | Phase 5 |
| **Engineer** | `dashboard-engineer` subagent + Lead review |

## 1. Goal

Give the owner an at-a-glance, trustworthy view of the business day: revenue, volume, average basket, trend, best sellers, stock risks and stock value — all consistent with the POS data.

## 2. Scope

### In (per approved discovery)
- KPI cards: **CA du jour**, **Ventes du jour**, **Panier moyen**, each with yesterday comparison.
- Sales trend chart: last **7** and **30** days (toggle), revenue + transaction count.
- Top products: top 5 by quantity over 30 days, with revenue.
- Low-stock alerts: products at/below threshold, with quick link to catalogue.
- Stock summary: active products, total units, stock value at cost and at retail.
- Suspense boundaries + skeletons; empty states; French labels.

### Out
- Sales history table, CSV export, date-range picker, profit margins, print/export of reports.
- Multi-period comparisons beyond yesterday, forecasting.
- Real-time push updates (manual refresh/navigation only).

## 3. User stories

| # | As | I want | So that |
| --- | --- | --- | --- |
| 4.1 | Owner | to see today's revenue and transaction count | I know how the day is going |
| 4.2 | Owner | to compare with yesterday | I detect a good/bad day |
| 4.3 | Owner | to see the 7/30-day trend | I spot patterns |
| 4.4 | Owner | to know my best sellers | I reorder intelligently |
| 4.5 | Owner | to be alerted about low/out-of-stock items | I avoid lost sales |
| 4.6 | Owner | to know my stock value | I understand cash tied up |

## 4. UX specification

### Layout (`/`)
- Header: "Tableau de bord", subtitle with the date ("samedi 7 novembre 2026"), refresh action.
- Row 1: three KPI cards (icon, label, big value, delta chip vs hier: ↑ green / ↓ red / "—" if no baseline).
- Row 2: **Évolution des ventes** (span 2) + **Meilleures ventes** (1).
- Row 3: **Stock faible** (span 2) + **Synthèse du stock** (1).
- Period toggle for the chart: "7 jours" / "30 jours" (`?periode=7|30`, default 7).
- KPI detail: "hier : 1 240,000 DT" under the value.

### States
- Skeleton cards while loading; per-widget `<Suspense>` so fast widgets don't wait for slow ones.
- Empty: "Aucune vente aujourd'hui" with a CTA to Caisse.
- Low stock empty: "Aucun produit en stock faible" (positive state).
- Chart empty: flat zero series with a message, not a broken chart.

## 5. Technical design

```
src/app/(app)/page.tsx                 # RSC, reads searchParams, Suspense per widget
src/app/(app)/loading.tsx              # route-level skeleton
src/components/dashboard/kpi-card.tsx
src/components/dashboard/sales-trend-chart.tsx   # 'use client' (Recharts)
src/components/dashboard/top-products.tsx
src/components/dashboard/low-stock-list.tsx
src/components/dashboard/stock-summary.tsx
src/components/dashboard/period-toggle.tsx
src/lib/dashboard/queries.ts           # typed RPC wrappers
```

Data (Phase 1 RPCs):

| Widget | RPC |
| --- | --- |
| KPI cards | `get_dashboard_summary()` |
| Trend | `get_sales_trend(p_days)` |
| Top products | `get_top_products(30, 5)` |
| Low stock | `get_low_stock_products(8)` |
| Stock summary | `get_stock_summary()` |

- Server page calls `await connection()`; independent RPCs run with `Promise.all` (reads only — never Server Actions).
- Chart component receives plain serializable arrays; Recharts `AreaChart` with `ChartContainer`, formatted tooltip (`formatTND`), French day labels (`Intl.DateTimeFormat("fr-FR", { weekday: "short", day: "2-digit" })`).
- Deltas:
  - revenue/transactions: `(today − yesterday) / yesterday` when `yesterday > 0`, else "—".
  - average basket = `total_millimes / sales_count` rounded to nearest millime, computed in SQL (integer division is acceptable but document rounding).
- "Today" is computed **in SQL** with Africa/Tunis; the UI never derives it from the browser clock.
- Server errors: widget-level `error.tsx` fallback with retry.
- Revalidate `/` after a sale (already done in Phase 3) so navigation shows fresh numbers.

## 6. Acceptance criteria

- [ ] All five widgets render with seeded/real data and French labels.
- [ ] KPI values reconcile exactly with manual SQL queries on `sales` (same day, Africa/Tunis).
- [ ] Yesterday comparison handles: no sales yesterday ("—"), increase (green), decrease (red).
- [ ] 7/30-day toggle updates the chart without a full page reload and preserves the other widgets.
- [ ] Chart tooltip shows TND with 3 decimals; x-axis labels readable on mobile.
- [ ] Top products shows quantity + revenue, ordered desc; ties deterministic.
- [ ] Low stock lists products with `stock <= threshold`, out-of-stock highlighted; link opens `/produits?stock=faible`.
- [ ] Stock summary: product count, units, cost value, retail value; matches SQL.
- [ ] Each widget has a skeleton; a forced RPC failure shows a contained error state, not a blank page.
- [ ] No hydration warnings (chart is a client component with serializable props).
- [ ] `npm run build`, `npm run lint` pass.

## 7. Task breakdown

| # | Task | Owner |
| --- | --- | --- |
| 4.1 | Typed RPC wrappers + `connection()` + Suspense layout | `dashboard-engineer` |
| 4.2 | KPI cards + deltas + skeletons | `dashboard-engineer` |
| 4.3 | Trend chart (client) + period toggle + empty state | `dashboard-engineer` |
| 4.4 | Top products + low stock + stock summary | `dashboard-engineer` |
| 4.5 | Reconcile numbers with SQL, responsive/a11y pass | `dashboard-engineer` |
| 4.6 | QA review, fixes, commit `phase-4` | Lead |

## 8. Risks

| Risk | Mitigation |
| --- | --- |
| "Today" disagreement between UI and DB | Compute dates only in SQL (Africa/Tunis) |
| Slow RPC blocking the page | Per-widget Suspense + skeletons |
| Chart bundle weight | Single client component; Recharts tree-shaken; no SSR |
| Revenue miscalc (average rounding) | Document rounding; reconcile with SQL fixture |
| Stale numbers after sale | `revalidatePath("/")` in checkout; refresh action |
