param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!(Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "SourceRoot must be an existing directory: $SourceRoot"
}
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
$target = 'engine\client\cl_cmds.c'
$patch = Join-Path $root 'patches\cof-levelshot-guard.patch'

if (!(Test-Path -LiteralPath $patch)) { throw "Missing patch: $patch" }
if (!(Test-Path -LiteralPath (Join-Path $source $target))) {
    throw "Not an FWGS source tree: $(Join-Path $source $target)"
}
$rootPrefix = $root.TrimEnd('\') + '\'
if (-not $source.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}

$cmds = Get-Content -Raw -LiteralPath (Join-Path $source $target)

if ($cmds.Contains('no world loaded, skipping the levelshot')) {
    throw 'The CoF levelshot NULL-world guard is already present; use a clean patched source tree.'
}
if (-not $cmds.Contains('ft1 = FS_FileTime( cl.worldmodel->name, false );')) {
    throw 'Not the expected CL_LevelShot_f: the unguarded cl.worldmodel->name read is not there.'
}

Push-Location $root
try {
    $relativeSource = $source.Substring($rootPrefix.Length).Replace('\','/')
    & git apply --ignore-whitespace --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Patch does not apply cleanly to this source tree.' }
    & git apply --ignore-whitespace --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'git apply failed.' }

    $after = Get-Content -Raw -LiteralPath (Join-Path $source $target)
    $present = $after.Contains('if( !cl.worldmodel || COM_StringEmpty( cl.worldmodel->name ) || COM_StringEmpty( clgame.mapname ))') -and
               $after.Contains('no world loaded, skipping the levelshot') -and
               $after.Contains('if( COM_StringEmpty( cls.demoname ))')
    if (-not $present) {
        throw 'Patch command completed without the expected levelshot guard markers.'
    }
    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) {
        throw 'Applied levelshot guard patch cannot be reverse-checked.'
    }
} finally {
    Pop-Location
}
Write-Host "Applied CoF levelshot NULL-world guard to $source"
