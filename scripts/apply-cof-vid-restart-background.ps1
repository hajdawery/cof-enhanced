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
    'engine\client\client.h',
    'engine\client\vid_common.c'
)
$patch = Join-Path $root 'patches\cof-vid-restart-background.patch'

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

$main = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\cl_main.c')
$header = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\client.h')
$vid = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\vid_common.c')

if ($main.Contains('cof_vid_restart_background') -or $header.Contains('CL_CoF_VidModeChanged') -or
    $vid.Contains('CL_CoF_VidModeChanged')) {
    throw 'The CoF video-mode background restart is already present; use a clean patched source tree.'
}
# prerequisite: this patch hangs its cvars off the unified UI gate block and its
# hunk context is the gate's own cvar lines, so the gate has to be there first
if (-not ($main.Contains('CVAR_DEFINE_AUTO( cof_ui_deferred_cmd_guard, "1"') -and
          $header.Contains('qboolean CL_CoF_UIGateActive( void );'))) {
    throw 'Apply scripts\apply-cof-ui-input-gate.ps1 first: this patch builds on the unified UI input gate.'
}

Push-Location $root
try {
    $relativeSource = $source.Substring($rootPrefix.Length).Replace('\','/')
    & git apply --ignore-whitespace --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Patch does not apply cleanly to this source tree.' }
    & git apply --ignore-whitespace --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'git apply failed.' }

    $mainAfter   = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\cl_main.c')
    $headerAfter = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\client.h')
    $vidAfter    = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\vid_common.c')

    $present = $mainAfter.Contains('CVAR_DEFINE_AUTO( cof_vid_restart_background, "1"') -and
               $mainAfter.Contains('CVAR_DEFINE_AUTO( cof_vid_skip_redundant_vidinit, "0"') -and
               $mainAfter.Contains('Cvar_RegisterVariable( &cof_vid_restart_background )') -and
               $mainAfter.Contains('Cvar_RegisterVariable( &cof_vid_skip_redundant_vidinit )') -and
               $mainAfter.Contains('void CL_CoF_VidModeChanged( void )') -and
               $mainAfter.Contains('void CL_CoF_VidRestartForget( void )') -and
               $mainAfter.Contains('Cbuf_AddTextf( "map_background %s\n", clgame.mapname )') -and
               $mainAfter.Contains('CL_CoF_VidRestartForget();') -and
               $headerAfter.Contains('extern convar_t cof_vid_restart_background;') -and
               $headerAfter.Contains('extern convar_t cof_vid_skip_redundant_vidinit;') -and
               $headerAfter.Contains('void CL_CoF_VidModeChanged( void );') -and
               $vidAfter.Contains('CL_CoF_VidModeChanged();') -and
               $vidAfter.Contains('skipped the redundant client VidInit')
    if (-not $present) {
        throw 'Patch command completed without the expected video-mode restart markers.'
    }
    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) {
        throw 'Applied video-mode background restart patch cannot be reverse-checked.'
    }
} finally {
    Pop-Location
}
Write-Host "Applied CoF video-mode background restart to $source"
