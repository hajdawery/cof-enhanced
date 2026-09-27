param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)
# OSK dismissal keys belong to the keyboard overlay until physically released.
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
if (-not $source.StartsWith($root.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}
$patch = Join-Path $root 'patches\cof-osk-dismiss-guard.patch'
$markers = @{
    'engine/client/cof_enter_hook.c' = 'static CVAR_DEFINE_AUTO( cof_osk_dismiss_guard, "1"'
    'engine/client/client.h' = 'void CL_CoF_EnterOskDismiss( void );'
    'engine/client/cof_osk.c' = 'CL_CoF_EnterOskDismiss();'
}
function Read-Source([string] $relative) {
    Get-Content -LiteralPath (Join-Path $source $relative) -Raw
}
foreach ($entry in $markers.GetEnumerator()) {
    $content = Read-Source $entry.Key
    if ($Reverse -and -not $content.Contains($entry.Value)) { throw "Missing dismissal marker: $($entry.Key)" }
    if (-not $Reverse -and $content.Contains($entry.Value)) { throw "Dismissal patch already present: $($entry.Key)" }
}
if (-not $Reverse) {
    if (-not (Read-Source 'engine/client/cof_osk.c').Contains('cof_osk_field_index') -or
        -not (Read-Source 'engine/client/cof_enter_hook.c').Contains('qboolean CL_CoF_EnterKeyEvent( int key, int down )')) {
        throw 'Prerequisite missing: apply compact/context OSK and client-enter-hook patches first.'
    }
}
$relativeSource = $source.Substring($root.TrimEnd('\').Length + 1).Replace('\', '/')
$direction = @()
if ($Reverse) { $direction += '--reverse' }
Push-Location $root
try {
    & git apply --ignore-whitespace @direction --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'OSK dismissal patch check failed.' }
    & git apply --ignore-whitespace @direction --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'OSK dismissal patch apply failed.' }
    foreach ($entry in $markers.GetEnumerator()) {
        if ((Read-Source $entry.Key).Contains($entry.Value) -eq [bool]$Reverse) {
            throw "Unexpected dismissal marker state: $($entry.Key)"
        }
    }
    $opposite = @()
    if (-not $Reverse) { $opposite += '--reverse' }
    & git apply --ignore-whitespace @opposite --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'OSK dismissal patch failed its round-trip check.' }
} finally { Pop-Location }
Write-Host "OSK dismissal guard applied (reverse=$Reverse): $source"
