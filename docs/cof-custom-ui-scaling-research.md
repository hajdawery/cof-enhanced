# Cry of Fear custom UI scaling research

This note records the coordinate spaces, ownership boundaries, and test gates
that matter when adapting the original Cry of Fear UI to a modern display. It
is a research reference, not a scaling implementation or a claim that the
current runtime has visual parity.

Evidence labels used here are deliberate:

- **Verified** means a source inspection, runtime configuration, disassembly,
  or retained capture directly supports the statement.
- **Hypothesis** means the ownership or cause is plausible but still needs a
  matched runtime capture.
- **Harness limit** means a diagnostic switch or console route changed the
  normal path and cannot stand in for a human GUI test.

The source references below are relative to pinned FWGS revision
`4857b389e6ba32ddaa68582aedcbc950c138f46a`.

## Ownership map

Treat these layers as separate when debugging a misplaced label, cursor, or
menu transition. A correct result in one layer does not validate another.

| Layer | Evidence and owner | Scaling/input consequence |
| --- | --- | --- |
| CoF map menu scene | **Verified:** `c_game_menu1` contains `cof_gamemenu`, menu camera/trigger entities, and ambient menu audio. | The visible background, camera, and some scene text can be map content. Moving FWGS `mainui` controls cannot correct map geometry. |
| CoF resource command menu | **Verified:** `cryoffear/resource/GameMenu.res` routes New Game to `engine beginspgame`, Load Game to `engine map c_loadgame`, 3D menu to `engine to3dmenu`, and 2D menu to `engine returnmenu`. | This resource selects commands; it does not by itself prove how the map menu panel is drawn or how a later click changes focus. |
| Original client panel/HUD | **Verified:** the original client export table in `engine/client/dll_int/cl_game.c:72` binds `HUD_Redraw` to `pfnRedraw`; `CL_DrawHUD` calls it in `CL_ACTIVE` and `CL_PAUSED` after engine crosshair and center-print drawing. | A client callback can draw or mutate game UI while the engine still owns surrounding overlays and state transitions. |
| Client triangle callbacks | **Verified:** `cl_game.c:90-91` binds `HUD_DrawNormalTriangles` and `HUD_DrawTransparentTriangles`; the GL renderer invokes them at `ref/gl/gl_rmain.c:870` and `:924`. | These callbacks run in renderer stages, with engine fog/state boundaries. A callback error can corrupt a frame without being a `HUD_Redraw` scaling problem. |
| VGUI support | **Verified:** `engine/client/vgui/vgui_draw.c:264` converts the renderer mouse position using `refState.width / clgame.scrInfo.iWidth` and the corresponding height ratio. | VGUI hit testing can use a logical client screen while the native cursor is in render pixels. Record both spaces. |
| FWGS `mainui` | **Verified:** `3rdparty/mainui/BaseMenu.cpp:103-130` scales logical controls; `:746-796` stores absolute cursor coordinates and dispatches menu mouse events. | This is a distinct engine-facing menu path. Its scale formula must not be applied to bespoke CoF map/client panels without ownership evidence. |
| SDL/display transform | **Verified:** `engine/client/vid_common.c:25,148-159` defines `vid_scale` (default `1.0`) and applies the display transform before render dimensions are exposed. | Window size, render size, `vid_scale`, and client logical size can differ. Capture all four. |

The current evidence does not establish that the supplied 3840×2160 menu
capture is drawn by FWGS `mainui`. It is a rendered `c_game_menu1` scene with
an original CoF menu appearance. **Hypothesis:** bespoke map/client UI owns
some visible labels and panels. Confirm this by tracing the actual draw owner
in a matched runtime before changing `mainui` scaling.

## Coordinate spaces and scaling boundaries

### FWGS `mainui`

