# Unified UI, milestone 1: plumbing

Scope: make the FWGS engine menu (`mainui`) the surface that is actually on
screen for Cry of Fear, over the live 3D scene, with no styling work. Nothing
here changes how the menu *looks* beyond what was needed to make it legible.
The feasibility audit this implements is
`stage1/ui-architecture-audit-20260921/RESULTS.md`; runtime evidence is in
`stage1/ui-m1-menu-fixture-20260921/` (`RESULTS.md`, `evidence/`).

Everything was verified in a disposable fixture that never writes to the
canonical game copy. The canonical tree was hashed by file count, byte total
and newest mtime before and after every run and came back identical.

## The five pieces

### 1. Background map (data)

`cryoffear/scripts/chapterbackgrounds.txt` naming `c_game_menu1`. MainUI parses
it in `UI_LoadBackgroundMapList` (`3rdparty/mainui/BaseMenu.cpp:970-994`) and
`UI_StartBackGroundMap` (`:547-583`) issues `map_background c_game_menu1` on
the first menu draw. The engine then renders the world behind the menu
(`engine/client/cl_view.c:395`) and `CMenuBackgroundBitmap::Draw` returns
without painting anything while `cl_background` is set
(`controls/BackgroundBitmap.cpp:113-118`), so the menu is transparent over a
running scene. `SV_IsSimulating` keeps a background map simulating
(`engine/server/sv_main.c:565-585`), and two captures five seconds apart differ
in the snow and sky.

**Command-buffer trap.** A `+wait` on the command line stalls the whole command
buffer, and the menu's `map_background` is appended *behind* it, so it never
runs before `+quit`. Delayed test scripts must go in
`maps/<map>_load.cfg`, which the engine execs after the map spawns
(`engine/server/sv_init.c:971`). The first attempt at this milestone looked
like "chapterbackgrounds.txt is ignored" purely because of this.

### 2. Removing the Cry of Fear client menu overlay (data)

`cryoffear/maps/c_game_menu1.ent` is the map's entity lump with the single
`cof_gamemenu` entity removed (127 entities in, 126 out). FWGS loads
`maps/<name>.ent` as a full entity-lump replacement for the world
(`engine/common/mod_bmodel.c:2304-2345`) as long as the `.ent` is not older
than the BSP. `cof_gamemenu` (`CCofGameMenu` in `cryoffear/cl_dlls/hl.dll`) is
what sends the `GameMenu` user message that `client.dll` hooks to raise its own
VGUI panel, so removing it removes the panel and nothing else.

Generate it with `scripts/make-cof-ent-override.py`; see
`gamedata/cryoffear/maps/README.md`. The `.ent` is derived game data and is not
committed.

Measured effect against the fixture's own pre-patch capture of the same map:
the CoF logo band, the item list and the Team Psykskallar mark all disappear
(mean channel difference 48.7 / 23.9 / 23.7 over those rectangles), while the
sky, skyline and water are unchanged apart from animation (mean 3.8-3.9 of 255,
under 0.13 % of pixels differing by more than 24). The camera framing, skyline
geometry, window lights, snow and sky are identical.

### 3. Translucent pause scrim (mainui source) + legible buttons (data)

`patches/cof-mainui-background-scrim.patch`, applied with
`scripts/apply-cof-mainui-background-scrim.ps1`, against the pinned mainui
revision `61263995592e93a278d764807243d043d3b97c54`.

Upstream `CMenuBackgroundBitmap::DrawInGameBackground` fills the whole screen
with `uiColorBlack` whenever `ui_renderworld` is on, which throws away the
world frame the engine just rendered. The patch draws a translucent black
scrim instead in that case, and keeps the original fill when the world is not
being rendered. A new archived cvar `ui_scrim_alpha` (default `150`) sets the
alpha: `0` leaves the scene undimmed, `255` reproduces the previous opaque
behaviour exactly.

Measured over a region of a paused `c_forest3` frame that carries no menu text:
scene luminance 18.80 with no menu, 7.43 with the menu open at
`ui_scrim_alpha 150` (ratio 0.395, against the 0.412 the alpha predicts), and
0.00 at `ui_scrim_alpha 255`.

`render_picbutton_text 1` in `gameinfo.txt`
(`filesystem/gameinfo.c:436-439` -> `GFL_RENDER_PICBUTTON_TEXT` ->
`uiStatic.renderPicbuttonText`) makes every pic button render as blurred TTF
text. Cry of Fear ships no `gfx/shell/btns_main.bmp`, so `CMenuPicButton::Draw`
already took the text branch on a null picture
(`controls/PicButton.cpp:258-310`); the key makes that explicit and stops
`CBtnsManager::LoadBmpButtons` probing for the atlas at all
(`Btns.cpp:36-39`). It is insurance, not a visible change for this game today.

