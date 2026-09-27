param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)
# Opt-in movement logging; no command or movement changes.
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
if (-not $source.StartsWith($root.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}
$patch = Join-Path $root 'patches\cof-pad-move-diagnostics.patch'
$markers = @{
    'engine/client/input/input.c' = 'static CVAR_DEFINE_AUTO( cof_pad_move_debug, "0"'
}
function Read-Source([string] $relative) {
    Get-Content -LiteralPath (Join-Path $source $relative) -Raw
}
foreach ($entry in $markers.GetEnumerator()) {
    $content = Read-Source $entry.Key
    if ($Reverse -and -not $content.Contains($entry.Value)) { throw "Missing movement diagnostic marker: $($entry.Key)" }
    if (-not $Reverse -and $content.Contains($entry.Value)) { throw "Movement diagnostic patch already present: $($entry.Key)" }
}
if (-not $Reverse -and -not (Read-Source 'engine/client/input/input.c').Contains('CL_CoF_PadMoveKeyThresholds')) {
    throw 'Prerequisite missing: apply the gamepad movement patches first.'
}
$relativeSource = $source.Substring($root.TrimEnd('\').Length + 1).Replace('\', '/')
$direction = @()
if ($Reverse) { $direction += '--reverse' }
Push-Location $root
try {
    & git apply --ignore-whitespace @direction --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Movement diagnostic patch check failed.' }
    & git apply --ignore-whitespace @direction --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Movement diagnostic patch apply failed.' }
    foreach ($entry in $markers.GetEnumerator()) {
        if ((Read-Source $entry.Key).Contains($entry.Value) -eq [bool]$Reverse) {
            throw "Unexpected movement diagnostic marker state: $($entry.Key)"
        }
    }
    $opposite = @()
    if (-not $Reverse) { $opposite += '--reverse' }
    & git apply --ignore-whitespace @opposite --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Movement diagnostic patch failed its round-trip check.' }
} finally { Pop-Location }
Write-Host "Movement diagnostics applied (reverse=$Reverse): $source"
