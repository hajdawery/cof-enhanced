# Gamepad input (`cof-gamepad-input`)

Round 4 adds [updated controls](cof-gamepad-controls.md) after this base patch:
RB dodge, R3 quick turn and pad-only double-tap suppression. The base-patch
history below describes generation 4. For missing cursor/controller pictures,
see the [art delivery repair](cof-gamepad-art-delivery.md).

Patch: `patches/cof-gamepad-input.patch` (engine, plus small FreeVGUI and
MainUI hunks since the gamepad2 round: `xash.dll`, `vgui.dll` and `menu.dll`
go together; a new `vguiapi_t` entry).
Script: `scripts/apply-cof-gamepad-input.ps1` (`-SourceRoot <tree>`, `-Reverse`).
Data: the pad lines in `gamedata/cryoffear/gfx/shell/kb_def.lst`; the cursor
art `gamedata/cryoffear/gfx/shell/gamepad/cursor.png`.
Stack position: step 57 of `docs/dev/patch-stack.md` (since m9), after the
on-screen keyboard steps 49-52, the quick save steps 53-54 (its `LoadGame.cpp`
hunks use lines of step 54 as context; regenerated in m9, offsets only) and
the panel patches 55-56, before the round-4 follow-ups (58-59) and `cof-cheats` (63, the last step). Needs `cof-ui-input-gate`, `cof-console-style`, `cof-ads-toggle`,
`cof-ui-scale`, `cof-mainui-options-layout`, `cof-panel-pause` and
`cof-panel-transparency` (the script checks their markers).

FWGS already reads gamepads through SDL2's GameController API
(`platform/sdl2/joy_sdl2.c`, `client/input/in_joy.c`): sticks move and turn,
buttons are keys (`A_BUTTON`, `LTRIGGER`...), the engine menu is usable with a
pad. What Cry of Fear needed on top is in the new file
`engine/client/input/cof_gamepad.c`, with small hooks in `input.c`,
`in_keys.c`, `in_joy.c`, `vgui_draw.c`/`.h`, `vgui_api.h`, `input.h`, the SDL2
platform files `host_sdl2.c`, `in_sdl2.c` and `joy_sdl2.c`; the panel buttons in the VGUI
support library (`3rdparty/freevgui/platform/xash3d-fwgs/cofpanels.cpp`,
`support.h`, `app.cpp`); two MainUI hunks (`menus/LoadGame.cpp`,
`menus/CoFOptions.cpp`).

## 1. "A clickable Cry of Fear panel is open"

`CL_CoF_ClickablePanelOpen()`: in play (`ca_active`, `key_game`, not the
background map) **and** a modal Cry of Fear panel is on screen.

**One source of truth (m8).** The panel is identified by its client class
name, the same report the panel pause uses
([`cof-panel-pause`](cof-panel-pause.md), step 55): the VGUI support library
names every visible client panel each painted frame, and
`CL_CoF_PanelsOnScreen()` (declared in `engine/common/common.h`) hands the
engine its `COF_PANEL_*` bits (the HUD container left out). Any bit = a panel
is open. The arrow cursor below is kept **only as the fallback**: it counts
when the class list names nothing, i.e. a panel class the list does not know
(a future client) or a `vgui.dll` without the panel report.
`cof_input_trace 1` prints "panel open by the arrow cursor only" whenever the
fallback is what engaged, and `cof_pad_status` shows the class bits behind the
answer (`panel classes 0x1` = inventory; ", cursor fallback" when it came from
the cursor). Measured in m8: inventory open -> `panel classes 0x1`, no
fallback, the same frame the panel pause went on.

The fallback signal: the client's
`TeamFortressViewport::UpdateCursorState` (client `100AAAD0`) turns the arrow on
for exactly its clickable panels (inventory, notes, documents list, user
documents, keypad, phone, landline, computer, padlock, puzzle bar, tape-recorder
page, save confirm, YES/NO, statue, billboard, clothes...) and off otherwise;
FreeVGUI re-applies it every painted frame and the engine records it in
`host.mouse_visible` (`Platform_SetCursorType`). No client offsets, no hash gate.
The telescope, cutscene masks, HUD and subtitles show no arrow and are not
"panels" here. Other code can call the function (declared in `input.h`).
The gamepad patch therefore goes on after the panel pause (stack step 57,
after 55-56); its apply script refuses a tree without `CL_CoF_PanelsOnScreen`.

While it holds and `cof_pad_panel_gate` is 1:

