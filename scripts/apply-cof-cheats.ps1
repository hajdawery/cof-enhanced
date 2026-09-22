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
    'engine\server\sv_client.c',
    'engine\server\sv_pmove.c',
    'engine\common\zone.c',
    'engine\common\common.h'
)
$newFiles = @(
    'engine\server\sv_cof_cheats.c',
    'engine\server\sv_cof_cheats.h'
)
$patch = Join-Path $root 'patches\cof-cheats.patch'

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

$cl   = Slurp 'engine\server\sv_client.c'
$pm   = Slurp 'engine\server\sv_pmove.c'
$zone = Slurp 'engine\common\zone.c'
$hdr  = Slurp 'engine\common\common.h'
$present = $cl.Contains('SV_CoF_CheatsClientCommand') -or $pm.Contains('SV_CoF_CheatsPostThink') -or
           $zone.Contains('Mem_AllocatedSize') -or
           (Test-Path -LiteralPath (Join-Path $source 'engine\server\sv_cof_cheats.c'))

if ($Reverse) {
    if (-not $present) {
        throw 'The Cry of Fear cheats are not present in this source tree; nothing to reverse.'
    }
} else {
    if ($present) {
        throw 'The Cry of Fear cheats are already present; use a clean patched source tree.'
    }
    # The command hook sits right after the menu-load trace's cofload lines in
    # SV_ExecuteClientCommand, which it uses as hunk context.
    if (-not $cl.Contains('[cof-trace] server received cofload %s client_state=%d server_state=%d')) {
        throw 'Apply patches\cof-menu-load-trace.patch first (scripts\apply-cof-menu-load-trace.ps1): this patch hooks SV_ExecuteClientCommand next to its cofload trace.'
    }
    if (-not $cl.Contains('static void SV_ExecuteClientCommand( sv_client_t *cl, const char *s )')) {
        throw 'engine\server\sv_client.c does not carry the stock SV_ExecuteClientCommand this patch hooks.'
    }
    # The per-frame hook goes between the game DLL's PlayerPostThink and CmdEnd.
    if ($pm -notmatch 'svgame\.dllFuncs\.pfnPlayerPostThink\( clent \);\r?\n\tsvgame\.dllFuncs\.pfnCmdEnd\( clent \);') {
        throw 'engine\server\sv_pmove.c does not carry the stock PlayerPostThink/CmdEnd pair in SV_RunCmd.'
    }
    if (-not $zone.Contains('qboolean Mem_IsAllocatedExt( poolhandle_t poolptr, void *data )') -or
        -not $hdr.Contains('qboolean Mem_IsAllocatedExt( poolhandle_t poolptr, void *data );')) {
        throw 'engine\common\zone.c / common.h do not carry the stock Mem_IsAllocatedExt this patch sits next to.'
    }
    # Every write assumes the Cry of Fear entvars layout; the new file refuses
    # to enable itself without it, but a tree without the profile is the wrong
    # tree to put this on.
    $progdefs = Slurp 'engine\progdefs.h'
    if (-not $progdefs.Contains('cof_legacy_unknown_0')) {
        throw 'Apply scripts\apply-cof-entvars-profile.ps1 first: the cheats read and write the Cry of Fear entvars layout.'
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

    $clAfter   = Slurp 'engine\server\sv_client.c'
    $pmAfter   = Slurp 'engine\server\sv_pmove.c'
    $zoneAfter = Slurp 'engine\common\zone.c'
    $hdrAfter  = Slurp 'engine\common\common.h'

    if ($Reverse) {
        $gone = -not $clAfter.Contains('SV_CoF_CheatsClientCommand') -and
                -not $clAfter.Contains('sv_cof_cheats.h') -and
                -not $pmAfter.Contains('SV_CoF_CheatsPostThink') -and
                -not $pmAfter.Contains('sv_cof_cheats.h') -and
                -not $zoneAfter.Contains('Mem_AllocatedSize') -and
                -not $hdrAfter.Contains('Mem_AllocatedSize')
        foreach ($f in $newFiles) {
            if (Test-Path -LiteralPath (Join-Path $source $f)) { $gone = $false }
        }
        if (-not $gone) { throw 'Reverse left Cry of Fear cheat markers behind.' }
        Write-Host "Reversed the Cry of Fear cheats in $source"
        return
    }

    foreach ($f in $newFiles) {
        if (!(Test-Path -LiteralPath (Join-Path $source $f))) { throw "Patch command completed without creating $f." }
    }
    $impl = Slurp 'engine\server\sv_cof_cheats.c'

    # (a) the two hooks and the allocation-size helper
    $hooks = $clAfter.Contains('#include "sv_cof_cheats.h"') -and
             $clAfter.Contains('if( SV_CoF_CheatsClientCommand( cl ))') -and
             $pmAfter.Contains('#include "sv_cof_cheats.h"') -and
             $pmAfter.Contains('SV_CoF_CheatsPostThink( cl );') -and
             $zoneAfter.Contains('size_t Mem_AllocatedSize( poolhandle_t poolptr, void *data )') -and
             $hdrAfter.Contains('size_t Mem_AllocatedSize( poolhandle_t poolptr, void *data );')
    if (-not $hooks) { throw 'Patch command completed without the expected hook markers.' }

    # the command hook must run BEFORE the stock user commands (noclip/notarget
    # are ucmds) and the frame hook right AFTER PlayerPostThink
    $iHook = $clAfter.IndexOf('if( SV_CoF_CheatsClientCommand( cl ))')
    $iUcmd = $clAfter.IndexOf('for( i = 0; i < ARRAYSIZE( ucmds ); i++ )')
    if ($iHook -lt 0 -or $iUcmd -lt 0 -or $iHook -gt $iUcmd) { throw 'The command hook does not precede the stock ucmd dispatch.' }
    if ($pmAfter -notmatch 'pfnPlayerPostThink\( clent \);\r?\n\tSV_CoF_CheatsPostThink\( cl \);[^\n]*\r?\n\tsvgame\.dllFuncs\.pfnCmdEnd\( clent \);') {
        throw 'The frame hook is not between PlayerPostThink and CmdEnd.'
    }

    # (b) the gate: retail 1.6 hl.dll hash, sv_cheats, and no test override
    $gate = $impl.Contains('0036b91c01e92ed205513f52563053a55a66a32d257efb5f476b8f1f3dde0e63') -and
            $impl.Contains('Cvar_VariableInteger( "sv_cheats" )') -and
            $impl.Contains('STATIC_ASSERT( offsetof( entvars_t, air_finished ) == 0x200')
    if (-not $gate) { throw 'The cheats implementation does not carry its hash / sv_cheats / layout gate.' }
    if ($impl.Contains('cof_cheats_test_expect') -or $impl.Contains('TEST BUILD ONLY')) {
        throw 'The cheats implementation carries the test-only hash override; this patch must never ship it.'
    }

    # (c) every command the docs promise
    foreach ($c in @('"noclip"','"notarget"','"fly"','"give"','"cof_infammo"','"cof_infstamina"','"cof_ending"',
                     '"cof_nodamage"','"cof_nodrown"','"cof_nightvision"','"cof_unlockdoors"','"cof_tapes"','"cof_cheats"')) {
        if (-not $impl.Contains($c)) { throw "The cheats implementation does not handle $c." }
    }

    & git @('apply','--ignore-whitespace','--reverse','--check',"--directory=$relativeSource", '--', $patch)
    if ($LASTEXITCODE -ne 0) {
        throw 'Applied Cry of Fear cheats patch cannot be reverse-checked.'
    }
} finally {
    Pop-Location
}
Write-Host "Applied the Cry of Fear cheats to $source"
