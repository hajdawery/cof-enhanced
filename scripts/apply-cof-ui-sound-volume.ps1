param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!(Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "SourceRoot must be an existing directory: $SourceRoot"
}
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
$target = 'engine\client\dll_int\cl_gameui.c'
$patch = Join-Path $root 'patches\cof-ui-sound-volume.patch'

if (!(Test-Path -LiteralPath $patch)) { throw "Missing patch: $patch" }
if (!(Test-Path -LiteralPath (Join-Path $source $target))) {
    throw "Not an FWGS source tree: $(Join-Path $source $target)"
}
$rootPrefix = $root.TrimEnd('\') + '\'
if (-not $source.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}

$gameui = Get-Content -Raw -LiteralPath (Join-Path $source $target)

if ($gameui.Contains('ui_sound_volume')) {
    throw 'The CoF UI sound volume is already present; use a clean patched source tree.'
}
if (-not $gameui.Contains('S_StartLocalSound( szSound, VOL_NORM, false );')) {
    throw 'Not the expected pfnPlaySound: the unscaled S_StartLocalSound call is not there.'
}
# prerequisite: the unified UI input gate. Its cof_ui_deferred_cmd_guard block
# inside UI_UpdateMenu is this patch's neighbour in the same file, and the whole
# cof_ui_* family assumes it is in place.
if (-not $gameui.Contains('cof_ui_deferred_cmd_guard')) {
    throw 'Apply scripts\apply-cof-ui-input-gate.ps1 first: this patch belongs to the same cof_ui_* family and shares cl_gameui.c with it.'
}

Push-Location $root
try {
    $relativeSource = $source.Substring($rootPrefix.Length).Replace('\','/')
    & git apply --ignore-whitespace --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Patch does not apply cleanly to this source tree.' }
    & git apply --ignore-whitespace --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'git apply failed.' }

    $after = Get-Content -Raw -LiteralPath (Join-Path $source $target)
    $present =
        $after.Contains('static CVAR_DEFINE_AUTO( ui_sound_volume, "1.0", FCVAR_ARCHIVE') -and
        $after.Contains('Cvar_RegisterVariable( &ui_sound_volume );') -and
        $after.Contains('S_StartLocalSound( szSound, volume, false );') -and
        $after.Contains('[cof-ui] menu sound \"%s\" -> S_StartLocalSound volume %.2f') -and
        -not $after.Contains('S_StartLocalSound( szSound, VOL_NORM, false );')
    if (-not $present) {
        throw 'Patch command completed without the expected ui_sound_volume markers.'
    }
    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) {
        throw 'Applied UI sound volume patch cannot be reverse-checked.'
    }
} finally {
    Pop-Location
}
Write-Host "Applied CoF menu sound volume (ui_sound_volume) to $source"
