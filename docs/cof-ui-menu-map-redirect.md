# Cry of Fear menu-map redirect (`cof_ui_menu_map_redirect`)

Unified UI stack. Cry of Fear's main menu is not a menu: it is a client VGUI
panel that lives on the real map `c_game_menu1`. "Go back to the main menu" is
therefore spelled `map c_game_menu1` throughout the game - by the client's own
console commands and panel handlers, and by `hl.dll` after deaths, endings and
the `closegame` teardown. Under the unified UI the main menu is the *engine*
menu drawn over a background map, so every one of those requests is a request
to come back to our menu, not to load a level and hand focus back to the Cry of
Fear panel.

The user-visible symptom that started this: from `c_unlockables`, the gallery's
**MAIN MENU** button brought up the old Cry of Fear menu instead of ours.

The behaviour is behind the engine cvar `cof_ui_menu_map_redirect`, default `1`.
Like the rest of the `cof_ui_*` family it is deliberately **not**
`FCVAR_ARCHIVE`, so an old `config.cfg` cannot silently pin it off; set it on
the command line (`+set cof_ui_menu_map_redirect 0`) or in a cfg to get the
stock behaviour back for a comparison.

## Who issues the command (measured)

Static disassembly of the shipped Cry of Fear binaries, read-only
(`GAME/cryoffear/cl_dlls/{client.dll,hl.dll}`):

| Producer | Site | How it is issued |
| --- | --- | --- |
| `client.dll` `HUD_Init` | push of `101427F4` at VA `1007A4B8` | `pfnClientCmd` (`cl_enginefunc_t` index 20) - boot time, before `cls.initialized`; owned by `cof_ui_deferred_cmd_guard`, not by this patch |
| `client.dll` `to3dmenu` console command | VA `1006E38A` (handler `1006E370`) | `pfnClientCmd`, single player only (`GetMaxClients() > 1` disconnects instead) |
| `client.dll` panel handler, level-name dispatcher `100314A0` | push at VA `10031680` | `pfnClientCmd`. This is the handler that tests the current level name against `"game_menu"`, `"difficulty_"`, `"server_"`, `"unlockables"` - i.e. **the Unlockables MAIN MENU button the user reported** |
| `client.dll` VA `100294C0` | push at VA `10029DDC` | `pfnClientCmd` |
| `client.dll` VA `10040B40` | push at VA `10040B74` | `pfnClientCmd`; the other arm of the same handler issues `ServerCmd("closegame")` (`10142808`) |
| `hl.dll` VA `10048040` and `1004ACE0` | pushes at VA `10048056` / `1004ACF6` | `UTIL_FindEntityByClassname(NULL, "player")` then **`CLIENT_COMMAND( player, "map c_game_menu1" )`**, i.e. `enginefuncs_t` index 41, which reaches the client as an **`svc_stufftext`** |

The `enginefuncs_t` base in `hl.dll` is `10222F48` (`GiveFnptrsToDll` at
`100B4AA0`: `mov edi, 10222F48h`), so the imported slot `10222FEC` used by both
`hl.dll` sites is index `(0x10222FEC - 0x10222F48) / 4 = 41` =
`pfnClientCommand`. Index 39 (`pfnServerCommand`, `10222FE4`) is **not** used
for this string anywhere in `hl.dll`.

`c_unlockables.bsp`'s entity lump holds only `worldspawn`,
`info_player_start`, a `light`, `game_player_equip` and `cof_unlockables`; the
MAIN MENU button is not an entity output, it is the client panel handler above.

## Interception points

| File:line (current checkout) | Producer it covers |
| --- | --- |
| `engine/client/dll_int/cl_game.c:1850` (`pfnClientCmd`) | the client DLL, once `cls.initialized` is set |
| `engine/server/sv_game.c:2336` (`pfnServerCommand`) | a game DLL using `SERVER_COMMAND`; precautionary, Cry of Fear does not use it for this |
| `engine/client/parse/cl_parse.c:2438` (`svc_stufftext` in `CL_ParseCommonHLMessage`) | `hl.dll`'s `CLIENT_COMMAND` |
| `engine/server/sv_cmds.c:213` (`SV_Map_f`) and `:563` (`SV_ChangeLevel_f`) | the backstop: an alias, a cfg, a typed console line, a compound stufftext - any other route to the same level change |

