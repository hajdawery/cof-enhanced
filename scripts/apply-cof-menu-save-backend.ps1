param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!(Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "SourceRoot must be an existing directory: $SourceRoot"
}
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
$projectPrefix = $projectRoot.TrimEnd('\') + '\'
if (-not $source.StartsWith($projectPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}

$files = @{
    Save = Join-Path $source 'engine\server\sv_save.c'
    Commands = Join-Path $source 'engine\server\sv_cmds.c'
    Header = Join-Path $source 'engine\server\server.h'
    GameUi = Join-Path $source 'engine\client\dll_int\cl_gameui.c'
}
foreach($path in $files.Values) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing FWGS source file: $path"
    }
}

$saveText = Get-Content -Raw -LiteralPath $files.Save
$commandsText = Get-Content -Raw -LiteralPath $files.Commands
$headerText = Get-Content -Raw -LiteralPath $files.Header
$gameUiText = Get-Content -Raw -LiteralPath $files.GameUi
$patch = Join-Path $projectRoot 'patches\cof-menu-save-backend.patch'
if (!(Test-Path -LiteralPath $patch -PathType Leaf)) { throw "Missing patch: $patch" }

if (-not $saveText.Contains('SV_CoFRootSaveCompat') -or
    -not $saveText.Contains('SV_SaveFSOpen') -or
    -not $gameUiText.Contains('cof_root_save_list')) {
    throw 'Expected the root-save and pause-save plumbing markers; apply those patches first.'
}
$menuMarker = 'Menu saves share CoF''s five slots, but never enter the tape-use path.'
if ($Reverse) {
    if (-not $saveText.Contains($menuMarker) -or
        -not $saveText.Contains('cofMenuSaveTracking') -or
        -not $commandsText.Contains('cof_menu_save') -or
        -not $headerText.Contains('SV_CoFMenuSave')) {
        throw 'Menu-save backend markers are absent; refusing reverse application.'
    }
} else {
    if ($saveText.Contains($menuMarker) -or
        $saveText.Contains('cofMenuSaveTracking') -or
        $commandsText.Contains('cof_menu_save') -or
        $headerText.Contains('SV_CoFMenuSave')) {
        throw 'Menu-save backend is already present; use -Reverse first or provide a clean source tree.'
    }
}

Push-Location $projectRoot
try {
    $relativeSource = $source.Substring($projectPrefix.Length).Replace('\','/')
    if ($Reverse) {
        & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
        if ($LASTEXITCODE -ne 0) { throw 'Reverse check failed.' }
        & git apply --ignore-whitespace --reverse --directory=$relativeSource -- $patch
        if ($LASTEXITCODE -ne 0) { throw 'Reverse application failed.' }
    } else {
        & git apply --ignore-whitespace --check --directory=$relativeSource -- $patch
        if ($LASTEXITCODE -ne 0) { throw 'Forward check failed.' }
        & git apply --ignore-whitespace --directory=$relativeSource -- $patch
        if ($LASTEXITCODE -ne 0) { throw 'Forward application failed.' }
    }
} finally {
    Pop-Location
}

$saveAfter = Get-Content -Raw -LiteralPath $files.Save
$commandsAfter = Get-Content -Raw -LiteralPath $files.Commands
$headerAfter = Get-Content -Raw -LiteralPath $files.Header
if ($Reverse) {
    if ($saveAfter.Contains($menuMarker) -or $saveAfter.Contains('cofMenuSaveTracking') -or
        $commandsAfter.Contains('cof_menu_save') -or $headerAfter.Contains('SV_CoFMenuSave')) {
        throw 'Reverse application completed without removing all menu-save markers.'
    }
    Write-Host "Reversed CoF menu-save backend in $source"
} else {
    if (-not $saveAfter.Contains($menuMarker) -or -not $saveAfter.Contains('cofMenuSaveTracking') -or
        -not $commandsAfter.Contains('cof_menu_save') -or -not $headerAfter.Contains('SV_CoFMenuSave')) {
        throw 'Forward application completed without the expected menu-save markers.'
    }
    Write-Host "Applied CoF menu-save backend in $source"
}
