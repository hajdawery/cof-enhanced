# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 haej (Cry of Fear: Enhanced contributors)
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$SourceRoot, [switch]$Reverse)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$prefix = $root.TrimEnd('\') + '\'
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
if (-not $source.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'SourceRoot must be inside this project workspace.' }
$file = Join-Path $source 'engine\client\cof_hud_remake.c'
$marker = 'HUD_BOSS_FIRST = 100'
if (-not (Test-Path -LiteralPath $file)) { throw 'Apply cof-hud-remake first.' }
if ((Get-Content -LiteralPath $file -Raw).Contains($marker) -ne [bool]$Reverse) { throw 'Unexpected HUD boss style patch state.' }
$patch = Join-Path $root 'patches\cof-hud-boss-style.patch'
$relative = $source.Substring($prefix.Length).Replace('\','/')
$direction = @(); $opposite = @('--reverse')
if ($Reverse) { $direction = @('--reverse'); $opposite = @() }
Push-Location $root
try {
    & git apply --ignore-whitespace --check --directory=$relative @direction -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'HUD boss style patch check failed.' }
    & git apply --ignore-whitespace --directory=$relative @direction -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'HUD boss style patch apply failed.' }
    if ((Get-Content -LiteralPath $file -Raw).Contains($marker) -eq [bool]$Reverse) { throw 'HUD boss style marker check failed.' }
    & git apply --ignore-whitespace --check --directory=$relative @opposite -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'HUD boss style inverse check failed.' }
} finally { Pop-Location }
Write-Host "HUD boss style patch updated (reverse=$Reverse): $source"
