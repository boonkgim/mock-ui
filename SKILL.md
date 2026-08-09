---
name: ui-mock
description: Build the whole app's screens in apps/web as mock pages — route inventory derived from the PRD, typed mock data behind async accessors, every route in its group — then review each group and verify mechanically. Use when the user says "ui mock", "mock pages", "mock up the screens", "scaffold the UI", or "build the pages". It writes no GraphQL and never commits; the vertical slices replace its mock data layer by layer.
---

# ui-mock — orchestrator

A mock of every screen, built once, before the slices. It sits after `db-design` and before
`feature`: the PRD says what the product must do, the data model says what may be true, and
this makes both visible as pages a person can click. The pages survive; `src/lib/mock-data.ts`
does not — each vertical slice replaces one accessor with a `graphqlFetch` call, and the
component above it never learns which it got.

**Why the mock is worth its own step.** A screen is where an unanswered question stops being
abstract: a form has to name every field, an empty list has to say what empty means, and a
price has to render in some currency. Finding those inside a slice means finding them with the
schema and the resolver already written. The skill's job is therefore as much to surface gaps
as to produce pages — anything the PRD is silent on gets **flagged, never invented** (BP52).

**What it does not do.** It writes no SDL, no resolvers, no schema, and no GraphQL operations.
It does not commit — the `feature` skill commits a slice, and a mock is not a slice. It does not
touch `apps/graphql`, `packages/db`, or `apps/web/src/generated/**`.

## Context discipline

Thin orchestrator. Every domain detail lives in the reference files, and every dispatch below
names input paths and an output destination, never content. Keep only a manifest in the
orchestrating turn: one line per artifact or dispatch result (path + line count), at most 40
lines total. Never read the review files — route on returned rule ids and file lists.

Reference files (read by subagents, not by this turn):

- `.claude/skills/ui-mock/reference/pages.md` — how the route inventory is derived and what it
  must contain: group structure, shared files, what is off-limits, the component add-list.
- `.claude/skills/ui-mock/reference/conventions.md` — design findings 1–5, BP1–BP60, AP1–AP32.
  Doubles as the reflection-loop checklist.

Project skills every subagent that writes UI must read: **`code-ui`** (how UI is written here —
the four states, messages, accessibility, layout that does not shift) and **`web`** (where files
live, the theme contract, the vendored shadcn checkout). Where they and this skill's checklist
disagree, **they win** — they are the repo's law, with lint rules and tests behind them.

Source of truth for every domain fact: the newest dated folder under `docs/` — its
`NN-prd.md` and, if it exists, `NN-data-model.md`. Never `docs/2026-08-08-setup`; that is
the scaffold's plan of record, and `pnpm docs:check` compares it against the working tree.

Run artifacts live in `.cache/ui-mock/` (gitignored).

## Phase 0 — Ground truth (subagent)

Dispatch one subagent:

- Inputs (paths): the newest `docs/<date>-*/` PRD and data-model files, and
  `.claude/skills/ui-mock/reference/pages.md` (Domain & brand section).
- Task: write `.cache/ui-mock/facts.md` — the fact sheet later agents build from: brand/site
  name; currency, price display and tax rule; timezone/locale; the audiences the product has;
  per-entity column lists for every capture form and displayed record (from the data model,
  nullability pairings included); state machines and who may move what; visibility rules; and
  the PRD's not-in-scope list verbatim. Anything the PRD leaves open is listed under an
  explicit **Gaps** heading rather than resolved.
- Return: the file path, its line count, the headline facts (brand, currency, timezone), and
  the gap count — at most 8 lines.

If there is no PRD, stop and say so: this skill mocks a specified product, and inventing the
specification is `brief-to-prd`'s job, not a side effect of drawing screens.

## Phase 1 — Route inventory (subagent, then a checkpoint)

Dispatch one subagent:

- Inputs (paths): `.cache/ui-mock/facts.md`, the PRD and data model,
  `.claude/skills/ui-mock/reference/pages.md`, and the current `apps/web/src/app/` tree.
