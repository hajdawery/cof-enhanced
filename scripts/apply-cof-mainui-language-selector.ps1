param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)

# The "Language" selector on the Game options page (menus/AdvancedControls.cpp),
# the ONE language option for Cry of Fear: a spin control listing "English",
# then every language pack installed under <gamedir>/languages/<code>/ with a
# manifest.txt, named by its display_name and sorted by it (the Polish pack and
# the six minimal packs dutch ... swedish that pick the game's own subtitle
# languages); an old configuration's client slot without a pack shows as its
# own "<name> (subtitles)" row. A row sets both the engine's archived
# cof_language (patches/cof-language-packs.patch) and the client's own subtitle
# slot cof_subtitlelanguage (1 English, 2..7 the game's folders; a pack names
# its slot with subtitle_language= in manifest.txt, default 1), then
# host_writeconfig. The client's old "Subtitle language" row is no longer
# added. A note under the rows says cached art needs a restart. It also adds
# the cfg-only test hook "menu_cof_language_select [row|code|english]", which
# moves the spinner exactly the way an arrow click does (tests in this project
# may not inject input). Round 2 (lang2, 2026-09-22) of this patch.
#
# Applies on top of the pinned MainUI baseline plus all four earlier MainUI
# patches, the last of them patches/cof-mainui-source-theme.patch (the Game
# page with the "Aim down sights" row this one sits next to). The engine half
# is patches/cof-language-packs.patch; without it the row lists the packs but
# selecting one does nothing (the cvar does not exist). See
# docs/cof-language-packs.md section 7.

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

$mainui  = Join-Path $source '3rdparty\mainui'
$advFile = Join-Path $mainui 'menus\AdvancedControls.cpp'
foreach ($path in @($mainui, $advFile, (Join-Path $mainui 'Theme.cpp'))) {
    if (!(Test-Path -LiteralPath $path)) { throw "Missing mainui source path (apply the four earlier MainUI patches first): $path" }
}

$head = (& git -C $mainui rev-parse HEAD 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or $head -ne '61263995592e93a278d764807243d043d3b97c54') {
    throw "mainui must be at pinned baseline 61263995592e93a278d764807243d043d3b97c54; found $head"
}

$patch = Join-Path $projectRoot 'patches\cof-mainui-language-selector.patch'
if (!(Test-Path -LiteralPath $patch -PathType Leaf)) { throw "Missing patch: $patch" }

$advText = Get-Content -Raw -LiteralPath $advFile
$present = $advText.Contains('CMenuCoFLangPackModel') -or $advText.Contains('menu_cof_language_select')

if ($Reverse) {
    if (-not $present) { throw 'The language selector is not present in this source tree; nothing to reverse.' }
} else {
    if ($present) { throw 'The language selector is already present; use -Reverse first or provide a clean tree.' }
    # the row it joins: the Game page as the theme patch leaves it (milestone 5b)
    if (-not $advText.Contains('adsMode.SetRect( left.pt.x, y, left.sz.w, THEME_CTRL_H );') -or
        -not $advText.Contains('conEnable.LinkCvar( "con_enable" );')) {
        throw 'Prerequisite missing: apply patches/cof-mainui-source-theme.patch (milestone 5b, the "Aim down sights" row) first.'
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

$advAfter = Get-Content -Raw -LiteralPath $advFile
if ($Reverse) {
    if ($advAfter.Contains('CMenuCoFLangPackModel') -or $advAfter.Contains('menu_cof_language_select') -or
        $advAfter.Contains('"cof_language"') -or $advAfter.Contains('subtitle_language=')) {
        throw 'Reversed, but language-selector markers remain. Inspect the tree.'
    }
    if (-not $advAfter.Contains('adsMode.SetRect( left.pt.x, y, left.sz.w, THEME_CTRL_H );') -or
        -not $advAfter.Contains('AddItem( language );')) {
        throw 'Reverse application damaged the theme patch in menus/AdvancedControls.cpp.'
    }
    Write-Host "Reversed patches\cof-mainui-language-selector.patch in $mainui"
} else {
    $ok = $advAfter.Contains('class CMenuCoFLangPackModel') -and
          $advAfter.Contains('EngFuncs::GetFilesList( "languages/*", &numFiles, 1 )') -and
          $advAfter.Contains('EngFuncs::CvarSetString( "cof_language", code );') -and
          $advAfter.Contains('host_writeconfig') -and
          $advAfter.Contains('langPack.SetRect( left.pt.x, y, left.sz.w, THEME_CTRL_H );') -and
          $advAfter.Contains('subtitle_language=') -and
          $advAfter.Contains('UI_CoFSetSubtitleLanguage( subtitle );') -and
          -not $advAfter.Contains('AddItem( language );') -and
          $advAfter.Contains('stricmp( m_rows[j].name, t.name ) > 0') -and
          $advAfter.Contains('langNote.szName = L(') -and
          $advAfter.Contains('ADD_COMMAND( menu_cof_language_select, UI_CoFLanguageSelect );')
    if (-not $ok) { throw 'Applied, but the expected markers are missing. Inspect the tree.' }
    Write-Host "Applied patches\cof-mainui-language-selector.patch in $mainui"
    Write-Host 'Build the menu: python waf build --targets=menu'
}
