param(
    [ValidateSet('permission', 'finish')]
    [string]$Type = 'finish',

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

function Get-WavDurationMilliseconds {
    param(
        [string]$Path
    )

    try {
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            if ($stream.Length -lt 44) {
                return $null
            }

            $reader = New-Object System.IO.BinaryReader $stream
            $riff = [System.Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
            $reader.ReadUInt32() | Out-Null
            $wave = [System.Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
            if ($riff -ne 'RIFF' -or $wave -ne 'WAVE') {
                return $null
            }

            $byteRate = $null
            $dataSize = $null
            while ($stream.Position -le ($stream.Length - 8)) {
                $chunkId = [System.Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
                $chunkSize = [int]$reader.ReadUInt32()
                $chunkStart = $stream.Position

                if ($chunkId -eq 'fmt ' -and $chunkSize -ge 12) {
                    $reader.ReadUInt16() | Out-Null
                    $reader.ReadUInt16() | Out-Null
                    $reader.ReadUInt32() | Out-Null
                    $byteRate = [double]$reader.ReadUInt32()
                } elseif ($chunkId -eq 'data') {
                    $dataSize = [double]$chunkSize
                }

                $nextPosition = $chunkStart + $chunkSize
                if (($chunkSize % 2) -eq 1) {
                    $nextPosition++
                }
                if ($nextPosition -gt $stream.Length) {
                    break
                }
                $stream.Position = $nextPosition

                if ($null -ne $byteRate -and $null -ne $dataSize) {
                    break
                }
            }

            if ($null -eq $byteRate -or $byteRate -le 0 -or $null -eq $dataSize) {
                return $null
            }

            return [int][Math]::Ceiling(($dataSize / $byteRate) * 1000)
        } finally {
            $stream.Dispose()
        }
    } catch {
        return $null
    }
}

function Resolve-SoundPath {
    param(
        [string]$Path,
        [string]$Root
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path $Root ($Path -replace '/', '\')
}

function Play-WavFile {
    param(
        [string]$Path,
        [int]$MaxMilliseconds
    )

    $durationMilliseconds = Get-WavDurationMilliseconds -Path $Path
    $playMilliseconds = $MaxMilliseconds
    if ($null -ne $durationMilliseconds -and $durationMilliseconds -gt 0) {
        $playMilliseconds = [Math]::Min($MaxMilliseconds, $durationMilliseconds)
    }

    Write-NotifierLog "playing wav for up to $playMilliseconds ms"
    $player = New-Object System.Media.SoundPlayer $Path
    $player.Play()
    Start-Sleep -Milliseconds $playMilliseconds
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

function Ensure-ToastAppIdentity {
    $appId = 'ClaudeCode.Notify'
    $shortcutDirectory = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
    $shortcutPath = Join-Path $shortcutDirectory 'Claude Code Notify.lnk'

    try {
        if (-not (Test-Path $shortcutDirectory)) {
            New-Item -ItemType Directory -Force -Path $shortcutDirectory | Out-Null
        }

        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = (Get-Command powershell.exe).Source
        $shortcut.Arguments = '-NoProfile'
        $shortcut.WorkingDirectory = $PSScriptRoot
        $shortcut.WindowStyle = 7
        $shortcut.Description = 'Claude Code Notify'
        $shortcut.Save()
        $signature = @'
using System;
using System.Runtime.InteropServices;

public static class AppUserModelIdWriter
{
    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    public struct PropertyKey
    {
        public Guid fmtid;
        public uint pid;
    }

    [DllImport("shell32.dll", CharSet = CharSet.Unicode, PreserveSig = false)]
    private static extern void SHGetPropertyStoreFromParsingName(
        string pszPath,
        IntPtr pbc,
        uint flags,
        ref Guid riid,
        out IPropertyStore propertyStore);

    [ComImport]
    [Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IPropertyStore
    {
        void GetCount(out uint cProps);
        void GetAt(uint iProp, out PropertyKey pkey);
        void GetValue(ref PropertyKey key, out PropVariant pv);
        void SetValue(ref PropertyKey key, ref PropVariant pv);
        void Commit();
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct PropVariant
    {
        public ushort vt;
        public ushort wReserved1;
        public ushort wReserved2;
        public ushort wReserved3;
        public IntPtr p;
        public int p2;
    }

    public static void SetAppUserModelId(string shortcutPath, string appId)
    {
        Guid propertyStoreGuid = new Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99");
        IPropertyStore propertyStore;
        SHGetPropertyStoreFromParsingName(shortcutPath, IntPtr.Zero, 2, ref propertyStoreGuid, out propertyStore);

        PropertyKey appIdKey = new PropertyKey
        {
            fmtid = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"),
            pid = 5
        };

        PropVariant value = new PropVariant
        {
            vt = 31,
            p = Marshal.StringToCoTaskMemUni(appId)
        };

        try
        {
            propertyStore.SetValue(ref appIdKey, ref value);
            propertyStore.Commit();
        }
        finally
        {
            Marshal.FreeCoTaskMem(value.p);
            Marshal.ReleaseComObject(propertyStore);
        }
    }
}
'@

        if (-not ('AppUserModelIdWriter' -as [type])) {
            Add-Type -TypeDefinition $signature
        }

        [AppUserModelIdWriter]::SetAppUserModelId($shortcutPath, $appId)
        Write-NotifierLog "toast app identity registered: $shortcutPath; app id: $appId"
        return $appId
    } catch {
        Write-NotifierLog "toast app identity registration failed: $($_.Exception.Message)"
        return $appId
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

        $appId = Ensure-ToastAppIdentity
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
        $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId)
        $notifier.Show($toast)
        Write-NotifierLog "toast requested successfully with app id: $appId"
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
        finish = 'C:\Windows\Media\Windows Notify Calendar.wav'
    }

    $defaultToastTitles = @{
        permission = 'Claude Code needs permission'
        finish = 'Claude Code finished'
    }

    $defaultToastMessages = @{
        permission = 'A command is waiting for your approval.'
        finish = 'Claude finished responding.'
    }

    $soundEnabled = Get-ConfigBoolean -Config $config -Name 'soundEnabled' -Default $true
    $toastEnabled = Get-ConfigBoolean -Config $config -Name 'toastEnabled' -Default $false
    $maxSoundMilliseconds = Get-ConfigInteger -Config $config -Name 'maxSoundMilliseconds' -Default 3000
    $soundPath = Get-TypeValue -Container $config.sounds -TypeName $Type -Default $defaultSounds[$Type]
    $soundPath = Resolve-SoundPath -Path $soundPath -Root $repoRoot
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
