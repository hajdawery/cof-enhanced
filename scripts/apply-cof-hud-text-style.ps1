param([Parameter(Mandatory=$true)][string]$SourceRoot, [switch]$Reverse)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
if (-not $source.StartsWith($root.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'SourceRoot must be inside this project workspace.' }
$patch = Join-Path $root 'patches\cof-hud-text-style.patch'
$markers = @{
 'engine/client/cl_main.c' = 'CVAR_DEFINE_AUTO( cof_hud_text_style, "1"'
 'engine/client/client.h' = 'extern convar_t cof_hud_text_style;'
 'engine/client/cl_scrn.c' = 'fonts/cof_hudtext_bold%i.fnt'
 'engine/client/dll_int/cl_game.c' = 'static int CL_CoF_DrawStyledHudChar('
 'engine/vgui_api.h' = '2 Bold transient style (same ABI)'
 '3rdparty/freevgui/platform/xash3d-fwgs/coffont.cpp' = 'bool vgui::CofFont_MessageStyle('
 '3rdparty/freevgui/platform/xash3d-fwgs/coffont.h' = 'bool CofFont_MessageStyle('
 '3rdparty/freevgui/platform/xash3d-fwgs/surface.cpp' = 'static void CofDrawStyledQuad('
 '3rdparty/freevgui/platform/xash3d-fwgs/support.h' = 'bool         textMessageStyle;'
 'engine/cof_text_style.h' = 'static void CoF_TextShadowTap('
}
function Read-Source([string]$relative) {
 $path = Join-Path $source $relative
 if (Test-Path -LiteralPath $path) { Get-Content -LiteralPath $path -Raw } else { '' }
}
foreach ($entry in $markers.GetEnumerator()) {
 $content = Read-Source $entry.Key
 if ($Reverse -and -not $content.Contains($entry.Value)) { throw "Missing text-style marker: $($entry.Key)" }
 if (-not $Reverse -and $content.Contains($entry.Value)) { throw "Text-style patch already present: $($entry.Key)" }
}
if (-not $Reverse) {
 if (-not (Read-Source 'engine/client/cl_main.c').Contains('CL_CoF_FontRoleIsMessage') -or
     -not (Read-Source '3rdparty/freevgui/platform/xash3d-fwgs/surface.cpp').Contains('int opacity = 255 - backingGlyphs[line.first + j].color[3];')) {
   throw 'Prerequisite missing: Inter font/message backing and panel transparency patches.'
 }
 if (Test-Path -LiteralPath (Join-Path $source 'engine/cof_text_style.h')) { throw 'Refusing to overwrite existing text-style header.' }
}
$rel = $source.Substring($root.TrimEnd('\').Length + 1).Replace('\', '/')
$direction = @(); if ($Reverse) { $direction += '--reverse' }
Push-Location $root
try {
 & git apply --ignore-whitespace @direction --check --directory=$rel -- $patch
 if ($LASTEXITCODE -ne 0) { throw 'Text-style patch preflight failed.' }
 & git apply --ignore-whitespace @direction --directory=$rel -- $patch
 if ($LASTEXITCODE -ne 0) { throw 'Text-style patch apply failed.' }
 foreach ($entry in $markers.GetEnumerator()) {
   if ((Read-Source $entry.Key).Contains($entry.Value) -eq [bool]$Reverse) { throw "Unexpected text-style marker state: $($entry.Key)" }
 }
 if (-not $Reverse -and -not (Read-Source 'engine/client/cl_main.c').Contains('CVAR_DEFINE_AUTO( cof_hud_text_backing, "0",')) { throw 'Text background default is not off.' }
 $opposite = @(); if (-not $Reverse) { $opposite += '--reverse' }
 & git apply --ignore-whitespace @opposite --check --directory=$rel -- $patch
 if ($LASTEXITCODE -ne 0) { throw 'Text-style reverse/reapply check failed.' }
} finally { Pop-Location }
Write-Host "HUD text style applied (reverse=$Reverse): $source"
