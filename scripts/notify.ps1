param(
    [ValidateSet('permission', 'complete', 'subagent', 'error')]
    [string]$Type = 'complete',

    [string]$LogPath = "$env:TEMP\claude-code-notify.log",

    [string]$ConfigPath = ""
)

$ErrorActionPreference = 'Stop'

function Write-NotifierLog {
    param(
        [string]$Message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff zzz'
    $line = "[$timestamp] [$Type] $Message"

    try {
        Add-Content -Path $LogPath -Value $line -Encoding UTF8
    } catch {
    }
}

function Get-ConfigBoolean {
    param(
        [object]$Config,
        [string]$Name,
        [bool]$Default
    )

    if ($null -eq $Config) {
        return $Default
    }

    $property = $Config.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        return $Default
    }

    return [bool]$property.Value
}

function Get-ConfigInteger {
    param(
        [object]$Config,
        [string]$Name,
        [int]$Default
    )

    if ($null -eq $Config) {
        return $Default
    }

    $property = $Config.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        return $Default
    }

    try {
        return [Math]::Min(4500, [Math]::Max(250, [int]$property.Value))
    } catch {
        return $Default
    }
}

function Get-TypeValue {
    param(
        [object]$Container,
        [string]$TypeName,
        [string]$Default
    )

    if ($null -eq $Container) {
        return $Default
    }

    $property = $Container.PSObject.Properties[$TypeName]
    if ($null -eq $property -or [string]::IsNullOrWhiteSpace([string]$property.Value)) {
        return $Default
    }

    return [string]$property.Value
}

function Play-WavFile {
    param(
        [string]$Path,
        [int]$MaxMilliseconds
    )

    Write-NotifierLog "playing wav for up to $MaxMilliseconds ms"
    $player = New-Object System.Media.SoundPlayer $Path
    $player.Play()
    Start-Sleep -Milliseconds $MaxMilliseconds
    $player.Stop()
    Write-NotifierLog "wav playback window finished"
}

function Play-Mp3File {
    param(
        [string]$Path,
        [int]$MaxMilliseconds
    )

    Write-NotifierLog "playing mp3 for up to $MaxMilliseconds ms"
    $player = $null

    try {
        $player = New-Object -ComObject WMPlayer.OCX
        $player.URL = $Path
        $player.controls.play()

        $deadline = (Get-Date).AddMilliseconds($MaxMilliseconds)
        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Milliseconds 100
            if ($player.playState -eq 1 -or $player.playState -eq 8) {
                break
            }
        }

        $player.controls.stop()
        Write-NotifierLog "mp3 playback window finished"
    } finally {
        if ($null -ne $player) {
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($player) | Out-Null
        }
    }
}

function Show-ToastNotification {
    param(
        [string]$Title,
        [string]$Message
    )

    try {
        Write-NotifierLog "showing toast"
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

        $escapedTitle = [System.Security.SecurityElement]::Escape($Title)
        $escapedMessage = [System.Security.SecurityElement]::Escape($Message)
        $xml = @"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <text>$escapedTitle</text>
      <text>$escapedMessage</text>
    </binding>
  </visual>
</toast>
"@

        $document = New-Object Windows.Data.Xml.Dom.XmlDocument
        $document.LoadXml($xml)
        $toast = [Windows.UI.Notifications.ToastNotification]::new($document)
        $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('ClaudeCode.Notify')
        $notifier.Show($toast)
        Write-NotifierLog "toast requested successfully"
    } catch {
        Write-NotifierLog "toast failed: $($_.Exception.Message)"
    }
}

try {
    Write-NotifierLog "started; pid=$PID; cwd=$(Get-Location)"

    $repoRoot = Split-Path -Parent $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Join-Path $repoRoot 'config\notifier.json'
    }

    $config = $null
    Write-NotifierLog "config path: $ConfigPath"
    if (Test-Path $ConfigPath) {
        try {
            $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
            Write-NotifierLog "config loaded"
        } catch {
            Write-NotifierLog "config failed to load: $($_.Exception.Message)"
        }
    } else {
        Write-NotifierLog "config not found; using defaults"
    }

    $defaultSounds = @{
        permission = 'C:\Windows\Media\Windows Notify System Generic.wav'
        complete = 'C:\Windows\Media\Windows Notify Calendar.wav'
        subagent = 'C:\Windows\Media\Windows Notify Messaging.wav'
        error = 'C:\Windows\Media\Windows Critical Stop.wav'
    }

    $defaultToastTitles = @{
        permission = 'Claude Code needs permission'
        complete = 'Claude Code finished'
        subagent = 'Claude Code subagent finished'
        error = 'Claude Code notifier error'
    }

    $defaultToastMessages = @{
        permission = 'A command is waiting for your approval.'
        complete = 'Claude finished responding.'
        subagent = 'A subagent task finished.'
        error = 'The notifier handled an error event.'
    }

    $soundEnabled = Get-ConfigBoolean -Config $config -Name 'soundEnabled' -Default $true
    $toastEnabled = Get-ConfigBoolean -Config $config -Name 'toastEnabled' -Default $false
    $maxSoundMilliseconds = Get-ConfigInteger -Config $config -Name 'maxSoundMilliseconds' -Default 3000
    $soundPath = Get-TypeValue -Container $config.sounds -TypeName $Type -Default $defaultSounds[$Type]
    $toastTitle = Get-TypeValue -Container $config.toastTitles -TypeName $Type -Default $defaultToastTitles[$Type]
    $toastMessage = Get-TypeValue -Container $config.toastMessages -TypeName $Type -Default $defaultToastMessages[$Type]

    Write-NotifierLog "sound enabled: $soundEnabled; toast enabled: $toastEnabled; max sound ms: $maxSoundMilliseconds"

    if ($toastEnabled) {
        Show-ToastNotification -Title $toastTitle -Message $toastMessage
    }

    if (-not $soundEnabled) {
        Write-NotifierLog "sound disabled"
        exit 0
    }

    Write-NotifierLog "selected sound path: $soundPath"
    if ($soundPath -and (Test-Path $soundPath)) {
        $extension = [System.IO.Path]::GetExtension($soundPath).ToLowerInvariant()
        Write-NotifierLog "sound extension: $extension"

        if ($extension -eq '.wav') {
            Play-WavFile -Path $soundPath -MaxMilliseconds $maxSoundMilliseconds
            exit 0
        }

        if ($extension -eq '.mp3') {
            Play-Mp3File -Path $soundPath -MaxMilliseconds $maxSoundMilliseconds
            exit 0
        }

        Write-NotifierLog "unsupported sound extension; falling back to Console.Beep"
    } else {
        Write-NotifierLog "sound missing; falling back to Console.Beep"
    }

    [console]::beep(880, [Math]::Min($maxSoundMilliseconds, 1000))
    Write-NotifierLog "played fallback beep successfully"
    exit 0
} catch {
    Write-NotifierLog "failed: $($_.Exception.Message)"
    exit 1
}
