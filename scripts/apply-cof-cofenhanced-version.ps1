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
$target = 'engine\client\console.c'
$patch  = Join-Path $root 'patches\cof-cofenhanced-version.patch'

if (!(Test-Path -LiteralPath $patch)) { throw "Missing patch: $patch" }
if (!(Test-Path -LiteralPath (Join-Path $source $target))) {
    throw "Not an FWGS source tree: $(Join-Path $source $target)"
}
$rootPrefix = $root.TrimEnd('\') + '\'
if (-not $source.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}

$console = Get-Content -Raw -LiteralPath (Join-Path $source $target)
$present = $console.Contains('COFE_BUILD_STRING')

if ($Reverse) {
    if (-not $present) { throw 'The cofenhanced version stamp is not present; nothing to reverse.' }
} else {
    if ($present) { throw 'The cofenhanced version stamp is already present; use a clean patched source tree.' }
    # both hunks sit inside code the styled console and the text autoscale added
    if (-not $console.Contains('cof_console_style')) {
        throw 'Apply scripts\apply-cof-console-style.ps1 first: the console title band hunk is part of the styled console.'
    }
    if (-not $console.Contains('cof_text_autoscale')) {
        throw 'Apply scripts\apply-cof-text-autoscale.ps1 first: this patch shares hunk context with the text autoscale.'
    }
}

Push-Location $root
try {
    $relativeSource = $source.Substring($rootPrefix.Length).Replace('\','/')
    $gitArgs = @('apply','--ignore-whitespace',"--directory=$relativeSource")
    if ($Reverse) { $gitArgs += '--reverse' }

    & git @($gitArgs + @('--check','--', $patch))
    if ($LASTEXITCODE -ne 0) { throw 'Patch does not apply cleanly to this source tree.' }
    & git @($gitArgs + @('--', $patch))
    if ($LASTEXITCODE -ne 0) { throw 'git apply failed.' }

    $after = Get-Content -Raw -LiteralPath (Join-Path $source $target)

    if ($Reverse) {
        if ($after.Contains('COFE_BUILD_STRING')) { throw 'Reverse left cofenhanced markers behind.' }
        if (-not $after.Contains('cof_text_autoscale') -or -not $after.Contains('cof_console_style')) {
            throw 'Reverse damaged the console patches this one sits on.'
        }
        Write-Host "Reversed the cofenhanced version stamp in $source"
        return
    }

    $ok = $after.Contains('#define COFE_BUILD_STRING "cofenhanced " COFE_VERSION " (" COFE_MILESTONE ", " COFE_COMMIT ")"') -and
          $after.Contains('__has_include( "cof_version.h" )') -and
          $after.Contains('#define COFE_VERSION   "dev"') -and
          $after.Contains('Con_DrawString( refState.width - cofLen * 1.05f,')
    if (-not $ok) { throw 'Patch command completed without the expected cofenhanced markers.' }

    & git @('apply','--ignore-whitespace','--reverse','--check',"--directory=$relativeSource", '--', $patch)
    if ($LASTEXITCODE -ne 0) { throw 'Applied cofenhanced patch cannot be reverse-checked.' }
} finally {
    Pop-Location
}
Write-Host "Applied the cofenhanced version stamp to $source"
Write-Host 'Run scripts\write-cof-version.ps1 before building to stamp the real values.'
