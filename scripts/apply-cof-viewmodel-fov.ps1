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
$patch = Join-Path $root 'patches\cof-viewmodel-fov.patch'

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

function Slurp([string]$rel) { Get-Content -Raw -LiteralPath (Join-Path $source $rel) }

$header = Slurp 'ref\gl\gl_local.h'
$opengl = Slurp 'ref\gl\gl_opengl.c'
$studio = Slurp 'ref\gl\gl_studio.c'
$present = $header.Contains('cof_viewmodel_fov') -or
           $opengl.Contains('cof_viewmodel_fov') -or
           $studio.Contains('cof_viewmodel_fov')

if ($Reverse) {
    if (-not $present) { throw 'The CoF viewmodel field of view is not present in this source tree; nothing to reverse.' }
} else {
    if ($present) { throw 'The CoF viewmodel field of view is already present; use a clean patched source tree.' }
    # The declaration and the registration sit next to cof_custom_renderfx_opaque,
    # so this is the LAST patch of the ref/gl stack, after the trace patches and
    # the renderfx-opaque fix the runtime renderer already ships.
    if (-not $header.Contains('cof_custom_renderfx_opaque') -or
        -not $opengl.Contains('cof_custom_renderfx_opaque')) {
        throw 'Apply scripts\apply-cof-custom-renderfx-opaque.ps1 first: this patch declares and registers its cvar next to that one.'
    }
    if (-not $studio.Contains('pglDepthRange( gldepthmin, gldepthmin + 0.3f * ( gldepthmax - gldepthmin ));')) {
        throw 'gl_studio.c does not carry the stock R_DrawViewModel depth-range bracket this patch wraps.'
    }
}

Push-Location $root
try {
    $relativeSource = $source.Substring($rootPrefix.Length).Replace('\','/')
    $gitArgs = @('apply','--ignore-whitespace',"--directory=$relativeSource")
    if ($Reverse) { $gitArgs += '--reverse' }

    & git @($gitArgs + @('--check','--', $patch))
    if ($LASTEXITCODE -ne 0) { throw 'Patch does not apply cleanly to this source tree.' }
    & git @($gitArgs + @('--', $patch))
    if ($LASTEXITCODE -ne 0) { throw 'git apply failed.' }

    $headerAfter = Slurp 'ref\gl\gl_local.h'
    $openglAfter = Slurp 'ref\gl\gl_opengl.c'
    $studioAfter = Slurp 'ref\gl\gl_studio.c'

    if ($Reverse) {
        $gone = -not $headerAfter.Contains('cof_viewmodel_fov') -and
                -not $openglAfter.Contains('cof_viewmodel_fov') -and
                -not $studioAfter.Contains('cof_viewmodel_fov') -and
                -not $studioAfter.Contains('R_CoFViewModelProjection')
        if (-not $gone) { throw 'Reverse left viewmodel-FOV markers behind.' }
        # a reverse must not damage the renderer fix this one sits on top of
        if (-not $headerAfter.Contains('cof_custom_renderfx_opaque') -or
            -not $openglAfter.Contains('Cvar_RegisterVariable( &cof_custom_renderfx_opaque )')) {
            throw 'Reverse damaged the custom-renderfx opaque fix.'
        }
        if (-not $studioAfter.Contains('pglDepthRange( gldepthmin, gldepthmax );')) {
            throw 'Reverse did not restore the stock R_DrawViewModel depth-range restore.'
        }
        Write-Host "Reversed the CoF viewmodel field of view in $source"
        return
    }

    $ok = $headerAfter.Contains('extern convar_t cof_viewmodel_fov;') -and
          $openglAfter.Contains('Cvar_RegisterVariable( &cof_viewmodel_fov )') -and
          $studioAfter.Contains('CVAR_DEFINE_AUTO( cof_viewmodel_fov, "0", FCVAR_GLCONFIG') -and
          $studioAfter.Contains('static qboolean R_CoFViewModelProjection( matrix4x4 m )') -and
          $studioAfter.Contains('vm_fov = R_CoFViewModelProjection( vm_projection );')
    if (-not $ok) { throw 'Patch command completed without the expected viewmodel-FOV markers.' }

    # the override is a PASS override: it has to be pushed and popped inside
    # R_DrawViewModel, and RI's own copies have to be put back, or every later
    # pfnWorldToScreen and the next frame's 2D pass would inherit it
    $pushes = ([regex]::Matches($studioAfter, 'pglPushMatrix\(\);')).Count
    $pops   = ([regex]::Matches($studioAfter, 'pglPopMatrix\(\);')).Count
    if ($pushes -ne $pops) { throw "gl_studio.c has $pushes matrix pushes against $pops pops; the viewmodel projection must be balanced." }
    if (-not $studioAfter.Contains('Matrix4x4_Copy( RI.projectionMatrix, saved_projection );') -or
        -not $studioAfter.Contains('Matrix4x4_Copy( RI.worldviewProjectionMatrix, saved_worldviewprojection );')) {
        throw 'gl_studio.c does not restore RI.projectionMatrix / RI.worldviewProjectionMatrix after the viewmodel pass.'
    }
    # and the stock depth-range bracket must still surround the whole thing
    if (-not $studioAfter.Contains('pglDepthRange( gldepthmin, gldepthmin + 0.3f * ( gldepthmax - gldepthmin ));') -or
        -not $studioAfter.Contains('pglDepthRange( gldepthmin, gldepthmax );')) {
        throw 'The viewmodel depth-range bracket is no longer intact.'
    }

    & git @('apply','--ignore-whitespace','--reverse','--check',"--directory=$relativeSource", '--', $patch)
    if ($LASTEXITCODE -ne 0) { throw 'Applied viewmodel-FOV patch cannot be reverse-checked.' }
} finally {
    Pop-Location
}
Write-Host "Applied the CoF viewmodel field of view to $source"
