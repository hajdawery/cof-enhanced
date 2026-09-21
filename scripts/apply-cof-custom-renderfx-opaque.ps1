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
$patch = Join-Path $root 'patches\cof-custom-renderfx-opaque.patch'

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
$rmain  = Get-Content -Raw -LiteralPath (Join-Path $source 'ref\gl\gl_rmain.c')
$hasOpaque = $header.Contains('cof_custom_renderfx_opaque') -or
             $opengl.Contains('cof_custom_renderfx_opaque') -or
             $rmain.Contains('cof_custom_renderfx_opaque')

if($Reverse) {
    if(-not $hasOpaque) { throw 'The CoF custom-renderfx opaque fix is not present; refusing reverse application.' }
} else {
    if(-not $header.Contains('cof_gl_trace') -or
       -not $header.Contains('cof_solid_entity_trace') -or
       -not $header.Contains('cof_skip_client_normal_triangles') -or
       -not $header.Contains('cof_skip_client_transparent_triangles')) {
        throw 'Apply the GL stage, solid-entity, and transparent-triangle trace prerequisites first.'
    }
    if($hasOpaque) { throw 'The CoF custom-renderfx opaque fix is already present; use a clean source tree.' }
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
    $rmain  = Get-Content -Raw -LiteralPath (Join-Path $source 'ref\gl\gl_rmain.c')
    $present = $header.Contains('cof_custom_renderfx_opaque') -and
               $opengl.Contains('CVAR_DEFINE_AUTO( cof_custom_renderfx_opaque, "1", FCVAR_GLCONFIG') -and
               $opengl.Contains('Cvar_RegisterVariable( &cof_custom_renderfx_opaque )') -and
               $rmain.Contains('ent->curstate.renderfx > kRenderFxLightMultiplier')
    if($Reverse) {
        if($present) { throw 'Reverse application completed without removing all custom-renderfx opaque markers.' }
    } elseif(-not $present) {
        throw 'Patch command completed without all expected custom-renderfx opaque markers.'
    }

    $checkDirection = if($Reverse) { @() } else { @('--reverse') }
    $check = @('--ignore-whitespace') + $checkDirection + @('--check', "--directory=$relativeSource", '--', $patch)
    & git apply @check
    if ($LASTEXITCODE -ne 0) { throw 'Applied custom-renderfx opaque patch cannot be reverse-checked.' }
} finally {
    Pop-Location
}
if($Reverse) { Write-Host "Removed the CoF custom-renderfx opaque classification from $source" }
else { Write-Host "Applied the CoF custom-renderfx opaque classification to $source" }
