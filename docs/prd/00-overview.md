# PharmaCare — Product Overview (v1)

| | |
| --- | --- |
| **Status** | Draft — awaiting approval |
| **Version** | 1.0 |
| **Date** | 2026-11-07 |
| **Owner** | Technical Lead / Orchestrator |
| **Target** | Single independent pharmacy in Tunisia |

## 1. Summary

PharmaCare is a cloud web application that lets a single pharmacy run its counter and understand its business:

- **Caisse (POS):** fast product search, cart, cash checkout, printable 80 mm receipt.
- **Catalogue:** products, prices, barcodes, categories, stock levels, low-stock thresholds.
- **Tableau de bord:** today's revenue/transactions/average basket, sales trend, top products, low-stock alerts, stock value.

The UI is **French only** in v1, but all copy is centralized so Arabic/RTL can be added later. Currency is the **Tunisian dinar (TND)**, which has **3 decimals** (millimes). Prices are displayed and stored with that precision.

## 2. Personas

| Persona | Primary jobs |
| --- | --- |
| **Owner (propriétaire)** | Watches revenue, best sellers, stock value, low stock. Configures the pharmacy identity. |
| **Pharmacist** | Maintains the catalogue, prices, stock levels, categories. |
| **Cashier (caissier)** | Sells quickly, takes cash, prints receipts. |

v1 runs in **demo mode**: no login. The architecture keeps a single seam (`getCurrentUser`) so authentication and role enforcement can be added without rewriting screens.

## 3. Scope

### In scope (v1)

| Area | Included |
| --- | --- |
| Catalogue | Create/edit/archive products; barcode; category; price; cost; stock; low-stock threshold |
| Stock | Manual adjustments with reason/note; automatic decrement on sale; negative stock prevented |
| Categories | Create, rename, delete (products become uncategorized) |
| Settings | Pharmacy name, address, phone, receipt footer |
| POS | Search by name/barcode, category filter, cart, quantity limits, cash payment, change calculation |
| Receipts | On-screen receipt, 80 mm print layout, receipt number |
| Dashboard | Today's KPIs + yesterday comparison, 7/30-day trend, top products, low stock, stock summary |
| Platform | French UI, TND formatting, Africa/Tunis time zone, responsive layout |

### Explicitly out of scope (v1)

Authentication/roles enforcement, purchases & suppliers, prescriptions, insurance/CNAM reimbursement, batch/lot & expiry tracking, returns/refunds, card/credit payments, multi-branch, offline mode, Arabic/RTL, barcode/receipt hardware drivers, sales history page, customer records, CSV export, notifications.

> These stay in the backlog and the data model leaves room for them (e.g. `stock_movements.reason`, `sale_items` price snapshots).

## 4. Success criteria

1. A cashier completes a cash sale in **under 30 seconds** using only the keyboard + mouse.
2. Stock never goes negative, including two simultaneous checkouts of the last unit.
3. Receipt totals are **exact to the millime** (no floating-point drift).
4. The dashboard's "today" numbers match the sales recorded in Africa/Tunis time.
5. A receipt prints correctly on 80 mm paper via the browser print dialog.
6. `npm run build` and `npm run lint` pass on every merged phase.

## 5. Architecture

```
Browser (React 19 client components)
   │  Server Actions (mutations)          Server Components (reads)
   ▼                                            ▼
Next.js 16.4.5 App Router (Node runtime)
   │  src/lib/supabase/admin.ts  (server-only, secret key)
   ▼
Supabase Postgres
   ├─ tables: categories, products, sales, sale_items, stock_movements, settings
   ├─ RPC: create_sale(), adjust_stock(), dashboard_*()
   └─ RLS enabled, no public policies (service-role access only)
```

### Stack decisions

| Concern | Choice | Why |
| --- | --- | --- |
| Framework | Next.js 16.4.5 (App Router, Turbopack) | Already scaffolded; RSC + Server Actions fit CRUD + POS |
| UI | Tailwind CSS v4 + shadcn/ui (**Radix** primitives) | Fast, accessible, mature examples |
| Charts | shadcn `chart` (Recharts 3.8) | Fits dashboard, React 19 compatible |
| Database | Supabase Postgres | Managed, free tier, SQL-first, auth available later |
| DB access | `@supabase/supabase-js` 2.x, **server-only secret key** | No auth in v1; key never reaches the browser |
| Mutations | Server Actions + zod validation | No hand-written API layer |
| Money | Integer **millimes** (`1 DT = 1000`) | Exact arithmetic |
| Dates | `timestamptz` + Africa/Tunis for day boundaries | Correct "today" for the pharmacy |
| i18n | French dictionary module | Arabic later without rewriting screens |
| Deployment | Vercel + Supabase | Zero-config Next.js hosting |

### Next.js 16 constraints (verified against bundled docs)

- `cacheComponents` and `partialPrefetching` are **disabled** for v1. Data is live and mutation-heavy; Cache Components would force `<Suspense>`/`connection()` ceremony and risk stale stock.
- Data helpers call `connection()` (from `next/server`) so pages are never statically baked at build time.
- Server Actions use `revalidatePath()` after writes (Cache Components APIs are unavailable when disabled).
- `params`/`searchParams` are Promises; use the generated `PageProps<'/route'>` helper.
- Errors: `error.tsx` receives `{ error, retry }` (not `reset`) in Next 16.