All five call into one predicate pair in `engine/client/cl_main.c`:

* `CL_CoF_MenuMapRedirect( cmd, source )` (`:519`) - string form. Splits the
  command on `;` and newlines and takes it over **only** when the whole string
  is that one level change. A compound command that merely contains one is left
  to the stock path, so the function can never promote a server's stufftext from
  the filtered command buffer into the unfiltered one; the backstop still sees
  it afterwards.
* `CL_CoF_MenuMapLevelChange( mapname, source )` (`:469`) - map-name form, used
  by the two console commands.
* `CL_CoF_ParseMenuMapCommand()` (`:379`) accepts `map` or `changelevel`,
  case-insensitive, any whitespace, an optionally quoted and optionally
  extensioned map name, and nothing after it (a `changelevel2 <map> <landmark>`
  stays a real transition).
* Neither fires while `cl.maxclients > 1`. Cry of Fear's own client makes the
  same distinction: with more than one client its menu buttons disconnect
  instead of loading the menu map.

`map_background c_game_menu1` is a different command (`SV_MapBackground_f`) and
is deliberately untouched, so the redirect cannot recurse and the background map
still works.

The cvar is file-static in `cl_main.c` (nothing else reads it - every caller
goes through the two predicates), which also keeps this patch's hunks clear of
the milestone-3c `cof-ui-overlay-mirror.patch`, whose `cl_main.c` and
`client.h` hunks sit at the same anchors the rest of the `cof_ui_*` family uses.
Verified: the two patches apply cleanly in either order on the same tree.

## What the redirect issues

`CL_CoF_MenuMapReturn()` (`engine/client/cl_main.c:429`) queues, in one
`Cbuf_AddText`:

```
disconnect
menu_main
map_background <background map>
```

This is the sequence MainUI's own Quit-to-menu path produces, measured in
`3rdparty/mainui`:

* `CMenuMain::DisconnectCb` (`menus/Main.cpp:180-192`) issues
  `ClientCmd("disconnect\n")` and sets `bCoFWantBackgroundMap`;
* `CMenuMain::Think` (`menus/Main.cpp:709-728`) waits until
  `!ClientInGame() && cl_background == 0 && host_serverstate == 0` has held for
  30 frames, then calls `UI_StartBackGroundMap()`;
* `UI_StartBackGroundMap()` (`BaseMenu.cpp:548-583`) picks a random entry of the
  list MainUI loaded from `scripts/chapterbackgrounds.txt`
  (`UI_LoadBackgroundMapList()`, `BaseMenu.cpp:971-995`) and issues
  `map_background <name>`.

`menu_main` is added in between because `CL_Disconnect()` only calls
`UI_SetActiveMenu( true )` in non-developer mode.

MainUI's 30-frame idle wait exists because a queued level change is not visible
in any cvar yet. The engine does not need it: `disconnect` on a local game goes
through `Host_EndGame()`, which aborts the current frame, and
`Cbuf_ExecuteCommandsFromBuffer()` (`engine/common/cmd.c`) pops each line
*before* executing it, so `menu_main` and `map_background` stay in the buffer
and run at the start of the next frame, with the server already down. That is
also why the sequence can be queued from inside a client or server DLL callback:
nothing is executed at the interception point.

### Which background map

`CL_CoF_MenuBackgroundMap()` (`:337`), in order:

1. the last background map the engine really started -
   `CL_CoF_RememberBackgroundMap()` (`:315`) is called from
   `SV_MapBackground_f` (`engine/server/sv_cmds.c:297`), which is where MainUI's
   random choice actually lands;
