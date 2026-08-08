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
- `.claude/skills/ui-mock/reference/conventions.md` — design findings 1–5, BP1–BP49,
  AP1–AP32, Next 16 docs pointers. Doubles as the reflection-loop review checklist.

## Phase 1 — Toolkit setup (script)

Run `bash .claude/skills/ui-mock/scripts/setup_shadcn.sh`. Idempotent: verifies Tailwind 4,
runs `shadcn init` only when `components.json` is missing (this rewrites `globals.css` to the
token pattern — intended), adds the components the inventory needs, verifies the results.
On non-zero exit, stop and report the script's ERROR line to the user.

## Phase 2 — Mock data (subagent)

Dispatch one subagent:

- Inputs (paths): `.claude/skills/ui-mock/reference/pages.md`,
  `.claude/skills/ui-mock/reference/conventions.md` (BP47–BP49 and design finding 5 govern
  this phase).
- Task: write `src/lib/types.ts` (all domain interfaces) and `src/lib/mock-data.ts` (single
  module, starts with `import 'server-only'`, async accessor functions only, edge-state
  records per BP49 so every UI state in pages.md is demonstrable).
- Return: each file written with its line count — at most 6 lines.

## Phase 3 — Three group agents (one message)

After Phase 2's return arrives, dispatch three subagents **in a single message** — one each
for `(public)`, `(customer)`, `(admin)`. Each dispatch:

- Inputs (paths): `.claude/skills/ui-mock/reference/pages.md` (its group's section),
  `.claude/skills/ui-mock/reference/conventions.md`, `src/lib/types.ts`,
  `src/lib/mock-data.ts`.
- Task: build every route of its group under `src/app/(<group>)/` — page.tsx, group
  layout.tsx/loading.tsx/error.tsx, not-found.tsx and actions.ts where pages.md says so —
  plus feature components under `src/components/<area>/`. The `(public)` agent also deletes
  the default `src/app/page.tsx` (pages.md, Shared structure).
- Return: files written with line counts — at most 12 lines (group related files onto one
  line if needed to stay under the cap).

## Phase 4 — Reflection loop (per group; all-must-pass; cap 2 rounds)

For round R = 1, then R = 2, over the groups not yet passed:

1. **Reviewers** — dispatch one reviewer subagent per remaining group, all in one message.
   Each: inputs (paths) = `src/app/(<group>)/`, `src/components/<area>/`, and
   `.claude/skills/ui-mock/reference/conventions.md` (score against every BP/AP id, skipping
   items tagged `[scan]` — `verify_pages.sh` checks those mechanically). Output: findings to
   `.cache/ui-mock/review-<group>-r<R>.md`, each finding citing rule id + file + line.
   Return: verdict PASS/FAIL, finding count, failing rule ids, and the files they name — at
   most 15 lines. PASS with zero findings is a real, expected verdict — do not manufacture
   findings.
2. A group returning PASS with 0 findings is done. Pass bar: **all findings resolved** —
   no partial credit.
3. **Fixers** — for each failing group, dispatch one fixer subagent per named file (one
   message per group, fixers in parallel). Each: inputs (paths) =
   `.cache/ui-mock/review-<group>-r<R>.md` plus its single file path; task = apply that
   file's findings; return = the file path and its new line count — at most 2 lines.
   A finding spanning multiple files goes to one fixer owning exactly those files.
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
