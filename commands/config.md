---
description: Configure Claude Code Notify interactively
allowed-tools: ["Read", "Edit", "AskUserQuestion", "PowerShell", "Bash"]
---

# Configure Claude Code Notify

Interactively configure Claude Code Notify settings stored in `config/notifier.json`.

## Target files

- Plugin config: `${CLAUDE_PLUGIN_ROOT}/config/notifier.json`
- Notify scripts:
  - Windows: `${CLAUDE_PLUGIN_ROOT}/scripts/notify.ps1`
  - Linux: `${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh`

If `${CLAUDE_PLUGIN_ROOT}` is unavailable, locate this command's plugin root and use that path.

## Notification types

Claude Code Notify only exposes two user-facing events:

- `permission`: Claude Code needs user approval or confirmation.
- `finish`: Claude Code finished a response or task turn.

Only offer these two notification choices.

## Steps

### 1. Read current config

Read `config/notifier.json` and extract:

- `soundEnabled`
- `toastEnabled`
- `maxSoundMilliseconds`
- `sounds.permission`
- `sounds.finish`

If the file is missing, create it from these defaults:

```json
{
  "soundEnabled": true,
  "toastEnabled": false,
  "maxSoundMilliseconds": 3000,
  "sounds": {
    "permission": "C:/Windows/Media/Windows Notify System Generic.wav",
    "finish": "C:/Windows/Media/Windows Notify Calendar.wav"
  },
  "toastTitles": {
    "permission": "Claude Code needs permission",
    "finish": "Claude Code finished"
  },
  "toastMessages": {
    "permission": "A command is waiting for your approval.",
    "finish": "Claude finished responding."
  }
}
```

### 2. Ask what to configure

Use AskUserQuestion:

```json
{
  "questions": [
    {
      "question": "What would you like to change in Claude Code Notify?",
      "header": "Notify",
      "multiSelect": false,
      "options": [
        {
          "label": "Sound/desktop",
          "description": "Turn sound or desktop notifications on or off."
        },
        {
          "label": "Preset sounds",
          "description": "Choose a built-in Windows sound preset."
        },
        {
          "label": "Custom sound",
          "description": "Set a local sound file for permission or finish."
        },
        {
          "label": "Test notify",
          "description": "Play permission or finish to verify the current config."
        }
      ]
    }
  ]
}
```

### 3. Apply the selected flow

#### Sound/desktop notification

Ask for the desired mode:

- Sound only: `soundEnabled=true`, `toastEnabled=false`
- Desktop notification only: `soundEnabled=false`, `toastEnabled=true`
- Sound and desktop notification: `soundEnabled=true`, `toastEnabled=true`
- Disable both: `soundEnabled=false`, `toastEnabled=false`

`toastEnabled` is the config key for Windows toast notifications and Linux desktop notifications.

Edit only those boolean fields in `config/notifier.json`.

#### Preset sounds

Offer these presets:

- Default: balanced Windows notification sounds
- Quiet: softer Windows notification sounds
- Alert: more noticeable permission sound
- Desktop only: disables sound and enables desktop notifications

Preset values:

```json
{
  "default": {
    "soundEnabled": true,
    "toastEnabled": false,
    "sounds": {
      "permission": "C:/Windows/Media/Windows Notify System Generic.wav",
      "finish": "C:/Windows/Media/Windows Notify Calendar.wav"
    }
  },
  "quiet": {
    "soundEnabled": true,
    "toastEnabled": false,
    "sounds": {
      "permission": "C:/Windows/Media/Windows Notify.wav",
      "finish": "C:/Windows/Media/Windows Notify Email.wav"
    }
  },
  "alert": {
    "soundEnabled": true,
    "toastEnabled": false,
    "sounds": {
      "permission": "C:/Windows/Media/Windows Exclamation.wav",
      "finish": "C:/Windows/Media/Windows Notify Calendar.wav"
    }
  },
  "toast-only": {
    "soundEnabled": false,
    "toastEnabled": true
  }
}
```

Only write sound paths that exist on the user's machine. If a preset file is missing, keep the existing value for that event and tell the user which sound was skipped.

#### Custom sound

Ask which event to configure:

- permission: approval prompts; should be the most noticeable
- finish: normal turn completion; should be pleasant and short

Then ask the user for a local sound file path. Validate that:

- The path exists and is a regular file.
- On Windows, the extension is `.wav` or `.mp3`.
- On Linux, prefer `.wav`; `.mp3` works when a compatible player such as `ffplay` or `mpg123` is available.
- Files larger than 20 MB should be rejected unless the user explicitly confirms copying them.

Copy the selected file into `${CLAUDE_PLUGIN_ROOT}/config/sounds/` as `permission.<ext>` or `finish.<ext>`, then save the relative path such as `config/sounds/permission.wav`. Use forward slashes in JSON paths. Update only the selected `sounds.<event>` value.

After saving, run a test for that event.

#### Test notify

Ask which notification types to test. Then run the platform-appropriate command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin-root>/scripts/notify.ps1" -Type <type>
```

```bash
sh "<plugin-root>/scripts/notify.sh" --type <type>
```

Valid types: `permission`, `finish`.

### 4. Confirm

Briefly report:

- What changed
- Which config file was updated
- Whether a test was run

Keep the response short.
