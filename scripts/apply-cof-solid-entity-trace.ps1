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
    'ref\gl\gl_rmain.c'
)
$patch = Join-Path $root 'patches\cof-solid-entity-trace.patch'
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
$headerPath = Join-Path $source 'ref\gl\gl_local.h'
$openglPath = Join-Path $source 'ref\gl\gl_opengl.c'
$rmainPath = Join-Path $source 'ref\gl\gl_rmain.c'
$header = Get-Content -Raw -LiteralPath $headerPath
$opengl = Get-Content -Raw -LiteralPath $openglPath
$rmain = Get-Content -Raw -LiteralPath $rmainPath
$present = $header.Contains('cof_solid_entity_trace') -and $opengl.Contains('cof_solid_entity_trace') -and $rmain.Contains('[cof-solid-gl]')

if($Reverse) {
    if(-not $present) { throw 'The CoF solid-entity trace is not present; refusing reverse application.' }
} else {
    if(-not $header.Contains('cof_gl_trace') -or -not $header.Contains('cof_skip_client_normal_triangles')) {
        throw 'Apply the GL stage trace prerequisite first.'
    }
    if($present) { throw 'The CoF solid-entity trace is already present; use a clean source tree.' }
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

    $header = Get-Content -Raw -LiteralPath $headerPath
    $opengl = Get-Content -Raw -LiteralPath $openglPath
    $rmain = Get-Content -Raw -LiteralPath $rmainPath
    $present = $header.Contains('cof_solid_entity_trace') -and $opengl.Contains('cof_solid_entity_trace') -and $rmain.Contains('[cof-solid-gl]')
    if($Reverse) {
        if($present) { throw 'Reverse application completed without removing all solid-entity trace markers.' }
    } elseif(-not $present) {
        throw 'Patch command completed without all expected solid-entity trace markers.'
    }

    $checkDirection = if($Reverse) { @() } else { @('--reverse') }
    $check = @('--ignore-whitespace') + $checkDirection + @('--check', "--directory=$relativeSource", '--', $patch)
    & git apply @check
    if ($LASTEXITCODE -ne 0) { throw 'Applied solid-entity trace patch cannot be checked in the opposite direction.' }
} finally {
    Pop-Location
}
if($Reverse) { Write-Host "Removed off-by-default CoF solid-entity trace from $source" }
else { Write-Host "Applied off-by-default CoF solid-entity trace to $source" }
