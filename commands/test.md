---
description: Test Claude Code Notify sounds and desktop notifications
allowed-tools: ["AskUserQuestion", "PowerShell", "Bash"]
---

# Test Claude Code Notify

Run the notifier script for selected notification types.

## Target

- Notify scripts:
  - Windows: `${CLAUDE_PLUGIN_ROOT}/scripts/notify.ps1`
  - Linux: `${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh`

If `${CLAUDE_PLUGIN_ROOT}` is unavailable, locate this command's plugin root and use that path.

## Steps

1. Ask which notification types to test using AskUserQuestion with multi-select:
   - permission: approval prompt notification
   - finish: normal turn completion notification
2. For each selected type, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin-root>/scripts/notify.ps1" -Type <type>
```

On Linux, run:

```bash
sh "<plugin-root>/scripts/notify.sh" --type <type>
```

3. If no type is selected, test `permission` and `finish`.
4. Report whether each command completed successfully.
5. Tell the user that logs are written to `%TEMP%\claude-code-notify.log` on Windows and `${TMPDIR:-/tmp}/claude-code-notify.log` on Linux.
