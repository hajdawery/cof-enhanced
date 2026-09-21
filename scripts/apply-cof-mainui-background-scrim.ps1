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

$mainui = Join-Path $source '3rdparty\mainui'
$baseMenuFile = Join-Path $mainui 'BaseMenu.cpp'
$baseMenuHeader = Join-Path $mainui 'BaseMenu.h'
$backgroundFile = Join-Path $mainui 'controls\BackgroundBitmap.cpp'
foreach($path in @($mainui, $baseMenuFile, $baseMenuHeader, $backgroundFile)) {
    if (!(Test-Path -LiteralPath $path)) { throw "Missing mainui source path: $path" }
}

$head = (& git -C $mainui rev-parse HEAD 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or $head -ne '61263995592e93a278d764807243d043d3b97c54') {
    throw "mainui must be at pinned baseline 61263995592e93a278d764807243d043d3b97c54; found $head"
}
$baseMenuText = Get-Content -Raw -LiteralPath $baseMenuFile
$headerText = Get-Content -Raw -LiteralPath $baseMenuHeader
$backgroundText = Get-Content -Raw -LiteralPath $backgroundFile
$patch = Join-Path $projectRoot 'patches\cof-mainui-background-scrim.patch'
if (!(Test-Path -LiteralPath $patch -PathType Leaf)) { throw "Missing patch: $patch" }

if ($Reverse) {
    if (-not $baseMenuText.Contains('ui_scrim_alpha') -or
        -not $headerText.Contains('ui_scrim_alpha') -or
        -not $backgroundText.Contains('ui_scrim_alpha')) {
        throw 'MainUI background-scrim markers are absent; refusing reverse application.'
    }
} else {
    if ($baseMenuText.Contains('ui_scrim_alpha') -or
        $headerText.Contains('ui_scrim_alpha') -or
        $backgroundText.Contains('ui_scrim_alpha')) {
        throw 'MainUI background-scrim changes are already present; use -Reverse first or provide a clean baseline.'
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

$baseMenuAfter = Get-Content -Raw -LiteralPath $baseMenuFile
$headerAfter = Get-Content -Raw -LiteralPath $baseMenuHeader
$backgroundAfter = Get-Content -Raw -LiteralPath $backgroundFile
if ($Reverse) {
    if ($baseMenuAfter.Contains('ui_scrim_alpha') -or $headerAfter.Contains('ui_scrim_alpha') -or
        $backgroundAfter.Contains('ui_scrim_alpha')) {
        throw 'Reverse application completed without removing all MainUI background-scrim markers.'
    }
    Write-Host "Reversed CoF MainUI background-scrim change in $mainui"
} else {
    if (-not $baseMenuAfter.Contains('ui_scrim_alpha') -or -not $headerAfter.Contains('ui_scrim_alpha') -or
        -not $backgroundAfter.Contains('ui_scrim_alpha')) {
        throw 'Forward application completed without the expected MainUI background-scrim markers.'
    }
    Write-Host "Applied CoF MainUI background-scrim change in $mainui"
}
