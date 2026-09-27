#Requires -Version 5.1
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Cry of Fear: Enhanced contributors
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$prefix = $root.TrimEnd('\') + '\'
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
if (-not $source.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}
$enginePath = Join-Path $source 'engine\client\cof_osk.c'
$vguiPath = Join-Path $source '3rdparty\freevgui\platform\xash3d-fwgs\cofosk.cpp'
foreach ($file in @($enginePath, $vguiPath)) {
    if (!(Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing OSK prerequisite: $file" }
}
$engine = Get-Content -LiteralPath $enginePath -Raw
$vgui = Get-Content -LiteralPath $vguiPath -Raw
$present = $engine.Contains('cof_osk_next_field') -or $vgui.Contains('CofOsk_NextField')
if ($Reverse) {
    if (!$present) { throw 'OSK field navigation is not present.' }
} else {
    if ($present) { throw 'OSK field navigation already present; reverse first.' }
    if (!$engine.Contains('CL_CoF_OskPut') -or !$engine.Contains('cof_enter_pulse') -or
        !$vgui.Contains('CofOsk_FindVisible') -or !$vgui.Contains('CofOsk_Focused')) {
        throw 'Apply cof-osk-engine and cof-client-enter-hook before this patch.'
    }
}
$patch = Join-Path $root 'patches\cof-osk-field-navigation.patch'
$relative = $source.Substring($prefix.Length).Replace('\', '/')
$argsApply = @()
$argsCheck = @('--reverse')
if ($Reverse) { $argsApply = @('--reverse'); $argsCheck = @() }
Push-Location $root
try {
    & git apply --ignore-whitespace --check --directory=$relative @argsApply -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'OSK navigation patch does not apply cleanly.' }
    & git apply --ignore-whitespace --directory=$relative @argsApply -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'OSK navigation patch application failed.' }
    $engine = Get-Content -LiteralPath $enginePath -Raw
    $vgui = Get-Content -LiteralPath $vguiPath -Raw
    $enginePresent = $engine.Contains('cof_osk_next_field')
    $vguiPresent = $vgui.Contains('CofOsk_NextField')
    if ($enginePresent -ne (!$Reverse) -or $vguiPresent -ne (!$Reverse)) {
        throw 'Unexpected OSK navigation markers after application.'
    }
    & git apply --ignore-whitespace --check --directory=$relative @argsCheck -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'OSK navigation patch inverse check failed.' }
} finally { Pop-Location }
Write-Host "OSK field navigation updated in $source (reverse=$Reverse)"
