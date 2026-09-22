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
    'engine\client\vgui\vgui_draw.c',
    'engine\vgui_api.h'
)
$patch = Join-Path $root 'patches\cof-ui-scale.patch'

if (!(Test-Path -LiteralPath $patch)) { throw "Missing patch: $patch" }
foreach($relative in $targets) {
    if (!(Test-Path -LiteralPath (Join-Path $source $relative))) {
        throw "Not an FWGS source tree: $(Join-Path $source $relative)"
    }
}
$rootPrefix = $root.TrimEnd('\') + '\'
if (-not $source.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}

function Read-Target([string] $relative) {
    Get-Content -Raw -LiteralPath (Join-Path $source $relative)
}

$main   = Read-Target 'engine\client\cl_main.c'
$header = Read-Target 'engine\client\client.h'
$scrn   = Read-Target 'engine\client\cl_scrn.c'
$game   = Read-Target 'engine\client\dll_int\cl_game.c'
$vgui   = Read-Target 'engine\client\vgui\vgui_draw.c'
$api    = Read-Target 'engine\vgui_api.h'

if (-not $Reverse) {
    if ($main.Contains('cof_ui_scale') -or $vgui.Contains('CL_CoF_UIScaleRect') -or
        $api.Contains('CofUITransform')) {
        throw 'The CoF in-game UI scaling is already present; use a clean patched source tree.'
    }
    # prerequisite: the UI gate supplies the CL_CoF_UIGateActive() lines this
    # patch uses as hunk context in cl_main.c and cl_game.c, and owns the
    # cof_* cvar block this patch appends to
    if (-not $main.Contains('CL_CoF_UIGateActive')) {
        throw 'Apply scripts\apply-cof-ui-input-gate.ps1 first: this patch extends its cof_* cvar block and uses its hunk context.'
    }
    # the sky reset is the last cvar in that block before this one
    if (-not $main.Contains('cof_sky_reset_per_map')) {
        throw 'Apply scripts\apply-cof-sky-reset-per-map.ps1 first: this patch appends its cvars after that one.'
    }
    # cl_scrn.c is shared with the console/overlay text scaling, whose
    # SCR_LoadCreditsFont neighbourhood this patch edits
    if (-not $scrn.Contains('cof_text_autoscale') -and -not $scrn.Contains('Con_TextTargetHeight')) {
        throw 'Apply scripts\apply-cof-text-autoscale.ps1 first: this patch shares cl_scrn.c hunk context with it.'
    }
} else {
    if (-not $main.Contains('cof_ui_scale')) {
        throw 'The CoF in-game UI scaling is not present in this source tree; nothing to reverse.'
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

    $mainAfter = Read-Target 'engine\client\cl_main.c'
    $gameAfter = Read-Target 'engine\client\dll_int\cl_game.c'
    $scrnAfter = Read-Target 'engine\client\cl_scrn.c'
    $vguiAfter = Read-Target 'engine\client\vgui\vgui_draw.c'
    $apiAfter  = Read-Target 'engine\vgui_api.h'

    if (-not $Reverse) {
        $present =
            $mainAfter.Contains('CVAR_DEFINE_AUTO( cof_ui_scale, "0"') -and
            $mainAfter.Contains('CVAR_DEFINE_AUTO( cof_ui_scale_user, "1.0"') -and
            $mainAfter.Contains('CVAR_DEFINE_AUTO( cof_ui_scale_sprites, "1"') -and
            $mainAfter.Contains('CVAR_DEFINE_AUTO( cof_hud_text_height_pct, "1.76"') -and
            $mainAfter.Contains('CL_CoF_UIPinLayout') -and
            $mainAfter.Contains('CL_CoF_HudScaleBlocked') -and
            $mainAfter.Contains('CL_CoF_CheckUIScaleChanged') -and
            $gameAfter.Contains('COF_SPRITE_MAX_WIDGET') -and
            $gameAfter.Contains('CL_CoF_HudScaleBlocked( )') -and
            $scrnAfter.Contains('SCR_HudTextTargetHeight') -and
            $scrnAfter.Contains('SCR_ScaleCreditsFont') -and
            $vguiAfter.Contains('CL_CoF_UIScaleRect') -and
            $vguiAfter.Contains('VGUI_CofUITransform') -and
            $apiAfter.Contains('CofUITransform')
        if (-not $present) { throw 'Applied, but the expected markers are missing. Inspect the tree.' }
        Write-Host 'Applied patches\cof-ui-scale.patch'
        Write-Host 'NOTE: this patch is the engine half only. Apply scripts\apply-cof-vgui-anchor.ps1 as well,'
        Write-Host '      or the client panels scale without being re-anchored and the HUD leaves the screen.'
    } else {
        $absent =
            -not $mainAfter.Contains('cof_ui_scale') -and
            -not $gameAfter.Contains('COF_SPRITE_MAX_WIDGET') -and
            -not $scrnAfter.Contains('SCR_HudTextTargetHeight') -and
            -not $vguiAfter.Contains('CL_CoF_UIScaleRect') -and
            -not $apiAfter.Contains('CofUITransform')
        if (-not $absent) { throw 'Reversed, but markers remain. Inspect the tree.' }
        Write-Host 'Reversed patches\cof-ui-scale.patch'
    }
}
finally {
    Pop-Location
}