## 6. Data model (summary)

| Table | Purpose | Key columns |
| --- | --- | --- |
| `categories` | Product grouping | `id`, `name` |
| `products` | Sellable items | `name`, `barcode` (unique, nullable), `category_id`, `price_millimes`, `cost_millimes`, `stock_quantity`, `low_stock_threshold`, `is_active` |
| `sales` | One checkout | `receipt_number` (unique), `total_millimes`, `payment_method` (`cash`), `created_at` |
| `sale_items` | Immutable line snapshots | `sale_id`, `product_id`, `product_name`, `unit_price_millimes`, `quantity`, `line_total_millimes` |
| `stock_movements` | Audit trail | `product_id`, `delta`, `reason` (`sale`/`restock`/`adjustment`), `reference_id`, `note` |
| `settings` | Single-row pharmacy identity | `pharmacy_name`, `address`, `phone`, `receipt_footer` |

Invariants:
- `products.stock_quantity >= 0` (DB check + locked update inside `create_sale`).
- Sale totals are computed **server-side** from `products.price_millimes`; client prices are ignored.
- Sale items keep a **price/name snapshot** so later product edits don't rewrite history.

## 7. Cross-cutting rules

- **Money:** all amounts are integers in millimes. Formatting lives in `formatTND()` (`fr-TN`, 3 decimals, `DT`). No `parseFloat` for arithmetic.
- **Dates:** store UTC, render `Africa/Tunis`. "Today" = `(created_at at time zone 'Africa/Tunis')::date = (now() at time zone 'Africa/Tunis')::date`.
- **Security:** secret key only in `SUPABASE_SECRET_KEY` (no `NEXT_PUBLIC_`). `import "server-only"` guard. RLS on every table and grants revoked from `anon`/`authenticated`.
- **Validation:** zod schemas on the server for every action; HTML constraints for UX only.
- **Errors:** user-facing French messages; technical detail logged server-side. Insufficient stock is a first-class, recoverable error.
- **Accessibility:** labeled inputs, visible focus, keyboard-complete POS, contrast ≥ WCAG AA.
- **Responsiveness:** desktop-first counter layout; POS and tables usable on a tablet.

## 8. Key decisions (ADR log)

| # | Decision | Rationale | Rejected alternative |
| --- | --- | --- | --- |
| D1 | Disable `cacheComponents` / `partialPrefetching` | Live stock + frequent writes; avoid stale reads and Suspense ceremony | Keep PPR and cache reads |
| D2 | Radix-based shadcn | Mature, widely documented, stable with React 19 | Base UI default |
| D3 | Service-role secret key, server-only | No auth in v1; secret never exposed | Anon key + permissive RLS (`using (true)`) |
| D4 | Integer millimes | Exact totals and change | `numeric`/floats in JS |
| D5 | Atomic `create_sale` RPC | Row locks prevent overselling; server computes totals | Multi-step client writes |
| D6 | Client-side product filtering in POS | Single pharmacy, ≤ ~1000 active products; instant search | Per-keystroke server queries |
| D7 | French dictionary from day one | Arabic later without rewriting screens | Hard-coded strings |
| D8 | Soft-delete products (`is_active=false`) | Preserves sale history and receipts | Hard delete |

## 9. Roadmap

| Phase | Deliverable | Gate |
| --- | --- | --- |
| 0 | Foundation: config, shadcn theme, app shell, i18n, formatters, empty routes | Build + lint + shell demo |
| 1 | Supabase schema, RPCs, seed, security, TS types | SQL clean run + RPC smoke test |
| 2 | Catalogue: CRUD, stock adjustments, categories, settings | Create/edit/adjust flows demoed |
| 3 | POS: search, cart, cash checkout, receipt + 80 mm print | End-to-end sale + stock decrement |
| 4 | Dashboard: KPIs, trend, top products, low stock, stock value | Numbers reconciled with SQL |
| 5 | QA, accessibility, performance, deployment, release notes | Production smoke test + tag v1.0.0 |

## 10. Risks & mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Supabase project not created yet | Blocks Phase 1 | Phase 0 is DB-free; provide step-by-step guide before Phase 1 |
| Secret key leaked to client | Full DB compromise | `server-only`, no `NEXT_PUBLIC_`, RLS + revoked grants, review imports |
| Floating-point money bugs | Wrong totals | Integer millimes + DB-side totals + formatter tests |
| Overselling last unit | Negative stock | `SELECT … FOR UPDATE` inside RPC + DB check constraint |
| Free-tier project pauses | Demo unavailable | Document unpause; export/restore SQL |
| Scope creep (expiry, suppliers…) | Delays v1 | Explicit out-of-scope list; backlog in overview |

## 11. Open questions

1. Supabase project URL + secret key (needed at Phase 1).
2. Real pharmacy name/address/phone for receipts (defaults can be seeded).
3. Vercel account for deployment (Phase 5).
