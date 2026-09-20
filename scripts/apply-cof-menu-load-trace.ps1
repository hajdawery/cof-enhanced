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
    'engine\common\cmd.c',
    'engine\server\sv_client.c',
    'engine\server\sv_game.c',
    'engine\server\sv_main.c',
    'engine\server\sv_save.c'
)
$patch = Join-Path $root 'patches\cof-menu-load-trace.patch'

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
$relativeSource = $source.Substring($rootPrefix.Length).Replace('\','/')
$marker = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\server\sv_main.c')
if ($marker.Contains('cof_trace_menu_load')) {
    throw 'The CoF menu-load trace is already present; use a clean patched source tree.'
}

Push-Location $root
try {
    # Resolve the destination under the validated source directory. The patch
    # paths are repository-relative and are never allowed to escape it.
    & git apply --ignore-whitespace --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Patch does not apply cleanly to this source tree.' }
    & git apply --ignore-whitespace --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'git apply failed.' }

    $applied = Get-Content -Raw -LiteralPath (Join-Path $source 'engine\server\sv_main.c')
    if (-not $applied.Contains('cof_trace_menu_load')) {
        throw 'Patch command completed without the expected diagnostic cvar marker.'
    }
    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) {
        throw 'Applied menu-load trace patch cannot be reverse-checked.'
    }
} finally {
    Pop-Location
}
Write-Host "Applied off-by-default CoF menu-load trace to $source"
