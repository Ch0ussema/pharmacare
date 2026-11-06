# Phase 3 — POS (Caisse) & Receipts

| | |
| --- | --- |
| **Status** | Draft — awaiting approval |
| **Depends on** | Phases 0, 1, 2 |
| **Blocks** | Phase 4 (dashboard needs sales) |
| **Engineer** | `pos-engineer` subagent + Lead review |

## 1. Goal

A fast, keyboard-friendly cash register: find products, build a cart, take cash, record an atomic sale, and print an 80 mm receipt.

## 2. Scope

### In
- `/caisse`: product search (name/barcode, accent-insensitive), category filter, product grid, cart.
- Quantity controls bounded by stock; remove line; clear cart.
- Cash checkout: amount received, change due, quick-amount buttons; disabled until enough cash.
- Server action → `create_sale` RPC; server-computed totals; stock decremented atomically.
- Success receipt dialog + print, and a standalone printable route `/recu/[saleId]`.
- 80 mm print stylesheet; French receipt content.
- Error handling: insufficient stock, network failure, double-submit prevention.

### Out
- Card/credit payments, discounts, returns, held sales, customer accounts.
- Receipt printer drivers/ESC-POS (browser print only).
- Sales history page (backlog).

## 3. User stories

| # | As | I want | So that |
| --- | --- | --- | --- |
| 3.1 | Cashier | to scan/type a barcode and press Enter | the product lands in the cart instantly |
| 3.2 | Cashier | to search "dolip" and click a product | I can sell without a barcode |
| 3.3 | Cashier | to change quantities and see the total live | I can confirm with the customer |
| 3.4 | Cashier | to enter cash received and see change | I give the right change |
| 3.5 | Cashier | to print the receipt | the customer gets proof of purchase |
| 3.6 | Owner | stock to decrease automatically | inventory stays accurate |
| 3.7 | Cashier | a clear message when stock is insufficient | I can correct the cart |

## 4. UX specification

### Desktop layout (≥ lg)
- **Left (≈65%)**: sticky search bar (autofocus), category chips, product grid (cards: name, price, stock badge). Out-of-stock cards disabled. Results count.
- **Right (≈35%)**: cart panel — lines (name, unit price, qty stepper, line total, remove), total TTC, item count, **Vider** and **Encaisser** buttons.
- Empty cart: illustration + "Ajoutez des produits pour commencer".
- Mobile/tablet: product grid full width; cart becomes a bottom sheet with a sticky "Voir le panier (n)" bar.

### Search behaviour
- Input is local (products preloaded once server-side, ≤ 1000 active).
- Accent-insensitive, case-insensitive `contains` on name; exact match on barcode (Enter).
- Enter with a single result adds it; Enter on exact barcode adds immediately.
- Search cleared after a barcode add; focus returns to the input.

### Checkout dialog
- Summary: item count, total.
- "Montant reçu (DT)" numeric input (3 decimals); quick buttons: exact, 5, 10, 20, 50 DT.
- Change = received − total; shown large; negative blocked.
- Confirm button: "Valider la vente" with pending state; cannot double-submit.
- On success: dialog switches to receipt view (number, total, received, change) + **Imprimer** + **Nouvelle vente**.

### Receipt (80 mm)
- Header: pharmacy name, address, phone.
- Meta: `N° V-000123`, date/time (`fr-TN`, Africa/Tunis).
- Lines: `qty × name` and line total; unit price if qty > 1.
- Footer: total, "Espèces", received, change, footer text, "Merci de votre visite".
- Print: `@page { size: 80mm auto; margin: 4mm; }`, monospace, black on white, no app chrome.

## 5. Technical design

