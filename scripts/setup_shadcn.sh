#!/usr/bin/env bash
# setup_shadcn.sh — idempotent shadcn/ui setup for the ui-mock skill.
# Safe to re-run: init is skipped when components.json exists; add runs only for components
# whose file is missing (their payload may refresh registry-dependency files to registry
# state — harmless, see the add step's comment). Files under src/components/ui are generated
# output and must never be hand-edited (BP40/BP41 in ../reference/conventions.md) —
# customization belongs in wrappers under src/components/<area>/.
set -euo pipefail

# Repo root: this script lives at .claude/skills/ui-mock/scripts/, four directories below it.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$REPO_ROOT"

# Components required by the route inventory — MUST match the "Component add-list"
# section of ../reference/pages.md. Add there first, then here.
COMPONENTS=(alert badge button card checkbox dialog dropdown-menu field input label select
  separator skeleton table tabs textarea)

# npm packages BP53 (client form validation) builds on. The `field` registry item is
# validation-library-agnostic and does NOT install these; the old `form` registry item
# that used to pull in react-hook-form is an empty stub in the base-nova registry.
FORM_DEPS=(react-hook-form zod @hookform/resolvers)

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

# --- First-run scaffold cleanup: remove create-next-app leftovers before init. Gated on
# the same first-run marker as init (no components.json yet) so re-runs never touch files
# the skill's own agents have since created.
if [ ! -f components.json ]; then
  # Default root page — only when it is recognizably the scaffold (references the demo
  # assets), never a hand-written page. The (public) group later owns "/" via
  # src/app/(public)/page.tsx; leaving this file in place is a duplicate-route build error (BP20).
  if [ -f src/app/page.tsx ] && grep -qE '/next\.svg|create-next-app' src/app/page.tsx; then
    rm src/app/page.tsx
    echo "cleanup: removed scaffold src/app/page.tsx"
  fi
  # Demo assets shipped by create-next-app; nothing in the skill's pages uses them.
  for f in public/next.svg public/vercel.svg public/globe.svg public/file.svg public/window.svg; do
    if [ -f "$f" ]; then
      rm "$f"
      echo "cleanup: removed scaffold $f"
    fi
  done
  # Scaffold font variables: create-next-app names them --font-geist-*, but shadcn's
  # generated globals.css wires body text to var(--font-sans). A mismatch leaves
  # --font-sans self-referential (guaranteed-invalid), silently dropping every page to
  # the browser's default serif. Normalize to the canonical shadcn names up front.
  if [ -f src/app/layout.tsx ]; then
    sed -i "s/--font-geist-sans/--font-sans/g; s/--font-geist-mono/--font-mono/g" src/app/layout.tsx
  fi
fi

# --- Init: only when components.json is missing (that file is shadcn's marker of an
# initialized project, which is what makes this step idempotent).
if [ ! -f components.json ]; then
  # NOTE: init REWRITES src/app/globals.css to the shadcn :root/.dark/@theme-inline token
  # pattern. This is INTENDED (design finding 4 in reference/conventions.md): the old
  # 2-token prefers-color-scheme file must not be preserved — without @theme inline,
  # semantic classes like bg-primary silently stop resolving.
  #   --yes            accept all defaults, never prompt (non-interactive/CI-safe)
  #   --defaults       shadcn CLI 4.x dropped --base-color; this picks the CLI's stock
  #                    preset (base-nova) — the out-of-the-box shadcn look. Restyling
  #                    later is a one-file edit of the globals.css tokens, per the
  #                    skill's bar.
  if ! npx shadcn@latest init --yes --defaults; then
    echo "ERROR: 'npx shadcn@latest init' failed. Check network access to the shadcn" >&2
    echo "       registry and that src/app/globals.css imports tailwindcss." >&2
    exit 2
  fi
fi

