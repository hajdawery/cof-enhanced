param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)

# Cry of Fear: Enhanced window name (patches/cof-window-name.patch, engine
# only). See docs/dev/building.md, "The game's name in Windows".
#
#   * engine/platform/sdl2/vid_sdl2.c: for the cryoffear game folder the
#     window title is "Cry of Fear Enhanced", whatever gameinfo.txt's title
#     says (the installer writes that file from the player's liblist.gam);
#     the title and class read back from the window are logged
#     ("[cof-window] ...", developer).
#   * engine/platform/sdl2/sys_sdl2.c: with -game cryoffear, SDL's window
#     class is registered as "CryOfFearEnhanced" instead of "SDL_app".
#
# No ordering constraint inside the engine stack (upstream lines only); it
# sits after apply-cof-client-enter-hook.ps1 in docs/dev/patch-stack.md.

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
$vidRel = 'engine\platform\sdl2\vid_sdl2.c'
$sysRel = 'engine\platform\sdl2\sys_sdl2.c'
foreach ($relative in @($vidRel, $sysRel)) {
    if (!(Test-Path -LiteralPath (Join-Path $source $relative))) {
        throw "Not an FWGS source tree: $(Join-Path $source $relative)"
    }
}
$patch = Join-Path $root 'patches\cof-window-name.patch'
if (!(Test-Path -LiteralPath $patch -PathType Leaf)) { throw "Missing patch: $patch" }

function Slurp([string] $rel) { Get-Content -Raw -LiteralPath (Join-Path $source $rel) }

$vid = Slurp $vidRel
$sys = Slurp $sysRel
$present = $vid.Contains('VID_CoF_WindowTitle') -or $sys.Contains('CryOfFearEnhanced')

if ($Reverse) {
    if (-not $present) { throw 'The window name patch is not present in this source tree; nothing to reverse.' }
} else {
    if ($present) { throw 'The window name patch is already present; use -Reverse first or provide a clean tree.' }
    if (-not $vid.Contains('host.hWnd = SDL_CreateWindow( GI->title, rect.x, rect.y, rect.w, rect.h, flags );') -or
        -not $sys.Contains('if( SDL_Init( SDL_INIT_TIMER | SDL_INIT_VIDEO | SDL_INIT_EVENTS ) )')) {
        throw 'Unexpected vid_sdl2.c / sys_sdl2.c: not the pinned FWGS commit?'
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

    $vid = Slurp $vidRel
    $sys = Slurp $sysRel

    if ($Reverse) {
        if ($vid.Contains('VID_CoF_') -or $sys.Contains('CryOfFearEnhanced')) { throw 'Reversed, but window name markers remain. Inspect the tree.' }
        if (-not $vid.Contains('host.hWnd = SDL_CreateWindow( GI->title,')) { throw 'Reverse application damaged vid_sdl2.c.' }
        Write-Host "Reversed patches\cof-window-name.patch in $source"
        return
    }

    $ok = $vid.Contains('#define COF_WINDOW_TITLE "Cry of Fear Enhanced"') -and
          $vid.Contains('host.hWnd = SDL_CreateWindow( VID_CoF_WindowTitle( ), rect.x, rect.y, rect.w, rect.h, flags );') -and
          $vid.Contains('VID_CoF_ReportWindow( host.hWnd );') -and
          $sys.Contains('SDL_RegisterApp( "CryOfFearEnhanced", 0x1000 | 0x0020, NULL );')
    if (-not $ok) { throw 'Applied, but the window name markers are missing. Inspect the tree.' }

    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Applied window name patch cannot be reverse-checked.' }
} finally {
    Pop-Location
}
Write-Host "Applied patches\cof-window-name.patch in $source"
Write-Host 'Build: python waf build --targets=xash'
