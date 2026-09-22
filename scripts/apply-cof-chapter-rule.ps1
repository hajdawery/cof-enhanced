param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)

# Cry of Fear chapter title card: suppress the client's own decorative rule
# (cof_hud_chapter_rule_hide, default 1) in the engine's pfnFillRGBA path.
# Engine only; applied after scripts\apply-cof-ads-toggle.ps1, whose client.h
# block its declaration follows. See docs\cof-ads-toggle.md (chapter rule).

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!(Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "SourceRoot must be an existing directory: $SourceRoot"
}
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
$targets = @('engine\client\cl_main.c', 'engine\client\client.h', 'engine\client\dll_int\cl_game.c')
$patch = Join-Path $root 'patches\cof-chapter-rule.patch'

if (!(Test-Path -LiteralPath $patch)) { throw "Missing patch: $patch" }
foreach ($relative in $targets) {
    if (!(Test-Path -LiteralPath (Join-Path $source $relative))) { throw "Not an FWGS source tree: $(Join-Path $source $relative)" }
}
$rootPrefix = $root.TrimEnd('\') + '\'
if (-not $source.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}

function Slurp([string]$rel) { Get-Content -Raw -LiteralPath (Join-Path $source $rel) }

$present = (Slurp 'engine\client\dll_int\cl_game.c').Contains('CL_CoF_ChapterRuleHidden')
if ($Reverse) {
    if (-not $present) { throw 'The CoF chapter rule suppression is not present in this source tree; nothing to reverse.' }
} else {
    if ($present) { throw 'The CoF chapter rule suppression is already present; use a clean patched source tree.' }
    if (-not (Slurp 'engine\client\client.h').Contains('void CL_CoF_ADSSync( void );')) {
        throw 'Apply scripts\apply-cof-ads-toggle.ps1 first: this patch shares hunk context with it.'
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

    $m = Slurp 'engine\client\cl_main.c'; $c = Slurp 'engine\client\client.h'; $g = Slurp 'engine\client\dll_int\cl_game.c'
    if ($Reverse) {
        if ($m.Contains('cof_hud_chapter_rule_hide') -or $c.Contains('cof_hud_chapter_rule_hide') -or $g.Contains('CL_CoF_ChapterRuleHidden')) {
            throw 'Reverse left chapter rule markers behind.'
        }
        Write-Host "Reversed the CoF chapter rule suppression in $source"
        return
    }
    $calls = ([regex]::Matches($g, 'if\( CL_CoF_ChapterRuleHidden\( x, y, w, h, r, g, b, a \)\)')).Count
    $ok = $m.Contains('CVAR_DEFINE_AUTO( cof_hud_chapter_rule_hide, "1"') -and
          $m.Contains('Cvar_RegisterVariable( &cof_hud_chapter_rule_hide )') -and
          $c.Contains('extern convar_t cof_hud_chapter_rule_hide;') -and
          $g.Contains('static qboolean CL_CoF_ChapterRuleHidden(') -and $calls -eq 2
    if (-not $ok) { throw 'Patch command completed without the expected chapter rule markers (both fill paths must ask).' }
} finally {
    Pop-Location
}
Write-Host "Applied the CoF chapter rule suppression to $source"
