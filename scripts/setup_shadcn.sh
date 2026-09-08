#!/usr/bin/env bash
# setup_shadcn.sh — idempotent toolkit setup for the mock-ui skill's Next.js app.
#
# This script never runs `shadcn init`. The app is assumed to already be an initialized shadcn
# project whose token VALUES live in src/styles/theme.css and whose `@theme inline` mapping
# lives in src/app/globals.css — a deliberate split (see reference/conventions.md, design
# finding 4). `init` rewrites globals.css whole and would undo that split silently, so a missing
# components.json is an error here rather than a thing to fix by initializing.
#
# Files under src/components/ui are the CLI's, never hand-edited (BP41) — customization goes
# in wrappers under src/components/<area>/.
#
# The Next.js app's root defaults to the repo root; set MOCK_UI_APP_DIR (relative to the repo
# root) if the app lives in a subdirectory, e.g. a monorepo package. The package manager is
# detected from a lockfile — pnpm-lock.yaml, yarn.lock, package-lock.json, in that order,
# falling back to npm — rather than assumed.
set -euo pipefail

# Repo root: this script lives at .claude/skills/mock-ui/scripts/, four directories below it.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$REPO_ROOT"

WEB="${MOCK_UI_APP_DIR:-.}"
INVENTORY=".cache/mock-ui/components.txt"

# Package manager: detected from a lockfile, checked in the app dir first and then the repo
# root (a monorepo's lockfile is usually at the root). Change PM directly below if this guesses
# wrong for your setup.
if [ -f "$WEB/pnpm-lock.yaml" ] || [ -f pnpm-lock.yaml ]; then
  PM=pnpm
elif [ -f "$WEB/yarn.lock" ] || [ -f yarn.lock ]; then
  PM=yarn
elif [ -f "$WEB/package-lock.json" ] || [ -f package-lock.json ]; then
  PM=npm
else
  PM=npm
fi

# The default add-list, used when Phase 1 wrote no inventory. It MUST match the
# "Component add-list" section of ../reference/pages.md.
DEFAULT_COMPONENTS=(alert badge button card checkbox dialog dropdown-menu input label select
  separator skeleton table tabs textarea)

if [ -f "$INVENTORY" ]; then
  # One registry name per line; blank lines and # comments ignored, so the inventory file
  # can carry its own notes.
  mapfile -t COMPONENTS < <(sed 's/#.*//' "$INVENTORY" | tr -s '[:space:]' '\n' | grep -v '^$')
  echo "add-list: ${#COMPONENTS[@]} components from $INVENTORY"
else
  COMPONENTS=("${DEFAULT_COMPONENTS[@]}")
  echo "add-list: $INVENTORY absent — using the ${#COMPONENTS[@]} defaults from reference/pages.md"
fi

# --- Check: this must already be an initialized shadcn project on Tailwind 4.
if [ ! -f "$WEB/components.json" ]; then
  echo "ERROR: $WEB/components.json missing — the Next.js app is not an initialized shadcn" >&2
  echo "       project. Do NOT run 'shadcn init' to fix it: init rewrites" >&2
  echo "       src/app/globals.css and destroys the theme.css / globals.css token split." >&2
  echo "       Read the project's own design-system setup notes first, if it has any." >&2
  exit 1
fi
if ! node -e "
  const p = require('./${WEB}/package.json');
  const v = (p.devDependencies && p.devDependencies.tailwindcss) || (p.dependencies && p.dependencies.tailwindcss) || '';
  process.exit(/^[\^~]?4/.test(v) ? 0 : 1);
"; then
  echo "ERROR: tailwindcss ^4 not found in $WEB/package.json." >&2
  exit 1
fi

# --- Add components — only those whose generated file is missing. `--overwrite` is passed
# for the ADD PAYLOAD's sake, not to re-add present components: a missing component's payload
# can include registry dependencies whose files already exist, and without the flag the CLI
# blocks on an interactive overwrite prompt that piped input cannot answer. Refreshing those
# files to registry state is safe BECAUSE of BP41 — they are the CLI's output, never
# hand-edited, and a project's own plan-of-record mechanism, if it has one, deliberately does
# not claim them either. To force a fresh copy of one component, delete its file and re-run.
MISSING=()
for c in "${COMPONENTS[@]}"; do
  # Registry names map 1:1 to generated kebab-case filenames (button -> button.tsx).
  if [ ! -f "$WEB/src/components/ui/${c}.tsx" ]; then
    MISSING+=("$c")
  fi
