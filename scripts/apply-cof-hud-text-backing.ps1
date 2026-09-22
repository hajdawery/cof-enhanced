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
    'engine\client\cl_scrn.c',
    'engine\client\dll_int\cl_game.c',
    'engine\vgui_api.h',
    'engine\client\vgui\vgui_draw.c',
    '3rdparty\freevgui\platform\xash3d-fwgs\cofscale.cpp',
    '3rdparty\freevgui\platform\xash3d-fwgs\surface.cpp',
    '3rdparty\freevgui\platform\xash3d-fwgs\support.h',
    '3rdparty\freevgui\platform\xash3d-fwgs\clip.cpp',
    '3rdparty\freevgui\platform\xash3d-fwgs\coffont.cpp',
    '3rdparty\freevgui\platform\xash3d-fwgs\coffont.h',
    '3rdparty\freevgui\platform\xash3d-fwgs\app.cpp'
)
$patch = Join-Path $root 'patches\cof-hud-text-backing.patch'

if (!(Test-Path -LiteralPath $patch)) { throw "Missing patch: $patch" }
foreach($relative in $targets) {
    if (!(Test-Path -LiteralPath (Join-Path $source $relative))) {
        throw "Not an FWGS source tree with freevgui checked out and the font patch applied: $(Join-Path $source $relative)"
    }
}
$rootPrefix = $root.TrimEnd('\') + '\'
if (-not $source.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}

function Read-Target([string] $relative) {
    Get-Content -Raw -LiteralPath (Join-Path $source $relative)
}

$main = Read-Target 'engine\client\cl_main.c'
$scrn = Read-Target 'engine\client\cl_scrn.c'
$api  = Read-Target 'engine\vgui_api.h'

if (-not $Reverse) {
    if ($main.Contains('cof_hud_text_backing') -or $scrn.Contains('scr_hud_text_atlas_base')) {
        throw 'The CoF HUD text legibility round is already present; use a clean patched source tree.'
    }
    # the HUD font sizing this builds on
    if (-not $main.Contains('cof_hud_text_height_pct')) {
        throw 'Apply scripts\apply-cof-ui-scale.ps1 first: this patch resizes and restyles the font that one introduced.'
    }
    # the engine-rasterised VGUI fonts own cof_vgui_font_t, whose struct this
    # patch extends, and the surface/coffont files it edits
    if (-not $api.Contains('cof_vgui_font_t')) {
        throw 'Apply scripts\apply-cof-vgui-inter-fonts.ps1 first: this patch extends its font descriptor and its surface.'
    }
} else {
    if (-not $main.Contains('cof_hud_text_backing')) {
        throw 'The CoF HUD text legibility round is not present in this source tree; nothing to reverse.'
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
        $mainAfter = Read-Target 'engine\client\cl_main.c'
        $scrnAfter = Read-Target 'engine\client\cl_scrn.c'
        $gameAfter = Read-Target 'engine\client\dll_int\cl_game.c'
        $apiAfter  = Read-Target 'engine\vgui_api.h'
        $surfAfter = Read-Target '3rdparty\freevgui\platform\xash3d-fwgs\surface.cpp'
        $suppAfter = Read-Target '3rdparty\freevgui\platform\xash3d-fwgs\support.h'
        $cofAfter  = Read-Target '3rdparty\freevgui\platform\xash3d-fwgs\coffont.cpp'
        $appAfter  = Read-Target '3rdparty\freevgui\platform\xash3d-fwgs\app.cpp'
        $clipAfter = Read-Target '3rdparty\freevgui\platform\xash3d-fwgs\clip.cpp'

        $present =
            $mainAfter.Contains('CVAR_DEFINE_AUTO( cof_hud_text_font, "1"') -and
            $mainAfter.Contains('CVAR_DEFINE_AUTO( cof_hud_text_backing, "120"') -and
            $mainAfter.Contains('CL_CoF_HudTextProbe_f') -and
            $scrnAfter.Contains('scr_hud_text_atlas_base') -and
            $scrnAfter.Contains('SCR_HudTextUseAtlas') -and
            $gameAfter.Contains('CL_CoF_HudTextFlush') -and
            $gameAfter.Contains('CL_CoF_HudTextYOffset') -and
            $apiAfter.Contains('int	backing;') -and
            $mainAfter.Contains('CVAR_DEFINE_AUTO( cof_hud_msg_y_pct, "78"') -and
            $mainAfter.Contains('CL_CoF_FontRoleIsMessage') -and
            $mainAfter.Contains('CL_CoF_MsgProbe_f') -and
            $surfAfter.Contains('deferBackingGlyph') -and
            $surfAfter.Contains('applyTextYTarget') -and
            $suppAfter.Contains('MAX_TEXT_BACKING_LINES') -and
            # milestone 5a: the moved message run carries its clip rectangle
            $clipAfter.Contains('Scissor::getRect') -and
            $cofAfter.Contains('CofFont_Backing') -and
            $appAfter.Contains('flushBackingText')
        if (-not $present) { throw 'Applied, but the expected markers are missing. Inspect the tree.' }
        Write-Host 'Applied patches\cof-hud-text-backing.patch'
        Write-Host 'Build both libraries: python waf build --targets=xash,vgui'
        Write-Host 'The generated atlases gamedata/cryoffear/fonts/cof_hudtext{0,1}.fnt ship with it.'
    } else {
        if ((Read-Target 'engine\client\cl_main.c').Contains('cof_hud_text_backing')) {
            throw 'Reversed, but markers remain. Inspect the tree.'
        }
        Write-Host 'Reversed patches\cof-hud-text-backing.patch'
    }
}
finally {
    Pop-Location
}
