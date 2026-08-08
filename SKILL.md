---
name: ui-mock
description: Builds the full set of mock Next.js pages for this app — shadcn/ui setup, typed mock data, and every route in the (public)/(customer)/(admin) groups — then runs a per-group review loop and mechanical verification. Use when the user says "ui mock", "mock pages", "mock up the screens", "scaffold the UI", or "build the pages".
---

# ui-mock — orchestrator

Thin orchestrator. All domain detail lives in the reference files; every dispatch below names
input paths and an output destination, never content. Keep only a manifest in this turn:
one line per artifact or dispatch result (path + line count), at most 40 lines total.

Reference files (read by subagents, not by this orchestrating turn):

- `.claude/skills/ui-mock/reference/pages.md` — full route inventory per group: purpose,
  shadcn components, mock data, group-level extras, component add-list.
- `.claude/skills/ui-mock/reference/conventions.md` — design findings 1–5, BP1–BP52,
  AP1–AP32, Next 16 docs pointers. Doubles as the reflection-loop review checklist.

Source-of-truth docs (the business spec; reference files describe structure only):

- the newest `docs/<date>-setup/` PRD (`NN-prd.html`) and data model (`NN-data-model.html`).
  Every domain fact — names, fields, prices, currency, statuses, visibility, scope — comes
  from these, per BP52. `.cache/ui-mock/facts.md` is their per-run distillation (Phase 0).

## Phase 0 — Ground truth (subagent)

Dispatch one subagent:

- Inputs (paths): the newest `docs/<date>-setup/` PRD and data-model HTML files, and
  `.claude/skills/ui-mock/reference/pages.md` (Domain & brand section, for placeholders
  the PRD lacks, e.g. the brand name).
- Task: write `.cache/ui-mock/facts.md` — the compact fact sheet later agents build from:
  brand/site name; currency, price display and tax rule; timezone/locale; per-entity
  column lists for every capture form and displayed record (copied from the data model,
  including nullability pairings); run delivery rules; visibility rules (who sees what,
  when); and the PRD's not-in-scope list verbatim.
- Return: the file path, its line count, and the headline facts (brand, currency,
  timezone) — at most 8 lines.

## Phase 1 — Toolkit setup (script)

Run `bash .claude/skills/ui-mock/scripts/setup_shadcn.sh`. Idempotent: verifies Tailwind 4;
on first run (no `components.json`) removes the create-next-app scaffold (default
`src/app/page.tsx`, demo `public/` svgs) and normalizes the layout's font variables to the
shadcn names; runs `shadcn init` only on that first run (this rewrites `globals.css` to the
token pattern — intended); adds the components the inventory needs; reconciles the
globals.css font wiring; verifies the results.
On non-zero exit, stop and report the script's ERROR line to the user.

## Phase 2 — Mock data (subagent)

Dispatch one subagent:

- Inputs (paths): `.claude/skills/ui-mock/reference/pages.md`,
  `.claude/skills/ui-mock/reference/conventions.md` (BP47–BP49, BP52 and design finding 5
  govern this phase), `.cache/ui-mock/facts.md`, and the source PRD + data-model files.
- Task: write `src/lib/types.ts` (all domain interfaces) and `src/lib/mock-data.ts` (single
  module, starts with `import 'server-only'`, async accessor functions only, edge-state
  records per BP49 so every UI state in pages.md is demonstrable). Structure comes from
  pages.md; every domain fact comes from facts.md and the source docs — interfaces mirror
  the data model's columns (BP52); when the spec is silent, flag the gap in the return
  instead of inventing.
- Return: each file written with its line count — at most 6 lines.

## Phase 3 — Three group agents (one message)

After Phase 2's return arrives, dispatch three subagents **in a single message** — one each
for `(public)`, `(customer)`, `(admin)`. Each dispatch:

- Inputs (paths): `.claude/skills/ui-mock/reference/pages.md` (its group's section),
  `.claude/skills/ui-mock/reference/conventions.md`, `src/lib/types.ts`,
  `src/lib/mock-data.ts`, `.cache/ui-mock/facts.md`, and the source PRD + data-model
  files. Structure from pages.md; domain facts from facts.md and the source docs (BP52) —
  form fields mirror the entity's columns; unspecified facts get flagged, not invented.
- Task: build every route of its group under `src/app/(<group>)/` — page.tsx, group
  layout.tsx/loading.tsx/error.tsx, not-found.tsx and actions.ts where pages.md says so —
  plus feature components under `src/components/<area>/`. The `(public)` agent also verifies
  no `src/app/page.tsx` remains (Phase 1 removes the scaffold one; two pages resolving to
  `/` is a build error — pages.md, Shared structure).
- Return: files written with line counts — at most 12 lines (group related files onto one
  line if needed to stay under the cap).

## Phase 4 — Reflection loop (per group; all-must-pass; cap 2 rounds)

For round R = 1, then R = 2, over the groups not yet passed:

1. **Reviewers** — dispatch TWO reviewer subagents per remaining group, all in one message:
   - *Conventions reviewer*: inputs (paths) = `src/app/(<group>)/`, `src/components/<area>/`,
     and `.claude/skills/ui-mock/reference/conventions.md` (score against every BP/AP id,
     skipping items tagged `[scan]` — `verify_pages.sh` checks those mechanically). Output:
     findings to `.cache/ui-mock/review-<group>-r<R>.md`, each citing rule id + file + line.
   - *Spec-fidelity reviewer*: inputs (paths) = the same group dirs, `.cache/ui-mock/facts.md`,
     and the source PRD + data-model files. Diff the built UI against the spec in BOTH
     directions: every required fact present (form fields vs entity columns, copy claims vs
     PRD rules) and nothing unrequested invented (features, fields, price lines the PRD
     excludes). Output: findings to `.cache/ui-mock/fidelity-<group>-r<R>.md`, each citing
     BP52 + file + line + the spec passage it violates.
   Both return: verdict PASS/FAIL, finding count, failing rule ids, and the files they
   name — at most 15 lines each. PASS with zero findings is a real, expected verdict — do
   not manufacture findings.
2. A group is done when BOTH its reviewers return PASS with 0 findings. Pass bar: **all
   findings resolved** — no partial credit.
3. **Fixers** — for each failing group, dispatch one fixer subagent per named file (one
   message per group, fixers in parallel). Each: inputs (paths) = whichever of
   `.cache/ui-mock/review-<group>-r<R>.md` / `.cache/ui-mock/fidelity-<group>-r<R>.md`
   named its file, plus that single file path; task = apply that file's findings; return =
   the file path and its new line count — at most 2 lines. A finding spanning multiple
   files goes to one fixer owning exactly those files.
4. Never read the review files in this orchestrating turn — route on the returned rule ids
   and file lists only.

After round 2, stop looping; carry any unresolved rule ids + files into Phase 6.

## Phase 5 — Mechanical verification (script)

Run `bash .claude/skills/ui-mock/scripts/verify_pages.sh`. It prints one PASS/FAIL line per
check and writes full command output to `.cache/ui-mock/verify-last.log`.

If it exits non-zero: dispatch one fixer subagent per file (or route-group area) that the
FAIL lines name — inputs (paths) = `.cache/ui-mock/verify-last.log` plus that file/area path;
return = files touched with line counts, at most 3 lines each. Then rerun the script once.
One repair round only; if it still fails, carry the remaining FAIL lines into Phase 6.

## Phase 6 — Report

Report to the user, at most 15 lines: routes built per group, review rounds used and any
unresolved rule ids + files, verify verdict, and the restyle note: all theming lives in
`src/app/globals.css` tokens — a restyle is a one-file edit, no page recode.
