#!/usr/bin/env bash
# setup_shadcn.sh — idempotent toolkit setup for the ui-mock skill, for apps/web.
#
# This script never runs `shadcn init`. Slice 6 already initialized the app and then split
# the result in two: token VALUES live in src/styles/theme.css, the `@theme inline` mapping
# lives in src/app/globals.css. `init` rewrites globals.css whole and would undo that split
# silently, so a missing components.json is an error here rather than a thing to fix by
# initializing.
#
# Files under src/components/ui are the CLI's, never hand-edited (BP41) — customization goes
# in wrappers under src/components/<area>/.
set -euo pipefail

# Repo root: this script lives at .claude/skills/ui-mock/scripts/, four directories below it.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$REPO_ROOT"

WEB="apps/web"
INVENTORY=".cache/ui-mock/components.txt"

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
  echo "ERROR: $WEB/components.json missing — apps/web is not an initialized shadcn project." >&2
  echo "       Do NOT run 'shadcn init' to fix it: init rewrites src/app/globals.css and" >&2
  echo "       destroys the theme.css / globals.css token split. Read" >&2
  echo "       docs/2026-08-08-setup/06-design-system.md first." >&2
  exit 1
fi
if ! node -e '
  const p = require("./apps/web/package.json");
  const v = (p.devDependencies && p.devDependencies.tailwindcss) || (p.dependencies && p.dependencies.tailwindcss) || "";
  process.exit(/^[\^~]?4/.test(v) ? 0 : 1);
'; then
  echo "ERROR: tailwindcss ^4 not found in $WEB/package.json." >&2
  exit 1
fi

# --- Add components — only those whose generated file is missing. `--overwrite` is passed
# for the ADD PAYLOAD's sake, not to re-add present components: a missing component's payload
# can include registry dependencies whose files already exist, and without the flag the CLI
# blocks on an interactive overwrite prompt that piped input cannot answer. Refreshing those
# files to registry state is safe BECAUSE of BP41 — they are the CLI's output, never
# hand-edited, and the plan of record deliberately does not claim them either. To force a
# fresh copy of one component, delete its file and re-run.
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
  if ! (cd "$WEB" && pnpm dlx shadcn@latest add --yes --overwrite "${MISSING[@]}"); then
    echo "ERROR: 'pnpm dlx shadcn@latest add' failed. Check network access and that every" >&2
    echo "       name in the add-list is a real registry name (see reference/pages.md)." >&2
    exit 3
  fi
  # The registry ships its own formatting; reconcile it with the repo's prettier config so
  # generated files are not a perpetual diff.
  pnpm exec prettier --write "$WEB/src/components/ui" --ignore-path .prettierignore >/dev/null 2>&1 || true
fi

# --- server-only: BP3's build-time guarantee that mock-data never reaches a client bundle.
# Idempotent — skipped once the dependency is declared.
if ! node -e "
  const p = require('./apps/web/package.json');
  process.exit((p.dependencies && p.dependencies['server-only']) || (p.devDependencies && p.devDependencies['server-only']) ? 0 : 1);
"; then
  if ! pnpm --filter @nanostore/web add server-only; then
    echo "ERROR: 'pnpm --filter @nanostore/web add server-only' failed — BP3 cannot compile" >&2
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
  echo "       then re-run. src/styles/theme.test.ts checks the half of this it can see." >&2
  exit 7
fi

echo "OK: toolkit ready — $(ls "$WEB/src/components/ui" | wc -l) files in $WEB/src/components/ui," \
  "server-only present, globals.css token split intact."
