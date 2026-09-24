param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)

# Cry of Fear: the live world behind the in-play panels
# (patches/cof-panel-transparency.patch, engine + FreeVGUI):
#
#   * cof_panel_transparent (saved, default 1): while the inventory, a note,
#     the tape recorder page, the phone, the keypad, the computer, the statue,
#     the landline, the documents list or a billboard is open, the support
#     library skips exactly the client's opaque black backdrop fills, so the
#     world shows around the art (3rdparty/freevgui/platform/xash3d-fwgs/
#     cofbackdrop.cpp, through two paint filters added to Panel::paintTraverse
#     and Panel::paintBackground in 3rdparty/freevgui/panel.cpp/.h);
#   * cof_panel_plate_alpha (saved, default 200): the rusty plate
#     gfx/vgui/backgroundtoall.tga at that opacity - recognised by the file
#     name the client loaded through COM_LoadFile just before it built the
#     bitmap (engine/client/dll_int/cl_game.c, CL_CoF_LoadFile), and drawn
#     through a Bitmap paint hook (3rdparty/freevgui/image.cpp/.h);
#   * cof_panel_hide_hud (saved, default 2): 0 keep the HUD container,
#     1 hide it, 2 hide only the pieces that overlap the open panel's art;
#     letterbox bars are never hidden;
#   * the backing strip under strip-backed VGUI text is only as opaque as the
#     most opaque glyph on its line (3rdparty/freevgui/platform/xash3d-fwgs/
#     surface.cpp): a faded caption no longer leaves a dark bar over the world.
#   Engine side: engine/client/cof_panel_transparency.c, two vguiapi_t entries
#   (engine/vgui_api.h, engine/client/vgui/vgui_draw.c), the cvar registration
#   in engine/client/cl_main.c.
#
# Goes on right after apply-cof-panel-pause.ps1 (its panel identification is
# what tells an inventory from a telescope) and BEFORE apply-cof-cheats.ps1.
# See docs/patches/cof-panel-transparency.md.

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
    'engine\client\cl_main.c',
    'engine\client\dll_int\cl_game.c',
    '3rdparty\freevgui\panel.h',
    '3rdparty\freevgui\panel.cpp',
    '3rdparty\freevgui\image.h',
    '3rdparty\freevgui\image.cpp',
    '3rdparty\freevgui\platform\xash3d-fwgs\app.cpp',
    '3rdparty\freevgui\platform\xash3d-fwgs\support.h',
    '3rdparty\freevgui\platform\xash3d-fwgs\surface.cpp'
)
$newFiles = @(
    'engine\client\cof_panel_transparency.c',
    '3rdparty\freevgui\platform\xash3d-fwgs\cofbackdrop.cpp'
)
foreach ($relative in $targets) {
    if (!(Test-Path -LiteralPath (Join-Path $source $relative))) {
        throw "Not an FWGS source tree with freevgui checked out: $(Join-Path $source $relative)"
    }
}
$patch = Join-Path $root 'patches\cof-panel-transparency.patch'
if (!(Test-Path -LiteralPath $patch -PathType Leaf)) { throw "Missing patch: $patch" }

function Slurp([string] $rel) { Get-Content -Raw -LiteralPath (Join-Path $source $rel) }
function Exists([string] $rel) { Test-Path -LiteralPath (Join-Path $source $rel) }

$api   = Slurp 'engine\vgui_api.h'
$game  = Slurp 'engine\client\dll_int\cl_game.c'
$panel = Slurp '3rdparty\freevgui\panel.cpp'
$image = Slurp '3rdparty\freevgui\image.cpp'
$surf  = Slurp '3rdparty\freevgui\platform\xash3d-fwgs\surface.cpp'
$app   = Slurp '3rdparty\freevgui\platform\xash3d-fwgs\app.cpp'

$present = $api.Contains('CofPanelConfig') -or $game.Contains('CL_CoF_PanelImageLoad') -or
           $panel.Contains('Panel_SetPaintFilters') -or $image.Contains('Bitmap_SetHooks') -or
           $surf.Contains('lineOpacity') -or $app.Contains('CofBackdrop_') -or
           ($newFiles | Where-Object { Exists $_ })