| input | on an open panel |
| --- | --- |
| left / right stick | do **not** move or turn the player (`IN_EngineAppendMove` returns after releasing any `+forward`... the stick was holding); they move the panel cursor instead (section 3) |
| gyro (when `joy_gyro_enable` is on) | ignored, same as the sticks |
| `START` (bound to `cancelselect`) | gets the Escape bypass of `cof_ui_input_gate`: the engine pause menu opens, the panel does not see the key |
| close key (`cof_pad_close_key`, default `B_BUTTON`) | **backs out of the panel** (section 1b): the support library clicks the panel's own Back / Close / Cancel / No button; the inventory is handed to the client as `pfnKey_Event(down, key, "+inventory")` (its key handler, client `10044040`, closes it for exactly that binding string); a panel without a known button gets the game's own Escape handling (`pfnKey_Event(ESCAPE, "cancelselect")`, what retail Escape did before the input gate sent Escape to the engine menu). Nothing is typed |
| click keys (`cof_vcursor_click_key` `A_BUTTON`, `cof_vcursor_rclick_key` `X_BUTTON`) | left / right mouse button at the panel cursor (`VGui_MouseEvent`, the path a real click takes in `key_game`); an A on a tape recorder slot is followed by the page's second click (section 1b) |
| every other pad key | unchanged: offered to the client, which swallows it on most panels, as with the keyboard |

A captured press is remembered, so its release does the matching thing even
if the panel closed or the pause menu opened in between. Keyboard and mouse
take none of these paths.

## 1b. B backs out of every panel; A completes a tape recorder pick

Every button of the client's in-play panels is a `vgui::Button` (the
support library's class; the client derives `ColorButton`, `CommandButton`
from it) carrying one ActionSignal of the panel's own handler class,
`C<Panel>Handler_Command { vtable, panel, command }`, whose `actionPerformed`
calls the panel's `ActionSignal( command )` switch. The switches were read
from the shipped client.dll (`stage1/gamepad2-20260923/tools/switches.txt`);
the table names the command whose case hides the panel the way its own
Back / Close / Cancel / No button does. `vguiapi_t::CofPanelAction(
COF_VGUI_PANEL_BACK )` finds the open panel by class (dialogs first), then the
visible button whose handler has that class and command (the class of a
button and of a handler read from MSVC run-time type information, every
pointer checked, no client address), and fires it with `Button::doClick`,
which runs the same ActionSignals as a mouse click.

| panel (class) | handler class | command | what it does | measured |
| --- | --- | --- | --- | --- |
| save confirm (`CSave`) | `CSaveHandler_Command` | 3, else 1 | No / Cancel (`unfreeze 1024` / `unfreeze 666`) | not opened from a cfg |
| YES/NO (`CYesno`) | `CYesnoHandler_Command` | 3 | No (`yesnono %i`, save_no.wav) | yes |
| notes list (`CDocuments`) | `CDocumentsHandler_Command` | 25 | back to the inventory | see RESULTS |
| note (`CNoteDocument`) | `CNoteDocumentHandler_Command` | 3 | close (hide all, `closedocument`) | yes |
| user document (`CUserDocument`) | `CUserDocumentHandler_Command` | 1 | close (hide all, `closedocument`) | no entity found |
| tape recorder page (`CSaveLoad`) | `CSaveLoadHandler_Command` | 1 | Cancel | yes |
| billboard (`CVGUIBillboard`) | `CBillboardHandler_Command` | 1 | close | yes |
| keypad (`CKeypad`) | `CKeypadHandler_Command` | 1 | close (the X) | yes |
| padlock (`CPadlock`) | `CPadlockHandler_Command` | 5 | Cancel (`padlockcancel`) | yes |
| landline (`CTelephone`) | `CTelephoneHandler_Command` | 12 | hang up (the X) | yes |
| computer (`CComputer`) | `CComputerHandler_Command` | 2 | close | yes |
| boiler puzzle (`CPuzzleBar`) | `CPuzzleBarHandler_Command` | 5 | close (`boilercheck 5`) | yes |
| animal statue (`CAnimalStatue`) | `CAnimalStatueHandler_Command` | 1 | close | no entity found |
| clothes (`CClothesMenu`) | `CClothesMenuHandler_Command` | 13 | close (`closeclothes`) | not in play |
| text window (`CParanoiaTextPanel`) | `CMenuHandler_TextWindow` (state at +4) | 0 | hide | not opened |
| inventory (`CRECBInventory`) | - | - | engine: its `+inventory` binding | yes |
| phone (`CPhone`) and anything unknown | - | - | engine: the game's own Escape handling | not opened |

