param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)

# Cry of Fear panel pause (patches/cof-panel-pause.patch, engine + FreeVGUI):
#
#   * cof_panel_pause (saved, default 0): in single player the server stops
#     simulating while a "tier 1" in-play panel is open - the inventory, the
#     documents list, a note, a user document, a billboard, a YES/NO question,
#     the tape recorder's SAVED GAMES page and its confirm box - and never
#     while the phone, the landline, the computer, the padlock or the boiler
#     puzzle is up (engine/client/cof_panel_pause.c; hooked in SV_IsSimulating,
#     engine/server/sv_main.c, and the usercmd zeroing in
#     SV_ExecuteClientMessage, engine/server/sv_client.c). Not the `pause`
#     command: the client clock, sound, music and the HUD keep running.
#   * per-panel identity: the VGUI support library names every visible client
#     panel by its class (MSVC run-time type information in client.dll) and
#     reports one COF_PANEL_* bit per class each painted frame
#     (3rdparty/freevgui/platform/xash3d-fwgs/cofpanels.cpp, cofmem.cpp;
#     vguiapi_t::CofPanelReport in engine/vgui_api.h).
#   * cof_panel_trace (developer) and the cof_panel_status command.
#
# Goes on after the whole documented stack up to apply-cof-notify-option.ps1
# (step 47) and BEFORE apply-cof-cheats.ps1, which still applies on top.
# apply-cof-panel-transparency.ps1 builds on this one.
# See docs/patches/cof-panel-pause.md.

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
$targets = @(
    'engine\vgui_api.h',
    'engine\client\vgui\vgui_draw.c',
    'engine\common\common.h',
    'engine\server\sv_main.c',
    'engine\server\sv_client.c',
    'engine\client\cl_main.c',
    '3rdparty\freevgui\platform\xash3d-fwgs\app.cpp',
    '3rdparty\freevgui\platform\xash3d-fwgs\support.h'
)
$newFiles = @(
    'engine\client\cof_panel_pause.c',
    '3rdparty\freevgui\platform\xash3d-fwgs\cofpanels.cpp',
    '3rdparty\freevgui\platform\xash3d-fwgs\cofmem.cpp'
)
foreach ($relative in $targets) {
    if (!(Test-Path -LiteralPath (Join-Path $source $relative))) {
        throw "Not an FWGS source tree with freevgui checked out: $(Join-Path $source $relative)"
    }
}
$patch = Join-Path $root 'patches\cof-panel-pause.patch'
if (!(Test-Path -LiteralPath $patch -PathType Leaf)) { throw "Missing patch: $patch" }

function Slurp([string] $rel) { Get-Content -Raw -LiteralPath (Join-Path $source $rel) }
function Exists([string] $rel) { Test-Path -LiteralPath (Join-Path $source $rel) }

$api  = Slurp 'engine\vgui_api.h'
$main = Slurp 'engine\client\cl_main.c'
$svc  = Slurp 'engine\server\sv_client.c'
$app  = Slurp '3rdparty\freevgui\platform\xash3d-fwgs\app.cpp'

$present = $api.Contains('CofPanelReport') -or $main.Contains('CL_CoF_PanelPauseInit') -or
           $svc.Contains('CL_CoF_PanelPaused') -or $app.Contains('CofPanels_Frame') -or
           ($newFiles | Where-Object { Exists $_ })

