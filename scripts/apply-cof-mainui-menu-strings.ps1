param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)

# The menu's own strings from the active language pack (MainUI): the table
# <gamedir>/languages/<cof_language>/strings/menu-strings.tsv (English as the
# menu draws it <TAB> translation, UTF-8), applied where text is drawn and
# measured (UI_DrawString, CFontManager::GetTextWide / GetTextHeightExt),
# reloaded when cof_language changes, with the open pages laid out again;
# editable fields are held out. Adds the console command
# "menu_cof_strings [reload | <text>]". Code in MenuStrings.cpp next to L();
# declarations in Utils.h; hooks in BaseMenu.cpp, font/FontManager.cpp,
# controls/Field.cpp and Theme.cpp (the letter-spaced wordmark / GAME OVER,
# which also learns to decode UTF-8); the menu fonts also get the Latin-1
# punctuation U+00A1-00BF (Spanish inverted marks). See
# docs/cof-language-packs.md section 8.
#
# Applies on top of the pinned MainUI baseline plus the MainUI patches up to
# patches/cof-mainui-source-theme.patch (whose BaseMenu.cpp and FontManager.cpp
# it sits next to); README order: after cof-mainui-language-selector.patch.
# The two are independent (different files), and the selector's "%s
# (subtitles)" / "not installed" rows are keys of the same table.

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

$mainui = Join-Path $source '3rdparty\mainui'
$files = [ordered]@{
    strings = Join-Path $mainui 'MenuStrings.cpp'
    utils   = Join-Path $mainui 'Utils.h'
    base    = Join-Path $mainui 'BaseMenu.cpp'
    font    = Join-Path $mainui 'font\FontManager.cpp'
    field   = Join-Path $mainui 'controls\Field.cpp'
    theme   = Join-Path $mainui 'Theme.cpp'
}
foreach ($path in @($mainui) + @($files.Values)) {
    if (!(Test-Path -LiteralPath $path)) { throw "Missing mainui source path (apply the earlier MainUI patches first): $path" }
}

$head = (& git -C $mainui rev-parse HEAD 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or $head -ne '61263995592e93a278d764807243d043d3b97c54') {
    throw "mainui must be at pinned baseline 61263995592e93a278d764807243d043d3b97c54; found $head"
}

$patch = Join-Path $projectRoot 'patches\cof-mainui-menu-strings.patch'
if (!(Test-Path -LiteralPath $patch -PathType Leaf)) { throw "Missing patch: $patch" }

function Read-All { $t = @{}; foreach ($k in $files.Keys) { $t[$k] = Get-Content -Raw -LiteralPath $files[$k] }; return $t }
$before = Read-All
$present = $before.strings.Contains('UI_LangText') -or $before.base.Contains('UI_LangText') -or $before.utils.Contains('UI_LangText')

if ($Reverse) {
    if (-not $present) { throw 'The menu string table is not present in this source tree; nothing to reverse.' }
} else {
    if ($present) { throw 'The menu string table is already present; use -Reverse first or provide a clean tree.' }
    # the theme patch it sits next to (deferred defaults in UI_UpdateMenu)
    if (-not $before.base.Contains('UI_ThemeApplyDeferredDefaults();') -or
        -not $before.theme.Contains('int UI_ThemeDrawTracked( int font, int x, int y, const char *str,')) {
        throw 'Prerequisite missing: apply patches/cof-mainui-source-theme.patch first.'
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

$after = Read-All
if ($Reverse) {
    foreach ($k in $files.Keys) {
        if ($after[$k].Contains('UI_LangText') -or $after[$k].Contains('UI_LangFrame') -or $after[$k].Contains('CUILangHold') -or $after[$k].Contains('menu-strings.tsv')) {
            throw "Reversed, but menu-string markers remain in $($files[$k]). Inspect the tree."
        }
    }
    if (-not $after.base.Contains('UI_ThemeApplyDeferredDefaults();') -or
        -not $after.theme.Contains('x += g_FontMgr->DrawCharacter( font, (unsigned char)*p, Point( x, y ), charH, color );') -or
        -not $after.font.Contains('{ 0x00C0, 0x00FF, NULL, 0 }')) {
        throw 'Reverse application damaged the theme patch in BaseMenu.cpp or Theme.cpp.'
    }
    Write-Host "Reversed patches\cof-mainui-menu-strings.patch in $mainui"
} else {
    $fontHooks = ([regex]::Matches($after.font, [regex]::Escape('text = UI_LangText( text );'))).Count
    $themeHooks = ([regex]::Matches($after.theme, [regex]::Escape('str = UI_LangText( str );'))).Count
    $ok = $after.strings.Contains('const char *UI_LangText( const char *text )') -and
          $after.strings.Contains('languages/%s/strings/menu-strings.tsv') -and
          $after.strings.Contains('bool UI_LangFrame( void )') -and
          $after.strings.Contains('ADD_COMMAND( menu_cof_strings, UI_LangStrings_f );') -and
          $after.utils.Contains('const char *UI_LangText( const char *text );') -and
          $after.utils.Contains('class CUILangHold') -and
          $after.base.Contains('string = UI_LangText( string );') -and
          $after.base.Contains('if( UI_LangFrame( ))') -and
          ($fontHooks -eq 2) -and
          $after.field.Contains('CUILangHold langHold;') -and
          ($themeHooks -eq 2) -and $after.theme.Contains('#include "utflib.h"') -and
          $after.font.Contains('{ 0x00A1, 0x00FF, NULL, 0 }')
    if (-not $ok) { throw 'Applied, but the expected markers are missing. Inspect the tree.' }
    Write-Host "Applied patches\cof-mainui-menu-strings.patch in $mainui"
    Write-Host 'Build the menu: python waf build --targets=menu'
}
