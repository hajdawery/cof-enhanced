#requires -Version 5.1
<#
.SYNOPSIS
    List every string this project's menu (MainUI with the Cry of Fear theme)
    draws, so a language pack's strings/menu-strings.tsv can be written and
    kept complete. Optionally check a pack's file against the list.

.DESCRIPTION
    The menu translates text where it is drawn (MenuStrings.cpp, UI_LangText,
    patches/cof-mainui-menu-strings.patch), keyed by the English exactly as it
    appears on screen. This script collects those keys from three places:

      1. the MainUI sources of the pages Cry of Fear can reach (-MainUI):
         every L("...") argument, and every other string literal that reads
         as text (not a cvar, command, path, class name or console message);
         "#GameUI_..." / "GameUI_..." tokens are resolved to the English the
         game's resource files give them;
      2. the game's resource/gameui_english.txt and valve_english.txt (UTF-16)
         and this project's gamedata resource/cryoffear_english.txt, only to
         resolve those tokens;
      3. the Controls list, gfx/shell/kb_act.lst: every action label, and each
         section caption upper-cased the way the theme draws it.

    A literal with printf conversions (%s, %d, ...) is kept as it is: the
    menu matches formatted text against such keys.

    Output (-Out, default menu-strings.en.tsv in the current directory):
    english <TAB> where, UTF-8 without BOM, one row per key, in source order.

    With -Pack <languages\<code>> the pack's strings/menu-strings.tsv is
    checked: keys it lacks, keys no source uses any more, rows whose
    translation drops or adds a printf conversion, and characters the menu
    fonts do not carry (MainUI uploads ASCII, Latin-1 from U+00A1, Latin
    Extended-A, Cyrillic U+0400-045F and the cp1251 punctuation set; see
    font/FontManager.cpp UploadTextureForFont). Exit code 1 when anything is
    missing or invalid.

.EXAMPLE
    .\extract-menu-strings.ps1 -MainUI ..\..\pristine-lang2-20260922\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a\3rdparty\mainui -Pack ..\..\languages\polish

.NOTES
    Read-only: nothing is written but -Out. The game directory is only read.
    The page list below ($Files) is the set Cry of Fear reaches with the
    theme; a new page (for example the co-op Host/Join pages) is added there.
#>
param(
    [Parameter(Mandatory = $true)] [string] $MainUI,
    [string] $GameDir = 'K:\LLM\COF_Fix\Cry of Fear\cryoffear',
    [string] $GameData = '',
    [string] $Out = 'menu-strings.en.tsv',
    [string] $Pack = ''
)
$ErrorActionPreference = 'Stop'
$here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (!$GameData) { $GameData = Join-Path $here '..\..\gamedata\cryoffear' }

# The pages and controls Cry of Fear can reach with the theme (Main menu,
# its CoF pages, Options and every page under it, Save/Load, the stock
# Join/Host pages, connection dialogs) and the shared controls and theme.
# Mobile-only pages (Touch*, Gamepad, Gyro), the stock multiplayer setup,
# New Game, Custom Game and the test Zoo are not reachable and not listed.
$Files = @(
    'menus\Main.cpp', 'menus\CryOfFear.cpp', 'menus\Configuration.cpp',
    'menus\AdvancedControls.cpp', 'menus\InputDevices.cpp', 'menus\Controls.cpp',
    'menus\Video.cpp', 'menus\VideoModes.cpp', 'menus\VideoOptions.cpp', 'menus\Audio.cpp',
    'menus\LoadGame.cpp', 'menus\SaveLoad.cpp', 'menus\CreateGame.cpp',
    'menus\ServerBrowser.cpp', 'menus\ServerInfo.cpp',
    'menus\ConnectionProgress.cpp', 'menus\ConnectionWarning.cpp',
    'controls\Framework.cpp', 'controls\YesNoMessageBox.cpp', 'controls\MessageBox.cpp',
    'controls\Table.cpp', 'controls\SpinControl.cpp', 'controls\Slider.cpp',
    'controls\CheckBox.cpp', 'controls\PicButton.cpp', 'controls\Field.cpp',
    'model\KbActListModel.h', 'Theme.cpp',
    # the co-op Host/Join pages (patches/cof-mainui-coop.patch); listed when present
    'menus\CoFCoop.cpp',
    # the options relayout's Controls and Gamepad controls pages
    # (patches/cof-mainui-options-layout.patch); listed when present
    'menus\CoFOptions.cpp',
    # the on-screen keyboard (patches/cof-mainui-osk.patch); listed when present
    'menus\CoFOsk.cpp'
)

