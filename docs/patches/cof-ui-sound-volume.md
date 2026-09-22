# Menu sound volume (`ui_sound_volume`)

The user: *the CoF menu sounds are too loud.*

They are. `patches/cof-mainui-source-theme.patch` gave the engine menu Cry of
Fear's own UI samples (`docs/design/ui-theme.md` § *Menu sounds*) because none
of the fourteen Half-Life paths MainUI asks for exists in this game. Those
samples were mixed for the client's own VGUI panels, which play them at `0.5`
(`client.dll`'s `CGameMenu` methods, measured in
`docs/patches/cof-ui-menu-map-redirect.md`), and the engine menu was playing them at
`1.0`.

This patch adds one archived engine cvar, `ui_sound_volume`, that scales the
menu library's sounds and nothing else.

## Where the scaling happens, and why there

**Measured, in the engine sources.** The menu DLL has exactly one route into the
mixer:

```
3rdparty/mainui/enginecallback_menu.h:212  EngFuncs::PlayLocalSound( szSound )
    -> engfuncs.pfnPlayLocalSound
engine/client/dll_int/cl_gameui.c          pfnPlaySound( szSound )
    -> S_StartLocalSound( szSound, VOL_NORM, false )
engine/client/sound/s_main.c:966           S_StartLocalSound( name, volume, reliable )
    -> S_StartSound( NULL, snd.entnum, channel, sfxHandle, volume, ATTN_NONE, PITCH_NORM, SND_LOCALSOUND|SND_STOP_LOOPING )
```

Every `PlayLocalSound` call site in the library - `controls/PicButton.cpp:194`,
`controls/Framework.cpp:161`, `controls/CheckBox.cpp`, `controls/Slider.cpp`,
`controls/SpinControl.cpp`, `controls/Switch.cpp`, `controls/Table.cpp`,
`controls/Action.cpp`, `controls/Bitmap.cpp`, `controls/ItemsHolder.cpp`,
`controls/BaseWindow.cpp:68`, `menus/Controls.cpp`,
`menus/ConnectionProgress.cpp`, `menus/PlayerModelView.cpp` - goes through
`CMenuBaseItem::PlayLocalSound` or `EngFuncs::PlayLocalSound` directly, so they
all land on that one engine function.

**The local-sound path already carries a per-call volume**, so there was no need
for the `playvol` command path or for a scale inside `S_StartLocalSound`:
`S_StartLocalSound( name, volume, ... )` hands `volume` straight to
`S_StartSound` as `fvol`, which becomes the channel's `master_vol`. The scale is
therefore applied in `pfnPlaySound`, which is:

* **complete** for the menu - it is the library's only entry;
* **incapable of touching a game sound** - the game DLL uses
  `pfnEmitSound`/`pfnEmitAmbientSound`, the client DLL uses `pfnPlaySoundByName`
  and `pfnPlaySoundByIndex` (different functions in `cl_game.c`), maps use
  `ambient_generic`, and the `play` / `playvol` / `speak` console commands call
  `S_StartLocalSound` themselves (`s_main.c:1695`, `:1723`, `:1733`). None of
  them passes through `cl_gameui.c`.

That is the documented choice: **a per-call volume on the existing local-sound
path, applied at the menu's single entry point**, not `playvol` and not a scale
inside the mixer.

## The cvar

`ui_sound_volume`, `FCVAR_ARCHIVE`, default `"1.0"`, clamped to `0 … 1` on use.
It is registered in `UI_LoadProgs()` (`engine/client/dll_int/cl_gameui.c`)
rather than lazily in `pfnPlaySound`: `UI_LoadProgs` runs from `CL_Init`, and
`Host_Init` execs `config.cfg` only afterwards, so a value the user chose
reaches the cvar. The registration is behind a `static qboolean` because the
menu library can be reloaded.

Default `1.0` means every other game keeps the stock loudness byte for byte.
**Cry of Fear gets `0.5`**, and that comes from the menu, not from the engine:
`UI_ThemeApplyDeferredDefaults()` (`3rdparty/mainui/Theme.cpp`) sets it once
through the same one-shot marker that already defaults `ui_renderworld` to `1`
and `r_detailtextures` to `0`. See `docs/design/ui-theme.md` § *Menu sounds
volume* for the marker's new generation number, which is what lets an
installation that already ran an older build receive this one default without
losing the choices it made about the older two.