`BaseMenu.cpp` uses a logical 1024×768-style space. At aspect ratios narrower
than 4:3 it sets `scaleX = scaleY = ScreenWidth / 1024` and applies a vertical
offset. At 4:3 or wider it sets both scales to `ScreenHeight / 768`, derives
logical width as `ScreenWidth / scaleX`, and starts the cursor at screen
center. `UI_ScaleCoords` multiplies control positions and sizes by those
scales. `UI_MouseMove` receives absolute screen coordinates, clamps them to
`ScreenWidth`/`ScreenHeight`, and sends them to either the client or menu
object.

For a 16:9 display, the expected `mainui` scales are therefore:

| Display | Expected `mainui` scale |
| --- | ---: |
| 1920×1080 | 1.40625 |
| 2560×1440 | 1.87500 |
| 3840×2160 | 2.81250 |

These values are source-derived expectations for `mainui` only. They are not
the correct scale for a CoF panel until the panel is shown to use that layer.

### Original client HUD and game UI

`CL_GetScreenInfo` in `engine/client/dll_int/cl_game.c:1654-1702` begins with
the renderer dimensions and applies `hud_scale` when it is at least 320 and
meets `hud_scale_minimal_width`. It then exposes the resulting logical width
and height through `clgame.scrInfo` and marks the screen stretched. With the
default `hud_scale 0`, the client sees the renderer dimensions directly.

This path is relevant to weapon geometry, HUD sprites, text, and any client
panel that uses `GetScreenInfo`. It is separate from the `mainui` scale and
from `vid_scale`. A change to `hud_scale` can move the HUD while leaving a map
menu camera or VGUI panel unchanged.

The ignored runtime `menu_settings.txt` describes the weapon-selection overlay
in a 640×480 logical coordinate space. Treat that as a **verified runtime
configuration fact**, not proof that every CoF menu uses 640×480. Inventory,
phone, quick-slot, and HUD assets must be measured independently.

### VGUI and cursor coordinates

`VGUI_GetMousePos` converts native renderer coordinates into client logical
coordinates using the ratio of `refState` to `clgame.scrInfo`. This creates a
specific failure mode: a panel can render at one scale while hit testing uses
another. For every interaction capture, record native cursor coordinates,
`refState` dimensions, `clgame.scrInfo` dimensions, and the resulting logical
coordinates.

The supplied capture reports 3840×2160 pixels and embedded metadata of
143.9926×143.9926 DPI. The DPI metadata does not establish Windows display
scaling. The pinned SDL path defaults `vid_scale` to 1.0, disables
`SDL_WINDOW_ALLOW_HIGHDPI` on Windows, and requests the `permonitor` DPI hint;
the actual process DPI context still must be recorded during a display test.

### Fonts, sprites, and hitboxes

Do not infer a font or sprite scale from the size of a screenshot alone. Record
the asset path, source dimensions, logical draw rectangle, final pixel
rectangle, and the hitbox rectangle. A text label can be client-drawn while a
nearby button is map geometry or VGUI, which makes a single global scale
factor the wrong fix.

The 4K reference capture provides comparison anchors only: its approximate
bright-pixel logo envelope is `(1682,894)`–`(2136,980)` and its menu envelope
is `(1818,1750)`–`(2020,2108)`. These measurements are not semantic masks or
visual-fidelity scores. Use normalized coordinates and row spacing after the
actual owner is identified.

## Menu transition side effects

The full slot click handler has more work than the server save command. Static
disassembly of the original client slot-1 path at `VA 0x100316F7` shows this
order:

1. Hide the panel through vtable slot `+24` with argument `0`.
2. Call the UI cursor/update helper at `VA 0x100AAAD0`.
3. Send the server command `unfreeze 1024`.
4. Check `game_menu`.
5. Call `VA 0x1007FC10(0)`.
6. Free `saveinfo`.
7. Send the server-forwarded `cofload1` command.

The two internal call names are unresolved. This order is **verified static
evidence**, while the full click execution remains untested. The console and
delayed-command probes exercise the server-forwarded save route only; they do
not reproduce panel hiding, cursor state, focus, or the client-side handler.
The save-selector appearance in the HUD-suppressed diagnostic frame may be a
harness artifact and must not be used as proof that the real click handler
left the panel visible.

