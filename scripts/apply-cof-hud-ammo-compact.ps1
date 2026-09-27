#Requires -Version 5.1
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Cry of Fear: Enhanced contributors
[CmdletBinding()]
param([Parameter(Mandatory=$true)] [string] $SourceRoot, [switch] $Reverse)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$prefix = $root.TrimEnd('\') + '\'
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
if (-not $source.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}
$paths = @('engine\client\cof_hud_remake.c')
$markers = @('HudCompactWeaponRow')
$contents = @()
foreach ($path in $paths) {
    $file = Join-Path $source $path
    if (!(Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing ammo-state prerequisite: $file" }
    $contents += Get-Content -LiteralPath $file -Raw
}
$present = $false
for ($i = 0; $i -lt $paths.Count; $i++) { $present = $present -or $contents[$i].Contains($markers[$i]) }
if ($Reverse) {
    if (!$present) { throw 'Compact ammo context is not present.' }
} else {
    if ($present) { throw 'Compact ammo context already present; reverse first.' }
    if (!$contents[0].Contains('hud_catalog') -or !$contents[0].Contains('HudWeaponRow')) {
        throw 'Apply cof-hud-ammo-state first.'
    }
}
$patch = Join-Path $root 'patches\cof-hud-ammo-compact.patch'
$relative = $source.Substring($prefix.Length).Replace('\', '/')
$argsApply = @(); $argsCheck = @('--reverse')
if ($Reverse) { $argsApply = @('--reverse'); $argsCheck = @() }
Push-Location $root
try {
    & git apply --ignore-whitespace --check --directory=$relative @argsApply -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Compact ammo patch does not apply cleanly.' }
    & git apply --ignore-whitespace --directory=$relative @argsApply -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Compact ammo patch application failed.' }
    for ($i = 0; $i -lt $paths.Count; $i++) {
        $text = Get-Content -LiteralPath (Join-Path $source $paths[$i]) -Raw
        if ($text.Contains($markers[$i]) -ne (!$Reverse)) { throw "Unexpected Compact ammo marker in $($paths[$i])" }
    }
    & git apply --ignore-whitespace --check --directory=$relative @argsCheck -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Compact ammo patch inverse check failed.' }
} finally { Pop-Location }
Write-Host "Compact ammo context updated in $source (reverse=$Reverse)"