**Tape recorder page.** The page acts on a slot only on a **double click**:
each slot's handler compares the client clock with a per-slot time stamp and
sets a new one 0.5 s ahead (client `100316BD`). A mouse user double-clicks; a
gamepad A used to do nothing visible. After an A release the engine calls
`CofPanelAction( COF_VGUI_PANEL_CONFIRM )`: when the click landed on a slot
button of a still-visible `CSaveLoad` (handler `CSaveLoadHandler_Command`,
commands 2-6), the library clicks it once more, so pick slot, A, and the game
saves (or loads, in its load mode) through its own path (hide, `unfreezesave
1024 N`, the client's `savehack cofsaveN` 3.25 s of client time later). The
mouse path is untouched.

`cof_pad_panel_dump` lists the buttons of the open panels with their handler
class and command (the evidence behind the table); `cof_vcursor_test button
<handler class> <command> [0|1|2]` puts the gamepad cursor on such a button
(test hook).

## 2. Default layout and binds

The game's `config.cfg` starts with `unbindall`, which removes the engine's
built-in (Half-Life) pad binds. Once per profile, when `config.cfg` has run,
the engine checks `cof_pad_defaults_gen` (archived, 0 on a profile that never
had it) against the current layout generation, **4** (gamepad3 round, 2026-09-24):

* **no** pad key bound (START's `cancelselect`, which `unbindall` itself
  restores, does not count): the layout below is bound;
* generation 1 (the first staging of this patch), 2 (m8) or 3 (gamepad2):
  every pad key that still holds exactly its bind of that generation moves to
  the layout below (generation 3 -> 4: X `+use` -> `+reload`, Y `+inventory` ->
  `+use`, LB `+reload` -> `+attack2`, RB `+attack2` -> `cof_quickturn`, View
  `+objectives` -> `+inventory`; 2 -> 3 was D-pad down `flashlight` ->
  `weapontoggle`, L3 `+sprint` -> `cof_sprint_toggle_press`); a key the player
  rebound or cleared keeps what it has;
* otherwise (the player bound pad keys by hand) nothing is touched.

Every profile below generation 2 also gets `joy_gyro_enable 0` once (gyro
aiming is opt-in, see below); a generation-2 profile had that already. Then the generation is set, so the check never
runs again for that profile; the binds are written into `config.cfg` with the
rest at the next save. `cof_pad_defaults` (`force` to overwrite, `list` to
compare) does it by hand; Options > Keybinds > Use defaults restores the same
layout from `kb_def.lst`.

The engine key names are **positions**: `A_BUTTON` is the bottom face button,
`B_BUTTON` the right one, `X_BUTTON` the left one, `Y_BUTTON` the top one, on
every pad - Nintendo pads included (section 2d) - so the layout is positional.

| position (Xbox / PlayStation / Nintendo / Steam Deck) | engine key | in play | bind | on an open panel |
| --- | --- | --- | --- | --- |
| left stick | axes | move (shaped like the keys, section 2c) | (engine axis) | panel cursor |
| right stick | axes | look | (engine axis) | panel cursor |
| RT / R2 / ZR / R2 | `RTRIGGER` | attack | `+attack` | |
| LT / L2 / ZL / L2 | `LTRIGGER` | aim down sights (Hold/Toggle per `cof_ads_toggle`) | `+attack3` | |
| bottom: A / Cross / B / A | `A_BUTTON` | jump | `+jump` | left click |
| right: B / Circle / A / B | `B_BUTTON` | crouch, **toggle** | `cof_duck_toggle` | backs out of the panel |
| left: X / Square / Y / X | `X_BUTTON` | reload | `+reload` | right click |
| top: Y / Triangle / X / Y | `Y_BUTTON` | use / interact | `+use` | |
| LB / L1 / L / L1 | `L1_BUTTON` | secondary attack: bash, weapon mode, the light of the flashlight and phone weapons (the MOUSE3 action) | `+attack2` | |
| RB / R1 / R / R1 | `R1_BUTTON` | quick 180-degree turn (section 2a) | `cof_quickturn` | (ignored) |
| left stick click (L3) | `STICK1` | sprint, Toggle or Hold (`cof_sprint_toggle`) | `cof_sprint_toggle_press` | |
| right stick click (R3) | `STICK2` | crouch while held | `+duck` | |
| d-pad up / left / right | `DPAD_UP` / `DPAD_LEFT` / `DPAD_RIGHT` | quick slot 1 / 2 / 3 | `quicksel 1..3` | |
| d-pad down | `DPAD_DOWN` | toggle weapon function (the game's `weapontoggle`, kb_act "Toggle weapon function", keyboard Z) | `weapontoggle` | |
| View / Create / - / View | `BACK` | inventory, opens and closes it (the game's own key check) | `+inventory` | closes the inventory |
| Menu / Options / + / Menu | `START` | pause menu | `cancelselect` | pause menu |

The objective (`+objectives`, keyboard B) is not bound by default.
Weapons come from the inventory and the quick slots; the shoulder buttons do
not switch weapons. Not bound by default (Keybinds page): `+objectives`, `+dodge`,
`flashlight` (keyboard F; kb_act calls it "Flashlight (coop only)"; RB's
`+attack2` switches the light of the flashlight and phone weapons),
`invprev`/`invnext`. A dodge also works as on the keyboard:
flick the left stick twice in a direction (section 4). `MODE` (Xbox guide / PS
button; Windows' Game Bar usually takes the Xbox one), `TOUCHPAD` (DualSense
touchpad click) and `MISC_BUTTON` (DualSense mic button) are free.

**Crouch toggle** (`cof_duck_toggle`, B's default): the first press crouches,
the next stands up. It is an engine-side latch on the game's own `+duck`: the
engine holds `+duck` for you (queued at the head of the command buffer, like a
held key) and sends `-duck` on the second press. In play only (`key_game`,
connected, not the background map; on a panel B closes the inventory instead).
The latch is released on its own at every level change and every load (the
server count changes or the client leaves the active state), so a new map
never starts crouched; `-duck` without a key number releases every holder, so
R3 held at that moment is released too.

**Sprint** (`cof_sprint_toggle_press`, L3's default): with `cof_sprint_toggle
1` (saved, the default) the first press holds the game's own `+sprint` (queued
at the head of the command buffer without a key number, like the crouch
toggle) and it lets go by itself when the player stops moving: the left stick
below `cof_sprint_stop_threshold` (0.2 of full deflection) with no key bound
to `+forward`/`+back`/`+moveleft`/`+moveright` held, for
`cof_sprint_stop_time` (0.15 s) and at least 3 frames; a press while standing
still lets go when no movement starts within 0.75 s. A second press lets go
too, and so do a panel or a menu opening, every load and every level change.
With `cof_sprint_toggle 0` L3 sprints while it is held, as before. The
keyboard keeps its plain `+sprint` (SHIFT) unless the player binds the command
to a key, which then follows the same setting.

**Gyro aiming** (DualSense and other pads with a gyroscope): `joy_gyro_enable`
now defaults to 0 (upstream: 1), and profiles below generation 2 get it set to
0 once. The options worker's Controls page offers it; sensitivity
`joy_gyro_yaw` / `joy_gyro_pitch` (1.0 each, multipliers of the pad's rotation
speed), `joy_gyro_roll` (0; a sideways tilt added to turning), deadzones
`joy_gyro_*_deadzone` (0.5 deg/s), command `joy_calibrate_gyro` (pad lying
still for 5 s; the engine also calibrates on its own when a pad connects).

The game's hint texts ("Press TAB to...") still name keyboard keys: the client
reads the first matching `bind` line of `config.cfg` itself, and keyboard lines
come first. Pad glyphs in hints are a later stage.

The client's own WinMM joystick code (stock Half-Life, cvar `joystick`) is kept
at 0 whenever the client is loaded (`cof_joy_legacy_off`, default 1; checked
twice a second), so an XInput pad is never read twice; the engine's SDL pad is
the only source.

## 2a. Quick turn (`cof_quickturn`, RB)

A smooth 180-degree turn over `cof_quickturn_time` seconds (0.18, archived,
0.05..1), eased in and out (smoothstep sampled at the accumulated time, so the
frame steps always add up to exactly 180 degrees). The yaw is added in
`IN_EngineAppendMove`, the path the right stick turns the player with, after
the client built its command, so it does not fight the client's own view
handling or the aim down sights. Ignored outside play, while a panel or a menu
is open, and while a turn runs; a level change or a load drops a turn in
progress. `cof_quickturn` is a plain command, bindable to any key (Keybinds
row for the options worker: `"cof_quickturn" "Quick turn"`). Measured
(gamepad3 round): 180.0 degrees in 0.180-0.184 s at 200-240 fps, 0.401 s with
`cof_quickturn_time 0.4`; RB (the generation-4 bind) turns; a second press
while turning is ignored; with the inventory open: "ignored: a panel is open".

## 2b. Triggers: one key edge per pull (`cof_pad_trigger_hyst`)

The engine's `Joy_ProcessTrigger` pressed `LTRIGGER` / `RTRIGGER` when the
value crossed `joy_lt_threshold` / `joy_rt_threshold` (16384 = half a pull)
upwards and released it when it crossed downwards. A finger resting near the
threshold therefore produced a key edge for every jitter of the analogue
value, and with the default Toggle the aim down sights flipped on every press
(measured: LT moving between 16000 and 16800 every frame = 958 key events in
3 s, the zoom ending wherever the last accepted toggle left it). Now a pulled
trigger is a state with hysteresis: pressed above threshold +
`cof_pad_trigger_hyst` x 32767, released below threshold - that (0.1:
press above 0.6, release below 0.4 of the pull); the same jitter gives no key
event at all, a jitter across the press point exactly one. `0` restores the
plain threshold. The menu's trigger-threshold slider still moves the centre.

## 2c. The left stick shaped like the movement keys (`cof_pad_move_mode`)

Measured (c_forest3, `cof_pad_measure`, every case out and back along the
same line; u/s = units per second):

| input | mode 0 (engine) | mode 1 (default) | keyboard |
| --- | ---: | ---: | ---: |
| straight, full | 225.0 | 225.0 | 225.0 (+forward) |
| diagonal 45 degrees, full | **132.3** | **225.0** (187.5 with `cof_pad_move_diagonal 1`) | 187.5 (+forward +moveright) |
| diagonal, 75 % push | 99.4 | 225.0 | |
| diagonal, 50 % push | 65.8 | 145.4 (below the walk threshold) | |
| straight, 50 % push | 112.5 (m0 C in round 1) | 174.7 | |
| sideways, full | 150.0 | 150.0 | |
| sprint straight, full | 300.0 | 300.0 | 300.0 |
| sprint diagonal, full | 265.0 | 300.0 | 300.0 |
| 30 degrees, full, mode 2 (8-way) | | 187.5 (snapped to 45; 225 with the boost) | |

Cry of Fear walks at a speed that depends on the direction (straight 225,
sideways 150, diagonal 187.5 with keys) times the LARGER of forwardmove /
sidemove over the full value, capped at the straight speed; sprinting runs
straight ahead at 300 whatever the side input. The engine's round stick sends
0.71 / 0.71 at 45 degrees, so it walked at 187.5 x 0.71 = 132 - the lost
momentum. Mode 1 ("digital-style", the default): a radial deadzone
(`cof_pad_move_deadzone` 0.15); from `cof_pad_move_walk` (0.6) on the stick
counts as fully pushed in its direction, mapped onto the keys' square (45
degrees = full forward AND full side, like two held keys); below that the
player walks slower along `cof_pad_move_curve` (1 = linear from the deadzone
to the walk threshold); then `cof_pad_move_diagonal` (1.2 = 225 / 187.5) lifts
the diagonals to the straight speed - it grows with the smaller component, so
straight and pure sideways stay the keyboard's, and the game's cap keeps
straight at 225 (measured: 1.2 on a straight push is still 225.0). The
+forward/+back/+moveleft/+moveright keys the engine presses for the stick
follow the direction's sector once the stick counts as fully pushed (both keys
on a diagonal), none below. Mode 2 snaps the direction to 8; mode 0 is the
engine's own proportional stick (0.7 / 0.9 key thresholds).

## 2d. Pad styles, Nintendo and Steam Deck (`cof_pad_style`, `cof_pad_style_auto`, `cof_pad_positional`)

`cof_pad_style` (archived, **-1** = Auto, the string `auto` too; 0 Xbox, 1
PlayStation, 2 Nintendo, 3 Steam Deck by hand) is registered by the engine;
the menu shows the pictures of that style, or of `cof_pad_style_auto`
(read-only, 0..3) when it is Auto. `cof_pad_style_auto` is the style of the
pad in use - the one that sent the last button or a stick/trigger push past
8000 of 32767 (`joy_sdl2.c`; an idle second pad's resting noise no longer
takes the active role) - and updates when pads connect and disconnect (the
first remaining game controller stands in after the active one goes; 0
without any pad). `cof_pad_type` (read-only) holds the same as a style id.
Detection (`CL_CoF_StyleForPad`), in this order: name "Steam Deck" or Valve
28DE:1205 (the Deck's built-in controller through SDL's HIDAPI driver) ->
Steam Deck; SDL type PS3/PS4/PS5 -> PlayStation; SDL type
NINTENDO_SWITCH_PRO / JOYCON_LEFT / JOYCON_RIGHT / JOYCON_PAIR -> Nintendo
(the 8BitDo Ultimate in Switch mode presents itself as a Pro Controller,
057E:2009); Nintendo vendor 057E or a Nintendo name -> Nintendo; Valve 28DE
(Steam Input's virtual gamepad) with `SteamDeck=1` in the environment (Steam
sets it in the Deck's game mode) -> Steam Deck (when Steam tells SDL through
`SteamVirtualGamepadInfo` that a PlayStation or Nintendo pad is behind the
virtual one, SDL reports that type and it wins); anything else -> Xbox.

**Positions, not labels.** SDL 2's default for Nintendo pads is to report
the face buttons by their printed label (hint
`SDL_GAMECONTROLLER_USE_BUTTON_LABELS` = 1), which puts the Nintendo "B" -
the bottom button - on `B_BUTTON`. The engine sets the hint to 0 before the
game-controller subsystem starts (`joy_sdl2.c`) and follows
`cof_pad_positional` (archived, default 1; 0 = by label) at run time: SDL's
HIDAPI Switch driver (Pro Controller, Joy-Cons, pads in Switch mode) watches
the hint with a callback (SDL 2.30.9 headers and the
`release-2.30.x` source of `SDL_hidapi_switch.c`: `RemapButton` swaps A/B and
X/Y only while labels are wanted). So `A_BUTTON` is the bottom button on every
pad, and the layout, the menus (A select / B back), the on-screen keyboard and
the panels agree without a second remap. SDL 2.30 has no
`SDL_GameControllerGetButtonLabel` (that is SDL 3); the prompts take the
printed letter from `icons.txt`: a Nintendo pad's `A_BUTTON` shows the Xbox
"B" glyph at the bottom of the Joy-Con picture, `B_BUTTON` the "A" on the
right, `X_BUTTON` "Y", `Y_BUTTON` "X".

**Steam Deck labels** (Valve's own names; SDL 2.30 `SDL_hidapi_steamdeck.c`):
A/B/X/Y in the Xbox positions; bumpers L1/R1 (`L1_BUTTON`/`R1_BUTTON`),
analogue triggers L2/R2 (`LTRIGGER`/`RTRIGGER`), stick clicks L3/R3; View
(two rectangles, `BACK`) upper left, Menu (three lines, `START`) upper right;
STEAM below the left trackpad (`MODE`, the guide button) and Quick Access
"..." below the right one (`MISC_BUTTON`, SDL's MISC1); back grips L4/L5
(upper/lower left) and R4/R5 (upper/lower right) = SDL `PADDLE2`/`PADDLE4` and
`PADDLE1`/`PADDLE3`. In the Deck's game mode Steam Input keeps STEAM and
"..." for itself and passes the grips only if the controller template maps
them.

Art and the per-style rows: `gfx/shell/gamepad/switch/`, `steamdeck/`,
`icons.txt` (format in its header), `LICENSE-NOTE.md`;
`scripts/make-gamepad-style-art.py` rebuilds them from haej's originals.
## 3. The panel cursor (virtual cursor)

While a clickable panel is open, the stick pushed further (left or right)
moves an engine-side cursor: speed `cof_vcursor_speed` screen heights per
second at full deflection, response exponent `cof_vcursor_curve` (fine control
near the centre), plus `cof_vcursor_accel` extra speed ramped in over
`cof_vcursor_accel_time` seconds of continuous motion; `cof_vcursor_deadzone`
on top of the engine's stick deadzone. The position goes to FreeVGUI through
both of its paths: pushed with `VGui_MouseMove` and pulled by
`VGUI_GetMousePos` (overridden while the pad owns the pointer, so it never
depends on when SDL catches up with a warp); the OS cursor is warped to match
(`cof_vcursor_warp`). While the pad owns the pointer, the real mouse position
is not pushed over it; moving the real mouse hands the pointer back. The
`cof_ui_scale` transform needs no change (both paths already apply its
inverse). `joy_enable 0` switches all of this off.

**Look.** While the pad owns the pointer the OS arrow is hidden
(`SDL_ShowCursor`, the cursor *type* and `host.mouse_visible` stay as the client
set them, so the panel check is unaffected) and the engine draws its own
cursor at the end of `VGui_Paint`, over the panels: the user's art
`gfx/shell/gamepad/cursor.png` (a white square frame with an inner line, a
centre dot and a soft glow; 128x128 RGBA, made from the user's 1254 px
original by `stage1/gamepad2-20260923/art/make-cursor.py`: centred crop,
premultiplied Lanczos), loaded once as a mipmapped texture, with a black
shadow made in code from the same picture (its alpha spread over w/40 px and
blurred) drawn under it at `cof_vcursor_shadow` (0.7) so the white frame stays
visible on the white note pages. Centred on the cursor position; size
`cof_vcursor_size` (44 px at UI scale 1, times the in-game UI scale: 66 px at
1080p with the HUD scale at 150 percent), opacity `cof_vcursor_alpha` (0.85);
it shrinks to 85 percent while the click key is held. Without the file the
drawn ring of the first round is used (`CL_CoF_VCursorTexture`). Moving the
real mouse brings the OS arrow back and hides the gamepad cursor.

**The last input device** (`cof_last_input`: `pad`, `mouse` or `keyboard`, not
saved) is taken from the SDL events themselves (`CL_CoF_InputEvent`, first
thing in `SDLash_EventHandler`): a controller button or a stick/trigger past
12000 of 32767 is the pad (the gyro and touchpad reports are not); a real key
press is the keyboard (the arrow keys the engine makes from the stick in the
menus never pass there, so moving the menu focus with the stick keeps the
pad); a mouse button, the wheel, or 6 pixels of real motion within half a
second is the mouse (the motion SDL reports for the engine's own warps,
`Platform_SetMousePos` -> `CL_CoF_NoteMouseWarp`, is left out). A deflected
axis also counts through `Joy_AxisMotionEvent` (so `cof_joy_axis_probe` does),
and the menu marks the cvar `pad` for every gamepad key it receives (so
`menu_cof_key` does). The menu shows its button prompts while it reads `pad`
(`UI_CoFPadMode` prefers this cvar). While it is `pad`
(`cof_pad_hide_cursor` 1), `Platform_SetCursorType` asks
`CL_CoF_OSCursorRequest` before it shows the arrow the client (a panel) or the
menu (`pfnSetCursor`, `IN_ToggleClientMouse` on opening the menu) asks for,
and keeps it hidden from that very call: the arrow never appears for a frame
when the inventory, a panel, the pause menu (START) or any menu window opens.
A panel opened with the pad as the last device gets the gamepad cursor at
once, in the middle of the screen (where every CoF panel is), without waiting
for the stick; after the mouse had the panel, the stick picks up where the
arrow is. The mouse or a key brings the arrow back
(`CL_CoF_ApplyOSCursor`, once per frame; it only shows an arrow this file
hid). The gamepad cursor is drawn only in `key_game` and never while the
on-screen keyboard is open over the game (`cof_osk_over_game`, looked up by
name so the file does not depend on that patch).

## 4. Dodge guard

The engine turns a stick past 0.7 (forward/back) or 0.9 (sideways) into
`+forward`/`+back`/`+moveleft`/`+moveright` presses, and the client dodges when
such a key is pressed twice within 0.18 s (`cl_nodoubletapdodge 0`, the game's
default). A stick resting near the threshold used to press and release every
few frames and dodge on its own. A pressed key is now released only when the
stick falls `cof_joy_pulse_hysteresis` (default 0.25) below the level that
pressed it. A deliberate double flick through the centre still dodges.
`cl_nodoubletapdodge 1` turns double-tap dodging off entirely (keyboard too).

## 5. Cvars and commands

| name | default | saved | meaning |
| --- | --- | --- | --- |
| `cof_pad_panel_gate` | 1 | yes | section 1 on/off |
| `cof_pad_close_key` | `B_BUTTON` | yes | key that backs out of an open panel (section 1b); empty = off |
| `cof_vcursor` | 1 | yes | panel cursor on/off (also the A/X clicks) |
| `cof_vcursor_speed` | 0.9 | yes | screen heights per second at full deflection |
| `cof_vcursor_accel` | 1.5 | yes | extra speed after `cof_vcursor_accel_time` (1.5 = up to 2.5x) |
| `cof_vcursor_accel_time` | 0.6 | yes | seconds to full acceleration |
| `cof_vcursor_curve` | 2 | yes | response exponent |
| `cof_vcursor_deadzone` | 0.2 | yes | stick deadzone for the cursor |
| `cof_vcursor_warp` | 1 | yes | move the (hidden) OS cursor too |
| `cof_vcursor_size` | 44 | yes | cursor size in pixels at UI scale 1 |
| `cof_vcursor_alpha` | 0.85 | yes | cursor opacity |
| `cof_vcursor_shadow` | 0.7 | yes | opacity of the dark shadow under the cursor art |
| `cof_pad_hide_cursor` | 1 | yes | hide the Windows arrow in menus and over panels while the pad is the last input device |
| `cof_last_input` | `mouse` | no | the last input device: `pad`, `mouse`, `keyboard` (read by the menu) |
| `cof_sprint_toggle` | 1 | yes | L3 / `cof_sprint_toggle_press`: 1 = Toggle, 0 = Hold |
| `cof_sprint_stop_threshold` | 0.2 | yes | left-stick deflection below which the toggled sprint counts the player as stopped |
| `cof_sprint_stop_time` | 0.15 | yes | seconds stopped before the toggled sprint lets go |
| `cof_vcursor_click_key` | `A_BUTTON` | yes | left click key |
| `cof_vcursor_rclick_key` | `X_BUTTON` | yes | right click key |
| `cof_joy_pulse_hysteresis` | 0.25 | yes | section 4, 0..0.6 |
| `cof_joy_legacy_off` | 1 | yes | keep the client's `joystick` at 0 |
| `cof_pad_defaults_gen` | 0 | yes | layout generation already applied (current: 4) |
| `cof_quickturn_time` | 0.18 | yes | seconds of the quick 180-degree turn (0.05..1) |
| `cof_pad_trigger_hyst` | 0.1 | yes | trigger hysteresis around `joy_lt/rt_threshold`, 0..0.4 of the pull (0 = plain threshold) |
| `cof_pad_move_mode` | 1 | yes | left stick: 0 = the engine's proportional stick, 1 = shaped like the movement keys, 2 = the same, 8 directions |
| `cof_pad_move_deadzone` | 0.15 | yes | modes 1/2: radial deadzone, 0..0.5 |
| `cof_pad_move_walk` | 0.6 | yes | modes 1/2: from this push on the stick counts as fully pushed |
| `cof_pad_move_curve` | 1 | yes | modes 1/2: response exponent below the walk threshold |
| `cof_pad_move_diagonal` | 1.2 | yes | modes 1/2: diagonal boost, 1 = the keyboard's diagonal (187.5 u/s), 1.2 = as fast as straight (225) |
| `cof_pad_style` | -1 | yes | button pictures: -1 / `auto` = the pad in use, 0 Xbox, 1 PlayStation, 2 Nintendo, 3 Steam Deck |
| `cof_pad_style_auto` | 0 | no (read-only) | the style of the pad in use, 0..3 (what Auto shows) |
| `cof_pad_type` | none | no (read-only) | the same as a style id: xbox, ps5, switch, steamdeck, none |
| `cof_pad_positional` | 1 | yes | 1 = Nintendo face buttons by position (SDL hint), 0 = by printed label |
| `cof_input_trace` | 0 | no | developer log (`[cof-pad]`) |

Commands: `cof_pad_status [binds]` (controllers SDL sees, panel state, cursor,
sticks, client `joystick`, what the defaults check did, crouch toggle, player
hull, view height, gyro, optionally the pad binds), `cof_pad_defaults
[force|list]`, `cof_duck_toggle` (the crouch toggle; bindable to any key),
`cof_sprint_toggle_press` (the sprint, Toggle or Hold; bindable to any key),
`cof_pad_panel_dump` (the open panels' buttons with their handlers),
`cof_quickturn` (the quick turn; bindable to any key).

Developer hooks (need `developer 1`, restricted, no OS input):
`cof_pad_measure <label> <seconds> [alias]` (frame rate, slowest frame, SDL event
loop time, SDL / axis / sensor events, trigger edges, pad keys, active-pad
switches, the player's horizontal speed and yaw over a window; runs the alias
afterwards), `cof_pad_jitter <sdl axis> <lo> <hi> [virtual] | off` (an axis moved
between two values every frame), `cof_pad_style_test` (the style detection over
14 simulated pads, PASS/FAIL), `cof_pad_virtual <switchpro|joycons|deck|xbox|ps5>
| button <n> <0|1> | axis <n> <v> | off` (an SDL virtual game controller with a
real pad's ids and name, in process; while it is attached SDL's
`SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS` is 1, so a test does not depend on the
window having the focus), `cof_joy_axis_probe
<side|fwd|pitch|yaw|lt|rt> <value>` feeds `Joy_AxisMotionEvent` (the entry point
the SDL backend feeds), `cof_vcursor_test [abs] <x> <y> [0|1|2]` moves the panel
cursor and optionally clicks (`cof_vcursor_test button <handler class>
<command>` puts it on that panel button); pad keys go through the existing
`cof_key_probe`. Note for test cfgs: `cof_key_probe` on a key whose binding is a
plain command (`cancelselect`, `cof_sprint_toggle_press`, `weapontoggle`)
inserts it in two pieces at the head of the command buffer, so the next cfg
line is glued to it; start that line with `;`. START's `cancelselect` becomes
the client's `escape` appended at the end of the buffer, so a test opens the
pause menu with `escape` itself.

Upstream cvars worth knowing: `joy_enable`, `joy_pitch`/`joy_yaw` (look speed,
100 deg/s), `joy_*_deadzone` (4096 of 32767), `joy_lt/rt_threshold`,
`joy_gyro_enable` (off by default here, section 2; the DualSense has a gyro),
`joy_debug 1` (draws axes and buttons).

## 6. Controllers (measured 2026-09-23, SDL 2.30.9)

Both pads connected to the development machine resolve through SDL's
GameController mappings to the same logical buttons and axes, so one layout
serves both:

| pad | SDL name, type | GUID | notes |
| --- | --- | --- | --- |
| Xbox One Controller | "Xbox One Controller", XBOXONE | `0300938d5e040000ff02000000007200` | d-pad via hat; no gyro, no touchpad |
| DualSense | "DualSense Wireless Controller", PS5 (HIDAPI) | `030057564c050000e60c000000016800` | gyro + accelerometer, one touchpad (`TOUCHPAD` click), mic button = `MISC_BUTTON`, PS = `MODE`, Create = `BACK`, Options = `START`; triggers are axes (`LTRIGGER`/`RTRIGGER`) |

With two pads the engine takes input from **both** at once; the "active" pad
(rumble, gyro) is the first one found at startup and then whichever sent the
last event. There is no cvar to pick one.

## 7. Verification

Round 3 (`stage1/gamepad3-20260924/RESULTS.md`): the frame-rate check on
c_trainride (idle, mouse ADS, pad ADS steady / jittering, Toggle and Hold,
through the engine and through an SDL virtual pad), the movement table of
section 2c, the quick turn, the generation 3 -> 4 migration and a fresh
generation 4, View opening and closing the inventory, the style test (14 of
14) and virtual Switch Pro / Steam Deck pads (style, `cof_pad_style_auto`,
keys). No Nintendo or Steam Deck hardware was available.

Round 2 (`stage1/gamepad2-20260923/RESULTS.md`): B on the keypad, landline,
YES/NO, tape page, note, padlock, billboard, computer and boiler puzzle
(dump + B, each closed by its own button); tape slot by A (the slot's save
info written at once, the save through the game's own delayed `savehack`);
generation 2 -> 3 migration and a fresh generation 3; sprint toggle / hold /
auto-release; the OS arrow kept hidden from the first frame of the inventory
and the pause menu with the pad, shown with the mouse; the prompts kept over
D-pad and stick focus moves in the pause menu; A on a Load row loads it; the
cursor art on the inventory (150 percent) and on a note.

Round 1:

`stage1/gamepad-20260923/RESULTS.md`: nine launches in a junction fixture with
both pads connected (untouched), every input from `cof_key_probe`,
`cof_joy_axis_probe` and `cof_vcursor_test`, `cof_vcursor_warp 0` so no run moved
the desktop cursor. No press on a real pad was part of any check.
