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

$targets = @(
    'engine\client\dll_int\cl_gameui.c',
    'engine\server\sv_save.c'
)
foreach($relative in $targets) {
    $path = Join-Path $source $relative
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing source file: $path"
    }
}

$serverFile = Join-Path $source 'engine\server\sv_save.c'
$uiFile = Join-Path $source 'engine\client\dll_int\cl_gameui.c'
$serverText = Get-Content -Raw -LiteralPath $serverFile
$uiText = Get-Content -Raw -LiteralPath $uiFile
if (-not $serverText.Contains('cof_save_root_compat') -or -not $serverText.Contains('SV_SaveFSOpen')) {
    throw 'Expected the existing CoF root-save compatibility adapter in sv_save.c; apply the base save patch first.'
}
if ($Reverse) {
    if (-not $uiText.Contains('cof_root_save_list') -or -not $serverText.Contains('Route comments through the existing CoF root-save read adapter.')) {
        throw 'Pause-save plumbing markers are absent; refusing reverse application.'
    }
} else {
    if ($uiText.Contains('cof_root_save_list') -or $serverText.Contains('Route comments through the existing CoF root-save read adapter.')) {
        throw 'Pause-save plumbing is already present; use -Reverse first or provide a clean source tree.'
    }
}

$patch = Join-Path $projectRoot 'patches\cof-pause-save-plumbing.patch'
if (!(Test-Path -LiteralPath $patch -PathType Leaf)) { throw "Missing patch: $patch" }

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

$serverAfter = Get-Content -Raw -LiteralPath $serverFile
$uiAfter = Get-Content -Raw -LiteralPath $uiFile
if ($Reverse) {
    if ($uiAfter.Contains('cof_root_save_list') -or $serverAfter.Contains('Route comments through the existing CoF root-save read adapter.')) {
        throw 'Reverse application completed without removing all markers.'
    }
    Write-Host "Reversed CoF pause-save plumbing in $source"
} else {
    if (-not $uiAfter.Contains('cof_root_save_list') -or -not $serverAfter.Contains('SV_SaveFSOpen( savename')) {
        throw 'Forward application completed without the expected markers.'
    }
    Write-Host "Applied CoF pause-save plumbing to $source"
}
