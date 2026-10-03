param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Cry of Fear: Enhanced contributors
# Opt-in entity visibility logging; no visibility decision changes.
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
if (-not $source.StartsWith($root.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}
$patch = Join-Path $root 'patches\cof-entity-visibility-trace.patch'
$markers = @{
    'engine/server/sv_frame.c' = '[cof-entity-visibility]'
    'engine/server/sv_main.c' = 'cof_entity_visibility_trace'
    'engine/server/sv_client.c' = 'effects: 0x%x (EF_NODRAW=%d)'
}
function Read-Source([string] $relative) {
    Get-Content -LiteralPath (Join-Path $source $relative) -Raw
}
foreach ($entry in $markers.GetEnumerator()) {
    $content = Read-Source $entry.Key
    if ($Reverse -and -not $content.Contains($entry.Value)) { throw "Missing entity visibility diagnostic marker: $($entry.Key)" }
    if (-not $Reverse -and $content.Contains($entry.Value)) { throw "Entity visibility diagnostic patch already present: $($entry.Key)" }
}
$relativeSource = $source.Substring($root.TrimEnd('\').Length + 1).Replace('\', '/')
$direction = @()
if ($Reverse) { $direction += '--reverse' }
Push-Location $root
try {
    & git apply --ignore-whitespace @direction --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Entity visibility diagnostic patch check failed.' }
    & git apply --ignore-whitespace @direction --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Entity visibility diagnostic patch apply failed.' }
    foreach ($entry in $markers.GetEnumerator()) {
        if ((Read-Source $entry.Key).Contains($entry.Value) -eq [bool]$Reverse) {
            throw "Unexpected entity visibility diagnostic marker state: $($entry.Key)"
        }
    }
    $opposite = @()
    if (-not $Reverse) { $opposite += '--reverse' }
    & git apply --ignore-whitespace @opposite --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Entity visibility diagnostic patch failed its round-trip check.' }
} finally { Pop-Location }
Write-Host "Entity visibility diagnostics applied (reverse=$Reverse): $source"
