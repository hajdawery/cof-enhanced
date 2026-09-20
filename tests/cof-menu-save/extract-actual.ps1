param(
  [string]$SourceRoot = (Join-Path $PSScriptRoot '..\..\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a')
)
$source = Join-Path $SourceRoot 'engine\server\sv_save.c'
$text = Get-Content -Raw $source
function Extract-Function([string]$name) {
  $start = $text.IndexOf($name)
  if ($start -lt 0) { throw "Missing $name" }
  $brace = $text.IndexOf('{', $start)
  $depth = 0
  for ($i = $brace; $i -lt $text.Length; $i++) {
    if ($text[$i] -eq '{') { $depth++ }
    elseif ($text[$i] -eq '}') { $depth--; if ($depth -eq 0) { return $text.Substring($start, $i - $start + 1) } }
  }
  throw "Unclosed $name"
}
$parts = @(
  (Extract-Function 'static fs_offset_t SV_SaveFSWrite'),
  (Extract-Function 'static int SV_SaveFSClose'),
  (Extract-Function 'static qboolean SV_SaveFSFileCopy'),
  (Extract-Function 'qboolean SV_CoFMenuSave')
)
$out = ($parts -join "`r`n`r`n")
$out = $out.Replace('SV_SaveFSWrite', 'Actual_SV_SaveFSWrite').Replace('SV_SaveFSClose', 'Actual_SV_SaveFSClose').Replace('SV_SaveFSFileCopy', 'Actual_SV_SaveFSFileCopy').Replace('SV_CoFMenuSave', 'Actual_SV_CoFMenuSave')
Set-Content -NoNewline -Encoding utf8 actual_extracted.inc $out