# --- Add components — but only those whose generated file is missing. `--overwrite` is
# passed for the ADD PAYLOAD's sake, not to re-add present components: a missing
# component's payload can include registry dependencies whose files already exist (e.g.
# `field` ships label + separator), and without the flag the CLI blocks on an interactive
# overwrite prompt that piped input cannot answer (the prompt library needs a TTY).
# Refreshing those files to registry state is safe BECAUSE of BP40/BP41 in
# reference/conventions.md: src/components/ui files are generated output that is never
# hand-edited, so there is nothing of ours to destroy — customization goes in wrapper
# components under src/components/<area>/. The prettier pass below restores repo
# formatting (the registry ships its own style). To force a fresh copy of one component,
# delete its file in src/components/ui/ and re-run.
MISSING=()
for c in "${COMPONENTS[@]}"; do
  # shadcn registry names map 1:1 to generated kebab-case filenames (button -> button.tsx).
  if [ ! -f "src/components/ui/${c}.tsx" ]; then
    MISSING+=("$c")
  fi
done
if [ "${#MISSING[@]}" -eq 0 ]; then
  echo "OK: all ${#COMPONENTS[@]} components already present in src/components/ui — nothing to add."
else
  if ! npx shadcn@latest add --yes --overwrite "${MISSING[@]}"; then  # --yes: non-interactive
    echo "ERROR: 'npx shadcn@latest add' failed. Check network access and that every name in" >&2
    echo "       COMPONENTS matches the add-list in reference/pages.md (registry names)." >&2
    exit 3
  fi
  # The registry emits its own formatting; reconcile with the repo's prettier config so
  # generated files don't show up as perpetual diffs. No-op where prettier is absent.
  npx --no-install prettier --write src/components/ui >/dev/null 2>&1 || true
fi

# --- Form-validation deps (BP53): react-hook-form + zod + @hookform/resolvers. Installed
# here (not via the registry — see FORM_DEPS note above). Idempotent: skipped when every
# package is already in package.json.
NEED_DEPS=()
for d in "${FORM_DEPS[@]}"; do
  if ! node -e "
    const p = require('./package.json');
    process.exit((p.dependencies && p.dependencies['$d']) || (p.devDependencies && p.devDependencies['$d']) ? 0 : 1);
  "; then
    NEED_DEPS+=("$d")
  fi
done
if [ "${#NEED_DEPS[@]}" -gt 0 ]; then
  if ! npm install "${NEED_DEPS[@]}"; then
    echo "ERROR: npm install ${NEED_DEPS[*]} failed — BP53 client validation cannot compile" >&2
    echo "       without these packages. Check network access and retry." >&2
    exit 7
  fi
fi

# --- Font-wiring reconciliation: whatever variable names the shadcn registry emitted in
# globals.css, point them at the canonical names the layout now declares. Idempotent (a
# no-op once the names already match).
if [ -f src/app/globals.css ]; then
  sed -i "s/var(--font-geist-sans)/var(--font-sans)/g; s/var(--font-geist-mono)/var(--font-mono)/g" src/app/globals.css
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
# Every font variable globals.css consumes must resolve at runtime: either next/font
# declares it in layout.tsx, or globals.css itself defines it with a non-self-referential
# value (e.g. --font-heading: var(--font-sans)). A dangling name means body text silently
# falls back to the browser default serif — the bug this guards against.
while read -r ref; do
  name="${ref#var(}"; name="${name%)}"
  if grep -q -- "'${name}'" src/app/layout.tsx; then continue; fi
  if grep -E -- "${name}:" src/app/globals.css | grep -vq -- "var(${name})"; then continue; fi
  echo "ERROR: globals.css references ${ref} but ${name} is neither declared by next/font" >&2
  echo "       in src/app/layout.tsx nor defined non-self-referentially in globals.css." >&2
  echo "       Body text would fall back to the browser default font." >&2
  exit 6
done < <(grep -ohE 'var\(--font-[a-z0-9-]+\)' src/app/globals.css | sort -u)

echo "OK: shadcn ready — components.json present, src/lib/utils.ts present," \
  "$(ls src/components/ui | wc -l) files in src/components/ui."
