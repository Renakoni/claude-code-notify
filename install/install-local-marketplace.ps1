param(
    [string]$MarketplaceRoot = "$env:USERPROFILE\.claude\plugins\marketplaces\local-claude-plugins",
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$pluginName = 'claude-code-notify'
$targetRoot = Join-Path $MarketplaceRoot "plugins\$pluginName"
$marketplaceDir = Join-Path $MarketplaceRoot '.claude-plugin'
$marketplaceFile = Join-Path $marketplaceDir 'marketplace.json'

if ((Test-Path $targetRoot) -and -not $Force) {
    throw "Target already exists: $targetRoot. Re-run with -Force to replace it."
}

$existingConfig = $null
$targetConfig = Join-Path $targetRoot 'config\notifier.json'
if ((Test-Path $targetConfig) -and $Force) {
    $existingConfig = Get-Content -Path $targetConfig -Raw
}

if (Test-Path $targetRoot) {
    Remove-Item -Recurse -Force $targetRoot
}

New-Item -ItemType Directory -Force -Path $targetRoot, $marketplaceDir | Out-Null

$exclude = @('.git', 'install')
Get-ChildItem $repoRoot -Force | Where-Object { $exclude -notcontains $_.Name } | ForEach-Object {
    Copy-Item $_.FullName -Destination $targetRoot -Recurse -Force
}

if ($null -ne $existingConfig) {
    $targetConfigDirectory = Split-Path -Parent $targetConfig
    New-Item -ItemType Directory -Force -Path $targetConfigDirectory | Out-Null
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($targetConfig, $existingConfig, $utf8NoBom)
}

$marketplace = [ordered]@{
    '$schema' = 'https://json.schemastore.org/claude-code-marketplace.json'
    name = 'local-claude-plugins'
    version = '0.1.0'
    description = 'Local Claude Code plugins under the user profile.'
    owner = [ordered]@{
        name = $env:USERNAME
    }
    plugins = @(
        [ordered]@{
            name = $pluginName
            description = 'Play Windows notification sounds when Claude Code needs permission or finishes work.'
            author = [ordered]@{
                name = 'Renakoni'
            }
            category = 'productivity'
            source = './plugins/claude-code-notify'
        }
    )
}

$json = $marketplace | ConvertTo-Json -Depth 10
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($marketplaceFile, $json, $utf8NoBom)

Write-Host "Installed local marketplace copy to: $targetRoot"
Write-Host "Marketplace manifest: $marketplaceFile"
Write-Host "Next: run: claude plugin marketplace add `"$MarketplaceRoot`""
Write-Host "Then run: claude plugin install claude-code-notify@local-claude-plugins"