# calls whose string arguments are never drawn
$DenyCalls = @(
    'Con_Printf', 'Con_DPrintf', 'Con_NPrintf', 'Con_NXPrintf', 'Host_Error', 'printf',
    'ClientCmd', 'ClientCmdF', 'CvarSetValue', 'CvarSetString', 'GetCvarFloat', 'GetCvarString',
    'GetCvarPointer', 'LinkCvar', 'CvarRegister', 'Cmd_AddCommand', 'Cmd_RemoveCommand',
    'COM_LoadFile', 'COM_ParseFile', 'FileExists', 'GetFilesList', 'SetPicture', 'PIC_Load',
    'PIC_Width', 'PIC_Height', 'PlayLocalSound', 'PlayBackgroundTrack', 'ShellExecute',
    'strcmp', 'stricmp', 'strncmp', 'strnicmp', 'strstr', 'strchr', 'strrchr', 'strpbrk', 'Q_stricmp',
    'KEY_GetState', 'KEY_GetBinding', 'KEY_SetBinding', 'KEY_GetKey', 'KeynumToString',
    'ADD_MENU', 'ADD_MENU3', 'ADD_COMMAND', 'CMenuFramework', 'CMenuBaseWindow', 'CMenuYesNoMessageBox',
    'Info_ValueForKey', 'Info_SetValueForKey', 'SetKey', 'CFontBuilder', 'SetFontName',
    'fopen', 'FS_Open', 'DeleteFile', 'CheckGameDll', 'LoadLibrary', 'GetProcAddress',
    'UI_CoFReadScriptSettings', 'UI_ThemeCvarDefault', 'SetGameFile', 'StartBackgroundMap',
    'Cvar_Set', 'UI_SetCvar', 'Printf', 'Q_snprintf_cmd', 'WriteCvar', 'DebugMsg', 'HostEndGame',
    'fallback', 'BaseClass',
    'COF_KEY'   # engine key names in menus/CoFOptions.cpp
)

# literals that read as text but are never drawn as menu text (font face
# names, class names, internal format strings, protocol labels)
$NeverText = @(
    'Inter', 'Tahoma', 'Verdana', 'Microsoft Sans Serif', 'Arial', 'ConnectionProgress',
    'vibrate %f', 'Xash3D 49', 'GoldSource 48',
    '_wheel <up> <down> <release> <press>', '_hwheel <left> <right> <release> <press>'
)

function Unescape-C([string] $s) {
    # C string body -> text; \xNN are bytes of a UTF-8 sequence
    $sb = New-Object System.Collections.Generic.List[byte]
    $i = 0
    while ($i -lt $s.Length) {
        $c = $s[$i]
        if ($c -eq '\' -and $i + 1 -lt $s.Length) {
            $e = [string]$s[$i + 1]
            if ($e -ceq 'x') {
                $m = [regex]::Match($s.Substring($i + 2), '^[0-9A-Fa-f]{1,2}')
                $sb.Add([Convert]::ToByte($m.Value, 16)); $i += 2 + $m.Length
            } elseif ($e -ceq 'n') { $sb.Add(10); $i += 2 }
            elseif ($e -ceq 't') { $sb.Add(9); $i += 2 }
            elseif ($e -ceq 'r') { $sb.Add(13); $i += 2 }
            else { $sb.Add([byte][char]$e); $i += 2 }
            continue
        }
        foreach ($b in [Text.Encoding]::UTF8.GetBytes([string]$c)) { $sb.Add($b) }
        $i++
    }
    return [Text.Encoding]::UTF8.GetString($sb.ToArray())
}

