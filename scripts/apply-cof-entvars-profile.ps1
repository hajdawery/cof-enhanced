param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!(Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "SourceRoot must be an existing directory: $SourceRoot"
}
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
$target = Join-Path $source 'engine\progdefs.h'
$patch = Join-Path $root 'patches\cof-entvars-legacy.patch'

if (!(Test-Path -LiteralPath $target)) { throw "Not an FWGS source tree: $target" }
if (!(Test-Path -LiteralPath $patch)) { throw "Missing patch: $patch" }
$rootPrefix = $root.TrimEnd('\') + '\'
if (-not $source.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "SourceRoot must be inside this project workspace: $root"
}
$relativeSource = $source.Substring($rootPrefix.Length).Replace('\','/')
$text = Get-Content -Raw $target
if ($text.Contains('XASH_COF_ENTVARS_LEGACY')) {
    throw 'The CoF entvars profile is already present; use a clean pinned source tree before applying the patch.'
}

Push-Location $root
try {
    & git apply --ignore-whitespace --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Patch does not apply cleanly to this source tree.' }
    & git apply --ignore-whitespace --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'git apply failed.' }
} finally {
    Pop-Location
}
Write-Host "Applied experimental CoF entvars profile to $target"
