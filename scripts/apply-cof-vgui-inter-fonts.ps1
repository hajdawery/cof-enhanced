param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!(Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "SourceRoot must be an existing directory: $SourceRoot"
}
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
$targets = @(
    'engine\client\cl_main.c',
    'engine\client\client.h',
    'engine\client\dll_int\cl_game.c',
    'engine\client\vgui\vgui_draw.c',
    'engine\vgui_api.h',
    '3rdparty\freevgui\font.h',
    '3rdparty\freevgui\font.cpp',
    '3rdparty\freevgui\image.cpp',
    '3rdparty\freevgui\controls\text.cpp',
    '3rdparty\freevgui\controls\edit.cpp',
    '3rdparty\freevgui\platform\xash3d-fwgs\support.h',
    '3rdparty\freevgui\platform\xash3d-fwgs\surface.cpp',
    '3rdparty\freevgui\platform\xash3d-fwgs\app.cpp'
)
$patch = Join-Path $root 'patches\cof-vgui-inter-fonts.patch'

# stb_truetype.h is not carried in the patch: an identical copy is already in
# this source tree, vendored by the menu library. It is copied into the VGUI
# support library at apply time and verified by hash, which keeps 200 KB of
# third-party code out of the diff.
$stbFrom = Join-Path $source '3rdparty\mainui\font\stb_truetype.h'
$stbTo   = Join-Path $source '3rdparty\freevgui\platform\xash3d-fwgs\stb_truetype.h'
$stbHash = '45FB1C2A73AC8F33E0D98B488FCFB4FBD574D28D4D2F24E39A3FF59DB2F10EF1'

if (!(Test-Path -LiteralPath $patch)) { throw "Missing patch: $patch" }
foreach($relative in $targets) {
    if (!(Test-Path -LiteralPath (Join-Path $source $relative))) {
        throw "Not an FWGS source tree with freevgui checked out: $(Join-Path $source $relative)"
    }
}
$rootPrefix = $root.TrimEnd('\') + '\'
if (-not $source.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}

function Read-Target([string] $relative) {
    Get-Content -Raw -LiteralPath (Join-Path $source $relative)
}

$main    = Read-Target 'engine\client\cl_main.c'
$api     = Read-Target 'engine\vgui_api.h'
$fontH   = Read-Target '3rdparty\freevgui\font.h'
$coffont = Join-Path $source '3rdparty\freevgui\platform\xash3d-fwgs\coffont.cpp'

if (-not $Reverse) {
    if ($main.Contains('cof_ui_inter_fonts') -or $api.Contains('cof_vgui_font_t') -or (Test-Path -LiteralPath $coffont)) {
        throw 'The CoF engine-rasterised VGUI fonts are already present; use a clean patched source tree.'
    }
    # both halves of the scaling milestone come first: this patch reports its
    # metrics in the logical space the surface transform defines, and it edits
    # the same files the anchor pass added hooks to
    if (-not $main.Contains('CL_CoF_UIScaleUser')) {
        throw 'Apply scripts\apply-cof-ui-scale.ps1 first: the font sizes are derived from that transform.'
    }
    if (-not $fontH.Contains('CHECK_STRUCT_SIZE( Font')) {
        throw 'Not a freevgui tree.'
    }
    if (-not (Read-Target '3rdparty\freevgui\panel.cpp').Contains('Panel_SetSolveHook')) {
        throw 'Apply scripts\apply-cof-vgui-anchor.ps1 first: this patch builds on its hooks and its signed-char fixes.'
    }
    if (!(Test-Path -LiteralPath $stbFrom)) {
        throw "Missing $stbFrom - check out the mainui submodule; this patch vendors its stb_truetype.h copy."
    }
} else {
    if (-not $main.Contains('cof_ui_inter_fonts')) {
        throw 'The CoF engine-rasterised VGUI fonts are not present in this source tree; nothing to reverse.'
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
        Copy-Item -LiteralPath $stbFrom -Destination $stbTo -Force
        $got = (Get-FileHash -LiteralPath $stbTo -Algorithm SHA256).Hash
        if ($got -ne $stbHash) {
            Write-Host "NOTE: vendored stb_truetype.h hashes $got, expected $stbHash."
            Write-Host '      That is the copy this tree ships; the build will use it as-is.'
        }

        $mainAfter = Read-Target 'engine\client\cl_main.c'
        $apiAfter  = Read-Target 'engine\vgui_api.h'
        $surfAfter = Read-Target '3rdparty\freevgui\platform\xash3d-fwgs\surface.cpp'
        $fontAfter = Read-Target '3rdparty\freevgui\font.cpp'

        $present =
            $mainAfter.Contains('CVAR_DEFINE_AUTO( cof_ui_inter_fonts, "1"') -and
            $mainAfter.Contains('CVAR_DEFINE_AUTO( cof_text_codepage, "1252"') -and
            $mainAfter.Contains('CL_CoF_FontRoleLatch') -and
            $mainAfter.Contains('CL_CoF_FontProbe') -and
            $apiAfter.Contains('cof_vgui_font_t') -and
            $apiAfter.Contains('CofFontProbe') -and
            $fontAfter.Contains('Font_AllocId') -and
            $surfAfter.Contains('CofFont_Cast') -and
            $surfAfter.Contains('cofDrawProbe') -and
            (Test-Path -LiteralPath $coffont) -and
            (Test-Path -LiteralPath $stbTo)
        if (-not $present) { throw 'Applied, but the expected markers are missing. Inspect the tree.' }
        Write-Host 'Applied patches\cof-vgui-inter-fonts.patch'
        Write-Host 'Build both libraries: python waf build --targets=xash,vgui'
    } else {
        Remove-Item -LiteralPath $coffont -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $source '3rdparty\freevgui\platform\xash3d-fwgs\coffont.h') -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $stbTo -Force -ErrorAction SilentlyContinue

        if ((Read-Target 'engine\client\cl_main.c').Contains('cof_ui_inter_fonts')) {
            throw 'Reversed, but markers remain. Inspect the tree.'
        }
        Write-Host 'Reversed patches\cof-vgui-inter-fonts.patch'
    }
}
finally {
    Pop-Location
}
