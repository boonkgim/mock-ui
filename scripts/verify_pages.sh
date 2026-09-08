#!/usr/bin/env bash
# verify_pages.sh — mechanical verification for the mock-ui skill.
# One PASS/FAIL line per check; full command output goes to the log so the orchestrator's
# context stays small (fixer subagents read the log by path). Exits non-zero on any failure.
#
# The Next.js app's root defaults to the repo root; set MOCK_UI_APP_DIR (relative to the repo
# root) if the app lives in a subdirectory, e.g. a monorepo package. The package manager is
# detected from a lockfile — pnpm-lock.yaml, yarn.lock, package-lock.json, in that order,
# falling back to npm — rather than assumed.
set -uo pipefail
# No 'set -e': every check must run so the report is complete; failures are counted instead.

# Repo root: this script lives at .claude/skills/mock-ui/scripts/, four directories below it.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$REPO_ROOT"

LOG=".cache/mock-ui/verify-last.log"
ROUTES=".cache/mock-ui/routes.txt"
SHELL_CONTRACT=".cache/mock-ui/shell.md"

# APP_DIR normalizes to "" for the default (repo root == app root) so path/regex construction
# below never carries a spurious "./" prefix that would fail to match routes.txt entries, which
# are written repo-relative as if the Next.js app were the repo root.
APP_DIR="${MOCK_UI_APP_DIR:-.}"
if [ "$APP_DIR" = "." ]; then
  APP_PREFIX=""
else
  APP_PREFIX="$APP_DIR/"
fi
# The two directories the shell contract names (BP61, BP64). They are conventions of this
# skill's own output, not of the product: change them here if the contract ever moves them, and
# the checks below follow.
SRC="${APP_PREFIX}src"
SHELL_DIR="$SRC/components/shell"
MOCK_DIR="$SRC/components/mock"
mkdir -p .cache/mock-ui
: >"$LOG"

# Package manager: detected from a lockfile, checked in the app dir first and then the repo
# root (a monorepo's lockfile is usually at the root). Change PM directly below if this guesses
# wrong for your setup.
if [ -f "${APP_PREFIX}pnpm-lock.yaml" ] || [ -f pnpm-lock.yaml ]; then
  PM=pnpm
elif [ -f "${APP_PREFIX}yarn.lock" ] || [ -f yarn.lock ]; then
  PM=yarn
elif [ -f "${APP_PREFIX}package-lock.json" ] || [ -f package-lock.json ]; then
  PM=npm
else
  PM=npm
fi
pm_run() {
  case "$PM" in
    pnpm) pnpm run "$@" ;;
    yarn) yarn run "$@" ;;
    npm)  npm run "$@" ;;
  esac
}

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
# hard-coded here, because the product this app holds is decided by the PRD — see
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
if [ -f "$SRC/app/layout.tsx" ]; then
  pass "root layout $SRC/app/layout.tsx"
else
  fail "root layout $SRC/app/layout.tsx missing"
fi
mapfile -t GROUP_DIRS < <(printf '%s\n' "${PAGES[@]}" |
  grep -oE "^${SRC}/app/\([^)]+\)" | sort -u)
for g in "${GROUP_DIRS[@]}"; do
  for f in layout.tsx loading.tsx error.tsx; do
    if [ -f "$g/$f" ]; then pass "group file $g/$f"; else fail "group file $g/$f missing"; fi
  done
done

# --- Check 3: no two pages resolve to '/'. A group page.tsx beside the scaffold's own
# src/app/page.tsx is a build error, and the ruling for it is written in the inventory (BP20,
# BP58) — this catches the case where the ruling was made but never executed.
if printf '%s\n' "${PAGES[@]}" | grep -qE "^${SRC}/app/\([^)]+\)/page\.tsx$" &&
  [ -f "$SRC/app/page.tsx" ]; then
  fail "$SRC/app/page.tsx still exists — collides with the group page at '/'"
else
  pass "no duplicate route at '/'"
fi

# --- Check 4: the host project's own plan-of-record check, if it has one. Some projects track
# a document that asserts against the file tree (a docs-check-style script, a scaffold manifest)
# and fail their own gate on drift; BP58 is the rule for what a mock does when it touches a file
# that document claims. This check runs the project's own script if declared, and is a no-op
# otherwise — nothing here assumes such a mechanism exists.
if node -e "process.exit((require('./${APP_PREFIX}package.json').scripts||{})['docs:check']?0:1)" 2>/dev/null; then
  run_check "plan-of-record check ($PM run docs:check)" pm_run docs:check
else
  echo "WARN: no 'docs:check' script in package.json — skipping the plan-of-record check" \
    "(BP58 applies only if the host project has this kind of mechanism)." | tee -a "$LOG"
fi

