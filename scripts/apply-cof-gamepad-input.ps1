param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)

# Gamepad input for Cry of Fear (patches/cof-gamepad-input.patch; engine,
# FreeVGUI support library and two small MainUI hunks - xash.dll, vgui.dll and
# menu.dll go together):
#
#   * engine/client/input/cof_gamepad.c (new): CL_CoF_ClickablePanelOpen() -
#     "a clickable CoF panel is open" = in play, key_game, and a modal client
#     panel on screen by class (CL_CoF_PanelsOnScreen of cof-panel-pause; the
#     VGUI arrow cursor, host.mouse_visible, only as the fallback when the class
#     list names nothing); while it holds (cvar cof_pad_panel_gate) the sticks
#     do not move the player, START gets the Escape bypass to the pause menu,
#     the close key (cof_pad_close_key, B) backs out of the panel through the
#     panel's own Back/Close/Cancel/No button (vguiapi_t::CofPanelAction; the
#     inventory through its "+inventory" binding, other panels through the
#     game's own Escape handling), and A / X click at the gamepad cursor (A on
#     a tape recorder slot also gives the page its second click). The virtual
#     cursor (cof_vcursor*, drawn by the engine from gfx/shell/gamepad/cursor.png
#     with a dark shadow; the drawn ring when the file is missing), the last
#     input device (cof_last_input, from the SDL events; the OS arrow stays
#     hidden in menus and over panels while it is the pad, cof_pad_hide_cursor),
#     the once-per-profile default pad layout (generation 3: D-pad down
#     weapontoggle, L3 cof_sprint_toggle_press; cof_pad_defaults,
#     cof_pad_defaults_gen), the sprint toggle (cof_sprint_toggle), the client's
#     WinMM joystick kept off (cof_joy_legacy_off), the crouch toggle
#     (cof_duck_toggle), gyro aiming off by default, the dodge guard
#     (cof_joy_pulse_hysteresis), cof_pad_status, cof_pad_panel_dump and the
#     developer hooks cof_joy_axis_probe / cof_vcursor_test / cof_input_trace.
#   * engine/client/input/input.c: CL_CoF_PadInit in IN_Init, stick suppression
#     in IN_EngineAppendMove, the pulse hysteresis in IN_JoyAppendMove, the
#     cursor frame in Host_InputFrame.
#   * engine/client/input/in_keys.c: START in the cof_ui_input_gate Escape
#     bypass; pad keys on an open panel routed before the client sees them.
#   * engine/client/input/in_joy.c: the Joy_CoF_AxisValue accessor; joy_gyro_enable
#     defaults to 0; a deflected axis marks the pad as the last input device.
#   * engine/client/vgui/vgui_draw.c/.h: VGUI_GetMousePos reads the gamepad
#     cursor; VGui_Paint draws it last; VGui_CoF_PanelAction.
#   * engine/vgui_api.h: vguiapi_t::CofPanelAction + COF_VGUI_PANEL_*.
#   * engine/platform/sdl2/host_sdl2.c: every SDL event goes past
#     CL_CoF_InputEvent (the last input device).
#   * engine/platform/sdl2/in_sdl2.c: Platform_SetMousePos notes the engine's own
#     warps; Platform_SetCursorType asks CL_CoF_OSCursorRequest before it shows
#     the arrow.
#   * 3rdparty/freevgui/platform/xash3d-fwgs/cofpanels.cpp, support.h, app.cpp:
#     CofPanels_Action (the panels' own buttons by their handler class and
#     command; the tape slot's second click; the developer dump and locate).
#   * 3rdparty/mainui/menus/LoadGame.cpp: A / Enter / double click on a Load or
#     Save row loads / saves it. 3rdparty/mainui/menus/CoFOptions.cpp: a
#     gamepad key reaching the menu marks cof_last_input "pad".
#   * engine/client/input.h: declarations.
#
# Step 55 of docs/dev/patch-stack.md: after the on-screen keyboard steps
# (49-52, which it applies after unchanged; it also applies without them, at
# the m8 position) and after patches/cof-panel-pause.patch and
# cof-panel-transparency.patch (53-54; the panel check reads the panel
# identity of cof-panel-pause, the vgui_api.h hunk sits after the transparency
# entries), after cof-mainui-options-layout (48), BEFORE apply-cof-cheats.ps1
# (56, which touches none of these files). Needs the input gate (cof-ui-input-gate), the
# styled console's Con_MouseMove (cof-console-style), the ADS hold hook
# (cof-ads-toggle) and the UI scale inverse in VGUI_GetMousePos (cof-ui-scale).
# See docs/patches/cof-gamepad-input.md.

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
$inputRel = 'engine\client\input\input.c'
$keysRel  = 'engine\client\input\in_keys.c'
$joyRel   = 'engine\client\input\in_joy.c'
$vguiRel  = 'engine\client\vgui\vgui_draw.c'
$hdrRel   = 'engine\client\input.h'
$newRel   = 'engine\client\input\cof_gamepad.c'
$apiRel   = 'engine\vgui_api.h'
$hostRel  = 'engine\platform\sdl2\host_sdl2.c'
$insdlRel = 'engine\platform\sdl2\in_sdl2.c'
$panRel   = '3rdparty\freevgui\platform\xash3d-fwgs\cofpanels.cpp'
$appRel   = '3rdparty\freevgui\platform\xash3d-fwgs\app.cpp'
$loadRel  = '3rdparty\mainui\menus\LoadGame.cpp'
$optRel   = '3rdparty\mainui\menus\CoFOptions.cpp'
foreach ($relative in @($inputRel, $keysRel, $joyRel, $vguiRel, $hdrRel, $apiRel, $hostRel, $insdlRel, $appRel, $loadRel)) {
    if (!(Test-Path -LiteralPath (Join-Path $source $relative))) {
        throw "Not an FWGS source tree with FreeVGUI and MainUI: $(Join-Path $source $relative)"
    }
}
$patch = Join-Path $root 'patches\cof-gamepad-input.patch'
if (!(Test-Path -LiteralPath $patch -PathType Leaf)) { throw "Missing patch: $patch" }

