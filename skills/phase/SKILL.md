---
name: phase
description: Use to run the plan's phases, continue a feature already branched and planned, or execute one phase by number.
---

# Phase

## Overview

Runs the plan's remaining phases in order, or one phase by number, each sub-phase gated by tests, the project's own check and test commands, and a self-check against the plan.

**Preflight:** run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh"` as the first
action. A non-zero exit stops the skill: print its output verbatim and do nothing else.
