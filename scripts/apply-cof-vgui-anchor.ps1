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
$vguiRel = '3rdparty\freevgui'
$vgui = Join-Path $source $vguiRel
$targets = @(
    'panel.cpp',
    'panel.h',
    'font.cpp',
    'image.cpp',
    'controls\text.cpp',
    'controls\edit.cpp',
    'platform\xash3d-fwgs\app.cpp',
    'platform\xash3d-fwgs\support.h'
)
$patch = Join-Path $root 'patches\cof-vgui-anchor.patch'

if (!(Test-Path -LiteralPath $patch)) { throw "Missing patch: $patch" }
if (!(Test-Path -LiteralPath $vgui -PathType Container)) {
    throw "Not an FWGS source tree with the freevgui submodule checked out: $vgui"
}
foreach($relative in $targets) {
    if (!(Test-Path -LiteralPath (Join-Path $vgui $relative))) {
        throw "Missing freevgui source: $(Join-Path $vgui $relative)"
    }
}
$rootPrefix = $root.TrimEnd('\') + '\'
if (-not $source.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}

function Read-Vgui([string] $relative) {
    Get-Content -Raw -LiteralPath (Join-Path $vgui $relative)
}

$panelCpp = Read-Vgui 'panel.cpp'
$panelH   = Read-Vgui 'panel.h'
$appCpp   = Read-Vgui 'platform\xash3d-fwgs\app.cpp'
$scale    = Join-Path $vgui 'platform\xash3d-fwgs\cofscale.cpp'

if (-not $Reverse) {
    if ($panelCpp.Contains('Panel_SetSolveHook') -or (Test-Path -LiteralPath $scale)) {
        throw 'The CoF VGUI anchor pass is already present; use a clean freevgui tree.'
    }
    # the engine half must be in place: this library calls
    # g_engine->CofUITransform, which that patch adds to vguiapi_t
    $api = Join-Path $source 'engine\vgui_api.h'
    if (!(Test-Path -LiteralPath $api) -or -not (Get-Content -Raw -LiteralPath $api).Contains('CofUITransform')) {
        throw 'Apply scripts\apply-cof-ui-scale.ps1 first: this patch calls the CofUITransform entry it adds to vguiapi_t.'
    }
} else {
    if (-not $panelCpp.Contains('Panel_SetSolveHook')) {
        throw 'The CoF VGUI anchor pass is not present in this tree; nothing to reverse.'
    }
}

Push-Location $root
try {
    $relativeVgui = (Join-Path $source.Substring($rootPrefix.Length) $vguiRel).Replace('\','/')
    $extra = @()
    if ($Reverse) { $extra += '--reverse' }

    & git apply --ignore-whitespace --check --directory=$relativeVgui @extra -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Patch does not apply cleanly to this freevgui tree.' }
    & git apply --ignore-whitespace --directory=$relativeVgui @extra -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'git apply failed.' }

    $panelCppAfter = Read-Vgui 'panel.cpp'
    $panelHAfter   = Read-Vgui 'panel.h'
    $appCppAfter   = Read-Vgui 'platform\xash3d-fwgs\app.cpp'
    $fontAfter     = Read-Vgui 'font.cpp'
    $imageAfter    = Read-Vgui 'image.cpp'

    if (-not $Reverse) {
        $present =
            $panelHAfter.Contains('struct CofPanelAccess') -and
            $panelHAfter.Contains('Panel_SetSolveHook') -and
            $panelCppAfter.Contains('g_panelSolveHook( this )') -and
            $appCppAfter.Contains('Panel_SetSolveHook( CofUI_SolvePanel )') -and
            $fontAfter.Contains('getCharABCwide( (unsigned char)ch') -and
            $imageAfter.Contains('int ch = (unsigned char)text[i]') -and
            (Test-Path -LiteralPath $scale) -and
            (Get-Content -Raw -LiteralPath $scale).Contains('bool CofIsPage( Panel *p )')
        if (-not $present) { throw 'Applied, but the expected markers are missing. Inspect the tree.' }
        Write-Host 'Applied patches\cof-vgui-anchor.patch'
        Write-Host 'Build the support library as well as the engine: python waf build --targets=xash,vgui'
    } else {
        Remove-Item -LiteralPath $scale -Force -ErrorAction SilentlyContinue
        $absent = -not $panelCppAfter.Contains('Panel_SetSolveHook') -and -not (Test-Path -LiteralPath $scale)
        if (-not $absent) { throw 'Reversed, but markers remain. Inspect the tree.' }
        Write-Host 'Reversed patches\cof-vgui-anchor.patch'
    }
}
finally {
    Pop-Location
}