if ($Reverse) {
    if (-not $present) { throw 'The panel transparency is not present in this source tree; nothing to reverse.' }
} else {
    if ($present) { throw 'The panel transparency is already present; use -Reverse first or provide a clean patched tree.' }
    if (-not $api.Contains('int	(*CofPanelReport)( unsigned int visible );') -or
        -not (Exists '3rdparty\freevgui\platform\xash3d-fwgs\cofpanels.cpp')) {
        throw 'Prerequisite missing: apply scripts\apply-cof-panel-pause.ps1 first (panel identification).'
    }
    # the milestone 4 hooks and the milestone 4b/5b strip this extends
    if (-not $panel.Contains('g_panelSolveHook( this );') -or -not $game.Contains('CL_CoF_FontLatch( scheme );') -or
        -not $surf.Contains('drawSetColor( 0, 0, 0, 255 - backingAlpha );')) {
        throw 'Prerequisite missing: apply scripts\apply-cof-vgui-anchor.ps1, apply-cof-vgui-inter-fonts.ps1 and apply-cof-hud-text-backing.ps1 first.'
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

    $api   = Slurp 'engine\vgui_api.h'
    $draw  = Slurp 'engine\client\vgui\vgui_draw.c'
    $main  = Slurp 'engine\client\cl_main.c'
    $game  = Slurp 'engine\client\dll_int\cl_game.c'
    $ph    = Slurp '3rdparty\freevgui\panel.h'
    $panel = Slurp '3rdparty\freevgui\panel.cpp'
    $ih    = Slurp '3rdparty\freevgui\image.h'
    $image = Slurp '3rdparty\freevgui\image.cpp'
    $app   = Slurp '3rdparty\freevgui\platform\xash3d-fwgs\app.cpp'
    $sup   = Slurp '3rdparty\freevgui\platform\xash3d-fwgs\support.h'
    $surf  = Slurp '3rdparty\freevgui\platform\xash3d-fwgs\surface.cpp'

    if ($Reverse) {
        if ($api.Contains('CofPanelConfig') -or $api.Contains('cof_vgui_panel_cfg_t') -or $draw.Contains('CL_CoF_PanelConfig') -or
            $main.Contains('CL_CoF_PanelTransparencyInit') -or $game.Contains('CL_CoF_PanelImageLoad') -or
            $ph.Contains('Panel_SetPaintFilters') -or $panel.Contains('g_panelSkip') -or $ih.Contains('Bitmap_SetHooks') -or
            $image.Contains('g_bitmap') -or $app.Contains('CofBackdrop_') -or $sup.Contains('CofBackdrop_') -or
            $surf.Contains('lineOpacity') -or ($newFiles | Where-Object { Exists $_ })) {
            throw 'Reversed, but panel-transparency markers remain. Inspect the tree.'
        }
        if (-not $api.Contains('int	(*CofPanelReport)( unsigned int visible );') -or
            -not $surf.Contains('drawSetColor( 0, 0, 0, 255 - backingAlpha );')) {
            throw 'Reverse application damaged the patches this one sits on.'
        }
        Write-Host "Reversed patches\cof-panel-transparency.patch in $source"
        return
    }

    foreach ($rel in $newFiles) { if (-not (Exists $rel)) { throw "Applied, but $rel was not created. Inspect the tree." } }
    $trans = Slurp 'engine\client\cof_panel_transparency.c'
    $bd    = Slurp '3rdparty\freevgui\platform\xash3d-fwgs\cofbackdrop.cpp'

    $ok = $api.Contains('} cof_vgui_panel_cfg_t;') -and
          $api.Contains('int	(*CofPanelConfig)( cof_vgui_panel_cfg_t *out );') -and
          $api.Contains('int	(*CofImageLatch)( char *buf, int size );') -and
          $draw.Contains("	CL_CoF_PanelConfig,") -and $draw.Contains("	CL_CoF_PanelImageLatch,") -and
          $main.Contains('CL_CoF_PanelTransparencyInit(); }') -and
          $game.Contains('CL_CoF_PanelImageLoad( filename );') -and
          $trans.Contains('static CVAR_DEFINE_AUTO( cof_panel_transparent, "1", FCVAR_ARCHIVE,') -and
          $trans.Contains('static CVAR_DEFINE_AUTO( cof_panel_plate_alpha, "200", FCVAR_ARCHIVE,') -and
          $trans.Contains('static CVAR_DEFINE_AUTO( cof_panel_hide_hud, "2", FCVAR_ARCHIVE,')
    if (-not $ok) { throw 'Applied, but the engine panel-transparency markers are missing. Inspect the tree.' }

    $ok = $ph.Contains('void Panel_SetPaintFilters( PanelPaintFilterFn skipTraverse, PanelPaintFilterFn skipBackground );') -and
          $panel.Contains('if( visible && g_panelSkipTraverse && g_panelSkipTraverse( this ))') -and
          $panel.Contains('if( g_panelSkipBackground && g_panelSkipBackground( this ))') -and
          $ih.Contains('void Bitmap_SetHooks( BitmapCreatedFn created, BitmapPaintFn paint );') -and
          $image.Contains('g_bitmapPaintHook( this, p, r, g, b, a );') -and $image.Contains('g_bitmapCreatedHook( this );') -and
          $app.Contains('CofBackdrop_Frame( panel );') -and $app.Contains('CofBackdrop_Install();') -and
          $sup.Contains('void CofBackdrop_Frame( Panel *root );') -and
          $surf.Contains('drawSetColor( 0, 0, 0, 255 - backingAlpha * lineOpacity / 255 );') -and
          $bd.Contains('bool CofIsBackdrop( Panel *panel )') -and $bd.Contains('CofNameIs( name, "backgroundtoall" )')
    if (-not $ok) { throw 'Applied, but the support-library panel-transparency markers are missing. Inspect the tree.' }

    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Applied panel-transparency patch cannot be reverse-checked.' }
} finally {
    Pop-Location
}
Write-Host "Applied patches\cof-panel-transparency.patch in $source"
Write-Host 'Build: python waf build --targets=xash,vgui (the two go together)'
