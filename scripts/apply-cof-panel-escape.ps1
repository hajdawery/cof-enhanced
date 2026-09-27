# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 haej (Cry of Fear: Enhanced contributors)
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$SourceRoot, [switch]$Reverse)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$prefix = $root.TrimEnd('\') + '\'
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
if (-not $source.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'SourceRoot must be inside this project workspace.' }
$keys = Join-Path $source 'engine\client\input\in_keys.c'
$panels = Join-Path $source '3rdparty\freevgui\platform\xash3d-fwgs\cofpanels.cpp'
$keyText = Get-Content -LiteralPath $keys -Raw
$panelText = Get-Content -LiteralPath $panels -Raw
if (-not $keyText.Contains('CL_CoF_EnterKeyEvent') -or -not $panelText.Contains('CofPanelBack')) { throw 'Apply CoF gamepad and OSK input prerequisites first.' }
if ($keyText.Contains('Key_CoF_PanelEscape') -ne [bool]$Reverse -or $panelText.Contains('const bool hiddenClose') -ne [bool]$Reverse) { throw 'Unexpected pane Escape patch state.' }
$patch = Join-Path $root 'patches\cof-panel-escape.patch'
$relative = $source.Substring($prefix.Length).Replace('\','/')
$direction = @(); $opposite = @('--reverse')
if ($Reverse) { $direction = @('--reverse'); $opposite = @() }
Push-Location $root
try {
    & git apply --ignore-whitespace --check --directory=$relative @direction -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Pane Escape patch check failed.' }
    & git apply --ignore-whitespace --directory=$relative @direction -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Pane Escape patch apply failed.' }
    if ((Get-Content -LiteralPath $keys -Raw).Contains('Key_CoF_PanelEscape') -eq [bool]$Reverse -or (Get-Content -LiteralPath $panels -Raw).Contains('const bool hiddenClose') -eq [bool]$Reverse) { throw 'Pane Escape marker mismatch.' }
    & git apply --ignore-whitespace --check --directory=$relative @opposite -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Pane Escape inverse check failed.' }
} finally { Pop-Location }
Write-Host "Pane Escape patch updated (reverse=$Reverse): $source"
