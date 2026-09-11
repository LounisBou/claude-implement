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

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
