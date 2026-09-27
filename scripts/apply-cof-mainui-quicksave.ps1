param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)

# Cry of Fear quick save and quick load, the menu half
# (patches/cof-mainui-quicksave.patch, MainUI only).
# See docs/patches/cof-quicksave.md.
#
#   * menus/LoadGame.cpp: the quick save's row at the top of the Load list
#     while cof_quick_saves is on and SAVE/cofquick.sav exists ("Quick" in the
#     Slot column, "Quick save (<map>)" in the Save column, the date in the
#     Date column, from cryoffear/SAVE/saveinfoquick.cof); never in the Save
#     tab; the menu registers cof_quick_saves too.
#   * menus/Main.cpp: "Quick save" as the FIRST pause-menu item (single
#     player, option on): cof_quicksave, then back to the game.
#   * menus/AdvancedControls.cpp: the Game tab checkbox "Quick saves"
#     (cof_quick_saves, written at once), the free right-hand slot of the
#     fourth checkbox row; menu_cof_options_select game quicksaves 0|1.
#   * model/KbActListModel.h: Keybinds rows "Quick save" / "Quick load"
#     (cof_quicksave / cof_quickload) under "Pause game", added in code - the
#     game's kb_act.lst is not shipped modified.
#   * Theme.cpp: deferred-defaults generation 5 binds F9 = cof_quickload when
#     F9 is free and F5 = cof_quicksave when F5 is free or still holds the
#     game's shipped "snapshot" (moved to F12 when F12 is free); a key bound
#     to anything else is left alone.
#
# Goes on after cof-mainui-osk (step 49; needs the options layout, step 48,
# and the m5b pause list and generation 4 of the theme).

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
    load  = $mu + 'menus\LoadGame.cpp'
    main  = $mu + 'menus\Main.cpp'
    adv   = $mu + 'menus\AdvancedControls.cpp'
    kbact = $mu + 'model\KbActListModel.h'
    theme = $mu + 'Theme.cpp'
}
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
$patch = Join-Path $root 'patches\cof-mainui-quicksave.patch'
if (!(Test-Path -LiteralPath $patch -PathType Leaf)) { throw "Missing patch: $patch" }

function ReadAll {
    $t = @{}
    foreach ($k in @($rel.Keys)) { $t[$k] = Get-Content -Raw -LiteralPath (Join-Path $source ([string]$rel[$k])) }
    return $t
}

$t = ReadAll
$present = $t.load.Contains('UI_CoFQuickSavesEnabled') -or $t.main.Contains('cofQuickSave') -or $t.adv.Contains('quickSaves') -or
           $t.kbact.Contains('"cof_quickload"') -or $t.theme.Contains('#define COF_SCENE_DEFAULTS_GEN	5')

if ($Reverse) {
    if (-not $present) { throw 'The quick save menu patch is not present in this source tree; nothing to reverse.' }
} else {
    if ($present) { throw 'The quick save menu patch is already present; use -Reverse first or provide a clean tree.' }
    if (-not $t.adv.Contains('CMenuCheckBox *boxes[] = { &crosshair, &lookSpring, &conEnable, &menuSaves, &notifyLines, &panelPause, &panelTransparent };') -or
        -not $t.kbact.Contains('AddAfter( "+duck", "cof_duck_toggle", L( "Crouch (toggle)" ));')) {
        throw 'Prerequisite missing: apply patches/cof-mainui-options-layout.patch first.'
    }
    if (-not $t.main.Contains('CMenuPicButton	cofSaveGame;') -or -not $t.theme.Contains('#define COF_SCENE_DEFAULTS_GEN	4') -or
        -not $t.load.Contains('static bool UI_CoFMenuSavesEnabled()')) {
        throw 'Prerequisite missing: apply the menu save and theme patches (cof-mainui-menu-save, cof-mainui-source-theme) first.'
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
        if ($t.load.Contains('UI_CoFQuickSavesEnabled') -or $t.main.Contains('cofQuickSave') -or $t.adv.Contains('quickSaves') -or
            $t.kbact.Contains('"cof_quickload"') -or -not $t.theme.Contains('#define COF_SCENE_DEFAULTS_GEN	4')) {
            throw 'Reversed, but quick save menu markers remain. Inspect the tree.'
        }
        Write-Host "Reversed patches\cof-mainui-quicksave.patch in $source"
        return
    }

    $checks = [ordered]@{
        'Load list quick row'   = $t.load.Contains('static bool UI_CoFQuickSavesEnabled()') -and $t.load.Contains('"SAVE/saveinfoquick.cof"') -and
                                  $t.load.Contains('if( !parent->IsSaveMode() && UI_CoFQuickSavesEnabled() &&') -and
                                  $t.load.Contains('EngFuncs::CvarRegister( "cof_quick_saves", "0", FCVAR_ARCHIVE );')
        'pause list item'       = $t.main.Contains('CMenuPicButton	cofQuickSave;') -and $t.main.Contains('EngFuncs::ClientCmd( false, "cof_quicksave\n" );') -and
                                  $t.main.Contains('AddItem( cofQuickSave );') -and $t.main.Contains('&cofQuickSave, &resumeGame,')
        'Game tab checkbox'     = $t.adv.Contains('CMenuCheckBox	quickSaves;') -and $t.adv.Contains('quickSaves.LinkCvar( "cof_quick_saves" );') -and
                                  $t.adv.Contains('&panelTransparent, &quickSaves };') -and $t.adv.Contains('{ "quicksaves", &quickSaves, "cof_quick_saves" },')
        'Keybinds rows'         = $t.kbact.Contains('AddAfter( "pause", "cof_quicksave", L( "Quick save" ));') -and
                                  $t.kbact.Contains('AddAfter( "cof_quicksave", "cof_quickload", L( "Quick load" ));')
        'default binds gen 5'   = $t.theme.Contains('#define COF_SCENE_DEFAULTS_GEN	5') -and $t.theme.Contains('if( generation < 5 )') -and
                                  $t.theme.Contains('bind F5 \"cof_quicksave\"')
    }
    foreach ($k in $checks.Keys) {
        if (-not $checks[$k]) { throw "Applied, but the marker for '$k' is missing. Inspect the tree." }
    }

    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Applied quick save menu patch cannot be reverse-checked.' }
} finally {
    Pop-Location
}
Write-Host "Applied patches\cof-mainui-quicksave.patch in $source"
Write-Host 'Build: python waf build --targets=menu'
