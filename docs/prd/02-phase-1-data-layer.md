# Phase 1 — Data Layer (Supabase Schema, RPCs, Seed)

| | |
| --- | --- |
| **Status** | Draft — awaiting approval |
| **Depends on** | Phase 0 |
| **Blocks** | Phases 2, 3, 4 |
| **Engineer** | `db-architect` subagent + Lead review |

## 1. Goal

Create the complete Postgres data layer for v1: schema, constraints, indexes, atomic business functions, dashboard aggregations, security posture, and realistic Tunisian seed data.

## 2. Scope

### In
- Supabase project creation guide (dashboard flow) and env wiring.
- SQL migrations as plain files in `db/` (runnable in Supabase SQL Editor; CLI optional).
- Tables: `categories`, `products`, `sales`, `sale_items`, `stock_movements`, `settings`.
- Functions: `create_sale`, `adjust_stock`, `get_dashboard_summary`, `get_sales_trend`, `get_top_products`, `get_low_stock_products`, `get_stock_summary`.
- RLS enabled, grants revoked from `anon`/`authenticated`, functions restricted to `service_role`.
- Seed: settings row, 8 categories, ~40 products (realistic Tunisian medicines/prices/stock; some low/zero stock).
- Hand-written TypeScript types in `src/types/db.ts` matching the schema.
- `src/lib/supabase/admin.ts` real client + `db:smoke` SQL checks documented.

### Out
- Auth tables/policies.
- Purchases, suppliers, prescriptions, batches/expiry, returns.
- ORM (Prisma/Drizzle); we use SQL + `supabase-js`.

## 3. Supabase setup (manual, guided)

1. supabase.com → **New project** → Free plan → region `eu-west-*` (closest) → save DB password.
2. Settings → **API Keys** → create/copy a **secret key** (`sb_secret_…`).
3. Copy **Project URL**.
4. Put in `.env.local` (never commit):

```bash
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_SECRET_KEY=sb_secret_...
```

5. Run `db/001_schema.sql`, then `002_functions.sql`, then `003_seed.sql` in the SQL Editor (in order).

## 4. Schema

```sql
create extension if not exists pgcrypto;

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now()
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  barcode text,
  category_id uuid references public.categories(id) on delete set null,
  price_millimes integer not null check (price_millimes >= 0),
  cost_millimes integer not null default 0 check (cost_millimes >= 0),
  stock_quantity integer not null default 0 check (stock_quantity >= 0),
  low_stock_threshold integer not null default 10 check (low_stock_threshold >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index products_barcode_key
  on public.products (barcode) where barcode is not null;
create index products_category_idx on public.products (category_id);
create index products_active_low_stock_idx
  on public.products (stock_quantity) where is_active;

create table public.sales (
  id uuid primary key default gen_random_uuid(),
  receipt_number text not null unique,
  total_millimes integer not null check (total_millimes >= 0),
  payment_method text not null default 'cash' check (payment_method = 'cash'),
  created_at timestamptz not null default now()
);
create index sales_created_at_idx on public.sales (created_at desc);

create table public.sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  unit_price_millimes integer not null check (unit_price_millimes >= 0),
  quantity integer not null check (quantity > 0),
  line_total_millimes integer not null check (line_total_millimes >= 0)
);
create index sale_items_sale_idx on public.sale_items (sale_id);
create index sale_items_product_idx on public.sale_items (product_id);

create table public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  delta integer not null check (delta <> 0),
  reason text not null check (reason in ('sale', 'restock', 'adjustment')),
  reference_id uuid,
  note text,
  created_at timestamptz not null default now()
);
create index stock_movements_product_idx on public.stock_movements (product_id, created_at desc);

create table public.settings (
  id smallint primary key default 1 check (id = 1),
  pharmacy_name text not null default 'Pharmacie',
  address text not null default '',
  phone text not null default '',
  receipt_footer text not null default 'Merci de votre visite',
  updated_at timestamptz not null default now()
);

create sequence public.sale_receipt_seq start 1;
```

`updated_at` is maintained by a shared trigger `set_updated_at()` on `products` and `settings`.

## 5. Functions

### 5.1 `create_sale(p_items jsonb)` → jsonb

Input: `[{"product_id":"uuid","quantity":2}, …]`

Algorithm (single transaction):
1. Reject empty input, quantity `< 1` or `> 999`, duplicate product lines are merged.
2. `SELECT … FROM products WHERE id = ANY(...) FOR UPDATE` (row locks).
3. Reject inactive/missing products and insufficient stock (raise `P0001` with `stock_insufficient:<id>:<available>`).
4. Compute `line_total = price_millimes * quantity` and total **server-side**.
5. Insert `sales` with `receipt_number = 'V-' || lpad(nextval('sale_receipt_seq')::text, 6, '0')`.
6. Insert `sale_items` snapshots; update stock; insert `stock_movements` (`reason='sale'`).
7. Return `{ sale_id, receipt_number, total_millimes, created_at, items:[…] }`.

