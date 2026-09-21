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
    'engine\client\console.c',
    'engine\client\parse\cl_parse.c'
)
$patch = Join-Path $root 'patches\cof-ui-death-flow.patch'

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

$main    = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\cl_main.c')
$header  = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\client.h')
$console = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\console.c')
$clparse = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\parse\cl_parse.c')

$markers = @(
    $main.Contains('cof_ui_death_menu'),
    $main.Contains('CL_CoF_DeathUserMessage'),
    $console.Contains('con_enable'),
    $clparse.Contains('CL_CoF_DeathUserMessage( clgame.msg[i].name')
)

if ($Reverse) {
    if ($markers -contains $false) {
        throw 'CoF death-flow markers are absent; refusing reverse application.'
    }
} else {
    if ($markers -contains $true) {
        throw 'The CoF death flow is already present; use a clean patched source tree.'
    }
    # prerequisite 1: the menu-map redirect. The death page's Exit reuses its
    # return sequence (CL_CoF_MenuMapReturn) and every cl_main.c hunk here sits
    # on the redirect's own lines.
    if (-not ($main.Contains('static CVAR_DEFINE_AUTO( cof_ui_menu_map_redirect, "1"') -and
              $main.Contains('static qboolean CL_CoF_MenuMapReturn( const char *what, const char *source )'))) {
        throw 'Apply scripts\apply-cof-ui-menu-map-redirect.ps1 first: this patch builds on the unified UI menu-map redirect.'
    }
    # prerequisite 2: the unified UI input gate. It is what keeps the client's
    # own GAME OVER panel off the screen while our page is up.
    if (-not $header.Contains('qboolean CL_CoF_UIGateActive( void );')) {
        throw 'Apply scripts\apply-cof-ui-input-gate.ps1 first: the death page relies on the unified UI input gate.'
    }
    # prerequisite 3: the styled console. con_enable is registered next to the
    # cof_console_* family and its Con_Init hunk uses those lines as context.
    if (-not $console.Contains('cof_console_style')) {
        throw 'Apply scripts\apply-cof-console-style.ps1 first: this patch uses its console.c lines as hunk context.'
    }
}

Push-Location $root
try {
    $relativeSource = $source.Substring($rootPrefix.Length).Replace('\','/')
    $common = New-Object System.Collections.ArrayList
    [void]$common.Add('apply')
    [void]$common.Add('--ignore-whitespace')
    if ($Reverse) { [void]$common.Add('--reverse') }
    [void]$common.Add("--directory=$relativeSource")

    $checkArgs = @($common.ToArray()) + @('--check', '--', $patch)
    $applyArgs = @($common.ToArray()) + @('--', $patch)

    & git $checkArgs
    if ($LASTEXITCODE -ne 0) { throw 'Patch does not apply cleanly to this source tree.' }
    & git $applyArgs
    if ($LASTEXITCODE -ne 0) { throw 'git apply failed.' }

    $mainAfter    = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\cl_main.c')
    $headerAfter  = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\client.h')
    $consoleAfter = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\console.c')
    $clparseAfter = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\parse\cl_parse.c')

    $present =
        $mainAfter.Contains('static CVAR_DEFINE_AUTO( cof_ui_death_menu, "1"') -and
        $mainAfter.Contains('Cvar_RegisterVariable( &cof_ui_death_menu );') -and
        $mainAfter.Contains('#define COF_DEATH_USERMSG') -and
        $mainAfter.Contains('#define COF_DEATH_MENU_INDEX	35') -and
        $mainAfter.Contains('qboolean CL_CoF_DeathUserMessage( const char *name, int size, const byte *buf )') -and
        $mainAfter.Contains('void CL_CoF_DeathPump( void )') -and
        $mainAfter.Contains('CL_CoF_DeathForget();') -and
        $mainAfter.Contains('CL_CoF_DeathPump ();') -and
        $mainAfter.Contains('Cmd_AddCommand ("cof_ui_menu_return", CL_CoF_MenuReturn_f') -and
        $mainAfter.Contains('qboolean CL_CoF_DeathMenuActive( void )') -and
        $consoleAfter.Contains('CL_CoF_DeathMenuActive( )') -and
        $headerAfter.Contains('qboolean CL_CoF_DeathUserMessage( const char *name, int size, const byte *buf );') -and
        $consoleAfter.Contains('static CVAR_DEFINE_AUTO( con_enable, "0", FCVAR_ARCHIVE') -and
        $consoleAfter.Contains('static void Con_ApplyEnable( void )') -and
        $consoleAfter.Contains('Cvar_RegisterVariable( &con_enable );') -and
        $clparseAfter.Contains('CL_CoF_DeathUserMessage( clgame.msg[i].name, iSize, pbuf );')

    if ($Reverse) {
        if ($present) { throw 'Reverse application left the death-flow markers behind.' }
        # the redirect this patch builds on must survive a reverse
        if (-not $mainAfter.Contains('static CVAR_DEFINE_AUTO( cof_ui_menu_map_redirect, "1"')) {
            throw 'Reverse application damaged the menu-map redirect patch.'
        }
        if (-not $consoleAfter.Contains('cof_console_style')) {
            throw 'Reverse application damaged the styled-console patch.'
        }
    } else {
        if (-not $present) { throw 'Patch command completed without the expected source markers.' }

        & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
        if ($LASTEXITCODE -ne 0) {
            throw 'Applied death-flow patch cannot be reverse-checked.'
        }
    }
} finally {
    Pop-Location
}

if ($Reverse) {
    Write-Host "Reverted CoF unified UI death flow in $source"
} else {
    Write-Host "Applied CoF unified UI death flow to $source"
}
