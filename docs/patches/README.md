# Patch index

Every patch in `patches/`, what it changes and why, and the cvars and commands
it adds, grouped by milestone. The **apply order** is not repeated here: it is
in [the patch stack](../dev/patch-stack.md), and the `#` column below is the
step number there. Each entry links the page with the measurements.

Most of this text used to be the repository README; it moved here unchanged
in substance when the README became a player page (2026-09-22).

Targets: **E** engine (`xash.dll`), **R** renderer (`ref_gl.dll`),
**V** FreeVGUI (`vgui.dll`), **M** MainUI (`cryoffear/cl_dlls/menu.dll`).
"Default" is the shipped value; almost every behaviour change can be switched
off live with its cvar, which then reproduces the stock path in the same binary.

## Summary table

| # | Patch | Target | Adds (cvars / commands) | Page |
| ---: | --- | --- | --- | --- |
| 0 | `cof-pmove-legacy` | E | `-cof-pmove-legacy` command-line switch | [pmove adapter](pmove-adapter.md) |
| 1 | `cof-client-pmove-legacy` | E | (same switch) | [pmove adapter](pmove-adapter.md) |
| 2 | `cof-entvars-legacy` | E | `--enable-cof-entvars-legacy` configure option | [entvars layout](../history/entvars-layout-analysis.md) |
| 3 | `cof-edict-stride-legacy` | E | - | [edict stride](edict-stride-proposal.md) |
| 4 | `cof-menu-load-trace` | E | `cof_trace_menu_load` (diag) | [menu-load trace](menu-load-trace.md) |
| 5 | `cof-save-root-compat` | E | `cof_save_root_compat` | [root SAVE](cof-save-root-compat.md) |
| 6 | `cof-pause-save-plumbing` | E | - | [pause plumbing](cof-pause-save-plumbing.md) |
| 7 | `cof-menu-save-backend` | E | `cof_pause_menu_saves`, `cof_menu_save <1-5>` | [save backend](cof-menu-save-backend.md) |
| 8 | `cof-tape-save-command` | E | - | [tape command](cof-tape-save-command.md) |
| 9 | `cof-ui-input-gate` | E | `cof_ui_input_gate`, `cof_ui_deferred_cmd_guard`, `cof_skip_client_hud_redraw` / `cof_skip_vgui_paint` (diag) | [input gate](cof-ui-input-gate.md) |
| 10 | `cof-vid-restart-background` | E | `cof_vid_restart_background`, `cof_vid_skip_redundant_vidinit` | [video mode](cof-vid-restart-background.md) |
| 11 | `cof-ui-menu-map-redirect` | E | `cof_ui_menu_map_redirect`, `cof_ui_menu_panel_probe` | [menu-map redirect](cof-ui-menu-map-redirect.md) |
| 12 | `cof-ui-sound-volume` | E | `ui_sound_volume` | [menu sound volume](cof-ui-sound-volume.md) |
| 13 | `cof-console-variable-font-fallback` | E | - | [console font fallback](cof-console-variable-font-fallback.md) |
| 14 | `cof-console-style` | E | `cof_console_style`, `cof_console_width` / `_height`, `cof_console_*_color`, `cof_console_title`, `cof_console_font_grayscale` | [styled console](cof-console-style.md) |
| 15 | `cof-ui-death-flow` | E | `cof_ui_death_menu`, `con_enable`, `cof_ui_menu_return` | [death flow](cof-ui-death-flow.md) |
| 16 | `cof-levelshot-guard` | E | - | [levelshot guard](cof-levelshot-guard.md) |
| 17 | `cof-text-autoscale` | E | `cof_text_autoscale`, `cof_text_height_pct`, `cof_text_font` | [text autoscale](cof-text-autoscale.md) |
| 18 | `cof-mp3-stop-on-map` | E | `cof_mp3_stop_on_map` | [MP3 stop](cof-mp3-stop-on-map.md) |
| 19 | `cof-sky-reset-per-map` | E | `cof_sky_reset_per_map`, `cof_default_skyname` | [sky reset](cof-sky-reset-per-map.md) |
| 20 | `cof-cofenhanced-version` | E | `cof_version` | [build stamp](cof-cofenhanced-version.md) |
| 21 | `cof-ui-scale` | E | `cof_ui_scale`, `cof_ui_scale_user`, `cof_ui_scale_sprites`, `cof_hud_text_height_pct` | [UI scaling](../design/ui-scaling.md) |
| 22 | `cof-vgui-anchor` | V | - | [UI scaling](../design/ui-scaling.md) |
| 23 | `cof-vgui-inter-fonts` | E + V | `cof_ui_inter_fonts`, `cof_text_codepage`, `cof_font_probe` | [VGUI Inter fonts](../design/vgui-inter-fonts.md) |
| 24 | `cof-ui-death-live` | E | `cof_ui_death_keep_running`, `cof_world_probe` | [death flow](cof-ui-death-flow.md) section 8 |
| 25 | `cof-hud-text-backing` | E + V | `cof_hud_text_font`, `cof_hud_text_backing`, `cof_hud_text_y`, `cof_hud_text_y_shift`, `cof_hud_msg_y_pct`, `cof_hud_text_probe`, `cof_hud_msg_probe`, `cof_hud_text_trace` | [HUD text](cof-hud-text-legibility.md) |
| 26 | `cof-gl-stage-trace` | R | `cof_gl_trace`, `cof_skip_client_normal_triangles` (diag) | [GL stage trace](cof-gl-stage-trace.md) |
| 27 | `cof-solid-entity-trace` | R | `cof_solid_entity_trace` (diag) | [solid-entity trace](cof-solid-entity-trace.md) |
| 28 | `cof-transparent-triangle-trace` | R | `cof_skip_client_transparent_triangles` (diag) | [transparent-triangle trace](cof-transparent-triangle-trace.md) |
| 29 | `cof-skyline-trace` | R | `cof_skyline_trace` (diag) | [skyline trace](cof-skyline-trace.md) |
| 30 | `cof-gl-debug-stack` | R | (sampling under `cof_gl_trace`) | [GL debug stack](cof-gl-debug-stack.md) |
| 31 | `cof-custom-renderfx-opaque` | R | `cof_custom_renderfx_opaque` | [renderfx opaque](cof-custom-renderfx-opaque.md) |
| 32 | `cof-mainui-menu-save` | M | (uses `cof_pause_menu_saves`, `cof_menu_save`) | [MainUI menu save](cof-mainui-menu-save.md) |
| 33 | `cof-mainui-background-scrim` | M | `ui_scrim_alpha` | [milestone 1](cof-ui-m1-plumbing.md) |
| 34 | `cof-mainui-cof-menu` | M | Cry of Fear main menu pages | [milestone 2](cof-ui-m2-cof-menu.md) |
| 35 | `cof-mainui-source-theme` | M | `ui_theme`, `ui_cof_scene_defaults`, `cof_skip_prologue`, `menu_cofdeath`, `menu_cof_sound_probe`, ... | [UI theme](../design/ui-theme.md) |
| 36 | `cof-fov` | E | `cof_fov`, `cof_fov_zoom_knee` | [field of view](cof-fov.md) |
| 37 | `cof-pmove-callback-view` | E | `cof_pmove_legacy_hullsync(_cl)`, `cof_pmove_legacy_touchfix(_cl)` | [pmove callback view](cof-pmove-callback-view.md) |
| 38 | `cof-viewmodel-fov` | R | `cof_viewmodel_fov` | [field of view](cof-fov.md) |
| 39 | `cof-ads-toggle` | E | `cof_ads_toggle`, `cof_ads_hold_pulse`, `cof_key_probe`, `cof_ads_status` | [ADS and binds](cof-ads-toggle.md) |
| 40 | `cof-chapter-rule` | E | `cof_hud_chapter_rule_hide` | [ADS and binds](cof-ads-toggle.md) section 4 |
| 41 | `cof-sprite-quiet-frames` | R | `cof_sprite_quiet_frames`, `cof_sprite_trace` | [sprite frames](cof-sprite-quiet-frames.md) |
| 42 | `cof-language-packs` | E + V | `cof_language`, `cof_language_strings`, `cof_language_files`, `cof_language_trace`, `cof_language_list` / `_status` / `_apply` | [language packs](../design/language-packs.md) |
| 43 | `cof-mainui-language-selector` | M | Language option, `menu_cof_language_select` | [language packs](../design/language-packs.md) section 7 |
| 44 | `cof-mainui-menu-strings` | M | per-pack menu translation, `menu_cof_strings` | [language packs](../design/language-packs.md) section 8 |
| 45 | `cof-coop-bridge` | E + V | `cof_ui_remote_end_menu`, `cof_vgui_text_overflow` | [co-op bridge](../design/coop-bridge.md) |
| 46 | `cof-mainui-coop` | M | Host / Join co-op pages, `cof_coop_*` settings, `menu_cof_host_start` | [co-op bridge](../design/coop-bridge.md) |
| 47 | `cof-cheats` | E | `fly`, `give`, sticky `noclip` / `notarget`, `cof_infammo`, `cof_infstamina`, `cof_nodamage`, `cof_nodrown`, `cof_nightvision`, `cof_ending`, `cof_tapes`, `cof_unlockdoors`, `cof_cheats` | [cheats internals](../design/cheats.md), player list in [CHEATS.md](../../CHEATS.md) |