if ($Reverse) {
    if (-not $present) { throw 'The panel pause is not present in this source tree; nothing to reverse.' }
    if ((Exists 'engine\client\cof_panel_transparency.c') -or $api.Contains('CofPanelConfig')) {
        throw 'apply-cof-panel-transparency.ps1 sits on this patch: reverse it first.'
    }
} else {
    if ($present) { throw 'The panel pause is already present; use -Reverse first or provide a clean patched tree.' }
    # the death page's usercmd gate this extends (cof-ui-death-live), the
    # language packs' last vguiapi_t entry it appends after, and the frame
    # hook the support library already runs (milestone 4)
    if (-not $svc.Contains('if( sv.paused || !CL_IsInGame() || CL_CoF_DeathWorldLive() || SV_PlayerIsFrozen( player ))') -or
        -not $main.Contains('Cvar_RegisterVariable( &cof_ui_death_keep_running );')) {
        throw 'Prerequisite missing: apply scripts\apply-cof-ui-death-live.ps1 first.'
    }
    if (-not $api.Contains('const char *(*CofLangString)( const char *str );')) {
        throw 'Prerequisite missing: apply scripts\apply-cof-language-packs.ps1 first.'
    }
    if (-not $app.Contains('staticApp.externalTick();') -or -not $app.Contains('CofUI_Refresh();')) {
        throw 'Prerequisite missing: apply scripts\apply-cof-vgui-anchor.ps1 first.'
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

    $api  = Slurp 'engine\vgui_api.h'
    $draw = Slurp 'engine\client\vgui\vgui_draw.c'
    $com  = Slurp 'engine\common\common.h'
    $svm  = Slurp 'engine\server\sv_main.c'
    $svc  = Slurp 'engine\server\sv_client.c'
    $main = Slurp 'engine\client\cl_main.c'
    $app  = Slurp '3rdparty\freevgui\platform\xash3d-fwgs\app.cpp'
    $sup  = Slurp '3rdparty\freevgui\platform\xash3d-fwgs\support.h'

    if ($Reverse) {
        if ($api.Contains('CofPanelReport') -or $api.Contains('COF_PANEL_INVENTORY') -or $draw.Contains('CL_CoF_PanelReport') -or
            $com.Contains('CL_CoF_PanelPaused') -or $svm.Contains('CL_CoF_PanelPaused') -or $svc.Contains('CL_CoF_PanelPaused') -or
            $main.Contains('CL_CoF_PanelPauseInit') -or $app.Contains('CofPanels_Frame') -or $sup.Contains('CofPanels_') -or
            ($newFiles | Where-Object { Exists $_ })) {
            throw 'Reversed, but panel-pause markers remain. Inspect the tree.'
        }
        if (-not $svc.Contains('CL_CoF_DeathWorldLive() || SV_PlayerIsFrozen( player )')) {
            throw 'Reverse application damaged the patches this one sits on.'
        }
        Write-Host "Reversed patches\cof-panel-pause.patch in $source"
        return
    }

    foreach ($rel in $newFiles) { if (-not (Exists $rel)) { throw "Applied, but $rel was not created. Inspect the tree." } }
    $pause  = Slurp 'engine\client\cof_panel_pause.c'
    $panels = Slurp '3rdparty\freevgui\platform\xash3d-fwgs\cofpanels.cpp'
    $mem    = Slurp '3rdparty\freevgui\platform\xash3d-fwgs\cofmem.cpp'

    $ok = $api.Contains('COF_PANEL_INVENTORY	= 1 << 0,') -and $api.Contains('COF_PANEL_PUZZLEBAR	= 1 << 12,') -and
          $api.Contains('int	(*CofPanelReport)( unsigned int visible );') -and
          $draw.Contains('int CL_CoF_PanelReport( unsigned int visible ); // cof_panel_pause.c') -and
          $draw.Contains("	CL_CoF_PanelReport,") -and
          $com.Contains('qboolean CL_CoF_PanelPaused( void );') -and
          $com.Contains('static inline qboolean CL_CoF_PanelPaused( void ) { return false; }') -and
          $svm.Contains('if( svs.maxclients <= 1 && CL_CoF_PanelPaused( ))') -and
          $svc.Contains('CL_CoF_DeathWorldLive() || CL_CoF_PanelPaused() || SV_PlayerIsFrozen( player )') -and
          $main.Contains('CL_CoF_PanelPauseInit(); }') -and
          $pause.Contains('static CVAR_DEFINE_AUTO( cof_panel_pause, "0", FCVAR_ARCHIVE,') -and
          $pause.Contains('Cmd_AddCommand( "cof_panel_status", CL_CoF_PanelStatus_f,') -and
          $com.Contains('unsigned int CL_CoF_PanelsOnScreen( qboolean *reporting );') -and
          $pause.Contains('unsigned int CL_CoF_PanelsOnScreen( qboolean *reporting )')
    if (-not $ok) { throw 'Applied, but the engine panel-pause markers are missing. Inspect the tree.' }

    $ok = $app.Contains('CofPanels_Frame( panel );') -and
          $sup.Contains('void CofPanels_Frame( Panel *root );') -and
          $panels.Contains('{ ".?AVCRECBInventory@@",     COF_PANEL_INVENTORY },') -and
          $panels.Contains('g_engine->CofPanelReport( g_cofFrame.visible )') -and
          $mem.Contains('bool CofMemReadable( const void *ptr, size_t size )')
    if (-not $ok) { throw 'Applied, but the support-library panel-identity markers are missing. Inspect the tree.' }

    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Applied panel-pause patch cannot be reverse-checked.' }
} finally {
    Pop-Location
}
Write-Host "Applied patches\cof-panel-pause.patch in $source"
Write-Host 'Build: python waf build --targets=xash,vgui (the two go together)'
