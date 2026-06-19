---
description: Disable Claude Code Notify sound alerts
allowed-tools: ["Read", "Edit"]
---

# Disable Claude Code Notify Sound

Disable sound alerts in `config/notifier.json` while leaving toast settings unchanged.

## Steps

1. Read `${CLAUDE_PLUGIN_ROOT}/config/notifier.json`.
2. Change the top-level field:

```json
"soundEnabled": false
```

3. Do not change `toastEnabled`.
4. Confirm briefly that sound alerts are disabled.

If `${CLAUDE_PLUGIN_ROOT}` is unavailable, locate this command's plugin root and use that path.
