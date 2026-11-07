-- PharmaCare — Phase 1: smoke tests
-- Target: PostgreSQL 15+ (Supabase SQL Editor)
--
-- Paste this whole file into the SQL Editor after 001 + 002 + 003 (+ optional
-- 004). It runs inside one transaction and ends with ROLLBACK, so the test
-- sale, stock changes and audit rows are never persisted.
--
-- Any failed assertion raises an exception and aborts the transaction; the SQL
-- Editor shows the message. Success prints NOTICE lines and "Success. No rows
-- returned." after the rollback.
--
-- Note: receipt sequence numbers are not transactional. The rolled-back test
-- sale consumes one sequence value, so receipt numbers may have gaps. That is
-- expected and documented in db/README.md.

begin;

-- ---------------------------------------------------------------------------
-- 1. Seed counts and RLS/grants
-- ---------------------------------------------------------------------------

do $$
declare
  v_count integer;
begin
  select count(*) into v_count from public.categories;
  if v_count < 8 then
    raise exception 'smoke: expected at least 8 categories, found %', v_count;
  end if;

  select count(*) into v_count from public.products;
  if v_count < 40 then
    raise exception 'smoke: expected at least 40 products, found %', v_count;
  end if;

  select count(*) into v_count from public.settings where id = 1;
  if v_count <> 1 then
    raise exception 'smoke: expected exactly one settings row, found %', v_count;
  end if;

  select count(*) into v_count
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname in (
      'categories', 'products', 'sales', 'sale_items', 'stock_movements', 'settings'
    )
    and c.relrowsecurity;
  if v_count <> 6 then
    raise exception 'smoke: RLS is enabled on % of 6 tables', v_count;
  end if;

  select count(*) into v_count
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname in (
      'categories', 'products', 'sales', 'sale_items', 'stock_movements', 'settings'
    )
    and c.relkind = 'r'
    and (
      has_table_privilege('anon', c.oid, 'SELECT,INSERT,UPDATE,DELETE')
      or has_table_privilege('authenticated', c.oid, 'SELECT,INSERT,UPDATE,DELETE')
    );
  if v_count > 0 then
    raise exception 'smoke: % table grant(s) leak to anon/authenticated', v_count;
  end if;

  select count(*) into v_count
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in (
      'set_updated_at',
      'create_sale',
      'adjust_stock',
      'get_dashboard_summary',
      'get_sales_trend',
      'get_top_products',
      'get_low_stock_products',
      'get_stock_summary'
    )
    and (
      has_function_privilege('anon', p.oid, 'EXECUTE')
      or has_function_privilege('authenticated', p.oid, 'EXECUTE')
    );
  if v_count > 0 then
    raise exception 'smoke: % function grant(s) leak to anon/authenticated/PUBLIC', v_count;
  end if;

  raise notice 'smoke: seed counts, RLS and grants ok';
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Stock / sale invariants
-- ---------------------------------------------------------------------------

do $$
declare
  v_bad integer;
begin
  select count(*) into v_bad from public.products where stock_quantity < 0;
  if v_bad > 0 then
    raise exception 'smoke: % product(s) have negative stock', v_bad;
  end if;

  select count(*) into v_bad
  from public.sales s
  where s.total_millimes <> (
    select coalesce(sum(si.line_total_millimes), 0)
    from public.sale_items si
    where si.sale_id = s.id
  );
  if v_bad > 0 then
    raise exception 'smoke: % sale(s) have a total different from their line sum', v_bad;
  end if;

  select count(*) into v_bad
  from public.sale_items si
  where si.line_total_millimes <> si.unit_price_millimes * si.quantity;
  if v_bad > 0 then
    raise exception 'smoke: % sale item(s) have an inconsistent line total', v_bad;
  end if;

  select count(*) into v_bad
  from public.sale_items si
  where si.product_id is not null
    and not exists (
      select 1
      from public.stock_movements sm
      where sm.reason = 'sale'
        and sm.reference_id = si.sale_id
        and sm.product_id = si.product_id
        and sm.delta = -si.quantity
    );
  if v_bad > 0 then
    raise exception 'smoke: % sale item(s) have no matching stock movement', v_bad;
  end if;

  select count(*) into v_bad
  from public.sales
  where receipt_number !~ '^V-[0-9]{6,}$';
  if v_bad > 0 then
    raise exception 'smoke: % sale(s) have a malformed receipt number', v_bad;
  end if;

  raise notice 'smoke: stock and sale invariants ok';
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. create_sale success path (duplicate lines must merge)
-- ---------------------------------------------------------------------------

do $$
declare
  v_product record;
  v_before integer;
  v_after integer;
  v_result jsonb;
