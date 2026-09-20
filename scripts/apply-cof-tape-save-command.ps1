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

$clientFile = Join-Path $source 'engine\client\dll_int\cl_game.c'
$serverInit = Join-Path $source 'engine\server\sv_main.c'
foreach($path in @($clientFile, $serverInit)) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing FWGS source file: $path"
    }
}

$clientText = Get-Content -Raw -LiteralPath $clientFile
$initText = Get-Content -Raw -LiteralPath $serverInit
$marker = "CoF's original engine handles the client's tape-save request locally."
$rootCvar = 'cof_save_root_compat'
if (-not $initText.Contains($rootCvar)) {
    throw 'Expected the existing CoF root-save compatibility cvar; apply the base save patch first.'
}
if ($Reverse) {
    if (-not $clientText.Contains($marker) -or -not $clientText.Contains('save cofsave%c')) {
        throw 'Tape-save command hook markers are absent; refusing reverse application.'
    }
} else {
    if ($clientText.Contains($marker) -or $clientText.Contains('save cofsave%c')) {
        throw 'Tape-save command hook is already present; use -Reverse first or provide a clean source tree.'
    }
}

$patch = Join-Path $projectRoot 'patches\cof-tape-save-command.patch'
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

$after = Get-Content -Raw -LiteralPath $clientFile
if ($Reverse) {
    if ($after.Contains($marker) -or $after.Contains('save cofsave%c')) {
        throw 'Reverse application completed without removing all tape-save markers.'
    }
    Write-Host "Reversed CoF tape-save command hook in $source"
} else {
    if (-not $after.Contains($marker) -or -not $after.Contains('save cofsave%c')) {
        throw 'Forward application completed without the expected tape-save markers.'
    }
    Write-Host "Applied CoF tape-save command hook in $source"
}
