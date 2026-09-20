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
$loadFile = Join-Path $mainui 'menus\LoadGame.cpp'
$saveLoadFile = Join-Path $mainui 'menus\SaveLoad.cpp'
foreach($path in @($mainui, $loadFile, $saveLoadFile)) {
    if (!(Test-Path -LiteralPath $path)) { throw "Missing mainui source path: $path" }
}

$head = (& git -C $mainui rev-parse HEAD 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or $head -ne '61263995592e93a278d764807243d043d3b97c54') {
    throw "mainui must be at pinned baseline 61263995592e93a278d764807243d043d3b97c54; found $head"
}
$loadText = Get-Content -Raw -LiteralPath $loadFile
$saveLoadText = Get-Content -Raw -LiteralPath $saveLoadFile
$patch = Join-Path $projectRoot 'patches\cof-mainui-menu-save.patch'
if (!(Test-Path -LiteralPath $patch -PathType Leaf)) { throw "Missing patch: $patch" }

if ($Reverse) {
    if (-not $loadText.Contains('UI_CoFMenuSavesEnabled') -or
        -not $loadText.Contains('ConfirmSaveGame') -or
        -not $saveLoadText.Contains('cofMenuSaves')) {
        throw 'MainUI menu-save markers are absent; refusing reverse application.'
    }
} else {
    if ($loadText.Contains('UI_CoFMenuSavesEnabled') -or
        $loadText.Contains('ConfirmSaveGame') -or
        $saveLoadText.Contains('cofMenuSaves')) {
        throw 'MainUI menu-save changes are already present; use -Reverse first or provide a clean baseline.'
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

$loadAfter = Get-Content -Raw -LiteralPath $loadFile
$saveLoadAfter = Get-Content -Raw -LiteralPath $saveLoadFile
if ($Reverse) {
    if ($loadAfter.Contains('UI_CoFMenuSavesEnabled') -or $loadAfter.Contains('ConfirmSaveGame') -or
        $saveLoadAfter.Contains('cofMenuSaves')) {
        throw 'Reverse application completed without removing all MainUI markers.'
    }
    Write-Host "Reversed CoF MainUI menu-save integration in $mainui"
} else {
    if (-not $loadAfter.Contains('UI_CoFMenuSavesEnabled') -or -not $loadAfter.Contains('ConfirmSaveGame') -or
        -not $saveLoadAfter.Contains('cofMenuSaves')) {
        throw 'Forward application completed without the expected MainUI markers.'
    }
    Write-Host "Applied CoF MainUI menu-save integration in $mainui"
}
