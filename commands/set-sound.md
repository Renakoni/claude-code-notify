---
description: Set a custom notification sound for Claude Code Notify
allowed-tools: ["Read", "Edit", "AskUserQuestion", "PowerShell", "Bash"]
---

# Set Claude Code Notify Custom Sound

Set a custom notification sound file for one notification event in `config/notifier.json`. By default, copy the source audio into the plugin-managed `config/sounds/` directory and save a relative path so the notification keeps working if the original file is moved or deleted.

Supported formats depend on the platform/player:

- Windows: `.wav` and `.mp3`.
- Linux: `.wav` is safest; `.mp3` works when a compatible player such as `ffplay` or `mpg123` is available.

## Target

- Config file: `${CLAUDE_PLUGIN_ROOT}/config/notifier.json`
- Managed sound directory: `${CLAUDE_PLUGIN_ROOT}/config/sounds/`
- Notify scripts:
  - Windows: `${CLAUDE_PLUGIN_ROOT}/scripts/notify.ps1`
  - Linux: `${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh`

If `${CLAUDE_PLUGIN_ROOT}` is unavailable, locate this command's plugin root and use that path.

## Steps

### 1. Read current config

Read `config/notifier.json` and preserve all existing fields except the one selected `sounds.<event>` value.

### 2. Ask which event to configure

Use AskUserQuestion:

```json
{
  "questions": [
    {
      "question": "Which notification sound do you want to customize?",
      "header": "Event",
      "multiSelect": false,
      "options": [
        {
          "label": "Permission",
          "description": "Approval prompts. This should be the most noticeable sound."
        },
        {
          "label": "Finish",
          "description": "Normal Claude turn completion. This should be pleasant and short."
        }
      ]
    }
  ]
}
```

Map labels to JSON keys:

- Permission -> `permission`
- Finish -> `finish`

### 3. Ask for the file path

Ask the user to provide a local sound file path. Accept Windows backslashes or forward slashes.

Validate on Windows with PowerShell:

- `Test-Path -PathType Leaf` must be true.
- Extension must be `.wav` or `.mp3`.
- File size should be reasonable for a notification sound; reject files larger than 20 MB unless the user explicitly confirms they still want to copy it.

Validate on Linux with Bash:

- `[ -f "$path" ]` must be true.
- Extension should be `.wav` or `.mp3`.
- File size should be reasonable for a notification sound; reject files larger than 20 MB unless the user explicitly confirms they still want to copy it.
- If the file is `.mp3`, check whether `ffplay` or `mpg123` is available; if neither is available, warn that Linux playback may fall back to the terminal bell.

If validation fails, do not edit the config. Tell the user the specific problem. If the extension is unusual but the user confirms their platform player supports it, allow it.

### 4. Save

Copy the source file into `${CLAUDE_PLUGIN_ROOT}/config/sounds/` using a deterministic event filename:

```text
config/sounds/permission.<ext>
config/sounds/finish.<ext>
```

Overwrite the previous managed sound for the selected event if it exists. Preserve unrelated sound files.

Write the relative copied path to `config/notifier.json`:

```json
"sounds": {
  "permission": "config/sounds/permission.wav",
  "finish": "config/sounds/finish.mp3"
}
```

Convert backslashes to forward slashes before writing JSON. Only update the selected `sounds.<event>` value. Do not change other fields unless `soundEnabled` is false; if sound is disabled, ask whether to enable it now.

If the user explicitly asks not to copy the file, allow saving the original absolute path as an advanced option, but explain that moving or deleting the source file will break playback.

### 5. Test

After saving, run the platform-appropriate command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin-root>/scripts/notify.ps1" -Type <event>
```

```bash
sh "<plugin-root>/scripts/notify.sh" --type <event>
```

### 6. Confirm

Report:

- Which event was changed
- The saved path
- Whether the test command succeeded

Keep the response short.
