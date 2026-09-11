#!/usr/bin/env bash
# Refuse to run when the dependency is missing or the repository is absent, so
# no skill degrades silently.
set -u

SETTINGS="${PREFLIGHT_SETTINGS:-$HOME/.claude/settings.json}"

die() {
  printf 'error: %s\n' "$1" >&2
  printf 'fix:   %s\n' "$2" >&2
  exit "$3"
}

# ── Plugin dependency ─────────────────────────────────────────
# The authority is enabledPlugins, not the presence of files under
# ~/.claude/plugins/cache: a plugin can sit on disk and be inert.
missing=$(python3 - "$SETTINGS" <<'PY'
import json, sys

required = ("superpowers@claude-plugins-official",)
try:
    with open(sys.argv[1]) as fh:
        data = json.load(fh)
    enabled = data["enabledPlugins"] if isinstance(data, dict) else None
    if not isinstance(enabled, dict):
        raise ValueError("enabledPlugins is not an object")
except (OSError, ValueError, KeyError, TypeError):
    # Unreadable, not JSON, or JSON of the wrong shape all mean the same
    # thing: nothing here proves the dependency is enabled.
    print(" ".join(required))
    sys.exit(0)
print(" ".join(dep for dep in required if enabled.get(dep) is not True))
PY
)
py_status=$?
# If the interpreter dies before printing (crash, killed, bad python3),
# $missing is empty exactly like the "nothing is missing" case, and the
# guard would otherwise PASS on no evidence at all.
if [ "$py_status" -ne 0 ]; then
  die "could not check plugin dependencies (python3 exited $py_status)" "check your python3 installation and try again" 10
fi
if [ -n "$missing" ]; then
  for dep in $missing; do
    printf 'error: required plugin not installed or not enabled: %s\n' "$dep" >&2
    printf 'fix:   /plugin install %s   then enable it in /plugin\n' "$dep" >&2
  done
  exit 10
fi

# ── Repository ────────────────────────────────────────────────
if [ "${PREFLIGHT_SKIP_GIT:-0}" != "1" ]; then
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 && [ -n "$(git branch --show-current 2>/dev/null)" ] \
    || die "not a git repository with a current branch" "run this from inside a git repository, on a branch" 13
fi

exit 0
