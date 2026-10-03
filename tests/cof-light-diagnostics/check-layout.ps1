# Copyright (C) 2026 Cry of Fear: Enhanced contributors
# SPDX-License-Identifier: GPL-3.0-or-later
param([Parameter(Mandatory=$true)][string]$SourceRoot,[Parameter(Mandatory=$true)][string]$Out)
$ErrorActionPreference='Stop'
# Run inside an x86 MSVC environment. Compile only: no executable or game launch.
$source=(Resolve-Path -LiteralPath $SourceRoot).Path
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$output=(Resolve-Path -LiteralPath $Out).Path
$compilerArgs=@('/nologo','/c','/std:c11',"/I$source\engine","/I$source\common","/I$source\public",(Join-Path $PSScriptRoot 'layout-check.c'),"/Fo$output\layout-check.obj")
& cl @compilerArgs
if($LASTEXITCODE){throw 'Retail-consumed lighting layout checks failed.'}
Write-Output 'PASS x86 node, surface, polygon, texinfo, and model offsets used by retail lighting'
