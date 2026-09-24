param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)

# Cry of Fear on-screen keyboard, the engine and FreeVGUI half
# (patches/cof-osk-engine.patch). See docs/design/osk.md.
#
#   * engine/client/cof_osk.c (new): the last input device (Key_Event), the
#     game's text entries reported by FreeVGUI, "menu_cof_osk game" when a
#     gamepad clicks or focuses one, cof_osk_set <hex> (the typed text into
#     the focused entry), cof_osk_probe (test hook), cof_osk_status; cvars
#     cof_osk (saved, 1), cof_osk_over_game, cof_osk_field, cof_osk_hidden,
#     cof_osk_trace.
#   * engine/vgui_api.h, engine/client/vgui/vgui_draw.c: vguiapi_t::CofOskEntry
#     / CofOskCall (after SetPaintOffset; xash.dll and vgui.dll go together);
#     VGui_Paint keeps the game's panels on screen under the keyboard.
#   * engine/client/client.h, engine/client/input/in_keys.c: declarations,
#     the Key_Event and Key_Init hooks.
#   * 3rdparty/freevgui/controls/text.h / text.cpp: TextEntry reports its
#     construction, focus changes and clicks; platform/xash3d-fwgs/cofosk.cpp
#     (new) passes them on and carries out the engine's requests.
#
# Goes on after apply-cof-mainui-osk.ps1 (step 49) and the whole stack before
# it (language packs 42 for the vguiapi_t layout, the input gate 9, the
# chapter rule 40), BEFORE the panel and gamepad patches.
# apply-cof-client-enter-hook.ps1 builds on this one.

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!(Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "SourceRoot must be an existing directory: $SourceRoot"
}
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
$rootPrefix = $root.TrimEnd('\') + '\'
if (-not $source.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}
$targets = @(
    'engine\vgui_api.h',
    'engine\client\vgui\vgui_draw.c',
    'engine\client\client.h',
    'engine\client\input\in_keys.c',
    '3rdparty\freevgui\controls\text.h',
    '3rdparty\freevgui\controls\text.cpp'
)
$newFiles = @(
    'engine\client\cof_osk.c',
    '3rdparty\freevgui\platform\xash3d-fwgs\cofosk.cpp'
)
foreach ($relative in $targets) {
    if (!(Test-Path -LiteralPath (Join-Path $source $relative))) {
        throw "Not an FWGS source tree with freevgui checked out: $(Join-Path $source $relative)"
    }
}
$patch = Join-Path $root 'patches\cof-osk-engine.patch'
if (!(Test-Path -LiteralPath $patch -PathType Leaf)) { throw "Missing patch: $patch" }

function Slurp([string] $rel) { Get-Content -Raw -LiteralPath (Join-Path $source $rel) }
function Exists([string] $rel) { Test-Path -LiteralPath (Join-Path $source $rel) }

$api  = Slurp 'engine\vgui_api.h'
$draw = Slurp 'engine\client\vgui\vgui_draw.c'
$cl   = Slurp 'engine\client\client.h'
$keys = Slurp 'engine\client\input\in_keys.c'
$txt  = Slurp '3rdparty\freevgui\controls\text.cpp'

$present = $api.Contains('CofOskEntry') -or $draw.Contains('CL_CoF_OskFrame') -or $cl.Contains('CL_CoF_OskInit') -or
           $keys.Contains('CL_CoF_OskNoteKey') -or $txt.Contains('s_cofOskHook') -or ($newFiles | Where-Object { Exists $_ })

if ($Reverse) {
    if (-not $present) { throw 'The on-screen keyboard engine half is not present in this source tree; nothing to reverse.' }
    if ((Exists 'engine\client\cof_enter_hook.c') -or $keys.Contains('CL_CoF_EnterKeyEvent')) {
        throw 'apply-cof-client-enter-hook.ps1 sits on this patch: reverse it first.'
    }
} else {
    if ($present) { throw 'The on-screen keyboard engine half is already present; use -Reverse first or provide a clean patched tree.' }
    if (-not $api.Contains('const char *(*CofLangString)( const char *str );')) {
        throw 'Prerequisite missing: apply scripts\apply-cof-language-packs.ps1 first.'
    }
    if (-not $draw.Contains('void VGui_CoF_ForgetKey( int key )') -or -not $draw.Contains('CoF HUD from bleeding through a translucent pause scrim later.')) {
        throw 'Prerequisite missing: apply scripts\apply-cof-ui-input-gate.ps1 first (the VGui_Paint gate).'
    }
    if (-not $cl.Contains('extern convar_t cof_hud_chapter_rule_hide;')) {
        throw 'Prerequisite missing: apply scripts\apply-cof-chapter-rule.ps1 first.'
    }
    if ($draw.Contains('CL_CoF_PanelReport') -or $draw.Contains('CL_CoF_VCursorDraw')) {
        throw 'This tree already has the panel or gamepad patches; this patch goes on BEFORE them (docs/dev/patch-stack.md).'
    }
}

Push-Location $root
try {
    $relativeSource = $source.Substring($rootPrefix.Length).Replace('\','/')
    $extra = @()
    if ($Reverse) { $extra += '--reverse' }
    & git apply --ignore-whitespace --check --directory=$relativeSource @extra -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Patch does not apply cleanly to this source tree.' }
    & git apply --ignore-whitespace --directory=$relativeSource @extra -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'git apply failed.' }

    $api  = Slurp 'engine\vgui_api.h'
    $draw = Slurp 'engine\client\vgui\vgui_draw.c'
    $cl   = Slurp 'engine\client\client.h'
    $keys = Slurp 'engine\client\input\in_keys.c'
    $txth = Slurp '3rdparty\freevgui\controls\text.h'
    $txt  = Slurp '3rdparty\freevgui\controls\text.cpp'

    if ($Reverse) {
        if ($api.Contains('CofOskEntry') -or $draw.Contains('CL_CoF_Osk') -or $draw.Contains('VGui_CoF_OskCall') -or $cl.Contains('CL_CoF_Osk') -or
            $keys.Contains('CL_CoF_Osk') -or $txth.Contains('TextEntry_SetCofOskHook') -or $txt.Contains('s_cofOskHook') -or
            ($newFiles | Where-Object { Exists $_ })) {
            throw 'Reversed, but on-screen keyboard engine markers remain. Inspect the tree.'
        }
        if (-not $api.Contains('const char *(*CofLangString)( const char *str );')) { throw 'Reverse application damaged the patches this one sits on.' }
        Write-Host "Reversed patches\cof-osk-engine.patch in $source"
        return
    }

    foreach ($rel in $newFiles) { if (-not (Exists $rel)) { throw "Applied, but $rel was not created. Inspect the tree." } }
    $osk = Slurp 'engine\client\cof_osk.c'
    $fv  = Slurp '3rdparty\freevgui\platform\xash3d-fwgs\cofosk.cpp'

    $ok = $api.Contains('void	(*CofOskEntry)( int event, int hidden, const char *text );') -and
          $api.Contains('int	(*CofOskCall)( int op, char *buf, int size );') -and
          $draw.Contains('	CL_CoF_OskEntry, // CofOskEntry (cof_osk.c)') -and
          $draw.Contains('int VGui_CoF_OskCall( int op, char *buf, int size )') -and
          $draw.Contains('const qboolean osk_over_game = CL_CoF_OskFrame( );') -and
          $cl.Contains('void CL_CoF_OskNoteKey( int key, int down );') -and
          $keys.Contains('CL_CoF_OskNoteKey( key, down );') -and $keys.Contains('CL_CoF_OskInit();') -and
          $osk.Contains('static CVAR_DEFINE_AUTO( cof_osk, "1", FCVAR_ARCHIVE,') -and
          $osk.Contains('Cbuf_InsertText( "menu_cof_osk game\n" );') -and
          $osk.Contains('Cmd_AddCommand( "cof_osk_set", CL_CoF_OskSet_f,')
    if (-not $ok) { throw 'Applied, but the engine on-screen keyboard markers are missing. Inspect the tree.' }

    $ok = $txth.Contains('void TextEntry_SetCofOskHook( void (*hook)( TextEntry *entry, int event, bool hidden ));') -and
          $txt.Contains('s_cofOskHook( this, lost ? 0 : 1, hideText );') -and $txt.Contains('s_cofOskHook( this, 2, hideText );') -and
          $fv.Contains('g_engine->CofOskCall = CofOsk_Call;') -and $fv.Contains('TextEntry_SetCofOskHook( CofOsk_Hook );')
    if (-not $ok) { throw 'Applied, but the FreeVGUI on-screen keyboard markers are missing. Inspect the tree.' }

    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Applied on-screen keyboard engine patch cannot be reverse-checked.' }
} finally {
    Pop-Location
}
Write-Host "Applied patches\cof-osk-engine.patch in $source"
Write-Host 'Build: python waf build --targets=xash,vgui (the two go together)'
