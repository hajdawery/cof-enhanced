# Copyright (C) 2026 Cry of Fear: Enhanced contributors
# SPDX-License-Identifier: GPL-3.0-or-later
param([Parameter(Mandatory=$true)][string]$SourceRoot,[switch]$Reverse)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source=[IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
$prefix=$root.TrimEnd('\')+'\'
if(!$source.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'SourceRoot must be inside this project workspace.'}
$file=Join-Path $source 'engine/client/cl_frame.c'
if(!(Test-Path -LiteralPath $file)){throw 'Missing engine/client/cl_frame.c'}
$text=Get-Content -LiteralPath $file -Raw
$present=$text.Contains('CL_CoFPreserveLanternColor')
if($Reverse -and !$present){throw 'Lantern light color fix are not present.'}
if(!$Reverse -and $present){throw 'Lantern light color fix are already present.'}
if(!(Get-Content -LiteralPath (Join-Path $source 'engine/client/cl_tent.c') -Raw).Contains('CL_CoFLightStatus_f')){throw 'Apply light diagnostics first.'}
$relative=$source.Substring($prefix.Length).Replace('\','/')
$patch=Join-Path $root 'patches/cof-lantern-light-color.patch'
$direction=@(); if($Reverse){$direction+= '--reverse'}
Push-Location $root
try {
 & git apply --ignore-whitespace @direction --check "--directory=$relative" -- $patch
 if($LASTEXITCODE){throw 'Patch check failed.'}
 & git apply --ignore-whitespace @direction "--directory=$relative" -- $patch
 if($LASTEXITCODE){throw 'Patch application failed.'}
 $text=Get-Content -LiteralPath $file -Raw
 if($text.Contains('CL_CoFPreserveLanternColor') -eq [bool]$Reverse){throw 'Patch markers do not match requested state.'}
 $opposite=@(); if(!$Reverse){$opposite+= '--reverse'}
 & git apply --ignore-whitespace @opposite --check "--directory=$relative" -- $patch
 if($LASTEXITCODE){throw 'Roundtrip check failed.'}
} finally {Pop-Location}
Write-Output "Lantern light color fix updated: $source"
