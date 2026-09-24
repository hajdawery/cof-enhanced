param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)

# Options relayout, tabbed windows and pad navigation for Cry of Fear
# (patches/cof-mainui-options-layout.patch, MainUI only). See
# docs/design/ui-theme.md, "Options relayout, tabbed windows and the pad".
#
#   * menus/CoFOptions.cpp / .h (new): the Controls tab (Aim down sights, the
#     mouse switches, the engine's joy_* gamepad cvars incl. gyro), the Gamepad
#     tab (every pad button and its binding, icons and picture from
#     gfx/shell/gamepad/, Use defaults from the pad lines of
#     gfx/shell/kb_def.lst), the tab-group registry (Options, Extras,
#     Save/Load), pad-input tracking, and the cfg-only test hooks
#     menu_cof_options_select and menu_cof_key.
#   * controls/Framework.cpp / .h: the shared tab strip, one frame per tabbed
#     window, LB/RB and mouse tab switching in place, X = the page's secondary
#     action, first-control focus on open, the pad hints line.
#   * controls/ItemsHolder.cpp, Slider.cpp, Table.cpp: greyed controls are
#     skipped by pad/arrow navigation, a focused slider lights its label, the
#     triggers page a list.
#   * BaseMenu.cpp: the input hooks (last device, Start = resume).
#   * menus/AdvancedControls.cpp: the Game tab (mouse and aim rows moved out;
#     Pause on Inventory = cof_panel_pause, Transparent UI background =
#     cof_panel_transparent).
#   * menus/Configuration.cpp, Main.cpp: Options and Extras open their tabbed
#     windows directly.
#   * menus/Controls.cpp, model/KbActListModel.h: the Keybinds tab (title,
#     KEY_SetBinding, pad buttons left to the Gamepad tab, X = Use defaults).
#
# Goes on after cof-mainui-source-theme, cof-mainui-language-selector,
# cof-mainui-menu-strings, cof-mainui-coop and cof-notify-option, before
# apply-cof-cheats.ps1 (engine only).

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
$mu = '3rdparty\mainui\'
$rel = @{
    opt = $mu + 'menus\Configuration.cpp'; game = $mu + 'menus\AdvancedControls.cpp'
    kb = $mu + 'menus\Controls.cpp'; model = $mu + 'model\KbActListModel.h'
    fw = $mu + 'controls\Framework.cpp'; fwh = $mu + 'controls\Framework.h'
    holder = $mu + 'controls\ItemsHolder.cpp'; slider = $mu + 'controls\Slider.cpp'
    table = $mu + 'controls\Table.cpp'; base = $mu + 'BaseMenu.cpp'; main = $mu + 'menus\Main.cpp'
}
$newCpp = $mu + 'menus\CoFOptions.cpp'
$newH   = $mu + 'menus\CoFOptions.h'
foreach ($r in $rel.Values) {
    if (!(Test-Path -LiteralPath (Join-Path $source $r))) {
        throw "Not an FWGS source tree with mainui checked out: $(Join-Path $source $r)"
    }
}
$mainui = Join-Path $source '3rdparty\mainui'
$head = (& git -C $mainui rev-parse HEAD 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or $head -ne '61263995592e93a278d764807243d043d3b97c54') {
    throw "mainui must be at pinned baseline 61263995592e93a278d764807243d043d3b97c54; found $head"
}
$patch = Join-Path $root 'patches\cof-mainui-options-layout.patch'
if (!(Test-Path -LiteralPath $patch -PathType Leaf)) { throw "Missing patch: $patch" }

function Slurp([string] $r) {
    $p = Join-Path $source $r
    if (Test-Path -LiteralPath $p) { Get-Content -Raw -LiteralPath $p } else { '' }
}
function ReadAll {
    $t = @{}
    foreach ($k in @($rel.Keys)) { $t[$k] = Slurp ([string]$rel[$k]) }
    $t['cpp'] = Slurp $newCpp
    $t['h'] = Slurp $newH
    return $t
}

$t = ReadAll
$present = $t.opt.Contains('UI_CoFOptionsLayout') -or $t.game.Contains('panelPause') -or $t.kb.Contains('OptionsProbe') -or
           $t.model.Contains('UI_CoFIsPadKey') -or $t.fw.Contains('GoToTab') -or $t.base.Contains('UI_CoFInputEvent') -or
           $t.cpp -or $t.h

