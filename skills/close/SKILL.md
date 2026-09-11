---
name: close
description: Use to close the feature, finish the branch, or release once every phase is done.
---

# Close

## Overview

Runs the full project gate, bumps the version when one was requested, and reports the final summary; push, pull request and review stay the operator's.

**Preflight:** run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh"` as the first
action. A non-zero exit stops the skill: print its output verbatim and do nothing else.
