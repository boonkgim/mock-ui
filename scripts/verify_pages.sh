#!/usr/bin/env bash
# verify_pages.sh — mechanical verification for the ui-mock skill.
# Prints one PASS/FAIL line per check; full command output goes to the log so the
# orchestrator's context stays small (fixer subagents read the log by path).
# Exits non-zero if any required check fails.
set -uo pipefail
# No 'set -e': every check must run so the report is complete; failures are counted instead.

# Repo root: this script lives at .claude/skills/ui-mock/scripts/, four directories below it.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$REPO_ROOT"

# Full command output lands here (fixed path — SKILL.md Phase 5 dispatches fixers to read it).
LOG=".cache/ui-mock/verify-last.log"
mkdir -p .cache/ui-mock
: >"$LOG"

FAILURES=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILURES=$((FAILURES + 1)); }

# --- Check 1: every route's page.tsx exists.
# This list MUST match the route inventory in ../reference/pages.md exactly
# (route-group directories included). Update pages.md first, then this list.
PAGES=(
  "src/app/(public)/page.tsx"
  "src/app/(public)/workshops/[slug]/page.tsx"
  "src/app/(public)/dates/page.tsx"
  "src/app/(public)/workshops/[slug]/waiting-list/page.tsx"
  "src/app/(public)/checkout/[runId]/page.tsx"
  "src/app/(public)/checkout/[runId]/confirmation/page.tsx"
  "src/app/(public)/bookings/[bookingId]/learner-details/page.tsx"
  "src/app/(public)/set-password/page.tsx"
  "src/app/(public)/login/page.tsx"
  "src/app/(customer)/account/bookings/page.tsx"
  "src/app/(customer)/account/bookings/past/page.tsx"
  "src/app/(customer)/account/credits/page.tsx"
  "src/app/(customer)/account/bookings/[bookingId]/cancel/page.tsx"
  "src/app/(admin)/admin/page.tsx"
  "src/app/(admin)/admin/workshops/page.tsx"
  "src/app/(admin)/admin/workshops/new/page.tsx"
  "src/app/(admin)/admin/workshops/[workshopId]/edit/page.tsx"
  "src/app/(admin)/admin/runs/new/page.tsx"
  "src/app/(admin)/admin/runs/[runId]/edit/page.tsx"
  "src/app/(admin)/admin/runs/[runId]/attendees/page.tsx"
  "src/app/(admin)/admin/cancellations/page.tsx"
  "src/app/(admin)/admin/export/page.tsx"
)
for p in "${PAGES[@]}"; do
  if [ -f "$p" ]; then pass "route page $p"; else fail "route page $p missing"; fi
done

# --- Check 2: root layout, group layout/loading/error files (pages.md "extras"),
# and the removal of the default root page (it would collide with (public)/page.tsx — BP20).
GROUP_FILES=(
  "src/app/layout.tsx"
  "src/app/(public)/layout.tsx"
  "src/app/(public)/loading.tsx"
  "src/app/(public)/error.tsx"
  "src/app/(customer)/layout.tsx"
  "src/app/(customer)/loading.tsx"
  "src/app/(customer)/error.tsx"
  "src/app/(admin)/layout.tsx"
  "src/app/(admin)/loading.tsx"
  "src/app/(admin)/error.tsx"
)
for f in "${GROUP_FILES[@]}"; do
  if [ -f "$f" ]; then pass "group file $f"; else fail "group file $f missing"; fi
done
if [ -f "src/app/page.tsx" ]; then
  fail "src/app/page.tsx still exists — collides with src/app/(public)/page.tsx at '/'"
else
  pass "default root page removed"
fi

# Runs a command, streams its output to $LOG only, records PASS/FAIL.
run_check() {
  local label="$1"
  shift
  echo "===== $label: $* =====" >>"$LOG"
  if "$@" >>"$LOG" 2>&1; then pass "$label"; else fail "$label (details: $LOG)"; fi
}

# --- Check 3: typegen BEFORE typecheck — PageProps/LayoutProps are GENERATED global
# types (design finding 2); tsc fails spuriously on every page if this hasn't run.
run_check "next typegen" npx next typegen

# --- Check 4/5: typecheck and build via package.json scripts (the project's own
# definitions, so this stays correct if the project changes its tsc/build flags).
run_check "typecheck (npm run typecheck)" npm run typecheck
run_check "build (npm run build)" npm run build

# --- Check 6: mechanical AI-anti-pattern scan (the [scan]-tagged AP rules in
# reference/conventions.md). Availability is probed first because the tool is a
# third-party npm package that may be unpublished, renamed, or unreachable offline —
# its absence must NOT hard-fail the run (the reflection loop still reviews the
# judgment-shaped rules; only the mechanical double-check is lost). WARN instead.
if npx --yes impeccable --help >>"$LOG" 2>&1; then
  run_check "impeccable detect src/" npx --yes impeccable detect src/
else
  echo "WARN: 'npx impeccable' unavailable (offline or package not resolvable) —" \
    "skipping mechanical AP-rule scan; [scan]-tagged rules in conventions.md were" \
    "not machine-checked this run."
fi

echo "----------------------------------------"
if [ "$FAILURES" -gt 0 ]; then
  echo "RESULT: $FAILURES check(s) failed. Full command output: $LOG"
  exit 1
fi
echo "RESULT: all checks passed."
