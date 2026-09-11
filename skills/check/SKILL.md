---
name: check
description: Use to check a delivery, verify a phase, or check a commit range against the plan and the design.
---

# Check

## Overview

Verifies a delivery against the plan and the design on a given commit range, seven checks each with their evidence, and edits nothing.

**Preflight:** run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh"` as the first
action. A non-zero exit stops the skill: print its output verbatim and do nothing else.
