# Co-op bridge: Host co-op, Join co-op and the engine shims

Cry of Fear's co-op is plain GoldSrc multiplayer plus a lobby that lives in the
game DLL. It already runs under FWGS (`stage1/coop-investigation-20260922`);
what was missing is a way in from the unified menu and a few places where the
engine or the menu did the wrong thing around it. This round adds exactly that,
as two patches:

| patch | apply script | what |
| --- | --- | --- |
| `patches/cof-coop-bridge.patch` | `scripts/apply-cof-coop-bridge.ps1` | engine + FreeVGUI: remote-session end returns to the menu scene; lobby hint lines no longer cut off; `Cmd_ExecScript` newline order |
| `patches/cof-mainui-coop.patch` | `scripts/apply-cof-mainui-coop.ps1` | MainUI: the Host co-op and Join co-op pages; the pause menu in multiplayer |

Order: the engine patch goes after the whole documented engine stack including
the milestone-5b patches and `cof-language-packs`, and before
`apply-cof-cheats.ps1` (which touches none of its files). The MainUI patch goes
after `apply-cof-mainui-source-theme.ps1`; it shares no file with
`cof-mainui-language-selector.patch` (that one only edits
`menus/AdvancedControls.cpp`), so the two go on in either order. Evidence:
`stage1/coop-bridge-20260922/RESULTS.md`.

## 1. How co-op is started (measured, not re-derived here)

From the investigation, section 1 and runs 2-8:

* `deathmatch 1` is the switch. `hl.dll` picks its multiplayer rules from
  `gpGlobals->deathmatch` and they set `sv_coop 1` themselves. `coop 1` would
  make the engine force `deathmatch 0` (`sv_init.c`) and give single-player
  rules - `coop` has to stay `0`.
* The lobby is server-side in `hl.dll` on maps whose worldspawn has `iuser1`
  (`cof_campaign_01`, `cof_manhunt_campaign`). Its autostart time is the
  engine cvar `mp_footsteps` (the original `settings.scr` relabels it "Lobby
  autostart time", default 120). `sv_auto_respawn_time` (default 384) is the
  dead-player auto respawn. Difficulty is the archived `difficulty` cvar.
* A `map` issued after `maxplayers` changed shuts the running background
  server down by itself ("Server was killed due to maxclients change").
* A `disconnect` before it is what broke the stock Create Server page under
  the unified UI: `CL_CoF_Disconnect_f` turns a single-player disconnect into
  `menu_main; map_background ...`, and `map_background` forces
  `maxplayers 1 / deathmatch 0`, so the game came up with single-player rules
  and no lobby (investigation run 8).

## 2. The menu pages (`menus/CoFCoop.cpp`)

Both pages are reached from the main menu's Extras list (Join Server, Host
Server), exist only for the `cryoffear` game directory, and remember their
settings in archived cvars.

### Host co-op

| control | values | stored in |
| --- | --- | --- |
| Campaign | Story co-op (`cof_campaign_01`), Manhunt (`cof_manhunt_campaign`), Survival 1-4 (`cof_suicide1..4`); a map that is not installed is left off | `cof_coop_campaign` |
| Difficulty | Easy, Medium, Difficult, plus Nightmare once it is unlocked (same gate as the single-player page: `scriptsettings.dat` line 83) | `cof_coop_difficulty` |
| Players | 2-4 (every co-op map has four slots) | `cof_coop_players` (default 4) |
| Lobby autostart (seconds) | 0-600 in steps of 10; 0 waits for everyone | `cof_coop_autostart` (default 120) |
| Auto respawn (seconds) | 0-9999 | `cof_coop_respawn` (default 384) |
| Your name | text | the engine's archived `name` |
| Server name | text | `cof_coop_hostname` (default "Cry of Fear co-op") |
| Password | text, hidden | not stored (the live `sv_password` is shown) |
| LAN only | check | `cof_coop_lan` |

**Start** writes one block to the command buffer, and nothing else:

```
name "<player>"
hostname "<server>"
sv_password "<password>"
sv_lan <0|1>
mp_footsteps <autostart>
sv_auto_respawn_time <respawn>
pausable 0
difficulty <1..4>
coop 0
deathmatch 1
maxplayers <2..4>
map <entry map>
```

