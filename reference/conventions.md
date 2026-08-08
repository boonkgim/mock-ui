# Conventions — ui-mock

This file doubles as the reflection-loop review checklist: reviewers score every rule id
below against the group's files and cite ids (BPnn/APnn) in findings. Items tagged `[scan]`
are mechanical class-name greps covered by `npx impeccable detect` in
`scripts/verify_pages.sh` — reviewers skip them and spend judgment on the rest.

## Contents

- Next.js 16 docs to consult
- Design findings (1–5)
- Best practices — DO / DON'T (BP1–BP53)
- AI UI anti-patterns to avoid (AP1–AP32)

## Next.js 16 docs to consult

This repo's Next.js has breaking changes vs training data (see AGENTS.md). Before writing
pages, read the relevant guide under `node_modules/next/dist/docs/`:

- `01-app/01-getting-started/`: `02-project-structure.md`, `03-layouts-and-pages.md`,
  `04-linking-and-navigating.md`, `05-server-and-client-components.md`,
  `07-mutating-data.md`, `10-error-handling.md`, `11-css.md`,
  `14-metadata-and-og-images.md`, `18-upgrading.md`
- `01-app/03-api-reference/03-file-conventions/`: `page.md`, `layout.md`, `loading.md`,
  `error.md`, `not-found.md`, `route-groups.md`, `dynamic-routes.md`, `template.md`,
  `unauthorized.md`, `forbidden.md`, `proxy.md`, `src-folder.md`
- `03-api-reference/02-components/`: `link.md`, `form.md`, `image.md`

## Design findings (1–5)

1. Next 16 `error.tsx` receives `{ error, retry }` — the pre-16 `reset` prop is gone
   (10-error-handling.md).
2. `PageProps`/`LayoutProps` are globally generated types — run `next typegen` (or
   dev/build) before tsc or page typechecks fail.
3. The three areas must be route groups `(public)`/`(customer)`/`(admin)` under the ONE
   existing root layout — never three root layouts (cross-area navigation would
   full-page-reload).
4. The original globals.css used prefers-color-scheme + only 2 tokens and a hardcoded Arial
   body font — shadcn init must be allowed to rewrite globals.css to the
   `:root`/`.dark`/`@theme inline` token pattern; do not preserve the old file.
5. Mock-data accessors should be async functions so loading.tsx/Suspense render truthfully
   and the real-DB swap touches only `src/lib/mock-data.ts`, not pages.

## Best practices — DO / DON'T

### Server/client component boundaries (05-server-and-client-components.md)

- BP1. Pages and layouts stay Server Components: no `'use client'` in any page.tsx,
  layout.tsx, loading.tsx, or not-found.tsx. Interactivity lives in leaf components under
  src/components.
- BP2. `'use client'` only on the smallest interactive leaf (form wrapper with
  useActionState, Stripe checkout, menu/dialog trigger) — never on a whole page section that
  is mostly static.
- BP3. src/lib/mock-data.ts starts with `import 'server-only'` so a client import fails at
  build time; no client file imports it.
- BP4. Data crosses the boundary as serializable props (or children slots for
  server-rendered content inside client shells); never fetch initial page data in useEffect.
- BP5. error.tsx and global-error.tsx must begin with `'use client'` — the only route files
  that do (10-error-handling.md).

### Awaited params/searchParams and typing (page.md, layout.md, dynamic-routes.md)

- BP6. `params` and `searchParams` are Promises in Next 16: every access is
  `await props.params` (or `use()` in a client page). Grep for synchronous `params.` access
  = violation.
- BP7. Type pages `PageProps<'/route/[param]'>` and layouts `LayoutProps<'/route'>` with the
  route literal — global helpers, no import; `next typegen` (or dev/build) must run before
  tsc (design finding 2).
- BP8. Read `searchParams` only in page.tsx (never layout.tsx — layouts don't rerender and
  have no searchParams); client-side-only filtering uses `useSearchParams` (layout.md).
- BP9. Param values are `string | string[] | undefined` — parse/validate them and call
  `notFound()` when the entity doesn't exist, before any suspending await
  (dynamic-routes.md, loading.md).

### Data fetching, Suspense, loading.tsx (loading.md)

