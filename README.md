# Claude Code Notify

Windows-first Claude Code plugin that plays a sound and can optionally show a Windows toast when Claude Code needs your permission or finishes a response.

## What it does

- Plays a permission sound when Claude Code shows a permission confirmation prompt.
- Plays a completion sound every time Claude finishes a turn.
- Plays a subagent sound every time a subagent finishes.
- Optionally shows Windows toast notifications.
- Supports built-in Windows WAV sounds by default.
- Supports custom `.wav` and `.mp3` sound paths through optional JSON config.
- Caps playback duration so long audio files do not block the hook forever.
- Writes a local log for every notifier invocation.
- Requires no external PowerShell modules.

## Files

```text
.claude-plugin/plugin.json                 Plugin metadata
config/notifier.json                       Built-in default sound/toast config
config/notifier.example.json               Reference custom sound/toast config example
hooks/hooks.json                           Claude Code hook configuration
scripts/notify.ps1                         Windows sound/toast notification script
install/install-local-marketplace.ps1      Local marketplace installer helper
tests/smoke-test.ps1                       Deterministic local sound/log test
```

## Install options

### Option 1: local development run

Use this while developing the plugin:

```powershell
claude --plugin-dir "E:/claude-plugins/claude-code-notify"
```

Some Claude Code plugin docs use `cc --plugin-dir`; use whichever command starts Claude Code in your environment.

### Option 2: local marketplace copy

Copy this plugin into a user-local marketplace layout:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "E:/claude-plugins/claude-code-notify/install/install-local-marketplace.ps1" -Force
```

The script creates:

```text
%USERPROFILE%\.claude\plugins\marketplaces\local-claude-plugins\
  .claude-plugin\marketplace.json
  plugins\claude-code-notify\
```

Then add or enable that local marketplace in Claude Code and install:

```text
/plugin install claude-code-notify@local-claude-plugins
```

### Option 3: project-level manual hooks

If you do not want to install the plugin yet, copy the `hooks` blocks from `hooks/hooks.json` into a project `.claude/settings.json` or user `~/.claude/settings.json`, replacing `${CLAUDE_PLUGIN_ROOT}` with this repository path:

```text
E:/claude-plugins/claude-code-notify
```

Plugin installation is preferred because `${CLAUDE_PLUGIN_ROOT}` stays portable.

## Configuration

The plugin reads this file automatically on every hook invocation:

```text
config/notifier.json
```

You do not need to pass `-ConfigPath` during normal Claude Code use. Install or start the plugin, then edit `config/notifier.json` if you want different behavior.

Example:

```json
{
  "soundEnabled": true,
  "toastEnabled": true,
  "maxSoundMilliseconds": 2500,
  "sounds": {
    "permission": "D:/sounds/permission.wav",
    "complete": "D:/sounds/done.mp3",
    "subagent": "C:/Windows/Media/Windows Notify Messaging.wav",
    "error": "C:/Windows/Media/Windows Critical Stop.wav"
  },
  "toastTitles": {
    "permission": "Claude Code needs permission",
    "complete": "Claude Code finished",
    "subagent": "Claude Code subagent finished",
    "error": "Claude Code notifier error"
  },
  "toastMessages": {
    "permission": "A command is waiting for your approval.",
    "complete": "Claude finished responding.",
    "subagent": "A subagent task finished.",
    "error": "The notifier handled an error event."
  }
}
```

Supported sound formats:

- `.wav`: played with `System.Media.SoundPlayer`.
- `.mp3`: played with Windows Media Player COM if available.

Keep notification audio short. The script enforces `maxSoundMilliseconds` and clamps it to 250-4500 ms, so a long song will only play briefly and stay within the hook timeout window.

You can disable sound and keep toast only:

```json
{
  "soundEnabled": false,
  "toastEnabled": true,
  "maxSoundMilliseconds": 2500
}
```

Toast support is best-effort because Windows notification identity rules can vary by terminal/session. Toast failures are logged and do not fail the hook.

## Test flow

### 1. Test sound without Claude Code

Run the deterministic smoke test from any PowerShell window:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "E:/claude-plugins/claude-code-notify/tests/smoke-test.ps1"
```

