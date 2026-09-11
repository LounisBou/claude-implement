---
name: install
description: Check that the superpowers dependency is enabled and the working directory is a git repository
---

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh"
```

Report its verdict to the user verbatim: exit 0 means everything is ready, a non-zero
exit prints an `error:`/`fix:` pair naming the first problem found.
