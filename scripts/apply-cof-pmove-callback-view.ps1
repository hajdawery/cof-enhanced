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
    'engine\server\sv_pmove.c',
    'engine\client\dll_int\cl_pmove.c'
)
$patch = Join-Path $root 'patches\cof-pmove-callback-view.patch'

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

$sv = Slurp 'engine\server\sv_pmove.c'
$cl = Slurp 'engine\client\dll_int\cl_pmove.c'
$present = $sv.Contains('SV_CoF_SyncLegacyToNative') -or $cl.Contains('CL_CoF_SyncLegacyToNative')

if ($Reverse) {
    if (-not $present) {
        throw 'The CoF playermove callback view is not present in this source tree; nothing to reverse.'
    }
} else {
    if ($present) {
        throw 'The CoF playermove callback view is already present; use a clean patched source tree.'
    }
    # Prerequisites: this patch only edits the two adapter files, and every hunk
    # is anchored either inside the adapter helpers or on a stock pmove callback.
    if (-not $sv.Contains('COF_PMOVE_LEGACY_SHIFT')) {
        throw 'Apply patches\cof-pmove-legacy.patch first (scripts\apply-pmove-adapter.ps1): this patch edits the server playermove adapter it adds. Note that cof-fix\pristine-clean already carries it.'
    }
    if (-not $cl.Contains('COF_CLIENT_PMOVE_LEGACY_SHIFT')) {
        throw 'Apply scripts\apply-cof-client-pmove-profile.ps1 first: this patch edits the client playermove adapter it adds.'
    }
    # The boundary hunks replace the historical offsetof(physinfo) in all four
    # copy helpers; if they are not there the adapter is not the shipped one.
    if (-not $sv.Contains('const size_t tail = offsetof( playermove_t, physinfo );')) {
        throw 'engine\server\sv_pmove.c does not carry the adapter''s offsetof( playermove_t, physinfo ) boundary; something else already rewrote it.'
    }
    if (-not $cl.Contains('const size_t tail = offsetof( playermove_t, physinfo );')) {
        throw 'engine\client\dll_int\cl_pmove.c does not carry the adapter''s offsetof( playermove_t, physinfo ) boundary; something else already rewrote it.'
    }
    # The callback hunks are anchored on the stock pmove callbacks.
    if (-not $sv.Contains('static int GAME_EXPORT pfnTestPlayerPosition( float *pos, pmtrace_t *ptrace )')) {
        throw 'engine\server\sv_pmove.c does not carry the stock pmove callbacks this patch anchors on.'
    }
    if (-not $cl.Contains('static pmtrace_t GAME_EXPORT pfnPlayerTrace( float *start, float *end, int traceFlags, int ignore_pe )')) {
        throw 'engine\client\dll_int\cl_pmove.c does not carry the stock pmove callbacks this patch anchors on.'
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

    $svAfter = Slurp 'engine\server\sv_pmove.c'
    $clAfter = Slurp 'engine\client\dll_int\cl_pmove.c'

    if ($Reverse) {
        $gone = -not $svAfter.Contains('SV_CoF_SyncLegacyToNative') -and
                -not $svAfter.Contains('cof_pmove_legacy_hullsync') -and
                -not $svAfter.Contains('SV_CoF_LegacyTail') -and
                -not $clAfter.Contains('CL_CoF_SyncLegacyToNative') -and
                -not $clAfter.Contains('cof_pmove_legacy_hullsync_cl') -and
                -not $clAfter.Contains('CL_CoF_LegacyTail')
        if (-not $gone) { throw 'Reverse left playermove callback-view markers behind.' }
        if (-not $svAfter.Contains('const size_t tail = offsetof( playermove_t, physinfo );') -or
            -not $clAfter.Contains('const size_t tail = offsetof( playermove_t, physinfo );')) {
            throw 'Reverse did not restore the adapter''s historical physinfo boundary.'
        }
        Write-Host "Reversed the CoF playermove callback view in $source"
        return
    }

    # (a) the live view the engine callbacks read
    $mirror = $svAfter.Contains('static void SV_CoF_SyncLegacyToNative( void )') -and
              $svAfter.Contains('svgame.pmove->usehull = legacy->usehull;') -and
              $svAfter.Contains('VectorCopy( legacy->origin, svgame.pmove->origin );') -and
              $svAfter.Contains('VectorCopy( legacy->velocity, svgame.pmove->velocity );') -and
              $svAfter.Contains('static playermove_t *cof_pmove_legacy_active;') -and
              $svAfter.Contains('cof_pmove_legacy_active = SV_CoF_LegacyPMove();') -and
              $svAfter.Contains('cof_pmove_legacy_active = NULL;') -and
              $clAfter.Contains('static void CL_CoF_SyncLegacyToNative( void )') -and
              $clAfter.Contains('clgame.pmove->usehull = legacy->usehull;') -and
              $clAfter.Contains('cof_client_pmove_legacy_active = CL_CoF_LegacyPMove();')
    if (-not $mirror) { throw 'Patch command completed without the expected callback-mirror markers.' }

    # every engine pmove callback that reads the pmove object must mirror first
    $svSites = ([regex]::Matches($svAfter, 'SV_CoF_SyncLegacyToNative\(\);')).Count
    $clSites = ([regex]::Matches($clAfter, 'CL_CoF_SyncLegacyToNative\(\);')).Count
    if ($svSites -ne 13) { throw "Expected 13 server callback mirror sites, found $svSites." }
    if ($clSites -ne 8)  { throw "Expected 8 client callback mirror sites, found $clSites." }

    # (b) the corrected shift boundary
    $boundary = $svAfter.Contains('static size_t SV_CoF_LegacyTail( void )') -and
                $svAfter.Contains('offsetof( playermove_t, numtouch ) : offsetof( playermove_t, physinfo )') -and
                $svAfter.Contains('const size_t tail = SV_CoF_LegacyTail();') -and
                $clAfter.Contains('static size_t CL_CoF_LegacyTail( void )') -and
                $clAfter.Contains('const size_t tail = CL_CoF_LegacyTail();')
    if (-not $boundary) { throw 'Patch command completed without the corrected shift-boundary markers.' }
    if ($svAfter.Contains('const size_t tail = offsetof( playermove_t, physinfo );') -or
        $clAfter.Contains('const size_t tail = offsetof( playermove_t, physinfo );')) {
        throw 'A copy helper still hard-codes the historical physinfo boundary.'
    }

    # both cvars default on, in both halves
    $cvars = $svAfter.Contains('CVAR_DEFINE_AUTO( cof_pmove_legacy_hullsync, "1"') -and
             $svAfter.Contains('CVAR_DEFINE_AUTO( cof_pmove_legacy_touchfix, "1"') -and
             $clAfter.Contains('CVAR_DEFINE_AUTO( cof_pmove_legacy_hullsync_cl, "1"') -and
             $clAfter.Contains('CVAR_DEFINE_AUTO( cof_pmove_legacy_touchfix_cl, "1"')
    if (-not $cvars) { throw 'The four adapter cvars are not all present and defaulted on.' }

    # the boundary must stay latched: the game DLL keeps the PM_Init pointer,
    # so flipping it mid-session would hand the DLL a differently shaped view
    if ($svAfter -notmatch 'cof_pmove_legacy_touchfix_latched = cof_pmove_legacy_touchfix\.value') {
        throw 'The server shift boundary is not latched at SV_InitClientMove.'
    }
    if ($clAfter -notmatch 'cof_client_pmove_touchfix_latched = cof_pmove_legacy_touchfix_cl\.value') {
        throw 'The client shift boundary is not latched at CL_InitClientMove.'
    }

    & git @('apply','--ignore-whitespace','--reverse','--check',"--directory=$relativeSource", '--', $patch)
    if ($LASTEXITCODE -ne 0) {
        throw 'Applied playermove callback-view patch cannot be reverse-checked.'
    }
} finally {
    Pop-Location
}
Write-Host "Applied the CoF playermove callback view and corrected shift boundary to $source"
