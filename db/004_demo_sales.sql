-- PharmaCare — Phase 1: OPTIONAL demo sales
-- Target: PostgreSQL 15+ (Supabase)
--
-- ===========================================================================
-- DEMO / DEVELOPMENT ONLY. Do not run this file on a real pharmacy database.
-- It creates sales and reduces stock so the dashboard has data to display.
-- ===========================================================================
--
-- Run after 003_seed.sql. The block is a no-op when public.sales already has
-- at least one row, so it is safe to re-run: it never mixes demo sales into an
-- existing sales history.
--
-- Sales are spread over the last 14 Africa/Tunis days. Each sale is created
-- through public.create_sale(), which keeps stock, totals and sale items
-- consistent. Only the timestamps are backdated afterwards. Quantities are
-- capped by the current stock, so no sale can drive stock below zero.

begin;

do $$
declare
  v_sale jsonb;
  v_sale_id uuid;
  v_items jsonb;
  v_when timestamptz;
  v_day_offset integer;
  v_sale_index integer;
  v_sales_created integer := 0;
begin
  if exists (select 1 from public.sales) then
    raise notice 'demo sales skipped: public.sales is not empty';
    return;
  end if;

  -- 13 days ago through today.
  for v_day_offset in reverse 13..0 loop
    -- 2 to 4 sales per day.
    for v_sale_index in 1..(2 + (v_day_offset % 3)) loop
      -- Pick 1-3 distinct active products that still have stock. The quantity
      -- is capped at 3 and at the product's current stock.
      select jsonb_agg(
               jsonb_build_object(
                 'product_id', picked.id,
                 'quantity', picked.quantity
               )
             )
      into v_items
      from (
        select p.id,
               1 + floor(random() * least(3, p.stock_quantity))::integer as quantity
        from public.products p
        where p.is_active
          and p.stock_quantity > 0
        order by random()
        limit 1 + floor(random() * 3)::integer
      ) as picked;

      if v_items is null or jsonb_array_length(v_items) = 0 then
        continue;
      end if;

      v_sale := public.create_sale(v_items);
      v_sale_id := (v_sale->>'sale_id')::uuid;

      -- Backdate the sale and its stock audit rows. The sale was created with
      -- now(); only the demo timestamp is rewritten.
      v_when := (
        date_trunc('day', now() at time zone 'Africa/Tunis')
        - make_interval(days => v_day_offset)
        + make_interval(
            hours => 9 + (v_sale_index * 2),
            mins => (v_day_offset * 7 + v_sale_index * 13) % 60
          )
      ) at time zone 'Africa/Tunis';

      update public.sales
      set created_at = v_when
      where id = v_sale_id;

      update public.stock_movements
      set created_at = v_when
      where reference_id = v_sale_id;

      v_sales_created := v_sales_created + 1;
    end loop;
  end loop;

  raise notice 'demo sales created: %', v_sales_created;
end;
$$;

commit;