(diag) = default-off developer diagnostic; it changes nothing unless switched on.

## Compatibility base: running the retail DLLs at all (steps 0-3)

The tested engine source is FWGS `4857b389e6ba32ddaa68582aedcbc950c138f46a`.
The launch dump proved that the original DLL expects `physinfo` and the common
playermove callbacks four bytes later than the current engine's
`playermove_t`: the current table has `PM_Info_ValueForKey` at `+0x4F554`,
while the original `PM_Init` helper reads its two-argument callback at
`+0x4F558`.

`cof-pmove-legacy` adds the `-cof-pmove-legacy` engine option (the launcher
always passes it). It copies the native playermove object into a persistent
four-byte-shifted view for the original DLL's `PM_Init` and `PM_Move` calls,
then copies state back; `cof-client-pmove-legacy` does the same for the client
DLL's two playermove entry points. The entvars and edict overlays
(`cof-entvars-legacy`, `cof-edict-stride-legacy`, built with
`--enable-cof-entvars-legacy`) correct the four-byte shifted range in
`entvars_s` and the `edict_s` stride (`0x32C` in the original DLL, `0x328` in
current FWGS). The inserted fields' identities were never recovered; the
overlays add correctly sized, deliberately diagnostic padding. See
[the adapter](pmove-adapter.md), [the edict stride](edict-stride-proposal.md),
[the entvars evidence](../history/entvars-layout-analysis.md) and
[the ABI findings](../history/abi-findings.md).

