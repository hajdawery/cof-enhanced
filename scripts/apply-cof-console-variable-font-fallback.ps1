param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!(Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "SourceRoot must be an existing directory: $SourceRoot"
}
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
$target = 'engine\client\console.c'
$patch = Join-Path $root 'patches\cof-console-variable-font-fallback.patch'

if (!(Test-Path -LiteralPath $patch)) { throw "Missing patch: $patch" }
if (!(Test-Path -LiteralPath (Join-Path $source $target))) {
    throw "Not an FWGS source tree: $(Join-Path $source $target)"
}
$rootPrefix = $root.TrimEnd('\') + '\'
if (-not $source.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}
$marker = Get-Content -Raw -LiteralPath (Join-Path $source $target)
if ($marker.Contains('Some mods provide a variable-width console font in gfx.wad.')) {
    throw 'The CoF console variable-font fallback is already present; use a clean patched source tree.'
}

Push-Location $root
try {
    $relativeSource = $source.Substring($rootPrefix.Length).Replace('\','/')
    & git apply --ignore-whitespace --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Patch does not apply cleanly to this source tree.' }
    & git apply --ignore-whitespace --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'git apply failed.' }

    $applied = Get-Content -Raw -LiteralPath (Join-Path $source $target)
    if (-not $applied.Contains('Some mods provide a variable-width console font in gfx.wad.')) {
        throw 'Patch command completed without the expected fallback marker.'
    }
    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) {
        throw 'Applied console fallback patch cannot be reverse-checked.'
    }
} finally {
    Pop-Location
}
Write-Host "Applied CoF console variable-font fallback to $source"
