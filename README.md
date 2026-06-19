# Claude Code Notify

Claude Code plugin that plays a sound and can optionally show a desktop notification when Claude Code needs your permission or finishes a response.

## What it does

- Plays a permission sound when Claude Code shows a permission confirmation prompt.
- Plays a finish sound every time Claude finishes a turn.
- Optionally shows desktop notifications.
- Supports Windows and Linux with platform-specific fallbacks.
- Supports custom local sound paths through `config/notifier.json`.
- Caps playback duration so long audio files do not block the hook forever.
- Copies custom sounds into plugin-managed storage so playback does not depend on the original source file.
- Writes a local log for every notifier invocation.

## Notification types

Claude Code Notify intentionally exposes only two user-facing events:

- `permission`: Claude Code needs user approval or confirmation.
- `finish`: Claude Code finished a response or task turn.

There is no cooldown, debounce, or suppression. The goal is to alert every time user attention is needed or a turn finishes.

## Install

Add the marketplace:

```powershell
claude plugin marketplace add https://github.com/Renakoni/claude-code-notify.git
```

Install the plugin:

```powershell
claude plugin install claude-code-notify@claude-code-notify
```

Then test inside Claude Code:

```text
/claude-code-notify:test
```

Configure interactively:

```text
/claude-code-notify:config
```

## Files

```text
.claude-plugin/plugin.json                 Plugin metadata
.claude-plugin/marketplace.json            Marketplace metadata
config/notifier.json                       Built-in default config
config/sounds/                             Managed custom sound storage
hooks/hooks.json                           Claude Code hook configuration
scripts/notify.js                          Cross-platform launcher
scripts/notify.ps1                         Windows notifier
scripts/notify.sh                          Linux notifier
scripts/notify.cmd                         Windows wrapper for manual use
tests/smoke-test.ps1                       Windows smoke test
tests/smoke-test.sh                        Linux smoke test
```

## Configuration

The plugin reads this file automatically on every hook invocation:

```text
config/notifier.json
```

Example:

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

`toastEnabled` is the config key for desktop notifications:

- Windows: toast notification.
- Linux: `notify-send` when available.

Supported sound behavior:

- Windows: `.wav` through `System.Media.SoundPlayer`; `.mp3` through Windows Media Player COM when available.
- Linux: configured sound through `paplay`, `aplay`, `ffplay`, or `mpg123`; terminal bell fallback.

Keep notification audio short. The script enforces `maxSoundMilliseconds` and clamps it to 250-4500 ms. The default is 3000 ms: shorter audio ends naturally when the player reports completion, while longer audio is stopped at the playback cap. Use 0.3-3 second sounds for best results.

Custom sounds set through `/claude-code-notify:set-sound` are copied into `config/sounds/` and stored in `config/notifier.json` as relative paths such as `config/sounds/permission.wav`. Existing absolute paths still work, but copied relative paths are more robust because playback does not depend on the original source file remaining in place.

## Slash commands

```text
/claude-code-notify:test
/claude-code-notify:config
/claude-code-notify:preset
/claude-code-notify:set-sound
/claude-code-notify:enable-sound
/claude-code-notify:disable-sound
/claude-code-notify:enable-toast
/claude-code-notify:disable-toast
```

The `enable-toast` and `disable-toast` commands control desktop notifications across platforms.

## Test flow

### Windows

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "E:/claude-plugins/claude-code-beep-notifier/tests/smoke-test.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "E:/claude-plugins/claude-code-beep-notifier/scripts/notify.ps1" -Type permission
powershell -NoProfile -ExecutionPolicy Bypass -File "E:/claude-plugins/claude-code-beep-notifier/scripts/notify.ps1" -Type finish
```

Log path:

```text
%TEMP%\claude-code-notify.log
```

### Linux

```bash
sh tests/smoke-test.sh
sh scripts/notify.sh --type permission
sh scripts/notify.sh --type finish
```

Log path:

```text
${TMPDIR:-/tmp}/claude-code-notify.log
```

### WSL2

WSL2 can partially test Linux shell logic, config loading, logs, and fallback behavior. It does not reliably prove native Linux desktop sound or desktop notification delivery unless WSLg/audio/notification bridges are configured.

## Hook events

The plugin uses only these Claude Code hook events:

- `PermissionRequest` -> `permission`
- `Stop` -> `finish`

The hook entrypoint is `scripts/notify.js`, which dispatches to `notify.ps1` on Windows and `notify.sh` on Linux.

## Troubleshooting

- If no sound plays, run the platform smoke test outside Claude Code first.
- If the smoke test logs success but you hear nothing, check system volume and output device.
- If no log lines appear during Claude Code tests, the hook did not run or the plugin is not loaded.
- If custom config is ignored, confirm it is named `config/notifier.json` inside the installed plugin.
- If custom sound paths fail, use absolute paths and forward slashes where possible.
- On Linux, install or enable a sound player such as `paplay`, `aplay`, `ffplay`, or `mpg123` for real audio playback.
- On Windows, toast delivery is best-effort and uses a registered AppUserModelID shortcut.
- Use `claude --debug` to inspect hook execution when testing inside Claude Code.
