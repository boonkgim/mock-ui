---
name: mock-ui
description: Build the whole app's screens as mock pages — route inventory and a shell contract derived from a PRD, typed mock data behind async accessors, one shared shell, then every route in its group — then review each group and verify mechanically. Use when the user says "mock ui", "ui mock", "mock pages", "mock up the screens", "scaffold the UI", or "build the pages". It writes no real data-fetching code and never commits; later, vertical slices replace its mock data layer by layer.
license: MIT
---

# mock-ui — orchestrator

Runs after a data-model or schema design step and before the app is actually built out screen
by screen: builds every screen a product brief (PRD) and, if one exists, a data model imply,
using typed mock data instead of the app's real data layer. Pages survive; `src/lib/mock-data.ts`
does not — each vertical slice replaces one accessor with the real data-fetching call that will
eventually replace it (a GraphQL query, a REST call, a tRPC procedure — whatever the app uses),
and the component above it never learns which it got.

**What the mock owes: the final layout, minus design and minus the backend.** Every structural
decision the real app will ship — the shell, the route tree, what is on each screen, where it
sits, how it reflows on a phone, which of the four states it can be in — is made here, once, and
the vertical slices only swap the data behind it. What is deliberately _not_ made here is visual
design (colour, type scale, spacing rhythm, imagery: tokens, and a later pass owns them) and the
API. A screen the mock skips, or a breakpoint it never decides, is a layout decision handed to
whoever writes the slice — which is the failure this skill exists to prevent.

Screens are built to what a shipped product of this kind has, not to the subset the PRD happened
to list, and the copy for it is written rather than left blank (BP69). Anything the PRD is silent
on gets flagged in the report and anchored to the element it is about, where it surfaces in the
run's one open-questions inspector — never as visible commentary on the screen (BP70), and never
silently invented as domain fact (BP52).

**Out of scope.** No edits to the API/schema layer (however the host project organizes its
backend — GraphQL SDL and resolvers, REST handlers, a database schema package) or to generated
code. No commits — building this out into the real app is a separate, later step this skill does
not do: whatever process the host project uses to turn a mock screen into a real one owns the
gates and the commit for that. This skill's job ends at a working, uncommitted tree; a mock is
not a slice.

## Two modes, decided in Phase 0

The same skill runs on a bare scaffold and on a live app, and almost everything below is shared.
What differs is who owns the shell:

- **greenfield** — the app has no product UI yet, only whatever demo or diagnostic UI the
  scaffold shipped to prove its wiring. This run authors the shell contract, and **the scaffold's
  demo UI is removed rather than parked inside the product's shell** (BP65). What the scaffold
  proved that is genuinely real — a working auth panel, a real payment form, a live health
  query — is kept where it is real and re-homed into a product screen; what only ever existed to
  demonstrate the stack is deleted, and its removal is recorded wherever the host project's own
  plan-of-record mechanism claims the file, if it has one (BP58).
- **extension** — the app already has product screens and a shell. This run adds the routes one
  new feature needs and **conforms to the shell that exists**: it re-derives the contract by
  reading the app rather than authoring one, adds no second header, nav, page-heading or
  empty-state component, and changes a shared component only where the new feature genuinely
  needs it — in which case every existing consumer is updated in the same run. An extension run
  that introduces a second way to do something the app already does has made the app worse, not
  bigger.

Mode is a fact about the working tree, not about the PRD: if `src/app` already contains route
groups with their own layouts and pages that are not the scaffold's, the run is an extension.

## Context discipline

Thin orchestrator. Every domain detail lives in the reference files, and every dispatch below
names input paths and an output destination, never content. Keep only a manifest in the
orchestrating turn: one line per artifact or dispatch result (path + line count), at most 40
lines total. Never read the review files — route on returned rule ids and file lists.

Reference files (read by subagents, not by this turn):

- `.claude/skills/mock-ui/reference/pages.md` — how the route inventory and the shell contract
  are derived and what they must contain: group structure, shared files, mode rulings, what is
  off-limits, the component add-list.
- `.claude/skills/mock-ui/reference/conventions.md` — design findings 1–5, BP1–BP73, AP1–AP32.
  Doubles as the review-loop checklist.

