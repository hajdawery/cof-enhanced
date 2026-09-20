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
    'engine\common\con_utils.c',
    'engine\client\cl_cmds.c',
    'engine\client\cl_scrn.c',
    'engine\server\server.h',
    'engine\server\sv_cmds.c',
    'engine\server\sv_main.c',
    'engine\server\sv_save.c'
)
$patch = Join-Path $root 'patches\cof-save-root-compat.patch'

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
$marker = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\server\sv_main.c')
if ($marker.Contains('cof_save_root_compat')) {
    throw 'The CoF root-save compatibility patch is already present; use a clean patched source tree.'
}
if (-not $marker.Contains('cof_trace_menu_load')) {
    throw 'Apply the existing CoF menu-load trace patch first; this patch is based on that source state.'
}

Push-Location $root
try {
    $relativeSource = $source.Substring($rootPrefix.Length).Replace('\','/')
    & git apply --ignore-whitespace --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Patch does not apply cleanly to this source tree.' }
    & git apply --ignore-whitespace --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'git apply failed.' }

    $applied = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\server\sv_main.c')
    if (-not $applied.Contains('cof_save_root_compat')) {
        throw 'Patch command completed without the expected compatibility cvar marker.'
    }
    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) {
        throw 'Applied root-save compatibility patch cannot be reverse-checked.'
    }
} finally {
    Pop-Location
}
Write-Host "Applied opt-in CoF root-save compatibility to $source"
