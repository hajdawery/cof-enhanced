param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)

# UI milestone 2: the Cry of Fear main menu and its pages in MainUI.
#
# Applies on top of, and only on top of, the pinned MainUI baseline plus the
# two earlier MainUI patches:
#
#   patches/cof-mainui-menu-save.patch        (menus/LoadGame.cpp, menus/SaveLoad.cpp)
#   patches/cof-mainui-background-scrim.patch (BaseMenu.cpp, BaseMenu.h, controls/BackgroundBitmap.cpp)
#
# so apply those first. This patch adds menus/CryOfFear.cpp and
# menus/CryOfFear.h, replaces CMenuMain's item set for the cryoffear game
# directory, exports UI_StartBackGroundMap, and points the Cry of Fear save
# preview at the root SAVE folder.

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
$mainFile   = Join-Path $mainui 'menus\Main.cpp'
$loadFile   = Join-Path $mainui 'menus\LoadGame.cpp'
$scrimFile  = Join-Path $mainui 'controls\BackgroundBitmap.cpp'
$newSource  = Join-Path $mainui 'menus\CryOfFear.cpp'
$newHeader  = Join-Path $mainui 'menus\CryOfFear.h'
foreach($path in @($mainui, $baseHeader, $mainFile, $loadFile, $scrimFile)) {
    if (!(Test-Path -LiteralPath $path)) { throw "Missing mainui source path: $path" }
}

$head = (& git -C $mainui rev-parse HEAD 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or $head -ne '61263995592e93a278d764807243d043d3b97c54') {
    throw "mainui must be at pinned baseline 61263995592e93a278d764807243d043d3b97c54; found $head"
}

# Prerequisites: both earlier MainUI patches have to be in place already.
$scrimText = Get-Content -Raw -LiteralPath $scrimFile
$loadText  = Get-Content -Raw -LiteralPath $loadFile
if (-not $scrimText.Contains('ui_scrim_alpha')) {
    throw 'Prerequisite missing: apply patches/cof-mainui-background-scrim.patch first.'
}
if (-not $loadText.Contains('UI_IsCoFRootSaveGame')) {
    throw 'Prerequisite missing: apply patches/cof-mainui-menu-save.patch first.'
}

$headerText = Get-Content -Raw -LiteralPath $baseHeader
$mainText   = Get-Content -Raw -LiteralPath $mainFile
$patch = Join-Path $projectRoot 'patches\cof-mainui-cof-menu.patch'
if (!(Test-Path -LiteralPath $patch -PathType Leaf)) { throw "Missing patch: $patch" }

$markersPresent = $mainText.Contains('UI_IsCryOfFear') -or
                  $headerText.Contains('UI_StartBackGroundMap') -or
                  (Test-Path -LiteralPath $newSource) -or
                  (Test-Path -LiteralPath $newHeader)

if ($Reverse) {
    if (-not $markersPresent) {
        throw 'MainUI CoF-menu markers are absent; refusing reverse application.'
    }
} else {
    if ($markersPresent) {
        throw 'MainUI CoF-menu changes are already present; use -Reverse first or provide a clean baseline.'
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

$headerAfter = Get-Content -Raw -LiteralPath $baseHeader
$mainAfter   = Get-Content -Raw -LiteralPath $mainFile
$loadAfter   = Get-Content -Raw -LiteralPath $loadFile
if ($Reverse) {
    if ($mainAfter.Contains('UI_IsCryOfFear') -or $headerAfter.Contains('UI_StartBackGroundMap') -or
        (Test-Path -LiteralPath $newSource) -or (Test-Path -LiteralPath $newHeader)) {
        throw 'Reverse application completed without removing all MainUI CoF-menu markers.'
    }
    if (-not $loadAfter.Contains('UI_IsCoFRootSaveGame')) {
        throw 'Reverse application damaged the menu-save patch in menus/LoadGame.cpp.'
    }
    Write-Host "Reversed CoF MainUI menu change in $mainui"
} else {
    if (-not $mainAfter.Contains('UI_IsCryOfFear') -or -not $headerAfter.Contains('UI_StartBackGroundMap') -or
        !(Test-Path -LiteralPath $newSource) -or !(Test-Path -LiteralPath $newHeader)) {
        throw 'Forward application completed without the expected MainUI CoF-menu markers.'
    }
    Write-Host "Applied CoF MainUI menu change in $mainui"
}
