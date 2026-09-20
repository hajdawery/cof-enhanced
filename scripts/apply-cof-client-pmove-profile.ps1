param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!(Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "SourceRoot must be an existing directory: $SourceRoot"
}
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
$target = Join-Path $source 'engine\client\dll_int\cl_pmove.c'
$serverTarget = Join-Path $source 'engine\server\sv_pmove.c'
$patch = Join-Path $root 'patches\cof-client-pmove-legacy.patch'

if (!(Test-Path -LiteralPath $target)) { throw "Not an FWGS source tree: $target" }
if (!(Test-Path -LiteralPath $serverTarget)) { throw "Not an FWGS source tree: $serverTarget" }
if (!(Test-Path -LiteralPath $patch)) { throw "Missing patch: $patch" }
$rootPrefix = $root.TrimEnd('\') + '\'
if (-not $source.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "SourceRoot must be inside this project workspace: $root"
}
$relativeSource = $source.Substring($rootPrefix.Length).Replace('\','/')
$serverText = Get-Content -Raw $serverTarget
$text = Get-Content -Raw $target
if (-not $serverText.Contains('COF_PMOVE_LEGACY_SHIFT')) {
    throw 'The client PMove profile requires the server PMove adapter first; apply that adapter to a clean pinned source tree.'
}
if ($text.Contains('COF_CLIENT_PMOVE_LEGACY_SHIFT')) {
    throw 'The client PMove profile is already present; use a clean pinned source tree before applying the patch.'
}

Push-Location $root
try {
    # The patch is redirected to the validated source directory. Do not use
    # --unsafe-paths: a patch path must never escape the project checkout.
    & git apply --ignore-whitespace --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Patch does not apply cleanly to this source tree.' }
    & git apply --ignore-whitespace --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'git apply failed.' }

    $appliedText = Get-Content -Raw $target
    if (-not $appliedText.Contains('COF_CLIENT_PMOVE_LEGACY_SHIFT') -or
        -not $appliedText.Contains('CL_CoF_LegacyPMove') -or
        -not $appliedText.Contains('cof_client_pmove_legacy_enabled')) {
        throw 'Patch command completed without the expected client PMove adapter markers.'
    }

    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) {
        throw 'Applied client PMove patch cannot be reverse-checked; refusing an unverified source tree.'
    }
} finally {
    Pop-Location
}
Write-Host "Applied experimental CoF client PMove adapter to $target"
