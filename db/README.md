# PharmaCare — Data Layer (Phase 1)

SQL files for the Supabase Postgres database, plus the TypeScript types that
mirror it. There is no Supabase CLI or `psql` requirement: every file is meant
to be pasted into the Supabase **SQL Editor** as the project owner.

The application talks to the database with the server-only secret key
(`service_role`). No browser role has access to these tables or functions.

## 1. Files and run order

Run the files **in this order** in the SQL Editor:

| # | File | Purpose | Expected result |
| - | ---- | ------- | --------------- |
| 1 | `001_schema.sql` | Tables, checks, indexes, `updated_at` triggers, RLS, grants, receipt sequence | `Success. No rows returned` |
| 2 | `002_functions.sql` | `create_sale`, `adjust_stock`, dashboard functions, function grants | `Success. No rows returned` |
| 3 | `003_seed.sql` | Settings row, 8 categories, 40 products | `Success. No rows returned` + `NOTICE: seed: 8 categories, 40 products, 1 settings row(s)` |
| 4 | `004_demo_sales.sql` | **Optional / demo only**: ~2–4 sales per day for the last 14 days | `Success. No rows returned` + `NOTICE: demo sales created: N` |
| 5 | `smoke.sql` | Transactional assertions; ends with `ROLLBACK` | `NOTICE` lines for each passing check, then `ROLLBACK` |

Do not run `004_demo_sales.sql` on a real pharmacy database. It exists only so
the Phase 4 dashboard has data to display.

`smoke.sql` deliberately runs inside `begin; ... rollback;`. It creates one
test sale and rolls it back, so neither the sale nor the stock changes persist.

## 2. Prerequisites

1. A Supabase project (Free plan is enough).
2. The project URL and a secret key (`sb_secret_…`) in `.env.local`:

   ```bash
   SUPABASE_URL=https://<project-ref>.supabase.co
   SUPABASE_SECRET_KEY=sb_secret_...
   ```

   Never commit `.env.local`, and never expose this key to the browser. The
   client in `src/lib/supabase/admin.ts` imports `server-only`.

3. Paste each file into **SQL Editor → New query → Run**. The SQL Editor runs
   as the `postgres` role, which owns the objects and bypasses RLS.

## 3. What gets created

### Tables

| Table | Notes |
| ----- | ----- |
| `categories` | Unique category names; `created_at` |
| `products` | Price/cost in millimes, nullable unique barcode (partial index), stock, threshold, `is_active`, `updated_at` trigger |
| `sales` | `receipt_number` unique (`V-000001`), integer total, cash only |
| `sale_items` | Immutable name/price snapshots; cascades from `sales`, product delete sets it to NULL |
| `stock_movements` | Audit trail: `sale`, `restock`, `adjustment`; `reference_id` is the sale id for sales |
| `settings` | Single row (`id = 1`) with pharmacy identity and receipt footer |

`products.stock_quantity >= 0` is enforced by a check constraint and by the
`create_sale`/`adjust_stock` functions. Sale totals are always recomputed on
the server from `products.price_millimes`; client prices are ignored.

### Functions (all `security definer`, `search_path = public`)

| Function | Returns |
| -------- | ------- |
| `create_sale(p_items jsonb)` | `jsonb` receipt payload |
| `adjust_stock(p_product_id uuid, p_delta integer, p_note text)` | new stock `integer` |
| `get_dashboard_summary()` | `jsonb` with today/yesterday revenue, counts, average basket |
| `get_sales_trend(p_days integer)` | `table(day date, revenue_millimes bigint, sales_count bigint)` |
| `get_top_products(p_days integer, p_limit integer)` | `table(product_id uuid, name text, quantity bigint, revenue_millimes bigint)` |
| `get_low_stock_products(p_limit integer)` | `table(id uuid, name text, stock_quantity integer, low_stock_threshold integer)` |
| `get_stock_summary()` | `jsonb` with product count, units, cost/retail value |

