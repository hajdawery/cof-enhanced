param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)
# Copyright (C) 2026 Cry of Fear: Enhanced contributors
# SPDX-License-Identifier: GPL-3.0-or-later
# Observe movement sound callbacks without changing sound or prediction behavior.
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
if (-not $source.StartsWith($root.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}
$patch = Join-Path $root 'patches\cof-step-diagnostics.patch'
$markers = @{
    'engine/client/dll_int/cl_pmove.c' = 'static CVAR_DEFINE_AUTO( cof_step_trace_cl, "0"'
    'engine/server/sv_pmove.c' = 'static CVAR_DEFINE_AUTO( cof_step_trace_sv, "0"'
}
function Read-Source([string] $relative) {
    Get-Content -LiteralPath (Join-Path $source $relative) -Raw
}
foreach ($entry in $markers.GetEnumerator()) {
    $content = Read-Source $entry.Key
    if ($Reverse -and -not $content.Contains($entry.Value)) { throw "Missing movement sound diagnostic marker: $($entry.Key)" }
    if (-not $Reverse -and $content.Contains($entry.Value)) { throw "Movement sound diagnostic patch already present: $($entry.Key)" }
}
if (-not $Reverse -and -not (Read-Source 'engine/client/dll_int/cl_pmove.c').Contains('CL_CoF_SyncLegacyToNative')) {
    throw 'Prerequisite missing: apply the playermove adapters and callback-view patch first.'
}
$relativeSource = $source.Substring($root.TrimEnd('\').Length + 1).Replace('\', '/')
$direction = @()
if ($Reverse) { $direction += '--reverse' }
Push-Location $root
try {
    & git apply --ignore-whitespace @direction --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Movement sound diagnostic patch check failed.' }
    & git apply --ignore-whitespace @direction --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Movement sound diagnostic patch apply failed.' }
    foreach ($entry in $markers.GetEnumerator()) {
        if ((Read-Source $entry.Key).Contains($entry.Value) -eq [bool]$Reverse) {
            throw "Unexpected movement sound diagnostic marker state: $($entry.Key)"
        }
    }
    $opposite = @()
    if (-not $Reverse) { $opposite += '--reverse' }
    & git apply --ignore-whitespace @opposite --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Movement sound diagnostic patch failed its round-trip check.' }
} finally { Pop-Location }
Write-Host "Movement sound diagnostics applied (reverse=$Reverse): $source"
