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
#     the once-per-profile default pad layout (generation 4: A jump, B crouch
#     toggle, X reload, Y use, LB +attack2, RB quick turn, View inventory;
#     cof_pad_defaults, cof_pad_defaults_gen; older generations migrate their
#     untouched keys), the quick turn (cof_quickturn), the trigger hysteresis
#     (cof_pad_trigger_hyst), the left stick shaped like the movement keys
#     (cof_pad_move_mode and friends), the pad styles (cof_pad_style -1 = Auto,
#     cof_pad_style_auto, Nintendo face buttons by position:
#     cof_pad_positional), the sprint toggle (cof_sprint_toggle), the client's
#     WinMM joystick kept off (cof_joy_legacy_off), the crouch toggle
#     (cof_duck_toggle), gyro aiming off by default, the dodge guard
#     (cof_joy_pulse_hysteresis), cof_pad_status, cof_pad_panel_dump and the
#     developer hooks cof_joy_axis_probe / cof_vcursor_test / cof_input_trace /
#     cof_pad_measure / cof_pad_jitter / cof_pad_style_test / cof_pad_virtual.
#   * engine/client/input/input.c: CL_CoF_PadInit in IN_Init, stick suppression
#     and the quick turn in IN_EngineAppendMove, the pulse hysteresis and the
#     movement-key thresholds in IN_JoyAppendMove, the cursor frame in
#     Host_InputFrame.
#   * engine/client/input/in_keys.c: START in the cof_ui_input_gate Escape
#     bypass; pad keys on an open panel routed before the client sees them.
#   * engine/client/input/in_joy.c: the Joy_CoF_AxisValue / Joy_CoF_AxisRaw
#     accessors; joy_gyro_enable defaults to 0; a deflected axis marks the pad
#     as the last input device; trigger hysteresis in Joy_ProcessTrigger; the
#     stick movement shape in Joy_FinalizeMove.
#   * engine/client/vgui/vgui_draw.c/.h: VGUI_GetMousePos reads the gamepad
#     cursor; VGui_Paint draws it last; VGui_CoF_PanelAction.
#   * engine/vgui_api.h: vguiapi_t::CofPanelAction + COF_VGUI_PANEL_*.
#   * engine/platform/sdl2/host_sdl2.c: every SDL event goes past
#     CL_CoF_InputEvent (the last input device); the event loop's time and
#     count for cof_pad_measure.
#   * engine/platform/sdl2/joy_sdl2.c: SDL_GAMECONTROLLER_USE_BUTTON_LABELS 0 at
#     init (Nintendo face buttons by position); the pad in use reported to
#     CL_CoF_PadActivated (pad style); an axis makes its pad the active one only
#     past 8000 of 32767.
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
$sdljRel = 'engine\platform\sdl2\joy_sdl2.c'
$panRel   = '3rdparty\freevgui\platform\xash3d-fwgs\cofpanels.cpp'
$appRel   = '3rdparty\freevgui\platform\xash3d-fwgs\app.cpp'
$loadRel  = '3rdparty\mainui\menus\LoadGame.cpp'
$optRel   = '3rdparty\mainui\menus\CoFOptions.cpp'
foreach ($relative in @($inputRel, $keysRel, $joyRel, $vguiRel, $hdrRel, $apiRel, $hostRel, $insdlRel, $sdljRel, $appRel, $loadRel)) {
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
    $sdlj   = Slurp $sdljRel
    $pan    = Slurp $panRel
    $app    = Slurp $appRel
    $load   = Slurp $loadRel
    $opt    = Slurp $optRel

    if ($Reverse) {
        if ((Test-Path -LiteralPath (Join-Path $source $newRel)) -or $inputC.Contains('CL_CoF_Pad') -or $keys.Contains('CL_CoF_Pad') -or
            $joy.Contains('Joy_CoF_AxisValue') -or $joy.Contains('CL_CoF_NotePadAxis') -or $vgui.Contains('CL_CoF_VCursorPos') -or
            $vgui.Contains('VGui_CoF_PanelAction') -or $hdr.Contains('CL_CoF_Pad') -or $api.Contains('CofPanelAction') -or
            $hostC.Contains('CL_CoF_InputEvent') -or $hostC.Contains('CL_CoF_NoteEventLoop') -or $insdl.Contains('CL_CoF_') -or $sdlj.Contains('CL_CoF_') -or $pan.Contains('CofPanels_Action') -or
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
          $newC.Contains('#define COF_PAD_DEFAULTS_GENERATION 4') -and
          $newC.Contains('{ K_R1_BUTTON,     "cof_quickturn" },   // quick 180-degree turn') -and
          $newC.Contains('{ K_BACK_BUTTON,   "+inventory" },      // View: opens and closes the inventory') -and
          $newC.Contains('static const cof_pad_bind_t cof_pad_layout_gen3[] =') -and
          $newC.Contains('Cmd_AddCommand( "cof_quickturn", CL_CoF_QuickTurn_f,') -and
          $newC.Contains('static CVAR_DEFINE_AUTO( cof_pad_trigger_hyst, "0.1", FCVAR_ARCHIVE,') -and
          $newC.Contains('static CVAR_DEFINE_AUTO( cof_pad_move_mode, "1", FCVAR_ARCHIVE,') -and
          $newC.Contains('CVAR_DEFINE_AUTO( cof_pad_style, "-1", FCVAR_ARCHIVE,') -and
          $newC.Contains('static CVAR_DEFINE_AUTO( cof_pad_style_auto, "0", FCVAR_READ_ONLY,') -and
          $newC.Contains('static int CL_CoF_StyleForPad( int type, int vid, int pid, const char *name, qboolean deck_env, const char **why )') -and
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
          $inputC.Contains('else if ( forwardmove < fthr - hyst && ( moveflags & F ))') -and
          $inputC.Contains('CL_CoF_PadMoveKeyThresholds( &fthr, &sthr );') -and
          $inputC.Contains('yaw += CL_CoF_QuickTurnYaw( );') -and
          $inputC.Contains('if( !CL_CoF_PadFrame( ))')
    if (-not $ok) { throw 'Applied, but the input.c markers are missing. Inspect the tree.' }

    $ok = $keys.Contains('( key == K_ESCAPE || CL_CoF_PadStartAsEscape( key, kb ))') -and
          $keys.Contains('CL_CoF_PadKeyEvent( key, down ))')
    if (-not $ok) { throw 'Applied, but the in_keys.c markers are missing. Inspect the tree.' }

    $ok = $joy.Contains('short Joy_CoF_AxisValue( engineAxis_t axis )') -and
          $joy.Contains('static CVAR_DEFINE_AUTO( joy_gyro_enable, "0",') -and
          $joy.Contains('CL_CoF_NotePadAxis( engineAxis, value );') -and
          $joy.Contains('if( trigButton && CL_CoF_TriggerHysteresis( ) > 0.0f )') -and
          $joy.Contains('if( !CL_CoF_PadMoveShape( fw, side, joy_forward.value, joy_side.value ))') -and
          $joy.Contains('short Joy_CoF_AxisRaw( engineAxis_t axis )') -and
          $vgui.Contains('if( !CL_CoF_VCursorPos( &x, &y ))') -and
          $vgui.Contains('CL_CoF_VCursorDraw( );') -and
          $vgui.Contains('int VGui_CoF_PanelAction( int action, char *info, int infoSize )') -and
          $hdr.Contains('qboolean CL_CoF_PadFrame( void );') -and
          $hdr.Contains('qboolean CL_CoF_OSCursorRequest( int type );') -and
          $api.Contains('int	(*CofPanelAction)( int action, char *info, int infoSize );') -and
          $hostC.Contains('CL_CoF_InputEvent( event );') -and
          $hostC.Contains('CL_CoF_NoteEventLoop( Sys_DoubleTime( ) - cof_t0, cof_events );') -and
          $sdlj.Contains('SDL_SetHint( SDL_HINT_GAMECONTROLLER_USE_BUTTON_LABELS, "0" );') -and
          $sdlj.Contains('CL_CoF_PadActivated( g_current_gamepad );') -and
          $insdl.Contains('CL_CoF_NoteMouseWarp( x, y );') -and
          $insdl.Contains('SDL_ShowCursor( CL_CoF_OSCursorRequest( type ));')
    if (-not $ok) { throw 'Applied, but the in_joy.c / vgui_draw.c / input.h / vgui_api.h / SDL platform (host, input, joystick) markers are missing. Inspect the tree.' }

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
