# Phase 5 — QA, Accessibility, Deployment & Release

| | |
| --- | --- |
| **Status** | Draft — awaiting approval |
| **Depends on** | Phases 0–4 |
| **Blocks** | v1.0.0 release |
| **Engineers** | `qa-reviewer` (read-only audit) + `release-engineer` + Lead |

## 1. Goal

Harden, test, document and ship PharmaCare v1 to production (Vercel + Supabase), with a clean release tag and a repeatable smoke test.

## 2. Scope

### In
- Unit tests for pure logic: `formatTND`, DT→millimes parser, cart reducer/totals, zod schemas.
- QA matrix: browsers (Chrome, Edge, Firefox, Safari where available), viewports (1440, 1024, 768, 375), print preview.
- Accessibility pass: labels, focus order, keyboard-only POS sale, contrast, dialogs (focus trap, Esc), aria-live for errors.
- Performance: production build, Lighthouse on `/`, `/caisse`; image/font checks; avoid layout shift.
- Security review: no secrets in client bundles, RLS enabled, server-action validation, error messages not leaking internals.
- Resilience: empty DB, invalid env, Supabase paused/down, RPC failure, duplicate barcode.
- Documentation: `README.md` (setup, env, DB), `docs/DEPLOYMENT.md`, `docs/QA-CHECKLIST.md`, phase index.
- Deployment to Vercel; production env vars; smoke test; tag `v1.0.0`.

### Out
- E2E browser automation (Playwright) — backlog.
- Load testing, monitoring/alerting, backups automation.
- Native app, PWA/offline.

## 3. Test plan

### 3.1 Unit tests (Vitest)

```
src/lib/format.test.ts        # 12500 → "12,500 DT"; 0; 1; 999999999; parse "12,5"/"0,750"
src/lib/pos/cart.test.ts      # add/merge/increment/remove/clear; max stock; totals
src/lib/validations/*.test.ts # product/sale schemas: valid/invalid/tampered payloads
```

`npm i -D vitest` + `"test": "vitest run"` + `"test:watch": "vitest"`.

### 3.2 Manual QA matrix

| Area | Checks |
| --- | --- |
| Catalogue | create/edit/archive/restore; duplicate barcode; filters; pagination; low stock |
| Stock | +/− adjustments, zero crossing blocked, audit rows |
| POS | barcode Enter, accent search, max qty, empty cart, checkout, change, double-click, concurrent tab |
| Receipt | content accuracy, 80 mm print, long product names, 30+ items |
| Dashboard | KPIs vs SQL, 7/30 toggle, empty states, yesterday delta, low stock link |
| Settings | save/reload, receipt header update |
| Errors | DB down, invalid env, RPC stock error, network retry |
| Responsive | 1440/1024/768/375; sidebar sheet; cart sheet; tables scroll |
| Browser | Chrome, Edge, Firefox (+ Safari if available) |

### 3.3 Accessibility checklist

- All inputs have labels; errors linked with `aria-describedby`; `aria-live` for action feedback.
- Full keyboard sale: focus search → type → Enter → Tab to cart → checkout → Esc closes dialogs.
- Focus trap in dialogs; focus returns to trigger; no keyboard traps.
- Contrast ≥ 4.5:1 for text; focus ring visible; icons have accessible names.
- Toasts announced politely; pending states exposed via `aria-busy`.
- `lang="fr"` on `<html>`; page titles per route.

### 3.4 Performance targets

| Metric | Target |
| --- | --- |
| Production build | no warnings/errors |
| Lighthouse Performance (desktop) | ≥ 90 |
| Lighthouse Accessibility | ≥ 95 |
| POS interaction (add to cart) | < 100 ms perceived |
| Dashboard first content | shell + skeletons < 1 s locally |

### 3.5 Security checklist

- [ ] `SUPABASE_SECRET_KEY` only in server env; grep built client bundles for `sb_secret` / `service_role` → none.
- [ ] `src/lib/supabase/admin.ts` imports `server-only`.
- [ ] No `NEXT_PUBLIC_` secret.
- [ ] Every server action validates with zod and never trusts client prices/totals.
- [ ] RLS on all tables; grants revoked from `anon`/`authenticated` (Supabase Security Advisor clean).
- [ ] Error messages user-safe; stack traces only in server logs.
- [ ] `.env.local` gitignored; `.env.example` contains placeholders.

## 4. Deployment

1. Push repository to GitHub (private).
2. Vercel → **Import Project** → framework Next.js (auto-detected).
3. Environment variables (Production + Preview):
   - `SUPABASE_URL`
   - `SUPABASE_SECRET_KEY`
4. Deploy; verify build uses Node 22+ (project already on Node 26 locally).
5. Run SQL files on the production Supabase project (schema → functions → seed; seed optional in prod).
6. Smoke test on the deployed URL:
   - `/` loads KPIs; `/produits` lists; create a product; `/caisse` sell it; receipt prints; dashboard updates.
7. Note: Supabase free tier pauses after 1 week of inactivity — document how to restore and how to export data (`pg_dump` / dashboard backup).
8. Tag `v1.0.0` and write release notes.

## 5. Acceptance criteria

- [ ] `npm test` passes (formatters, money parser, cart, validations).
- [ ] QA matrix executed and signed off in `docs/QA-CHECKLIST.md`.
- [ ] Accessibility checklist passed; Lighthouse a11y ≥ 95.
- [ ] Security checklist passed; no secret in client bundle.
- [ ] README lets a new developer run the app from clone to sale in < 10 minutes.
- [ ] Production deployment completes; smoke test passes end-to-end.
- [ ] `docs/DEPLOYMENT.md` covers env vars, SQL order, free-tier caveats, rollback.
- [ ] `v1.0.0` tag exists; release notes list scope and known limitations.
- [ ] No open P0/P1 defects; P2s documented in the backlog.

## 6. Task breakdown

| # | Task | Owner |
| --- | --- | --- |
| 5.1 | Add Vitest + unit tests for pure logic | `release-engineer` |
| 5.2 | Read-only QA audit vs all PRDs; defect list | `qa-reviewer` |
| 5.3 | Fix defects (Lead + targeted subagent) | Lead |
| 5.4 | A11y + responsive + performance pass | `release-engineer` |
| 5.5 | Write README, DEPLOYMENT, QA-CHECKLIST, release notes | `release-engineer` |
| 5.6 | Deploy to Vercel, prod smoke test, tag `v1.0.0` | Lead |

## 7. Risks

| Risk | Mitigation |
| --- | --- |
| No Vercel/Supabase account ready | Prepare docs now; deployment can be deferred without blocking v1 code |
| Free-tier pause during demo | Document unpause; keep a local `pg_dump` |
| Print differences in Firefox | Test print preview; keep layout simple (no flex quirks) |
| A11y regressions from shadcn defaults | Audit focus/aria; don't remove labels |
| Scope creep at the end | Freeze v1 scope; log ideas in backlog |
