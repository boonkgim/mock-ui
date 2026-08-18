# Route inventory — mock-ui

This file does not list routes. It says how the run's inventory is **derived** from the PRD and
written to `.cache/mock-ui/pages.md`, because nanostore is a scaffold: the product it ends up
holding is decided by whatever PRD is in the newest dated folder under `docs/`, and a route list
checked in here would be a second, staler spec.

## Contents

- Domain & brand (binding)
- What the inventory must contain
- Shared structure
- Existing routes: keep, replace, off-limits
- The three output files
- Component add-list

## Domain & brand (binding — do not invent)

- Every domain fact — the business domain, currency and price display, timezone and locale,
  entity and field lists, delivery rules, scope — comes from the newest `docs/<date>-*/` PRD and
  data model, distilled per run into `.cache/mock-ui/facts.md`. When they are silent, **flag the
  gap** (BP52); never fill it from a plausible prior.
- The brand/site name comes from the PRD. If the PRD has none, use `nanostore` — the name the
  root layout already carries — and list the missing name as a gap, rather than coining one.
  Coining a brand is the single easiest invention to miss in review, because it looks like
  content rather than like a decision.
- Money is formatted by `apps/web/src/lib/formatPrice.ts` and timestamps by
  `apps/web/src/lib/formatUtc.ts`. Read them before writing a formatter: the currency and the
  zone are decisions the scaffold already made, with tests behind them.

## What the inventory must contain

`.cache/mock-ui/pages.md` holds one section per route group, and each section is a table:

| URL | Page file | Purpose | Key shadcn components | Mock data shown |

Then, under the table, that group's extras: `layout.tsx` (its shell), `loading.tsx`,
`error.tsx`, every `not-found.tsx`, and every `actions.ts`. Mark a route **form** where it
mutates; a form route always gets a colocated `actions.ts` (BP23–BP29).

**Groups come from the PRD's audiences, not from a template.** The common shape is
`(public)` / `(customer)` / `(admin)` — anonymous visitor, signed-in owner of their own rows,
operator — and it is the right default when the PRD names those three. A product with two
audiences gets two groups. The test is the shell: a group exists when its pages share a header,
a nav, and a guard that the other groups' pages do not. Groups that would share all three are
one group.

**Derive routes from the PRD's journeys, then check them against the data model.** A journey
that cannot be completed with the screens listed is a missing route; an entity in the data model
that no screen ever creates, shows, or edits is either a missing route or a gap worth flagging.
Both directions matter — the second is the one that goes unnoticed.

**Cover the states, not just the happy path.** Every list needs an empty state, every form an
error state, every async surface a pending one, and every mutation a success the user can see
(`code-ui`, four states). The mock data is what makes them demonstrable (BP49), so the inventory
says which record demonstrates which state.

## Shared structure

- **One root layout.** `apps/web/src/app/layout.tsx` owns `<html>`/`<body>`, the fonts, and the
  `ThemeProvider`. Route groups are directories beside it; their layouts return plain wrappers
  carrying the area shell (BP18–BP19, design finding 3). Never a second root layout — it costs
  a full page reload on every cross-area link.
- **Metadata.** Every page exports `metadata` or `generateMetadata` with a distinct title
  (BP22). The root layout's `title` becomes a `title.template` when the first group lands; that
  file is claimed by the plan of record, so the edit carries a `docs-check.ignore` line with it
  (BP58).
- **Dynamic segments** call `notFound()` on unknown ids and have a sibling `not-found.tsx`
  (BP9, BP17).
- **Loading.** The group's `loading.tsx` is the baseline skeleton; a segment whose shape differs
  enough that the group skeleton would lie gets its own (BP11).
- **Auth.** Pages that require a visitor read the session the way the `auth` skill says, and
  every server action re-checks it (BP24) — a group layout guard is navigation, not security.

## Existing routes: keep, replace, off-limits

`apps/web` is not greenfield; the scaffold shipped working pages, and the inventory must rule on
each one explicitly rather than discovering the collision at build time.

- **Off-limits — never mocked, never moved:** `src/app/api/auth/[...all]/route.ts` (the
  same-origin proxy; the `auth` skill owns it) and `src/generated/**`.
- **Keep and link to, do not re-mock:** the Stripe checkout at `src/app/checkout/`. It is real,
  it takes real test money, and the `payments` skill owns it. A mock checkout beside it would be
  two answers to one question. The inventory's purchase journey links to `/checkout`.
- **Replace, with a ruling written down:** `src/app/page.tsx`. If the inventory claims `/` — it
  usually does — this file must go, because two pages resolving to one URL is a build error
  (BP20). It is claimed by the plan of record, so replacing it means appending a reasoned line
  to `scripts/docs-check.ignore` (BP58). Its working parts are reused, not rewritten: `AuthPanel`
  is the sign-in surface, and whatever the mock's public home does with version and health, it
  does by composing what is there.

Any other collision gets the same treatment: name the file, say keep / replace / off-limits, and
give the reason in one line.

## The three output files

Phase 1 writes all three, and they must agree:

- `.cache/mock-ui/pages.md` — the tables above, the extras, and the collision rulings.
- `.cache/mock-ui/routes.txt` — one repo-relative page path per line, e.g.
  `apps/web/src/app/(public)/page.tsx`. Blank lines and `#` comments are ignored.
  `verify_pages.sh` reads this file, so a route in the table and missing here is a route nothing
  checks.
- `.cache/mock-ui/components.txt` — shadcn registry names, one per line, read by
  `setup_shadcn.sh`.

## Component add-list

The default list, extended by whatever the inventory's tables actually name:

```
alert badge button card checkbox dialog dropdown-menu input label select separator skeleton
table tabs textarea
```

`alert`, `button`, `card`, `input` and `label` are already vendored in
`apps/web/src/components/ui/`; the script adds only what is missing.

Two notes before extending the list:

- **`field` is not on it.** shadcn's `FieldError` returns `null` when it has nothing to say, so
  the surrounding form resizes the moment a message appears — the exact bug `code-ui` reserves
  space to prevent. Use it only with a reserved slot around it, and prefer the
  label/input/reserved-line pattern `AuthPanel` already demonstrates.
- **No form library.** This repo validates with plain state and maps error codes to its own
  copy (`code-ui`, and `AuthPanel` as the exemplar). Do not install react-hook-form or zod for
  the mock: a second form philosophy in the same app is a fork nobody chose.
