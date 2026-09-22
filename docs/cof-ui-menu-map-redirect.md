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

**That button turned out not to be a level change at all.** The first version of
this redirect covered every command producer and the user still reported the bug
on the shipped engine `BD90FDB9…`. The measurement is in
[§ The producer that issues nothing](#the-producer-that-issues-nothing-the-unlockables-main-menu-button):
the gallery's MAIN MENU calls `setVisible( true )` on the client's own
`CGameMenu` panel in place, over the map that is already loaded, and never
touches the engine's command path. A fifth interception point was added for it.

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
| `client.dll` `CSaveLoad::OnCommand( 1 )`, VA `100314A0` | push at VA `10031680` | `pfnClientCmd`. The client's own save/load panel (`gViewport + 0x1464`, vtable `10144048`, handler thunk `100327C0` / `CSaveLoadHandler_Command`). Its back button tests the current level name against `"game_menu"`, `"difficulty_"`, `"server_"`, `"unlockables"` and asks for the menu map on the last three. **Not** the Unlockables MAIN MENU button - that correction is below |
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
| `engine/client/cl_main.c` (`CL_CoF_Disconnect_f`, the `disconnect` console command) | **the sixth point**, added 2026-09-22 and not a redirect at all: it leaves the disconnect alone and only re-arms the background map behind it, so a console `disconnect` lands where Quit to menu lands. See [§ `disconnect` re-arms the background map too](#disconnect-re-arms-the-background-map-too-2026-09-22) |
| `engine/client/dll_int/cl_game.c:1922` (`pfnPlaySoundByName`) | **the fifth point**, and the only one that is not on the command path at all: the Unlockables gallery's MAIN MENU button, which shows the client's own `CGameMenu` panel in place. See [§ The producer that issues nothing](#the-producer-that-issues-nothing-the-unlockables-main-menu-button) |

The first four call into one predicate pair in `engine/client/cl_main.c`:

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

## The producer that issues nothing: the Unlockables MAIN MENU button

The first version of this redirect covered every *command* producer and the user
still reported the bug on the shipped engine `BD90FDB9…`. The reason is that the
button is not a command producer.

### What the button does (measured, read-only disassembly)

`CUnlockables::OnCommand( 50 )`, `client.dll` VA `10035950`, arm at `10035991`:

```
10035991  cmp   dword ptr [10542A68], 0     ; the gallery's own unlock gate
1003599E  mov   eax, [101B2600]             ; gViewport
100359AB  cmp   dword ptr [eax+1468], 0     ; gViewport->m_pGameMenu
100359B8  ...   this->vtable[0x24]( 0 )     ; CUnlockables::setVisible( false )
100359C7  call  100AAAD0                    ; gViewport->UpdateCursorState()
100359D1  ...   m_pGameMenu->vtable[0x24]( 1 )   ; CGameMenu::setVisible( true )
100359E4  call  100AAAD0                    ; gViewport->UpdateCursorState()
100359EA  mov   dword ptr [esp], 3F800000h  ; 1.0f
100359F1  push  1014078C                    ; "ui/3d_click.wav"
100359F6  call  dword ptr [101B2660]        ; pfnPlaySoundByName
```

No console command, no `ServerCmd`, no user message, no level change anywhere on
that path: the client simply shows its own main-menu panel over the map that is
already loaded. `gViewport->m_pGameMenu` (`+0x1468`) has vtable `10143200`,
whose slot `+0x24` is the override `CGameMenu::setVisible` at VA `1002ECF0` -
every other panel in the binary leaves that slot as the base thunk `100B34A0`.

### What the engine can see, and the discriminator

`CGameMenu::setVisible( true )` (`1002ECF0`) shows each of its ~22 child controls
(`this+0xC6B4 … this+0xC73C`), hides two more, and ends with:

```
1002EE59  mov   dword ptr [esp], 3F000000h  ; 0.5f
1002EE60  push  1014078C                    ; "ui/3d_click.wav"
1002EE65  call  dword ptr [101B2660]        ; pfnPlaySoundByName
```

`"ui/3d_click.wav"` lives at VA `1014078C` and is pushed at exactly 19 sites in
`client.dll`. Twelve of those are `pfnPlaySoundByName` calls (the imported slot
`101B2660`); the other seven, at `1002FE2A`…`1003009A`, are a different call
through `101B2758` and never reach this hook. Of the twelve, **eight pass
`0.5f`** - `1002D91D`, `1002D998`, `1002D9EE`, `1002DC61`, `1002DCF3`,
`1002DD67`, `1002DF32` and `1002EE60` - and all eight are methods of `CGameMenu`
itself (they work on the `0xC2xx`/`0xC6xx`/`0xC7xx` members of that one
`0xC748`-byte object). Every other site passes `1.0f`, including the outer
`CUnlockables` arm above and the item viewer's way back to the gallery
(`1001F0ED`, also on `c_unlockables`).

So a `pfnPlaySoundByName( "ui/3d_click.wav", 0.5f )` means exactly one thing:
**the Cry of Fear main-menu panel is taking the screen.** Under the unified UI
that is the same request as `map c_game_menu1`, and it is answered with the same
queued sequence. The `1.0f` clicks are left alone, which is what keeps the
gallery's own item buttons working.

The sound still plays - the user pressed a button and should hear it - and
nothing is executed at the interception point; the return is queued exactly as
for the command producers, and the `disconnect` that follows one frame later is
what actually takes the panel off the screen.

`CL_CoF_MenuPanelSound()` (`engine/client/cl_main.c`) additionally requires
`cls.state == ca_active`, `cl.maxclients <= 1` and `cl_background == 0`, so it
can never fire on the background map (where the panel cannot be on screen) or in
multiplayer (where Cry of Fear's own panels disconnect instead). One press
produces two clicks, so `cof_menu_panel_map` remembers the map a return was
already queued on; `CL_CoF_RememberBackgroundMap()` clears it when the engine is
back on the background map.

### Testing it without a mouse

The hook answers to a VGUI mouse click, and this project may not inject mouse or
keyboard input. `cof_ui_menu_panel_probe [sample] [volume]` feeds
`CL_CoF_MenuPanelSound()` the same pair `pfnPlaySoundByName` would, defaulting to
the measured one. It plays nothing and touches nothing else, and prints
`taken over` or `passed through`. **Marked for the user's manual test:** the real
click on the gallery's MAIN MENU button.

## `disconnect` re-arms the background map too (2026-09-22)

The user: *typing `disconnect` in the console lands in the engine menu with NO
background map, unlike Quit to menu.*

**Why the two differed (measured, source).** Quit to menu is not the
`disconnect` doing that. `CMenuMain::DisconnectCb`
(`3rdparty/mainui/menus/Main.cpp:201`) issues `ClientCmd("disconnect\n")` and
sets `bCoFWantBackgroundMap`; `CMenuMain::Think` (`:831`) then waits for
`!ClientInGame() && cl_background == 0 && host_serverstate == 0` to hold for
`COF_BACKGROUND_RESTART_DELAY` frames and calls `UI_StartBackGroundMap()`. That
re-arm lives in the *menu's* code, so it belonged to that one button: a typed
`disconnect`, an alias, a cfg line or a stufftext all left the engine menu
standing over nothing.

**The fix.** `CL_CoF_Disconnect_f()` (`engine/client/cl_main.c`) wraps the
`disconnect` **console command** - the one thing every route shares - and, with
`cof_ui_menu_map_redirect` on and a single-player session up, queues the same
two commands the return sequence uses after its own disconnect:

```
menu_main
map_background <the remembered chapter background>
```

It then calls the real `CL_Disconnect_f()`. The engine's own internal callers
(connection failure, host error, `CL_Crashed`, the retry paths at
`cl_main.c:3485` etc.) still call `CL_Disconnect_f` directly and are unaffected;
only `Cmd_AddCommand ("disconnect", …)` was repointed.

Ordering is the trick `CL_CoF_MenuMapReturn` already relies on: the commands are
only *queued*. `CL_Disconnect_f` ends a local game through `Host_EndGame()`,
which aborts the current frame, and `Cbuf_ExecuteCommandsFromBuffer` has already
popped the `disconnect` line, so the two queued commands run at the start of the
next frame with the server really down - which `SV_MapBackground_f` insists on
(*can't set background map while game is active*).

### Not armed twice: `cof_menu_return_armed`

One file-static one-shot latch in `cl_main.c`, cleared by
`CL_CoF_RememberBackgroundMap()` (the same place `cof_menu_panel_map` is
cleared, i.e. when a background map really starts):

* **the redirect's own sequence** already begins with `disconnect`.
  `CL_CoF_MenuMapReturn()` sets the latch when it queues, and that `disconnect`
  consumes it here and arms nothing. Logged as
  `"disconnect" - background map already armed, not arming again`;
* **MainUI's Quit to menu** issues a bare `disconnect`, so it *is* armed here -
  and the menu's own delayed re-arm then cannot fire, because
  `CMenuMain::Think` requires `cl_background == 0` for 30 consecutive frames and
  `UI_StartBackGroundMap()` (`BaseMenu.cpp:611`) refuses outright while
  `cl_background` is set. The engine's `map_background` runs one frame after the
  disconnect, long before that count could complete. One background map is
  started, not two - measured below.

Guards, the same family as the rest of this patch: nothing happens with the cvar
off, with `cls.state == ca_disconnected` (there is no session to leave), or with
`cl.maxclients > 1`.

**Known bound.** If `map_background` is refused after the latch was set (a
missing or invalid map), the latch stays set until the next disconnect consumes
it, so that one disconnect does not re-arm. It is self-healing after one extra
disconnect and cannot leave the game in a bad state.

### Log lines

```
[cof-ui] menu map redirect: "disconnect" -> menu_main + map_background c_game_menu1
[cof-ui] menu map redirect: "disconnect" - background map already armed, not arming again
```

### Validation

Fixture `stage1/ui-m1-menu-fixture-20260921` (not the engine fixture: that one
junctions `cryoffear\gfx` and `cryoffear\resource` into the canonical read-only
copy, see `stage1/canonical-restore-20260922/README.md`), driver `run-m2.ps1`,
windowed 1280x720, `+volume 0`, `-dev 2 +set developer 2`, every command from
`+exec <case>.cfg` and `maps/<map>_load.cfg`, each case cfg ending in `quit`.
**No keyboard or mouse input was injected.** Engine
`1C25CE6BF17EB3C7A70931CD6D00D9296917B41F756CDA6FFD4E603ECF197C13`, menu
`F7E46B3A2A472AFED3167E78D2D575EC58A631AF344FE6789A344346F0A569DF`.

Quit to menu is a click on a menu item followed by a click on the
confirmation's positive button, neither of which this project may inject, so
the menu gained `menu_cof_quit_to_menu` (`3rdparty/mainui/menus/Main.cpp`,
same pattern as `menu_cof_extras_list`), which runs exactly
`CMenuMain::DisconnectCb`.

| Run | What it shows |
| --- | --- |
| `dm1-console-disconnect` (`dmcase1.cfg`) | `+load cofsave1` -> `Spawn Server: c_forest3`, then a plain `disconnect` from the `c_forest3` load hook: `[cof-ui] menu map redirect: "disconnect" -> menu_main + map_background c_game_menu1` (log:1300), `Host_EndGame`, **one** `Spawn Server: c_game_menu1` (log:1314); `-b.png` is the engine main menu over the live scene, snow and lit windows and all |
| `dm2-quit-to-menu` (`dmcase2.cfg`) | the same route through `menu_cof_quit_to_menu`: the identical redirect line at log:1300 and again **exactly one** `Spawn Server: c_game_menu1`. No second `map_background` anywhere in the log - MainUI's own delayed re-arm never fires |
| `dm3-control-off` (`dmcase3.cfg`, `+set cof_ui_menu_map_redirect 0`) | the reported behaviour, reproduced: no redirect line, **zero** `Spawn Server: c_game_menu1`, and `-b.png` is the menu over MainUI's flat Steam background bitmap (`LoadBackground: found steam background in game directory`) instead of the live map |
| `dm4-redirect-latch` (`dmcase4.cfg`) | the client's own `to3dmenu` -> `"map c_game_menu1" from client pfnClientCmd -> disconnect + menu_main + map_background` (log:1001) immediately followed by `"disconnect" - background map already armed, not arming again` (log:1002), and **one** `Spawn Server: c_game_menu1` (log:1014). The latch works and the existing redirect is unregressed |

The same four cases also exist as `dccase1.cfg`, `dccase2.cfg` and `dccase3.cfg`
in `stage1/ui-m1-engine-fixture-20260921` for `run-menuredirect-case.ps1`; they
produce the same lines, but that fixture cannot show the theme's Inter faces
without writing into the canonical copy, so the published captures are the `dm*`
set.

Canonical tree bracketed by
`stage1/ui-m1-engine-fixture-20260921/evidence/canonical-uisound-before.txt` and
`-after.txt`: 6 197 files, 4 702 274 797 bytes, newest write
`2026-09-18T20:33:58.9860178Z`, identical apart from the `taken=` line.

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

The panel hook was verified on engine
`96F0BA9CCEE3CA36FB1F125BA8C07416F24AFF94C500A4225066299F0EB92C17`
(2026-09-22), same fixture and driver:

| Run | What it shows |
| --- | --- |
| `g1-panel-on` | `unlockablescmd` -> `Spawn Server: c_unlockables` (`-b.png` is the real CoF gallery), then `cof_ui_menu_panel_probe`: `[cof-ui] menu map redirect: "Cry of Fear main menu panel" from client menu panel -> disconnect + menu_main + map_background c_game_menu1`, `menu panel probe: "ui/3d_click.wav" 0.50 -> taken over`, `Spawn Server: c_game_menu1`, and `-c.png` is our menu with no CoF panel |
| `g2-panel-off` | `cof_ui_menu_map_redirect 0` control in the same binary: `menu panel probe: … 0.50 -> passed through`, no redirect line, `-c.png` is still the CoF gallery |
| `g3-volume` | the volume discriminator: `… 1.00 -> passed through` (the ordinary button click, `-c.png` unchanged), then `… 0.50 -> taken over` and our menu |

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
* **The panel hook keys on a sound, not on a command.** That is a deliberate
  choice forced by the client: the MAIN MENU arm reaches the engine through
  nothing else (no command, no user message, no level change), and the engine
  cannot call into the client's VGUI object to hide the panel. The
  discriminator is the 0.5 volume, which the static scan above shows belongs to
  `CGameMenu`'s own methods alone in the shipped `client.dll`. It is therefore
  exact for **this** binary and would need re-measuring if the client were ever
  replaced. The failure mode is bounded in both directions: a false positive
  returns to our menu (which under the unified UI is what a `CGameMenu` show
  means anyway), a false negative leaves the old behaviour. `cof_ui_menu_map_redirect 0`
  turns it off with the rest of the redirect, and the guard on `cls.state`,
  `cl.maxclients` and `cl_background` keeps it out of every state where the CoF
  panel cannot be on screen.
* The panel is **not suppressed**, it is out-competed: the queued `disconnect`
  runs one frame later and tears the session down, which takes the panel with
  it. For the frame or two in between the client's panel is on screen; nothing
  in the engine can hide a client VGUI panel directly.
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

### Artefacts, 2026-09-22 (disconnect round)

| Artefact | Bytes | SHA-256 |
| --- | ---: | --- |
| `patches/cof-ui-menu-map-redirect.patch` | 27 711 | `C2A120D114A884F1F892088252C0E8E78B5E6CF0325620406AB2728B434357B2` |
| `xash.dll` (`build-cof-ui-m1-engine-20260921`) | 3 520 000 | `1C25CE6BF17EB3C7A70931CD6D00D9296917B41F756CDA6FFD4E603ECF197C13` |

**Regenerated in place, and re-anchored on a clean stack.** The patch had drifted
out of step with the trees it was being reversed on, so this round rebuilt its
baseline from scratch: `cof-fix/pristine-clean` plus the README's ordered
helpers up to and including `apply-cof-vid-restart-background.ps1`, the patch
generated against exactly that, LF-normalised. `CL_CoF_Disconnect_f` is placed
immediately **before** `CL_CoF_MenuMapRedirect`, because the death-flow patch
inserts `CL_CoF_MenuReturn_f` right after it and uses `qboolean
CL_IsIntermission( void )` as its following context.

Verified three ways:

1. old ↔ new round trip in a scratch copy: forward apply, byte-identical
   result, reverse check;
2. the whole documented engine stack applied in order on a fresh copy of
   `pristine-clean` (`cof-fix/pristine-stackverify-20260922`, 20 apply scripts,
   zero failures), whose `engine/` then differs from the working build tree in
   **no content line at all** - only in a handful of pre-existing blank-line
   positions and in the generated `engine/cof_version.h`;
3. the engine rebuilt from the working tree after the relocation and re-run
   through all four validation cases above.
