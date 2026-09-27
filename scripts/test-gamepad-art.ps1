# Copyright (C) 2026 haej (Cry of Fear: Enhanced contributors)
# SPDX-License-Identifier: GPL-3.0-or-later
# Read-only payload check; accepts the gamepad folder in a repo, stage or runtime.
[CmdletBinding()]
param(
    [string]$Root = (Join-Path (Split-Path $PSScriptRoot -Parent) 'gamedata\cryoffear\gfx\shell\gamepad'),
    [string]$Manifest = ''
)
$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($Root)
function Art-Path([string]$relative) {
    $path = [IO.Path]::GetFullPath((Join-Path $Root $relative))
    if (-not $path.StartsWith($Root.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Art path escapes its folder: $relative"
    }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing gamepad art: $relative" }
    return $path
}
function Test-Png([string]$relative, [switch]$Cursor) {
    $bytes = [IO.File]::ReadAllBytes((Art-Path $relative))
    if ($bytes.Length -lt 33 -or [BitConverter]::ToString($bytes, 0, 8) -ne '89-50-4E-47-0D-0A-1A-0A' -or
        [Text.Encoding]::ASCII.GetString($bytes, 12, 4) -ne 'IHDR') { throw "Invalid PNG header: $relative" }
    $width = $bytes[16] * 16777216 + $bytes[17] * 65536 + $bytes[18] * 256 + $bytes[19]
    $height = $bytes[20] * 16777216 + $bytes[21] * 65536 + $bytes[22] * 256 + $bytes[23]
    if ($width -lt 1 -or $height -lt 1) { throw "Empty PNG: $relative" }
    # CL_CoF_VCursorArt requires RGBA and limits dimensions to 8..1024.
    if ($Cursor -and ($bytes[24] -ne 8 -or $bytes[25] -ne 6 -or $width -lt 8 -or $height -lt 8 -or $width -gt 1024 -or $height -gt 1024)) {
        throw 'cursor.png must be 8-bit RGBA, dimensions 8..1024 for CL_CoF_VCursorArt'
    }
}
Test-Png 'cursor.png' -Cursor
foreach ($notice in 'LICENSE-NOTE.md', 'LICENSE-Zacksly.txt') { $null = Art-Path $notice }
$styles = @{}
$images = @{}
foreach ($line in (Get-Content -LiteralPath (Art-Path 'icons.txt'))) {
    $text = ($line -split '//', 2)[0].Trim()
    if (-not $text) { continue }
    $fields = @([regex]::Matches($text, '"([^"]*)"|([^\s]+)') | ForEach-Object {
        if ($_.Groups[1].Success) { $_.Groups[1].Value } else { $_.Groups[2].Value }
    })
    if ($fields[0] -eq 'STYLE' -and $fields.Count -eq 3) {
        if ($styles.ContainsKey($fields[1])) { throw "Duplicate STYLE: $($fields[1])" }
        $styles[$fields[1]] = $fields[2]; $images[$fields[2]] = $true
    } elseif ($fields.Count -eq 10) {
        $images[$fields[1]] = $true; $images[$fields[2]] = $true
    } elseif ($fields.Count -eq 7) {
        $images[$fields[2]] = $true
    } else { throw "Invalid icons.txt row: $text" }
}
foreach ($style in 'xbox', 'ps5', 'switch', 'steamdeck') {
    if (-not $styles.ContainsKey($style)) { throw "Missing STYLE row: $style" }
}
foreach ($name in $images.Keys) { Test-Png $name }
if ($Manifest) {
    $listed = @{}
    foreach ($line in (Get-Content -LiteralPath $Manifest)) {
        if (-not $line.Trim()) { continue }
        if ($line -notmatch '^([0-9a-fA-F]{64})  (.+)$') { throw "Invalid art manifest row: $line" }
        $expected = $Matches[1]; $name = $Matches[2]
        if ($listed.ContainsKey($name)) { throw "Duplicate manifest entry: $name" }
        $listed[$name] = $true
        if ((Get-FileHash -LiteralPath (Art-Path $name) -Algorithm SHA256).Hash -ne $expected) { throw "Art hash mismatch: $name" }
    }
    $actual = @(Get-ChildItem -LiteralPath $Root -File -Recurse)
    if ($listed.Count -ne $actual.Count) { throw "Art manifest count mismatch: $($listed.Count) listed, $($actual.Count) present" }
}
Write-Host "Gamepad art OK: cursor, four controller pictures, $($images.Count) referenced PNGs and notices; $Root"