```
src/app/(app)/caisse/page.tsx              # RSC: loads active products + categories
src/app/(app)/caisse/actions.ts            # 'use server' checkout(items)
src/app/(recu)/layout.tsx                  # minimal print layout
src/app/(recu)/recu/[saleId]/page.tsx      # RSC: sale + items + settings
src/app/(recu)/recu/[saleId]/print-button.tsx
src/components/pos/pos-client.tsx          # client orchestrator
src/components/pos/product-grid.tsx
src/components/pos/cart-panel.tsx
src/components/pos/checkout-dialog.tsx
src/components/pos/receipt-view.tsx
src/lib/pos/cart.ts                        # reducer + totals (pure, testable)
src/lib/pos/search.ts                      # normalize + matching
src/lib/validations/sale.ts
```

- **State:** `useReducer` cart (`{ productId, name, unitPrice, quantity, stock }[]`); totals derived with integer math.
- **Preload:** server page selects `id, name, barcode, price_millimes, stock_quantity, category_id, low_stock_threshold` where `is_active` and orders by name; cap 1000; `await connection()`.
- **Checkout action:**
  ```ts
  const parsed = saleSchema.parse(items);           // uuid + quantity 1..999
  const { data, error } = await supabaseAdmin.rpc("create_sale", { p_items: parsed });
  if (error) return { ok: false, code: mapError(error) };
  revalidatePath("/caisse"); revalidatePath("/produits"); revalidatePath("/");
  return { ok: true, sale: data };
  ```
- **Error mapping:** `stock_insufficient:<id>:<available>` → "Stock insuffisant pour « name » (disponible : n)." Resolve name from the cart.
- **Refresh:** `router.refresh()` after success to refresh stock on the page; cart state lives in the client and is cleared explicitly.
- **Receipt route:** loads sale by id, `sale_items`, and the single `settings` row; `notFound()` if missing.
- **Print:** `window.print()` from a client button; no auto-print (avoids popup blocking).
- **No floats:** received amount parsed with the DT→millimes string parser; change is integer subtraction.

## 6. Acceptance criteria

- [ ] Typing a barcode + Enter adds exactly that product and refocuses the search.
- [ ] Searching "betadine" finds "Bétadine" (accent-insensitive); clicking adds it.
- [ ] Quantity cannot exceed available stock; feedback explains why.
- [ ] Total = Σ(unit price × qty) exactly in millimes; displayed with 3 decimals.
- [ ] Checkout with insufficient received cash is blocked; change is exact.
- [ ] A completed sale: stock decreases by the sold quantities, a `sales` row + items + movements exist.
- [ ] Two tabs checking out the last unit simultaneously: one succeeds, one shows a French stock error.
- [ ] Receipt shows correct pharmacy header, number, lines, total, cash, change, footer.
- [ ] `/recu/[id]` opens standalone and prints at 80 mm with no sidebar/nav.
- [ ] Double-clicking "Valider" creates only one sale.
- [ ] Cart can be emptied; empty state is clear; POS is usable at 768 px width.
- [ ] `npm run build`, `npm run lint` pass; no `any` in cart/money code.

## 7. Task breakdown

| # | Task | Owner |
| --- | --- | --- |
| 3.1 | Cart reducer, search/normalize, money parsing + zod schema | `pos-engineer` |
| 3.2 | POS RSC page + product grid + category chips | `pos-engineer` |
| 3.3 | Cart panel + quantity controls + responsive sheet | `pos-engineer` |
| 3.4 | Checkout dialog + server action + error mapping | `pos-engineer` |
| 3.5 | Receipt view + `/recu/[id]` + 80 mm print CSS | `pos-engineer` |
| 3.6 | QA review (incl. concurrency + print), fixes, commit `phase-3` | Lead |

## 8. Risks

| Risk | Mitigation |
| --- | --- |
| Overselling | Row locks + stock check inside RPC; UI limits are UX only |
| Stale stock after another terminal sells | `router.refresh()`; error path re-syncs |
| Print layout drifting across browsers | Fixed 80 mm `@page`, monospace, test Chrome + Edge print preview |
| Accent search misses | NFD normalize + strip diacritics on both sides |
| Double submit | `pending` disables button; RPC remains the source of truth |