No `disconnect`. Text fields lose `"`, `;` and control characters before they
go between quotes. Start refuses while a real game is running (the page is only
on the main menu's list anyway).

### Join co-op

Server address (host name or IP, optional `:port`; anything with other
characters is refused rather than cleaned), Your name, a hint about port 27015,
and three buttons: **LAN servers** (writes the name, then opens MainUI's stock
server browser on its LAN tab), Cancel, **Connect**:

```
name "<player>"
connect <address>
```

FWGS shuts the local background server down itself when it connects. The
address is remembered in `cof_coop_address`.

### The player name

Cry of Fear's shipped `config.cfg` has `name "Unknown"` (Steam used to supply
the real one). The lobby reads the name from the client's own player table
(`client.dll` `10556CC4`, filled from the engine's player info, i.e. the
`name` userinfo), so every player was "Unknown". Both pages show the engine
`name`, except that "Unknown" (and "Player") is offered as the OS user name the
engine already has in `ui_username`; the page writes it with `name` on Start /
Connect, so it is also archived from then on.

### Test hooks (no input may be injected in this project)

| command | does |
| --- | --- |
| `menu_cofhost`, `menu_cofjoin` | open the page, as the Extras item does |
| `menu_cof_host_start [map] [difficulty] [players] [autostart] [respawn] [lan]` | opens Host co-op, sets the controls the way a user would (`-` leaves one alone), then runs the Start button's own handler |
| `menu_cof_join_connect [address] [cfg]` | opens Join co-op, types the address, runs the Connect button's own handler; the optional cfg is exec'd from behind the page's command (the page appends to the command buffer exactly as a click does, so a test cfg cannot simply continue after it) |

## 3. The pause menu in multiplayer (`menus/Main.cpp`)

In a multiplayer session (`gpGlobals->maxClients > 1`, the test the stock pause
menu already uses) the pause list is Resume game, Options, **Disconnect**,
Quit: no Save Game and no Load Game (the engine refuses saves there, "Can't
save multiplayer games.", and a load would end everyone's session). Disconnect
is the Quit-to-menu item relabelled, with its own confirmation ("Leave the
co-op game and return to the main menu?"); it runs the same callback. The list
is laid out again when the session type changes while it is open.

The menu keeps the world running behind it in multiplayer by itself
(`CL_IsInGame` is true for `maxclients > 1`); nothing else was needed.

**Background re-arm guard.** Quit to menu asks `CMenuMain::Think` to start the
background map once the engine has been idle for 30 frames. When the engine
put the scene back itself first (the single-player disconnect wrapper, or the
remote-session shim below), that request used to stay pending - and the next
time the engine looked idle for 30 frames was the next `connect`, which it
then killed with a `map_background`. `Think` now drops the request as soon as
`cl_background` is set.

## 4. Engine shims (`patches/cof-coop-bridge.patch`)

### (a) Remote session end -> menu over the background map

`cof_ui_remote_end_menu` (default `1`; only while `cof_ui_menu_map_redirect` is
on too; `0` = stock). A joiner's session ends in many places that are not the
`disconnect` command `CL_CoF_Disconnect_f` wraps: the host quits or its server
shuts down (`svc_disconnect` -> `CL_Drop`), a kick, a timeout
(`CL_CheckTimeout`), a refused connection (`CL_Reject`), five unanswered
connect packets (`CL_CheckForResend`, "couldn't connect"). All of them go
through `CL_Disconnect`, and all of them used to leave the joiner in the
console over black.

`CL_CoF_NoteSessionEnd` runs first thing in `CL_Disconnect`, while the ending
session's address is still known. A local game (single player, the background
map, a listen server we host) talks over `NA_LOOPBACK`, and its ends are owned
by `CL_CoF_Disconnect_f` and MainUI's Quit to menu, so only a remote session is
noted. It queues `cof_ui_session_end` rather than deciding on the spot, because
`connect`, `retry` and `reconnect` call `CL_Disconnect` and then start a new
session; the queued command runs after the command that caused it, and if by
then nothing has started a new session it queues `menu_main` and
`map_background <the remembered chapter background>` - the same two commands
`CL_CoF_Disconnect_f` uses (`CL_CoF_MenuBackgroundMap`). The check is appended,
not inserted, so a typed `disconnect; connect x` still connects.

### (b) Pause menu in multiplayer

Menu side, section 3.

### (c) The lobby's hint lines and the "Unknown" name

The CO-OP LOBBY panel's two hint lines ("Press MOUSE1 to become
ready/unready", "Type votekick name in chat to votekick a player") are
client VGUI labels 256 layout units wide that the client sized for its bitmap
font; under the Inter fonts (`cof_ui_inter_fonts`) the centred text is wider
and was cut at both ends. Measured with `cof_hud_text_trace` at 1280x720: role
`pager`, clip `512..768`, text `478..803` and `452..828`.

`cof_vgui_text_overflow` (default `1`; `0` = cut as before): in the support
library's strip-backed text path (`XashSurface::flushBackingText`), a line
that overflows its own label on **both** sides - a centred caption - is drawn
under its parent panel's clip rectangle (`Panel::getParent()->getClipRect`,
the paint stack does not nest panels) instead, for that line only, with half a
glyph height of padding. A left-aligned line that runs off one edge stays cut.
The flag travels on the font descriptor (`cof_vgui_font_t::overflow`), the
same channel as the trace flag.

