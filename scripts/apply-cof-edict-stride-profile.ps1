param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!(Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "SourceRoot must be an existing directory: $SourceRoot"
}
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
$target = Join-Path $source 'engine\edict.h'
$entvars = Join-Path $source 'engine\progdefs.h'
$wscript = Join-Path $source 'wscript'
$patch = Join-Path $root 'patches\cof-edict-stride-legacy.patch'

if (!(Test-Path -LiteralPath $target)) { throw "Not an FWGS source tree: $target" }
if (!(Test-Path -LiteralPath $entvars)) { throw "Not an FWGS source tree: $entvars" }
if (!(Test-Path -LiteralPath $wscript)) { throw "Not an FWGS source tree: $wscript" }
if (!(Test-Path -LiteralPath $patch)) { throw "Missing patch: $patch" }
$rootPrefix = $root.TrimEnd('\') + '\'
if (-not $source.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "SourceRoot must be inside this project workspace: $root"
}
$relativeSource = $source.Substring($rootPrefix.Length).Replace('\','/')
$text = Get-Content -Raw $target
$entvarsText = Get-Content -Raw $entvars
$wscriptText = Get-Content -Raw $wscript
if (-not $entvarsText.Contains('cof_legacy_unknown_0') -or
    -not $wscriptText.Contains('XASH_COF_ENTVARS_LEGACY')) {
    throw 'The edict stride profile requires the CoF entvars profile first; apply that profile to a clean pinned source tree.'
}
if ($text.Contains('cof_legacy_edict_tail') -or $text.Contains('xash_cof_edict_stride')) {
    throw 'The CoF edict stride profile is already present; use a clean pinned source tree before applying the patch.'
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
    if (-not $appliedText.Contains('cof_legacy_edict_tail') -or
        -not $appliedText.Contains('xash_cof_edict_stride') -or
        -not $appliedText.Contains('sizeof(struct edict_s) == 0x32C')) {
        throw 'Patch command completed without the expected edict stride markers.'
    }

    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) {
        throw 'Applied edict stride patch cannot be reverse-checked; refusing an unverified source tree.'
    }
} finally {
    Pop-Location
}
Write-Host "Applied experimental CoF edict stride profile to $target"
