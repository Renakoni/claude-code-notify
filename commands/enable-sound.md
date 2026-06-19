---
description: Enable Claude Code Notify sound alerts
allowed-tools: ["Read", "Edit"]
---

# Enable Claude Code Notify Sound

Enable sound alerts in `config/notifier.json`.

## Steps

1. Read `${CLAUDE_PLUGIN_ROOT}/config/notifier.json`.
2. Change the top-level field:

```json
"soundEnabled": true
```

3. Do not change `toastEnabled`.
4. Confirm briefly that sound alerts are enabled.

If `${CLAUDE_PLUGIN_ROOT}` is unavailable, locate this command's plugin root and use that path.
