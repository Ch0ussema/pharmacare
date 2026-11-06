# Phase 2 — Product Catalogue, Stock & Settings

| | |
| --- | --- |
| **Status** | Draft — awaiting approval |
| **Depends on** | Phases 0, 1 |
| **Blocks** | Phase 3 (POS needs products) |
| **Engineer** | `catalog-engineer` subagent + Lead review |

## 1. Goal

Give the pharmacist full control of the catalogue: products, prices, categories, stock levels and pharmacy settings — with safe stock adjustments and a fast, searchable list.

## 2. Scope

### In
- `/produits`: server-rendered table with search, category filter, stock filter, pagination, sorting by name.
- Create / edit product (dialog + server action), archive/restore (soft delete).
- Stock adjustment dialog (`adjust_stock` RPC) with reason/note.
- Categories management (create, rename, delete) accessible from `/produits`.
- `/parametres`: pharmacy identity (name, address, phone, receipt footer).
- Price inputs in DT (3 decimals) converted exactly to millimes.
- French validation messages and toasts.

### Out
- Purchases, suppliers, cost-price history, batch/expiry, CSV import/export.
- Bulk edit, images, multi-location stock.
- Deleting products that have sales (archive only).

## 3. User stories

| # | As | I want | So that |
| --- | --- | --- | --- |
| 2.1 | Pharmacist | to find a product by name or barcode | I can verify price/stock quickly |
| 2.2 | Pharmacist | to add/edit a product with price and stock | the catalogue matches reality |
| 2.3 | Pharmacist | to adjust stock with a note | corrections are traceable |
| 2.4 | Pharmacist | to archive an old product | it disappears from the POS but history stays |
| 2.5 | Owner | to set the pharmacy name/address/footer | receipts are correct |
| 2.6 | Owner | to see which products are low/out of stock | I can reorder in time |

## 4. UX specification

### `/produits`
- URL state: `?q=<text>&categorie=<uuid>&stock=tous|faible|rupture|archives&page=<n>` (all optional, shareable).
- Header: "Produits", subtitle with active count; primary action **Nouveau produit**.
- Toolbar: search input (debounced, by name/barcode), category select, stock select (`Tous`, `Stock faible`, `Rupture`, `Archivés`), reset link.
- Table columns: **Produit** (name + barcode), **Catégorie**, **Prix**, **Stock** (badge: OK / Faible / Rupture), **Statut**, **Actions** (menu: Modifier, Ajuster le stock, Archiver/Restaurer).
- Pagination: 15 rows, previous/next + "Page X sur Y".
- Empty states: no products vs no search results (different copy + reset action).

### Product dialog
- Fields: name*, barcode, category, price TTC* (DT), cost (DT, optional), stock initial, low-stock threshold, active.
- Native validation + server-side zod; inline field errors; pending button state.
- Duplicate barcode → "Ce code-barres existe déjà."

### Stock dialog
- Shows current stock; delta input (+/−), note; resulting stock preview; cannot go below 0.
- Success toast: "Stock mis à jour : 24 → 30".

### Categories dialog
- List with product counts; inline add; rename; delete with confirmation. Delete leaves products uncategorized.

### `/parametres`
- Form: pharmacy name, address, phone, receipt footer; live receipt header preview; save toast.

## 5. Technical design

```
src/app/(app)/produits/page.tsx           # RSC, reads searchParams
src/app/(app)/produits/actions.ts         # 'use server' saveProduct, archiveProduct, adjustStock
src/app/(app)/produits/categories-actions.ts
src/app/(app)/parametres/page.tsx
src/app/(app)/parametres/actions.ts
src/components/products/product-table.tsx
src/components/products/product-dialog.tsx
src/components/products/stock-dialog.tsx
src/components/products/category-manager.tsx
src/components/products/stock-badge.tsx
src/components/products/product-filters.tsx
src/lib/validations/product.ts
```

- Reads: Server Components, `await connection()` in the data helper, Supabase server client.
- Mutations: Server Actions with `useActionState`; `revalidatePath("/produits")` and `revalidatePath("/caisse")` after writes.
- Search: `q` (trimmed, max 80 chars), `.or(\`name.ilike.%${q}%,barcode.ilike.%${q}%\`)`; escape `%`/`,` per Supabase rules.
- Pagination: `.range(from, to)` with `{ count: "exact" }`; page clamped to valid range.
- Price parsing: strict regex `^\d{1,7}([.,]\d{1,3})?$` → millimes via string math (no float multiply):
  `"12,5" → 12500`, `"0,750" → 750`, `"12" → 12000`.
- Validation (zod): name 2–120 chars; barcode 0–64 chars; price 0–9 999 999 millimes; threshold 0–99 999.
- Archive: `is_active = false`; POS excludes archived; table filter shows them.
- Error mapping: Postgres `23505` on `products_barcode_key` → friendly French message.

## 6. Acceptance criteria

- [ ] `/produits` lists seeded products, 15 per page; search by partial name and exact barcode works.
- [ ] Category and stock filters combine with search; reset restores the full list.
- [ ] Creating a product with valid data shows it immediately (no manual refresh) and in the POS list.
- [ ] Duplicate barcode is rejected with a French field error; no row is created.
- [ ] Editing price/name/threshold persists and is reflected in POS/receipts for future sales.
- [ ] Stock adjustment updates the stock and writes a `stock_movements` row; negative result is blocked.
- [ ] Archiving hides the product from `/caisse` but keeps it visible under "Archivés"; restore works.
- [ ] Categories can be added, renamed, deleted; deletion leaves products uncategorized without error.
- [ ] `/parametres` saves and the values appear in the receipt preview.
- [ ] Invalid inputs are rejected server-side (test by tampering the request, not only UI).
- [ ] `npm run build`, `npm run lint` pass; all copy French.

## 7. Task breakdown

| # | Task | Owner |
| --- | --- | --- |
| 2.1 | Validations + money input parser + types | `catalog-engineer` |
| 2.2 | Products RSC page + filters + pagination | `catalog-engineer` |
| 2.3 | Product create/edit dialog + actions | `catalog-engineer` |
| 2.4 | Stock adjustment dialog + action | `catalog-engineer` |
| 2.5 | Category manager + actions | `catalog-engineer` |
| 2.6 | Settings page + action | `catalog-engineer` |
| 2.7 | QA review vs acceptance, fixes, commit `phase-2` | Lead |

## 8. Risks

| Risk | Mitigation |
| --- | --- |
| Float errors converting DT inputs | String-based parser + unit tests in Phase 5 |
| Supabase `.or()` injection via `q` | Sanitize `%`, `,`, `(`, `)`; cap length |
| Lost updates on stock | Adjustments go through RPC; never write `stock_quantity` directly |
| Archived products still sellable | POS query filters `is_active = true`; server RPC also rejects inactive |
