param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)
# Cancel retail mixed-axis forward halving for continuous Digital-style input.
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
if (-not $source.StartsWith($root.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}
$patch = Join-Path $root 'patches\cof-pad-digital-speed.patch'
$markers = @{
    'engine/client/input/cof_gamepad.c' = 'static CVAR_DEFINE_AUTO( cof_pad_move_fix, "1"'
    'engine/client/input.h' = 'void CL_CoF_PadMoveCorrectCommand('
    'engine/client/input/input.c' = 'CL_CoF_PadMoveCorrectCommand( cmd, forwardmove, sidemove );'
}
function Read-Source([string] $relative) {
    Get-Content -LiteralPath (Join-Path $source $relative) -Raw
}
foreach ($entry in $markers.GetEnumerator()) {
    $content = Read-Source $entry.Key
    if ($Reverse -and -not $content.Contains($entry.Value)) { throw "Missing digital movement marker: $($entry.Key)" }
    if (-not $Reverse -and $content.Contains($entry.Value)) { throw "Digital movement patch already present: $($entry.Key)" }
}
if (-not $Reverse -and -not (Read-Source 'engine/client/input/input.c').Contains('IN_CoFMoveDiagnostic')) {
    throw 'Prerequisite missing: apply the gamepad movement patches first.'
}
$relativeSource = $source.Substring($root.TrimEnd('\').Length + 1).Replace('\', '/')
$direction = @()
if ($Reverse) { $direction += '--reverse' }
Push-Location $root
try {
    & git apply --ignore-whitespace @direction --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Digital movement patch check failed.' }
    & git apply --ignore-whitespace @direction --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Digital movement patch apply failed.' }
    foreach ($entry in $markers.GetEnumerator()) {
        if ((Read-Source $entry.Key).Contains($entry.Value) -eq [bool]$Reverse) {
            throw "Unexpected digital movement marker state: $($entry.Key)"
        }
    }
    $opposite = @()
    if (-not $Reverse) { $opposite += '--reverse' }
    & git apply --ignore-whitespace @opposite --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Digital movement patch failed its round-trip check.' }
} finally { Pop-Location }
Write-Host "Digital movement correction applied (reverse=$Reverse): $source"
