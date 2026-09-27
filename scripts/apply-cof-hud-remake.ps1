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
if ((Test-Path -LiteralPath $file) -ne [bool]$Reverse) { throw 'Unexpected Remake HUD patch state.' }
$game = Get-Content -LiteralPath (Join-Path $source 'engine\client\dll_int\cl_game.c') -Raw
if (-not $game.Contains('CL_CoF_HudTextFlush') -or -not $game.Contains('cof_hud_widget')) { throw 'Apply cof-hud-text-style and cof-gamepad-input prerequisites first.' }
$patch = Join-Path $root 'patches\cof-hud-remake.patch'
$relative = $source.Substring($prefix.Length).Replace('\','/')
$direction = @(); $opposite = @('--reverse')
if ($Reverse) { $direction = @('--reverse'); $opposite = @() }
Push-Location $root
try {
    & git apply --ignore-whitespace --check --directory=$relative @direction -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Remake HUD patch check failed.' }
    & git apply --ignore-whitespace --directory=$relative @direction -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Remake HUD patch apply failed.' }
    if ((Test-Path -LiteralPath $file) -eq [bool]$Reverse) { throw 'Remake HUD file state verification failed.' }
    foreach ($entry in @('engine\client\cl_main.c','engine\client\client.h','engine\client\dll_int\cl_game.c','engine\client\parse\cl_parse.c','engine\client\vgui\vgui_draw.c')) {
        if ((Get-Content -LiteralPath (Join-Path $source $entry) -Raw).Contains('CL_CoF_HudRemake') -eq [bool]$Reverse) { throw "Remake HUD integration marker mismatch: $entry" }
    }
    & git apply --ignore-whitespace --check --directory=$relative @opposite -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Remake HUD inverse check failed.' }
} finally { Pop-Location }
Write-Host "Remake HUD patch updated (reverse=$Reverse): $source"
