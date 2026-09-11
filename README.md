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
  DESIGN.md              the spec the brainstorm produced (superpowers:brainstorming, architectural path)
  plan/INDEX.md          the phase list (superpowers:writing-plans)
  plan/phase-NN-<slug>.md  one file per phase: sub-phases, files, tests, definition of done
  IMPLEMENTATION.md      the state, and the only source of truth for progress
ROADMAP.md               at the repository root: one line per prepared feature
.implement.json          at the repository root, optional: {"artifacts": "local" | "committed"}
```

`/implement:feature` writes all of it; `/implement:phase` and `/implement:close`
read it. `IMPLEMENTATION.md` carries six header lines — codename, title, branch,
bump type, artifacts mode, and the commit the branch was cut from — then one row
per phase:

```
| phase | title | status | milestone |
|---|---|---|---|
| 01 | the first phase | done | 82525e4 |
| 02 | the second one | doing |  |
```

Status is `todo`, `doing` or `done`, and the milestone stays empty until the phase
is done. `/implement:phase` resumes at the first row that is not done and refuses
to run without this file; `/implement:close` refuses while a row is not done.
`/implement:prepare` appends `- <codename> — <title> (<bump>)` to `ROADMAP.md` and
writes no state file, which is what makes a prepared feature recognisable.

Each of the three reading commands takes `--docs <path>` naming the feature
directory, for the case where the default — `docs/features/<codename>`, the
codename read from the branch name — is not what should be read: a worktree does
not see an ignored directory of the main checkout.

## .implement.json

Optional, at the repository root, one key:

```json
{"artifacts": "local"}
```

**Local, the default** — also what an absent file means. `docs/features/` must be
ignored, which `/implement:feature`, `/implement:prepare`, `/implement:phase` and
`/implement:close` verify with `git check-ignore -q docs/features` and refuse to run
without, naming the fix. Nothing under it, and no `ROADMAP.md`, is
ever staged; the artifacts are working notes, and a closed feature's own directory
is deleted by `/implement:close`.

**Committed** — `{"artifacts": "committed"}`. The check inverts: the directory must
not be ignored. The design, the plan and the state travel with the code — in the
commit that opens the feature, in one commit per finished phase, and in the closing
commit — and nothing is deleted at close.

## CLAUDE.md

This repository keeps a local `CLAUDE.md` with the conventions for working on
the plugin itself. It is gitignored and will not be tracked.

## Licence

MIT.
