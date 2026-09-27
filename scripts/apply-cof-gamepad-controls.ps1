param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)
# Additive gamepad round 4 controls patch; after gamepad-input and before cheats.
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
if (-not $source.StartsWith($root.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}
$patch = Join-Path $root 'patches\cof-gamepad-controls.patch'
$markers = @{
    'engine/client/input/cof_gamepad.c' = 'static CVAR_DEFINE_AUTO( cof_pad_no_doubletap, "1"'
    'engine/client/input/input.c' = 'CL_CoF_PadMoveCommand( "+forward" );'
    'engine/client/input.h' = 'void CL_CoF_PadMoveCommand( const char *command );'
    '3rdparty/mainui/menus/CoFOptions.cpp' = 'ALT action; RB default since generation 5'
}
function Read-Source([string] $relative) {
    Get-Content -LiteralPath (Join-Path $source $relative) -Raw
}
foreach ($entry in $markers.GetEnumerator()) {
    $content = Read-Source $entry.Key
    if ($Reverse -and -not $content.Contains($entry.Value)) { throw "Missing controls marker: $($entry.Key)" }
    if (-not $Reverse -and $content.Contains($entry.Value)) { throw "Controls patch already present: $($entry.Key)" }
}
if (-not $Reverse) {
    if (-not (Read-Source 'engine/client/input/cof_gamepad.c').Contains('#define COF_PAD_DEFAULTS_GENERATION 4') -or
        -not (Read-Source 'engine/client/input/input.c').Contains('CL_CoF_PadMoveKeyThresholds( &fthr, &sthr );') -or
        -not (Read-Source '3rdparty/mainui/menus/CoFOptions.cpp').Contains('AddAction( "cof_quickturn", L( "Quick turn" ));')) {
        throw 'Prerequisite missing: apply cof-gamepad-input and its MainUI prerequisites first.'
    }
}
$relativeSource = $source.Substring($root.TrimEnd('\').Length + 1).Replace('\', '/')
$direction = @()
if ($Reverse) { $direction += '--reverse' }
Push-Location $root
try {
    & git apply --ignore-whitespace @direction --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Gamepad controls patch check failed.' }
    & git apply --ignore-whitespace @direction --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Gamepad controls patch apply failed.' }
    foreach ($entry in $markers.GetEnumerator()) {
        if ((Read-Source $entry.Key).Contains($entry.Value) -eq [bool]$Reverse) {
            throw "Unexpected controls marker state after apply/reverse: $($entry.Key)"
        }
    }
    $opposite = @()
    if (-not $Reverse) { $opposite += '--reverse' }
    & git apply --ignore-whitespace @opposite --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Gamepad controls patch failed its round-trip check.' }
} finally { Pop-Location }
Write-Host "Gamepad controls patch applied (reverse=$Reverse): $source"
