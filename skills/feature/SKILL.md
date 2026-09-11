---
name: feature
description: Use to start a feature, begin implementing something new, or turn a prepared feature into a branch with a plan.
---

# Feature

## Overview

Starts one feature: a brainstorm that produces its design, one question that settles
its codename, title, branch type and bump type, a branch cut from the main branch,
and a plan written phase by phase. It ends on a planned branch with the state file
every later command reads. No code is written here.

**Preflight:** run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh"` as the first
action. A non-zero exit stops the skill: print its output verbatim and do nothing else.

**Announce at start:** "I am using implement:feature to open this feature." Speak to
the user in the user's language; write every artifact in English.

---

## The Iron Rule

```
NEVER write code here: this skill stops at a planned branch
NEVER start from a dirty tree, or from a branch other than the main one
NEVER stage or commit anything under docs/features in local mode
```

---

## Preconditions

```bash
# Each bash block is its own shell; derive rather than inherit.
MAIN=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##'); MAIN=${MAIN:-$(git branch --show-current)}
BRANCH=$(git branch --show-current) || exit 1
[ "$BRANCH" = "$MAIN" ] || { echo "start from $MAIN, not from $BRANCH"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "the tree is not clean"; exit 1; }
MODE=$(python3 -c 'import json,os; print(json.load(open(".implement.json")).get("artifacts","local") if os.path.exists(".implement.json") else "local")')
[ "$MODE" = committed ] || git check-ignore -q docs/features || { echo "docs/features is not ignored: add it to the excludes, or set artifacts to committed in .implement.json"; exit 1; }
ls -d docs/features/*/ 2>/dev/null | while read -r d; do [ -f "$d/IMPLEMENTATION.md" ] || echo "prepared: $(basename "$d")"; done
```

The last line lists the prepared features: a directory with a design and a plan and
no state file is one `implement:prepare` left ready.

---

## Step 1 — A prepared feature?

When the block listed one or more, show the list and ask which one to start, or
`new` for a fresh brainstorm. **WAIT.** On a name: its design and its plan already
exist, so skip to Step 3 with the codename it already carries and read its
`DESIGN.md` before asking. On `new`, or on an empty list, go to Step 2.

---

## Step 2 — Brainstorm

`superpowers:brainstorming`, architectural path. Its output is the design of this
feature, and it is the only source of the title. Nothing else happens in this step:
no branch, no directory, no file outside what the brainstorm itself writes.

---

## Step 3 — The one question

One question, asked once, carrying four proposed values:

- **codename** — kebab-case, derived from the title, the name every path and every
  branch uses from here on;
- **title** — the sentence the brainstorm settled on;
- **branch** type — `feat` or `fix`;
- **bump** type — `major`, `minor`, `patch` or `none`, which `implement:close` reads
  and which alone decides whether a version file is ever touched.

Show the four proposed values together, in one message, and **WAIT**. The user
confirms them or corrects any of them. Asked once: a second round of confirmation
is the user's time spent on what they already answered.

Then write the design under `docs/features/<codename>/DESIGN.md` — the codename is
known only now, which is why the brainstorm came first.

---

## Step 4 — Branch

```bash
# Each bash block is its own shell; derive rather than inherit.
MAIN=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##'); MAIN=${MAIN:-$(git branch --show-current)}
CODENAME=<the confirmed codename>
git checkout -b <feat-or-fix>/"$CODENAME" "$MAIN"
mkdir -p "docs/features/$CODENAME/plan"
```

---

## Step 5 — Plan

`superpowers:writing-plans` on `DESIGN.md`, output under
`docs/features/<codename>/plan/`: `INDEX.md` listing the phases, and one
`phase-NN-<slug>.md` per phase holding its sub-phases, its files, its tests and its
definition of done. `implement:phase` reads those files and nothing else.

---

## Step 6 — State

Write `docs/features/<codename>/IMPLEMENTATION.md` in this exact shape.
`implement:phase` and `implement:close` parse it, so the spelling is the contract:

```
**Codename**: <codename>
**Title**: <title>
**Branch**: <type>/<codename>
**Bump**: <major|minor|patch|none>
**Artifacts**: <local|committed>
**Base**: <sha of the main branch head>

| phase | title | status | milestone |
|---|---|---|---|
| 01 | <title of plan/phase-01-<slug>.md> | todo |  |
| 02 | <title of plan/phase-02-<slug>.md> | todo |  |
```

One row per phase of `plan/INDEX.md`, in its order, `NN` on two digits, status
`todo`, milestone empty. The base is the head the branch was cut from, which the
new branch still points at:

```bash
# Each bash block is its own shell; derive rather than inherit.
BRANCH=$(git branch --show-current) || exit 1
CODENAME=${BRANCH#*/}
git rev-parse --short HEAD          # the Base line: nothing is committed yet
ls "docs/features/$CODENAME/plan"   # the rows to write, one per phase file
```

---

## Step 7 — Committed mode

Only when the artifacts mode read in the preconditions is `committed`: one commit
`Start <title>` carrying the design, the plan and the state file, in the convention
read from `git log --format=%s -10`, with no trailer. In `local` mode this step does
nothing: the files stay on disk and nothing under `docs/features/` is ever staged.

---

## The summary

Close on it, in the user's language: the codename, the branch, the number of phases
and the title of the first one, the artifacts mode, and the next command,
`/implement:phase`. Nothing is pushed: the branch is local until the user says
otherwise, and this skill never says it for them.

---

## Stops

| Situation | The one line |
|---|---|
| The current branch is not the main one | `start from <main>, not from <branch>` |
| The tree is dirty | `the tree is not clean` |
| `docs/features` is not ignored in local mode | `docs/features is not ignored: add it to the excludes, or set artifacts to committed in .implement.json` |
| The user has not answered the one question | wait; nothing is derived from a value they did not confirm |
| The brainstorm settled no title | ask for it in one line, then wait |

---

## Report

```
branch:    <type>/<codename>, cut from <main> at <sha>
commits:   none in local mode; one "Start <title>" in committed mode
files:     docs/features/<codename>/DESIGN.md, plan/INDEX.md, plan/phase-NN-*.md, IMPLEMENTATION.md
gate:      not run here, no code is written
checks:    the state table matches plan/INDEX.md row for row
deviations: what departs from what the user confirmed, and why
open questions: what the design leaves for a phase to settle
status:    DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_DECISION
```

---

## Quick Reference

```
1. Preflight, then the preconditions block (main branch, clean tree, MODE, prepared list)
2. A prepared feature? WAIT for a name or "new"
3. superpowers:brainstorming, architectural path, for the design and the title
4. The one question: codename, title, branch type, bump type. WAIT. Asked once
5. git checkout -b <type>/<codename> from the main branch
6. superpowers:writing-plans on DESIGN.md, output under plan/
7. IMPLEMENTATION.md in the exact shape: six header lines, one row per phase, todo
8. committed mode only: one commit "Start <title>", no trailer
9. Summary, then /implement:phase. Write no code, push nothing
```
