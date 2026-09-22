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
    'engine\client\cl_view.c',
    'engine\client\cl_main.c'
)
$patch = Join-Path $root 'patches\cof-fov.patch'

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

$view = Slurp 'engine\client\cl_view.c'
$main = Slurp 'engine\client\cl_main.c'
$present = $view.Contains('cof_fov') -or $main.Contains('V_CoF_RegisterFovCvars')

if ($Reverse) {
    if (-not $present) { throw 'The CoF world field of view is not present in this source tree; nothing to reverse.' }
} else {
    if ($present) { throw 'The CoF world field of view is already present; use a clean patched source tree.' }
    # This patch has NO ordering constraint inside the engine stack. Its
    # cl_view.c hunks sit in V_GetRefParams, which no other CoF patch touches,
    # and its one cl_main.c line is anchored on two stock registrations
    # (cl_maxframetime, cl_fixmodelinterpolationartifacts), so it applies to a
    # pristine tree and to the full stack alike. It only needs the stock
    # V_GetRefParams FOV line to still be there.
    if (-not $view.Contains('rvp->fov_x = bound( 10.0f, cl.local.scr_fov, 150.0f )')) {
        throw 'cl_view.c does not carry the stock V_GetRefParams FOV line; this is not the pinned FWGS revision, or something else already rewrote it.'
    }
    if (-not $main.Contains('Cvar_RegisterVariable( &cl_fixmodelinterpolationartifacts );')) {
        throw 'cl_main.c does not carry the stock CL_InitLocal registrations this patch anchors on.'
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

    $viewAfter = Slurp 'engine\client\cl_view.c'
    $mainAfter = Slurp 'engine\client\cl_main.c'

    if ($Reverse) {
        $gone = -not $viewAfter.Contains('cof_fov') -and
                -not $viewAfter.Contains('V_CoF_WorldFov') -and
                -not $mainAfter.Contains('V_CoF_RegisterFovCvars')
        if (-not $gone) { throw 'Reverse left world-FOV markers behind.' }
        if (-not $viewAfter.Contains('rvp->fov_x = bound( 10.0f, cl.local.scr_fov, 150.0f )')) {
            throw 'Reverse did not restore the stock V_GetRefParams FOV line.'
        }
        Write-Host "Reversed the CoF world field of view in $source"
        return
    }

    $ok = $viewAfter.Contains('static CVAR_DEFINE_AUTO( cof_fov, "90", FCVAR_ARCHIVE') -and
          $viewAfter.Contains('static CVAR_DEFINE_AUTO( cof_fov_zoom_knee, "60"') -and
          $viewAfter.Contains('void V_CoF_RegisterFovCvars( void )') -and
          $viewAfter.Contains('static float V_CoF_WorldFov( float requested )') -and
          $viewAfter.Contains('rvp->fov_x = bound( 10.0f, V_CoF_WorldFov( cl.local.scr_fov ), 150.0f )') -and
          $mainAfter.Contains('V_CoF_RegisterFovCvars();')
    if (-not $ok) { throw 'Patch command completed without the expected world-FOV markers.' }

    # the remap must be applied to rvp->fov_x only: cl.local.scr_fov is what the
    # client, its mouse sensitivity and the save state all see, and the whole
    # point of this patch is that none of them notice
    if ($viewAfter -match 'cl\.local\.scr_fov\s*=') {
        throw 'cl_view.c now assigns cl.local.scr_fov; the world-FOV preference must never be written back to the client state.'
    }

    & git @('apply','--ignore-whitespace','--reverse','--check',"--directory=$relativeSource", '--', $patch)
    if ($LASTEXITCODE -ne 0) { throw 'Applied world-FOV patch cannot be reverse-checked.' }
} finally {
    Pop-Location
}
Write-Host "Applied the CoF world field of view to $source"