function Escape-Tsv([string] $s) {
    return $s.Replace('\', '\\').Replace("`t", '\t').Replace("`r", '\r').Replace("`n", '\n')
}

# ------------------------------------------------------------------ tokens
$tokens = @{}
function Read-Vdf([string] $path) {
    if (!(Test-Path -LiteralPath $path)) { Write-Warning "no $path"; return }
    $bytes = [IO.File]::ReadAllBytes($path)
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { $text = [Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2) }
    else { $text = [Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF) }
    foreach ($m in [regex]::Matches($text, '(?m)^\s*"([^"]+)"\s+"((?:[^"\\]|\\.)*)"')) {
        $k = $m.Groups[1].Value
        $v = $m.Groups[2].Value.Replace('\n', "`n").Replace('\"', '"').Replace('\\', '\')
        $tokens[$k.ToLowerInvariant()] = $v   # the last file read wins, as in MenuStrings.cpp
    }
}
Read-Vdf (Join-Path $GameDir 'resource\gameui_english.txt')
Read-Vdf (Join-Path $GameDir 'resource\valve_english.txt')
Read-Vdf (Join-Path $GameData 'resource\cryoffear_english.txt')

# MainUI's own StringsList_<n> defaults (MenuStrings.cpp: "text", // n)
$ms = Join-Path $MainUI 'MenuStrings.cpp'
if (Test-Path -LiteralPath $ms) {
    foreach ($m in [regex]::Matches([IO.File]::ReadAllText($ms), '(?m)^"((?:[^"\\]|\\.)*)",?\s*//\s*(\d+)')) {
        $tokens[('stringslist_' + $m.Groups[2].Value)] = Unescape-C $m.Groups[1].Value
    }
}

function Resolve-Token([string] $s) {
    $k = $s.TrimStart('#')
    if ($k -match '^(GameUI|Valve|StringsList)_' ) {
        $v = $tokens[$k.ToLowerInvariant()]
        if ($null -ne $v) { return $v }
        return $null     # an unresolved token is drawn as its own name: nothing to translate
    }
    return $s
}

function Test-Text([string] $s) {
    if ($s.Length -lt 2) { return $false }
    if ($s -notmatch '[A-Za-z]{2}') { return $false }
    if ($s.EndsWith("`n")) { return $false }                  # console lines and commands
    if ($s -match '[/\\]' -and $s -notmatch ' ') { return $false }  # paths
    if ($s -match '\.(tga|bmp|wav|mp3|txt|cfg|lst|dat|bsp|custom|dll|ttf|sav|res)$') { return $false }
    if ($s -cmatch '^[a-z0-9_+\-\.]+$') { return $false }         # cvars, commands, file stems
    # class names (CMenuMain, CAdvancedControls) but not titles ("CONTROLS")
    if ($s -cmatch '^(CMenu|C[A-Z][a-z]+[A-Za-z]*$|menu_|ui_|cof_|cl_|sv_|gl_|r_|m_|s_|hud_)') { return $false }
    if ($s -cmatch '^%[-0-9.]*[sdif]$') { return $false }
    if ($s.EndsWith('=')) { return $false }                       # manifest keys
    if ($s -notmatch ' ' -and $s -match '[\^\(\)!\$&\*%,{}]') { return $false }   # tokens, format fragments
    if ($NeverText -ccontains $s) { return $false }
    if ($s -match '^(https?://|www\.)') { return $false }
    return $true
}

# ------------------------------------------------------------------ sources
$keys = New-Object System.Collections.Specialized.OrderedDictionary ([StringComparer]::Ordinal)   # case matters: "LOAD GAME" is not "Load Game"
function Add-Key([string] $k, [string] $where) {
    if ([string]::IsNullOrEmpty($k)) { return }
    if ($keys.Contains($k)) { if ($keys[$k] -notmatch [regex]::Escape($where)) { $keys[$k] += ";$where" } }
    else { $keys[$k] = $where }
}

$review = New-Object System.Collections.Generic.List[string]

foreach ($rel in $Files) {
    $path = Join-Path $MainUI $rel
    if (!(Test-Path -LiteralPath $path)) { Write-Host "not in this tree (skipped): $rel"; continue }
    $src = [IO.File]::ReadAllText($path)
    $n = $src.Length
    $stack = New-Object System.Collections.Generic.List[string]
    $line = 1; $i = 0
    $ident = ''; $lastIdent = ''
    $pending = $null   # adjacent literals are one string
    $atLineStart = $true
    while ($i -lt $n) {
        $c = $src[$i]
        if ($c -eq "`n") { $line++ }
        # comments
        if ($c -eq '/' -and $i + 1 -lt $n -and $src[$i + 1] -eq '/') {
            while ($i -lt $n -and $src[$i] -ne "`n") { $i++ }
            continue
        }
        if ($c -eq '/' -and $i + 1 -lt $n -and $src[$i + 1] -eq '*') {
            $e = $src.IndexOf('*/', $i + 2); if ($e -lt 0) { break }
            $line += ([regex]::Matches($src.Substring($i, $e - $i), "`n")).Count
            $i = $e + 2; continue
        }
        # preprocessor lines (#include "x.h", #define ...), with continuations
        if ($c -eq '#' -and $atLineStart) {
            while ($i -lt $n -and $src[$i] -ne "`n") {
                if ($src[$i] -eq '' -and $i + 1 -lt $n -and $src[$i + 1] -eq "`r") { $i++ }
                if ($src[$i] -eq '' -and $i + 1 -lt $n -and $src[$i + 1] -eq "`n") { $i += 2; $line++; continue }
                $i++
            }
            continue
        }
        if (-not [char]::IsWhiteSpace($c)) { $atLineStart = $false } elseif ($c -eq "`n") { $atLineStart = $true }
        if ($c -eq "'") {
            $i++
            while ($i -lt $n -and $src[$i] -ne "'") { if ($src[$i] -eq '\') { $i++ }; $i++ }
            $i++; continue
        }
        if ($c -eq '"') {
            $j = $i + 1
            while ($j -lt $n -and $src[$j] -ne '"') { if ($src[$j] -eq '\') { $j++ }; $j++ }
            $raw = $src.Substring($i + 1, $j - $i - 1)
            $text = Unescape-C $raw
            if ($null -ne $pending) { $pending.Text += $text }
            else {
                $call = if ($stack.Count) { $stack[$stack.Count - 1] } else { '' }
                $pending = [pscustomobject]@{ Text = $text; Call = $call; Line = $line; Prev = $lastIdent }
            }
            $i = $j + 1
            # another literal right after (only whitespace between) joins this one
            $k = $i; while ($k -lt $n -and [char]::IsWhiteSpace($src[$k])) { $k++ }
            if ($k -lt $n -and $src[$k] -eq '"') {
                $line += ([regex]::Matches($src.Substring($i, $k - $i), "`n")).Count
                $i = $k; continue
            }
            # classify the finished string
            $p = $pending; $pending = $null
            $where = '{0}:{1}' -f ($rel.Replace('\', '/')), $p.Line
            if ($p.Call -eq 'L') {
                Add-Key (Resolve-Token $p.Text) $where
            } elseif ($DenyCalls -contains $p.Call) {
                # never drawn
            } elseif ($p.Text -match '^#?(GameUI|Valve)_') {
                Add-Key (Resolve-Token $p.Text) $where
            } elseif (Test-Text $p.Text) {
                if ($p.Call -in @('', 'SetPanel', 'SetNameAndStatus', 'AddButton', 'SetMessage', 'SetPositiveButton',
                        'SetNegativeButton', 'snprintf', 'Q_snprintf', 'V_snprintf', 'AddLabel', 'AddVirtualCommand',
                        'SetupColumn', 'SetCaption', 'AddRow', 'SetTitle', 'SetInfo', 'AddSwitch', 'AddItem', 'Setup', 'Q_strncpy',
                        'UI_ShowMessageBox')) {
                    Add-Key $p.Text $where
                } else {
                    $review.Add(("{0}`t{1}`t{2}" -f $where, $p.Call, $p.Text))
                    Add-Key $p.Text $where
                }
            }
            continue
        }
        if ([char]::IsLetterOrDigit($c) -or $c -eq '_') { $ident += $c; $i++; continue }
        if ($ident) { $lastIdent = $ident; $ident = '' }
        if ($c -eq '(') { $stack.Add($lastIdent); $lastIdent = '' }
        elseif ($c -eq ')') { if ($stack.Count) { $stack.RemoveAt($stack.Count - 1) } }
        elseif ($c -eq ';' -or $c -eq '{' -or $c -eq '}') { $stack.Clear() }
        $i++
    }
}

# ------------------------------------------------------------------ kb_act.lst
$kb = Join-Path $GameDir 'gfx\shell\kb_act.lst'
if (Test-Path -LiteralPath $kb) {
    $ln = 0
    foreach ($l in [IO.File]::ReadAllLines($kb)) {
        $ln++
        $m = [regex]::Match($l, '^\s*"([^"]*)"\s+"([^"]*)"')
        if (!$m.Success) { continue }
        $label = [regex]::Replace($m.Groups[2].Value, '\^[0-9]', '')
        if ($label -match '^=+$' -or !$label) { continue }
        if ($label.StartsWith('#')) { $label = Resolve-Token $label; if (!$label) { continue } }
        if ($m.Groups[1].Value -eq 'blank') { $label = $label.ToUpperInvariant() }   # section caption, as the theme draws it
        Add-Key $label ("gfx/shell/kb_act.lst:{0}" -f $ln)
    }
} else { Write-Warning "no $kb (the Controls list is not covered)" }

# ------------------------------------------------------------------ engine text the menu draws
# Strings that reach a menu page from the engine rather than from MainUI.
Add-Key 'Pause Save (%s)' 'engine/server/sv_save.c (title of a pause-menu save, in the Load list)'

# ------------------------------------------------------------------ output
$utf8 = New-Object Text.UTF8Encoding $false
$lines = @("english`twhere")
foreach ($k in $keys.Keys) { $lines += ("{0}`t{1}" -f (Escape-Tsv $k), $keys[$k]) }
[IO.File]::WriteAllText([IO.Path]::GetFullPath($Out), (($lines -join "`n") + "`n"), $utf8)
Write-Host ("{0} menu strings -> {1}" -f $keys.Count, $Out)
if ($review.Count) {
    Write-Host ("{0} of them are literals in calls this script does not know (kept; add the call to DenyCalls if one is never drawn):" -f $review.Count)
    $review | ForEach-Object { Write-Host "  $_" }
}

if (!$Pack) { exit 0 }

# ------------------------------------------------------------------ pack check
$tsv = Join-Path $Pack 'strings\menu-strings.tsv'
if (!(Test-Path -LiteralPath $tsv)) { Write-Host "no $tsv"; exit 1 }
$pk = New-Object System.Collections.Specialized.OrderedDictionary ([StringComparer]::Ordinal)
$first = $true; $ln = 0
foreach ($l in [IO.File]::ReadAllLines($tsv, [Text.Encoding]::UTF8)) {
    $ln++
    if (!$l -or $l.StartsWith('#')) { continue }
    $cells = $l.Split("`t")
    if ($first) { $first = $false; if ($cells[0] -eq 'english') { continue } }
    if ($cells.Count -lt 2) { Write-Host "line ${ln}: no tab"; continue }
    $en = $cells[0].Replace('\n', "`n").Replace('\t', "`t").Replace('\\', '\')
    $tr = $cells[1].Replace('\n', "`n").Replace('\t', "`t").Replace('\\', '\')
    if (!$pk.Contains($en)) { $pk[$en] = [pscustomobject]@{ Tr = $tr; Line = $ln } }
}

$bad = 0
$missing = @($keys.Keys | Where-Object { -not $pk.Contains($_) })
$obsolete = @($pk.Keys | Where-Object { -not $keys.Contains($_) })
$empty = @($pk.Keys | Where-Object { $keys.Contains($_) -and -not $pk[$_].Tr })

# the glyphs MainUI uploads for its fonts
$cp1251 = [Text.Encoding]::GetEncoding(1251)
$allowed = New-Object 'System.Collections.Generic.HashSet[int]'
foreach ($r in @(@(0x20, 0x7E), @(0xA1, 0xFF), @(0x100, 0x17F), @(0x400, 0x45F))) { for ($u = $r[0]; $u -le $r[1]; $u++) { [void]$allowed.Add($u) } }
for ($b = 0x80; $b -le 0xBF; $b++) { [void]$allowed.Add([int][char]($cp1251.GetString([byte[]]@($b)))) }
[void]$allowed.Add(10)

$conv = '%[-+ #0]*[0-9]*(\.[0-9]+)?[lh]*[sdiufcxX]'
foreach ($k in $pk.Keys) {
    $tr = $pk[$k].Tr
    if (!$tr) { continue }
    foreach ($ch in $tr.ToCharArray()) {
        if (-not $allowed.Contains([int]$ch)) { Write-Host ("line {0}: U+{1:X4} '{2}' is not in the menu fonts: {3}" -f $pk[$k].Line, [int]$ch, $ch, $tr); $bad++ }
    }
    $a = ([regex]::Matches(($k -replace '%%', ''), $conv)).Count
    $b2 = ([regex]::Matches(($tr -replace '%%', ''), $conv)).Count
    if ($a -ne $b2) { Write-Host ("line {0}: {1} conversion(s) in the English, {2} in the translation: {3}" -f $pk[$k].Line, $a, $b2, $tr); $bad++ }
}

Write-Host ("pack {0}: {1} rows, {2} of the {3} menu strings covered" -f $tsv, $pk.Count, ($keys.Count - $missing.Count), $keys.Count)
if ($missing.Count) { Write-Host ("MISSING ({0}):" -f $missing.Count); $missing | ForEach-Object { Write-Host ("  {0}`t{1}" -f (Escape-Tsv $_), $keys[$_]) } }
if ($empty.Count) { Write-Host ("EMPTY translation ({0}):" -f $empty.Count); $empty | ForEach-Object { Write-Host "  $(Escape-Tsv $_)" } }
if ($obsolete.Count) { Write-Host ("not used by the sources any more ({0}; harmless, remove when sure):" -f $obsolete.Count); $obsolete | ForEach-Object { Write-Host "  $(Escape-Tsv $_)" } }
if ($missing.Count -or $bad) { exit 1 }
exit 0
