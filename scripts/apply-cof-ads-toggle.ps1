param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)

# Cry of Fear "Aim down sights: Hold / Toggle" (cof_ads_toggle, archived,
# default 1 = the game's own toggle) kept in the game's ironsights_toggle, plus
# the cof_key_probe / cof_ads_status developer commands. Engine only. Applied
# after the milestone-5 engine patches (scripts\apply-cof-pmove-callback-view.ps1);
# its cl_main.c hunks sit next to cof_sky_reset_per_map and the death flow.
# See docs\cof-ads-toggle.md.

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!(Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "SourceRoot must be an existing directory: $SourceRoot"
}
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
$targets = @('engine\client\input\in_keys.c', 'engine\client\cl_main.c', 'engine\client\client.h')
$patch = Join-Path $root 'patches\cof-ads-toggle.patch'

if (!(Test-Path -LiteralPath $patch)) { throw "Missing patch: $patch" }
foreach ($relative in $targets) {
    if (!(Test-Path -LiteralPath (Join-Path $source $relative))) { throw "Not an FWGS source tree: $(Join-Path $source $relative)" }
}
$rootPrefix = $root.TrimEnd('\') + '\'
if (-not $source.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}

function Slurp([string]$rel) { Get-Content -Raw -LiteralPath (Join-Path $source $rel) }

$present = (Slurp 'engine\client\cl_main.c').Contains('cof_ads_toggle')
if ($Reverse) {
    if (-not $present) { throw 'The CoF aim-down-sights option is not present in this source tree; nothing to reverse.' }
} else {
    if ($present) { throw 'The CoF aim-down-sights option is already present; use a clean patched source tree.' }
    $main = Slurp 'engine\client\cl_main.c'
    if (-not $main.Contains('cof_sky_reset_per_map') -or -not $main.Contains('cof_ui_death_menu')) {
        throw 'Apply the sky reset and death-flow patches first: this patch shares hunk context with them.'
    }
}

Push-Location $root
try {
    $relativeSource = $source.Substring($rootPrefix.Length).Replace('\','/')
    $gitArgs = @('apply','--ignore-whitespace',"--directory=$relativeSource")
    if ($Reverse) { $gitArgs += '--reverse' }
    & git @($gitArgs + @('--check','--', $patch))
    if ($LASTEXITCODE -ne 0) { throw 'Patch does not apply cleanly to this source tree.' }
    & git @($gitArgs + @('--', $patch))
    if ($LASTEXITCODE -ne 0) { throw 'git apply failed.' }

    $k = Slurp 'engine\client\input\in_keys.c'; $m = Slurp 'engine\client\cl_main.c'; $c = Slurp 'engine\client\client.h'
    if ($Reverse) {
        if ($k.Contains('cof_key_probe') -or $k.Contains('CL_CoF_ADSHold') -or $m.Contains('cof_ads_') -or $c.Contains('CL_CoF_ADSSync') -or $c.Contains('Key_QueueBindText')) {
            throw 'Reverse left aim-down-sights markers behind.'
        }
        if (-not $m.Contains('cof_sky_reset_per_map')) { throw 'Reverse damaged the sky reset patch.' }
        Write-Host "Reversed the CoF aim-down-sights option in $source"
        return
    }
    $ok = $k.Contains('"cof_key_probe"') -and $k.Contains('void Key_QueueBindText( const char *text )') -and
          $m.Contains('CVAR_DEFINE_AUTO( cof_ads_toggle, "1", FCVAR_ARCHIVE') -and
          $m.Contains('void CL_CoF_ADSSync( void )') -and $m.Contains('Cvar_RegisterVariable( &cof_ads_toggle )') -and
          $m.Contains('"cof_ads_status"') -and
          $c.Contains('void CL_CoF_ADSSync( void );') -and $c.Contains('void Key_QueueBindText( const char *text );') -and
          $k.Contains('CL_CoF_ADSHoldKey( key, down );') -and $m.Contains('void CL_CoF_ADSHoldKey( int key, qboolean down )') -and
          $m.Contains('Cvar_RegisterVariable( &cof_ads_hold_pulse )') -and $c.Contains('qboolean CL_CoF_ADSHoldActive( void );')
    if (-not $ok) { throw 'Patch command completed without the expected aim-down-sights markers.' }
} finally {
    Pop-Location
}
Write-Host "Applied the CoF aim-down-sights option to $source"
