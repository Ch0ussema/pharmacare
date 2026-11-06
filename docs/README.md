# PharmaCare — Delivery Handbook

How we plan, build, review, and ship PharmaCare v1.

## 1. Roles

| Role | Responsibility |
| --- | --- |
| **Main Orchestrator / Technical Lead / PM** (me) | Owns PRDs, architecture, task decomposition, subagent briefs, code review, quality gates, and final commits. |
| **Feature engineers** (subagents) | Implement one phase at a time inside an explicitly assigned file set. |
| **QA reviewer** (subagent) | Read-only audit of each phase against its PRD and acceptance criteria. |
| **Research agents** (subagents) | Version-matched research when a decision needs evidence (Next 16, Supabase, shadcn, Postgres). |

## 2. Phase lifecycle

```
PRD written → PRD approved → subagent implementation → self-check
→ QA review (read-only) → Lead fixes → build + lint + manual smoke
→ phase commit/tag → next phase
```

Rules:
1. **One phase in flight at a time.** No parallel writers in the same files.
2. **Every subagent gets a contract**: goal, file ownership, data contracts, acceptance criteria, and "do not touch" list.
3. **The Lead reviews every diff** before it is considered done. Subagent output is never trusted blindly.
4. **No phase is done until** `npm run build` and `npm run lint` pass and the acceptance criteria are demonstrated.
5. PRD changes are made by the Lead only, and recorded in the phase file.

## 3. File ownership (avoids write conflicts)

| Area | Files | Owner |
| --- | --- | --- |
| Config & shell | `next.config.ts`, `src/app/layout.tsx`, `src/app/(app)/layout.tsx`, `src/components/layout/**`, `src/app/globals.css` | Phase 0 engineer |
| Data layer | `db/**`, `src/lib/supabase/**`, `src/types/db.ts` | Phase 1 engineer |
| Catalog | `src/app/(app)/produits/**`, `src/app/(app)/parametres/**`, `src/components/products/**`, `src/lib/validations/**` | Phase 2 engineer |
| POS | `src/app/(app)/caisse/**`, `src/app/(recu)/**`, `src/components/pos/**`, `src/lib/pos/**` | Phase 3 engineer |
| Dashboard | `src/app/(app)/page.tsx`, `src/components/dashboard/**` | Phase 4 engineer |
| Shared UI | `src/components/ui/**` (shadcn), `src/lib/i18n/**`, `src/lib/format.ts` | Lead only after Phase 0 |

## 4. Definition of Done (per phase)

- [ ] All PRD acceptance criteria met and demonstrated.
- [ ] `npm run build` passes (Turbopack, production build).
- [ ] `npm run lint` passes with zero errors.
- [ ] No TypeScript `any` added without justification.
- [ ] Loading, empty, and error states implemented for touched screens.
- [ ] All user-facing copy is French and comes from the i18n dictionary.
- [ ] Money is handled as integer millimes; no floating-point math for totals.
- [ ] No secret key or service-role client imported into a client component.
- [ ] QA reviewer report addressed (or explicitly waived by the Lead).
- [ ] Conventional commit + phase tag (`phase-0`, `phase-1`, …).

## 5. Commands

```bash
npm run dev        # dev server (Turbopack)
npm run build      # production build
npm run lint       # ESLint
npx tsc --noEmit   # type check
```

## 6. Branching

Solo repository, no remote yet.

```
main
 └─ phase/0-foundation
 └─ phase/1-data-layer
 └─ phase/2-catalog
 └─ phase/3-pos
 └─ phase/4-dashboard
 └─ phase/5-qa-release
```

Each phase branch is reviewed, squashed/merged into `main`, then tagged.

## 7. Document index

| Document | Purpose |
| --- | --- |
| `prd/00-overview.md` | Product vision, scope, architecture, data model, decisions |
| `prd/01-phase-0-foundation.md` | App shell, design system, i18n, config |
| `prd/02-phase-1-data-layer.md` | Supabase schema, RPCs, seed, security |
| `prd/03-phase-2-catalog.md` | Products, stock adjustments, categories, settings |
| `prd/04-phase-3-pos.md` | Cash register, checkout, receipts, printing |
| `prd/05-phase-4-dashboard.md` | KPIs, charts, alerts, stock summary |
| `prd/06-phase-5-qa-release.md` | QA, accessibility, deployment, release |
