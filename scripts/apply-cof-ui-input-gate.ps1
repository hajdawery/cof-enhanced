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
    'engine\client\cl_view.c',
    'engine\client\dll_int\cl_game.c',
    'engine\client\dll_int\cl_gameui.c',
    'engine\client\vgui\vgui_draw.c',
    'engine\client\vgui\vgui_draw.h',
    'engine\client\input\in_keys.c'
)
$patch = Join-Path $root 'patches\cof-ui-input-gate.patch'

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
$header = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\client.h')
$keys   = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\input\in_keys.c')
$vgui   = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\vgui\vgui_draw.c')

$gameui = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\dll_int\cl_gameui.c')

if ($main.Contains('cof_ui_input_gate') -or $header.Contains('CL_CoF_UIGateActive') -or
    $keys.Contains('cof_ui_input_gate') -or $vgui.Contains('VGui_CoF_DeliverKey') -or
    $gameui.Contains('cof_ui_deferred_cmd_guard')) {
    throw 'The CoF unified UI input gate is already present; use a clean patched source tree.'
}
if ($main.Contains('cof_skip_client_hud_redraw') -or $main.Contains('cof_skip_vgui_paint')) {
    throw 'This source tree already carries the untracked cof_skip_* diagnostics; this patch supplies them. Start from a tree without them.'
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
    $keysAfter   = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\input\in_keys.c')
    $vguiAfter   = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\vgui\vgui_draw.c')
    $gameAfter   = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\dll_int\cl_game.c')
    $viewAfter   = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\cl_view.c')
    $gameuiAfter = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\dll_int\cl_gameui.c')

    $present = $mainAfter.Contains('CVAR_DEFINE_AUTO( cof_ui_input_gate, "1"') -and
               $mainAfter.Contains('Cvar_RegisterVariable( &cof_ui_input_gate )') -and
               $mainAfter.Contains('qboolean CL_CoF_UIGateActive( void )') -and
               $headerAfter.Contains('qboolean CL_CoF_UIGateActive( void );') -and
               $keysAfter.Contains('escape routed to the engine') -and
               $vguiAfter.Contains('VGui_CoF_DeliverKey') -and
               $vguiAfter.Contains('vgui_key_delivered') -and
               $gameAfter.Contains('!cof_skip_client_hud_redraw.value && !cof_gate') -and
               $viewAfter.Contains('!cof_skip_vgui_paint.value') -and
               $mainAfter.Contains('CVAR_DEFINE_AUTO( cof_ui_deferred_cmd_guard, "1"') -and
               $mainAfter.Contains('Cvar_RegisterVariable( &cof_ui_deferred_cmd_guard )') -and
               $headerAfter.Contains('extern convar_t cof_ui_deferred_cmd_guard;') -and
               $gameuiAfter.Contains('dropped stale deferred client command')
    if (-not $present) {
        throw 'Patch command completed without the expected unified UI input gate markers.'
    }
    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) {
        throw 'Applied unified UI input gate patch cannot be reverse-checked.'
    }
} finally {
    Pop-Location
}
Write-Host "Applied CoF unified UI input gate to $source"
