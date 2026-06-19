# Claude Code Notify

> 让 Claude Code 在需要你回来操作时，真的提醒你。

Claude Code Notify 是一个 Claude Code 插件。当 Claude Code 需要权限确认，或者一轮回复完成时，它会播放提示音，也可以同时弹出桌面通知。

适合这些场景：

- 你把 Claude Code 放在后台跑任务，不想一直盯着终端。
- Claude Code 卡在权限确认时，你希望马上知道。
- 一轮任务结束后，你希望有明确提示。
- 你想给不同事件设置不同声音。

English documentation: [README.en.md](README.en.md)

## 安装

添加 marketplace：

```powershell
claude plugin marketplace add https://github.com/Renakoni/claude-code-notify.git
```

安装插件：

```powershell
claude plugin install claude-code-notify@claude-code-notify
```

安装后，在 Claude Code 里运行：

```text
/claude-code-notify:test
```

如果你能听到声音，说明插件已经正常工作。

## 功能

- 权限确认时提醒：`permission`
- 一轮回复完成时提醒：`finish`
- 支持声音提醒
- 支持桌面通知
- 支持自定义 WAV / MP3
- 自定义声音会复制到插件目录，避免原文件被移动或删除后失效
- 播放窗口默认 3000ms，防止长音频阻塞 hook
- 每次触发都会写日志，方便排查问题

Claude Code Notify 只保留两个通知事件：

| 事件 | 触发时机 | 目的 |
| --- | --- | --- |
| `permission` | Claude Code 请求权限确认 | 提醒你回来批准或拒绝 |
| `finish` | Claude Code 完成一轮回复 | 提醒你任务已经结束 |

## 常用命令

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

推荐第一次安装后按这个顺序测试：

1. 运行 `/claude-code-notify:test`
2. 如果声音正常，运行 `/claude-code-notify:config` 调整声音或桌面通知
3. 如果想换声音，运行 `/claude-code-notify:set-sound`

## 自定义声音

使用：

```text
/claude-code-notify:set-sound
```

你可以分别设置：

- `permission`：权限确认提示音，建议更明显一点
- `finish`：任务完成提示音，建议短促、舒适一点

支持格式：

| 系统 | 支持情况 |
| --- | --- |
| Windows | `.wav`、`.mp3` |
| Linux | `.wav` 最稳；`.mp3` 依赖 `ffplay` 或 `mpg123` |

设置后，插件会使用你选择的声音作为对应事件的提示音。

## 音频长度

插件不限制源文件长度，但会限制实际播放窗口。

默认配置：

```json
{
  "maxSoundMilliseconds": 3000
}
```

合法范围：

```text
250-4500 ms
```

行为示例：

| 音频长度 | 默认播放结果 |
| --- | --- |
| 0.2 秒 | 播放 0.2 秒 |
| 2.5 秒 | 播放 2.5 秒 |
| 3 秒 | 播放 3 秒 |
| 20 秒 | 只播放前 3 秒 |

建议使用 0.3-3 秒的短音频。长音频不会被拒绝，但只会播放开头部分。

## 桌面通知

可以开启桌面通知：

```text
/claude-code-notify:enable-toast
```

也可以关闭：

```text
/claude-code-notify:disable-toast
```

桌面通知是 best-effort：

| 系统 | 实现 |
| --- | --- |
| Windows | Toast notification |
| Linux | `notify-send` |

如果系统通知被关闭、勿扰模式开启，或者 Linux 没有桌面通知环境，声音仍然可以继续工作。

## 配置文件

插件每次触发 hook 时都会读取：

```text
config/notifier.json
```

默认配置示例：

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

一般不需要手动改这个文件，优先使用插件命令配置。

## 工作原理

插件只绑定两个 Claude Code hook：

| Claude Code hook | 插件事件 |
| --- | --- |
| `PermissionRequest` | `permission` |
| `Stop` | `finish` |

入口脚本是：

```text
scripts/notify.js
```

它会根据平台分发到：

| 系统 | 脚本 |
| --- | --- |
| Windows | `scripts/notify.ps1` |
| Linux | `scripts/notify.sh` |

## 排查问题

### 没有声音

1. 先运行 `/claude-code-notify:test`
2. 检查系统音量和输出设备
3. 查看日志是否有记录
4. Windows 确认声音文件存在
5. Linux 确认安装了 `paplay`、`aplay`、`ffplay` 或 `mpg123`

### 没有桌面通知

1. 确认 `toastEnabled` 是 `true`
2. Windows 检查系统通知权限和勿扰模式
3. Linux 检查是否安装并可用 `notify-send`
4. 查看日志确认 hook 是否触发

### 插件没有触发

1. 确认插件已启用：打开 `/plugin`
2. 运行 `/claude-code-notify:test`
3. 使用 `claude --debug` 查看 hook 执行情况
4. 查看日志文件是否有新记录