if ($Reverse) {
    if (-not $present) { throw 'The options layout is not present in this source tree; nothing to reverse.' }
} else {
    if ($present) { throw 'The options layout is already present; use -Reverse first or provide a clean tree.' }
    if (-not $t.opt.Contains('static const char *names[4]  = { "Game", "Controls", "GameUI_Audio", "GameUI_Video" };') -or
        -not $t.kb.Contains('SetPanel( "CONTROLS", 900, 600 );') -or -not $t.model.Contains('CollapseSections') -or
        -not $t.fw.Contains('void CMenuFramework::DrawPanelChrome()') -or -not $t.fwh.Contains('Rect  RowRect( int index ) const;')) {
        throw 'Prerequisite missing: apply patches/cof-mainui-source-theme.patch first.'
    }
    if (-not $t.game.Contains('CMenuSpinControl	langPack;') -or -not $t.game.Contains('notifyLines.LinkCvar( "cof_notify" );') -or
        -not $t.game.Contains('SetPanel( "GAME", 760, m_bCoF ? 580 + THEME_ROW_PITCH : 520 );')) {
        throw 'Prerequisite missing: apply patches/cof-mainui-language-selector.patch and patches/cof-notify-option.patch first.'
    }
    if (-not (Slurp ($mu + 'MenuStrings.cpp')).Contains('UI_LangText') -or
        -not (Slurp ($mu + 'menus\CoFCoop.cpp')).Contains('void UI_CoFHost_Menu( void )') -or
        -not $t.main.Contains('void CMenuMain::CoFExtrasCb()')) {
        throw 'Prerequisite missing: apply patches/cof-mainui-menu-strings.patch and patches/cof-mainui-coop.patch first.'
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
        if ($t.opt.Contains('UI_CoFOptionsLayout') -or $t.game.Contains('panelPause') -or $t.kb.Contains('OptionsProbe') -or
            $t.model.Contains('UI_CoFIsPadKey') -or $t.fw.Contains('GoToTab') -or $t.base.Contains('UI_CoFInputEvent') -or
            $t.holder.Contains('QMF_GRAYED )))') -or $t.cpp -or $t.h) {
            throw 'Reversed, but options-layout markers or files remain. Inspect the tree.'
        }
        if (-not $t.game.Contains('notifyLines.LinkCvar( "cof_notify" );')) { throw 'Reverse application damaged the Game page patches this one sits on.' }
        Write-Host "Reversed patches\cof-mainui-options-layout.patch in $source"
        return
    }

    $checks = [ordered]@{
        'Options opens the Game tab' = $t.opt.Contains('ADD_MENU3( menu_options, CMenuOptions, UI_Options_Menu );') -and $t.opt.Contains('UI_AdvControls_Menu();')
        'Game tab switches'          = $t.game.Contains('panelPause.LinkCvar( "cof_panel_pause" );') -and $t.game.Contains('L( "Pause on Inventory" )') -and
                                       $t.game.Contains('panelTransparent.LinkCvar( "cof_panel_transparent" );') -and $t.game.Contains('L( "Transparent UI background" )')
        'Keybinds tab'               = $t.kb.Contains('"KEYBINDS"') -and $t.kb.Contains('EngFuncs::KEY_SetBinding( key, bindName );') -and $t.kb.Contains('pPadSecondary = AddButton(')
        'pad keys off Keybinds'      = $t.model.Contains('UI_CoFIsPadKey( i )')
        'tab strip and frame'        = $t.fw.Contains('void CMenuFramework::GoToTab( int index )') -and $t.fw.Contains('void CMenuFramework::DrawPadHints( void )') -and
                                       $t.fw.Contains('FocusFirstItem();') -and $t.fwh.Contains('CMenuBaseItem *pPadSecondary;')
        'greyed skipped'             = $t.holder.Contains('( UI_ThemeActive() && ( item->iFlags & QMF_GRAYED ))')
        'slider focus label'         = $t.slider.Contains('hot ? THEME_TEXT_HI : THEME_TEXT_DIM')
        'triggers page lists'        = $t.table.Contains('key == K_JOY1') -and $t.table.Contains('key == K_JOY2')
        'input hooks'                = $t.base.Contains('if( UI_CoFInputEvent( key, down ))') -and $t.base.Contains('UI_CoFInputMouse();')
        'Extras tabbed window'       = $t.main.Contains('UI_CoFHost_Menu();')
        'new pages and hooks'        = $t.cpp.Contains('ADD_COMMAND( menu_cof_options_select, UI_CoFOptionsSelect );') -and
                                       $t.cpp.Contains('ADD_COMMAND( menu_cof_key, UI_CoFKey );') -and
                                       $t.cpp.Contains('ADD_MENU( menu_cofcontrols, CMenuCoFControls, UI_CoFControls_Menu );') -and
                                       $t.cpp.Contains('ADD_MENU4( menu_cofgamepad,') -and $t.cpp.Contains('"cof_pad_style"') -and
                                       $t.cpp.Contains('"joy_gyro_enable"') -and $t.h.Contains('bool UI_CoFOptionsLayout( void );')
    }
    foreach ($k in $checks.Keys) {
        if (-not $checks[$k]) { throw "Applied, but the marker for '$k' is missing. Inspect the tree." }
    }

    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Applied options-layout patch cannot be reverse-checked.' }
} finally {
    Pop-Location
}
Write-Host "Applied patches\cof-mainui-options-layout.patch in $source"
Write-Host 'Build: python waf build --targets=menu (ship gamedata\cryoffear\gfx\shell\gamepad with it)'
