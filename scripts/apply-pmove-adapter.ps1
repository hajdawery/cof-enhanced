param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Force
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!(Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "SourceRoot must be an existing directory: $SourceRoot"
}
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
$target = Join-Path $source 'engine\server\sv_pmove.c'
$patch = Join-Path $root 'patches\cof-pmove-legacy.patch'

if (!(Test-Path $target)) { throw "Not an FWGS source tree: $target" }
if (!(Test-Path $patch)) { throw "Missing patch: $patch" }
$relativeSource = [IO.Path]::GetRelativePath($root, $source)
if ($relativeSource -eq '.' -or $relativeSource.StartsWith('..' + [IO.Path]::DirectorySeparatorChar) -or [IO.Path]::IsPathRooted($relativeSource)) {
    throw "SourceRoot must be inside this project workspace: $root"
}
$relativeSource = $relativeSource.Replace('\','/')
$text = Get-Content -Raw $target
if ($text.Contains('COF_PMOVE_LEGACY_SHIFT') -and !$Force) {
    throw 'The adapter is already present. Use -Force only after reviewing the existing change.'
}

Push-Location $root
try {
    # The patch is redirected to the validated source directory. Do not use
    # --unsafe-paths: a patch path must never escape the project checkout.
    & git apply --ignore-whitespace --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Patch does not apply cleanly to this source tree.' }
    & git apply --ignore-whitespace --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'git apply failed.' }
} finally {
    Pop-Location
}
Write-Host "Applied experimental CoF PMove adapter to $target"
