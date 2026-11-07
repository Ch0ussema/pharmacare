-- PharmaCare — Phase 1: business functions
-- Target: PostgreSQL 15+ (Supabase)
--
-- Run after 001_schema.sql. Re-runnable: every function is CREATE OR REPLACE
-- and privileges are revoked/granted again at the end.
--
-- Conventions:
--   * Money = integer millimes, computed server-side.
--   * "Day" = Africa/Tunis calendar day.
--   * Errors are raised with the default SQLSTATE P0001 and a stable,
--     machine-readable prefix (e.g. stock_insufficient:<uuid>:<available>).

begin;

-- ---------------------------------------------------------------------------
-- create_sale(p_items jsonb) -> jsonb
--
-- Input: [{"product_id": "uuid", "quantity": 2}, ...]
--
-- The whole function runs inside the caller's transaction. Product rows are
-- locked with FOR UPDATE before stock is checked, so two concurrent sales
-- cannot both consume the last unit. Prices are read from products; any price
-- sent by the client is ignored.
-- ---------------------------------------------------------------------------

create or replace function public.create_sale(p_items jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_line jsonb;
  v_merged jsonb;
  v_product_ids uuid[];
  v_product public.products%rowtype;
  v_qty integer;
  v_total bigint := 0;
  v_line_total bigint;
  v_sale_id uuid;
  v_receipt_number text;
  v_created_at timestamptz;
  v_result_items jsonb := '[]'::jsonb;
begin
  -- 1. Basic payload validation -------------------------------------------------
  if p_items is null then
    raise exception 'sale_empty: at least one item is required';
  end if;

  if jsonb_typeof(p_items) <> 'array' then
    raise exception 'sale_empty: at least one item is required';
  end if;

  if jsonb_array_length(p_items) = 0 then
    raise exception 'sale_empty: at least one item is required';
  end if;

  for v_line in
    select elem.value
    from jsonb_array_elements(p_items) as elem(value)
  loop
    if jsonb_typeof(v_line) <> 'object' then
      raise exception 'invalid_item: each item must be an object';
    end if;

    if nullif(v_line->>'product_id', '') is null then
      raise exception 'invalid_item: product_id is required';
    end if;

    if (v_line->>'product_id') !~*
       '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      raise exception 'invalid_item: product_id must be a valid uuid';
    end if;

    if nullif(v_line->>'quantity', '') is null then
      raise exception 'invalid_item: quantity is required';
    end if;

    begin
      v_qty := (v_line->>'quantity')::integer;
    exception
      when invalid_text_representation or numeric_value_out_of_range then
        raise exception 'invalid_quantity: quantity must be an integer between 1 and 999';
    end;

    if v_qty < 1 or v_qty > 999 then
      raise exception 'invalid_quantity: quantity must be between 1 and 999 (got %)', v_qty;
    end if;
  end loop;

  -- 2. Merge duplicate product lines -------------------------------------------
  -- first_position preserves the cart order in the returned receipt while
  -- quantities for the same product are summed into one line.
  select jsonb_agg(
           jsonb_build_object(
             'product_id', merged.product_id,
             'quantity', merged.quantity
           )
           order by merged.first_position
         )
  into v_merged
  from (
    select (elem.value->>'product_id')::uuid as product_id,
           sum((elem.value->>'quantity')::integer) as quantity,
           min(elem.ordinal) as first_position
    from jsonb_array_elements(p_items) with ordinality as elem(value, ordinal)
    group by 1
  ) as merged;

  for v_line in
    select elem.value
    from jsonb_array_elements(v_merged) as elem(value)
  loop
    if (v_line->>'quantity')::bigint > 999 then
      raise exception 'invalid_quantity: total quantity per product must not exceed 999';
    end if;
  end loop;

  select array_agg((elem.value->>'product_id')::uuid order by (elem.value->>'product_id')::uuid)
  into v_product_ids
  from jsonb_array_elements(v_merged) as elem(value);

  -- 3. Lock product rows (sorted to keep a deterministic lock order) -----------
  perform p.id
  from public.products p
  where p.id = any (v_product_ids)
  order by p.id
  for update;

  -- 4. Validate products/stock and compute the total server-side ---------------
  for v_line in
    select elem.value
    from jsonb_array_elements(v_merged) as elem(value)
  loop
    select * into v_product
    from public.products
    where id = (v_line->>'product_id')::uuid;

    if not found then
      raise exception 'product_not_found:%', v_line->>'product_id';
    end if;

    if not v_product.is_active then
      raise exception 'product_inactive:%', v_product.id;
    end if;

    v_qty := (v_line->>'quantity')::integer;

    if v_product.stock_quantity < v_qty then
      raise exception 'stock_insufficient:%:%', v_product.id, v_product.stock_quantity;
    end if;

    v_line_total := v_product.price_millimes::bigint * v_qty;
    v_total := v_total + v_line_total;
  end loop;

  if v_total > 2147483647 then
    raise exception 'sale_total_overflow: total exceeds the supported maximum';
  end if;

  -- 5. Create the sale ---------------------------------------------------------
  -- nextval() is deliberately outside the rollback scope: failed sales leave
  -- gaps in receipt numbers rather than reusing a number.
  v_receipt_number := 'V-' || lpad(nextval('public.sale_receipt_seq')::text, 6, '0');

  insert into public.sales (receipt_number, total_millimes, payment_method)
  values (v_receipt_number, v_total::integer, 'cash')
  returning id, created_at into v_sale_id, v_created_at;

  -- 6. Snapshot lines, decrement stock, log movements --------------------------
  for v_line in
    select elem.value
    from jsonb_array_elements(v_merged) as elem(value)
  loop
    select * into v_product
    from public.products
    where id = (v_line->>'product_id')::uuid;

    v_qty := (v_line->>'quantity')::integer;
    v_line_total := v_product.price_millimes::bigint * v_qty;

    insert into public.sale_items (
      sale_id,
      product_id,
      product_name,
      unit_price_millimes,
      quantity,
      line_total_millimes
    )
    values (
      v_sale_id,
      v_product.id,
      v_product.name,
      v_product.price_millimes,
      v_qty,
      v_line_total::integer
    );

    update public.products
    set stock_quantity = stock_quantity - v_qty
    where id = v_product.id;

    insert into public.stock_movements (product_id, delta, reason, reference_id)
    values (v_product.id, -v_qty, 'sale', v_sale_id);

    v_result_items := v_result_items || jsonb_build_array(
      jsonb_build_object(
        'product_id', v_product.id,
        'product_name', v_product.name,
        'unit_price_millimes', v_product.price_millimes,
        'quantity', v_qty,
        'line_total_millimes', v_line_total::integer
      )
    );
  end loop;

  -- 7. Return the receipt payload ---------------------------------------------
  return jsonb_build_object(
    'sale_id', v_sale_id,
    'receipt_number', v_receipt_number,
    'total_millimes', v_total::integer,
    'created_at', v_created_at,
    'items', v_result_items
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- adjust_stock(p_product_id, p_delta, p_note) -> integer
--
-- Manual stock correction. delta > 0 is logged as 'restock', delta < 0 as
-- 'adjustment'. Rejects a zero delta and any result below zero.
-- ---------------------------------------------------------------------------

create or replace function public.adjust_stock(
  p_product_id uuid,
  p_delta integer,
  p_note text default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_stock integer;
  v_new_stock bigint;
begin
  if p_delta is null or p_delta = 0 then
    raise exception 'invalid_delta: delta must be a non-zero integer';
  end if;

  select stock_quantity
  into v_stock
  from public.products
  where id = p_product_id
  for update;

  if not found then
    raise exception 'product_not_found:%', p_product_id;
  end if;

  v_new_stock := v_stock::bigint + p_delta::bigint;

  if v_new_stock < 0 then
    raise exception 'stock_insufficient:%:%', p_product_id, v_stock;
  end if;

  if v_new_stock > 2147483647 then
    raise exception 'stock_overflow: resulting stock exceeds the supported maximum';
  end if;

  update public.products
  set stock_quantity = v_new_stock::integer
  where id = p_product_id;

  insert into public.stock_movements (product_id, delta, reason, note)
  values (
    p_product_id,
    p_delta,
    case when p_delta > 0 then 'restock' else 'adjustment' end,
    p_note
  );

  return v_new_stock::integer;
end;
$$;

-- ---------------------------------------------------------------------------
-- Dashboard functions
-- ---------------------------------------------------------------------------

-- Returns today's and yesterday's revenue/count in Africa/Tunis.
--
-- today_avg_basket is rounded to the nearest millime (numeric round, then
-- cast to bigint) because the TypeScript layer works with integers only.
-- When there are no sales today the average is 0.
create or replace function public.get_dashboard_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_today date := (now() at time zone 'Africa/Tunis')::date;
  v_today_revenue bigint;
  v_today_sales bigint;
  v_yesterday_revenue bigint;
  v_yesterday_sales bigint;
  v_avg_basket bigint;
begin
  select coalesce(sum(total_millimes), 0)::bigint,
         count(*)::bigint
  into v_today_revenue, v_today_sales
  from public.sales
  where (created_at at time zone 'Africa/Tunis')::date = v_today;

  select coalesce(sum(total_millimes), 0)::bigint,
         count(*)::bigint
  into v_yesterday_revenue, v_yesterday_sales
  from public.sales
  where (created_at at time zone 'Africa/Tunis')::date = v_today - 1;

  if v_today_sales = 0 then
    v_avg_basket := 0;
  else
    v_avg_basket := round(v_today_revenue::numeric / v_today_sales)::bigint;
  end if;

  return jsonb_build_object(
    'today_revenue', v_today_revenue,
    'today_sales', v_today_sales,
    'today_avg_basket', v_avg_basket,
    'yesterday_revenue', v_yesterday_revenue,
    'yesterday_sales', v_yesterday_sales
  );
end;
$$;

-- Revenue and sale count per Africa/Tunis day, gap-filled for every day in
-- the requested window, oldest first. p_days is clamped to 1..365.
create or replace function public.get_sales_trend(p_days integer default 7)
returns table (
  day date,
  revenue_millimes bigint,
  sales_count bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_days integer := least(greatest(coalesce(p_days, 7), 1), 365);
  v_today date := (now() at time zone 'Africa/Tunis')::date;
begin
  return query
  with series as (
    select generate_series(
             (v_today - (v_days - 1))::timestamp,
             v_today::timestamp,
             interval '1 day'
           )::date as day
  ),
  daily as (
    select (s.created_at at time zone 'Africa/Tunis')::date as sale_day,
           sum(s.total_millimes)::bigint as revenue,
           count(*)::bigint as sale_count
    from public.sales s
    where (s.created_at at time zone 'Africa/Tunis')::date
          between v_today - (v_days - 1) and v_today
    group by 1
  )
  select series.day,
         coalesce(daily.revenue, 0)::bigint,
         coalesce(daily.sale_count, 0)::bigint
  from series
  left join daily on daily.sale_day = series.day
  order by series.day;
end;
$$;

-- Top products by units sold in the window. p_days is clamped to 1..365 and
-- p_limit to 1..100. The product_name snapshot is used as a fallback if the
-- live product row is missing.
create or replace function public.get_top_products(
  p_days integer default 30,
  p_limit integer default 5
)
returns table (
  product_id uuid,
  name text,
  quantity bigint,
  revenue_millimes bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_days integer := least(greatest(coalesce(p_days, 30), 1), 365);
  v_limit integer := least(greatest(coalesce(p_limit, 5), 1), 100);
  v_today date := (now() at time zone 'Africa/Tunis')::date;
begin
  return query
  select si.product_id,
         coalesce(p.name, max(si.product_name)) as display_name,
         sum(si.quantity)::bigint as sold_quantity,
         sum(si.line_total_millimes)::bigint as revenue
  from public.sale_items si
  join public.sales s on s.id = si.sale_id
  left join public.products p on p.id = si.product_id
  where si.product_id is not null
    and (s.created_at at time zone 'Africa/Tunis')::date
        between v_today - (v_days - 1) and v_today
  group by si.product_id, p.name
  order by sum(si.quantity) desc,
           sum(si.line_total_millimes) desc,
           si.product_id
  limit v_limit;
end;
$$;

-- Active products at or below their low-stock threshold. Out-of-stock rows
-- come first, then the lowest stock, then alphabetical order.
create or replace function public.get_low_stock_products(p_limit integer default 8)
returns table (
  id uuid,
  name text,
  stock_quantity integer,
  low_stock_threshold integer
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 8), 1), 100);
begin
  return query
  select p.id,
         p.name,
         p.stock_quantity,
         p.low_stock_threshold
  from public.products p
  where p.is_active
    and p.stock_quantity <= p.low_stock_threshold
  order by (p.stock_quantity = 0) desc,
           p.stock_quantity asc,
           p.name asc
  limit v_limit;
end;
$$;

-- Aggregate value of active stock. Values use bigint because units * price can
-- exceed the int4 range for a large catalogue.
create or replace function public.get_stock_summary()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'product_count', count(*)::bigint,
    'total_units', coalesce(sum(stock_quantity), 0)::bigint,
    'cost_value_millimes', coalesce(sum(stock_quantity::bigint * cost_millimes), 0)::bigint,
    'retail_value_millimes', coalesce(sum(stock_quantity::bigint * price_millimes), 0)::bigint
  )
  from public.products
  where is_active;
$$;

-- ---------------------------------------------------------------------------
-- Privileges: browser roles have no access; the server secret key only.
-- ---------------------------------------------------------------------------

revoke execute on function public.create_sale(jsonb) from public, anon, authenticated;
revoke execute on function public.adjust_stock(uuid, integer, text) from public, anon, authenticated;
revoke execute on function public.get_dashboard_summary() from public, anon, authenticated;
revoke execute on function public.get_sales_trend(integer) from public, anon, authenticated;
revoke execute on function public.get_top_products(integer, integer) from public, anon, authenticated;
revoke execute on function public.get_low_stock_products(integer) from public, anon, authenticated;
revoke execute on function public.get_stock_summary() from public, anon, authenticated;

grant execute on function public.create_sale(jsonb) to service_role;
grant execute on function public.adjust_stock(uuid, integer, text) to service_role;
grant execute on function public.get_dashboard_summary() to service_role;
grant execute on function public.get_sales_trend(integer) to service_role;
grant execute on function public.get_top_products(integer, integer) to service_role;
grant execute on function public.get_low_stock_products(integer) to service_role;
grant execute on function public.get_stock_summary() to service_role;

commit;