This plays all supported notification types and prints recent log lines.

The smoke test automatically uses `config/notifier.json` when it exists.

You can also test with a different config file for development:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "E:/claude-plugins/claude-code-notify/tests/smoke-test.ps1" -ConfigPath "E:/claude-plugins/claude-code-notify/config/notifier.json"
```

You can also test one notification directly:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "E:/claude-plugins/claude-code-notify/scripts/notify.ps1" -Type permission
powershell -NoProfile -ExecutionPolicy Bypass -File "E:/claude-plugins/claude-code-notify/scripts/notify.ps1" -Type complete
powershell -NoProfile -ExecutionPolicy Bypass -File "E:/claude-plugins/claude-code-notify/scripts/notify.ps1" -Type subagent
```

### 2. Check logs

Default log path:

```text
%TEMP%\claude-code-notify.log
```

Read it with:

```powershell
Get-Content "$env:TEMP\claude-code-notify.log" -Tail 50
```

Each hook invocation should write lines like:

```text
[2026-06-18 20:00:00.000 +08:00] [complete] started; pid=12345; cwd=...
[2026-06-18 20:00:00.010 +08:00] [complete] config path: ...\config\notifier.json
[2026-06-18 20:00:00.020 +08:00] [complete] selected sound path: C:\Windows\Media\Windows Notify Calendar.wav
[2026-06-18 20:00:03.030 +08:00] [complete] wav playback window finished
```

### 3. Test hooks inside Claude Code

Start Claude Code with the plugin:

```powershell
claude --plugin-dir "E:/claude-plugins/claude-code-notify" --debug
```

Then use fixed prompts:

```text
Say exactly: hook completion test
```

Expected result: `Stop` fires after the response and the complete sound plays.

For permission prompt testing, run Claude Code in a permission mode that asks before tools. One reliable flow is:

```text
/permissions
```

Add ask rules for shell/Bash/PowerShell, then ask:

```text
Use the shell tool to run this exact command: powershell -NoProfile -Command "Get-Location"
```

Expected result: Claude Code requests permission for the shell/tool call, `PermissionRequest` fires, and the permission sound plays. After the response finishes, the completion sound also plays.

After each test, check the log file to confirm whether the notifier script ran.

## Hook events

The plugin uses these Claude Code hook events:

- `PermissionRequest`
- `Notification` with matcher `permission_prompt`
- `Stop`
- `TaskCompleted`
- `SubagentStop`

`PermissionRequest` is the primary hook for the visible command approval prompt. `Notification(permission_prompt)` is kept as additional coverage.

The intended behavior is to alert every time these events occur. There is no cooldown or suppression by design.

## Troubleshooting

- If no sound plays, run `tests/smoke-test.ps1` outside Claude Code first.
- If the smoke test logs success but you hear nothing, check Windows volume mixer and output device.
- If no log lines appear during Claude Code tests, the hook did not run or the plugin is not loaded.
- If custom config is ignored, confirm it is named `config/notifier.json` or pass `-ConfigPath` explicitly.
- If custom sound paths fail, use absolute paths and forward slashes, for example `D:/sounds/done.mp3`.
- If an MP3 does not play, Windows Media Player COM may be unavailable; use WAV for the most reliable behavior.
- If toast does not appear, check the log for `toast failed`; sound alerts should still work independently.
- If log lines show `sound missing`, the script should still fall back to `Console.Beep` unless sound is disabled.
- If PowerShell execution is blocked, keep using `-ExecutionPolicy Bypass` for the local process.
- Use `claude --debug` to inspect hook execution when testing inside Claude Code.

## Next ideas

- Add macOS and Linux notifier scripts.
- Add packaged short default sounds.
