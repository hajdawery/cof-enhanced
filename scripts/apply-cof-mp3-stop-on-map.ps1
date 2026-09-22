param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot
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
    'engine\common\host_state.c'
)
$patch = Join-Path $root 'patches\cof-mp3-stop-on-map.patch'

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

$main   = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\cl_main.c')
$common = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\common\common.h')
$state  = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\common\host_state.c')

if ($main.Contains('cof_mp3_stop_on_map') -or $state.Contains('CL_CoF_StopMP3')) {
    throw 'The CoF MP3 stop hook is already present; use a clean patched source tree.'
}
# prerequisite: the hunks sit next to the unified UI cvars and the
# CL_CoF_* declaration block the redirect adds to common.h
if (-not $main.Contains('cof_ui_menu_map_redirect')) {
    throw 'Apply scripts\apply-cof-ui-menu-map-redirect.ps1 first: this patch shares hunk context with the unified UI redirect.'
}
if (-not $main.Contains('cof_ui_death_menu')) {
    throw 'Apply scripts\apply-cof-ui-death-flow.ps1 first: this patch shares hunk context with the death flow.'
}

Push-Location $root
try {
    $relativeSource = $source.Substring($rootPrefix.Length).Replace('\','/')
    & git apply --ignore-whitespace --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Patch does not apply cleanly to this source tree.' }
    & git apply --ignore-whitespace --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'git apply failed.' }

    $mainAfter   = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\cl_main.c')
    $commonAfter = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\common\common.h')
    $stateAfter  = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\common\host_state.c')

    $present = $mainAfter.Contains('static CVAR_DEFINE_AUTO( cof_mp3_stop_on_map, "1"') -and
               $mainAfter.Contains('Cvar_RegisterVariable( &cof_mp3_stop_on_map )') -and
               $mainAfter.Contains('void CL_CoF_StopMP3( const char *reason )') -and
               $mainAfter.Contains('Cmd_ExecuteString( "stopmp3" )') -and
               $mainAfter.Contains('CL_CoF_StopMP3( "disconnect" )') -and
               $commonAfter.Contains('void CL_CoF_StopMP3( const char *reason );') -and
               $commonAfter.Contains('static inline void CL_CoF_StopMP3( const char *reason ) { }') -and
               $stateAfter.Contains('CL_CoF_StopMP3( "newgame" )') -and
               $stateAfter.Contains('CL_CoF_StopMP3( "map" )') -and
               $stateAfter.Contains('CL_CoF_StopMP3( "load" )')
    if (-not $present) {
        throw 'Patch command completed without the expected MP3 stop markers.'
    }
    # the deliberate exception: COM_ChangeLevel must stay untouched
    if ($stateAfter -match '(?s)void COM_ChangeLevel\(.*?\n\}' -and $Matches[0].Contains('CL_CoF_StopMP3')) {
        throw 'COM_ChangeLevel must not stop the music: Cry of Fear carries a track across an in-game level transition on purpose.'
    }
    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) {
        throw 'Applied MP3 stop patch cannot be reverse-checked.'
    }
} finally {
    Pop-Location
}
Write-Host "Applied CoF stopmp3-on-transition hook to $source"
