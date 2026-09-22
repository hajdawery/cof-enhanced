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
    'engine\client\dll_int\cl_game.c',
    'engine\client\dll_int\ref_common.c',
    'engine\server\sv_main.c',
    'engine\server\server.h',
    'engine\server\sv_game.c'
)
$patch = Join-Path $root 'patches\cof-sky-reset-per-map.patch'

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

function Slurp([string]$rel) { Get-Content -Raw -LiteralPath (Join-Path $source $rel) }

$main = Slurp 'engine\client\cl_main.c'
$hdr  = Slurp 'engine\client\client.h'
$game = Slurp 'engine\client\dll_int\cl_game.c'
$ref  = Slurp 'engine\client\dll_int\ref_common.c'
$svm  = Slurp 'engine\server\sv_main.c'
$svh  = Slurp 'engine\server\server.h'
$svg  = Slurp 'engine\server\sv_game.c'

$present = $main.Contains('cof_sky_reset_per_map')

if ($Reverse) {
    if (-not $present) { throw 'The CoF sky reset is not present in this source tree; nothing to reverse.' }
} else {
    if ($present) { throw 'The CoF sky reset is already present; use a clean patched source tree.' }
    # prerequisites: the cl_main.c hunks sit directly under the unified UI
    # cvars and the mp3 cvar and inside CL_ClearState next to the vid-restart
    # and death-flow calls; the client.h hunk sits under the vid-restart block
    if (-not $main.Contains('cof_ui_menu_map_redirect')) {
        throw 'Apply scripts\apply-cof-ui-menu-map-redirect.ps1 first: this patch shares hunk context with the unified UI redirect.'
    }
    if (-not $main.Contains('cof_vid_restart_background')) {
        throw 'Apply scripts\apply-cof-vid-restart-background.ps1 first: this patch shares hunk context with the vid-restart hook in CL_ClearState.'
    }
    if (-not $main.Contains('cof_ui_death_menu')) {
        throw 'Apply scripts\apply-cof-ui-death-flow.ps1 first: this patch shares hunk context with the death flow.'
    }
    if (-not $main.Contains('cof_mp3_stop_on_map')) {
        throw 'Apply scripts\apply-cof-mp3-stop-on-map.ps1 first: this patch shares hunk context with the MP3 stop hook.'
    }
    # the server half replaces the stock "desert" default of sv_skyname; the
    # hunks are anchored on stock FWGS code, so only the cvar has to be there
    if (-not $svm.Contains('CVAR_DEFINE_AUTO( sv_skyname, "desert"')) {
        throw 'engine\server\sv_main.c does not carry the stock sv_skyname definition this patch anchors on.'
    }
    if (-not $svg.Contains('Cvar_Reset( "sv_skyname" );')) {
        throw 'engine\server\sv_game.c does not carry the stock SV_SpawnEntities sky reset this patch anchors on.'
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

    $mainAfter = Slurp 'engine\client\cl_main.c'
    $hdrAfter  = Slurp 'engine\client\client.h'
    $gameAfter = Slurp 'engine\client\dll_int\cl_game.c'
    $refAfter  = Slurp 'engine\client\dll_int\ref_common.c'
    $svmAfter  = Slurp 'engine\server\sv_main.c'
    $svhAfter  = Slurp 'engine\server\server.h'
    $svgAfter  = Slurp 'engine\server\sv_game.c'

    if ($Reverse) {
        $gone = -not $mainAfter.Contains('cof_sky_reset_per_map') -and
                -not $mainAfter.Contains('CL_CoF_SkyResetPerMap();') -and
                -not $hdrAfter.Contains('CL_CoF_SkyResetPerMap') -and
                -not $gameAfter.Contains('pfnCvarSetValue') -and
                -not $refAfter.Contains('CL_CoF_SkyResetPerMap') -and
                -not $svmAfter.Contains('cof_default_skyname') -and
                -not $svhAfter.Contains('SV_CoF_ApplyDefaultSkyName') -and
                -not $svgAfter.Contains('SV_CoF_ApplyDefaultSkyName();')
        if (-not $gone) { throw 'Reverse left sky-reset markers behind.' }
        # a reverse must not damage the patches this one sits on top of, the
        # stock engfuncs table, or the stock server sky defaults
        $intact = $mainAfter.Contains('cof_ui_menu_map_redirect') -and
                  $mainAfter.Contains('cof_ui_death_menu') -and
                  $mainAfter.Contains('cof_mp3_stop_on_map') -and
                  $mainAfter.Contains('CL_CoF_DeathForget();') -and
                  $gameAfter.Contains('CL_CoF_MenuPanelSound( szSound, volume )') -and
                  $gameAfter.Contains("`tCvar_SetValue,") -and
                  $svmAfter.Contains('CVAR_DEFINE_AUTO( sv_skyname, "desert"') -and
                  $svgAfter.Contains('Cvar_Reset( "sv_skyname" );')
        if (-not $intact) { throw 'Reverse damaged the earlier CoF patches, the stock engfuncs table or the stock sv_skyname default.' }
        Write-Host "Reversed the CoF per-map sky reset in $source"
        return
    }

    $ok = $mainAfter.Contains('static CVAR_DEFINE_AUTO( cof_sky_reset_per_map, "1"') -and
          $mainAfter.Contains('Cvar_RegisterVariable( &cof_sky_reset_per_map )') -and
          $mainAfter.Contains('void CL_CoF_SkyClientCvarSet( const char *name, float value )') -and
          $mainAfter.Contains('void CL_CoF_SkyResetPerMap( void )') -and
          $mainAfter.Contains('#define COF_SKY_CVAR') -and
          $mainAfter.Contains('static qboolean	cof_sky_off_by_client;') -and
          $hdrAfter.Contains('void CL_CoF_SkyClientCvarSet( const char *name, float value );') -and
          $hdrAfter.Contains('void CL_CoF_SkyResetPerMap( void );') -and
          $gameAfter.Contains('static void GAME_EXPORT pfnCvarSetValue( const char *name, float value )') -and
          $gameAfter.Contains("`tpfnCvarSetValue,") -and
          $refAfter.Contains('CL_CoF_SkyResetPerMap();') -and
          $svmAfter.Contains('CVAR_DEFINE_AUTO( cof_default_skyname, "black", FCVAR_ARCHIVE') -and
          $svmAfter.Contains('Cvar_RegisterVariable( &cof_default_skyname )') -and
          $svmAfter.Contains('void SV_CoF_ApplyDefaultSkyName( void )') -and
          $svhAfter.Contains('void SV_CoF_ApplyDefaultSkyName( void );') -and
          $svgAfter.Contains('SV_CoF_ApplyDefaultSkyName();')
    if (-not $ok) { throw 'Patch command completed without the expected sky-reset markers.' }

    # the wrapper must REPLACE the raw Cvar_SetValue slot, not be added next to
    # it: two entries would shift every engfunc after index 37 and break the
    # client's whole table
    if ($gameAfter -match "(?m)^\tCvar_SetValue,\s*$") {
        throw 'The client engfuncs table still has the raw Cvar_SetValue entry; the wrapper must replace it.'
    }

    # the level-start restore has to be reached from BOTH hooks: R_SetupSky and
    # CL_ClearState. One of them alone is what the first round shipped.
    if (($mainAfter -split "`n" | Where-Object { $_ -match '^\s+CL_CoF_SkyResetPerMap\(\);' }).Count -lt 1) {
        throw 'CL_ClearState does not call CL_CoF_SkyResetPerMap; the level-start hook is missing.'
    }

    # the server default must be applied where sv_skyname is reset, before the
    # entity lump is parsed, or a map WITH a skyname would be overridden
    $spawn = [regex]::Match($svgAfter, '(?s)void SV_SpawnEntities\(.*?SV_LoadFromFile')
    if (-not $spawn.Success -or -not $spawn.Value.Contains('SV_CoF_ApplyDefaultSkyName();')) {
        throw 'SV_CoF_ApplyDefaultSkyName is not called inside SV_SpawnEntities before SV_LoadFromFile.'
    }

    & git @('apply','--ignore-whitespace','--reverse','--check',"--directory=$relativeSource", '--', $patch)
    if ($LASTEXITCODE -ne 0) { throw 'Applied sky-reset patch cannot be reverse-checked.' }
} finally {
    Pop-Location
}
Write-Host "Applied the CoF per-map sky reset to $source"