This project's UI-writing skill, **`project-ui`**, is law, and every subagent that writes UI
**invokes it** before writing anything — reading its file directly is not the same and is not
enough; a "read this if you get to it" framing is how a subagent skims past exactly the subtle
rule (spacing ownership, a component's own composition pattern) that matters most. `project-ui`
covers reuse, the four states, accessibility, messages, the type ramp, touch targets, and layout
that does not shift or overflow — including a card grid's siblings matching height with their
action row pinned to the bottom (BP62), which is not a fresh judgement call each time a card
grid is built, it is this rule. For file layout and the theme/token contract, also invoke
**`project-web`** — skip its GraphQL query mechanics; this skill writes no real data-fetching
code. Where they and this skill's checklist disagree, **they win** — they have lint rules and
tests behind them, and this skill's checklist does not. If a host project has no UI-writing
skill of its own — its root `CLAUDE.md`/`AGENTS.md` typically names one per area it owns ("See
`.claude/skills/<name>/SKILL.md`"); invoke whichever it names, under whatever name that project
gives it — `reference/conventions.md` carries a self-sufficient fallback (e.g. the four states
for async UI) so this skill does not depend on one existing.

Source of truth for every domain fact: this run's own PRD — wherever the brief for this run
lives, by the host project's own convention if it has one (a dated folder under `docs/` is a
common one) or wherever the user points the run at — and, if one exists, the data model,
resolved **separately**, because they are not guaranteed to be the same document: a feature-scoped
PRD often carries a data model only when that feature adds tables, so resolving both from the
PRD's own folder can make the app's actual, project-wide data model invisible. If the host project
tracks a plan-of-record document that asserts against the file tree (a docs-check-style script, a
scaffold manifest), that document is not a source of domain facts, and a file it claims is not
edited without going through whatever exception mechanism it defines (BP58).

Run artifacts live in `.cache/mock-ui/` (gitignored).

## Phase 0 — Ground truth (subagent)

Dispatch one subagent:

- Inputs (paths): this run's PRD and, if one exists, the data model, resolved separately as
  above, `.claude/skills/mock-ui/reference/pages.md` (Domain & brand section), and the current
  `src/app/` and `src/components/` trees.
- Task: write `.cache/mock-ui/facts.md` — the fact sheet later agents build from: the run's
  **Mode** (greenfield or extension) with the evidence for it; brand/site name; currency, price
  display and tax rule; timezone/locale; the audiences the product has; per-entity column lists
  for every capture form and displayed record (from the data model, nullability pairings
  included); state machines and who may move what; visibility rules; and the PRD's not-in-scope
  list verbatim. Anything the PRD leaves open goes under an explicit **Gaps** heading rather than
  getting resolved.
- Return: the file path, its line count, the mode, the headline facts (brand, currency,
  timezone), and the gap count — at most 8 lines.

If there is no PRD, stop and say so — this skill mocks a specified product; it does not invent
one. Producing a PRD is a separate, earlier step for whatever process the host project uses.

## Phase 1 — Inventory and shell contract (subagent, then a checkpoint)

Dispatch one subagent:

- Inputs (paths): `.cache/mock-ui/facts.md`, the PRD and data model,
  `.claude/skills/mock-ui/reference/pages.md`, and the current `src/app/` and
  `src/components/` trees.
- Task: derive this run's inventory and write four files:
  - `.cache/mock-ui/pages.md` — the route table per group, in the format pages.md specifies,
    plus each group's extras and the disposition ruling for every route and component that
    already exists (keep / re-home / delete / conform).
  - `.cache/mock-ui/shell.md` — the shell contract, in the format pages.md specifies. In
    greenfield mode it is authored from the audiences; in extension mode it is **read off the
    existing app** and cites the files it was read from.
  - `.cache/mock-ui/routes.txt` — one repo-relative page file path per line (verification reads
    this, so it is the inventory's machine half and must not drift from the table).
  - `.cache/mock-ui/components.txt` — the shadcn registry names the inventory needs, one per
    line, starting from pages.md's default list.
- Return: the mode, group names with route counts, the shell contract's headline decisions
  (container, nav pattern, heading ramp, breakpoint ramp), the disposition rulings, and any
  registry name added beyond the default list — at most 20 lines.

**Stop and show the user the route list** — one line per route, grouped — with the shell
contract's headline decisions, the disposition rulings and Phase 0's gaps. Get confirmation
before building; both artifacts are expensive to change once pages exist on top of them.

## Phase 2 — Toolkit setup (script)

Run `bash .claude/skills/mock-ui/scripts/setup_shadcn.sh`. It verifies the app is already a
shadcn project on Tailwind 4 (never runs `init`, which would rewrite `globals.css` and undo the
token split), adds every component in `components.txt` whose file is missing, installs
`server-only` if absent, reformats the generated files, and checks that `shadcn add` did not
append a token block to `globals.css`.

On a non-zero exit, stop and report the script's ERROR line. For the token-block failure: keep
the `@theme inline` mapping line in `globals.css`, move the values down into
`src/styles/theme.css` (both schemes), and re-run.

## Phase 3 — Mock data (subagent)

Dispatch one subagent:

- Inputs (paths): `.cache/mock-ui/pages.md`, `.cache/mock-ui/facts.md`,
  `.claude/skills/mock-ui/reference/conventions.md` (BP47–BP49, BP52, BP57 and design finding 5
  govern this phase), and the PRD + data model.
- Task: write `src/lib/types.ts` (the domain interfaces) and
  `src/lib/mock-data.ts` (one module, first line `import "server-only"`, async accessor
  functions only, edge-state records so every UI state in the inventory is demonstrable).
  Interfaces mirror the data model's columns; **never import the app's own database client or
  ORM** — the mock stands in for the app's data layer, not its database, and each accessor is
  shaped like the real data-fetching call that will eventually replace it, not a query.
  In extension mode, extend the existing modules rather than rewriting them.
- Return: each file with its line count — at most 6 lines.

## Phase 4 — The shell (one subagent, before any group)

Every group builds on this, so it is built once and first. Dispatching the groups in parallel
without it is what produces three headers that disagree — the divergence is invisible in each
group's own review and obvious only across them.

Dispatch one subagent:

- Inputs (paths): `.cache/mock-ui/shell.md`, `.cache/mock-ui/pages.md`, `.cache/mock-ui/facts.md`,
  `.claude/skills/mock-ui/reference/conventions.md`, and the `project-ui` and `project-web` skills
  (see "Context discipline" above — invoke them, do not just read their files).
- Task: build exactly what the contract names (BP61) —
  the shell module under `src/components/shell/`: the container, the area header, the
  nav pattern, the footer if the contract has one, the page heading (the app's **only** `<h1>`),
  the section heading, the footer, and the shared empty state; the run's one annotation module
  (anchor + inspector) and its flag
  (BP64); the root `not-found.tsx` and `global-error.tsx` (BP67). In **greenfield** mode it also
  removes the scaffold's demo UI and re-homes whatever of it is real (BP65), recording that
  removal wherever the host project's own plan-of-record mechanism claims the file, if it has one
  (BP58). A
  re-homed component's behaviour is left alone and its surface is not: it is now part of a
  product screen and is held to the same rules as one (BP71). In
  **extension** mode it writes nothing new if the app already has these — it returns the paths
  the group agents must import instead.
- Return: the module's files with line counts, the import list group agents are to use, and —
  named separately — every component it re-homed with the group that now owns it, because that
  list is what Phase 6 adds to the reviewer's inputs — at most 14 lines.

## Phase 5 — One agent per group (single message)

After Phase 4 returns, dispatch one subagent per group from the inventory, **all in one
message**. Each dispatch:

- Inputs (paths): `.cache/mock-ui/pages.md` (its group's section), `.cache/mock-ui/shell.md`,
  `.cache/mock-ui/facts.md`, `.claude/skills/mock-ui/reference/conventions.md`, the `project-ui`
  and `project-web` skills (see "Context discipline" above — invoke them, do not just read their
  files), Phase 4's import list, `src/lib/types.ts`, `src/lib/mock-data.ts`, and the PRD + data
  model.
- Task: build every route of its group under `src/app/(<group>)/` — page.tsx, the
  group's layout.tsx / loading.tsx / error.tsx, not-found.tsx and actions.ts where the
  inventory says so — plus feature components under `src/components/<area>/`. The
  group layout composes the shell module and adds only its own nav items and guard; it defines
  no container, header markup, heading or empty state of its own (BP61). Structure from the
  inventory and the contract; every domain fact from facts.md and the source docs (BP52); every
  screen decides its phone layout (BP62).
- **Build each route on the surface its inventory row says**, not on the surface its file path
  suggests (BP51, BP74). A `dialog` or `both` row means this group also gets the `@modal` slot,
  its null `default.tsx`, and the layout's leak guard; a `both` row means the page and the
  intercepted route render ONE shared component with a surface flag, so the two cannot drift.
  A row whose Surface cell is empty is an unfinished inventory — rule it before building it,
  and say in the return that the inventory was incomplete.
- The agent owning the group that claims `/` also executes that route's disposition ruling and,
  if the host project has a plan-of-record mechanism (BP58), records the change through it — two
  pages resolving to `/` is a build error, and a silently deleted doc-owned file is drift.
- Return: files written with line counts — at most 12 lines, grouping related files onto one
  line if needed.

## Phase 6 — Review loop (per group; all-must-pass; cap 2 rounds)

For round R = 1, then R = 2, over the groups not yet passed:

1. **Reviewers** — three per remaining group, all dispatched in one message:
   - _Conventions reviewer_: inputs = `src/app/(<group>)/`, the group's components,
     **every other component the group's pages import that this run has not already reviewed** —
     Phase 4's re-homed list, and anything under `src/components/` outside `components/<area>/`
     (BP71) — `.cache/mock-ui/shell.md`, `reference/conventions.md`, and the `project-ui` skill
     (invoked, not just read).
     A component is reviewed because a screen renders it, never because this run authored it:
     scoping the inputs by who wrote the file is how an inherited component reaches production
     unreviewed while every screen around it passes. Score every
     BP/AP id except those tagged `[scan]` (the script checks those). Findings to
     `.cache/mock-ui/review-<group>-r<R>.md`, each citing rule id + file + line. Include an
     explicit BP54–BP56 pass, screen by screen: each descriptive slot is one short sentence,
     dense facts change UI pattern rather than sentence length, no fact is stated twice on one
     screen, the heading is still true in every state, and a height-changing dialog is anchored
     rather than centred. Include a BP61–BP64 pass: every shared element comes from the shell
     module, every screen's phone layout is a decision rather than a default, the design seam is
     used uniformly, and every open question is an anchor read by the one inspector with nothing
     visible on the screen (BP70). Include a BP71–BP72 pass over every inherited component the
     group renders: it is judged as part of the screen, not by who wrote it — and where the
     screen is the way into an account, against BP72's list. Include a BP74–BP75 pass, which is
     the only one that cannot be done from a single file: for every route reached by a link from
     another route in this group, list both screens' contents side by side and say what is left
     after the parent is subtracted — a couple of facts and one control is a finding, whatever
     the route is named — and flag every link whose destination's whole message is that there is
     nothing to do there. Include a
     four-states pass too (the host project's own definition if it has one, otherwise loading /
     empty / error / success): all four present, every conditional message's space reserved, no
     raw server error rendered.
   - _Spec-fidelity reviewer_: inputs = the same directories, `.cache/mock-ui/facts.md`, and the
     PRD + data model. Diff the built UI against the spec in **both** directions — every
     required fact present, nothing unrequested invented — and treat a fact the spec never
     stated as a gap to report, not a defect to fix. Findings to
     `.cache/mock-ui/fidelity-<group>-r<R>.md`, citing BP52 + file + line + the passage.
   - _Fresh-eyes reviewer_ (BP69, BP73): inputs = the group's routes and the components they
     render, and the not-in-scope list from `.cache/mock-ui/facts.md`. **Deliberately not given
     `reference/conventions.md` and not given the PRD** — a rule list turns this into a third
     scorer, and the spec re-anchors it to what someone remembered to write down, which is the
     blind spot it exists to cover. Its question is not "is what is here correct" but "what does
     a shipped version of this screen not have". For every route: name the screen's genre in a
     few words (a sign-in, a checkout, a list with filters, a record detail, a destructive
     confirm), then walk it as a user _in the source_ — press Enter in the form, arrive already
     signed in, arrive with the list empty, get it wrong twice, come back on a phone — and say
     what is missing. Bounds, or it becomes a slop generator: it may propose FURNITURE only
     (controls, states, affordances, destinations, ordinary copy — BP69's category), never a
     domain fact, status, price rule or noun (BP52); nothing on the not-in-scope list; and a
     rationale it finds in a comment is not evidence (BP73) — a file that argues its own
     exemption is the one to look at hardest. Findings to
     `.cache/mock-ui/shape-<group>-r<R>.md`. **Every route gets its own row whether or not it
     has findings** — that is what stops a screen being skimmed — but a defect shared by
     several routes is stated ONCE as a pattern with the routes listed under it, never repeated
     per route. One undecided thing (where a form lands after it saves) restated on five screens
     reads as five problems, inflates the count, and sends five fixers at one decision. Each
     finding cites file + line + the genre the comparison was against, and carries a severity so
     the round can be triaged rather than swallowed whole.
   - All three return: PASS/FAIL, finding count, failing rule ids, and the files named — at most
     15 lines each. PASS with zero findings is a real verdict; do not manufacture findings.
2. A group is done when all three reviewers return PASS with zero findings. **All findings
   resolved** — no partial credit.
3. **Merge before dispatching.** Groups are reviewed independently, so two of them routinely
   find the same defect in a file they share — the shell module, `src/lib/**`, the root layout.
   Dispatching per group sends two fixers at one file in one round, and the second overwrites or
   conflicts with the first. So: collect the round's findings across ALL groups first, merge the
   ones naming the same file, and give every shared file exactly ONE fixer for the round,
   carrying every group's findings for it. Groups are the unit of REVIEW, never the unit of
   repair.
4. **Fixers** — one fixer subagent per file in the merged list, dispatched in one message.
   Inputs = the findings for that file (from whichever review files named it) plus that single
   file path; task = apply them; return = the path and new line count, at most 2 lines. A finding
   spanning files goes to one fixer owning exactly those files. A fresh-eyes finding names what
   is MISSING, not how to build it: where the missing thing is a decision the mock owes rather
   than behaviour the mock can have — where a form lands after saving, when the backend cannot
   save — the fixer makes the decision and renders it, and does not try to wire up a mock
   accessor to make it real.

   **One exception, and it is not a fixer's to make:** a fresh-eyes finding that needs a NEW
   ROUTE — a password reset, a sign-up screen, a confirmation step — is an inventory defect, and
   the inventory was approved by the user at the Phase 1 checkpoint. It goes to Phase 8 as a
   question, never into a fixer's hands. What a fixer may do on that screen is make the gap
   visible where it is felt (BP64): the control present and inert, with the question anchored.

After round 2, stop looping and carry unresolved rule ids + files into Phase 8.

## Phase 7 — Mechanical verification (script)

Run `bash .claude/skills/mock-ui/scripts/verify_pages.sh`. It prints one PASS/FAIL line per
check and writes full output to `.cache/mock-ui/verify-last.log`: the host project's own
verification gate (whatever it wires up for lint, typecheck, tests and build), its
plan-of-record check if it has one, the web build, the route-file inventory, the
shell-conformance scan (one `<h1>` owner, one annotation module, root error files), the
breakpoint scan, and the mechanical anti-pattern scan.

On a non-zero exit: dispatch one fixer per file or area the FAIL lines name — inputs =
`.cache/mock-ui/verify-last.log` plus that path, return ≤ 3 lines — then rerun the script once.
One repair round only; remaining FAIL lines go into Phase 8.

## Phase 8 — Report

At most 20 lines: the mode, routes built per group, the shell contract's headline decisions,
review rounds used and any unresolved rule ids, verify verdict, the spec gaps Phase 0 and the
fidelity reviewers surfaced plus the route-level findings the fresh-eyes reviewers raised
(questions for the user — the most valuable output of the run), and
two notes on what stays cheap: every token value is in `src/styles/theme.css`, so a re-theme is
a one-file edit with no page recode; and every open question is behind one flag in one module,
so seeing the layout as it will ship is flipping the flag, and deleting the annotations is
deleting one directory.

**Do not commit.** Hand back a working tree. Turning these screens into the real app is a
separate, later step this skill does not do — whatever process the host project uses to build
out a vertical slice owns the gates and the commit for each.
