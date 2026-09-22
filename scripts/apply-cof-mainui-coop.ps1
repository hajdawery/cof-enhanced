param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)

# Cry of Fear co-op bridge, menu half (patches/cof-mainui-coop.patch):
#
#   * menus/CoFCoop.cpp (new): the Host co-op page (campaign list, difficulty,
#     players, lobby autostart = mp_footsteps, auto respawn, server name,
#     password, LAN only, player name) whose Start issues the measured
#     multiplayer sequence with NO disconnect, and the Join co-op page
#     (address, player name, the stock LAN list) whose Connect issues
#     name + connect; archived cof_coop_* cvars; cfg-only test hooks
#     menu_cof_host_start and menu_cof_join_connect (no input may be injected);
#   * menus/Main.cpp: Extras > Join Server / Host Server open those pages;
#     the pause list in a multiplayer session has no Save Game / Load Game
#     and its Quit to menu reads Disconnect; Think drops a pending
#     background-map re-arm once the engine has put the scene back itself;
#   * menus/CryOfFear.h: the two page entry points.
#
# Applies on top of the pinned MainUI baseline plus the MainUI stack up to and
# including patches/cof-mainui-source-theme.patch (milestone 5b: the separate
# pause-list Save Game item). It touches no file of
# patches/cof-mainui-language-selector.patch (AdvancedControls.cpp only), so
# the two go on in either order. The engine half is
# patches/cof-coop-bridge.patch. See docs/cof-coop-bridge.md.

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

$mainui   = Join-Path $source '3rdparty\mainui'
$mainFile = Join-Path $mainui 'menus\Main.cpp'
$hdrFile  = Join-Path $mainui 'menus\CryOfFear.h'
$newFile  = Join-Path $mainui 'menus\CoFCoop.cpp'
foreach ($path in @($mainui, $mainFile, $hdrFile, (Join-Path $mainui 'menus\CryOfFear.cpp'))) {
    if (!(Test-Path -LiteralPath $path)) { throw "Missing mainui source path (apply the earlier MainUI patches first): $path" }
}

$head = (& git -C $mainui rev-parse HEAD 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or $head -ne '61263995592e93a278d764807243d043d3b97c54') {
    throw "mainui must be at pinned baseline 61263995592e93a278d764807243d043d3b97c54; found $head"
}

$patch = Join-Path $projectRoot 'patches\cof-mainui-coop.patch'
if (!(Test-Path -LiteralPath $patch -PathType Leaf)) { throw "Missing patch: $patch" }

$mainText = Get-Content -Raw -LiteralPath $mainFile
$hdrText  = Get-Content -Raw -LiteralPath $hdrFile
$present = (Test-Path -LiteralPath $newFile) -or $mainText.Contains('CoFInMultiplayer') -or $hdrText.Contains('UI_CoFHost_Menu')

if ($Reverse) {
    if (-not $present) { throw 'The co-op pages are not present in this source tree; nothing to reverse.' }
} else {
    if ($present) { throw 'The co-op pages are already present; use -Reverse first or provide a clean tree.' }
    # the pause list this changes: milestone 5b's separate Save Game item
    if (-not $mainText.Contains('cofSaveGame.SetVisibility( connected && CoFPauseSavesEnabled( ));') -or
        -not $mainText.Contains('cofHostServer.onReleased = UI_CreateGame_Menu;') -or
        -not $hdrText.Contains('void UI_CoFDeath_Menu( void );')) {
        throw 'Prerequisite missing: apply patches/cof-mainui-source-theme.patch (milestone 5b pause list) first.'
    }
}

Push-Location $projectRoot
try {
    $relativeSource = $source.Substring($projectPrefix.Length).Replace('\','/')
    $extra = @()
    if ($Reverse) { $extra += '--reverse' }
    & git apply --ignore-whitespace --check --directory=$relativeSource @extra -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Patch does not apply cleanly to this source tree.' }
    & git apply --ignore-whitespace --directory=$relativeSource @extra -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'git apply failed.' }
} finally {
    Pop-Location
}

$mainAfter = Get-Content -Raw -LiteralPath $mainFile
$hdrAfter  = Get-Content -Raw -LiteralPath $hdrFile
if ($Reverse) {
    if ((Test-Path -LiteralPath $newFile) -or $mainAfter.Contains('CoFInMultiplayer') -or
        $mainAfter.Contains('UI_CoFHost_Menu') -or $hdrAfter.Contains('UI_CoFJoin_Menu')) {
        throw 'Reversed, but co-op page markers remain. Inspect the tree.'
    }
    if (-not $mainAfter.Contains('cofSaveGame.SetVisibility( connected && CoFPauseSavesEnabled( ));')) {
        throw 'Reverse application damaged the theme patch in menus/Main.cpp.'
    }
    Write-Host "Reversed patches\cof-mainui-coop.patch in $mainui"
} else {
    $coop = Get-Content -Raw -LiteralPath $newFile
    $ok = $coop.Contains('class CMenuCoFHost : public CMenuFramework') -and
          $coop.Contains('class CMenuCoFJoin : public CMenuFramework') -and
          $coop.Contains('"maxplayers %d\n"') -and $coop.Contains('"map %s\n"') -and
          -not $coop.Contains('"disconnect\n') -and
          $coop.Contains('ADD_COMMAND( menu_cof_host_start, UI_CoFHostStart_f );') -and
          $coop.Contains('ADD_COMMAND( menu_cof_join_connect, UI_CoFJoinConnect_f );') -and
          $mainAfter.Contains('cofJoinServer.onReleased = UI_CoFJoin_Menu;') -and
          $mainAfter.Contains('cofHostServer.onReleased = UI_CoFHost_Menu;') -and
          $mainAfter.Contains('cofSaveGame.SetVisibility( connected && !mp && CoFPauseSavesEnabled( ));') -and
          $mainAfter.Contains('if( bCoFWantBackgroundMap && EngFuncs::GetCvarFloat( "cl_background" ) != 0.0f )') -and
          $hdrAfter.Contains('void UI_CoFHost_Menu( void );')
    if (-not $ok) { throw 'Applied, but the expected markers are missing. Inspect the tree.' }
    Write-Host "Applied patches\cof-mainui-coop.patch in $mainui"
    Write-Host 'Build the menu: python waf build --targets=menu'
}
