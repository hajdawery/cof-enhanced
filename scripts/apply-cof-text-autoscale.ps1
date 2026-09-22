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
    'engine\client\console.c',
    'engine\client\cl_scrn.c',
    'engine\client\cl_netgraph.c',
    'engine\common\imagelib\img_wad.c'
)
$patch = Join-Path $root 'patches\cof-text-autoscale.patch'

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

$console  = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\console.c')
$scrn     = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\cl_scrn.c')
$netgraph = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\cl_netgraph.c')
$imgwad   = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\common\imagelib\img_wad.c')

if ($console.Contains('cof_text_autoscale') -or $netgraph.Contains('cof_text_autoscale') -or
    $imgwad.Contains('identity grey ramp')) {
    throw 'The CoF text autoscale is already present; use a clean patched source tree.'
}
# prerequisite: the size derivation is applied on top of the Source-style
# console, whose layout function supplies the wrap width and whose title band
# hunk is patched here as well
if (-not $console.Contains('static qboolean Con_DrawStyledConsole( int lines )')) {
    throw 'Apply scripts\apply-cof-console-style.ps1 first: this patch builds on the Source-style console window.'
}
# and that one in turn sits on the variable-width console font fallback
if (-not $console.Contains('// Some mods provide a variable-width console font in gfx.wad.')) {
    throw 'Apply scripts\apply-cof-console-variable-font-fallback.ps1 first.'
}
# the death flow adds the Con_ToggleConsole_f lines this patch uses as hunk
# context further down console.c, so it has to be in place as well. Note the
# real stack order is: styled console FIRST, then the death flow, then this.
if (-not $console.Contains('CL_CoF_DeathMenuActive')) {
    throw 'Apply scripts\apply-cof-ui-death-flow.ps1 first: this patch uses its console.c lines as hunk context.'
}

Push-Location $root
try {
    $relativeSource = $source.Substring($rootPrefix.Length).Replace('\','/')
    & git apply --ignore-whitespace --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Patch does not apply cleanly to this source tree.' }
    & git apply --ignore-whitespace --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'git apply failed.' }

    $consoleAfter  = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\console.c')
    $scrnAfter     = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\cl_scrn.c')
    $netgraphAfter = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\cl_netgraph.c')
    $imgwadAfter   = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\common\imagelib\img_wad.c')

    $present = $consoleAfter.Contains('CVAR_DEFINE_AUTO( cof_text_autoscale, "1"') -and
               $consoleAfter.Contains('CVAR_DEFINE_AUTO( cof_text_height_pct, "1.7"') -and
               $consoleAfter.Contains('CVAR_DEFINE_AUTO( cof_text_font, "1"') -and
               $consoleAfter.Contains('Cvar_RegisterVariable( &cof_text_autoscale )') -and
               $consoleAfter.Contains('Cvar_RegisterVariable( &cof_text_height_pct )') -and
               $consoleAfter.Contains('Cvar_RegisterVariable( &cof_text_font )') -and
               $consoleAfter.Contains('static float Con_TextTargetHeight( void )') -and
               $consoleAfter.Contains('static void Con_ScaleConsoleFont( cl_font_t *font, int base, float target )') -and
               $consoleAfter.Contains('static void Con_CheckTextScale( void )') -and
               $consoleAfter.Contains('static int Con_StyleLogWidth( void )') -and
               $consoleAfter.Contains('"fonts/cof_console%i.fnt"') -and
               $consoleAfter.Contains('ClearBits( texFlags, TF_NEAREST )') -and
               $scrnAfter.Contains('CL_DrawStringLen( font, msg, &width, NULL, FONT_DRAW_RESETCOLORONLF )') -and
               $netgraphAfter.Contains('int		rows = ( graphtype > 2 ) ? 4 : 3;') -and
               $netgraphAfter.Contains('ty = Q_min( ty, refState.height - charH - row * ( rows - 1 ));') -and
               $imgwadAfter.Contains('Image_GetPaletteLMP( pal, ramp ? LUMP_GRADIENT : LUMP_MASKED )')
    if (-not $present) {
        throw 'Patch command completed without the expected text autoscale markers.'
    }
    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) {
        throw 'Applied text autoscale patch cannot be reverse-checked.'
    }
} finally {
    Pop-Location
}
Write-Host "Applied CoF console/overlay text autoscale to $source"
Write-Host 'Remember: the generated atlases in gamedata\cryoffear\fonts must be copied into the game directory, or cof_text_font falls back to the game CONCHARS.'