- BP10. Fetch in the async server page (or an async server child), awaiting the mock-data
  accessors; pages are `async function`.
- BP11. Every segment that awaits data has a loading.tsx skeleton that mirrors the real page
  shape (shadcn `<Skeleton>` in the same card/table/list layout) — not a bare spinner or
  "Loading..." string.
- BP12. Layouts never fetch uncached data — it blocks loading.tsx from showing; keep fetches
  in page.tsx (loading.md caveat).
- BP13. Independent slow regions on one page (e.g. admin diary panels) get their own
  `<Suspense fallback={...}>` blocks instead of one page-wide await chain.
- BP14. When generateMetadata and the page need the same record, wrap the accessor in React
  `cache()` so it runs once (14-metadata-and-og-images.md).

### error.tsx / not-found.tsx (10-error-handling.md)

- BP15. Each route group has an error.tsx whose props are `{ error, retry }` — Next 16
  renamed `reset` to `retry`; any `reset` prop is a bug (design finding 1).
- BP16. Expected failures (validation, seat sold out, expired credit) are returned as
  action-state values, never thrown; thrown errors are reserved for genuine bugs caught by
  error.tsx.
- BP17. Detail routes ([slug], [id]) have a sibling not-found.tsx and the page calls
  `notFound()` on missing ids.

### Route groups, layouts, nav (route-groups.md, layout.md, 03-layouts-and-pages.md)

- BP18. Exactly one root layout owns `<html>`/`<body>`; `(public)`, `(customer)`, `(admin)`
  group layouts return plain wrappers (design finding 3 — multiple root layouts force full
  page reloads).
- BP19. Each group layout carries that area's shell (header/nav/footer); no per-page
  copy-pasted nav bars.
- BP20. No two routes in different groups resolve to the same URL path (build error).
- BP21. Internal navigation uses `<Link>` from next/link — grep for `<a href="/` =
  violation; `router.push` only where a real programmatic redirect is needed.
- BP22. Every page exports `metadata` (or `generateMetadata`) with a distinct title; root
  layout sets a `title.template`; no manual `<head>`/`<title>` tags anywhere
  (14-metadata-and-og-images.md, layout.md).

### Forms via server actions + useActionState (07-mutating-data.md, 10-error-handling.md)

- BP23. All mutations are server actions in `'use server'` files (src/app/**/actions.ts),
  invoked via `<form action={...}>` — no onClick fetch, no route handlers for form posts
  (only the two allowed route handlers exist: Stripe webhook + waiting-list removal link).
- BP24. Every server action starts with an auth/session check stub (plus row-ownership
  check for customer resources) — actions are reachable by direct POST, so the guard lives
  in the action even at mock stage (07-mutating-data.md warning).
- BP25. Actions used with useActionState take `(prevState, formData)` and return a typed
  state (e.g. `{ status: 'idle' | 'error' | 'success'; message?: string; fieldErrors?:
  Record<string, string> }`) declared next to the action; no `any` state.
- BP26. Submit buttons reflect both validity and pending: on client-validated forms (BP53)
  `disabled={!isValid || pending}` — the button unlocks only once the form is valid — plus
  visible pending text; never a silent unresponsive submit. Forms with nothing to validate
  client-side disable on `pending` alone.
- BP27. Inputs carry `name` attributes read via `formData.get()` — the FormData contract
  with the action holds even when react-hook-form controls the inputs (Controller spreads
  `name`). Forms with nothing to validate client-side (confirm-only, selects that always
  hold a valid default) stay uncontrolled and progressively enhanced.
- BP28. On success: `revalidatePath()` (or `refresh()`) then `redirect()` — in that order,
  because `redirect` throws and code after it never runs.
- BP29. Action error messages render near the form in an `aria-live="polite"` element fed
  from action state.
