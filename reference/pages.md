# Route inventory — ui-mock

## Contents

- Shared structure (root layout, groups, URL rules)
- (public) routes
- (customer) routes
- (admin) routes
- Component add-list (must match scripts/setup_shadcn.sh)

Each group section lists every route: URL, page file, purpose, key shadcn components, and the
mock data shown. Routes marked **form** get a colocated `actions.ts` (server action +
useActionState typed state, per BP23–BP29). Each group section ends with its group-level
extras. Rules and ids (BPnn/APnn) referenced here are defined in `conventions.md`.

## Shared structure

- One root layout — the existing `src/app/layout.tsx` — owns `<html>`/`<body>`. The three
  areas are route groups `(public)`, `(customer)`, `(admin)` under it; group layouts return
  plain wrappers with the area shell (BP18–BP19, design finding 3).
- The default `src/app/page.tsx` from create-next-app is removed by the Phase 1 setup
  script (first-run scaffold cleanup). The `(public)` agent must still verify it is gone
  before creating `src/app/(public)/page.tsx` — two pages resolving to `/` is a build
  error (BP20).
- Every page exports `metadata` (or `generateMetadata`) with a distinct title (BP22); the
  root layout sets a `title.template`.
- Dynamic-segment pages call `notFound()` on unknown ids and have a sibling `not-found.tsx`
  (BP9, BP17).
- Group-level `loading.tsx` is the baseline skeleton; add a deeper per-segment `loading.tsx`
  wherever the page shape differs enough that the group skeleton would lie (BP11).

## (public) routes — `src/app/(public)/`

| URL | Page file | Purpose | Key shadcn components | Mock data shown |
|---|---|---|---|---|
| `/` | `page.tsx` | Public workshop catalogue | Card, Badge, Button | All workshops with next run date, price, seats-left badge (incl. one sold-out — BP34/BP49) |
| `/workshops/[slug]` | `workshops/[slug]/page.tsx` | Workshop page: schedule + book + waiting-list CTA | Card, Table, Badge, Button, Separator | One workshop, its runs (sold-out run shows waiting-list CTA instead of Book) |
| `/dates` | `dates/page.tsx` | Upcoming-dates list across workshops | Table, Badge, Button | All future runs sorted by date, seats remaining |
| `/workshops/[slug]/waiting-list` | `workshops/[slug]/waiting-list/page.tsx` | Waiting-list join screen — **form** | Card, Input, Label, Button, Alert | Workshop + sold-out run being waited on |
| `/checkout/[runId]` | `checkout/[runId]/page.tsx` | Payment/checkout (Stripe embedded) — **form** | Card, Separator, Button | Run summary, price breakdown; Stripe embed is a `'use client'` leaf placeholder (BP2) |
| `/checkout/[runId]/confirmation` | `checkout/[runId]/confirmation/page.tsx` | Booking confirmation | Card, Badge, Button | Confirmed booking: reference, run, learner count |
| `/bookings/[bookingId]/learner-details` | `bookings/[bookingId]/learner-details/page.tsx` | Learner-details capture — **form** | Card, Input, Label, Select, Checkbox, Button | Booking with learners still to be named |
| `/set-password` | `set-password/page.tsx` | Set / reset password (accounts created passwordless by booking flow) — **form** | Card, Input, Label, Button, Alert | None (token arrives via searchParams — BP8/BP9) |
| `/login` | `login/page.tsx` | Login — **form** | Card, Input, Label, Button, Alert | None |

(public) extras: `layout.tsx` (site header with `<nav>`, footer), `loading.tsx`, `error.tsx`
(`{ error, retry }` — design finding 1), `workshops/[slug]/not-found.tsx`,
`bookings/[bookingId]/not-found.tsx`; `actions.ts` beside each **form** page.

## (customer) routes — `src/app/(customer)/`

| URL | Page file | Purpose | Key shadcn components | Mock data shown |
|---|---|---|---|---|
| `/account/bookings` | `account/bookings/page.tsx` | Upcoming bookings | Card, Table, Badge, Button | Upcoming bookings incl. one with a pending cancellation request (BP49) |
| `/account/bookings/past` | `account/bookings/past/page.tsx` | Past bookings + receipts | Table, Badge, Button | Past bookings with receipt links (one with receipt — BP49) |
| `/account/credits` | `account/credits/page.tsx` | Credit balance with expiries | Card, Table, Badge | Credit lines incl. one expiring soon ("Expires 12 Sep" literal text — BP34) |
| `/account/bookings/[bookingId]/cancel` | `account/bookings/[bookingId]/cancel/page.tsx` | Cancellation request — **form** | Card, Textarea, Label, Button, Alert | The booking being cancelled + policy summary |

(customer) extras: `layout.tsx` (account nav with `aria-current="page"` — BP36),
`loading.tsx`, `error.tsx`, `account/bookings/[bookingId]/not-found.tsx`; `actions.ts` beside
the cancel page (row-ownership check stub — BP24).

## (admin) routes — `src/app/(admin)/`

| URL | Page file | Purpose | Key shadcn components | Mock data shown |
|---|---|---|---|---|
| `/admin` | `admin/page.tsx` | Diary: runs, seats sold/remaining signed, undecided requests | Table, Badge, Card, Tabs | Runs with signed sold/remaining counts; undecided cancellation requests; independent panels in own `<Suspense>` blocks (BP13); plain-token stat tiles (AP21) |
| `/admin/workshops` | `admin/workshops/page.tsx` | Workshop list → create/edit | Table, Button, DropdownMenu | All workshops with run counts |
| `/admin/workshops/new` | `admin/workshops/new/page.tsx` | Workshop create — **form** | Card, Input, Label, Textarea, Button | Empty form defaults |
| `/admin/workshops/[workshopId]/edit` | `admin/workshops/[workshopId]/edit/page.tsx` | Workshop edit — **form** | Card, Input, Label, Textarea, Button | Existing workshop pre-filled |
| `/admin/runs/new` | `admin/runs/new/page.tsx` | Run schedule create — **form** | Card, Input, Label, Select, Button | Workshop options for the Select |
| `/admin/runs/[runId]/edit` | `admin/runs/[runId]/edit/page.tsx` | Run edit + copy — **form** (copy = second action in same actions.ts) | Card, Input, Label, Select, Button | Existing run pre-filled |
| `/admin/runs/[runId]/attendees` | `admin/runs/[runId]/attendees/page.tsx` | Attendee list for a run | Table, Badge, Button | Attendees with learner details, payment status |
| `/admin/cancellations` | `admin/cancellations/page.tsx` | Cancellation-request decisions — **form** (approve/decline actions) | Table, Badge, Button, Dialog | Pending requests with booking + credit implications |
| `/admin/export` | `admin/export/page.tsx` | CSV/spreadsheet export — **form** (export action stub) | Card, Select, Button, Alert | Export scope options (run, date range) |

(admin) extras: `layout.tsx` (admin nav sidebar/header, single admin guard stub — one guard
on `/admin`, per auth decisions), `loading.tsx`, `error.tsx`,
`admin/workshops/[workshopId]/not-found.tsx`, `admin/runs/[runId]/not-found.tsx`;
`actions.ts` beside each **form** page (auth-check stub first line of every action — BP24).

## Component add-list (must match scripts/setup_shadcn.sh)

alert, badge, button, card, checkbox, dialog, dropdown-menu, input, label, select,
separator, skeleton, table, tabs, textarea
