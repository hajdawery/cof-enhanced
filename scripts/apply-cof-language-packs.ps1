param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)

# Cry of Fear language packs (cof_language): pack discovery and mount, the
# CreateFileW import hook of client.dll / hl.dll, the engine-filesystem text
# redirect, the draw-time DLL string table (FreeVGUI TextImage::setText and
# the engine font path), the code page from the pack's manifest, per-map
# entity patches (maps/<map>.entpatch, engine/common/cof_entpatch.c) applied
# to the map's entity string at load, and studio-model texture overrides
# (models/<model>/<texture>.bmp) written into the loaded model before upload.
# See docs/cof-language-packs.md. Goes after the whole documented stack.

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!(Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "SourceRoot must be an existing directory: $SourceRoot"
}
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
$targets = @(
    'engine\common\common.c',
    'engine\common\filesystem_engine.c',
    'engine\common\host.c',
    'engine\common\mod_bmodel.c',
    'engine\common\mod_studio.c',
    'engine\platform\win32\lib_win.c',
    'engine\server\sv_game.c',
    'engine\client\cl_font.c',
    'engine\client\cl_main.c',
    'engine\client\dll_int\cl_game.c',
    'engine\client\vgui\vgui_draw.c',
    'engine\vgui_api.h',
    '3rdparty\freevgui\font.h',
    '3rdparty\freevgui\font.cpp',
    '3rdparty\freevgui\image.cpp',
    '3rdparty\freevgui\platform\xash3d-fwgs\coffont.cpp'
)
$patch = Join-Path $root 'patches\cof-language-packs.patch'

if (!(Test-Path -LiteralPath $patch)) { throw "Missing patch: $patch" }
foreach($relative in $targets) {
    if (!(Test-Path -LiteralPath (Join-Path $source $relative))) {
        throw "Not an FWGS source tree with freevgui checked out and the font patches applied: $(Join-Path $source $relative)"
    }
}
$rootPrefix = $root.TrimEnd('\') + '\'
if (-not $source.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}

function Read-Target([string] $relative) {
    $p = Join-Path $source $relative
    if (!(Test-Path -LiteralPath $p)) { return '' }
    Get-Content -Raw -LiteralPath $p
}

$lang = Join-Path $source 'engine\common\cof_language.c'
$entp = Join-Path $source 'engine\common\cof_entpatch.c'
$api  = Read-Target 'engine\vgui_api.h'
$main = Read-Target 'engine\client\cl_main.c'

if (-not $Reverse) {
    if ((Test-Path -LiteralPath $lang) -or (Test-Path -LiteralPath $entp) -or $api.Contains('CofLangString')) {
        throw 'The CoF language packs are already present; use a clean patched source tree.'
    }
    # the code page the manifest sets, and the font layer that decodes with it
    if (-not $main.Contains('cof_text_codepage')) {
        throw 'Apply scripts\apply-cof-vgui-inter-fonts.ps1 first: packs set its cof_text_codepage.'
    }
    # the vguiapi_t entry this appends after
    if (-not $api.Contains('(*CofPrint)')) {
        throw 'Apply scripts\apply-cof-hud-text-backing.ps1 first: this patch appends to its vguiapi_t.'
    }
} else {
    if (!(Test-Path -LiteralPath $lang)) {
        throw 'The CoF language packs are not present in this source tree; nothing to reverse.'
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

    if (-not $Reverse) {
        $langAfter = Read-Target 'engine\common\cof_language.c'
        $present =
            $langAfter.Contains('CoF_Lang_HookModule') -and
            $langAfter.Contains('CoF_Lang_CreateFileW') -and
            $langAfter.Contains('CoF_Lang_EarlyApply') -and
            (Read-Target 'engine\common\cof_language.h').Contains('FONT_DRAW_COF_LANG') -and
            (Read-Target 'engine\common\common.c').Contains('CoF_Lang_GameFile') -and
            (Read-Target 'engine\common\filesystem_engine.c').Contains('CoF_Lang_Remount') -and
            (Read-Target 'engine\common\host.c').Contains('CoF_Lang_EarlyApply') -and
            (Read-Target 'engine\common\mod_bmodel.c').Contains('CoF_Lang_TextureReplacement') -and
            (Read-Target 'engine\common\mod_bmodel.c').Contains('CoF_Lang_ApplyEntityPatch') -and
            (Read-Target 'engine\common\cof_entpatch.c').Contains('CoF_EntPatch_Apply') -and
            $langAfter.Contains('CoF_Lang_StudioTextures') -and
            (Read-Target 'engine\common\mod_studio.c').Contains('CoF_Lang_StudioTextures') -and
            (Read-Target 'engine\server\sv_game.c').Contains('CoF_Lang_ApplyEntityPatch') -and
            (Read-Target 'engine\platform\win32\lib_win.c').Contains('CoF_Lang_UnhookModule') -and
            (Read-Target 'engine\server\sv_game.c').Contains('CoF_Lang_HookModule') -and
            (Read-Target 'engine\client\cl_font.c').Contains('CoF_Lang_StringEngineFont') -and
            (Read-Target 'engine\client\dll_int\cl_game.c').Contains('FONT_DRAW_COF_LANG') -and
            (Read-Target 'engine\vgui_api.h').Contains('CofLangString') -and
            (Read-Target '3rdparty\freevgui\image.cpp').Contains('Text_Substitute') -and
            (Read-Target '3rdparty\freevgui\platform\xash3d-fwgs\coffont.cpp').Contains('CofLangSubstitute')
        if (-not $present) { throw 'Applied, but the expected markers are missing. Inspect the tree.' }
        Write-Host 'Applied patches\cof-language-packs.patch'
        Write-Host 'Build both libraries: python waf build --targets=xash,vgui'
        Write-Host 'Deploy a pack by copying languages\<code> into <game>\cryoffear\languages\<code>.'
    } else {
        if ((Test-Path -LiteralPath $lang) -or (Test-Path -LiteralPath $entp) -or
            (Read-Target 'engine\vgui_api.h').Contains('CofLangString') -or
            (Read-Target 'engine\common\mod_studio.c').Contains('CoF_Lang_StudioTextures') -or
            (Read-Target 'engine\common\mod_bmodel.c').Contains('CoF_Lang_ApplyEntityPatch')) {
            throw 'Reversed, but markers remain. Inspect the tree.'
        }
        Write-Host 'Reversed patches\cof-language-packs.patch'
    }
}
finally {
    Pop-Location
}