The name is section 2.

### (d) `Cmd_ExecScript` newline order (upstreamable)

`engine/common/cmd.c`: for a cfg without a trailing newline, FWGS inserted the
file and then the missing `"\n"` - both at the FRONT of the command buffer, so
the newline landed in front of the file and the file's last line was glued onto
whatever command followed the `exec`. Cry of Fear's own `listenserver.cfg` has
no trailing newline; the investigation's runs only escaped the menu redirect by
accident because of it. The fix inserts the newline first, then the file. It
is independent of Cry of Fear and **worth sending upstream**. (The same
function still reads `f[len - 1]` for an empty file; left as it is.)

## 5. Measured

Four launches (three host + joiner pairs over `127.0.0.1`, one single
process), windowed 1280x720, commands only from planted cfgs and the test hooks
above, no input injection (the pause menu was opened with the engine's own
`escape` command). Details, logs, screenshots and hashes:
`stage1/coop-bridge-20260922/RESULTS.md`.

| what | result |
| --- | --- |
| Host page Start from the live background map | the exact block above in the log; "Server was killed due to maxclients change", `maxplayers 2`, `deathmatch 1`, `coop 0`, `mp_footsteps 120`, `sv_auto_respawn_time 384`, `pausable 0`, `sv_lan 1`, `difficulty 3` (`GAME SKILL LEVEL:3`), "Executing listen server config file", "2 player server started"; `sv_coop 1` in play |
| Player name | config `name "Unknown"` -> page offered and set the OS user name; lobby and HUD list show it |
| Join page Connect | joiner in the CO-OP LOBBY, both names, ready via `+attack`, "Starting in 2 seconds", introduction, both players in play (co-op HUD list, pings) |
| Lobby autostart, nobody ready | Manhunt with 30 s: lobby closed on its own, `sv_coop_music` -> `manhunt_intro.mp3` |
| Lobby hint lines | full text with `cof_vgui_text_overflow 1`, cut at both ends with `0` (A/B in one session) |
| Pause menu, host and joiner in play | Resume game, Options, Disconnect, Quit |
| Host quits | joiner: `remote session ... ended` -> `menu_main + map_background c_game_menu1`, main menu over the scene, `cl_background 1` |
| Host uses Disconnect | host back on the main menu over the scene (MainUI re-arm), joiner likewise through the shim |
| Join to a dead address | five retries, "couldn't connect", back on the main menu over the scene |
| After Quit to menu, Join again to a dead address | all five retries happen (the re-arm guard); back on the menu |
| Single player regression | quick save loads; pause list Resume, Save Game, Load Game, Options, Quit to menu, Quit; Quit to menu returns to the scene |
| `Cmd_ExecScript` | a cfg ending without newline, then `echo`: two separate lines (`CB-EXEC-LASTLINE`, `CB-EXEC-NEXT`) |

## 6. Not covered

* LAN discovery (`localservers`) and a real second machine: only loopback was
  run. The LAN servers button is the stock browser, untested here.
* Internet play through NAT, packet loss, latency.
* Survival and Manhunt campaigns beyond their entry map being listed and
  valid; the co-op end/stats maps.
* A kick and a timeout are covered by the same `CL_Disconnect` hook as the
  measured server shutdown and connect failure, but were not run.