- Task: derive this run's inventory and write three files:
  - `.cache/ui-mock/pages.md` — the route table per group, in the format pages.md specifies,
    plus each group's extras and the collision ruling for every route that already exists.
  - `.cache/ui-mock/routes.txt` — one repo-relative page file path per line (verification reads
    this, so it is the inventory's machine half and must not drift from the table).
  - `.cache/ui-mock/components.txt` — the shadcn registry names the inventory needs, one per
    line, starting from pages.md's default list.
- Return: group names with route counts, the collision rulings, and any registry name added
  beyond the default list — at most 15 lines.

**Then stop and show the user the route list** — one line per route, grouped — together with
the collisions and Phase 0's gaps. The inventory is the one decision that is expensive to
discover wrong after twenty pages exist. Build only once it is confirmed.

## Phase 2 — Toolkit setup (script)

Run `bash .claude/skills/ui-mock/scripts/setup_shadcn.sh`. It verifies the app is already a
shadcn project on Tailwind 4 (Slice 6 made it one — this script never runs `init`, because
init would rewrite `globals.css` and undo the token split), adds every component in
`components.txt` whose file is missing, installs `server-only` if absent, reformats the
generated files, and checks that `shadcn add` did not append a token block to `globals.css`.

On a non-zero exit, stop and report the script's ERROR line. The token-block failure in
particular has a fixed remedy, stated in the error: keep the `@theme inline` mapping line in
`globals.css`, move the values down into `src/styles/theme.css` — both schemes — and re-run.

## Phase 3 — Mock data (subagent)

Dispatch one subagent:

- Inputs (paths): `.cache/ui-mock/pages.md`, `.cache/ui-mock/facts.md`,
  `.claude/skills/ui-mock/reference/conventions.md` (BP47–BP49, BP52, BP57 and design finding 5
  govern this phase), and the PRD + data model.
- Task: write `apps/web/src/lib/types.ts` (the domain interfaces) and
  `apps/web/src/lib/mock-data.ts` (one module, first line `import "server-only"`, async accessor
  functions only, edge-state records so every UI state in the inventory is demonstrable).
  Interfaces mirror the data model's columns; **never import `@nanostore/db`** — web reaches
  data through the API, and the accessor's future is a `graphqlFetch` call, not a query.
- Return: each file with its line count — at most 6 lines.

## Phase 4 — One agent per group (single message)

After Phase 3 returns, dispatch one subagent per group from the inventory, **all in one
message**. Each dispatch:

- Inputs (paths): `.cache/ui-mock/pages.md` (its group's section), `.cache/ui-mock/facts.md`,
  `.claude/skills/ui-mock/reference/conventions.md`, the `code-ui` and `web` skills,
  `apps/web/src/lib/types.ts`, `apps/web/src/lib/mock-data.ts`, and the PRD + data model.
- Task: build every route of its group under `apps/web/src/app/(<group>)/` — page.tsx, the
  group's layout.tsx / loading.tsx / error.tsx, not-found.tsx and actions.ts where the
  inventory says so — plus feature components under `apps/web/src/components/<area>/`.
  Structure from the inventory; every domain fact from facts.md and the source docs (BP52).
- The agent owning the group that claims `/` also executes that route's collision ruling and
  appends the reasoned line to `scripts/docs-check.ignore` (BP58). Two pages resolving to `/`
  is a build error, and a silently deleted doc-owned file is drift.
- Return: files written with line counts — at most 12 lines, grouping related files onto one
  line if needed.

## Phase 5 — Reflection loop (per group; all-must-pass; cap 2 rounds)

For round R = 1, then R = 2, over the groups not yet passed:

1. **Reviewers** — two per remaining group, all dispatched in one message:
   - _Conventions reviewer_: inputs = `apps/web/src/app/(<group>)/`, the group's components,
     `reference/conventions.md`, and the `code-ui` skill. Score every BP/AP id except those
     tagged `[scan]` (the script checks those). Findings to
     `.cache/ui-mock/review-<group>-r<R>.md`, each citing rule id + file + line. Include an
     explicit BP54–BP56 pass, screen by screen: each descriptive slot is one short sentence,
     dense facts change UI pattern rather than sentence length, no fact is stated twice on one
     screen, the heading is still true in every state, and a height-changing dialog is anchored
     rather than centred. Include a `code-ui` pass too: all four states present, every
     conditional message's space reserved, no raw server error rendered.
   - _Spec-fidelity reviewer_: inputs = the same directories, `.cache/ui-mock/facts.md`, and the
     PRD + data model. Diff the built UI against the spec in **both** directions — every
     required fact present, nothing unrequested invented — and treat a fact the spec never
     stated as a gap to report, not a defect to fix. Findings to
     `.cache/ui-mock/fidelity-<group>-r<R>.md`, citing BP52 + file + line + the passage.
   - Both return: PASS/FAIL, finding count, failing rule ids, and the files named — at most 15
     lines each. PASS with zero findings is a real verdict; do not manufacture findings.
2. A group is done when both reviewers return PASS with zero findings. **All findings resolved**
   — no partial credit.
3. **Fixers** — per failing group, one fixer subagent per named file, dispatched in one message
   per group. Inputs = whichever review file named it plus that single file path; task = apply
   that file's findings; return = the path and new line count, at most 2 lines. A finding
   spanning files goes to one fixer owning exactly those files.

After round 2, stop looping and carry unresolved rule ids + files into Phase 7.

## Phase 6 — Mechanical verification (script)

Run `bash .claude/skills/ui-mock/scripts/verify_pages.sh`. It prints one PASS/FAIL line per
check and writes full output to `.cache/ui-mock/verify-last.log`. It runs the repo-root gate —
`pnpm lint && pnpm typecheck && pnpm test` — because that is the only tally that answers "is the
workspace green", plus `pnpm docs:check`, the web build, the route-file inventory, and the
mechanical anti-pattern scan.

On a non-zero exit: dispatch one fixer per file or area the FAIL lines name — inputs =
`.cache/ui-mock/verify-last.log` plus that path, return ≤ 3 lines — then rerun the script once.
One repair round only; remaining FAIL lines go into Phase 7.

## Phase 7 — Report

At most 20 lines: routes built per group, review rounds used and any unresolved rule ids,
verify verdict, the spec gaps Phase 0 and the fidelity reviewers surfaced (these are questions
for the user, and the most valuable thing the run produces), and the restyle note — every token
value is in `src/styles/theme.css`, so a re-theme is a one-file edit with no page recode.

**Do not commit.** Hand back a working tree. The screens become real one vertical slice at a
time, and the `feature` skill owns the gates and the commit for each.
