param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)

# Cry of Fear Enter hook (patches/cof-client-enter-hook.patch, engine only).
# See docs/design/osk.md, "The Enter hook".
#
#   * engine/client/cof_enter_hook.c (new): client.dll's
#     USER32!GetAsyncKeyState import is pointed at CoF_Enter_GetAsyncKeyState
#     (the computer login, 1003F54C, and the Press Enter cards, 1003D21E, ask
#     Windows for VK_RETURN directly). It answers Enter as pressed for one
#     frame of polls after cof_enter_pulse (the on-screen keyboard's Done), or
#     after a gamepad START while the game is polling for Enter (that START
#     goes nowhere else; cof_enter_pad, saved, 1), or while +cof_enter is held;
#     a real Enter is hidden from the game while the menu or the console owns
#     the keyboard. cof_enter_status, cof_enter_trace.
#   * engine/client/dll_int/cl_game.c: installed next to the language packs'
#     CreateFileW hook, right after client.dll is loaded.
#   * engine/client/input/in_keys.c, client.h: the Key_Event (START) and
#     Key_Init hooks, declarations.
#
# Goes on after apply-cof-osk-engine.ps1 (whose Key_Event and client.h lines
# it sits next to) and the language packs (42).

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!(Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "SourceRoot must be an existing directory: $SourceRoot"
}
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
$rootPrefix = $root.TrimEnd('\') + '\'
if (-not $source.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}
$targets = @(
    'engine\client\client.h',
    'engine\client\input\in_keys.c',
    'engine\client\dll_int\cl_game.c'
)
$newFile = 'engine\client\cof_enter_hook.c'
foreach ($relative in $targets) {
    if (!(Test-Path -LiteralPath (Join-Path $source $relative))) {
        throw "Not an FWGS source tree: $(Join-Path $source $relative)"
    }
}
$patch = Join-Path $root 'patches\cof-client-enter-hook.patch'
if (!(Test-Path -LiteralPath $patch -PathType Leaf)) { throw "Missing patch: $patch" }

function Slurp([string] $rel) { Get-Content -Raw -LiteralPath (Join-Path $source $rel) }
function Exists([string] $rel) { Test-Path -LiteralPath (Join-Path $source $rel) }

$cl   = Slurp 'engine\client\client.h'
$keys = Slurp 'engine\client\input\in_keys.c'
$game = Slurp 'engine\client\dll_int\cl_game.c'

$present = $cl.Contains('CL_CoF_EnterInit') -or $keys.Contains('CL_CoF_EnterKeyEvent') -or $game.Contains('CL_CoF_EnterHookModule') -or (Exists $newFile)

if ($Reverse) {
    if (-not $present) { throw 'The Enter hook is not present in this source tree; nothing to reverse.' }
} else {
    if ($present) { throw 'The Enter hook is already present; use -Reverse first or provide a clean patched tree.' }
    if (-not $game.Contains('CoF_Lang_HookModule( clgame.hInstance, name );')) {
        throw 'Prerequisite missing: apply scripts\apply-cof-language-packs.ps1 first.'
    }
    if (-not $keys.Contains('CL_CoF_OskNoteKey( key, down );') -or -not $cl.Contains('int VGui_CoF_OskCall( int op, char *buf, int size );')) {
        throw 'Prerequisite missing: apply scripts\apply-cof-osk-engine.ps1 first.'
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

    $cl   = Slurp 'engine\client\client.h'
    $keys = Slurp 'engine\client\input\in_keys.c'
    $game = Slurp 'engine\client\dll_int\cl_game.c'

    if ($Reverse) {
        if ($cl.Contains('CL_CoF_Enter') -or $keys.Contains('CL_CoF_Enter') -or $game.Contains('CL_CoF_Enter') -or (Exists $newFile)) {
            throw 'Reversed, but Enter hook markers remain. Inspect the tree.'
        }
        if (-not $keys.Contains('CL_CoF_OskNoteKey( key, down );')) { throw 'Reverse application damaged the patches this one sits on.' }
        Write-Host "Reversed patches\cof-client-enter-hook.patch in $source"
        return
    }

    if (-not (Exists $newFile)) { throw "Applied, but $newFile was not created. Inspect the tree." }
    $hook = Slurp $newFile

    $ok = $cl.Contains('qboolean CL_CoF_EnterKeyEvent( int key, int down );') -and
          $keys.Contains('if( CL_CoF_EnterKeyEvent( key, down ))') -and $keys.Contains('CL_CoF_EnterInit();') -and
          $game.Contains('CL_CoF_EnterHookModule( clgame.hInstance, name );') -and
          $hook.Contains('static SHORT WINAPI CoF_Enter_GetAsyncKeyState( int vkey )') -and
          $hook.Contains('"GetAsyncKeyState"') -and
          $hook.Contains('static CVAR_DEFINE_AUTO( cof_enter_pad, "1", FCVAR_ARCHIVE,') -and
          $hook.Contains('Cmd_AddCommand( "cof_enter_pulse", CL_CoF_EnterPulse_f,')
    if (-not $ok) { throw 'Applied, but the Enter hook markers are missing. Inspect the tree.' }

    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Applied Enter hook patch cannot be reverse-checked.' }
} finally {
    Pop-Location
}
Write-Host "Applied patches\cof-client-enter-hook.patch in $source"
Write-Host 'Build: python waf build --targets=xash'