done
if [ "${#MISSING[@]}" -eq 0 ]; then
  echo "OK: all ${#COMPONENTS[@]} components already present in $WEB/src/components/ui."
else
  ADD_OK=0
  case "$PM" in
    pnpm) (cd "$WEB" && pnpm dlx shadcn@latest add --yes --overwrite "${MISSING[@]}") && ADD_OK=1 || ADD_OK=0 ;;
    yarn) (cd "$WEB" && yarn dlx shadcn@latest add --yes --overwrite "${MISSING[@]}") && ADD_OK=1 || ADD_OK=0 ;;
    npm)  (cd "$WEB" && npx --yes shadcn@latest add --yes --overwrite "${MISSING[@]}") && ADD_OK=1 || ADD_OK=0 ;;
  esac
  if [ "$ADD_OK" -ne 1 ]; then
    echo "ERROR: '$PM ... shadcn@latest add' failed. Check network access and that every" >&2
    echo "       name in the add-list is a real registry name (see reference/pages.md)." >&2
    exit 3
  fi
  # The registry ships its own formatting; reconcile it with the project's prettier config so
  # generated files are not a perpetual diff.
  case "$PM" in
    pnpm) pnpm exec prettier --write "$WEB/src/components/ui" --ignore-path .prettierignore >/dev/null 2>&1 || true ;;
    yarn) yarn prettier --write "$WEB/src/components/ui" --ignore-path .prettierignore >/dev/null 2>&1 || true ;;
    npm)  npx --yes prettier --write "$WEB/src/components/ui" --ignore-path .prettierignore >/dev/null 2>&1 || true ;;
  esac
fi

# --- server-only: BP3's build-time guarantee that mock-data never reaches a client bundle.
# Idempotent — skipped once the dependency is declared.
if ! node -e "
  const p = require('./${WEB}/package.json');
  process.exit((p.dependencies && p.dependencies['server-only']) || (p.devDependencies && p.devDependencies['server-only']) ? 0 : 1);
"; then
  ADD_DEP_OK=0
  case "$PM" in
    pnpm) (cd "$WEB" && pnpm add server-only) && ADD_DEP_OK=1 || ADD_DEP_OK=0 ;;
    yarn) (cd "$WEB" && yarn add server-only) && ADD_DEP_OK=1 || ADD_DEP_OK=0 ;;
    npm)  (cd "$WEB" && npm install server-only) && ADD_DEP_OK=1 || ADD_DEP_OK=0 ;;
  esac
  if [ "$ADD_DEP_OK" -ne 1 ]; then
    echo "ERROR: '$PM add server-only' (run from $WEB) failed — BP3 cannot compile" >&2
    echo "       without it. Check network access and retry." >&2
    exit 4
  fi
fi

# --- Post-conditions.
if [ ! -f "$WEB/src/lib/utils.ts" ]; then
  echo "ERROR: $WEB/src/lib/utils.ts missing — the cn() helper (BP39) is unavailable." >&2
  exit 5
fi
if [ ! -d "$WEB/src/components/ui" ]; then
  echo "ERROR: $WEB/src/components/ui/ missing — no primitives were generated." >&2
  exit 6
fi

# --- The token split (design finding 4). `shadcn add` appends BOTH a mapping line and a
# `:root`/`.dark` value block to globals.css when a component needs new tokens. The mapping
# line belongs there; the values do not — they land AFTER the @import of theme.css and win on
# cascade order, so the file you edit afterwards is the one that does nothing. globals.css
# holds no token block at all, which makes this a presence check rather than a diff.
if grep -nE '^[[:space:]]*(:root|\.dark)[[:space:]]*\{' "$WEB/src/app/globals.css"; then
  echo "ERROR: 'shadcn add' wrote a token block into $WEB/src/app/globals.css (lines above)." >&2
  echo "       Keep the '@theme inline' mapping lines there, move every --token VALUE down" >&2
  echo "       into $WEB/src/styles/theme.css under BOTH :root and .dark, delete the block," >&2
  echo "       then re-run. src/styles/theme.test.ts checks the half of this it can see, if" >&2
  echo "       the project has a test like it." >&2
  exit 7
fi

echo "OK: toolkit ready — $(ls "$WEB/src/components/ui" | wc -l) files in $WEB/src/components/ui," \
  "server-only present, globals.css token split intact."
