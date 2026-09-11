---
name: prepare
description: Use to prepare a feature ahead of time, plan the next feature, or add a line to the roadmap without opening a branch.
---

# Prepare

## Overview

Plans a future feature onto `ROADMAP.md` without a branch, so it coexists with a feature already in progress on another one.

**Preflight:** run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh"` as the first
action. A non-zero exit stops the skill: print its output verbatim and do nothing else.