- BP53. Forms with client-validatable input (free text, required checkboxes/selects) never
  surface the browser's native validation bubbles (unstylable, inconsistent per browser):
  the `<form>` gets `noValidate`, and validation runs client-side via react-hook-form +
  zod (`useForm` + `zodResolver`, `mode: 'onTouched'`, explicit `defaultValues`), rendered
  through the shadcn Field primitives — each input wrapped in `<Controller>` rendering
  `<Field data-invalid>` + `<FieldLabel>` + the control (with `aria-invalid`) +
  `<FieldError>`; the form body sits in a `<FieldGroup>` (its gap replaces `space-y-*`).
  Keep semantic input types (`email`, `tel`) — `noValidate` strips their validation, not
  their mobile-keyboard semantics. The client zod schema mirrors the server action's
  checks with IDENTICAL error copy — the server stays the source of truth (BP16, BP24,
  BP25 unchanged) — and server `fieldErrors` are mapped into the same per-field slots via
  `form.setError(name, { type: 'server', message })` in an effect, so the two sources
  cannot render differently. Submission stays the server action: `action={formAction}`
  plus an onSubmit guard (`if (!isValid) { event.preventDefault(); form.trigger(); }`).
  Exemplar: `src/components/public/waiting-list-form.tsx`.

### Accessibility

- BP30. Exactly one `<h1>` per page; heading levels never skip (h1 → h3 with no h2 =
  violation).
- BP31. Every input has a programmatically associated label (`<Label htmlFor>` / id pair);
  placeholder text is never the only label.
- BP32. Icon-only buttons have `aria-label` or `<span className="sr-only">`; decorative
  lucide icons get `aria-hidden="true"`.
- BP33. Group layouts render landmarks: `<header>`, `<nav aria-label="...">`, one `<main>`
  wrapping page content.
- BP34. Status is never color-only: seat/booking/credit states pair a Badge color with
  literal text ("Sold out", "3 left", "Expires 12 Sep").
- BP35. No `focus:outline-none`/`outline-none` on interactive elements without a
  `focus-visible:` ring replacement (shadcn primitives already ship one — don't strip it).
- BP36. Tabular data (attendees, bookings, diary) uses the shadcn `<Table>` (real table/th
  semantics), not div grids; current-page nav links get `aria-current="page"`.
- BP50. Cards are NOT whole-clickable in this app — the standard is explicit, consistent
  affordances: the title is a normal `<Link>`, and the footer action is a Button-rendered
  link styled the same on every sibling card (never a button on one card and bare text on
  its neighbour). Never a card-level `onClick` on a div (breaks middle-click, right-click,
  semantics) and never nested interactive elements (`<a>`/`<button>` inside a wrapping
  link). The stretched-link pattern (Heydon Pickering's inclusive card: `relative` card,
  ONE title link with `after:absolute after:inset-0`, secondary controls raised with
  `relative z-10`) is the approved technique if whole-card targets are ever adopted — but
  adopting it is an app-wide decision applied to every card grid at once, not per-card;
  do not introduce it piecemeal.
- BP51. Short, non-destructive, context-returning actions (e.g. join a waiting list) render
  as a URL-driven dialog via intercepting + parallel routes, never as a client-state-only
  popup: keep the full page at its canonical URL (deep links, refresh, no-JS), add a
  `@modal` slot to the group layout with a null `default.tsx` and a null catch-all page,
  and intercept with `@modal/(.)<path>/page.tsx` rendering the SAME form component inside
  a client dialog shell that closes via `router.back()` (parallel-routes.md, Modals).
  Loading states for intercepted modals need two defences, because the router applies the
  LAYOUT-level loading boundary to the slot on unprefetched re-entry (e.g. reopening after
  `router.back()`), bypassing every slot/segment loading file: (a) the intercepted page is
  SYNCHRONOUS — it returns the dialog shell immediately and suspends only inside it (async
  content behind an in-dialog `<Suspense>` whose fallback mirrors the form); (b) the layout
  wraps the slot in a container that hides children lacking `data-modal-chrome`
  (`[&>*:not([data-modal-chrome])]:hidden`) — the real dialog escapes via portal, slot
  skeletons carry the attribute, so only the leaked page-shaped fallback is suppressed.
  Consequential, multi-step, or externally-entered flows (checkout, login, set-password,
  cancellation) stay full pages. Never fork the copy or the form between the page and the
  dialog — share one component so the two renderings cannot drift.
- BP52. No invention: every domain noun, form field, price rule, status, and copy fact must
  be traceable to the PRD, the data model, pages.md, or `.cache/ui-mock/facts.md`. Capture
  forms mirror their entity's columns exactly (names, required/optional, nullability
  pairings) — a required column missing from a form and a field the spec never asked for
  are equally findings. Anything on the PRD's not-in-scope list must not appear in the UI.
  When the spec is silent on a fact the UI needs, flag the gap (return it to the
  orchestrator or mark it in the review) — never fill it from a plausible prior.

