param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!(Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "SourceRoot must be an existing directory: $SourceRoot"
}
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
$targets = @(
    'ref\gl\gl_local.h',
    'ref\gl\gl_opengl.c',
    'ref\gl\gl_rmain.c',
    'ref\gl\gl_beams.c'
)
$patch = Join-Path $root 'patches\cof-gl-stage-trace.patch'

if (!(Test-Path -LiteralPath $patch)) { throw "Missing patch: $patch" }
foreach($relative in $targets) {
    if (!(Test-Path -LiteralPath (Join-Path $source $relative))) {
        throw "Not an FWGS source tree: $(Join-Path $source $relative)"
    }
}
$rootPrefix = $root.TrimEnd('\') + '\'
if (-not $source.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}
$relativeSource = $source.Substring($rootPrefix.Length).Replace('\','/')
$header = Get-Content -Raw -LiteralPath (Join-Path $source 'ref\gl\gl_local.h')
if ($header.Contains('cof_gl_trace') -or $header.Contains('GL_CheckForErrorsNamed_')) {
    throw 'The CoF GL stage trace is already present; use a clean source tree.'
}

Push-Location $root
try {
    # The destination is resolved under the validated source directory. The
    # patch has repository-relative paths and is never allowed to escape it.
    & git apply --ignore-whitespace --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Patch does not apply cleanly to this source tree.' }
    & git apply --ignore-whitespace --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'git apply failed.' }

    $applied = Get-Content -Raw -LiteralPath (Join-Path $source 'ref\gl\gl_local.h')
    if (-not $applied.Contains('cof_gl_trace')) {
        throw 'Patch command completed without the expected diagnostic cvar marker.'
    }
    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) {
        throw 'Applied GL stage trace patch cannot be reverse-checked.'
    }
} finally {
    Pop-Location
}
Write-Host "Applied off-by-default CoF GL stage trace to $source"