# --- Checks 5-7: the host project's own verification gate — whatever it wires up for lint,
# typecheck, tests and build. Run through its own package.json scripts, so this works whether
# the tooling behind them is a monorepo task runner, a plain tsc/eslint/test-runner chain, or
# anything else. Prefer a "test:unit" script over "test" if the project defines one:
# integration-style tests often need infrastructure (a database, external services) this run
# does not have, and a mock does not commit — the full gate belongs to whatever slice later
# makes the screen real.
TEST_SCRIPT="test"
if node -e "process.exit((require('./${APP_PREFIX}package.json').scripts||{})['test:unit']?0:1)" 2>/dev/null; then
  TEST_SCRIPT="test:unit"
fi
run_check "lint ($PM run lint)" pm_run lint
run_check "typecheck ($PM run typecheck)" pm_run typecheck
run_check "unit tests ($PM run $TEST_SCRIPT)" pm_run "$TEST_SCRIPT"

# --- Check 8: the build. It is what proves the route tree actually resolves — duplicate
# segments, bad dynamic params and client/server boundary violations surface here and nowhere
# earlier.
run_check "build ($PM run build)" pm_run build

# --- Check 9: mechanical AI-anti-pattern scan (the [scan]-tagged AP rules). Availability is
# probed first: the tool is a third-party package that may be unpublished or unreachable
# offline, and its absence must not hard-fail the run — the review loop still reviews the
# judgment-shaped rules. The palette scan that used to live here is gone on purpose: BP42 is
# meant to be a lint rule in the app's eslint config, and check 5 already runs it if so.
if npx --yes impeccable --help >>"$LOG" 2>&1; then
  run_check "impeccable detect $SRC" npx --yes impeccable detect "$SRC"
else
  echo "WARN: 'npx impeccable' unavailable (offline or not resolvable) — skipping the" \
    "mechanical AP-rule scan; [scan]-tagged rules were not machine-checked this run."
fi

# --- Check 10: BP54 copy density — a descriptive slot holding a paragraph. Literal strings
# only: interpolated content is legitimately long and is not matched, and the judgment half of
# BP54 (the same fact stated twice on one screen) stays with the reviewers.
echo "===== BP54 copy density: description literals over ~200 chars =====" >>"$LOG"
DENSITY_HITS="$(grep -rEn --include='*.tsx' \
  '<[A-Za-z]*Description>[^<{]{200,}<|description="[^"]{200,}"' "$SRC" || true)"
if [ -n "$DENSITY_HITS" ]; then
  printf '%s\n' "$DENSITY_HITS" >>"$LOG"
  fail "BP54 copy density: paragraph-length description literal in $(printf '%s\n' \
    "$DENSITY_HITS" | cut -d: -f1 | sort -u | tr '\n' ' ')(details: $LOG)"
else
  pass "BP54 copy density (no paragraph-length description literals)"
fi


# --- Check 11: the shell contract exists. Phase 1 writes it and Phase 4 builds from it; a run
# without one built three headers that happen to differ, and nothing downstream can tell.
if [ -f "$SHELL_CONTRACT" ]; then
  pass "shell contract $SHELL_CONTRACT"
else
  fail "shell contract $SHELL_CONTRACT missing — Phase 1 writes it (BP61)"
fi

# --- Check 12: BP61 — exactly one component owns <h1>. This is the cheapest possible proof that
# every area's page heading is the same element with the same treatment: if a second file can
# render an <h1>, two areas can drift and no per-group review will see it.
H1_FILES="$(grep -rln --include='*.tsx' '<h1' "$SRC/app" "$SRC/components" 2>/dev/null |
  grep -v "^$SHELL_DIR/" || true)"
if [ -n "$H1_FILES" ]; then
  printf '===== BP61 <h1> outside the shell module =====\n%s\n' "$H1_FILES" >>"$LOG"
  fail "BP61 <h1> outside $SHELL_DIR: $(printf '%s' "$H1_FILES" | tr '\n' ' ')"
else
  pass "BP61 one <h1> owner (in $SHELL_DIR)"
fi

# --- Check 13: BP67 — the two root fallbacks. Neither is reachable by clicking, so neither gets
# noticed missing until a visitor finds one.
for f in not-found.tsx global-error.tsx; do
  if [ -f "$SRC/app/$f" ]; then pass "BP67 root $f"; else fail "BP67 $SRC/app/$f missing"; fi
done