`p_days` is clamped to `1..365`; `p_limit` is clamped to `1..100`. All day
boundaries use `Africa/Tunis`, for example:

```sql
(created_at at time zone 'Africa/Tunis')::date = (now() at time zone 'Africa/Tunis')::date
```

`create_sale` merges duplicate product lines, locks product rows with
`SELECT ... FOR UPDATE`, and raises `stock_insufficient:<product_id>:<available>`
when stock is too low. The sale, its item snapshots, the stock decrements and
the `sale` movements are all written in one transaction.

`get_dashboard_summary().today_avg_basket` is rounded to the nearest millime
and returned as an integer (bigint in SQL, `number` in TypeScript).

## 4. Security model

- RLS is enabled on all six tables.
- Table privileges are revoked from `anon` and `authenticated`; no policies are
  created. Direct browser access is denied even if a grant is accidentally
  restored later, because no policy allows a row.
- All seven public functions have `EXECUTE` revoked from `PUBLIC`, `anon` and
  `authenticated`, and granted only to `service_role`.
- `SET search_path = public` prevents search-path hijacking on the
  `security definer` functions.
- `service_role` bypasses RLS and is only used from server code.
- After running the files, open **Security Advisor** in Supabase: there should
  be no “RLS disabled” findings for these tables.

## 5. Verification queries

### Seed counts

```sql
select 'categories' as entity, count(*) as row_count from public.categories
union all
select 'products', count(*) from public.products
union all
select 'settings', count(*) from public.settings
union all
select 'sales', count(*) from public.sales
union all
select 'sale_items', count(*) from public.sale_items
union all
select 'stock_movements', count(*) from public.stock_movements;
```

Expected after `003_seed.sql`: `categories = 8`, `products = 40`,
`settings = 1`; sales-related counts are `0` until you run the demo or make a
sale.

### RLS enabled

```sql
select c.relname, c.relrowsecurity
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in (
    'categories', 'products', 'sales', 'sale_items', 'stock_movements', 'settings'
  )
order by c.relname;
```

Expected: `relrowsecurity = true` on all six rows.

### No browser grants

`has_table_privilege` / `has_function_privilege` account for direct grants and
grants inherited through `PUBLIC`, which `information_schema.role_*_grants`
can hide for roles the current session is not a member of.

```sql
select c.relname as table_name
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and c.relname in (
    'categories', 'products', 'sales', 'sale_items', 'stock_movements', 'settings'
  )
  and (
    has_table_privilege('anon', c.oid, 'SELECT,INSERT,UPDATE,DELETE')
    or has_table_privilege('authenticated', c.oid, 'SELECT,INSERT,UPDATE,DELETE')
  )
order by c.relname;
```

Expected: zero rows.

```sql
select p.proname as function_name
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'set_updated_at', 'create_sale', 'adjust_stock',
    'get_dashboard_summary', 'get_sales_trend', 'get_top_products',
    'get_low_stock_products', 'get_stock_summary'
  )
  and (
    has_function_privilege('anon', p.oid, 'EXECUTE')
    or has_function_privilege('authenticated', p.oid, 'EXECUTE')
  )
order by p.proname;
```

Expected: zero rows (only `service_role` and the owner may execute them).

### A real sale, rolled back

```sql
begin;

select public.create_sale(jsonb_build_array(
  jsonb_build_object(
    'product_id', (select id from public.products
                   where is_active and stock_quantity > 0
                   order by id limit 1),
    'quantity', 1
  )
));

rollback;
```

Expected: one row with `sale_id`, `receipt_number` (`V-…`), `total_millimes`,
`created_at`, and an `items` array. The rollback removes the sale.

### Dashboard functions

```sql
select public.get_dashboard_summary() as summary;
select * from public.get_sales_trend(7);
select * from public.get_top_products(30, 5);
select * from public.get_low_stock_products(8);
select public.get_stock_summary() as stock;
```

