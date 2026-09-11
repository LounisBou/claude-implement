#!/bin/bash
# Test suite. No network, no plugin installation, isolated HOME per case.
#
# Each case runs a script against a temporary state directory or a temporary
# HOME and compares its output or its side effects with an expected value.

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0

# check <name> <expected> <actual>
check() {
  if [ "$2" = "$3" ]; then
    printf '  ok   %s\n' "$1"
    pass=$((pass + 1))
  else
    printf '  FAIL %s\n' "$1"
    printf '       expected: %s\n' "$(printf '%s' "$2" | tr '\n' '⏎')"
    printf '       actual:   %s\n' "$(printf '%s' "$3" | tr '\n' '⏎')"
    fail=$((fail + 1))
  fi
}

# check_status <name> <expected-exit-code> <command...>
check_status() {
  local name="$1" expected="$2"
  shift 2
  "$@" >/dev/null 2>&1
  local code=$?
  check "$name" "exit $expected" "exit $code"
}

echo "== manifests =="
MAN="$ROOT/.claude-plugin/plugin.json"; MKT="$ROOT/.claude-plugin/marketplace.json"
check "plugin is named implement" "implement" "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["name"])' "$MAN")"
check "manifest version" "0.1.0" "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$MAN")"
check "marketplace and manifest agree on the version" "0.1.0 0.1.0" \
  "$(python3 -c 'import json,sys; m=json.load(open(sys.argv[1])); print(m["metadata"]["version"], m["plugins"][0]["version"])' "$MKT")"
check "descriptions are identical" "True" \
  "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["description"]==json.load(open(sys.argv[2]))["plugins"][0]["description"])' "$MAN" "$MKT")"
check "the only dependency is superpowers" "['superpowers@claude-plugins-official']" \
  "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["dependencies"])' "$MAN")"
check "both commands run the preflight" "2" "$(grep -l 'scripts/preflight.sh' "$ROOT"/commands/*.md | wc -l | tr -d ' ')"

echo "== preflight =="
PF="$ROOT/scripts/preflight.sh"
settings() { mkdir -p "$WORK/cfg"; printf '%s' "$1" > "$WORK/cfg/settings.json"; }
pf() { env HOME="$WORK" PREFLIGHT_SETTINGS="$WORK/cfg/settings.json" PREFLIGHT_SKIP_GIT=1 bash "$PF" "$@"; }
settings '{"enabledPlugins":{"superpowers@claude-plugins-official":true}}'
check_status "superpowers enabled passes" 0 pf
settings '{"enabledPlugins":{"superpowers@claude-plugins-official":false}}'
check_status "superpowers disabled exits 10" 10 pf
check "the failure names superpowers with a fix line" "2" "$(pf 2>&1 >/dev/null | grep -cE '^(error|fix):.*superpowers')"
settings '{"enabledPlugins":{}}'
check_status "superpowers absent exits 10" 10 pf
settings '{ not json'
check_status "malformed settings exits 10" 10 pf
check "malformed settings is one error line and no traceback" "1 0" \
  "$(out=$(pf 2>&1 >/dev/null); printf '%s %s' "$(printf '%s\n' "$out" | grep -c '^error:')" "$(printf '%s\n' "$out" | grep -c Traceback)")"
settings '{"enabledPlugins":{"superpowers@claude-plugins-official":true}}'
check_status "outside a git repository exits 13" 13 env HOME="$WORK" PREFLIGHT_SETTINGS="$WORK/cfg/settings.json" bash -c "cd '$WORK' && bash '$PF'"

echo "== skills =="
for skill in feature phase check close prepare; do
  doc="$ROOT/skills/$skill/SKILL.md"
  check "$skill frontmatter names itself" "$skill" "$(awk '/^name:/{print $2; exit}' "$doc" 2>/dev/null)"
  check "$skill runs the preflight first" "1" "$(grep -c 'scripts/preflight.sh' "$doc" 2>/dev/null || echo 0)"
  check "$skill hard-codes no language" "" "$(grep -o 'French' "$doc" 2>/dev/null || true)"
  check "$skill has no accented character" "" "$(grep -o '[àâäéèêëïîôöùûüçÀÂÄÉÈÊËÏÎÔÖÙÛÜÇœŒ]' "$doc" 2>/dev/null | sort -u | tr '\n' ',' || true)"
  check "$skill has no common French words" "" "$(grep -Eiow 'vous|nous|avec|chemin|fichier|sont|une|titre' "$doc" 2>/dev/null | sort -u | tr '\n' ',' || true)"
  check "$skill reaches no other plugin's cache" "" "$(grep -o 'plugins/cache' "$doc" 2>/dev/null || true)"
  check "$skill never pushes, merges or calls GitHub" "" \
    "$(awk '/^```bash/{f=1;next} /^```/{f=0} f && /(git push|gh |curl |git merge)/{print NR}' "$doc" 2>/dev/null)"