# --- Check 14: BP64 — the mock's annotations live in one module behind one flag. A second
# per-area copy is how three of them appeared last time, and each one looked fine in its own
# group's review.
if [ -d "$MOCK_DIR" ]; then
  ANNOTATION_DUPES="$(grep -rlE --include='*.tsx' 'function (GapNote|SpecNote|SpecNotes|SpecGap|SpecAnchor|SpecInspector)' \
    "$SRC/app" "$SRC/components" 2>/dev/null | grep -v "^$MOCK_DIR/" || true)"
  if [ -n "$ANNOTATION_DUPES" ]; then
    printf '===== BP64 annotation components outside the mock module =====\n%s\n' \
      "$ANNOTATION_DUPES" >>"$LOG"
    fail "BP64 annotation component outside $MOCK_DIR: $(printf '%s' "$ANNOTATION_DUPES" | tr '\n' ' ')"
  else
    pass "BP64 one annotation module ($MOCK_DIR)"
  fi
else
  pass "BP64 no annotation module (the run found no gaps)"
fi

# --- Check 14b: BP70 — open questions never render as text on a screen. The failure this
# catches is the mock becoming untestable: a page covered in editorial asides cannot be put in
# front of a person, and every layout judgement they give is about a page that will never ship.
# Two signals, both cheap: the annotation module must export an inspector that some layout
# mounts, and no screen outside the module may print the words a note used to be introduced by.
if [ -d "$MOCK_DIR" ]; then
  echo "===== BP70 inspector mounted, no on-screen question text =====" >>"$LOG"
  BP70_FAIL=""
  grep -rqE 'function (SpecInspector|GapInspector|OpenQuestions)' "$MOCK_DIR" 2>/dev/null ||
    BP70_FAIL="$BP70_FAIL no-inspector-in-$MOCK_DIR"
  grep -rqE '<(SpecInspector|GapInspector|OpenQuestions)\b' --include='*.tsx' "$SRC/app" 2>/dev/null ||
    BP70_FAIL="$BP70_FAIL inspector-never-mounted"
  QUESTION_TEXT="$(grep -rlE --include='*.tsx' '>[[:space:]]*(Open question|Gap [0-9]+:|Question [0-9]+\.)' \
    "$SRC/app" "$SRC/components" 2>/dev/null | grep -v "^$MOCK_DIR/" || true)"
  [ -n "$QUESTION_TEXT" ] && BP70_FAIL="$BP70_FAIL $QUESTION_TEXT"
  if [ -n "$BP70_FAIL" ]; then
    printf '%s\n' $BP70_FAIL >>"$LOG"
    fail "BP70 open questions on screen or no inspector:$BP70_FAIL"
  else
    pass "BP70 questions behind the inspector, none on screen"
  fi
fi

# --- Check 15: BP62 — a screen that lays out columns or renders a table and carries no
# breakpoint anywhere has not decided its phone layout; it inherited one. Two exemptions, both
# because the decision is made elsewhere rather than skipped: files under components/ui are the
# vendored registry (BP41), and a file that renders the shell's table wrapper has taken that
# wrapper's phone behaviour deliberately. Everything else states its own.
echo "===== BP62 files with columns or a table and no breakpoint =====" >>"$LOG"
NO_BP=""
while IFS= read -r f; do
  grep -qE '\b(sm|md|lg|xl|2xl):' "$f" && continue
  grep -q 'components/shell/data-table' "$f" && continue
  NO_BP="$NO_BP $f"
done < <(grep -rlE 'grid-cols-|<Table' --include='*.tsx' "$SRC/app" "$SRC/components" 2>/dev/null |
  grep -v "^$SRC/components/ui/" || true)
if [ -n "$NO_BP" ]; then
  printf '%s\n' $NO_BP >>"$LOG"
  fail "BP62 no breakpoint in:$NO_BP"
else
  pass "BP62 every columned/tabular screen carries a breakpoint"
fi

# --- Check 16: BP23/BP27 — a form is a `<form>`, and a credential field carries its autofill
# token. Both failures are invisible on screen and invisible in a click-through review: a panel
# of onClick buttons looks exactly like a form until someone presses Enter, and a password field
# with no autocomplete is filled by heuristics often enough to look fine while a password manager
# is still unable to tell a credential being entered from one being chosen. components/ui is the
# vendored registry (BP41) and owns neither decision.
echo "===== BP23 inputs outside a form / BP27 credential field without autoComplete =====" >>"$LOG"
FORMLESS=""
while IFS= read -r f; do
  grep -q '<form' "$f" || FORMLESS="$FORMLESS $f"
done < <(grep -rl '<Input' --include='*.tsx' "$SRC/app" "$SRC/components" 2>/dev/null |
  grep -v "^$SRC/components/ui/" || true)
NO_AC=""
while IFS= read -r f; do
  grep -q 'autoComplete' "$f" || NO_AC="$NO_AC $f"
done < <(grep -rlE 'type="(password|email)"' --include='*.tsx' "$SRC/app" "$SRC/components" 2>/dev/null |
  grep -v "^$SRC/components/ui/" || true)
