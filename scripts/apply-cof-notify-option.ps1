param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)

# "Show console notifications" (patches/cof-notify-option.patch, engine + MainUI):
#
#   * engine/client/console.c: the archived cvar cof_notify (default 1). With
#     0, Con_DrawNotify draws no notify lines - the newest console lines the
#     engine otherwise prints over the top-left corner during play. The
#     console itself, the chat input line and the developer overlays are
#     unaffected.
#   * 3rdparty/mainui/menus/AdvancedControls.cpp: a "Show console
#     notifications" checkbox on the Game page (Cry of Fear with the theme),
#     linked to cof_notify and written at once; the page grows by one checkbox
#     row. Its two strings go through L() and the menu-string layer, so every
#     pack's strings/menu-strings.tsv translates them.
#
# Goes on after patches/cof-mainui-language-selector.patch (the Game page it
# extends) and patches/cof-mainui-coop.patch, and BEFORE apply-cof-cheats.ps1
# (which touches neither file). See docs/design/ui-theme.md (Game page).

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
$consoleRel = 'engine\client\console.c'
$pageRel    = '3rdparty\mainui\menus\AdvancedControls.cpp'
foreach ($relative in @($consoleRel, $pageRel)) {
    if (!(Test-Path -LiteralPath (Join-Path $source $relative))) {
        throw "Not an FWGS source tree with mainui checked out: $(Join-Path $source $relative)"
    }
}
$mainui = Join-Path $source '3rdparty\mainui'
$head = (& git -C $mainui rev-parse HEAD 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or $head -ne '61263995592e93a278d764807243d043d3b97c54') {
    throw "mainui must be at pinned baseline 61263995592e93a278d764807243d043d3b97c54; found $head"
}
$patch = Join-Path $root 'patches\cof-notify-option.patch'
if (!(Test-Path -LiteralPath $patch -PathType Leaf)) { throw "Missing patch: $patch" }

function Slurp([string] $rel) { Get-Content -Raw -LiteralPath (Join-Path $source $rel) }

$console = Slurp $consoleRel
$page    = Slurp $pageRel
$present = $console.Contains('cof_notify') -or $page.Contains('notifyLines')

if ($Reverse) {
    if (-not $present) { throw 'The notifications option is not present in this source tree; nothing to reverse.' }
} else {
    if ($present) { throw 'The notifications option is already present; use -Reverse first or provide a clean tree.' }
    # the Game page as the theme and the language selector left it
    if (-not $page.Contains('CMenuSpinControl	langPack;') -or -not $page.Contains('extra[n++] = &menuSaves;') -or
        -not $page.Contains('menuSaves.LinkCvar( "cof_pause_menu_saves" );')) {
        throw 'Prerequisite missing: apply patches/cof-mainui-source-theme.patch and patches/cof-mainui-language-selector.patch first.'
    }
    # the stock notify loop and the console's cvar block
    if (-not $console.Contains('static CVAR_DEFINE_AUTO( con_notifytime, "3", FCVAR_ARCHIVE, "notify time to live" );') -or
        -not $console.Contains('if( host.allow_console && !Con_BackgroundMapActive( ))')) {
        throw 'engine\client\console.c does not carry the stock notify lines this patch extends.'
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

    $console = Slurp $consoleRel
    $page    = Slurp $pageRel

    if ($Reverse) {
        if ($console.Contains('cof_notify') -or $page.Contains('notifyLines')) {
            throw 'Reversed, but notifications-option markers remain. Inspect the tree.'
        }
        if (-not $page.Contains('CMenuSpinControl	langPack;')) { throw 'Reverse application damaged the Game page patches this one sits on.' }
        Write-Host "Reversed patches\cof-notify-option.patch in $source"
        return
    }

    $ok = $console.Contains('static CVAR_DEFINE_AUTO( cof_notify, "1", FCVAR_ARCHIVE,') -and
          $console.Contains('Cvar_RegisterVariable( &cof_notify );') -and
          $console.Contains('if( host.allow_console && !Con_BackgroundMapActive( ) && cof_notify.value != 0.0f )')
    if (-not $ok) { throw 'Applied, but the engine cof_notify markers are missing. Inspect the tree.' }

    $ok = $page.Contains('notifyLines.LinkCvar( "cof_notify" );') -and
          $page.Contains('L( "Show console notifications" )') -and
          $page.Contains('extra[n++] = &notifyLines;') -and
          $page.Contains('AddItem( notifyLines );') -and
          $page.Contains('SetPanel( "GAME", 760, m_bCoF ? 580 + THEME_ROW_PITCH : 520 );')
    if (-not $ok) { throw 'Applied, but the Game page checkbox markers are missing. Inspect the tree.' }

    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Applied notifications-option patch cannot be reverse-checked.' }
} finally {
    Pop-Location
}
Write-Host "Applied patches\cof-notify-option.patch in $source"
Write-Host 'Build: python waf build --targets=xash,menu'