### shadcn/ui usage

- BP37. Primitives import from `@/components/ui/*` only; never hand-roll a control a
  generated primitive covers (Button, Dialog, Select, Badge, Skeleton, Table, Card, Input,
  Label).
- BP38. Feature components are composed in `src/components/<area>/`; page.tsx stays thin:
  await data, compose components, pass props.
- BP39. Conditional classes go through `cn()` from `@/lib/utils` — no template-string class
  concatenation.
- BP40. Visual variants use the primitive's built-in `variant`/`size` props — not
  per-call-site className soup overriding the primitive's look. When a new variant is
  genuinely needed, define it in a wrapper component under `src/components/<area>/` (e.g. a
  CVA wrapper composing the primitive), never by editing the ui file itself: ui files must
  stay identical to what `shadcn add` generated so any of them can be freshly regenerated
  (delete the file, re-run setup) without losing custom work.
- BP41. Files in `src/components/ui/` are generated output owned by `shadcn add` — no hand
  edits, ever. The setup script never overwrites them (it skips components whose file
  already exists, and passes no `--overwrite`), but that is a safety property, not
  permission to edit: anything custom lives outside `src/components/ui/` in wrappers under
  `src/components/<area>/`.

### Theming / design tokens (11-css.md + shadcn Tailwind-4 convention)

- BP42. Only semantic token classes in JSX: `bg-background`, `bg-card`, `text-foreground`,
  `text-muted-foreground`, `border-border`, `bg-primary`, `text-destructive`, etc. Grep for
  palette classes (`-blue-500`, `-slate-`, `-zinc-`, `-gray-`, ...) in src must return
  nothing.
- BP43. No hex/rgb/oklch literals in className or `style={}`; every color value lives in
  globals.css tokens (a restyle = one-file token edit).
- BP44. Dark mode comes from the `.dark` token block redefining the same variables —
  component files contain no scattered `dark:` overrides (target: zero `dark:` in
  src/components and src/app pages).
- BP45. globals.css follows the shadcn Tailwind-4 pattern: `:root` + `.dark` CSS-variable
  sets mapped through `@theme inline`; shadcn init is allowed to rewrite the old 2-token
  file (design finding 4). Without `@theme inline`, `bg-primary` etc. silently stop
  resolving.
- BP46. Radius via the `--radius` token and Tailwind scale; no arbitrary values
  (`w-[437px]`, `rounded-[13px]`) without a justifying comment.

### Mock-data isolation

- BP47. Domain interfaces (Workshop, Run, Booking, CreditBalance, CancellationRequest,
  Attendee...) live once in `src/lib/types.ts`; no inline/anonymous data shapes in pages.
- BP48. All mock data sits in the single `src/lib/mock-data.ts` module exposing async
  accessor functions (design finding 5); pages await accessors, components receive typed
  props and never import mock-data.
- BP49. Mock records are realistic and cover edge states on purpose: a sold-out run, a
  nearly-full run, an expiring credit, a pending cancellation request, a past booking with
  receipt — so every UI state is demonstrable.

## AI UI anti-patterns to avoid (impeccable.style)

Source: impeccable.style (pbakaus/impeccable) deterministic slop rules, phrased as
greppable DON'Ts. `[scan]` = covered by `npx impeccable detect` in verify_pages.sh;
reviewers skip those ids.

### Visual details

- AP1. `[scan]` No side-tab accent borders: `border-l-4`/`border-l-2` + a colored border
  class on a card — "the most recognizable tell of AI-generated UIs".
- AP2. `[scan]` No thick accent border on a rounded card (colored `border-2`+ combined with
  `rounded-*`).
- AP3. `[scan]` No decorative glassmorphism: `backdrop-blur` + translucent `bg-*/50`-style
  surfaces or glow borders unless solving a real layering problem (e.g. an actual overlay).
