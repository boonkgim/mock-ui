#!/usr/bin/env bash
# verify_pages.sh — mechanical verification for the ui-mock skill.
# One PASS/FAIL line per check; full command output goes to the log so the orchestrator's
# context stays small (fixer subagents read the log by path). Exits non-zero on any failure.
set -uo pipefail
# No 'set -e': every check must run so the report is complete; failures are counted instead.

# Repo root: this script lives at .claude/skills/ui-mock/scripts/, four directories below it.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$REPO_ROOT"

LOG=".cache/ui-mock/verify-last.log"
ROUTES=".cache/ui-mock/routes.txt"
mkdir -p .cache/ui-mock
: >"$LOG"

FAILURES=0
pass() { echo "PASS: $1"; }
fail() {
  echo "FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

# Runs a command, streams its output to $LOG only, records PASS/FAIL.
run_check() {
  local label="$1"
  shift
  echo "===== $label: $* =====" >>"$LOG"
  if "$@" >>"$LOG" 2>&1; then pass "$label"; else fail "$label (details: $LOG)"; fi
}

# --- Check 1: every route in the run's inventory exists. The list is generated, not
# hard-coded here, because the product this scaffold holds is decided by the PRD — see
# ../reference/pages.md.
if [ ! -f "$ROUTES" ]; then
  echo "ERROR: $ROUTES missing — Phase 1 writes it. Nothing to verify against." >&2
  exit 2
fi
mapfile -t PAGES < <(sed 's/#.*//' "$ROUTES" | tr -d '\r' | sed '/^[[:space:]]*$/d')
if [ "${#PAGES[@]}" -eq 0 ]; then
  echo "ERROR: $ROUTES is empty — Phase 1 produced no routes." >&2
  exit 2
fi
for p in "${PAGES[@]}"; do
  if [ -f "$p" ]; then pass "route page $p"; else fail "route page $p missing"; fi
done

# --- Check 2: the root layout, and each group's shell files. The group set is derived from
# the routes themselves, so a new group is covered without editing this script.
if [ -f "apps/web/src/app/layout.tsx" ]; then
  pass "root layout apps/web/src/app/layout.tsx"
else
  fail "root layout apps/web/src/app/layout.tsx missing"
fi
mapfile -t GROUP_DIRS < <(printf '%s\n' "${PAGES[@]}" |
  grep -oE '^apps/web/src/app/\([^)]+\)' | sort -u)
for g in "${GROUP_DIRS[@]}"; do
  for f in layout.tsx loading.tsx error.tsx; do
    if [ -f "$g/$f" ]; then pass "group file $g/$f"; else fail "group file $g/$f missing"; fi
  done
done

# --- Check 3: no two pages resolve to '/'. A group page.tsx beside the scaffold's own
# src/app/page.tsx is a build error, and the ruling for it is written in the inventory (BP20,
# BP58) — this catches the case where the ruling was made but never executed.
if printf '%s\n' "${PAGES[@]}" | grep -qE '^apps/web/src/app/\([^)]+\)/page\.tsx$' &&
  [ -f "apps/web/src/app/page.tsx" ]; then
  fail "apps/web/src/app/page.tsx still exists — collides with the group page at '/'"
else
  pass "no duplicate route at '/'"
fi

# --- Check 4: the plan of record. A scaffold file the mock replaced needs either a plan
# update or a reasoned line in scripts/docs-check.ignore (BP58); this is where a silent
# deletion shows up.
run_check "docs:check (pnpm docs:check)" pnpm docs:check

# --- Checks 5-7: the repo-root gate. Root fans these out through turbo, which is the only
# tally that answers "is the workspace green". `test:unit` rather than `test`: the
# integration projects need local Postgres, and a mock does not commit — the full
# `pnpm lint && pnpm typecheck && pnpm test` gate belongs to the slice that does.
# codegen is a turbo dependency of all three, so `next typegen` needs no separate step
# (design finding 2).
run_check "lint (pnpm lint)" pnpm lint
run_check "typecheck (pnpm typecheck)" pnpm typecheck
run_check "unit tests (pnpm test:unit)" pnpm test:unit

# --- Check 8: the web build. It is what proves the route tree actually resolves — duplicate
# segments, bad dynamic params and client/server boundary violations surface here and
# nowhere earlier.
run_check "build (turbo build --filter @nanostore/web)" pnpm turbo run build --filter @nanostore/web

# --- Check 9: mechanical AI-anti-pattern scan (the [scan]-tagged AP rules). Availability is
# probed first: the tool is a third-party package that may be unpublished or unreachable
# offline, and its absence must not hard-fail the run — the reflection loop still reviews the
# judgment-shaped rules. The palette scan that used to live here is gone on purpose: BP42 is
# a lint rule in apps/web/eslint.config.mjs, and check 5 already runs it.
if npx --yes impeccable --help >>"$LOG" 2>&1; then
  run_check "impeccable detect apps/web/src" npx --yes impeccable detect apps/web/src
else
  echo "WARN: 'npx impeccable' unavailable (offline or not resolvable) — skipping the" \
    "mechanical AP-rule scan; [scan]-tagged rules were not machine-checked this run."
fi

# --- Check 10: BP54 copy density — a descriptive slot holding a paragraph. Literal strings
# only: interpolated content is legitimately long and is not matched, and the judgment half of
# BP54 (the same fact stated twice on one screen) stays with the reviewers.
echo "===== BP54 copy density: description literals over ~200 chars =====" >>"$LOG"
DENSITY_HITS="$(grep -rEn --include='*.tsx' \
  '<[A-Za-z]*Description>[^<{]{200,}<|description="[^"]{200,}"' apps/web/src || true)"
if [ -n "$DENSITY_HITS" ]; then
  printf '%s\n' "$DENSITY_HITS" >>"$LOG"
  fail "BP54 copy density: paragraph-length description literal in $(printf '%s\n' \
    "$DENSITY_HITS" | cut -d: -f1 | sort -u | tr '\n' ' ')(details: $LOG)"
else
  pass "BP54 copy density (no paragraph-length description literals)"
fi

echo "----------------------------------------"
if [ "$FAILURES" -gt 0 ]; then
  echo "RESULT: $FAILURES check(s) failed. Full command output: $LOG"
  exit 1
fi
echo "RESULT: all checks passed."
