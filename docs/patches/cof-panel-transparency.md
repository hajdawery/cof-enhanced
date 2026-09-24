# The live world behind the in-play panels (`cof_panel_transparent`)

Engine + FreeVGUI patch `patches/cof-panel-transparency.patch`, applied with
`scripts/apply-cof-panel-transparency.ps1`, right after
[`cof-panel-pause`](cof-panel-pause.md) (whose panel identification it uses)
and before `cof-cheats`. Research: `stage1/controller-research-20260923/RESULTS.md`
(Q1); evidence: `stage1/panels-20260923`.

`xash.dll` and `vgui.dll` must be deployed together (two new `vguiapi_t`
entries).

## What the player sees

The engine renders the live 3D world every frame behind every Cry of Fear
panel. What hid it is black the client paints on purpose. With
`cof_panel_transparent 1` (the default) that black is left out while one of
these panels is open, so the world shows around the panel's art:

| panel | the black the client adds (VGUI1 colour `0,0,0,0` = opaque) |
| --- | --- |
| inventory, phone, keypad, computer, animal statue, landline, documents list, billboard | a plain `vgui::Panel` child covering the whole panel |
| note, user document | the panel's own full-screen background (the note's half-transparent `0,0,0,128` layer stays) |
| tape recorder SAVED GAMES page | four plain `vgui::Panel` masks around the picture |

Nothing else is touched: the telescope's and the cutscene's masks and the
letterbox bars belong to other panels, the padlock, the boiler puzzle and the
YES/NO question never had any black, and the save slot strips (`0,0,0,1`) are
not opaque black.

## How

`3rdparty/freevgui/platform/xash3d-fwgs/cofbackdrop.cpp`, once per painted
frame after the panel identification: find the open "owner" panels (the
classes above) and the HUD container (`CHUDControl`). Two paint filters added
to FreeVGUI (`Panel_SetPaintFilters`, `3rdparty/freevgui/panel.cpp/.h`, checked
at the top of `Panel::paintTraverse` and in `Panel::paintBackground`) skip:

* a background fill that is opaque black **and** is either the owner's own
  full-screen background or a plain `vgui::Panel` directly below the owner
  that covers it (any plain mask of the tape page);
* the HUD pieces `cof_panel_hide_hud` hides (below).

### The plate

`gfx/vgui/backgroundtoall.tga` is an 800x600 plate that is fully opaque. It is
drawn at `cof_panel_plate_alpha` (0-255 opacity, default 200) through a Bitmap
paint hook (`Bitmap_SetHooks`, `3rdparty/freevgui/image.cpp/.h`), only while it
hangs directly below an open owner panel. It is recognised by name: the client
loads every VGUI picture through the engine's `COM_LoadFile` immediately
before it builds the `BitmapTGA` from the bytes, so the engine latches the base
name of each `gfx/vgui/*.tga` load (`CL_CoF_LoadFile`,
`engine/client/dll_int/cl_game.c`) and the library consumes it when the bitmap
is constructed (`vguiapi_t::CofImageLatch`); the 800x600 size is checked again
when it is drawn.

### The HUD

The HUD container is painted before the panels and was hidden by the black.
Measured with `cof_panel_trace 3` at 1920x1080:

| HUD piece | rect (layout) | overlaps the panel art |
| --- | --- | --- |
| health bar, stamina bar | 32x160 at 32,920 and 64,920 | no |
| message strip (pickups, subtitles) | 1920x64 at 0,540 | always |
| top hint bar | 1920x64 at 0,0 | no at 100 percent; yes at 150 percent (the plate reaches the top) |
| letterbox bars | 1920x56 above and below the screen | never hidden |

Decision (default `cof_panel_hide_hud 2`): keep the bars - they are useful with
the world visible - and hide only the pieces that overlap the open panel's
art, so the message strip never draws across the plate. The owner's
full-screen and full-width children (backdrop, dimming layer, caption labels)
are not counted as art. `0` keeps the whole HUD, `1` hides all of it (the
letterbox bars are never hidden). The engine-drawn HUD (the ammo counter's
sprites, engine HUD text) is not VGUI and is not affected.

### The backing strip

The strip under strip-backed VGUI text (`cof-hud-text-backing`) is now only as
opaque as the most opaque glyph on its line
(`3rdparty/freevgui/platform/xash3d-fwgs/surface.cpp`). The client fades
captions by their text alpha, and a full-strength strip under fully faded text
showed as a dark bar under the billboard and the tape page once the world was
visible (invisible on the old black backdrop). Visible text is unchanged.

## Cvars

| name | default | flags | meaning |
| --- | --- | --- | --- |
| `cof_panel_transparent` | `1` | saved | show the world behind the in-play panels; `0` = the original black |
| `cof_panel_plate_alpha` | `200` | saved | opacity 0-255 of the rusty plate while the world is shown |
| `cof_panel_hide_hud` | `2` | saved | 0 keep the HUD, 1 hide it, 2 hide only pieces that overlap the panel |
| `cof_panel_trace` | `0` | | (from the pause patch) 1 logs what the frame skipped, 3 dumps the open panels' trees |

## Measured

Screenshots in `stage1/panels-20260923/evidence` (1920x1080, 100 and 150
percent HUD scale): inventory, note, tape page, billboard, landline, computer,
with `cof_panel_transparent 0` for the original black, and HUD modes 0/1/2.
The plate stays a readable frame at 200; the inventory, note and tape page are
anchored and scaled exactly as before (the anchor pass is untouched).
