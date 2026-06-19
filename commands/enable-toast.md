---
description: Enable Claude Code Notify desktop notifications
allowed-tools: ["Read", "Edit"]
---

# Enable Claude Code Notify Desktop Notifications

Enable desktop notifications in `config/notifier.json`. This uses Windows toast notifications or Linux desktop notifications depending on the platform.

## Steps

1. Read `${CLAUDE_PLUGIN_ROOT}/config/notifier.json`.
2. Change the top-level field:

```json
"toastEnabled": true
```

3. Do not change `soundEnabled`.
4. Confirm briefly that desktop notifications are enabled.
5. Mention that desktop notification delivery is best-effort and failures are logged without breaking sound alerts.

If `${CLAUDE_PLUGIN_ROOT}` is unavailable, locate this command's plugin root and use that path.
