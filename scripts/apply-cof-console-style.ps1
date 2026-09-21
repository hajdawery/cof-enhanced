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
    'engine\client\client.h',
    'engine\client\input\input.c'
)
$patch = Join-Path $root 'patches\cof-console-style.patch'

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

$console = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\console.c')
$header  = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\client.h')
$input   = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\input\input.c')

if ($console.Contains('cof_console_style') -or $header.Contains('void Con_MouseMove(') -or
    $input.Contains('Con_MouseMove( x, y )')) {
    throw 'The CoF styled console is already present; use a clean patched source tree.'
}
# prerequisite: the styled console's font hunks sit on top of the variable-width
# console font fallback, and that fallback is what makes CoF's gfx.wad CONCHARS
# load as an FNT atlas in the first place
if (-not $console.Contains('// Some mods provide a variable-width console font in gfx.wad.')) {
    throw 'Apply scripts\apply-cof-console-variable-font-fallback.ps1 first: this patch builds on the console variable-width font fallback.'
}

Push-Location $root
try {
    $relativeSource = $source.Substring($rootPrefix.Length).Replace('\','/')
    & git apply --ignore-whitespace --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Patch does not apply cleanly to this source tree.' }
    & git apply --ignore-whitespace --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'git apply failed.' }

    $consoleAfter = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\console.c')
    $headerAfter  = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\client.h')
    $inputAfter   = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\client\input\input.c')

    $present = $consoleAfter.Contains('CVAR_DEFINE_AUTO( cof_console_style, "1"') -and
               $consoleAfter.Contains('CVAR_DEFINE_AUTO( cof_console_font_grayscale, "1"') -and
               $consoleAfter.Contains('Cvar_RegisterVariable( &cof_console_style )') -and
               $consoleAfter.Contains('Cvar_RegisterVariable( &cof_console_font_grayscale )') -and
               $consoleAfter.Contains('static qboolean Con_DrawStyledConsole( int lines )') -and
               $consoleAfter.Contains('static qboolean Con_StyleLayout( constyle_t *r )') -and
               $consoleAfter.Contains('static int Con_DrawStringClipped(') -and
               $consoleAfter.Contains('static void Con_DrawStyledInput(') -and
               $consoleAfter.Contains('if( Con_StyleEnabled() && Con_DrawStyledConsole( lines ))') -and
               $consoleAfter.Contains('SetBits( texFlags, TF_LUMINANCE )') -and
               $consoleAfter.Contains('void Con_MouseMove( int x, int y )') -and
               $consoleAfter.Contains('key == K_MOUSE1 && Con_StyleCloseHit(') -and
               $headerAfter.Contains('void Con_MouseMove( int x, int y );') -and
               $inputAfter.Contains('Con_MouseMove( x, y );')
    if (-not $present) {
        throw 'Patch command completed without the expected styled console markers.'
    }
    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) {
        throw 'Applied styled console patch cannot be reverse-checked.'
    }
} finally {
    Pop-Location
}
Write-Host "Applied CoF styled console window to $source"
