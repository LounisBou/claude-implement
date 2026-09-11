# implement

The feature lifecycle in a repository — brainstorm, branch, plan, phases, close —
with nothing in it that belongs to one project.

## Requires one plugin

`superpowers@claude-plugins-official`. Installed is not the same as enabled: a
plugin can sit on disk and be inert, so the preflight reads the `enabledPlugins`
map rather than looking for files. If it is missing or disabled, every skill
stops before doing anything and prints the command that fixes it.

## Install

```
/plugin marketplace add LounisBou/claude-implement
/plugin install implement@claude-implement
/implement:install
```

`/implement:install` writes nothing. Run `/implement:doctor` any time to repeat
the check.

## The five commands

- **`/implement:feature`** — start a feature: brainstorm, confirm the codename,
  title, branch type and bump type once, create the branch, write the plan.
- **`/implement:phase`** — run the plan's phases, gated and checked, one sub-phase
  at a time, without pausing unless a phase number is given.
- **`/implement:check`** — verify a delivery against the plan and the design, on
  any commit range.
- **`/implement:close`** — the full project gate, the version bump, the final
  summary; push, pull request and review stay the operator's.
- **`/implement:prepare`** — plan a future feature onto `ROADMAP.md` without
  touching a branch, so it coexists with a feature in progress on another one.

## The artifact layout

```
docs/features/<codename>/
  DESIGN.md              the spec brainstorming produced (superpowers:brainstorming, architectural path)
  plan/INDEX.md          the phase list (superpowers:writing-plans)
  plan/phase-NN-<slug>.md  one file per phase: sub-phases, files, tests, definition of done
  IMPLEMENTATION.md      the state: codename, title, branch, bump type, artifacts mode, base commit, phases table
ROADMAP.md               at the repository root: one line per prepared feature
.implement.json          at the repository root, optional: {"artifacts": "local" | "committed"}
```

**Local mode (default).** `docs/features/` must be ignored (`git check-ignore -q
docs/features`); nothing under it, and no `ROADMAP.md`, is ever staged. A closed
feature's own directory is deleted at close.

**Committed mode** (`.implement.json` says `{"artifacts": "committed"}`): the
directory must not be ignored; the artifacts join the milestone commit of each
phase and the close commit; close deletes nothing.

## CLAUDE.md

This repository keeps a local `CLAUDE.md` with the conventions for working on
the plugin itself. It is gitignored and will not be tracked.

## Licence

MIT.
