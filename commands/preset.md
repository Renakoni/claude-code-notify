---
description: Apply a Claude Code Notify sound preset
allowed-tools: ["Read", "Edit", "AskUserQuestion", "PowerShell", "Bash"]
---

# Apply Claude Code Notify Preset

Apply a user-friendly notification preset to `config/notifier.json`.

## Presets

- Default: balanced Windows notification sounds.
- Quiet: softer Windows notification sounds.
- Alert: more noticeable permission sound.
- Desktop only: disables sound and enables desktop notifications.

Sound presets use Windows built-in media paths. On Linux, offer Desktop only or direct the user to `/claude-code-notify:set-sound` for local sound files.

## Target

- Config file: `${CLAUDE_PLUGIN_ROOT}/config/notifier.json`

If `${CLAUDE_PLUGIN_ROOT}` is unavailable, locate this command's plugin root and use that path.

## Steps

1. Read the current config.
2. Ask which preset to apply:

```json
{
  "questions": [
    {
      "question": "Which Claude Code Notify preset do you want to apply?",
      "header": "Preset",
      "multiSelect": false,
      "options": [
        {
          "label": "Default",
          "description": "Balanced Windows sounds for normal use."
        },
        {
          "label": "Quiet",
          "description": "Softer sounds for users who dislike loud alerts."
        },
        {
          "label": "Alert",
          "description": "More noticeable permission alerts."
        },
        {
          "label": "Desktop only",
          "description": "Disable sounds and use desktop notifications."
        }
      ]
    }
  ]
}
```

3. Apply the selected preset.

## Preset values

### Default

```json
{
  "soundEnabled": true,
  "toastEnabled": false,
  "sounds": {
    "permission": "C:/Windows/Media/Windows Notify System Generic.wav",
    "finish": "C:/Windows/Media/Windows Notify Calendar.wav"
  }
}
```

### Quiet

```json
{
  "soundEnabled": true,
  "toastEnabled": false,
  "sounds": {
    "permission": "C:/Windows/Media/Windows Notify.wav",
    "finish": "C:/Windows/Media/Windows Notify Email.wav"
  }
}
```

### Alert

```json
{
  "soundEnabled": true,
  "toastEnabled": false,
  "sounds": {
    "permission": "C:/Windows/Media/Windows Exclamation.wav",
    "finish": "C:/Windows/Media/Windows Notify Calendar.wav"
  }
}
```

### Desktop only

```json
{
  "soundEnabled": false,
  "toastEnabled": true
}
```

## Validation

Before writing Windows preset sound paths, use PowerShell `Test-Path` on Windows to confirm they exist. On Linux, do not write Windows preset sound paths; use Desktop only or ask the user to choose a local sound with `/claude-code-notify:set-sound`. If a preset sound file is missing, keep the existing value for that event and mention it in the final response.

## Confirm

Report the applied preset and suggest running `/claude-code-notify:test`.