### 5.2 `adjust_stock(p_product_id, p_delta, p_note)` → integer

- `delta = 0` rejected; resulting stock `< 0` rejected.
- Updates product, logs `restock` when delta > 0 and `adjustment` when delta < 0.
- Returns new stock.

### 5.3 Dashboard functions

| Function | Returns |
| --- | --- |
| `get_dashboard_summary()` | `today_revenue`, `today_sales`, `today_avg_basket`, `yesterday_revenue`, `yesterday_sales` |
| `get_sales_trend(p_days int default 7)` | `day date`, `revenue_millimes`, `sales_count` (gap-filled series) |
| `get_top_products(p_days int default 30, p_limit int default 5)` | `product_id`, `name`, `quantity`, `revenue_millimes` |
| `get_low_stock_products(p_limit int default 8)` | `id`, `name`, `stock_quantity`, `low_stock_threshold` |
| `get_stock_summary()` | `product_count`, `total_units`, `cost_value_millimes`, `retail_value_millimes` |

All "day" logic uses `(created_at at time zone 'Africa/Tunis')::date` and `(now() at time zone 'Africa/Tunis')::date`.

## 6. Security

```sql
alter table public.products enable row level security;
-- repeat for every table
revoke all on table public.products from anon, authenticated;
-- repeat for every table

alter function public.create_sale(jsonb) security definer;
alter function public.create_sale(jsonb) set search_path = public;
revoke execute on function public.create_sale(jsonb) from anon, authenticated, public;
grant execute on function public.create_sale(jsonb) to service_role;
```

- Server-only client uses the secret key (`service_role`), which bypasses RLS.
- No policies are created; direct browser access is denied.
- Verify with Supabase **Security Advisor** (no "RLS disabled" findings).

## 7. TypeScript types

`src/types/db.ts` mirrors rows and RPC payloads:

```ts
export type Product = {
  id: string; name: string; barcode: string | null; category_id: string | null;
  price_millimes: number; cost_millimes: number; stock_quantity: number;
  low_stock_threshold: number; is_active: boolean;
  created_at: string; updated_at: string;
};
export type SaleItemInput = { product_id: string; quantity: number };
export type SaleResult = { sale_id: string; receipt_number: string; total_millimes: number; created_at: string; items: SaleItemSnapshot[] };
```

## 8. Seed data

- `settings`: `Pharmacie Centrale`, Tunis address, phone, footer.
- Categories: Antalgiques, Antibiotiques, Anti-inflammatoires, Digestif, ORL, Vitamines, Dermatologie, Matériel.
- ~40 products with realistic names (Doliprane, Efferalgan, Amoxicilline, Spasfon, Gaviscon, Smecta, Vitamine C, Bétadine, sérum physiologique…), prices in millimes, barcodes, and a mix of healthy/low/zero stock.

## 9. Acceptance criteria

- [ ] All SQL files run top-to-bottom with no errors on a fresh project.
- [ ] Re-running `001_schema.sql` fails safely or is documented as one-time only.
- [ ] `create_sale` succeeds for valid input and returns the expected total.
- [ ] `create_sale` fails without changing stock when quantity > stock.
- [ ] Concurrent `create_sale` calls for the last unit: exactly one succeeds (tested manually with two SQL sessions or documented).
- [ ] `adjust_stock` prevents negative stock and writes an audit row.
- [ ] Dashboard functions return correct values for a known fixture (e.g. seeded/manual sale).
- [ ] RLS enabled on all 6 tables; `anon`/`authenticated` have no table grants.
- [ ] `src/lib/supabase/admin.ts` is server-only and typed; a smoke query returns products.
- [ ] Seed counts: 8 categories, 40 products, 1 settings row.

## 10. Task breakdown

| # | Task | Owner |
| --- | --- | --- |
| 1.1 | Write `db/001_schema.sql` (tables, indexes, triggers, RLS) | `db-architect` |
| 1.2 | Write `db/002_functions.sql` (sale, stock, dashboard) | `db-architect` |
| 1.3 | Write `db/003_seed.sql` (settings, categories, products) | `db-architect` |
| 1.4 | Types + Supabase admin client + env example | `db-architect` |
| 1.5 | SQL smoke tests (`db/smoke.sql`), security checks | `db-architect` |
| 1.6 | Review schema/functions, verify acceptance, commit `phase-1` | Lead |

## 11. Risks

| Risk | Mitigation |
| --- | --- |
| Legacy keys deprecated end-2026 | Use `sb_secret_…`; never commit it |
| Secret key in client bundle | `server-only`; no `NEXT_PUBLIC_`; review imports |
| Race on last unit | `FOR UPDATE` + check constraint |
| Time-zone drift in "today" | Fixed `Africa/Tunis` expressions in every function |
| Seed drift from real prices | Prices are demo data; settings editable in Phase 2 |
