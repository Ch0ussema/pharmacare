-- PharmaCare — Phase 1: seed data
-- Target: PostgreSQL 15+ (Supabase)
--
-- Run after 001_schema.sql and 002_functions.sql.
-- Re-runnable: settings/categories/products use ON CONFLICT DO NOTHING, so
-- existing rows are never overwritten.
--
-- The dataset is demo data for a Tunisian pharmacy: 8 categories, 40 products.
-- Prices are integer millimes (1 TND = 1000 millimes). Stock intentionally
-- includes healthy, low and zero levels so the dashboard has something to show.

begin;

-- ---------------------------------------------------------------------------
-- Pharmacy identity (single row, id = 1)
-- ---------------------------------------------------------------------------

insert into public.settings (id, pharmacy_name, address, phone, receipt_footer)
values (
  1,
  'Pharmacie Centrale',
  '12 avenue Habib Bourguiba, 1000 Tunis',
  '+216 71 123 456',
  'Merci de votre visite — Pharmacie Centrale'
)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Categories
-- ---------------------------------------------------------------------------

insert into public.categories (name)
values
  ('Antalgiques'),
  ('Antibiotiques'),
  ('Anti-inflammatoires'),
  ('Digestif'),
  ('ORL'),
  ('Vitamines'),
  ('Dermatologie'),
  ('Matériel')
on conflict (name) do nothing;

-- ---------------------------------------------------------------------------
-- Products
--
-- Barcode uniqueness is enforced by the partial unique index
-- products_barcode_key (barcode) WHERE barcode IS NOT NULL. PostgreSQL can
-- infer that index from `ON CONFLICT (barcode) WHERE barcode IS NOT NULL`.
-- ---------------------------------------------------------------------------

