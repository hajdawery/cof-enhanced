# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 haej (Cry of Fear: Enhanced contributors)
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$SourceRoot, [switch]$Reverse)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$prefix = $root.TrimEnd('\') + '\'
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
if (-not $source.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'SourceRoot must be inside this project workspace.' }
$file = Join-Path $source 'engine\client\input\cof_gamepad.c'
$text = Get-Content -LiteralPath $file -Raw
$marker = 'Mipmap upload may overwrite its input in place.'
if ($text.Contains($marker) -ne [bool]$Reverse) { throw 'Unexpected cursor shadow patch state (already applied, or not applied for reverse).' }
if (-not $text.Contains('static int CL_CoF_VCursorArt') -or -not $text.Contains('cof_pad.shadow_tex = GL_LoadTextureInternal')) { throw 'Apply cof-gamepad-input first.' }
$patch = Join-Path $root 'patches\cof-vcursor-shadow-source.patch'
$relative = $source.Substring($prefix.Length).Replace('\','/')
$direction = @(); $opposite = @('--reverse')
if ($Reverse) { $direction = @('--reverse'); $opposite = @() }
Push-Location $root
try {
    & git apply --ignore-whitespace --check --directory=$relative @direction -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Cursor shadow patch check failed.' }
    & git apply --ignore-whitespace --directory=$relative @direction -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Cursor shadow patch apply failed.' }
    if ((Get-Content -LiteralPath $file -Raw).Contains($marker) -eq [bool]$Reverse) { throw 'Cursor shadow marker check failed.' }
    & git apply --ignore-whitespace --check --directory=$relative @opposite -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Cursor shadow inverse check failed.' }
} finally { Pop-Location }
Write-Host "Cursor shadow source patch updated (reverse=$Reverse): $source"
