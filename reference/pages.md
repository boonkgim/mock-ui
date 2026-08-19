# Route inventory and shell contract — mock-ui

This file does not list routes, and it does not describe a shell. It says how the run's
inventory and its shell contract are **derived** from the PRD and from the app as it stands,
because nanostore is a scaffold: the product it ends up holding is decided by whatever PRD is in
the newest dated folder under `docs/`, and a route list or a header layout checked in here would
be a second, staler spec that every future product would be bent to fit.

## Contents

- Domain & brand (binding)
- What the inventory must contain
- The shell contract
- Shared structure
- Existing UI: the disposition ruling (both modes)
- Routes owned by another skill
- The four output files
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

Then, under the table, that group's extras: `layout.tsx` (its shell composition), `loading.tsx`,
`error.tsx`, every `not-found.tsx`, and every `actions.ts`. Mark a route **form** where it
mutates; a form route always gets a colocated `actions.ts` (BP23–BP29), and carries a
`page`/`dialog` ruling with its reason — see below. A group holding one or more `dialog` routes
also lists its `@modal` slot and that slot's `default.tsx` among the extras.

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

**Walk each journey end to end on the route list before accepting it.** Every step a user takes
between one screen and the next is a route or a redirect, and the steps that hand off to a
payment provider, an email link or an identity provider are the ones an inventory drops: the
handoff is somebody else's, but the screen it leaves from and the screen it returns to are this
run's. A journey with a hole in the middle is the most expensive kind of missing route, because
the hole is only visible when someone tries to walk it.

**Rule every form route page-or-dialog, in the table, before anything is built.** BP51 and
BP68 say how a dialog is built and when one is allowed, but both are written as constraints on
a dialog — so an inventory that never considers one never meets them, and every form ships as a
full page by default. Make the choice a decision the inventory records rather than a rule the
builder might trip over: mark each **form** route `page` or `dialog` with the reason.

Two tells decide it, and both are visible from the route list alone:

- **Where the links come from.** If every inbound link sits on a screen that already names the
  thing being acted on, the form is a side-step from that screen, not a destination — the page
  it would get spends its whole chrome (breadcrumb, restated title, restated subject) rebuilding
  a context the visitor never left. A route also reached from outside the app — an email link, a
  bookmark, a search result, a payment return — is a destination and stays a page.
- **Whether the success state can find its own way out.** A form whose confirmation has to grow
  "back to X" and "on to Y" buttons is telling you it stranded the visitor. Closing a dialog
  restores whatever screen it was opened from, so the exit costs one control and is always
  right; a page has no screen underneath and must invent destinations that are guesses.

Length is not one of the tells, and neither is how consequential the action is on its own — a
three-field form is a page when it is entered cold, and a longer one is a dialog when it is a
side-step from a screen the visitor wants to stay on. What rules a dialog out is a flow with
steps, a state the visitor would be upset to retype, or an entry from outside the app (BP68).

**Cover the states, not just the happy path.** Every list needs an empty state, every form an
error state, every async surface a pending one, and every mutation a success the user can see
(`code-ui`, four states). The mock data is what makes them demonstrable (BP49), so the inventory
says which record demonstrates which state.

## The shell contract

`.cache/mock-ui/shell.md` is the run's answer to "what does every screen sit inside", written
before any screen exists and imported by all of them (BP61). It is **derived, never
prescribed**: nothing about a header, a sidebar, a width or a nav belongs in this file, because
the right answer for an operator console and the right answer for a public storefront are not
the same. What is fixed is the list of decisions the contract must make, and that each is made
**once**.

The contract records, each in a line or two with the reason:

- **Container.** The page's max width and its horizontal padding at each step, as one class
  string every area uses. Two areas may legitimately differ — a dense operator table area wants
  more width than a reading area — but a difference is a decision the contract states, not an
  accident of two agents picking different numbers.
- **Header composition.** What sits in an area header, in order, and what it does when the
  viewport is narrow. Which parts are shared by every area and which are the area's own.
- **Nav pattern.** One implementation, parameterised by its links: how the current page is
  marked (`aria-current="page"`), what element the links are, and where the nav goes on a phone.
- **Footer.** There is one unless there is a strong reason there is not, and the contract states
  what is in it — links, contact, fine print, copyright — with the copy written (BP69). "The PRD
  specifies no footer content" is a reason to write the footer a product of this kind has and
  anchor what was invented, NOT a reason to ship a site with no bottom edge and no way to reach
  anyone. A staff-only area may legitimately carry a reduced one; say so and say why.
