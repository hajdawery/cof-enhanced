[CmdletBinding()]
param(
    [string]$SourceRoot = (Join-Path $PSScriptRoot '..'),
    [string]$OutputDirectory = (Join-Path (Join-Path $PSScriptRoot '..') 'build-launcher'),
    [string]$VcVarsPath = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$SourceRoot = [IO.Path]::GetFullPath($SourceRoot)
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
$source = Join-Path $SourceRoot 'launcher\cof_launch.cpp'
$resource = Join-Path $SourceRoot 'launcher\cof_launch.rc'
$icon = Join-Path $projectRoot 'assets\branding\coffix.ico'

$projectPrefix = $projectRoot.TrimEnd('\') + '\'
if (-not $SourceRoot.StartsWith($projectPrefix, [StringComparison]::OrdinalIgnoreCase) -and
    $SourceRoot -ne $projectRoot) {
    throw "SourceRoot must be inside this project workspace: $projectRoot"
}
if (-not $OutputDirectory.StartsWith($projectPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "OutputDirectory must be inside this project workspace: $projectRoot"
}

if ([string]::IsNullOrWhiteSpace($VcVarsPath)) {
    $vswhere = Get-Command vswhere.exe -ErrorAction SilentlyContinue
    if ($vswhere) {
        $installationPath = (& $vswhere.Source -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1)
        if ($installationPath) {
            $VcVarsPath = Join-Path $installationPath 'VC\Auxiliary\Build\vcvarsall.bat'
        }
    }
}
if ([string]::IsNullOrWhiteSpace($VcVarsPath) -and $env:VSINSTALLDIR) {
    $VcVarsPath = Join-Path $env:VSINSTALLDIR 'VC\Auxiliary\Build\vcvarsall.bat'
}
if ([string]::IsNullOrWhiteSpace($VcVarsPath)) {
    throw 'Visual Studio vcvarsall.bat was not found; pass -VcVarsPath explicitly.'
}
$vcvars = [IO.Path]::GetFullPath($VcVarsPath)

if (-not (Test-Path -LiteralPath $vcvars)) {
    throw "VS2022 x86 toolchain not found: $vcvars"
}
if (-not (Test-Path -LiteralPath $source)) {
    throw "Launcher source not found: $source"
}
if (-not (Test-Path -LiteralPath $resource)) {
    throw "Launcher resource not found: $resource"
}
if (-not (Test-Path -LiteralPath $icon)) {
    throw "Branding icon not found: $icon"
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$obj = Join-Path $OutputDirectory 'cof_launch.obj'
$res = Join-Path $OutputDirectory 'cof_launch.res'
$exe = Join-Path $OutputDirectory 'CoFLaunchApp.exe'
$sourceArg = $source.Replace('"', '""')
$resourceArg = $resource.Replace('"', '""')
$iconDirArg = (Split-Path -Parent $icon).Replace('"', '""')
$resArg = $res.Replace('"', '""')
$exeArg = $exe.Replace('"', '""')
$command = "call `"$vcvars`" x86 && rc /nologo /i `"$iconDirArg`" /fo `"$resArg`" `"$resourceArg`" && cl /nologo /W4 /EHsc /O2 /MT /DWIN32_LEAN_AND_MEAN `"$sourceArg`" `"$resArg`" /link user32.lib /SUBSYSTEM:CONSOLE /OUT:`"$exeArg`" /PDB:`"$($exe -replace '\.exe$','.pdb')`""
Push-Location $OutputDirectory
try {
    & cmd.exe /d /s /c $command
    if ($LASTEXITCODE -ne 0) { throw "cl failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}

Get-FileHash -LiteralPath $exe -Algorithm SHA256