The shift boundary was later found to be one field too late: it starts at
`numtouch`, not `physinfo`. That and the stale-hull crouch bug are fixed by
`cof-pmove-callback-view` (milestone 5, below).

## Saves (steps 4-8, 32)

Cry of Fear keeps `SAVE\` beside the game directory, where Xash looks in
`cryoffear\save\`. `cof-save-root-compat` (`cof_save_root_compat`, engine
default `0`, **always set to `1` by the launcher**) maps the server's save
paths to the root `SAVE\` directory with confined direct-path writes, so
existing Steam saves load. `cof-pause-save-plumbing` lets the menu's save list
and comment reader see that directory; `cof-menu-save-backend` adds the
server-side `cof_menu_save <1..5>` transaction behind `cof_pause_menu_saves`
(default `0`, the player's choice in Options > Game) that shares the game's
five slots, writes a `Pause Save (<map>) - <timestamp>` label, backs up an
overwritten slot and rolls back on failure; `cof-tape-save-command` restores
the client's `savehack cofsave1..5` path so tape-recorder saves keep working;
`cof-mainui-menu-save` wires the menu's Save/Load page to all of it.
`cof-menu-load-trace` is the diagnostic (`cof_trace_menu_load`) the save work
was measured with, and later patches use its lines as context.

## Unified UI, milestone 1: the engine menu over the live scene (steps 9, 33)

`cof-ui-input-gate`: with `cof_ui_input_gate 1` (default) the Cry of Fear
client neither paints its VGUI/HUD layer nor receives keyboard and mouse input
while the engine menu, the console or the chat line has focus, and `Escape`
always reaches `CL_Escape_f` so the engine menu opens even while a CoF VGUI
panel is up. The same patch carries `cof_ui_deferred_cmd_guard` (default `1`):
Cry of Fear's `HUD_Init` issues `map c_game_menu1` before the engine is
initialised, the engine parks it in `host.deferred_cmd` and replays it the
first frame the engine menu becomes visible, which threw away a loaded save
and, on a plain boot, replaced MainUI's `map_background` with a real map. The
guard drops that stale boot command. It also packages the
`cof_skip_client_hud_redraw` and `cof_skip_vgui_paint` diagnostics (default 0).

`cof-mainui-background-scrim` makes the in-game menu background a translucent
scrim instead of an opaque fill while `ui_renderworld` is on (`ui_scrim_alpha`,
default `150`; `255` is the old behaviour). Its data files live in
[`gamedata/`](../../gamedata/README.md): `chapterbackgrounds.txt` names
`c_game_menu1` as the background map, `gameinfo.keys` sets `startmap` and
`render_picbutton_text`, and a locally generated `maps/c_game_menu1.ent` drops
the client's own `cof_gamemenu` entity. See [milestone 1](cof-ui-m1-plumbing.md).

## Milestone 2: the menu becomes Cry of Fear's (steps 10, 16, 34)

`cof-mainui-cof-menu` replaces the stock main menu for the `cryoffear` game
directory only (every other game keeps the stock menu). New Game opens a Cry of
Fear difficulty page that forwards the game DLL's own `cmd skillset 1..4` to the
live background-map server, so the original white fade and `c_intro` start
happen for real; Custom Campaign lists `maps/*.custom` and prefixes
`cmd campaign <firstmap>`; Unlockables became an engine-menu page that reads the
real unlock state from `scriptsettings.dat` (27 items, Nightmare gated on line
83), with a button that still runs the client's gallery map; Extras opens the
original links with `ShellExecute` instead of the Steam overlay the game used
(under FWGS `steam_api.dll` is not loaded, so they were silent no-ops), with
*Cry of Fear: Enhanced* (<https://cofenhanced.haej.pl>) added first. The two
white squares top right were MainUI's minimize and close bitmaps with no
`gfx/shell` art behind them; they are gone. The item list and the Language page
were reshaped later (milestone 3 feedback, lang2); see
[milestone 2](cof-ui-m2-cof-menu.md) and [the UI theme](../design/ui-theme.md).

`cof-vid-restart-background`: a video mode change from the menu used to strip
the background scene (custom sky, atmosphere and snow gone, the map's plain
`blue22` skybox left), because FWGS keeps the GL context and only re-calls the
client's `pfnVidInit`, which in this client is a per-level entry point whose
one-shot setup nothing replays. With `cof_vid_restart_background 1` (default) a
completed resolution change or windowed/fullscreen toggle restarts the menu
background map, so the client's per-level init reruns; a real game in progress
is never reloaded. `cof_vid_skip_redundant_vidinit` (default `0`) skips the
client `pfnVidInit` when the render size did not change; it is off because it
was only exercised on SDL2 + `ref_gl` on Windows.
See [video mode changes](cof-vid-restart-background.md).

`cof-levelshot-guard`: `newgame` at the console while the background map runs
shut the server down, and the levelshot queued by the next load then ran with
no world and dereferenced a null path in `FS_FixFileCase`. Two early returns in
`CL_LevelShot_f`; no cvar. See [levelshot guard](cof-levelshot-guard.md).

## Milestone 3: theme, console, redirect, death flow (steps 11-15, 17-20, 35)

`cof-mainui-source-theme` gives the menu one minimalist Source-era look:
centred translucent dark-grey dialogs with a hairline border, an uppercase
title band, a close X and an OK/Cancel row; a centred plain-text main menu
under a `CRY OF FEAR` / `ENHANCED` wordmark; the pause menu as a lower-left
list over the scrim. Controls are drawn from primitives, so nothing depends on
`gfx/shell` art Cry of Fear does not ship. Type is Inter (SIL OFL 1.1) read
from `cryoffear/gfx/fonts/` through stb_truetype (configure with
`--enable-stbtt`) with a GDI fallback chain. Behind `ui_theme` (archived,
default `1`; `0` is the upstream WON look). The same patch carries the Options
tree (Game, Controls, Audio, Video), the death page, the Unlockables and
Credits pages, Skip prologue, the FOV sliders, the HUD scale spinner, the
pause list with separate Save Game / Load Game, the ADS option, and the
"deferred defaults" generation counter `ui_cof_scene_defaults` that applies a
new default once without overriding a player's later choice. See
[the UI theme](../design/ui-theme.md).

`cof-console-style`: with `cof_console_style 1` (default) the console is a
centred translucent panel (`cof_console_width` x `cof_console_height` of the
screen, 0.70 x 0.60) with a title band carrying `CONSOLE` and the build
string, a clickable close X and a separate input box. Tilde, history,
completion, backscroll and notify are untouched code. It opens and closes
instantly (no slide, no fade; milestone 5a). `cof_console_font_grayscale`
loads the font as luminance because the game's `CONCHARS` atlas is orange.
See [the styled console](cof-console-style.md).

`cof-ui-menu-map-redirect`: the game spells "back to the main menu" as
`map c_game_menu1` everywhere (the client's `to3dmenu`, its Unlockables,
difficulty and server-settings panels, and `hl.dll` after deaths, endings and
`closegame`), which brought the old menu back. With
`cof_ui_menu_map_redirect 1` (default) the engine answers with `disconnect`,
`menu_main`, `map_background` of the scene. The gallery's own MAIN MENU button
issues no command at all; it is detected by the panel sound it plays
(`ui/3d_click.wav` at 0.5 through `pfnPlaySoundByName`). The patch also makes a
`disconnect` from anywhere land where Quit to menu lands, behind a one-shot
latch. See [the menu-map redirect](cof-ui-menu-map-redirect.md).

`cof-ui-sound-volume`: the menu's sounds are the game's own UI samples, mixed
for 0.5 but played at 1.0. `ui_sound_volume` (archived, default `1.0`; the
theme sets `0.5` for Cry of Fear) scales them in `pfnPlaySound`, the menu
library's only entry into the mixer, so no game sound can be affected.
Audio page: *Menu sounds* slider. See [menu sound volume](cof-ui-sound-volume.md).

`cof-ui-death-flow`: dying sent the user message `VGUIMenu` with byte 35,
which the client turns into its own `GAME OVER` panel whose `EXIT` reached the
old menu. The engine now catches that message and opens its own death page
(`cof_ui_death_menu`, default `1`): `GAME OVER` over the untouched scene with
Load Game and Exit. The same patch adds `con_enable` (archived), so "Enable
console" on the Game page is a real checkbox. See [the death flow](cof-ui-death-flow.md).

`cof-text-autoscale`: console, notify lines and every engine corner overlay
were a fixed number of pixels tall. The glyph height is now
`cof_text_height_pct` (default `1.7` %) of the render height, continuous, no
per-resolution cases (12 px at 720p, 18 at 1080p, 24 at 1440p, 37 at 2160p),
drawn from Inter atlases in `gamedata/cryoffear/fonts/` (falls back to the
game's `CONCHARS` without them). See [text autoscale](cof-text-autoscale.md).

`cof-mp3-stop-on-map`: the game plays music through the client's own irrKlang
player, which no engine path sees, so a track bled across map changes, loads
and quit to menu. `cof_mp3_stop_on_map` (default `1`) runs the client's
`stopmp3` before a fresh map, new game, load and disconnect, and deliberately
not before `changelevel`, because the game carries a track across in-game
transitions. See [MP3 stop](cof-mp3-stop-on-map.md).

`cof-sky-reset-per-map`: the client owns its sky pass behind its own
`gl_customsky` cvar and writes `0` into it whenever a sky face fails to load;
nothing writes it back. `c_unlockables` has no `skyname`, the engine's default
`desert` is not shipped, so the gallery disabled the sky for the rest of the
session. `cof_sky_reset_per_map` (default `1`) restores the value at every
level start (never overriding a `gl_customsky 0` the player set), and
`cof_default_skyname` (archived, default `black`) replaces `desert` for the 56
maps without a sky name. See [sky reset](cof-sky-reset-per-map.md).

`cof-cofenhanced-version`: a second corner line (and the console title band)
reading `cofenhanced <version> (<milestone>, <commit>)` from `VERSION` and the
git hash, via the generated `engine/cof_version.h`. See
[the build stamp](cof-cofenhanced-version.md).

## Milestone 4: the in-game UI scales with the display (steps 21-25)

Every Cry of Fear surface - inventory, HUD bars, ammo counter, phone, notes,
hint and subtitle text - was a fixed-pixel layout built once from the screen
size the client is told about, so at 4K the inventory was a postage stamp. The
obvious lever, `hud_scale`, is **poison for this game**: the client builds its
2D overlay from the same screen info it lays its panels out from, so a virtual
screen size zooms and shifts the view. `hud_scale` is therefore ignored for Cry
of Fear, and `cof-ui-scale` + `cof-vgui-anchor` scale in the engine's VGUI
surface layer instead, with each top-level client surface anchored to the edge
it was laid out against (a full-screen page scales as one centred unit).
`cof_ui_scale 0` (default) keeps the UI at the fraction of the screen it has at
1080p, continuously; `cof_ui_scale_user` is the menu's HUD scale (Auto / 100 /
125 / 150 / 200 %). The same change fixes the inventory-in-the-corner bug after
a video mode change. Both halves are needed, and `vgui.dll` must be deployed
with `xash.dll`. See [UI scaling](../design/ui-scaling.md).

`cof-vgui-inter-fonts`: the client's VGUI text is rasterised from Inter instead
of the game's bitmap strips (whose sizes stop changing at the 1024 bucket).
`cof_ui_inter_fonts 1` sizes each scheme from the render height and answers
the glyph widths itself. `cof_text_codepage` (1250 / 1251 / 1252) decodes each
byte just before the glyph lookup, which the language packs need;
`cof_font_probe` draws a test string. The inventory's own labels are painted
into `gfx/vgui/640_inventory.tga` and are not text. See
[VGUI Inter fonts](../design/vgui-inter-fonts.md).

`cof-ui-death-live` (4b): while the death page is up the world keeps running
(ambience, rain, death music), as behind the original panel
(`cof_ui_death_keep_running`). `cof-hud-text-backing` (4b/4c/5a/5b): engine HUD
text (hints, `HudText`, prompts) from an Inter SemiBold atlas on a translucent
backing strip (`cof_hud_text_font`, `cof_hud_text_backing`, `cof_hud_text_y`);
the pickup lines and cutscene dialogue - one `Label` of the client's
`CHUDControl`, not engine text - pinned to `cof_hud_msg_y_pct` (78 %) of the
screen with the same strip, the scissor moved with the text, the retarget
scoped to runs already in the 35-90 % band, and no strip under the top hint
bar. See [HUD text](cof-hud-text-legibility.md).

## Renderer: the main-menu skyline (steps 26-31)

The skyline on the menu map is translucent brush entity `*23`. FWGS
`R_OpaqueEntity()` only treats a whitelist of `renderfx` values as opaque, so
the client's sky sphere (`rendermode 0`, `renderfx 137`) was sorted into the
translucent list after the skyline and painted over it. GoldSrc classifies by
`rendermode` alone. `cof-custom-renderfx-opaque` restores that rule
(`cof_custom_renderfx_opaque`, default `1`, `FCVAR_GLCONFIG`); `renderfx 137`
is on 99 entities in 74 maps, so the fix is campaign-wide. It also removed the
texture flicker the user had seen on the train. The four trace patches and the
GL debug stack are default-off diagnostics the fix was found with. See
[renderfx opaque](cof-custom-renderfx-opaque.md) and
[the engine and game facts](../history/engine-and-game-facts.md).

## Milestone 5: field of view, crouch fix (steps 36-38)

`cof-fov`: Cry of Fear has no `default_fov`; the client hard-codes 90 at the
hip, and `cl_fovmultiplier` scales ironsights and scripted zooms too.
`cof_fov` (archived, 70-110, stored as the 4:3 base like Source's
`fov_desired`) is added in `V_GetRefParams` to `rvp->fov_x` only, tapering out
towards the authored zooms (`cof_fov_zoom_knee`, 60), so ironsights and
cameras keep their framing: base 70 / 90 / 110 renders 86.09 / 106.26 / 124.60
degrees at 16:9 with pixel-identical glock ironsights. `cof-viewmodel-fov`
(`cof_viewmodel_fov`, 0 = follow world, 55-90) pushes a second projection
inside `R_DrawViewModel`'s depth-range bracket. A viewmodel FOV different from
the world moves iron sights off centre. See [field of view](cof-fov.md).

`cof-pmove-callback-view`: the engine's playermove callbacks read the native
object while the DLL mutates the shifted copy, so every trace in `PM_Move` used
the previous frame's `usehull` and players got stuck in crouch sections. The
patch mirrors `usehull`, `origin` and `velocity` at each callback
(`cof_pmove_legacy_hullsync`) and moves the shift boundary to `numtouch`
(`cof_pmove_legacy_touchfix`), which also restores playermove touch impacts.
See [the pmove callback view](cof-pmove-callback-view.md).

## Milestone 5b: aim down sights, binds, chapter card, sprites (steps 39-41)

`cof-ads-toggle`: the game's ironsights are a toggle (`hl.dll`'s
`ironsights_toggle`, never saved) and its own Hold mode is broken (a held aim
key blocks every shot; the hunting rifle ignores it). `cof_ads_toggle`
(archived, default `1`) is the saved option behind "Aim down sights: Hold /
Toggle"; in Hold the engine turns each press and release into a short toggle
pulse (`cof_ads_hold_pulse`), retried while the weapon refuses. Defaults
generation 4 swaps MOUSE2 (now aim) and MOUSE3 once in configs that still hold
the shipped binds, and `gamedata/cryoffear/gfx/shell/kb_def.lst` makes "Use
defaults" agree. `cof-chapter-rule` (`cof_hud_chapter_rule_hide`, default `1`)
drops the chapter card's white rule, a raw `pfnFillRGBA` hairline that no
longer lines up with the scaled title. See [ADS and binds](cof-ads-toggle.md).

`cof-sprite-quiet-frames` (`cof_sprite_quiet_frames`, default `1`): the
"no such frame 255 (sprites/glow01.spr)" flood came from the tape recorder's
blink light, a one-frame `CSprite` whose frame `hl.dll` never wraps; the
renderer now clamps silently (`cof_sprite_trace` finds the source).
See [sprite frames](cof-sprite-quiet-frames.md).

## Milestone 6: language packs (steps 42-44)

`cof_language <code>` (archived, empty = English) switches the game to a pack
under `cryoffear/languages/<code>/`. Three mechanisms, because Cry of Fear
loads its localisable data three ways: the pack's same-path art and models go
on top of the engine search path and its per-map `.ent` overrides and
repainted sign textures are probed first; the game DLLs' own `txtfiles/`,
`notes/` and `inventoryitems/` reads are redirected into the pack, both where
`client.dll` and `hl.dll` use their single `KERNEL32!CreateFileW` import
(patched in memory at load, restored before unload) and where they go through
the engine's `COM_LoadFileForMe`; and the strings compiled into the DLLs are
replaced at draw time from `strings/dll-strings.tsv`. The manifest's code page
goes into `cof_text_codepage`. Nothing on disk is ever modified.

The menu half is one **Language** option on the Game page: English plus every
installed pack by its `display_name` (Polski, plus six minimal packs -
Deutsch, Español, Français, Nederlands, Norsk, Svenska - that carry only a
translated menu and select the game's own subtitle slot). A row sets
`cof_language` and the client's `cof_subtitlelanguage` together, and the menu
itself is translated from the pack's `strings/menu-strings.tsv`, switching at
once. See [language packs](../design/language-packs.md) and
[`languages/README.md`](../../languages/README.md).

## Co-op bridge (steps 45-46)

Cry of Fear's co-op is plain GoldSrc multiplayer plus a lobby inside the game
DLL and runs under FWGS as it is; what was missing was the way in. The original
Join / Host buttons sent `optionshack 0/1`, which only the game's own engine
understood, and MainUI's stock Create Server page issues a `disconnect` first,
which the unified UI turns into a single-player background map. **Host co-op**
lists Story co-op, Manhunt and Survival 1-4 with difficulty, players (2-4),
lobby autostart (`mp_footsteps`, 120 s), auto respawn
(`sv_auto_respawn_time`, 384 s), server name, password, LAN only and player
name, and Start issues the exact sequence without `disconnect`
(`deathmatch 1` is the switch, not `coop`). **Join co-op** takes an address and
a name. In multiplayer the pause menu has no Save / Load and reads Disconnect.
Engine half: back to the menu over the background map when a remote session
ends (`cof_ui_remote_end_menu`), the lobby hint lines no longer cut off
(`cof_vgui_text_overflow`), and `Cmd_ExecScript` no longer glues a cfg's last
line onto the next command (upstreamable). See [the co-op bridge](../design/coop-bridge.md).

## Restored cheats (step 47, last)

Cry of Fear 1.6 removed its cheats in its own `hw.dll` and resets or ignores
the stock ones in `hl.dll` (`PostThink` turns noclip off every frame,
`TakeDamage` never looks at godmode, there is no `give`). The patch makes
`noclip`, `notarget` and a new `fly` stick by re-asserting them after the
game's `PlayerPostThink`, adds an engine `give` that hands an item over the way
a pickup does, and adds `cof_infammo`, `cof_infstamina`, `cof_nodamage`,
`cof_nodrown`, `cof_nightvision`, `cof_ending`, `cof_tapes`, `cof_unlockdoors`
and the `cof_cheats` status line, which write the retail DLL's own dormant
switches and player fields. Everything needs `sv_cheats 1` **and** a SHA-256
match of the loaded `hl.dll` against retail 1.6; any other game DLL gets the
stock behaviour and a one-line refusal. Player list: [CHEATS.md](../../CHEATS.md);
internals: [cheats](../design/cheats.md).
