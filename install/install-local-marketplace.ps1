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

if (Test-Path $targetRoot) {
    Remove-Item -Recurse -Force $targetRoot
}

New-Item -ItemType Directory -Force -Path $targetRoot, $marketplaceDir | Out-Null

$exclude = @('.git', 'install')
Get-ChildItem $repoRoot -Force | Where-Object { $exclude -notcontains $_.Name } | ForEach-Object {
    Copy-Item $_.FullName -Destination $targetRoot -Recurse -Force
}

$marketplace = [ordered]@{
    '$schema' = 'https://anthropic.com/claude-code/marketplace.schema.json'
    name = 'local-claude-plugins'
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
            homepage = 'local'
        }
    )
}

$marketplace | ConvertTo-Json -Depth 10 | Set-Content -Path $marketplaceFile -Encoding UTF8

Write-Host "Installed local marketplace copy to: $targetRoot"
Write-Host "Marketplace manifest: $marketplaceFile"
Write-Host "Next: add/install this local marketplace in Claude Code, then run: /plugin install claude-code-notify@local-claude-plugins"
