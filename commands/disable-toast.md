---
description: Disable Claude Code Notify desktop notifications
allowed-tools: ["Read", "Edit"]
---

# Disable Claude Code Notify Desktop Notifications

Disable desktop notifications in `config/notifier.json` while leaving sound settings unchanged.

## Steps

1. Read `${CLAUDE_PLUGIN_ROOT}/config/notifier.json`.
2. Change the top-level field:

```json
"toastEnabled": false
```

3. Do not change `soundEnabled`.
4. Confirm briefly that desktop notifications are disabled.

If `${CLAUDE_PLUGIN_ROOT}` is unavailable, locate this command's plugin root and use that path.