with seed_products (
  name,
  barcode,
  category_name,
  price_millimes,
  cost_millimes,
  stock_quantity,
  low_stock_threshold
) as (
  values
    ('Doliprane 1000 mg, 8 comprimés', '6191234500011', 'Antalgiques', 2400, 1650, 120, 20),
    ('Efferalgan 500 mg, 16 comprimés effervescents', '6191234500028', 'Antalgiques', 3100, 2100, 8, 15),
    ('Dafalgan 1 g, 8 comprimés', '6191234500035', 'Antalgiques', 2650, 1800, 45, 10),
    ('Paracétamol Biogaran 500 mg, 20 comprimés', '6191234500042', 'Antalgiques', 1850, 1200, 0, 20),
    ('Aspirine du Rhône 500 mg, 20 comprimés', '6191234500059', 'Antalgiques', 1900, 1250, 150, 20),
    ('Amoxicilline 500 mg, 12 gélules', '6191234500066', 'Antibiotiques', 4200, 2900, 60, 10),
    ('Augmentin 1 g, 14 comprimés', '6191234500073', 'Antibiotiques', 12800, 9500, 12, 5),
    ('Clamoxyl 500 mg, 12 gélules', '6191234500080', 'Antibiotiques', 6500, 4600, 0, 10),
    ('Azithromycine 250 mg, 6 comprimés', '6191234500097', 'Antibiotiques', 9400, 6800, 4, 5),
    ('Ibuprofène 400 mg, 20 comprimés', '6191234500103', 'Anti-inflammatoires', 3900, 2600, 80, 15),
    ('Voltarène 50 mg, 20 comprimés', '6191234500110', 'Anti-inflammatoires', 5600, 3900, 25, 10),
    ('Profénid 100 mg, 20 comprimés', '6191234500127', 'Anti-inflammatoires', 6200, 4400, 9, 10),
    ('Diclofénac 1 % gel, 50 g', '6191234500134', 'Anti-inflammatoires', 5800, 4100, 32, 10),
    ('Spasfon 80 mg, 30 comprimés', '6191234500141', 'Digestif', 4800, 3300, 40, 10),
    ('Gaviscon suspension buvable 250 ml', '6191234500158', 'Digestif', 6900, 4800, 18, 10),
    ('Smecta 3 g, 30 sachets', '6191234500165', 'Digestif', 7200, 5100, 6, 10),
    ('Imodium 2 mg, 12 gélules', '6191234500172', 'Digestif', 5400, 3800, 30, 10),
    ('Météospasmyl 60 mg, 30 gélules', '6191234500189', 'Digestif', 8100, 5900, 3, 5),
    ('Maalox suspension buvable 250 ml', '6191234500196', 'Digestif', 5900, 4100, 0, 10),
    ('Rhinofluimucil spray nasal 10 ml', '6191234500202', 'ORL', 7800, 5500, 14, 10),
    ('Fervex adulte, 8 sachets', '6191234500219', 'ORL', 6400, 4500, 22, 10),
    ('Actifed Rhume, 8 comprimés', '6191234500226', 'ORL', 4900, 3400, 5, 10),
    ('Otrivine spray nasal 10 ml', '6191234500233', 'ORL', 5100, 3600, 11, 10),
    ('Vitamine C Laroscorbine 500 mg, 30 comprimés', '6191234500240', 'Vitamines', 7500, 5200, 35, 10),
    ('Magnésium B6, 60 comprimés', '6191234500257', 'Vitamines', 11200, 8200, 2, 5),
    ('Vitamine D3 Uvedose 100 000 UI, 4 ampoules', '6191234500264', 'Vitamines', 9800, 7100, 16, 10),
    ('Bétadine dermique 10 %, 125 ml', '6191234500271', 'Dermatologie', 8400, 6000, 28, 10),
    ('Bétadine scrub 4 %, 500 ml', '6191234500288', 'Dermatologie', 12500, 9200, 7, 5),
    ('Cicalfate crème réparatrice 40 g', '6191234500295', 'Dermatologie', 14900, 11000, 4, 5),
    ('Biafine émulsion 100 ml', '6191234500301', 'Dermatologie', 10300, 7500, 0, 10),
    ('Gel hydroalcoolique 500 ml', '6191234500318', 'Dermatologie', 8900, 5800, 5, 10),
    ('Alcool 70°, 500 ml', '6191234500325', 'Dermatologie', 5200, 3300, 40, 10),
    ('Eau oxygénée 10 volumes, 250 ml', '6191234500332', 'Dermatologie', 3400, 2100, 9, 10),
    ('Sérum physiologique 0,9 %, 20 ampoules de 5 ml', '6191234500349', 'Matériel', 3200, 2000, 90, 20),
    ('Compresses stériles 10 x 10 cm, boîte de 25', '6191234500356', 'Matériel', 4500, 2900, 55, 15),
    ('Seringue stérile 5 ml, boîte de 10', '6191234500363', 'Matériel', 3600, 2200, 70, 15),
    ('Thermomètre digital', '6191234500370', 'Matériel', 18500, 13500, 13, 5),
    ('Tensiomètre bras électronique', '6191234500387', 'Matériel', 89000, 65000, 6, 3),
    ('Glucomètre + 25 bandelettes', '6191234500394', 'Matériel', 65000, 47000, 3, 2),
    ('Masques chirurgicaux, boîte de 50', '6191234500400', 'Matériel', 7500, 4800, 25, 10)
)
insert into public.products (
  name,
  barcode,
  category_id,
  price_millimes,
  cost_millimes,
  stock_quantity,
  low_stock_threshold
)
select
  seed.name,
  seed.barcode,
  categories.id,
  seed.price_millimes,
  seed.cost_millimes,
  seed.stock_quantity,
  seed.low_stock_threshold
from seed_products as seed
left join public.categories on categories.name = seed.category_name
on conflict (barcode) where barcode is not null do nothing;

-- ---------------------------------------------------------------------------
-- Sanity notice (does not modify data)
-- ---------------------------------------------------------------------------

do $$
declare
  v_categories integer;
  v_products integer;
  v_settings integer;
begin
  select count(*) into v_categories from public.categories;
  select count(*) into v_products from public.products;
  select count(*) into v_settings from public.settings;

  raise notice 'seed: % categories, % products, % settings row(s)',
    v_categories, v_products, v_settings;
end;
$$;

commit;
