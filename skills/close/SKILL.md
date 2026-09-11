---
name: close
description: Use to close a feature, finish a branch, or cut the release commit once every phase is done.
---

# Close

## Overview

Closes one feature on its branch: the project's full gate, the version bump the
feature declared, a summary of everything the branch carries, and the removal of the
local working notes. It refuses while a phase is not done or the tree is not clean.
What comes after the branch is the user's and is never done here.

**Preflight:** run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh"` as the first
action. A non-zero exit stops the skill: print its output verbatim and do nothing else.

**Announce at start:** "I am using implement:close to finish this branch." Speak to
the user in the user's language; write every artifact in English.

---

## The Iron Rule

```
NEVER push, open a pull request, merge or delete a branch
NEVER close while a phase is not done, or while the tree is dirty
NEVER touch a version file when the bump type is none
```

---

## Preconditions

`implement:close [--docs <path>]`. When `--docs <path>` is given, `export
DOCS_OVERRIDE=<path>` before running the block; without it the path is derived from
the branch name (`feat/<codename>` or `fix/<codename>`).

```bash
# Each bash block is its own shell; derive rather than inherit.
BRANCH=$(git branch --show-current) || exit 1
CODENAME=${BRANCH#*/}
DOCS=${DOCS_OVERRIDE:-docs/features/$CODENAME}
[ -f "$DOCS/IMPLEMENTATION.md" ] || { echo "no IMPLEMENTATION.md under $DOCS: pass --docs <path>"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "the tree is not clean"; exit 1; }
grep -qE '^\| *[0-9]+ *\|[^|]*\| *(todo|doing) *\|' "$DOCS/IMPLEMENTATION.md" && { echo "a phase is not done"; exit 1; }
BUMP=$(grep -E '^\*\*Bump\*\*:' "$DOCS/IMPLEMENTATION.md" | sed 's/^\*\*Bump\*\*: *//')
echo "$CODENAME ready to close, bump $BUMP"
```

---

## Step 1 — The full gate

The whole project, not the files of one phase. The commands are the ones the
repository names, in this order of discovery: the check and test commands of its
`CLAUDE.md`, else those of its `CONTRIBUTING.md`, else its test suite as its own
documentation describes it. Run each one synchronously, in the call that waits for
it, and state it with its exit code.

A non-zero code stops here: name the command, its exit code and the first lines of
its output, and repair nothing. A feature is not closed over a red gate, and a gate
whose exit code was not read was not run.

---

## Step 2 — The version

Only when the bump type read above is not `none`. Detect the version file in this
order, and take the first one that exists:

```
VERSION
pyproject.toml
package.json
composer.json
.claude-plugin/plugin.json
```

The order is the contract: a repository holding several of them is bumped in the
first one, always the same one. Read the current version, then apply the bump —
`major` raises the first number and resets the two others to zero, `minor` raises
the second and resets the third, `patch` raises the third. Write it back in place:
`python3` for a JSON field or a TOML field, so the rest of the file is untouched;
`printf` for a plain `VERSION` file.

Then one commit `Release <version>` in the convention read from
`git log --format=%s -10`, with no trailer, carrying the version file alone — and,
in `committed` mode, the feature's artifacts with it.

A bump type other than `none` with none of the five files present stops the skill:
say which five were looked for and wait. Guessing a version file is how a version
lands in a file nothing reads.

---

## Step 3 — The summary

```bash
# Each bash block is its own shell; derive rather than inherit.
BRANCH=$(git branch --show-current) || exit 1
CODENAME=${BRANCH#*/}
DOCS=${DOCS_OVERRIDE:-docs/features/$CODENAME}
BASE=$(grep -E '^\*\*Base\*\*:' "$DOCS/IMPLEMENTATION.md" | sed 's/^\*\*Base\*\*: *//')
git log --format='%h %s' "$BASE"..HEAD
git diff --stat "$BASE"..HEAD
```

The summary states, in the user's language: the branch, every commit since the base,
the version if one was written, and each gate command with its exit code. It ends on
one sentence, said once: push, pull request and review are yours.

---

## Step 4 — The local files

In `local` mode, and only there, the feature's own working notes go: that directory
and no other, plus the feature's line in the roadmap when it has one.

```bash
# Each bash block is its own shell; derive rather than inherit.
BRANCH=$(git branch --show-current) || exit 1
CODENAME=${BRANCH#*/}
DOCS=${DOCS_OVERRIDE:-docs/features/$CODENAME}
MODE=$(python3 -c 'import json,os; print(json.load(open(".implement.json")).get("artifacts","local") if os.path.exists(".implement.json") else "local")')
[ "$MODE" = committed ] && { echo "committed mode: nothing is deleted"; exit 0; }
rm -r "$DOCS"
[ -f ROADMAP.md ] && { TRIMMED=$(mktemp); grep -v "^- $CODENAME " ROADMAP.md > "$TRIMMED"; mv "$TRIMMED" ROADMAP.md; }
```

In `committed` mode nothing is deleted: the design, the plan and the state are part
of the repository and stay in it.

---

## Stops

| Situation | The one line |
|---|---|
| No `IMPLEMENTATION.md` under the derived path | `no IMPLEMENTATION.md under <docs>: pass --docs <path>` |
| The tree is dirty | `the tree is not clean` |
| A row is still `todo` or `doing` | `a phase is not done` |
| A gate command came back non-zero | `<command> exit <code>` and the first lines of its output |
| A bump is asked and no version file exists | the five names looked for, in order, then wait |

Each stop says its line once and waits. Nothing outward-facing is done here, on any
answer.

---

## Report

```
branch:    <type>/<codename>, base <sha>
commits:   <short sha> <subject>   (every commit since the base)
files:     the version file if one was written
gate:      <command> exit <code>   (one line per command)
checks:    every phase row done, tree clean before and after
deviations: what departs from the plan or the bump type the feature declared
open questions: what the branch leaves open
status:    DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_DECISION
```

---

## Quick Reference

```
1. Preflight, then derive BRANCH, CODENAME, DOCS, BUMP (--docs exports DOCS_OVERRIDE)
2. Refuse on a dirty tree, a missing state file, or a row not done
3. Full-project gate, every command with its exit code. Red stops, nothing repaired
4. Bump none: skip. Otherwise the first of VERSION, pyproject.toml, package.json,
   composer.json, .claude-plugin/plugin.json, and one commit "Release <version>"
5. Summary: branch, commits since the base, version, gate codes, the closing sentence
6. local mode: delete the feature directory and its roadmap line. committed: keep all
7. Push nothing, merge nothing, open nothing
```