## The developer print

One `Con_Reportf` per menu sound, naming the value the mixer is handed:

```
[cof-ui] menu sound "ui/3d_click.wav" -> S_StartLocalSound volume 0.50 (ui_sound_volume 0.50)
```

## The slider

`menus/Audio.cpp` gains a **Menu sounds** slider (`0 … 1`, step `0.05`) under
*Sound effects volume* and *MP3 volume*, linked to `ui_sound_volume`, with the
status line *Volume of the menu's own button and rollover sounds*. It is added
only in theme mode: the WON layout is a grid of fixed coordinates and a new row
would move controls that `ui_theme 0` promises to leave exactly as they were.
It writes on change and on *Close*, like the other sliders, and
`SaveAndPopMenu` skips it when it is hidden.

## Evidence

Fixture `stage1/ui-m1-menu-fixture-20260921` (its `gfx` and `resource` folders
are its own, not junctions into the canonical copy), windowed 1920x1080,
`+volume 0`, every command from `maps/c_game_menu1_load.cfg`. **No input was
injected.** Engine
`1C25CE6BF17EB3C7A70931CD6D00D9296917B41F756CDA6FFD4E603ECF197C13`, menu
`F7E46B3A2A472AFED3167E78D2D575EC58A631AF344FE6789A344346F0A569DF`.

The menu's sounds only ever start on a click, a key or the pointer entering an
item, and this project may not inject any of those, so the menu gained a cfg
hook of its own, `menu_cof_sound_probe [slot]` (`menus/Main.cpp`, same pattern
as `menu_cof_extras_list` and the engine's `cof_ui_menu_panel_probe`). It plays
one slot of `uiStatic.sounds` through the very call every control uses.

| Run | Decisive lines |
| --- | --- |
| `evidence/sv2-1920.log` | from a `config.cfg` whose marker still said `ui_cof_scene_defaults "1"`: `Cry of Fear: ui_sound_volume defaulted to 0.5 …` (:756), then `"ui_sound_volume" is "0.500000" ( "1.0" )` (:990) and four `[cof-ui] menu sound … -> S_StartLocalSound volume 0.50 (ui_sound_volume 0.50)` lines - two of them (`:763`, `:964`) are the menu's *own* `SND_MOVE` on startup, not the probe. `config.cfg` comes back with `ui_cof_scene_defaults "2"` and `ui_sound_volume "0.500000"` |
| `evidence/sv2-control.log` | the same build with the marker already at `2`: **no** `defaulted to` line, and the probe at three values gives `volume 0.50`, `volume 1.00`, `volume 0.25` - the scale tracks the cvar and is not a constant |
| `evidence/sv2-1920-audio.png` `0400A208…` | the Audio page with the **Menu sounds** slider, drawn at half travel |

**Audibility is a manual test**, as with every sound in this project; what the
log proves is the number the mixer is given.

## Applying

After the unified UI input gate, which is the other patch that touches
`cl_gameui.c`:

```powershell
pwsh -File .\scripts\apply-cof-ui-sound-volume.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

The script refuses a tree that already carries `ui_sound_volume`, requires the
unpatched `S_StartLocalSound( szSound, VOL_NORM, false );` call and the input
gate's `cof_ui_deferred_cmd_guard`, verifies the markers afterwards and
reverse-checks the patch.

| Artefact | Bytes | SHA-256 |
| --- | ---: | --- |
| `patches/cof-ui-sound-volume.patch` | 2 683 | `F847A7D432C1E9C18F0C5E822D0CA3E37C6743CB3F0B0EC7FF8DBBA7C46CF4C4` |

Round-tripped on a tree built from `cof-fix/pristine-clean` with the whole
documented patch order (`pristine-stackverify-20260922`): forward apply,
marker check, reverse check, and the resulting `engine/` compares identical to
the working build tree.