function Slurp([string] $rel) {
    $p = Join-Path $source $rel
    if (Test-Path -LiteralPath $p) { Get-Content -Raw -LiteralPath $p } else { '' }
}

$inputC = Slurp $inputRel
$keys   = Slurp $keysRel
$present = (Test-Path -LiteralPath (Join-Path $source $newRel)) -or $inputC.Contains('CL_CoF_PadFrame') -or $keys.Contains('CL_CoF_PadKeyEvent')

if ($Reverse) {
    if (-not $present) { throw 'The gamepad input patch is not present in this source tree; nothing to reverse.' }
} else {
    if ($present) { throw 'The gamepad input patch is already present; use -Reverse first or provide a clean tree.' }
    $vgui = Slurp $vguiRel
    if (-not $keys.Contains('if( cof_ui_input_gate.value && key == K_ESCAPE && down && cls.key_dest == key_game )') -or
        -not $keys.Contains('CL_CoF_ADSHoldActive( )')) {
        throw 'Prerequisite missing: apply patches/cof-ui-input-gate.patch and patches/cof-ads-toggle.patch first.'
    }
    if (-not $inputC.Contains('Con_MouseMove( x, y );')) {
        throw 'Prerequisite missing: apply patches/cof-console-style.patch first.'
    }
    if (-not $vgui.Contains('float cof_scale = CL_CoF_UIScale();')) {
        throw 'Prerequisite missing: apply patches/cof-ui-scale.patch first.'
    }
    if (-not (Slurp 'engine\common\common.h').Contains('unsigned int CL_CoF_PanelsOnScreen( qboolean *reporting );') -or
        -not (Test-Path -LiteralPath (Join-Path $source $panRel))) {
        throw 'Prerequisite missing: apply patches/cof-panel-pause.patch first (panel identity).'
    }
    if (-not (Slurp $apiRel).Contains('int	(*CofImageLatch)( char *buf, int size );')) {
        throw 'Prerequisite missing: apply patches/cof-panel-transparency.patch first (vguiapi_t entries).'
    }
    if (-not (Slurp $optRel).Contains('bool UI_CoFInputEvent( int key, int down )')) {
        throw 'Prerequisite missing: apply patches/cof-mainui-options-layout.patch first (menu pad input).'
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

    $inputC = Slurp $inputRel
    $keys   = Slurp $keysRel
    $joy    = Slurp $joyRel
    $vgui   = Slurp $vguiRel
    $hdr    = Slurp $hdrRel
    $newC   = Slurp $newRel
    $api    = Slurp $apiRel
    $hostC  = Slurp $hostRel
    $insdl  = Slurp $insdlRel
    $pan    = Slurp $panRel
    $app    = Slurp $appRel
    $load   = Slurp $loadRel
    $opt    = Slurp $optRel

    if ($Reverse) {
        if ((Test-Path -LiteralPath (Join-Path $source $newRel)) -or $inputC.Contains('CL_CoF_Pad') -or $keys.Contains('CL_CoF_Pad') -or
            $joy.Contains('Joy_CoF_AxisValue') -or $joy.Contains('CL_CoF_NotePadAxis') -or $vgui.Contains('CL_CoF_VCursorPos') -or
            $vgui.Contains('VGui_CoF_PanelAction') -or $hdr.Contains('CL_CoF_Pad') -or $api.Contains('CofPanelAction') -or
            $hostC.Contains('CL_CoF_InputEvent') -or $insdl.Contains('CL_CoF_') -or $pan.Contains('CofPanels_Action') -or
            $app.Contains('CofPanelAction') -or $load.Contains('CMenuSavesListModel::OnActivateEntry') -or
            $opt.Contains('"cof_last_input", "pad"')) {
            throw 'Reversed, but gamepad-input markers remain. Inspect the tree.'
        }
        if (-not $keys.Contains('if( cof_ui_input_gate.value && key == K_ESCAPE && down && cls.key_dest == key_game )')) {
            throw 'Reverse application damaged the input gate this patch sits on.'
        }
        Write-Host "Reversed patches\cof-gamepad-input.patch in $source"
        return
    }

    $ok = $newC.Contains('qboolean CL_CoF_ClickablePanelOpen( void )') -and
          $newC.Contains('classes = CL_CoF_PanelsOnScreen( &reporting );') -and
          $newC.Contains('static CVAR_DEFINE_AUTO( cof_pad_panel_gate, "1", FCVAR_ARCHIVE,') -and
          $newC.Contains('#define COF_PAD_DEFAULTS_GENERATION 3') -and
          $newC.Contains('{ K_DPAD_DOWN,     "weapontoggle" },') -and
          $newC.Contains('Cmd_AddCommand( "cof_duck_toggle", CL_CoF_DuckToggle_f,') -and
          $newC.Contains('Cmd_AddCommand( "cof_sprint_toggle_press", CL_CoF_SprintPress_f,') -and
          $newC.Contains('static CVAR_DEFINE_AUTO( cof_sprint_toggle, "1", FCVAR_ARCHIVE,') -and
          $newC.Contains('static CVAR_DEFINE_AUTO( cof_last_input, "mouse", 0,') -and
          $newC.Contains('qboolean CL_CoF_PadHidesOSCursor( void )') -and
          $newC.Contains('VGui_CoF_PanelAction( COF_VGUI_PANEL_BACK, info, sizeof( info ))') -and
          $newC.Contains('#define COF_VCURSOR_ART "gfx/shell/gamepad/cursor.png"') -and
          $newC.Contains('Cmd_AddRestrictedCommand( "cof_vcursor_test", CL_CoF_VCursorTest_f,') -and
          $newC.Contains('void CL_CoF_VCursorDraw( void )') -and
          $newC.Contains('static CVAR_DEFINE_AUTO( cof_vcursor_size, "44", FCVAR_ARCHIVE,')
    if (-not $ok) { throw 'Applied, but engine\client\input\cof_gamepad.c is missing or incomplete. Inspect the tree.' }

    $ok = $inputC.Contains('CL_CoF_PadInit(); // Cry of Fear gamepad cvars, before config.cfg runs') -and
          $inputC.Contains('if( CL_CoF_PadSuppressMove( ))') -and
          $inputC.Contains('else if ( forwardmove < 0.7f - hyst && ( moveflags & F ))') -and
          $inputC.Contains('if( !CL_CoF_PadFrame( ))')
    if (-not $ok) { throw 'Applied, but the input.c markers are missing. Inspect the tree.' }

    $ok = $keys.Contains('( key == K_ESCAPE || CL_CoF_PadStartAsEscape( key, kb ))') -and
          $keys.Contains('CL_CoF_PadKeyEvent( key, down ))')
    if (-not $ok) { throw 'Applied, but the in_keys.c markers are missing. Inspect the tree.' }

    $ok = $joy.Contains('short Joy_CoF_AxisValue( engineAxis_t axis )') -and
          $joy.Contains('static CVAR_DEFINE_AUTO( joy_gyro_enable, "0",') -and
          $joy.Contains('CL_CoF_NotePadAxis( engineAxis, value );') -and
          $vgui.Contains('if( !CL_CoF_VCursorPos( &x, &y ))') -and
          $vgui.Contains('CL_CoF_VCursorDraw( );') -and
          $vgui.Contains('int VGui_CoF_PanelAction( int action, char *info, int infoSize )') -and
          $hdr.Contains('qboolean CL_CoF_PadFrame( void );') -and
          $hdr.Contains('qboolean CL_CoF_OSCursorRequest( int type );') -and
          $api.Contains('int	(*CofPanelAction)( int action, char *info, int infoSize );') -and
          $hostC.Contains('CL_CoF_InputEvent( event );') -and
          $insdl.Contains('CL_CoF_NoteMouseWarp( x, y );') -and
          $insdl.Contains('SDL_ShowCursor( CL_CoF_OSCursorRequest( type ));')
    if (-not $ok) { throw 'Applied, but the in_joy.c / vgui_draw.c / input.h / vgui_api.h / SDL platform markers are missing. Inspect the tree.' }

    $ok = $pan.Contains('int vgui::CofPanels_Action( int action, char *info, int infoSize )') -and
          $app.Contains('api->CofPanelAction = CofPanels_Action;') -and
          $load.Contains('void CMenuSavesListModel::OnActivateEntry( int line )') -and
          $opt.Contains('EngFuncs::CvarSetString( "cof_last_input", "pad" );')
    if (-not $ok) { throw 'Applied, but the FreeVGUI / MainUI markers are missing. Inspect the tree.' }

    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Applied gamepad-input patch cannot be reverse-checked.' }
} finally {
    Pop-Location
}
Write-Host "Applied patches\cof-gamepad-input.patch in $source"
Write-Host 'Build: python waf build --targets=xash,vgui,menu'