- AP4. `[scan]` No hairline border paired with a wide diffuse shadow (`border` +
  `shadow-xl`/`shadow-2xl` on the same card).
- AP5. `[scan]` No decorative grid-line or repeating-gradient-stripe backgrounds
  (`bg-[linear-gradient(...)]` patterns, `repeating-linear-gradient`) without a
  canvas/measurement purpose.
- AP6. `[scan]` No extreme rounding: `rounded-3xl`+ on small cards/inputs; don't give every
  element the same radius "soft blob" treatment.
- AP7. No hand-coded decorative SVG scenes/mascots or heroes assembled from generic SVG
  shapes.

### Color & contrast

- AP8. `[scan]` No purple/violet gradients or cyan-on-dark accents: grep `from-purple`,
  `from-violet`, `from-indigo`, `to-cyan`, `to-blue` gradient combos.
- AP9. `[scan]` No gradient text: `bg-clip-text text-transparent` anywhere (headings,
  metrics) = violation.
- AP10. `[scan]` No dark surfaces with glowing colored box-shadows (`shadow-primary/...`,
  colored `shadow-[0_0_...]`).
- AP11. `[scan]` No radial-gradient halos/spotlight glows behind sections (`bg-radial`,
  `radial-gradient` haze).
- AP12. No cream/beige "tasteful AI default" page background — the page background is the
  shadcn `bg-background` token, unmodified toward warm beige.
- AP13. No gray text on colored backgrounds (e.g. `text-muted-foreground` on `bg-primary`);
  all text meets WCAG AA (4.5:1 body, 3:1 large).

### Typography

- AP14. No kicker/eyebrow: tracked-uppercase mini-label or pill chip sitting above a heading
  (`uppercase tracking-wide(st) text-xs` above h1/h2).
- AP15. No icon-in-rounded-tile stacked above a heading — the universal AI feature-card
  template.
- AP16. No oversized italic serif display hero headline; no full-sentence display-size
  headline monopolizing the viewport.
- AP17. No flat hierarchy: adjacent heading/body sizes must differ by clear steps (don't
  ship text-lg heading over text-base body everywhere).
- AP18. No all-caps body passages; no letter-spacing above 0.05em on body text; no crushed
  negative tracking on display text.
- AP19. No functional text under 11px / body text under 12px (`text-[10px]` = violation);
  line-height on multi-line text ≥ 1.3 (no `leading-none/tight` on paragraphs).

### Layout & space

- AP20. No identical card grids — same-sized icon+heading+text cards repeated endlessly;
  vary card content/size by what the data warrants.
- AP21. No hero-metric cliché (big number + tiny label + three supporting stats + gradient
  accent) on the admin dashboard; stat tiles use plain token styling.
- AP22. No nested cards (`<Card>` inside `<Card>`); flatten with spacing/dividers.
- AP23. No monotonous spacing — one gap value reused everywhere; use deliberate rhythm
  (tighter within groups, looser between sections).
- AP24. No prose lines wider than ~80ch: long text blocks get
  `max-w-prose`/`max-w-[65ch]`.
- AP25. No tiny numbered section labels ("01", "02") beside headings imitating editorial
  structure.
- AP26. No content flush to edges: containers keep ≥12–16px padding; nothing overflows its
  container or forces horizontal scroll.
- AP27. No justified text (`text-justify`); no skipped heading levels.

### Motion

- AP28. `[scan]` No pulsing status dots (`animate-pulse` on a status indicator), no
  decorative blinking cursors, no auto-scrolling marquees.
- AP29. `[scan]` No bounce/elastic easing; never animate layout properties
  (width/height/padding/margin) — transform/opacity only.
- AP30. `[scan]` No image hover transforms (`hover:scale-*`, `hover:rotate-*` on
  images/cards).

### Copy & imagery

- AP31. No marketing buzzwords in UI copy: streamline, empower, supercharge, world-class,
  enterprise-grade; no em-dash-heavy body copy; no repeated identical labels within one
  card.
- AP32. No `<img>`/`<Image>` with empty, missing, or placeholder `src` shipping as
  broken-image boxes.