The rebuilt `menu.dll` is deployed to `cryoffear/cl_dlls/menu.dll`, the
per-game menu path (`engine/common/lib_common.c:209-219` with
`dllpath "cl_dlls"` from `gameinfo.txt`), and the log confirms the engine loads
and unloads `cl_dlls/menu.dll` rather than the root copy.

### 4. New Game into the Cry of Fear flow (data)

`startmap "c_difficulty_settings"` plus `noskills 1` in `gameinfo.txt`. The
engine menu's New Game runs the restricted `newgame` command, which is
`COM_NewGame( GI->startmap )` (`engine/server/sv_cmds.c:355-360`,
`engine/common/host_state.c:47-67`); `noskills` makes `CMenuNewGame::Show`
call `StartGame` immediately instead of showing MainUI's own Easy/Medium/Hard
page (`3rdparty/mainui/menus/NewGame.cpp:37-43`). No code change is needed.
Verified: `+newgame` logs `Spawn Server: c_difficulty_settings`.

`trainmap "coft_1"` is left as it was: no `coft_*` map ships in this game
folder, so MainUI's Training Room item has nothing to load. Either point it at
a real map or hide the item in a later milestone.

### 5. Not done here

The engine-side gate that stops `CL_DrawHUD` / `VGui_Paint` and VGUI input
while the unified menu is visible (audit §4.1 option 3) and Escape ownership
(audit §4.2) are engine changes and are owned elsewhere. Without them the CoF
HUD still draws under the scrim on a normal map, and Escape is still swallowed
by any CoF client panel that is up.

## What the Cry of Fear menu maps actually do

Both menu maps are empty shells: `c_difficulty_settings` and `c_loadgame` each
hold five entities (`worldspawn`, `info_player_start`, `light`,
`game_player_equip`, and one `cof_*` entity). All behaviour is in
`cl_dlls/hl.dll` and `cl_dlls/client.dll`.

| Entry point | Option picked | Exact command(s) | Effect |
| --- | --- | --- | --- |
| client `beginspgame` (registered console command, `client.dll` VA `1006E1F0`) | - | `disconnect;maxplayers 1;deathmatch 0;map c_difficulty_settings` | enters the difficulty map |
| engine menu New Game | - | `newgame` -> `COM_NewGame( GI->startmap )` | same map once `startmap` is set (piece 4) |
| `c_difficulty_settings` -> difficulty row | Easy / Normal / Difficult / the locked fourth row | client `CDifficulty` panel sends `cmd skillset 1` … `cmd skillset 4` (`client.dll` `.rdata` `skillset 1`..`skillset 4`) | `hl.dll` handler VA `10019DA9`: `CVAR_SET_FLOAT("difficulty", N)`; for `N == 4` it also sets a player byte at `+0x1EE0` and a global flag; plays `inventory/game_start.wav`, runs a 5 s white `UTIL_ScreenFade`, then sets the think at VA `100DFC10` |
| the think at VA `100DFC10` | - | if a campaign first map is pending: `CLIENT_COMMAND("map %s\n", <firstmap>)`; otherwise `CLIENT_COMMAND("map c_intro\n")` | **first map started: `c_intro`** for the main campaign |
| Custom Campaign (client `CCampaignSlider`, reads `maps/*.custom`) | a campaign | `cmd campaign <firstmap>` then `cmd skillset N` | `campaign` handler VA `10019C91` stores `ALLOC_STRING(argv(1))` in the pending-map global; the same think then runs `map <firstmap>` |
| `c_loadgame` -> slot row | slot 1-5 | client `CSaveLoad` panel sends `cmd cofload 1` … `cmd cofload 5` | `hl.dll` handler VA `1001C7F7` -> `SERVER_COMMAND("load cofsave1\n")` … `("load cofsave5\n")`, i.e. the engine's own `load` command on `SAVE/cofsaveN.sav`. **First map started: whatever the save holds** (`cofsave1` loads `c_forest3`). |
| anywhere | open the load panel | `cmd loadgamemenu` | handler VA `1001BBE3` sends a user message that raises the client save/load panel; it does not change level |
| on `c_game_menu1` only | 3D menu mode switch | `cmd gamemenucmd <N>` | handler VA `1001B9BC` checks the level name contains `game_menu`, finds the `cof_gamemenu` entity and writes `N` into its `pev` field `+0x248` |

Notes for the next milestone:

* The difficulty cvar Cry of Fear uses is **`difficulty`**, not the engine's
  `skill`. MainUI's New Game page writes `skill`, which this game ignores.
* Nothing in either DLL builds a `map c_loadgame` string, so `c_loadgame` is
  entered from elsewhere (a map's own change-level), not from the 3D menu; the
  3D menu raises the save/load panel in place instead.
* `hl.dll` also contains a five-way chapter dispatch at VA `100DDD60`
  (`c_intro` / `c_city` / `c_subwaysick1` / `c_forest3` / default `c_start`,
  selected by the global at `10211AC0`). Nothing in the image references that
  function or writes that global, so treat it as dead code, not as a chapter
  select.

## Fonts: `--enable-stbtt` at this commit

* The option exists: `3rdparty/mainui/wscript:20-21` defines
  `--enable-stbtt` (`USE_STBTT`, default `False`), and `stb_truetype.h` is
  vendored at `3rdparty/mainui/font/stb_truetype.h`. `configure` turns it on
  automatically only for android, darwin, nswitch, psvita, emscripten and MAGX
  (`wscript:32-33`), and defines `MAINUI_USE_STB` from it (`:44`).
* The documented Windows build does **not** pass it
  (`docs/client-build.md:56-60`), and the waf config caches of both the tracked
  renderer build and this milestone's build record `'USE_STBTT': False`.
* On `win32` the wscript never checks for freetype either (`:50-53` is guarded
  by `DEST_OS != 'win32'`), so neither `MAINUI_USE_STB` nor
  `MAINUI_USE_FREETYPE` is defined and `CFontManager` falls back to the
  WinAPI/GDI backend (`font/FontManager.cpp:22-28`, `:489-499`).
* Consequence: only `FreeTypeFont.cpp:57` and `StbFont.cpp:67` call
  `FindFontDataFile`, so the current `menu.dll` cannot load a TTF from
  `cryoffear/gfx/fonts/` and uses whatever GDI resolves `"Trebuchet MS"` and
  `"Tahoma"` to. Switching is a configure flag, not a dependency hunt, but it
  changes every glyph in the menu and needs the resolution capture matrix from
  `docs/display-reference-audit.md:60-66`.

This is a report only; no font change was made.

## Artefacts

| Artefact | SHA-256 |
| --- | --- |
| `patches/cof-mainui-background-scrim.patch` (2 567 bytes) | `E6B5A22606D4B338D518480DF4371D1B60FC01D5F0B39F1B6EED462B7A34735A` |
| `menu.dll` from `build-cof-ui-m1-20260921` (1 314 304 bytes) | `B0D3ACCD22589AC895259E1990571B49F489CC141476E67E3B79EB7DEE82597D` |
| `menu.pdb` | `5C06828E9A8E6CC87AF1D6DB298863FC2E66BC7D4AEAB77689A14E9465F7083A` |
| `cryoffear/scripts/chapterbackgrounds.txt` (356 bytes) | `CBC1C605EB1D7D6B606C96D83855CFB29B5C1A97D4280C19EAD27CF8D041D80E` |
| `cryoffear/maps/c_game_menu1.ent` (17 994 bytes, generated) | `05F6269B65F8D7C996A52E596A96F7F606D02D38AB1F9F12437BDA3543966D61` |
| fixture `cryoffear/gameinfo.txt` (1 351 bytes) | `44F2A056728FFF7A8E2D542DA0D93F2C91057032EAC9EEEBBEE88D0C72766A7F` |

Build: `python waf configure -4 --out=build-cof-ui-m1-20260921
--sdl2=..\prereq\sdl2-2.30.9-vc\SDL2-2.30.9 -T release --notests
--disable-mbedtls --enable-cof-entvars-legacy` then
`python waf build -j8 --targets=menu`, from the pinned FWGS checkout with the
x86 MSVC environment and `WAFLOCK` set to a private lock file so a concurrent
build in the same tree is not disturbed.

## Limits

* All captures are console-command screenshots, not native mouse interaction.
  No menu item was clicked.
* Only `1920x1080` windowed was covered. No resolution matrix, no fullscreen.
* The pause-menu check loaded `SAVE/cofsave1.sav` (`c_forest3`) and opened the
  menu with the `togglemenu` console command. Whether Escape reaches the engine
  from inside Cry of Fear's own panels is unchanged and is not this change's
  problem (audit §4.2).
* The CoF HUD is not suppressed under the scrim; that needs the engine gate.
* `render_picbutton_text` has no measurable visible effect for this game today,
  because the missing button atlas already forced the text branch.
