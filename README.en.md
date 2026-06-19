# Claude Code Notify

> Get notified when Claude Code needs you back.

Claude Code Notify is a Claude Code plugin that plays a sound when Claude Code needs permission or finishes a response. It can also show desktop notifications.

Use it when:

- Claude Code is running in the background.
- A command is waiting for approval.
- A response or task turn has finished.
- You want different sounds for approval prompts and completion.

中文文档: [README.md](README.md)

## Install

Add the marketplace:

```powershell
claude plugin marketplace add https://github.com/Renakoni/claude-code-notify.git
```

Install the plugin:

```powershell
claude plugin install claude-code-notify@claude-code-notify
```

Then test it inside Claude Code:

```text
/claude-code-notify:test
```

If you hear the sounds, the plugin is working.

## Features

- Sound alert for permission prompts
- Sound alert when a Claude Code turn finishes
- Optional desktop notifications
- Custom WAV / MP3 sounds
- Custom sounds are copied into plugin-managed storage
- Playback window capped at 3000ms by default
- Local logs for troubleshooting

Claude Code Notify intentionally exposes only two user-facing events:

| Event | When it fires | Purpose |
| --- | --- | --- |
| `permission` | Claude Code asks for approval | Bring you back to approve or deny |
| `finish` | Claude Code finishes a response | Tell you the turn is done |

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

Recommended first run:

1. Run `/claude-code-notify:test`
2. Run `/claude-code-notify:config` to adjust sound and desktop notifications
3. Run `/claude-code-notify:set-sound` if you want custom sounds

## Custom sounds

Use:

```text
/claude-code-notify:set-sound
```

You can configure sounds separately for:

- `permission`: should be noticeable
- `finish`: should be short and pleasant

Supported formats:

| Platform | Support |
| --- | --- |
| Windows | `.wav`, `.mp3` |
| Linux | `.wav` is safest; `.mp3` requires `ffplay` or `mpg123` |

After setup, the plugin uses your selected file for that notification event.

## Audio length

Claude Code Notify does not reject long source audio files, but it limits the actual playback window.

Default:

```json
{
  "maxSoundMilliseconds": 3000
}
```

Allowed range:

```text
250-4500 ms
```

Default behavior:

| Audio length | Playback result |
| --- | --- |
| 0.2s | Plays 0.2s |
| 2.5s | Plays 2.5s |
| 3s | Plays 3s |
| 20s | Plays the first 3s |

For best results, use short sounds around 0.3-3 seconds.

## Desktop notifications

Enable desktop notifications:

```text
/claude-code-notify:enable-toast
```

Disable them:

```text
/claude-code-notify:disable-toast
```

Desktop notifications are best-effort:

| Platform | Implementation |
| --- | --- |
| Windows | Toast notification |
| Linux | `notify-send` |

If system notifications are disabled, Do Not Disturb is enabled, or the Linux desktop environment does not support notifications, sound alerts can still work.

## Configuration

The plugin reads this file on every hook invocation:

```text
config/notifier.json
```

Default example:

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

Most users should configure the plugin with slash commands instead of editing this file manually.

## How it works

The plugin uses only two Claude Code hook events:

| Claude Code hook | Plugin event |
| --- | --- |
| `PermissionRequest` | `permission` |
| `Stop` | `finish` |

The hook entrypoint is:

```text
scripts/notify.js
```

It dispatches by platform:

| Platform | Script |
| --- | --- |
| Windows | `scripts/notify.ps1` |
| Linux | `scripts/notify.sh` |

## Troubleshooting

### No sound

1. Run `/claude-code-notify:test`
2. Check system volume and output device
3. Check the log file
4. On Windows, confirm the sound file exists
5. On Linux, install or enable `paplay`, `aplay`, `ffplay`, or `mpg123`

### No desktop notification

1. Confirm `toastEnabled` is `true`
2. On Windows, check notification permissions and Do Not Disturb
3. On Linux, check whether `notify-send` is installed and usable
4. Check the log file to confirm the hook fired

### Plugin does not fire

1. Confirm the plugin is enabled in `/plugin`
2. Run `/claude-code-notify:test`
3. Run Claude Code with `claude --debug` to inspect hook execution
4. Check whether the log file receives new entries