Without demo sales, `get_sales_trend` is still expected to return 7 rows
(gap-filled with zeros), and `get_top_products` may return zero rows.

### Stock invariants

```sql
select count(*) as negative_stock_products
from public.products
where stock_quantity < 0;
-- expected 0

select count(*) as inconsistent_sales
from public.sales s
where s.total_millimes <> (
  select coalesce(sum(si.line_total_millimes), 0)
  from public.sale_items si where si.sale_id = s.id
);
-- expected 0
```

## 6. Re-running safely

| File | Re-run behaviour |
| ---- | ---------------- |
| `001_schema.sql` | Safe for the current schema: `CREATE TABLE/INDEX/SEQUENCE IF NOT EXISTS`, triggers dropped and recreated, grants idempotent. It does **not** migrate an existing table; add a new file for structural changes. |
| `002_functions.sql` | Safe: `CREATE OR REPLACE` plus repeated `REVOKE`/`GRANT`. |
| `003_seed.sql` | Safe: `ON CONFLICT DO NOTHING` on settings, category names and product barcodes. Existing rows are never updated. |
| `004_demo_sales.sql` | Safe: does nothing if `public.sales` already has at least one row. |
| `smoke.sql` | Safe: always ends with `ROLLBACK`. |

### Seed conflicts

Categories conflict on `name`. Products conflict on the partial unique index:

```sql
on conflict (barcode) where barcode is not null do nothing
```

PostgreSQL requires the `WHERE` predicate in the conflict target to match a
partial unique index before it can infer that index. The index is created in
`001_schema.sql` as:

```sql
create unique index products_barcode_key
  on public.products (barcode)
  where barcode is not null;
```

If the predicate is ever changed, update both statements together. A
targetless `on conflict do nothing` would also be safe; the explicit target is
kept to document the intended key and to catch accidental unique-key drift.

## 7. Resetting demo data

**Warning:** this deletes every sale, not only demo sales. Use it only on a
development/demo database.

```sql
begin;

-- Give sold units back to products (sale deltas are negative).
with sold as (
  select product_id, sum(delta) as delta
  from public.stock_movements
  where reason = 'sale'
  group by product_id
)
update public.products p
set stock_quantity = p.stock_quantity - sold.delta
from sold
where p.id = sold.product_id;

-- sale_items cascades from sales.
delete from public.sales;
delete from public.stock_movements where reason = 'sale';

-- Optional: restart receipt numbering once the sales table is empty.
select setval('public.sale_receipt_seq', 1, false);

commit;
```

Then run `004_demo_sales.sql` again if you want a fresh demo history.

Receipt numbers can contain gaps even without demo data: the sequence is
non-transactional, so a failed or rolled-back `create_sale` still consumes a
number. This is intentional — a receipt number is never reused.

## 8. Troubleshooting

| Symptom | Cause / fix |
| ------- | ----------- |
| `there is no unique or exclusion constraint matching the ON CONFLICT specification` | The partial barcode index is missing, or the `WHERE` predicate in `003_seed.sql` no longer matches it. Re-run `001_schema.sql` and keep both predicates identical. |
| `permission denied for function create_sale` | Function grants were not applied. Re-run `002_functions.sql`. Remember the app must use the secret key, not the anon key. |
| `permission denied for sequence sale_receipt_seq` | Re-run the grant section of `001_schema.sql`. |
| Dashboard “today” looks empty although sales exist | Check the server time zone is UTC and that all queries use `at time zone 'Africa/Tunis'`; do not compare UTC dates directly. |
| `new row violates check constraint products_stock_quantity_check` | A direct table write bypassed `create_sale`/`adjust_stock`. Use the functions for stock changes. |
| Seed products missing after re-run | A barcode already exists with different data; `ON CONFLICT DO NOTHING` skipped the row by design. Inspect `select * from products where barcode = '…'`. |