done
# Each bash block is its own shell.
for skill in feature phase check close prepare; do
  unresolved=$(python3 - "$ROOT/skills/$skill/SKILL.md" <<'PYFENCE'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read().split("\n")
names = ("CODENAME", "DOCS", "BRANCH", "MAIN")
bad, block, start = [], None, 0
for i, line in enumerate(text, 1):
    if block is None:
        if line.startswith("```bash"):
            block, start = [], i
    elif line.startswith("```"):
        body = "\n".join(block)
        for name in names:
            if re.search(r"\$\{?%s\b" % name, body) and not re.search(r"^\s*%s=" % name, body, re.M):
                bad.append("%d:%s" % (start, name))
        block = None
    else:
        block.append(line)
print(" ".join(bad))
PYFENCE
)
  check "every $skill bash block derives what it uses" "" "$unresolved"
done
# Contract: every superpowers:<name> exists in the installed plugin, every implement:<name> is one of ours.
# Each key of "plugins" in installed_plugins.json maps to a LIST of per-scope
# install records (a plugin can be installed at more than one scope), so every
# record of every matching key is flattened before the first installPath is read.
SP_ROOT="${SUPERPOWERS_ROOT:-$(python3 -c 'import json,os; d=json.load(open(os.path.expanduser("~/.claude/plugins/installed_plugins.json"))); recs=[r for k,v in d.get("plugins",{}).items() if k.startswith("superpowers@") for r in v]; print(recs[0]["installPath"] if recs and isinstance(recs[0],dict) and "installPath" in recs[0] else "")' 2>/dev/null)}"
check "the superpowers plugin resolves" "1" "$([ -d "$SP_ROOT/skills" ] && echo 1 || echo 0)"
phantoms=$(for skill in feature phase check close prepare; do
  grep -oE '(superpowers|implement):[a-z-]+' "$ROOT/skills/$skill/SKILL.md" 2>/dev/null | sort -u | while read -r ref; do
    case "$ref" in
      (superpowers:*) [ -d "$SP_ROOT/skills/${ref#superpowers:}" ] || printf '%s:%s ' "$skill" "$ref" ;;
      (implement:*)   [ -d "$ROOT/skills/${ref#implement:}" ] || printf '%s:%s ' "$skill" "$ref" ;;
    esac
  done
done)
check "every skill reference names something real" "" "$phantoms"

echo "== check =="
CHECK_DOC="$ROOT/skills/check/SKILL.md"

