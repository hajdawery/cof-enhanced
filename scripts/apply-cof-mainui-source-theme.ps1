param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)

# UI milestone 3a: the Source-style theme and dialogs in MainUI.
#
# Applies on top of, and only on top of, the pinned MainUI baseline plus the
# three earlier MainUI patches:
#
#   patches/cof-mainui-menu-save.patch        (menus/LoadGame.cpp, menus/SaveLoad.cpp)
#   patches/cof-mainui-background-scrim.patch (BaseMenu.cpp, BaseMenu.h, controls/BackgroundBitmap.cpp)
#   patches/cof-mainui-cof-menu.patch         (menus/CryOfFear.cpp/.h, menus/Main.cpp, ...)
#
# so apply those first. This patch adds Theme.cpp and Theme.h, the panel mode
# and close button in CMenuFramework, primitive-drawn checkbox / slider /
# spinner / table / drop-down art, the Inter font path through stb_truetype
# with a GDI fallback chain, and the per-dialog layouts.
#
# Two later additions live in the same patch: the Cry of Fear death page
# (menus/CryOfFear.cpp, command "menu_cofdeath", opened by the engine's
# cof_ui_death_menu hook) and the "Enable console" checkbox on the Game page
# (menus/AdvancedControls.cpp), which binds the engine cvar con_enable that
# patches/cof-ui-death-flow.patch adds.
#
# It also carries one functional fix that is not styling: the menu now issues
# the client's own "stopmp3" console command before a Cry of Fear save load and
# before a new game, which the original client panels did and the engine menu
# did not - without it the background map's music plays on into the loaded map.

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!(Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "SourceRoot must be an existing directory: $SourceRoot"
}
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
$projectPrefix = $projectRoot.TrimEnd('\') + '\'
if (-not $source.StartsWith($projectPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}

$mainui     = Join-Path $source '3rdparty\mainui'
$baseHeader = Join-Path $mainui 'BaseMenu.h'
$baseSource = Join-Path $mainui 'BaseMenu.cpp'
$mainFile   = Join-Path $mainui 'menus\Main.cpp'
$loadFile   = Join-Path $mainui 'menus\LoadGame.cpp'
$scrimFile  = Join-Path $mainui 'controls\BackgroundBitmap.cpp'
$cofFile    = Join-Path $mainui 'menus\CryOfFear.cpp'
$fwFile     = Join-Path $mainui 'controls\Framework.cpp'
$fontFile   = Join-Path $mainui 'font\FontManager.cpp'
$newSource  = Join-Path $mainui 'Theme.cpp'
$newHeader  = Join-Path $mainui 'Theme.h'
foreach($path in @($mainui, $baseHeader, $baseSource, $mainFile, $loadFile, $scrimFile, $cofFile, $fwFile, $fontFile)) {
    if (!(Test-Path -LiteralPath $path)) { throw "Missing mainui source path: $path" }
}

$head = (& git -C $mainui rev-parse HEAD 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or $head -ne '61263995592e93a278d764807243d043d3b97c54') {
    throw "mainui must be at pinned baseline 61263995592e93a278d764807243d043d3b97c54; found $head"
}

# Prerequisites: all three earlier MainUI patches have to be in place already.
$scrimText = Get-Content -Raw -LiteralPath $scrimFile
$loadText  = Get-Content -Raw -LiteralPath $loadFile
$mainText  = Get-Content -Raw -LiteralPath $mainFile
if (-not $scrimText.Contains('ui_scrim_alpha')) {
    throw 'Prerequisite missing: apply patches/cof-mainui-background-scrim.patch first.'
}
if (-not $loadText.Contains('UI_IsCoFRootSaveGame')) {
    throw 'Prerequisite missing: apply patches/cof-mainui-menu-save.patch first.'
}
if (-not $mainText.Contains('UI_IsCryOfFear') -or !(Test-Path -LiteralPath $cofFile)) {
    throw 'Prerequisite missing: apply patches/cof-mainui-cof-menu.patch first.'
}

$patch = Join-Path $projectRoot 'patches\cof-mainui-source-theme.patch'
if (!(Test-Path -LiteralPath $patch -PathType Leaf)) { throw "Missing patch: $patch" }

$fwText   = Get-Content -Raw -LiteralPath $fwFile
$fontText = Get-Content -Raw -LiteralPath $fontFile
$cofText  = Get-Content -Raw -LiteralPath $cofFile
$advFile  = Join-Path $mainui 'menus\AdvancedControls.cpp'
$advText  = Get-Content -Raw -LiteralPath $advFile

$markersPresent = (Test-Path -LiteralPath $newSource) -or
                  (Test-Path -LiteralPath $newHeader) -or
                  $fwText.Contains('DrawPanelChrome') -or
                  $fontText.Contains('UI_ThemeFontFallback') -or
                  $cofText.Contains('CMenuCoFDeath') -or
                  $advText.Contains('conEnable')

if ($Reverse) {
    if (-not $markersPresent) {
        throw 'MainUI Source-theme markers are absent; refusing reverse application.'
    }
} else {
    if ($markersPresent) {
        throw 'MainUI Source-theme changes are already present; use -Reverse first or provide a clean baseline.'
    }
}

Push-Location $projectRoot
try {
    $relativeSource = $source.Substring($projectPrefix.Length).Replace('\','/')
    if ($Reverse) {
        & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
        if ($LASTEXITCODE -ne 0) { throw 'Reverse check failed.' }
        & git apply --ignore-whitespace --reverse --directory=$relativeSource -- $patch
        if ($LASTEXITCODE -ne 0) { throw 'Reverse application failed.' }
    } else {
        & git apply --ignore-whitespace --check --directory=$relativeSource -- $patch
        if ($LASTEXITCODE -ne 0) { throw 'Forward check failed.' }
        & git apply --ignore-whitespace --directory=$relativeSource -- $patch
        if ($LASTEXITCODE -ne 0) { throw 'Forward application failed.' }
    }
} finally {
    Pop-Location
}

$fwAfter   = Get-Content -Raw -LiteralPath $fwFile
$fontAfter = Get-Content -Raw -LiteralPath $fontFile
$mainAfter = Get-Content -Raw -LiteralPath $mainFile
$loadAfter = Get-Content -Raw -LiteralPath $loadFile
$cofAfter  = Get-Content -Raw -LiteralPath $cofFile
$advAfter  = Get-Content -Raw -LiteralPath $advFile
if ($Reverse) {
    if ((Test-Path -LiteralPath $newSource) -or (Test-Path -LiteralPath $newHeader) -or
        $fwAfter.Contains('DrawPanelChrome') -or $fontAfter.Contains('UI_ThemeFontFallback') -or
        $cofAfter.Contains('CMenuCoFDeath') -or $advAfter.Contains('conEnable')) {
        throw 'Reverse application completed without removing all MainUI Source-theme markers.'
    }
    if (-not $mainAfter.Contains('UI_IsCryOfFear')) {
        throw 'Reverse application damaged the CoF-menu patch in menus/Main.cpp.'
    }
    if (-not $loadAfter.Contains('UI_IsCoFRootSaveGame')) {
        throw 'Reverse application damaged the menu-save patch in menus/LoadGame.cpp.'
    }
    Write-Host "Reversed CoF MainUI Source theme in $mainui"
} else {
    if (!(Test-Path -LiteralPath $newSource) -or !(Test-Path -LiteralPath $newHeader) -or
        -not $fwAfter.Contains('DrawPanelChrome') -or -not $fontAfter.Contains('UI_ThemeFontFallback') -or
        -not $cofAfter.Contains('ADD_MENU( menu_cofdeath, CMenuCoFDeath, UI_CoFDeath_Menu );') -or
        -not $advAfter.Contains('conEnable.LinkCvar( "con_enable" );')) {
        throw 'Forward application completed without the expected MainUI Source-theme markers.'
    }
    Write-Host "Applied CoF MainUI Source theme in $mainui"
}
