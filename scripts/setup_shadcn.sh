#!/usr/bin/env bash
# setup_shadcn.sh — idempotent shadcn/ui setup for the ui-mock skill.
# Safe to re-run: init is skipped when components.json exists; add installs only components
# whose file is missing, so re-running never overwrites anything under src/components/ui.
# Files there are generated output and must never be hand-edited (BP40/BP41 in
# ../reference/conventions.md) — customization belongs in wrappers under src/components/<area>/.
set -euo pipefail

# Repo root: this script lives at .claude/skills/ui-mock/scripts/, four directories below it.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$REPO_ROOT"

# Components required by the route inventory — MUST match the "Component add-list"
# section of ../reference/pages.md. Add there first, then here.
COMPONENTS=(alert badge button card checkbox dialog dropdown-menu input label select
  separator skeleton table tabs textarea)

# --- Check: Tailwind 4 must already be installed (shadcn init targets the Tailwind-4
# @theme token pattern; on Tailwind 3 it would generate an incompatible config).
if ! node -e '
  const p = require("./package.json");
  const v = (p.devDependencies && p.devDependencies.tailwindcss) || (p.dependencies && p.dependencies.tailwindcss) || "";
  process.exit(/^[\^~]?4/.test(v) ? 0 : 1);
'; then
  echo "ERROR: tailwindcss ^4 not found in package.json (devDependencies or dependencies)." >&2
  echo "       Install it first: npm install -D tailwindcss@^4 @tailwindcss/postcss" >&2
  exit 1
fi

# --- Init: only when components.json is missing (that file is shadcn's marker of an
# initialized project, which is what makes this step idempotent).
if [ ! -f components.json ]; then
  # NOTE: init REWRITES src/app/globals.css to the shadcn :root/.dark/@theme-inline token
  # pattern. This is INTENDED (design finding 4 in reference/conventions.md): the old
  # 2-token prefers-color-scheme file must not be preserved — without @theme inline,
  # semantic classes like bg-primary silently stop resolving.
  #   --yes            accept all defaults, never prompt (non-interactive/CI-safe)
  #   --base-color neutral  the stock out-of-the-box shadcn look; restyling later is a
  #                    one-file edit of the globals.css tokens, per the skill's bar
  if ! npx shadcn@latest init --yes --base-color neutral; then
    echo "ERROR: 'npx shadcn@latest init' failed. Check network access to the shadcn" >&2
    echo "       registry and that src/app/globals.css imports tailwindcss." >&2
    exit 2
  fi
fi

# --- Add components — but only those whose generated file is missing. No --overwrite:
# re-runs stay idempotent because already-present components are skipped, so this script
# never destroys an existing file. Note this is a safety property, not license to edit:
# BP40/BP41 in reference/conventions.md forbid hand edits to src/components/ui files —
# customization goes in wrapper components under src/components/<area>/. To force a fresh
# copy of one component, delete its file in src/components/ui/ and re-run.
MISSING=()
for c in "${COMPONENTS[@]}"; do
  # shadcn registry names map 1:1 to generated kebab-case filenames (button -> button.tsx).
  if [ ! -f "src/components/ui/${c}.tsx" ]; then
    MISSING+=("$c")
  fi
done
if [ "${#MISSING[@]}" -eq 0 ]; then
  echo "OK: all ${#COMPONENTS[@]} components already present in src/components/ui — nothing to add."
elif ! npx shadcn@latest add --yes "${MISSING[@]}"; then  # --yes: non-interactive
  echo "ERROR: 'npx shadcn@latest add' failed. Check network access and that every name in" >&2
  echo "       COMPONENTS matches the add-list in reference/pages.md (registry names)." >&2
  exit 3
fi

# --- Post-conditions: the two artifacts every page build depends on.
if [ ! -f src/lib/utils.ts ]; then
  echo "ERROR: src/lib/utils.ts missing after init — the cn() helper (BP39) is unavailable." >&2
  echo "       Delete components.json and re-run this script to force a fresh init." >&2
  exit 4
fi
if [ ! -d src/components/ui ]; then
  echo "ERROR: src/components/ui/ missing after add — no primitives were generated." >&2
  echo "       Re-run this script; if it persists, run the add command above manually." >&2
  exit 5
fi

echo "OK: shadcn ready — components.json present, src/lib/utils.ts present," \
  "$(ls src/components/ui | wc -l) files in src/components/ui."