- **Heading ramp.** The type treatment for the page heading, the section heading and the card
  title, as the classes to use — and the rule that the page heading exists in exactly one
  component, which every page renders (BP61). Whatever design seam the app already has (a
  heading-font token, a tracking scale) is used by **all** of them or by none (BP63).
- **Breakpoint ramp.** The named steps this app uses, and the phone behaviour of each layout
  pattern it contains: card grid, data table, definition list, form, header, dialog. This is the
  section that decides whether a wide table scrolls, drops columns, or restacks — once, so ten
  tables do not answer it ten ways (BP62).
- **Shared state components.** The empty state, the skeleton vocabulary, the form-level alert
  slot, and the annotation module — the anchor and the inspector that reads it — with its flag
  (BP64, BP70), named, with their paths.
- **Production slots the spec never mentioned.** The list of things this kind of product has
  that the PRD did not ask for — a footer, a contact route, terms, a privacy page, a way to
  leave — with, for each, whether it was built and where, or judged not needed and why (BP69).
  This is the section a reviewer reads to find out what the spec forgot.

In **extension** mode the contract is *read* rather than written: each line cites the file the
existing app answers it from, and a line the app answers inconsistently is reported as a finding
rather than resolved by picking a side.

## Shared structure

- **One root layout.** `apps/web/src/app/layout.tsx` owns `<html>`/`<body>`, the fonts, and the
  `ThemeProvider`. Route groups are directories beside it; their layouts return plain wrappers
  carrying the area shell (BP18–BP19, design finding 3). Never a second root layout — it costs
  a full page reload on every cross-area link.
- **Root-level fallbacks.** `src/app/not-found.tsx` and `src/app/global-error.tsx` exist and
  render inside the shell (BP67). Without them an unknown URL and a layout-level crash drop the
  visitor out of the product entirely, and those are the two screens nobody remembers to look at.
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

## Existing UI: the disposition ruling (both modes)

`apps/web` is never greenfield in the literal sense — the scaffold shipped working pages, and a
second or third run finds the previous run's screens. The inventory rules on each existing file
explicitly rather than discovering the collision at build time. Four rulings, one line each,
with the reason:

- **off-limits** — never mocked, never moved. Route handlers another skill owns (the auth
  proxy), and `src/generated/**`.
- **keep** — real product UI that already answers this question. In extension mode this is most
  of the app, and "keep" is the default: an existing header, nav, page-heading or empty-state
  component is imported, not re-authored.
- **re-home** — a working part of the scaffold's demo UI that is genuinely real (a sign-in panel
  wired to the auth server, a payment form that takes real test money). It moves into the
  product screen that owns that job and keeps working; it is not re-implemented, and it is not
  mocked beside itself.
- **delete** — the rest of the scaffold's demo UI: diagnostic panels, "test item" links, sample
  pages whose only purpose was to prove the pipeline. In **greenfield** mode these go (BP65).
  Leaving them in the product's shell means every screen ships furniture the design pass has to
  work around, and the layout the run hands back is not the layout that will ship. A file the
  plan of record claims cannot simply vanish: the deletion carries a reasoned line in
  `scripts/docs-check.ignore` (BP58), and the plan is not rewritten, because how the scaffold
  was built did not change.

The usual `/` collision is a disposition ruling like any other: if the inventory claims `/` and
a scaffold page already resolves there, that page is ruled **delete** or **re-home**, because two
pages resolving to one URL is a build error (BP20).

## Routes owned by another skill

Some routes are real before the mock starts: a payment form, an OAuth callback, an identity
proxy. The rule is not "skip them" — it is **keep the owned surface, mock the page around it**
(BP66).

The embedded widget, the redirect handler and the secret exchange stay exactly as their owning
skill wrote them. The page they live on is still this run's: the summary of what is being
committed to, the totals, the identity capture that the flow needs, the terms at the point of
commitment, the shell around all of it, and the screen the flow returns to. Those are layout,
they are in the PRD's journey, and a mock that leaves them out leaves out the highest-stakes
screen in the product — the one place where "we will work it out in the slice" costs the most.

A page around an owned surface is marked in the inventory table with the file it must not
rewrite, so the group agent knows which import is law.

## The four output files

Phase 1 writes all four, and they must agree:

- `.cache/mock-ui/pages.md` — the tables above, the extras, and the disposition rulings.
- `.cache/mock-ui/shell.md` — the shell contract.
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
  label/input/reserved-line pattern the app's existing auth form already demonstrates.
- **No form library.** This repo validates with plain state and maps error codes to its own
  copy (`code-ui`). Do not install react-hook-form or zod for the mock: a second form philosophy
  in the same app is a fork nobody chose.
