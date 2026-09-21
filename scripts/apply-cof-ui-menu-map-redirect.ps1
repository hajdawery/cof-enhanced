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
    'engine\client\cl_main.c',
    'engine\client\client.h',   # read for the prerequisite check only
    'engine\client\dll_int\cl_game.c',
    'engine\client\parse\cl_parse.c',
    'engine\common\common.h',
    'engine\server\sv_cmds.c',
    'engine\server\sv_game.c'
)
$patch = Join-Path $root 'patches\cof-ui-menu-map-redirect.patch'

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

$main    = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\cl_main.c')
$header  = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\client.h')
$clgame  = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\dll_int\cl_game.c')
$clparse = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\parse\cl_parse.c')
$common  = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\common\common.h')
$svcmds  = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\server\sv_cmds.c')
$svgame  = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\server\sv_game.c')

if ($main.Contains('cof_ui_menu_map_redirect') -or $common.Contains('CL_CoF_MenuMapRedirect') -or
    $svcmds.Contains('CL_CoF_MenuMapLevelChange')) {
    throw 'The CoF menu-map redirect is already present; use a clean patched source tree.'
}
# prerequisite 1: the unified UI input gate. This patch adds a cvar to that
# family and hangs its cl_main.c hunks off the gate's own lines.
if (-not ($main.Contains('CVAR_DEFINE_AUTO( cof_ui_deferred_cmd_guard, "1"') -and
          $header.Contains('qboolean CL_CoF_UIGateActive( void );'))) {
    throw 'Apply scripts\apply-cof-ui-input-gate.ps1 first: this patch builds on the unified UI input gate.'
}
# prerequisite 2: the video-mode background restart. Its cof_vid_restart_pending
# and CL_CoF_VidRestartForget lines are this patch's cl_main.c hunk context.
if (-not ($main.Contains('static qboolean	cof_vid_restart_pending;') -and
          $main.Contains('void CL_CoF_VidRestartForget( void )'))) {
    throw 'Apply scripts\apply-cof-vid-restart-background.ps1 first: this patch uses its lines as hunk context.'
}
# prerequisite 3: the menu-load trace. Its lines inside pfnServerCommand are the
# context of this patch's only sv_game.c hunk.
if (-not $svgame.Contains('cof_trace_menu_load')) {
    throw 'Apply scripts\apply-cof-menu-load-trace.ps1 first: this patch uses its pfnServerCommand lines as hunk context.'
}

Push-Location $root
try {
    $relativeSource = $source.Substring($rootPrefix.Length).Replace('\','/')
    & git apply --ignore-whitespace --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Patch does not apply cleanly to this source tree.' }
    & git apply --ignore-whitespace --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'git apply failed.' }

    $mainAfter    = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\cl_main.c')
    $clgameAfter  = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\dll_int\cl_game.c')
    $clparseAfter = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\parse\cl_parse.c')
    $commonAfter  = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\common\common.h')
    $svcmdsAfter  = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\server\sv_cmds.c')
    $svgameAfter  = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\server\sv_game.c')

    $present =
        $mainAfter.Contains('static CVAR_DEFINE_AUTO( cof_ui_menu_map_redirect, "1"') -and
        $mainAfter.Contains('Cvar_RegisterVariable( &cof_ui_menu_map_redirect )') -and
        $mainAfter.Contains('qboolean CL_CoF_MenuMapRedirect( const char *cmd, const char *source )') -and
        $mainAfter.Contains('qboolean CL_CoF_MenuMapLevelChange( const char *mapname, const char *source )') -and
        $mainAfter.Contains('void CL_CoF_RememberBackgroundMap( const char *mapname )') -and
        $mainAfter.Contains('#define COF_MENU_MAP') -and
        $mainAfter.Contains('scripts/chapterbackgrounds.txt') -and
        $mainAfter.Contains('disconnect\nmenu_main\nmap_background %s\n') -and
        $clgameAfter.Contains('CL_CoF_MenuMapRedirect( szCmdString, "client pfnClientCmd" )') -and
        $clparseAfter.Contains('CL_CoF_MenuMapRedirect( s, "server svc_stufftext" )') -and
        $commonAfter.Contains('qboolean CL_CoF_MenuMapRedirect( const char *cmd, const char *source );') -and
        $commonAfter.Contains('static inline qboolean CL_CoF_MenuMapLevelChange( const char *mapname, const char *source ) { return false; }') -and
        $svcmdsAfter.Contains('CL_CoF_RememberBackgroundMap( mapname );') -and
        $svcmdsAfter.Contains('CL_CoF_MenuMapLevelChange( mapname, "map command" )') -and
        $svcmdsAfter.Contains('CL_CoF_MenuMapLevelChange( Cmd_Argv( 1 ), "changelevel command" )') -and
        $svgameAfter.Contains('CL_CoF_MenuMapRedirect( str, "server pfnServerCommand" )')

    if (-not $present) {
        throw 'Patch command completed without the expected source markers.'
    }

    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) {
        throw 'Applied menu-map redirect patch cannot be reverse-checked.'
    }
} finally {
    Pop-Location
}

Write-Host "Applied CoF unified UI menu-map redirect to $source"