if [ -n "$FORMLESS" ] || [ -n "$NO_AC" ]; then
  printf '%s\n' $FORMLESS $NO_AC >>"$LOG"
  [ -n "$FORMLESS" ] && fail "BP23 <Input> with no <form> in:$FORMLESS"
  [ -n "$NO_AC" ] && fail "BP27 email/password field with no autoComplete in:$NO_AC"
else
  pass "BP23/BP27 every input is in a form and every credential field is autofillable"
fi

# --- Check 17: BP51 — a route-driven dialog derives its open state from the URL. The failure it
# catches is the one the shape hides best: a slot the current URL no longer matches keeps its
# last content on a soft navigation, so a dialog whose action navigates forward stays on screen
# over the page that replaced the one behind it. Nothing in the dialog's own file looks wrong,
# and no static review of it will say otherwise. The shell is found by the marker BP51 already
# requires (`data-modal-chrome`), and it must read the live pathname and never hold its own
# open state: `defaultOpen` on that shell IS the bug, spelled out.
# The marker is matched as a JSX attribute, which is the shell; the layout's leak guard
# mentions the same name inside a CSS selector (`[data-modal-chrome]`) and is not it.
SHELL_FILES="$(grep -rlE '(^|[[:space:]])data-modal-chrome([[:space:]>=]|$)' \
  --include='*.tsx' "$SRC" 2>/dev/null || true)"
if [ -n "$SHELL_FILES" ]; then
  echo "===== BP51 route-modal shell derives open from the pathname =====" >>"$LOG"
  BP51_FAIL=""
  while IFS= read -r f; do
    grep -q 'usePathname' "$f" || BP51_FAIL="$BP51_FAIL open-not-derived:$f"
    grep -q 'defaultOpen' "$f" && BP51_FAIL="$BP51_FAIL defaultOpen:$f"
  done <<<"$SHELL_FILES"
  if [ -n "$BP51_FAIL" ]; then
    printf '%s\n' $BP51_FAIL >>"$LOG"
    fail "BP51 route-modal shell holds its open state instead of deriving it:$BP51_FAIL"
  else
    pass "BP51 route-modal shell opens on the URL it stands for"
  fi
fi

# --- Check 18: BP76 — a route whose dynamic segment IS the credential. Both failures are
# invisible on screen and survive any click-through review: a page that renders perfectly is
# also perfectly indexable, and a token only leaks once someone else reads the log, the search
# result or the third party's referer. The segment name is the signal — a directory called
# `[accessToken]`/`[removalToken]` is a capability URL by construction, while `[bookingId]` is
# a row id behind a session. Two obligations follow, and both are greppable.
#
# The outbound-link half leans on BP21: internal navigation is `<Link>`, so a raw `<a>` in one
# of these files is by definition pointing at a host we do not control, and must send no
# referer. `mailto:`/`tel:` carry no referer and are exempt.
TOKEN_PAGES="$(find "$SRC/app" -type d -name '*[Tt]oken]' 2>/dev/null |
  while IFS= read -r d; do find "$d" -name 'page.tsx'; done || true)"
if [ -n "$TOKEN_PAGES" ]; then
  echo "===== BP76 capability-URL routes: noindex + no referer =====" >>"$LOG"
  BP76_FAIL=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    grep -q 'index: *false' "$f" || BP76_FAIL="$BP76_FAIL indexable:$f"
    # Raw <a> tags must each carry `rel` with noreferrer, or be a mailto:/tel: (which sends
    # none). Counted rather than grepped: the attribute is what suppresses the header, and a
    # file that merely mentions the word — a comment explaining the rule, say — has not applied
    # it. Matching `rel=` and not the bare word is the other half of the same point.
    A_TAGS="$(grep -cE '<a([[:space:]]|$)' "$f" || true)"
    SAFE="$(grep -cE 'rel=("[^"]*noreferrer|\{[^}]*noreferrer)' "$f" || true)"
    INERT="$(grep -cE 'href=("|\{")(mailto|tel):' "$f" || true)"
    if [ "${A_TAGS:-0}" -gt $((${SAFE:-0} + ${INERT:-0})) ]; then
      BP76_FAIL="$BP76_FAIL leaks-referer:$f"
    fi
  done <<<"$TOKEN_PAGES"
  if [ -n "$BP76_FAIL" ]; then
    printf '%s\n' $BP76_FAIL >>"$LOG"
    fail "BP76 capability URL exposes its token:$BP76_FAIL"
  else
    pass "BP76 every token-addressed route is unindexed and sends no referer"
  fi
fi

echo "----------------------------------------"
if [ "$FAILURES" -gt 0 ]; then
  echo "RESULT: $FAILURES check(s) failed. Full command output: $LOG"
  exit 1
fi
echo "RESULT: all checks passed."
