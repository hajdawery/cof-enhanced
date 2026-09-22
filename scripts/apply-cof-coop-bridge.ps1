param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)

# Cry of Fear co-op bridge, engine half (patches/cof-coop-bridge.patch):
#
#   (a) cof_ui_remote_end_menu: when a session with a REMOTE server ends (the
#       host quits or its server shuts down, a kick, a timeout, a refused or
#       failed connection, or our own disconnect) the engine menu comes back
#       over the background map instead of the console over black
#       (engine/client/cl_main.c: CL_CoF_NoteSessionEnd in CL_Disconnect, the
#       queued command cof_ui_session_end);
#   (c) cof_vgui_text_overflow: a centred line of strip-backed client VGUI
#       text wider than its own label on both sides may use its parent panel's
#       width - the co-op lobby's two hint lines (engine/vgui_api.h,
#       engine/client/cl_main.c, 3rdparty/freevgui/.../surface.cpp);
#   (d) Cmd_ExecScript newline order (engine/common/cmd.c), upstreamable.
#
# The menu half (pause menu in multiplayer, Host/Join co-op pages) is
# patches/cof-mainui-coop.patch. See docs/cof-coop-bridge.md.
#
# Goes after the whole documented engine stack including the milestone-5b
# patches and cof-language-packs, and BEFORE apply-cof-cheats.ps1 (which
# touches none of these files).

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!(Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "SourceRoot must be an existing directory: $SourceRoot"
}
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
$targets = @(
    'engine\client\cl_main.c',
    'engine\common\cmd.c',
    'engine\vgui_api.h',
    '3rdparty\freevgui\platform\xash3d-fwgs\surface.cpp'
)
$patch = Join-Path $root 'patches\cof-coop-bridge.patch'

if (!(Test-Path -LiteralPath $patch)) { throw "Missing patch: $patch" }
foreach ($relative in $targets) {
    if (!(Test-Path -LiteralPath (Join-Path $source $relative))) {
        throw "Not an FWGS source tree with freevgui checked out: $(Join-Path $source $relative)"
    }
}
$rootPrefix = $root.TrimEnd('\') + '\'
if (-not $source.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}

function Slurp([string] $rel) { Get-Content -Raw -LiteralPath (Join-Path $source $rel) }

$main = Slurp 'engine\client\cl_main.c'
$cmd  = Slurp 'engine\common\cmd.c'
$api  = Slurp 'engine\vgui_api.h'
$surf = Slurp '3rdparty\freevgui\platform\xash3d-fwgs\surface.cpp'

$present = $main.Contains('cof_ui_remote_end_menu') -or $main.Contains('cof_vgui_text_overflow') -or
           $surf.Contains('CofTextOverflowOn') -or $api.Contains('int	overflow;') -or
           $cmd.Contains('cof-coop-bridge')

if ($Reverse) {
    if (-not $present) { throw 'The co-op bridge is not present in this source tree; nothing to reverse.' }
} else {
    if ($present) { throw 'The co-op bridge is already present; use -Reverse first or provide a clean patched tree.' }
    # (a) sits on the menu-map redirect: its background-map choice and the
    # disconnect wrapper this complements
    if (-not $main.Contains('static const char *CL_CoF_MenuBackgroundMap( const char *requested )') -or
        -not $main.Contains('static void CL_CoF_Disconnect_f( void )')) {
        throw 'Prerequisite missing: apply scripts\apply-cof-ui-menu-map-redirect.ps1 (with the disconnect wrapper) first.'
    }
    # (c) extends the milestone 4b/5b backing-strip collector and its descriptor
    if (-not $surf.Contains('bool XashSurface::runIsTopBand( void ) const') -or
        -not $api.Contains('int	backing;') -or -not $main.Contains('out->trace = ( cof_hud_text_trace.value != 0.0f ) ? 1 : 0;')) {
        throw 'Prerequisite missing: apply scripts\apply-cof-hud-text-backing.ps1 (milestone 5b) first.'
    }
    # (d) the stock lines
    if ($cmd -notmatch 'Cbuf_InsertTextLen\( f, len, len \+ 1 \);\r?\n\t\tCbuf_InsertTextLen\( "\\n", 1, 1 \);') {
        throw 'engine\common\cmd.c does not carry the stock Cmd_ExecScript newline lines this patch fixes.'
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

    $main = Slurp 'engine\client\cl_main.c'
    $cmd  = Slurp 'engine\common\cmd.c'
    $api  = Slurp 'engine\vgui_api.h'
    $surf = Slurp '3rdparty\freevgui\platform\xash3d-fwgs\surface.cpp'

    if ($Reverse) {
        if ($main.Contains('cof_ui_remote_end_menu') -or $main.Contains('cof_ui_session_end') -or
            $main.Contains('cof_vgui_text_overflow') -or $surf.Contains('CofTextOverflowOn') -or
            $api.Contains('int	overflow;') -or $cmd.Contains('cof-coop-bridge')) {
            throw 'Reversed, but co-op bridge markers remain. Inspect the tree.'
        }
        if (-not $main.Contains('static void CL_CoF_Disconnect_f( void )') -or -not $surf.Contains('bool XashSurface::runIsTopBand( void ) const')) {
            throw 'Reverse application damaged the patches this one sits on.'
        }
        Write-Host "Reversed patches\cof-coop-bridge.patch in $source"
        return
    }

    # (a) the hook runs first thing in CL_Disconnect, before the address is cleared
    $iDisc = $main.IndexOf('void CL_Disconnect( void )')
    $iHook = $main.IndexOf('CL_CoF_NoteSessionEnd();', $iDisc)
    $iClear = $main.IndexOf('memset( &cls.serveradr, 0, sizeof( cls.serveradr ));', $iDisc)
    $ok = $iDisc -ge 0 -and $iHook -gt $iDisc -and $iClear -gt $iHook -and
          $main.Contains('static void CL_CoF_SessionEnd_f( void )') -and
          $main.Contains('Cvar_RegisterVariable( &cof_ui_remote_end_menu );') -and
          $main.Contains('Cmd_AddCommand ("cof_ui_session_end", CL_CoF_SessionEnd_f,') -and
          $main.Contains('if( NET_IsLocalAddress( cls.serveradr ))')
    if (-not $ok) { throw 'Applied, but the remote-session-end markers are missing or out of order. Inspect the tree.' }

    # (c) descriptor field, engine cvar, support-library use
    $ok = $api.Contains('int	overflow;') -and
          $main.Contains('out->overflow = ( cof_vgui_text_overflow.value != 0.0f ) ? 1 : 0;') -and
          $main.Contains('Cvar_RegisterVariable( &cof_vgui_text_overflow );') -and
          $surf.Contains('static bool CofTextOverflowOn( void )') -and
          $surf.Contains('if( line.minx < lineClip[0] && line.maxx > lineClip[2] && CofTextOverflowOn( ))') -and
          $surf.Contains('if( lineWidened )')
    if (-not $ok) { throw 'Applied, but the lobby-text overflow markers are missing. Inspect the tree.' }

    # (d) newline first, then the file
    if ($cmd -notmatch 'Cbuf_InsertTextLen\( "\\n", 1, len \+ 1 \);\r?\n\t\tCbuf_InsertTextLen\( f, len, len \);') {
        throw 'Applied, but the Cmd_ExecScript order is not the fixed one. Inspect the tree.'
    }

    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Applied co-op bridge patch cannot be reverse-checked.' }
} finally {
    Pop-Location
}
Write-Host "Applied patches\cof-coop-bridge.patch in $source"
Write-Host 'Build: python waf build --targets=xash,vgui'
