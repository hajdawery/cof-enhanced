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
$paths = @('3rdparty\mainui\controls\ItemsHolder.cpp', '3rdparty\mainui\controls\SpinControl.cpp', '3rdparty\mainui\controls\DropDown.cpp', '3rdparty\mainui\menus\VideoModes.cpp', '3rdparty\mainui\BaseMenu.cpp')
$markers = @('if(dy && UI_CoFSelectionLists())', 'CMenuSpinControl::OpenSelection', 'CMenuDropDown::SelectionCommit', 'CMenuResolutionSelection', 'ui_cof_dropdowns')
$contents = @()
foreach ($path in $paths) {
    $file = Join-Path $source $path
    if (!(Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing MainUI prerequisite: $file" }
    $contents += Get-Content -LiteralPath $file -Raw
}
$present = $false
for ($i = 0; $i -lt $paths.Count; $i++) { $present = $present -or $contents[$i].Contains($markers[$i]) }
if ($Reverse) {
    if (!$present) { throw 'Selection list context is not present.' }
} else {
    if ($present) { throw 'Selection list context already present; reverse first.' }
    if (!$contents[0].Contains('UI_CoFNavTarget')) {
        throw 'Apply the current CoF options-layout stack first.'
    }
}
$patch = Join-Path $root 'patches\cof-selection-list.patch'
$relative = $source.Substring($prefix.Length).Replace('\', '/')
$argsApply = @(); $argsCheck = @('--reverse')
if ($Reverse) { $argsApply = @('--reverse'); $argsCheck = @() }
Push-Location $root
try {
    & git apply --ignore-whitespace --check --directory=$relative @argsApply -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Selection list patch does not apply cleanly.' }
    & git apply --ignore-whitespace --directory=$relative @argsApply -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Selection list patch application failed.' }
    for ($i = 0; $i -lt $paths.Count; $i++) {
        $text = Get-Content -LiteralPath (Join-Path $source $paths[$i]) -Raw
        if ($text.Contains($markers[$i]) -ne (!$Reverse)) { throw "Unexpected Selection list marker in $($paths[$i])" }
    }
    & git apply --ignore-whitespace --check --directory=$relative @argsCheck -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Selection list patch inverse check failed.' }
} finally { Pop-Location }
Write-Host "Selection list context updated in $source (reverse=$Reverse)"