# A heading inside a fence is content the reader is shown, not a section of the
# document: this one shows the verdict table. Left uncounted, it moves every line
# after it into a section that does not exist. A fence opens on three or more
# backticks and closes on at least as many.
FENCE_TRACK='function bt(  c) { c = 0; while (substr($0, c + 1, 1) == "`") c++; return c }
/^```/ { n = bt(); if (!f) { f = 1; fence = n } else if (n >= fence) { f = 0 } next }'

# The report is the whole output of this skill. A reader who gets prose instead
# of the table cannot tell which of the seven checks produced which evidence.
check "check reports under one heading" "1" \
  "$(awk "$FENCE_TRACK"'
     !f && /^## Report$/ { hits++ }
     END { print (hits > 0) ? 1 : 0 }' "$CHECK_DOC")"
check "check gives the table its header" "1" \
  "$(grep -c '^| check | evidence | result |' "$CHECK_DOC" | awk '{print ($1 >= 1) ? 1 : 0}')"

# Seven verifications, each with its evidence, and the order is the one the spec
# fixes: a delivery is read before it is compared, compared before it is re-run.
# The concatenation falls on a deletion and on a reordering; the count names
# which of the two happened.
check "check carries seven numbered verifications" "7" \
  "$(awk "$FENCE_TRACK"'!f && /^### [1-7]\. / { seen++ } END { print seen + 0 }' "$CHECK_DOC")"
check "the seven verifications are in order" "1234567" \
  "$(awk "$FENCE_TRACK"'!f && /^### [1-7]\. / { printf "%s", substr($0, 5, 1) }' "$CHECK_DOC")"

# This skill verifies and stops there. An overview that leaves it open is read by
# an agent as licence to repair what it just found, which is the other skill's work.
check "check says in its overview that it edits nothing" "1" \
  "$(awk "$FENCE_TRACK"'
     !f && /^## Overview$/ { in_ov = 1; next }
     !f && /^## / { in_ov = 0 }
     in_ov && /(edits nothing|never edits)/ { hits++ }
     END { print (hits > 0) ? 1 : 0 }' "$CHECK_DOC")"

echo "== phase =="
PHASE_DOC="$ROOT/skills/phase/SKILL.md"

# The four NEVER lines are the whole of what this skill refuses. Three of them
# would still read as a complete rule, which is why the count is the check and
# not the presence of the fence.
check "phase's iron rule holds four NEVER lines" "4" \
  "$(awk '/^## The Iron Rule$/ { in_rule = 1; next }
          /^## / { in_rule = 0 }
          in_rule && /^NEVER / { nevers++ }
          END { print nevers + 0 }' "$PHASE_DOC")"

# The two skills the loop hands its work to. The contract check above proves the
# directories exist; here they are proved to be invoked at all.
for ref in implement:check superpowers:test-driven-development; do
  check "phase invokes $ref" "1" \
    "$(grep -c "$ref" "$PHASE_DOC" 2>/dev/null | awk '{print ($1 >= 1) ? 1 : 0}')"
done

# A gate whose result is not read is not a gate. The loop states each command with
# its exit code, so a transcript tells a green run from a red one without trusting
# the summary written over it.
check "the loop states the gate exit code" "1" \
  "$(awk "$FENCE_TRACK"'
     !f && /^## The loop$/ { in_loop = 1; next }
     !f && /^## / { in_loop = 0 }
     in_loop && /exit code/ { seen++ }
     END { print (seen > 0) ? 1 : 0 }' "$PHASE_DOC")"

# The work is written here, in this session, or it is written by nobody who read
# the plan. A dispatch hidden in a copyable block is the one that gets run.
check "no phase bash block dispatches a subagent" "" \
  "$(awk '/^```bash/ { b = 1; next } /^```/ { b = 0 } b && /(Task\(|subagent)/ { print NR }' "$PHASE_DOC")"

echo "== feature =="
FEATURE_DOC="$ROOT/skills/feature/SKILL.md"

# The spec fixes the two superpowers skills this one stands on. Paraphrasing
# either of them is the failure mode the whole plugin exists to avoid.
for ref in superpowers:brainstorming superpowers:writing-plans; do
  check "feature invokes $ref" "1" \
    "$(grep -c "$ref" "$FEATURE_DOC" 2>/dev/null | awk '{print ($1 >= 1) ? 1 : 0}')"
done

# One question, asked once, carrying four proposed values. Three of them asked and
# the fourth assumed is the quiet failure: the user confirms what they were shown
# and the unshown value lands in the state file unread.
check "feature's one question carries the four values" "4" \
  "$(awk "$FENCE_TRACK"'
     !f && /^## .*The one question/ { in_q = 1; next }
     !f && /^## / { in_q = 0 }
     in_q && /codename/ { seen["codename"] = 1 }
     in_q && /title/ { seen["title"] = 1 }
     in_q && /branch/ { seen["branch"] = 1 }
     in_q && /bump/ { seen["bump"] = 1 }
     END { total = 0; for (k in seen) total++; print total }' "$FEATURE_DOC")"

# The state table is the contract phase and close parse. It is shown in a fence so
# the writer copies it rather than inventing a spelling of its own.
check "feature gives the state table its header inside a fence" "1" \
  "$(awk "$FENCE_TRACK"'
     f && /^\| phase \| title \| status \| milestone \|/ { hits++ }
     END { print (hits > 0) ? 1 : 0 }' "$FEATURE_DOC")"

echo "== prepare =="
PREPARE_DOC="$ROOT/skills/prepare/SKILL.md"

# Preparing a feature is the first half of starting one, and the half that touches
# no branch: it has to stand on the same two superpowers skills.
for ref in superpowers:brainstorming superpowers:writing-plans; do
  check "prepare invokes $ref" "1" \
    "$(grep -c "$ref" "$PREPARE_DOC" 2>/dev/null | awk '{print ($1 >= 1) ? 1 : 0}')"
done

# The one line that keeps a prepared feature from disturbing whatever is in flight
# on another branch. Without it this skill is implement:feature with a missing step.
check "prepare refuses to create a branch" "1" \
  "$(grep -c '^NEVER create a branch' "$PREPARE_DOC" 2>/dev/null | awk '{print ($1 >= 1) ? 1 : 0}')"
check "prepare's iron rule holds two NEVER lines" "2" \
  "$(awk '/^## The Iron Rule$/ { in_rule = 1; next }
          /^## / { in_rule = 0 }
          in_rule && /^NEVER / { nevers++ }
          END { print nevers + 0 }' "$PREPARE_DOC")"

echo "== close =="
CLOSE_DOC="$ROOT/skills/close/SKILL.md"

# The detection order is the contract: the first file found is the one bumped, so a
# repository holding both a VERSION and a package.json gets a different version
# written if two names trade places. Compared in order of first appearance.
check "close names the five version files in order" \
  "VERSION pyproject.toml package.json composer.json .claude-plugin/plugin.json" \
  "$(grep -oE 'VERSION|pyproject\.toml|package\.json|composer\.json|\.claude-plugin/plugin\.json' "$CLOSE_DOC" \
     | awk '!already[$0]++' | tr '\n' ' ' | sed 's/ *$//')"

check "close's iron rule holds three NEVER lines" "3" \
  "$(awk '/^## The Iron Rule$/ { in_rule = 1; next }
          /^## / { in_rule = 0 }
          in_rule && /^NEVER / { nevers++ }
          END { print nevers + 0 }' "$CLOSE_DOC")"

# What happens after the branch belongs to the user. Said once: twice reads as a
# warning, absent it reads as an offer to do it.
check "close hands the rest back in one sentence" "1" \
  "$(grep -o 'push, pull request and review are yours' "$CLOSE_DOC" 2>/dev/null | wc -l | tr -d ' ')"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
