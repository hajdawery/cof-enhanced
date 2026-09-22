param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)

# Cry of Fear out-of-range sprite frames (cof_sprite_quiet_frames, default 1,
# and the cof_sprite_trace diagnostic). ref/gl only; the LAST patch of the
# ref/gl stack, after scripts\apply-cof-viewmodel-fov.ps1, because it declares
# and registers its cvars next to cof_viewmodel_fov. See
# docs\cof-sprite-quiet-frames.md.

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!(Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "SourceRoot must be an existing directory: $SourceRoot"
}
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
$targets = @('ref\gl\gl_local.h', 'ref\gl\gl_opengl.c', 'ref\gl\gl_sprite.c')
$patch = Join-Path $root 'patches\cof-sprite-quiet-frames.patch'

if (!(Test-Path -LiteralPath $patch)) { throw "Missing patch: $patch" }
foreach ($relative in $targets) {
    if (!(Test-Path -LiteralPath (Join-Path $source $relative))) { throw "Not an FWGS source tree: $(Join-Path $source $relative)" }
}
$rootPrefix = $root.TrimEnd('\') + '\'
if (-not $source.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}

function Slurp([string]$rel) { Get-Content -Raw -LiteralPath (Join-Path $source $rel) }
$stockCall = 'gEngfuncs.R_GetSpriteFrame( model, e->curstate.frame, e->angles[YAW] )'

$present = (Slurp 'ref\gl\gl_sprite.c').Contains('cof_sprite_quiet_frames')
if ($Reverse) {
    if (-not $present) { throw 'The CoF sprite quiet-frames change is not present in this source tree; nothing to reverse.' }
} else {
    if ($present) { throw 'The CoF sprite quiet-frames change is already present; use a clean patched source tree.' }
    if (-not (Slurp 'ref\gl\gl_local.h').Contains('extern convar_t cof_viewmodel_fov;') -or
        -not (Slurp 'ref\gl\gl_opengl.c').Contains('Cvar_RegisterVariable( &cof_viewmodel_fov )')) {
        throw 'Apply scripts\apply-cof-viewmodel-fov.ps1 first: this patch registers its cvars next to that one.'
    }
    if (-not (Slurp 'ref\gl\gl_sprite.c').Contains($stockCall)) {
        throw 'gl_sprite.c does not carry the stock R_GetSpriteFrame call this patch wraps.'
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

    $h = Slurp 'ref\gl\gl_local.h'; $o = Slurp 'ref\gl\gl_opengl.c'; $s = Slurp 'ref\gl\gl_sprite.c'
    if ($Reverse) {
        if ($h.Contains('cof_sprite_') -or $o.Contains('cof_sprite_') -or $s.Contains('cof_sprite_') -or -not $s.Contains($stockCall)) {
            throw 'Reverse did not restore the stock sprite code.'
        }
        if (-not $h.Contains('extern convar_t cof_viewmodel_fov;')) { throw 'Reverse damaged the viewmodel field-of-view patch.' }
        Write-Host "Reversed the CoF sprite quiet-frames change in $source"
        return
    }
    $ok = $h.Contains('extern convar_t cof_sprite_quiet_frames;') -and
          $h.Contains('extern convar_t cof_sprite_trace;') -and
          $o.Contains('Cvar_RegisterVariable( &cof_sprite_quiet_frames )') -and
          $o.Contains('Cvar_RegisterVariable( &cof_sprite_trace )') -and
          $s.Contains('CVAR_DEFINE_AUTO( cof_sprite_quiet_frames, "1", FCVAR_GLCONFIG') -and
          $s.Contains('CVAR_DEFINE_AUTO( cof_sprite_trace, "0", 0') -and
          $s.Contains('static int R_CoFSpriteFrame(') -and
          -not $s.Contains($stockCall)
    if (-not $ok) { throw 'Patch command completed without the expected sprite quiet-frames markers.' }
} finally {
    Pop-Location
}
Write-Host "Applied the CoF sprite quiet-frames change to $source"
