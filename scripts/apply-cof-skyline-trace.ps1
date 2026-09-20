param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
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
    'ref\gl\gl_studio.c'
)
$patch = Join-Path $root 'patches\cof-skyline-trace.patch'

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
$opengl = Get-Content -Raw -LiteralPath (Join-Path $source 'ref\gl\gl_opengl.c')
$studio = Get-Content -Raw -LiteralPath (Join-Path $source 'ref\gl\gl_studio.c')
$hasSkyline = $header.Contains('cof_skyline_trace') -or $opengl.Contains('cof_skyline_trace') -or $studio.Contains('cof_skyline_trace')

if($Reverse) {
    if(-not $hasSkyline) { throw 'The CoF skyline trace is not present; refusing reverse application.' }
} else {
    if(-not $header.Contains('cof_gl_trace')) { throw 'Apply the GL stage trace first; its cvar marker is required.' }
    if($hasSkyline) { throw 'The CoF skyline trace is already present; use a clean source tree.' }
}

Push-Location $root
try {
    $args = @('--ignore-whitespace')
    if($Reverse) { $args += '--reverse' }
    $args += @('--check', "--directory=$relativeSource", '--', $patch)
    & git apply @args
    if ($LASTEXITCODE -ne 0) { throw 'Patch check failed.' }

    $args = @('--ignore-whitespace')
    if($Reverse) { $args += '--reverse' }
    $args += @("--directory=$relativeSource", '--', $patch)
    & git apply @args
    if ($LASTEXITCODE -ne 0) { throw 'git apply failed.' }

    $header = Get-Content -Raw -LiteralPath (Join-Path $source 'ref\gl\gl_local.h')
    $opengl = Get-Content -Raw -LiteralPath (Join-Path $source 'ref\gl\gl_opengl.c')
    $studio = Get-Content -Raw -LiteralPath (Join-Path $source 'ref\gl\gl_studio.c')
    $present = $header.Contains('cof_skyline_trace') -and $opengl.Contains('cof_skyline_trace') -and $studio.Contains('[cof-skyline]')
    if($Reverse) {
        if($present) { throw 'Reverse application completed without removing all skyline markers.' }
    } elseif(-not $present) {
        throw 'Patch command completed without all expected skyline markers.'
    }

    $checkDirection = if($Reverse) { @() } else { @('--reverse') }
    $check = @('--ignore-whitespace') + $checkDirection + @('--check', "--directory=$relativeSource", '--', $patch)
    & git apply @check
    if ($LASTEXITCODE -ne 0) { throw 'Applied skyline trace patch cannot be reverse-checked.' }
} finally {
    Pop-Location
}
if($Reverse) { Write-Host "Removed off-by-default CoF skyline trace from $source" }
else { Write-Host "Applied off-by-default CoF skyline trace to $source" }
