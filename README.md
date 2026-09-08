# mock-ui

**A screen nobody built is a layout decision nobody made — it gets made later, by accident,
inside whichever vertical slice reaches that screen first. This turns a PRD into every
screen the product needs, in final-layout shape, before a line of real data-fetching code
exists.**

An [agent skill](https://agentskills.io) for Claude Code, Codex, and any other AI coding
agent that reads `SKILL.md`. Hand it a PRD — and, if one exists, a data model — for a
Next.js App Router app on shadcn/ui and Tailwind, and it derives the route inventory and a
shell contract, builds every route behind typed mock data, and reviews each group with three
independent reviewers before handing back a working, uncommitted tree. What it deliberately
does not do: visual design (colour, type scale, spacing rhythm — a later pass owns that) and
the API. The mock is the final layout minus design and minus the backend, not a sketch of
either.

This repo's own [commit history](https://github.com/boonkgim/mock-ui/commits/main) *is* the
skill's design record: every commit that shaped it, in order, from its first version through
the two real projects it was adopted into and the bugs their own use of it surfaced. Read it
before you install anything.

## Why you would want this

A coding agent asked to mock up a product will happily build the screens the spec spelled
out and silently skip the ones it didn't — a footer, a 404, a way past a forgotten password —
because nothing forces it to ask what a shipped product of this kind actually needs. The
gaps then surface three slices later, as a layout decision made under deadline instead of
here, cheaply, before any data is real.

- **Build for production, then mock the copy.** The target is what a real, shipped version
  of this product would have, not the subset the PRD happened to enumerate — a footer, an
  empty state, a way to reach a human. Invented copy marked as invented is reviewable; a
  missing page is not.
- **Open questions live in one inspector, never on the screen.** A mock covered in
  editorial asides about what the spec never decided cannot be put in front of a person —
  every judgement they give ends up being about a page that will never ship. Every gap is
  anchored to the exact element it concerns and surfaced through one floating panel instead,
  so the screen you hand back is the layout that will actually ship.
- **No invented domain facts, ever.** Every field, status and price rule traces to the PRD
  or the data model; what they're silent on is a flagged gap, never a plausible guess. The
  most common miss isn't a wrong fact — it's a confident, coherent, wrong one, because that's
  what a gap looks like once something fills it.
- **Three reviewers per group, each looking for a different failure.** A conventions
  reviewer scores the rule list; a spec-fidelity reviewer diffs the build against the PRD in
  both directions, so an unrequested feature is a finding too; a fresh-eyes reviewer gets
  neither the rule list nor the spec, on purpose — its only question is what a shipped
  version of this screen's *genre* would have that this one doesn't, which is the one
  question a reviewer holding the checklist stops being able to ask.
- **A rationale in a comment is not evidence.** Code that explains why it's exempt from
  review is the code most worth reviewing hardest — a docstring that has already reasoned
  through why a component is fine gets ratified, not checked, by default. The skill treats
  a comment as a claim to verify, never a verdict to adopt.
- **Every route earns its page or its dialog, by a test, not a guess.** Subtract from a
  screen everything its parent already showed; what's left decides whether it's a real
  destination or a side-step that belongs in a URL-driven dialog instead — with the four
  ways that shape fails quietly (a leaked loading state, a dialog left open after its own
  action navigates, a lost accessible name) written down once so nobody rediscovers them.

## Install

Paste this to your agent:

```
install the skill at https://github.com/boonkgim/mock-ui
```

It clones the repo and puts `SKILL.md`, `reference/` and `scripts/` where your tool looks
for skills. To update it later, ask the same way, or `git pull` in the clone.

<details>
<summary>By hand</summary>

```bash
git clone https://github.com/boonkgim/mock-ui.git

# Claude Code
ln -s "$PWD/mock-ui" ~/.claude/skills/mock-ui

# Codex
ln -s "$PWD/mock-ui" ~/.agents/skills/mock-ui
```

Symlink into a project's `.claude/skills/` instead to scope it to one repo. Other tools
read skills from their own location, and some take an upload; check yours.

</details>

A skill is instructions your agent will follow, so read `SKILL.md` before installing this
or any other. It is one file, plus two reference files and two scripts it runs or reads
from.

## Works with

`SKILL.md` follows the [Agent Skills](https://agentskills.io) open standard, so it loads
directly in any agent that reads the format — **Claude Code**, from `~/.claude/skills/`,
**OpenAI Codex**, from `~/.agents/skills/`, and any other tool with its own skills
directory. Where a tool does not read `SKILL.md` natively, paste it into the session or
drop it into the rules file that tool already reads, such as `AGENTS.md`.

Unlike a stack-agnostic skill, this one is not: it assumes a **Next.js App Router app on
shadcn/ui and Tailwind**, and a fair share of its rules are that stack's own mechanics —
parallel and intercepting routes, `PageProps`/`LayoutProps` typing, Server/Client component
boundaries. That coupling is deliberate; see "When not to use this" below.

## Usage

Have a PRD saved somewhere the agent can find it — and a data model too, if one exists,
though the skill runs without one. Tools that support invoking a skill by name take
`/mock-ui` directly; otherwise just ask to mock up the UI, scaffold the screens, or build
the pages once the PRD exists.

The skill first decides whether this is a **greenfield** run (a bare scaffold with no
product UI yet) or an **extension** run (an app that already has one) by reading the working
tree, then derives a route inventory and a shell contract from the PRD and shows you both
before building anything — the inventory is expensive to change once pages exist on top of
it. It builds the shared shell once, then one route group at a time behind typed mock data,
runs the three-reviewer loop per group for up to two rounds, and finishes with a mechanical
verification pass (`scripts/verify_pages.sh`) that greps for the failure modes a reviewer's
judgment can't reliably cover. Run artifacts live in `.cache/mock-ui/` — gitignored,
overwritten on the next run — never in the app's own source tree. It never touches the
API/schema layer, never runs a migration, and never commits: turning a mocked screen into a
real one, wired to real data, is a separate, later step this skill deliberately stops short
of.

If this is useful, a ⭐ helps other people find it.

## When not to use this

- **The app isn't Next.js App Router on shadcn/ui and Tailwind.** The skill's route,
  dialog and component rules are written against that stack's actual semantics, not a
  generic UI-framework abstraction — porting it to another stack means rewriting the rules,
  not just the reference paths.
- **There's no PRD yet.** This skill mocks a specified product; it doesn't invent the
  specification. Write the brief and get it approved first.
- **You want the visual design decided first.** Colour, type scale, spacing rhythm and
  imagery are explicitly out of scope — the mock uses the framework's out-of-the-box look on
  purpose, so a later design pass has a real layout to apply tokens to rather than a blank
  page to fill.
- **The change is small enough that mocking it separately is overhead** — a copy tweak, a
  new field on an existing form. This skill earns its cost on a new screen or a new flow,
  not on a one-line change to one that already shipped.

## Author

Built by **Khur Boon Kgim** at [boonkgim.com](https://boonkgim.com), where I write about
practical AI for builders: AI agents, coding workflows, and shipping software.

## License

MIT. See [LICENSE](LICENSE).