2. otherwise the first entry of `scripts/chapterbackgrounds.txt`, parsed the
   same way MainUI parses it (skip tokens that start with a digit, the old
   format list's numbers);
3. otherwise `c_game_menu1` itself, so the redirect can never end up with no
   scene at all.

### Log line

One developer-level line per redirect:

```
[cof-ui] menu map redirect: "map c_game_menu1" from client pfnClientCmd -> disconnect + menu_main + map_background c_game_menu1
```

and, when the engine is already on the background map (the request is then a
no-op and is dropped rather than run):

```
[cof-ui] menu map redirect: dropped "map c_game_menu1" from client pfnClientCmd (already on the background map)
```

## The CoF `GameMenu` user message

**Already handled; this patch adds nothing for it.** Two independent mechanisms
keep the client's 3D panel off our menu, and a third makes them mostly moot:

* `gamedata/cryoffear/maps/c_game_menu1.ent` drops the `cof_gamemenu` entity, so
  the server never sends the `GameMenu` user message at all (milestone 1).
* The support library self-suppresses: FreeVGUI's `XashPaint`
  (`3rdparty/freevgui/platform/xash3d-fwgs/app.cpp:53-55`) returns early unless
  `CL_IsInGame()`. On a **real** map in single player that is
  `cls.key_dest == key_game`, so with the engine menu up the panel is not
  painted even with `cof_ui_input_gate 0`. Measured: `r6-gamemenu-gate-on-b.png`
  and `r7-gamemenu-gate-off-b.png` are byte-identical
  (`5E100C615B75588E4BE22880CB7951BE3036C9C080CFF1D78003BD2B626CCC3D`).
* `CL_IsInGame()` returns `true` **unconditionally** when `cl.background` is set
  or `cl.maxclients > 1` (`engine/client/cl_main.c:123-131`), which is exactly
  the configuration this redirect lands in. There the support library does not
  suppress anything and `cof_ui_input_gate` is what does: `VGui_Paint` returns
  early while `cls.key_dest != key_game`
  (`engine/client/vgui/vgui_draw.c`). Measured with the `.ent` override removed
  so `cof_gamemenu` really spawns: after a redirect the panel is absent with the
  gate on (`r8-redirect-noent-gateon-b.png`) and with the gate off
  (`r9-redirect-noent-gateoff-b.png`) - in this session the client did not
  re-open the panel on the re-armed background map either way, so the gate was
  not the decisive factor here, but it is the only thing that would be if the
  client did.

And with the redirect on, the situation stops arising: `c_game_menu1` is never
loaded as a real map with focus in the game, which is the one configuration in
which the panel is genuinely on screen (`r6-gamemenu-gate-on-a.png` - the old
Cry of Fear menu, reproduced).

## Validation

Fixture `stage1/ui-m1-engine-fixture-20260921`, driver
`run-menuredirect-case.ps1` (no keyboard or mouse injection at all, no
`SetForegroundWindow`, every command from the command line or from
`maps/<map>_load.cfg`, each case cfg ends with `quit`). Windowed 1280x720,
`+volume 0`, `-dev 2 +set developer 2`. Engine
`build-cof-ui-m1-engine-20260921/engine/xash.dll` SHA-256
`5ED0318A6A996564C11173889EFFF2C792440CF61A1C47E5D0D6039CE3DE10AF`.

| Run | What it shows |
| --- | --- |
| `r1-ingame-to3dmenu` | `+load cofsave1` -> `Spawn Server: c_forest3`, then the client's own `to3dmenu`: `[cof-ui] menu map redirect: "map c_game_menu1" from client pfnClientCmd -> ...`, `Host_EndGame`, `Spawn Server: c_game_menu1` as the background map, `-b.png` is the engine menu over it |
| `r2-ingame-mapcmd` | the same with a plain `map c_game_menu1` from a cfg: caught by the backstop (`from map command`), same result |
| `r3-unlockables` | boot to the engine menu over the background map, `unlockablescmd` -> `Spawn Server: c_unlockables` (`-b.png` is the real CoF Unlockables panel with its MAIN MENU button), then the command that button emits -> redirect -> `-c.png` is our menu again |
| `r3b-unlockables-to3dmenu` | the same route with the client-issued form, logged `from client pfnClientCmd` |
| `r4-control-off` | `cof_ui_menu_map_redirect 0` in the same binary: no redirect line, `Spawn Server: c_game_menu1` as a real level, `-b.png` has no engine menu - the old behaviour, reproduced |
| `r5-newgame-load` | after a redirect: `newgame` -> `Spawn Server: c_difficulty_settings`, then `load cofsave1` -> `Spawn Server: c_forest3` with the HUD back (`-d.png`). New Game and Load Game still work |
| `r6-gamemenu-gate-on` / `r7-gamemenu-gate-off` | `.ent` override moved aside, redirect off, `+map c_game_menu1`: `-a.png` is the old Cry of Fear menu (the bug), `-b.png` after `menu_main` is our menu with no CoF panel, identical with the gate on and off |
| `r8-redirect-noent-gateon` / `r9-redirect-noent-gateoff` | `.ent` override moved aside, redirect on: the re-armed background map carries no CoF panel over our menu |
| `r10-stufftext-probe` | `cl_trace_stufftext 1` in a live game plus `cmd closegame`: the only stufftext observed was `fullserverinfo ""`. The `hl.dll` producer is **statically measured only** |
| `d0-baseline`, `d1-baseline-trace` (2026-09-22) | a real death with `cl_trace_stufftext 1` and `cl_trace_messages 1`: no stufftext at all, and the only relevant message is `VGUIMenu` index 35. See `docs/cof-ui-death-flow.md` |

Canonical tree bracketed by `evidence/canonical-menuredirect-before.txt` and
`evidence/canonical-menuredirect-after.txt`: 6197 files, 4702274797 bytes,
newest write `2026-09-18T20:33:58Z`, identical.

## Risks and limits

* **`c_game_menu1` can no longer be loaded as a real map** while the cvar is on,
  from any route, including a typed console line. That is the intent - under the
  unified UI it is a background map or nothing - but it is a real behaviour
  change; `cof_ui_menu_map_redirect 0` restores it.
* The map name is compiled in (`COF_MENU_MAP`, `engine/client/cl_main.c`). No
  other Cry of Fear menu map is redirected: `c_difficulty_settings`,
  `c_loadgame`, `c_unlockables` and `c_server_settings` still load as real maps
  and are handled by MainUI's own pages (milestone 2) or, as with
  `c_unlockables`, still by the client panel.
* The `hl.dll` stufftext producer was **not observed firing at runtime**. Its
  two call sites are reached through virtual dispatch (no direct `call` or data
  reference exists in the binary) and the paths that reach them - endings and
  the `closegame` chapter teardown - cannot be driven from a cfg without input
  injection. Marked for the user's manual test: finish a chapter and confirm the
  log shows `from server svc_stufftext` (or, if the command arrives inside a
  compound string, `from map command`).

  **Death is no longer one of those paths, measured.** `docs/cof-ui-death-flow.md`
  reproduced a death in the fixture with `cl_trace_stufftext 1` and
  `cl_trace_messages 1`: the only thing the game sends is the user message
  `VGUIMenu` with a first byte of 35, no stufftext arrives at all, and the game
  never asks for a level change. The `map c_game_menu1` a death eventually
  produces comes from the *client*, when the player presses that panel's `EXIT`
  link (`client.dll` VA `10040B74`, `pfnClientCmd`), which this redirect already
  covers and logs as `from client pfnClientCmd`.
* `pfnFilteredClientCmd` (`cl_enginefunc_t` index 91) is not hooked. Cry of Fear
  uses index 20 for every site measured above; anything arriving through the
  filtered entry still meets the backstop.
* The Quake and legacy-Quake protocol parsers (`cl_qparse.c`) are not hooked.
  Cry of Fear under Xash always runs the HL protocol against a local server.
* A mod other than Cry of Fear that legitimately owned a map called
  `c_game_menu1` would be broken by the default. The cvar is the escape hatch;
  the gate family is Cry of Fear specific by design.
* `CL_CoF_RememberBackgroundMap()` is only written by `SV_MapBackground_f`, so a
  session that never opened the engine menu falls back to
  `scripts/chapterbackgrounds.txt`. If that file is missing too the redirect
  arms `c_game_menu1` itself, which is what Cry of Fear wanted anyway.

## Applying

Apply after the unified UI input gate and the video-mode background restart, and
after the menu-load trace (the sv_game.c hunk uses its `pfnServerCommand` lines
as context):

```powershell
pwsh -File .\scripts\apply-cof-ui-menu-map-redirect.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

The script refuses a tree that already carries the redirect, checks all three
prerequisites by marker, verifies concrete markers in all seven touched files
afterwards, and reverse-checks the patch. Verified apply, duplicate-apply
refusal and reverse on `cof-fix/pristine-ui-m1-scratch` after
`apply-cof-ui-input-gate.ps1` and `apply-cof-vid-restart-background.ps1`; that
tree was restored to its starting state afterwards.
