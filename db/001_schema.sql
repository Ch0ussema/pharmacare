-- PharmaCare — Phase 1: schema
-- Target: PostgreSQL 15+ (Supabase)
--
-- Run this file first, in the Supabase SQL Editor, as the project owner.
-- It is safe to re-run for the current shape of the schema:
--   * tables/indexes/sequence use IF NOT EXISTS
--   * triggers are dropped and recreated
--   * RLS and grants are idempotent
-- CREATE TABLE IF NOT EXISTS does NOT evolve an existing table. Any future
-- column/constraint change must ship as a new migration file.

begin;

-- gen_random_uuid() is built in on PostgreSQL 13+, but pgcrypto is kept for
-- compatibility with older Supabase projects and future helpers.
create extension if not exists pgcrypto;

-- Receipt numbers are allocated outside the sale transaction so that rolling
-- back a failed sale does not reuse a number (gaps are acceptable).
create sequence if not exists public.sale_receipt_seq start 1;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  barcode text,
  category_id uuid references public.categories (id) on delete set null,
  price_millimes integer not null check (price_millimes >= 0),
  cost_millimes integer not null default 0 check (cost_millimes >= 0),
  stock_quantity integer not null default 0 check (stock_quantity >= 0),
  low_stock_threshold integer not null default 10 check (low_stock_threshold >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- A barcode is optional, but when present it must be unique. The partial
-- index lets several products have no barcode (NULL) at the same time.
create unique index if not exists products_barcode_key
  on public.products (barcode)
  where barcode is not null;

create index if not exists products_category_idx
  on public.products (category_id);

create index if not exists products_active_low_stock_idx
  on public.products (stock_quantity)
  where is_active;

create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  receipt_number text not null unique,
  total_millimes integer not null check (total_millimes >= 0),
  payment_method text not null default 'cash' check (payment_method = 'cash'),
  created_at timestamptz not null default now()
);

create index if not exists sales_created_at_idx
  on public.sales (created_at desc);

create table if not exists public.sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales (id) on delete cascade,
  product_id uuid references public.products (id) on delete set null,
  product_name text not null,
  unit_price_millimes integer not null check (unit_price_millimes >= 0),
  quantity integer not null check (quantity > 0),
  line_total_millimes integer not null check (line_total_millimes >= 0)
);

create index if not exists sale_items_sale_idx
  on public.sale_items (sale_id);

create index if not exists sale_items_product_idx
  on public.sale_items (product_id);

create table if not exists public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  delta integer not null check (delta <> 0),
  reason text not null check (reason in ('sale', 'restock', 'adjustment')),
  -- No FK here on purpose: a movement may reference a sale, an adjustment
  -- batch, or a future purchase order. The reason tells consumers how to read
  -- it, and audit rows must survive their source being deleted.
  reference_id uuid,
  note text,
  created_at timestamptz not null default now()
);

create index if not exists stock_movements_product_idx
  on public.stock_movements (product_id, created_at desc);

create index if not exists stock_movements_reference_idx
  on public.stock_movements (reference_id)
  where reference_id is not null;

create table if not exists public.settings (
  id smallint primary key default 1 check (id = 1),
  pharmacy_name text not null default 'Pharmacie',
  address text not null default '',
  phone text not null default '',
  receipt_footer text not null default 'Merci de votre visite',
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- updated_at trigger (products, settings)
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists products_set_updated_at on public.products;
create trigger products_set_updated_at
  before update on public.products
  for each row
  execute function public.set_updated_at();

drop trigger if exists settings_set_updated_at on public.settings;
create trigger settings_set_updated_at
  before update on public.settings
  for each row
  execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Row Level Security and grants
--
-- v1 has no authentication. The app uses the server-only secret key
-- (service_role), which bypasses RLS. No policies are created, so anon and
-- authenticated cannot read or write these tables even if a grant is missed.
-- ---------------------------------------------------------------------------

alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.stock_movements enable row level security;
alter table public.settings enable row level security;

revoke all on table public.categories from anon, authenticated;
revoke all on table public.products from anon, authenticated;
revoke all on table public.sales from anon, authenticated;
revoke all on table public.sale_items from anon, authenticated;
revoke all on table public.stock_movements from anon, authenticated;
revoke all on table public.settings from anon, authenticated;

revoke all on sequence public.sale_receipt_seq from anon, authenticated;

-- Trigger helper: never callable by browser roles. The explicit owner grant
-- keeps future re-runs and ownership changes predictable.
revoke execute on function public.set_updated_at() from public, anon, authenticated;
grant execute on function public.set_updated_at() to service_role;

-- The service_role needs table access for direct supabase-js reads/writes.
-- Supabase normally grants this through default privileges; making it explicit
-- keeps the data layer correct if those defaults are changed.
grant select, insert, update, delete on table public.categories to service_role;
grant select, insert, update, delete on table public.products to service_role;
grant select, insert, update, delete on table public.sales to service_role;
grant select, insert, update, delete on table public.sale_items to service_role;
grant select, insert, update, delete on table public.stock_movements to service_role;
grant select, insert, update, delete on table public.settings to service_role;

grant usage, select on sequence public.sale_receipt_seq to service_role;

commit;