The opt-in root-save compatibility path was separately shown to load the
stock root `SAVE` layout and to write, thumbnail, and reload an Xash save. That
is command-equivalent save evidence. It does not establish GUI slot selection,
camera state, or a clean rendered first-person frame.

## Diagnostic results and interpretation

The repository contains two off-by-default diagnostics that isolate callback
ownership; neither is a fix:

- `cof_skip_client_normal_triangles 1` bypassed the original
  `HUD_DrawNormalTriangles` callback. The matched trace lost thousands of
  repeated `after_client_normal_triangles` errors but the captured frame still
  had white radial and orange glyph corruption.
- `cof_skip_client_hud_redraw 1` additionally bypassed the original
  `HUD_Redraw` callback. In that harness configuration the white radial output
  disappeared while orange glyph corruption remained. This attributes the
  white radial contribution to the HUD callback in that run; it does not prove
  that the normal GUI path is wrong or that the remaining orange output has a
  single source.

The detailed hashes and retained-frame paths are in
[the menu transition investigation](menu-transition-investigation.md). Both
cvars default to off and are diagnostic controls. The runs also used
`sv_cheats 1` to permit `r_drawentities 0`/`r_drawbeams 0`; those probes alter
the draw path and are useful for isolation only.

## Systems that need separate scaling gates

The original runtime configuration and hints identify these game-facing
systems:

- Inventory opened with `+inventory`, including hover, use, drop, equip, and
  combine targets.
- Quick slots selected with `quicksel 1`, `quicksel 2`, and `quicksel 3`.
- Phone keypad input and phone light behavior, including holster transitions.
- Weapon selection and HUD sprites, including the 640×480 logical overlay
  noted above.
- Tape-recorder save UI and its slot preview.

The existing [custom UI regression checklist](custom-ui-regression-checklist.md)
keeps these as pending interaction gates. A renderer startup, nonblank frame,
footstep, console command, or menu screenshot does not pass any of them.

## Display acceptance matrix

Run each row with the same assets, language, renderer, window mode, DPI
context, and matched engine/client hashes. Keep an Xash-generated save and a
stock GoldSrc/CoF save as separate cases.

| Target | Capture points | Interaction gates |
| --- | --- | --- |
| 1920×1080 | Main menu, slot selector, first frame, inventory, phone, quick slots | Hover and click every visible row; verify cursor/hitbox alignment and each overlay. |
| 2560×1440 | Same points | Repeat with normalized logo, label, row, sprite, and hitbox measurements. |
| 3840×2160 | Same points plus comparison to the supplied capture | Repeat and record physical text/sprite size, menu envelopes, cursor alignment, and DPI context. |

For every capture record: native window size, render size, `vid_scale`,
`hud_scale`, `clgame.scrInfo` width/height and flags, `refState` dimensions,
`mainui` active/inactive state, `cls.key_dest`, input device, cursor native and
logical coordinates, active map, and the asset or callback responsible for
the measured element. Keep lossless PNGs and hashes beside the runtime log.

Acceptance requires the intended visual state to change, the expected command
or handler side effect to occur, and the resulting screen/map/input state to
match the test case. Footsteps, a map log, or a frame that merely looks
nonblank is insufficient.

## Finding record schema

Use this compact record for future observations so scaling fixes remain tied to
the correct owner:

```text
Finding:
Source/asset:
Coordinate owner: map | client HUD | client callback | VGUI | mainui | SDL/display
Logical space and dimensions:
Native/render space and dimensions:
Observed impact:
Evidence: source/static | runtime/config | capture | disassembly
Runtime hashes and cvars:
Test path: mouse | keyboard | console | harness
Status: verified | hypothesis | harness-limited | pending
Open questions:
```

Keep the full interaction plan in the [custom UI regression checklist](custom-ui-regression-checklist.md),
the measured reference anchors in the [display audit](display-reference-audit.md),
and transition evidence in the [menu investigation](menu-transition-investigation.md).
