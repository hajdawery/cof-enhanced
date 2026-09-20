param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!(Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "SourceRoot must be an existing directory: $SourceRoot"
}
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
$target = 'ref\gl\gl_opengl.c'
$targetPath = Join-Path $source $target
$patch = Join-Path $root 'patches\cof-gl-debug-stack.patch'
if (!(Test-Path -LiteralPath $patch)) { throw "Missing patch: $patch" }
if (!(Test-Path -LiteralPath $targetPath -PathType Leaf)) {
    throw "Not an FWGS source tree: $targetPath"
}
$rootPrefix = $root.TrimEnd('\') + '\'
if (-not $source.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}
$relativeSource = $source.Substring($rootPrefix.Length).Replace('\','/')
$headerPath = Join-Path $source 'ref\gl\gl_local.h'
$header = Get-Content -Raw -LiteralPath $headerPath
$opengl = Get-Content -Raw -LiteralPath $targetPath
$present = $opengl.Contains('GL_CoFTraceDebugStack') -and
    $opengl.Contains('COF_GL_TRACE_STACK_FRAMES') -and
    $opengl.Contains('path[ARRAYSIZE( path ) - 1]')

if($Reverse) {
    if(-not $present) { throw 'The CoF GL debug-stack helper is not present; refusing reverse application.' }
} else {
    if(-not $header.Contains('cof_gl_trace') -or
       -not $opengl.Contains('cof_gl_trace') -or
       -not $opengl.Contains('GL_CheckForErrorsNamed_')) {
        throw 'Apply the GL stage trace prerequisite first.'
    }
    if($present) { throw 'The CoF GL debug-stack helper is already present; use a clean source tree.' }
}

Push-Location $root
try {
    $args = @('--ignore-whitespace')
    if($Reverse) { $args += '--reverse' }
    $args += @('--check', "--directory=$relativeSource", '--', $patch)
    & git apply @args
    if ($LASTEXITCODE -ne 0) { throw 'Patch check failed.' }

    $args = @('--ignore-whitespace')
    if($Reverse) { $args += '--reverse' }
    $args += @("--directory=$relativeSource", '--', $patch)
    & git apply @args
    if ($LASTEXITCODE -ne 0) { throw 'git apply failed.' }

    $opengl = Get-Content -Raw -LiteralPath $targetPath
    $present = $opengl.Contains('GL_CoFTraceDebugStack') -and
        $opengl.Contains('COF_GL_TRACE_STACK_FRAMES') -and
        $opengl.Contains('path[ARRAYSIZE( path ) - 1]')
    if($Reverse) {
        if($present) { throw 'Reverse application completed without removing all GL debug-stack markers.' }
    } elseif(-not $present) {
        throw 'Patch command completed without all expected GL debug-stack markers.'
    }

    $checkDirection = if($Reverse) { @() } else { @('--reverse') }
    $check = @('--ignore-whitespace') + $checkDirection + @('--check', "--directory=$relativeSource", '--', $patch)
    & git apply @check
    if ($LASTEXITCODE -ne 0) { throw 'Applied GL debug-stack patch cannot be checked in the opposite direction.' }
} finally {
    Pop-Location
}
if($Reverse) { Write-Host "Removed off-by-default CoF GL debug-stack helper from $source" }
else { Write-Host "Applied off-by-default CoF GL debug-stack helper to $source" }
