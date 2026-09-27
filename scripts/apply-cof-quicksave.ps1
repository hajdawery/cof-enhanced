param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)

# Cry of Fear quick save and quick load, the engine half
# (patches/cof-quicksave.patch). See docs/patches/cof-quicksave.md.
#
#   * engine/client/cof_quicksave.c (new): the saved cvar cof_quick_saves
#     (default 0) and the commands cof_quicksave (F5) / cof_quickload (F9):
#     refused while off ("Quick saves are disabled in Options > Game"), in
#     co-op, outside play (menu map, loading), with the menu, the console or a
#     client panel open; the player is told on the game's own message strip
#     (the "ProFont" user message hl.dll uses for its "Saved" and the pickup
#     lines); CL_CoF_QuickSaveFrame shows "Quick loaded" once the level is up.
#   * engine/server/sv_save.c: the pause-menu save's transaction becomes
#     SV_CoFSaveTransaction, shared by SV_CoFMenuSave (unchanged behaviour)
#     and the new SV_CoFQuickSave (SAVE/cofquick.sav + .bmp, label
#     cryoffear/SAVE/saveinfoquick.cof); SV_CoFQuickSaveExists.
#   * engine/server/server.h: COF_QUICKSAVE_NAME and the two declarations.
#   * engine/client/cl_main.c: CL_CoF_QuickSaveInit in CL_InitLocal,
#     CL_CoF_QuickSaveFrame in Host_ClientFrame.
#
# Needs the save stack (cof-save-root-compat, cof-menu-save-backend) and the
# death flow's CL_CoF_DeathPump; sits after cof-window-name, before
# cof-panel-pause in docs/dev/patch-stack.md.

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!(Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "SourceRoot must be an existing directory: $SourceRoot"
}
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
$rootPrefix = $root.TrimEnd('\') + '\'
if (-not $source.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}
$rel = @{
    save = 'engine\server\sv_save.c'
    hdr  = 'engine\server\server.h'
    main = 'engine\client\cl_main.c'
}
$newRel = 'engine\client\cof_quicksave.c'
foreach ($r in $rel.Values) {
    if (!(Test-Path -LiteralPath (Join-Path $source $r))) {
        throw "Not an FWGS source tree: $(Join-Path $source $r)"
    }
}
$patch = Join-Path $root 'patches\cof-quicksave.patch'
if (!(Test-Path -LiteralPath $patch -PathType Leaf)) { throw "Missing patch: $patch" }

function Slurp([string] $r) {
    $p = Join-Path $source $r
    if (Test-Path -LiteralPath $p) { Get-Content -Raw -LiteralPath $p } else { '' }
}
function ReadAll {
    $t = @{}
    foreach ($k in @($rel.Keys)) { $t[$k] = Slurp ([string]$rel[$k]) }
    $t['new'] = Slurp $newRel
    return $t
}

$t = ReadAll
$present = $t.save.Contains('SV_CoFSaveTransaction') -or $t.hdr.Contains('COF_QUICKSAVE_NAME') -or
           $t.main.Contains('CL_CoF_QuickSave') -or $t.new

if ($Reverse) {
    if (-not $present) { throw 'The quick save patch is not present in this source tree; nothing to reverse.' }
} else {
    if ($present) { throw 'The quick save patch is already present; use -Reverse first or provide a clean tree.' }
    if (-not $t.save.Contains('qboolean SV_CoFMenuSave( int slot )') -or -not $t.save.Contains('static qboolean SV_CoFRootSaveCompat( void )')) {
        throw 'Prerequisite missing: apply patches/cof-save-root-compat.patch and patches/cof-menu-save-backend.patch first.'
    }
    if (-not $t.main.Contains('CL_CoF_DeathPump ();') -or -not $t.main.Contains('V_CoF_RegisterFovCvars(); }')) {
        throw 'Prerequisite missing: apply the death flow (cof-ui-death-flow) and cof-fov first.'
    }
}

Push-Location $root
try {
    $relativeSource = $source.Substring($rootPrefix.Length).Replace('\','/')
    $extra = @()
    if ($Reverse) { $extra += '--reverse' }
    & git apply --ignore-whitespace --check --directory=$relativeSource @extra -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Patch does not apply cleanly to this source tree.' }
    & git apply --ignore-whitespace --directory=$relativeSource @extra -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'git apply failed.' }

    $t = ReadAll

    if ($Reverse) {
        if ($t.save.Contains('SV_CoFSaveTransaction') -or $t.hdr.Contains('COF_QUICKSAVE_NAME') -or $t.main.Contains('CL_CoF_QuickSave') -or $t.new) {
            throw 'Reversed, but quick save markers or files remain. Inspect the tree.'
        }
        if (-not $t.save.Contains('qboolean SV_CoFMenuSave( int slot )')) { throw 'Reverse application damaged the menu-save backend.' }
        Write-Host "Reversed patches\cof-quicksave.patch in $source"
        return
    }

    $checks = [ordered]@{
        'quick save commands'   = $t.new.Contains('void CL_CoF_QuickSaveInit( void )') -and $t.new.Contains('"cof_quicksave"') -and
                                  $t.new.Contains('"cof_quickload"') -and $t.new.Contains('CVAR_DEFINE_AUTO( cof_quick_saves, "0", FCVAR_ARCHIVE,') -and
                                  $t.new.Contains('CL_DispatchUserMessage( "ProFont", len, buf )') -and $t.new.Contains('void CL_CoF_QuickSaveFrame( void )')
        'shared transaction'    = $t.save.Contains('static qboolean SV_CoFSaveTransaction( const char *name, const char *label, const char *title, const char *what )') -and
                                  $t.save.Contains('qboolean SV_CoFQuickSave( void )') -and $t.save.Contains('"SAVE/saveinfoquick.cof"') -and
                                  $t.save.Contains('qboolean SV_CoFQuickSaveExists( void )') -and
                                  $t.save.Contains('Con_Printf( "CoF menu save committed to slot %d.\n", slot );')
        'declarations'          = $t.hdr.Contains('#define COF_QUICKSAVE_NAME "cofquick"') -and $t.hdr.Contains('qboolean SV_CoFQuickSave( void );')
        'init and frame hooks'  = $t.main.Contains('{ void CL_CoF_QuickSaveInit( void ); CL_CoF_QuickSaveInit(); }') -and
                                  $t.main.Contains('{ void CL_CoF_QuickSaveFrame( void ); CL_CoF_QuickSaveFrame(); }')
    }
    foreach ($k in $checks.Keys) {
        if (-not $checks[$k]) { throw "Applied, but the marker for '$k' is missing. Inspect the tree." }
    }

    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Applied quick save patch cannot be reverse-checked.' }
} finally {
    Pop-Location
}
Write-Host "Applied patches\cof-quicksave.patch in $source"
Write-Host 'Build: python waf build --targets=xash'