begin
  select p.id, p.name, p.price_millimes, p.stock_quantity
  into v_product
  from public.products p
  where p.is_active
    and p.stock_quantity >= 3
  order by p.id
  limit 1;

  if not found then
    raise exception 'smoke: no active product with stock >= 3 for the success test';
  end if;

  v_before := v_product.stock_quantity;

  v_result := public.create_sale(jsonb_build_array(
    jsonb_build_object('product_id', v_product.id, 'quantity', 2),
    jsonb_build_object('product_id', v_product.id, 'quantity', 1)
  ));

  if (v_result->>'receipt_number') !~ '^V-[0-9]{6,}$' then
    raise exception 'smoke: unexpected receipt number %', v_result->>'receipt_number';
  end if;

  if (v_result->>'total_millimes')::integer <> v_product.price_millimes * 3 then
    raise exception 'smoke: expected total %, got %',
      v_product.price_millimes * 3, v_result->>'total_millimes';
  end if;

  if jsonb_array_length(v_result->'items') <> 1 then
    raise exception 'smoke: duplicate product lines were not merged (got % lines)',
      jsonb_array_length(v_result->'items');
  end if;

  select p.stock_quantity into v_after
  from public.products p
  where p.id = v_product.id;

  if v_after <> v_before - 3 then
    raise exception 'smoke: stock after sale should be %, got %', v_before - 3, v_after;
  end if;

  raise notice 'smoke: create_sale ok (receipt %, total %)',
    v_result->>'receipt_number', v_result->>'total_millimes';
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. create_sale insufficient-stock failure (must not change stock)
-- ---------------------------------------------------------------------------

do $$
declare
  v_product record;
  v_before integer;
  v_after integer;
  v_failed boolean := false;
begin
  select p.id, p.stock_quantity
  into v_product
  from public.products p
  where p.is_active
    and p.stock_quantity < 999
  order by p.stock_quantity asc, p.id
  limit 1;

  if not found then
    raise exception 'smoke: no active product with stock < 999 for the failure test';
  end if;

  v_before := v_product.stock_quantity;

  begin
    perform public.create_sale(jsonb_build_array(
      jsonb_build_object('product_id', v_product.id, 'quantity', 999)
    ));
  exception
    when others then
      if sqlerrm not like 'stock_insufficient:%' then
        raise exception 'smoke: expected stock_insufficient, got: %', sqlerrm;
      end if;
      v_failed := true;
  end;

  if not v_failed then
    raise exception 'smoke: create_sale accepted 999 units with only % in stock', v_before;
  end if;

  select p.stock_quantity into v_after
  from public.products p
  where p.id = v_product.id;

  if v_after <> v_before then
    raise exception 'smoke: failed sale changed stock from % to %', v_before, v_after;
  end if;

  raise notice 'smoke: insufficient stock rejected without side effects';
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. adjust_stock failure path (negative result must be rejected)
-- ---------------------------------------------------------------------------

do $$
declare
  v_product record;
  v_failed boolean := false;
begin
  select p.id, p.stock_quantity
  into v_product
  from public.products p
  where p.is_active
  order by p.stock_quantity asc, p.id
  limit 1;

  begin
    perform public.adjust_stock(v_product.id, -(v_product.stock_quantity + 1), 'smoke test');
  exception
    when others then
      if sqlerrm not like 'stock_insufficient:%' then
        raise exception 'smoke: unexpected adjust_stock error: %', sqlerrm;
      end if;
      v_failed := true;
  end;

  if not v_failed then
    raise exception 'smoke: adjust_stock allowed negative stock';
  end if;

  raise notice 'smoke: adjust_stock negative result rejected';
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Dashboard functions (shape, clamping and gap filling)
-- ---------------------------------------------------------------------------

do $$
declare
  v_summary jsonb;
  v_stock jsonb;
  v_count integer;
begin
  v_summary := public.get_dashboard_summary();
  if not (
    v_summary ? 'today_revenue'
    and v_summary ? 'today_sales'
    and v_summary ? 'today_avg_basket'
    and v_summary ? 'yesterday_revenue'
    and v_summary ? 'yesterday_sales'
  ) then
    raise exception 'smoke: get_dashboard_summary is missing keys: %', v_summary;
  end if;

  if (v_summary->>'today_sales')::bigint < 1 then
    raise exception 'smoke: today_sales should include the test sale';
  end if;

  select count(*) into v_count from public.get_sales_trend(7);
  if v_count <> 7 then
    raise exception 'smoke: get_sales_trend(7) returned % rows instead of 7', v_count;
  end if;

  select count(*) into v_count from public.get_sales_trend(0);
  if v_count <> 1 then
    raise exception 'smoke: get_sales_trend(0) should clamp to 1 row, got %', v_count;
  end if;

  select count(*) into v_count from public.get_sales_trend(1000);
  if v_count <> 365 then
    raise exception 'smoke: get_sales_trend(1000) should clamp to 365 rows, got %', v_count;
  end if;

  select count(*) into v_count from public.get_top_products(30, 0);
  if v_count <> 1 then
    raise exception 'smoke: get_top_products(30, 0) should clamp to 1 row, got %', v_count;
  end if;

  select count(*) into v_count from public.get_low_stock_products(0);
  if v_count <> 1 then
    raise exception 'smoke: get_low_stock_products(0) should clamp to 1 row, got %', v_count;
  end if;

  select count(*) into v_count from public.get_low_stock_products(1000);
  if v_count > 100 then
    raise exception 'smoke: get_low_stock_products(1000) should clamp to 100 rows, got %', v_count;
  end if;

  v_stock := public.get_stock_summary();
  if not (
    v_stock ? 'product_count'
    and v_stock ? 'total_units'
    and v_stock ? 'cost_value_millimes'
    and v_stock ? 'retail_value_millimes'
  ) then
    raise exception 'smoke: get_stock_summary is missing keys: %', v_stock;
  end if;

  if (v_stock->>'product_count')::bigint < 1 then
    raise exception 'smoke: get_stock_summary returned no active products';
  end if;

  raise notice 'smoke: dashboard functions ok (% sales today)', v_summary->>'today_sales';
end;
$$;

-- Roll back the test sale and any stock/audit changes above.
rollback;
