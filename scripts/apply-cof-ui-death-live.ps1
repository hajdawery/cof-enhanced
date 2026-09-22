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
    'engine\common\common.h',
    'engine\client\sound\s_mix.c',
    'engine\client\sound\s_stream.c',
    'engine\server\sv_client.c',
    'engine\server\sv_cmds.c'
)
$patch = Join-Path $root 'patches\cof-ui-death-live.patch'

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
$common = Read-Target 'engine\common\common.h'

if (-not $Reverse) {
    if ($main.Contains('cof_ui_death_keep_running') -or $common.Contains('CL_CoF_DeathWorldLive')) {
        throw 'The CoF death-page world-live exception is already present; use a clean patched source tree.'
    }
    # the death page itself has to exist first: this patch is the single
    # predicate CL_CoF_DeathMenuActive() feeds, and it uses that function's
    # neighbourhood as hunk context
    if (-not $main.Contains('CL_CoF_DeathMenuActive')) {
        throw 'Apply scripts\apply-cof-ui-death-flow.ps1 first: this patch extends the death page it adds.'
    }
    # the cvar block this patch inserts into is the input gate's
    if (-not $main.Contains('cof_mp3_stop_on_map')) {
        throw 'Apply scripts\apply-cof-mp3-stop-on-map.ps1 first: this patch inserts its cvar before that one.'
    }
} else {
    if (-not $main.Contains('cof_ui_death_keep_running')) {
        throw 'The CoF death-page world-live exception is not present in this source tree; nothing to reverse.'
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
        $mainAfter   = Read-Target 'engine\client\cl_main.c'
        $commonAfter = Read-Target 'engine\common\common.h'
        $mixAfter    = Read-Target 'engine\client\sound\s_mix.c'
        $streamAfter = Read-Target 'engine\client\sound\s_stream.c'
        $clientAfter = Read-Target 'engine\server\sv_client.c'
        $cmdsAfter   = Read-Target 'engine\server\sv_cmds.c'

        $present =
            $mainAfter.Contains('CVAR_DEFINE_AUTO( cof_ui_death_keep_running, "1"') -and
            $mainAfter.Contains('qboolean CL_CoF_DeathWorldLive( void )') -and
            $commonAfter.Contains('static inline qboolean CL_CoF_DeathWorldLive( void ) { return false; }') -and
            $mixAfter.Contains('!CL_CoF_DeathWorldLive( ))') -and
            $streamAfter.Contains('!CL_CoF_DeathWorldLive( )) return;') -and
            $clientAfter.Contains('CL_CoF_DeathWorldLive() || SV_PlayerIsFrozen( player )') -and
            $cmdsAfter.Contains('SV_CoFWorldProbe_f') -and
            $cmdsAfter.Contains('cof_world_probe')
        if (-not $present) { throw 'Applied, but the expected markers are missing. Inspect the tree.' }
        Write-Host 'Applied patches\cof-ui-death-live.patch'
        Write-Host 'Build the engine: python waf build --targets=xash'
    } else {
        if ((Read-Target 'engine\client\cl_main.c').Contains('cof_ui_death_keep_running')) {
            throw 'Reversed, but markers remain. Inspect the tree.'
        }
        Write-Host 'Reversed patches\cof-ui-death-live.patch'
    }
}
finally {
    Pop-Location
}
