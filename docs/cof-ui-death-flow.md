# The death flow, and "Enable console" (`cof_ui_death_menu`, `con_enable`)

Two unrelated-looking changes ship in one engine patch
(`patches/cof-ui-death-flow.patch`) and one MainUI patch
(`patches/cof-mainui-source-theme.patch`, extended in place), because both are
"the engine grew something the menu can bind to":

1. **The death flow.** Dying in Cry of Fear brought up the *old* Cry of Fear
   UI - a `GAME OVER` panel with `LOAD GAME` and `EXIT` links - and `EXIT` then
   brought up the old menu. Under the unified UI that screen is now ours.
2. **"Enable console".** The Game options page wanted a checkbox for the
   developer console, and stock FWGS has no cvar for it at all.

Labels as elsewhere in this project: **measured** = seen in a screenshot, a log
line or a shipped binary; **inferred** = a reading of measured facts.

---

## 1. What actually happens when you die (measured)

### 1.1 It is a user message, not a command

Reproduced in `stage1/ui-m1-engine-fixture-20260921` with the pre-change engine
`5ED0318A…`: load `cofsave1`, wait for `c_forest3`, then `kill` from
`maps/c_forest3_load.cfg`, with `developer 2`, `cl_trace_stufftext 1` and
`cl_trace_messages 1` (`evidence/d1-baseline-trace.log`). Every user message
between the `kill` and the panel appearing:

```
COFDEATH-kill-now
USERMSG DualWield  SIZE 21 SVC_NUM 155
USERMSG Health     SIZE  3 SVC_NUM  65
USERMSG CurWeapon  SIZE  3 SVC_NUM  61
USERMSG SetFOV     SIZE  1 SVC_NUM  94
USERMSG HeadShield SIZE  4 SVC_NUM 144
USERMSG FallOver   SIZE  1 SVC_NUM 136
USERMSG DualAmmo   SIZE  8 SVC_NUM 161   (x2)
USERMSG PlayMP3    SIZE 12 SVC_NUM 105
...
USERMSG VGUIMenu   SIZE  2 SVC_NUM 121   <- the GAME OVER screen
```

and then **nothing**. No `svc_stufftext` arrives at all (the only stufftext in
the whole session is the usual `fullserverinfo ""` at connect), no level change
is requested, and the game sits on that panel indefinitely. The screenshot
`evidence/d0-baseline-e.png` is the reproduced old screen: white `GAME OVER`
centred at mid-height over the still-rendered scene, `LOAD GAME` and `EXIT`
beneath it, each on a faint dark strip, no panel and no dimming.

**Timing (measured, same run):** the `VGUIMenu` message arrives between the
240-frame and 360-frame marks after `kill` - the death animation and the
`FallOver` / `PlayMP3` sequence run first. The panel then *fades in* rather
than appearing at once, which is why the 335-frame capture is still empty and
the 635-frame one is not: `CGameOver::setVisible` seeds a float at `255.0` and
`Think` decays it towards `0`, and VGUI1 alpha is inverted, so `255` is fully
transparent.

### 1.2 Which panel, and who sends it

Static disassembly of the shipped binaries, read-only
(`GAME/cryoffear/cl_dlls/{client.dll,hl.dll}`):

| Piece | Where | What |
| --- | --- | --- |
| `CGameOver` | `client.dll` ctor at VA `10040620`, RTTI `.?AVCGameOver@@` | loads `gfx/vgui/game_over.tga`, `…_load.tga`, `…_exit.tga` (and `…_restart.tga` for coop), uses the client's `Title Font` |
| `CGameOver::setVisible` | VA `10040E60`, vtable slot `+0x24` (vtable `10147850`) | on show, plays `game_over.mp3` unless the flag at `105593C4` is set, and starts the fade |
| the object | stored at `gViewport + 0x1474`, constructed at VA `100A49AA` | |
| `CClientViewport::ShowVGUIMenu` | VA `100AA7F0`, jump table at `100AA9D0` / index table `100AAA04` | **menu index 35 (`0x23`) is the only index that shows it** (index 37 is the `GameMenu` panel, index 4 the team menu, …) |
| `MsgFunc_VGUIMenu` | VA `100AA170`, hooked as `"VGUIMenu"` at VA `1006D4E8` | reads byte 1 = the menu index, byte 2 into `105593C4` (the "no death music" flag), then calls `ShowVGUIMenu` |
| the sender | `hl.dll` VA `100EA400` and `100F9B31` | the only two `MESSAGE_BEGIN(…, gmsgVGUIMenu, …)` sites that write `0x23`; `gmsgVGUIMenu` is the global at `10226580`, registered at VA `100E6433` |

Cross-checked: `client.dll` hooks 137 user messages and **none of them is
called `GameOver`, `Death`, `YouDied` or anything similar** - the only
death-adjacent hook is `DeathMsg`, which is Half-Life's kill-feed notice. The
death screen has no user message of its own; it is `VGUIMenu` index 35.

### 1.3 What the two links do

`CGameOverHandler_Command::actionPerformed` at `client.dll` VA `10040B40`,
one `int` argument:

| Link | id | Single player (measured) | Coop arm |
| --- | --- | --- | --- |
| `LOAD GAME` | 1 | `setVisible(0)` on itself, then shows the client's **own** save/load panel (`gViewport + 0x1464`, three `setVisible` calls at `10040C94`…). **No console command is issued at all.** | the `[105431DC]` arm at `10040BC6` makes it a *restart*: `ClientCmd("map <this+0xDC>")`, the level name `MsgFunc_CustomDoc` (VA `10040DE0`) copied in, or `map c_doc_city` if empty |
| `EXIT` | 2 | `setVisible(0)`, then `ClientCmd("map c_game_menu1")` - the push at VA `10040B74`, `cl_enginefunc_t` index 20 - when the client's menu-state word at `10542A68` is non-zero, which it always is (`HUD_Init` writes `1` at VA `1007A4BF`, `to3dmenu` writes `2`, nothing writes `0`) | otherwise `ServerCmd("closegame")` (`10040BA2`) |

So **`EXIT` is a producer of `map c_game_menu1` through `pfnClientCmd`** and
lands in the existing `cof_ui_menu_map_redirect`, which already logs it as
`from client pfnClientCmd`. Also measured: `client.dll` VA `100315B0` re-shows
`CGameOver` when the save/load panel is dismissed while
`[1018D648] <= 0` (the local player's health), which is why cancelling the load
list in the original takes you back to `GAME OVER`.

### 1.4 What this means for the redirect

`docs/cof-ui-menu-map-redirect.md` left one open item: the `hl.dll`
`CLIENT_COMMAND( player, "map c_game_menu1" )` producers at VA `10048040` and
`1004ACE0` were statically measured but never seen firing, and dying was one of
the suggested ways to trigger them. **Measured now: dying does not reach them.**
Both are think functions on chapter/ending entities; the death path does not go
near them. Their note stands for endings and the `closegame` teardown, not for
deaths.

---

## 2. What the engine does now (`cof_ui_death_menu`, default `1`)

Not `FCVAR_ARCHIVE`, like the rest of the `cof_ui_*` family, so a stale
`config.cfg` cannot pin it off; `+set cof_ui_death_menu 0` restores the stock
behaviour in the same binary.

`CL_CoF_DeathUserMessage()` (`engine/client/cl_main.c`) is called from
`CL_ParseUserMessage` (`engine/client/parse/cl_parse.c`) after the payload has
been read and **before** the client DLL is handed the message. It takes an
interest only when all of these hold: the cvar is on, the name is `VGUIMenu`,
the first payload byte is `35`, and `cl.maxclients <= 1` (in a multiplayer game
that screen is a respawn prompt, not the end of a session - the client's own
panels make the same distinction).

The message is **still delivered** to the client afterwards. Nothing is hidden
from the game DLL or the client: its own bookkeeping (including the death-music
flag) stays consistent, and what keeps its panel off the screen is
`cof_ui_input_gate` - `VGui_Paint` returns early while `cls.key_dest` is not
`key_game` (`engine/client/vgui/vgui_draw.c`), which is exactly what opening our
page produces.

### The one-frame delay, and why not `Cbuf_AddText`

The first version queued `menu_cofdeath` with `Cbuf_AddText`. **Measured
failure** (`evidence/d2-ours.log` vs `d4-ours.log`): the command buffer has a
single `wait` counter shared by everything in it
(`Cbuf_ExecuteCommandsFromBuffer`, `engine/common/cmd.c`), so a cfg that was
mid-`wait` when the player died held the death page back until the whole script
had finished - in the test, past the `quit`. `CL_CoF_DeathPump()` is called from
`Host_ClientFrame` right after `CL_ReadPackets` instead: it runs
`Cmd_ExecuteString( "menu_cofdeath" )` on the very next frame whatever the
buffer is doing, and still outside `CL_ParseServerMessage`, so the menu library
is never entered from the middle of a packet parse.

A latch (`cof_death_menu_open`) keeps a repeated message from stacking a second
page, and `CL_CoF_DeathForget()` clears it from `CL_ClearState`, next to the
video-restart forget, so a disconnect or a save load cannot leave it set.

### Closing the console must not dismiss the page

`Con_ToggleConsole_f` (`engine/client/console.c`) treats "close the console" as
"back to the game" whenever `cls.state == ca_active` and the map is not a
background map - it calls `UI_SetActiveMenu( false )`, which cleans the whole
menu stack. On the death page that would drop the player onto the client's own
GAME OVER panel with the session already over. `CL_CoF_DeathMenuActive()` is
the third term of that test now, so the console goes back to the menu it was
opened from, exactly as it does out of game. The death page is still on the
stack, so `UI_SetActiveMenu( true )` brings that page back rather than the main
menu (MainUI only opens the main menu when the stack is empty,
`BaseMenu.cpp:640`). **Measured**, run `d11-console`: open the console over the
death page, close it again, and `d11-console-c.png` is the death page.

### The new console command `cof_ui_menu_return`

`CL_CoF_MenuMapReturn()` - the redirect's `disconnect` + `menu_main` +
`map_background <scene>` sequence - is now also reachable as a console command,
so the menu can ask for exactly it without spelling out a level change that only
means "back to the menu" because the redirect happens to be on. The death page
uses it only when `cof_ui_menu_map_redirect` is `0`; with the redirect on it
emits the original panel's own `map c_game_menu1` so the measured path is the
one that runs.

### Log lines

```
[cof-ui] death screen: user message "VGUIMenu" index 35 (2 bytes) -> menu_cofdeath
[cof-ui] death screen: opening menu_cofdeath
[cof-ui] input gate engaged (key_dest=2)
```

and, if the message somehow arrives twice,

```
[cof-ui] death screen: repeated "VGUIMenu" index 35 ignored (page already open)
```

---

## 3. The death page (`CMenuCoFDeath`, command `menu_cofdeath`)

`3rdparty/mainui/menus/CryOfFear.cpp`. It follows the original's *structure*,
not its artwork:

* **No panel and no scrim.** `UI_ThemeSetSceneUnveiled(true)` in `Show()` makes
  `CMenuBackgroundBitmap::DrawInGameBackground` draw nothing at all while the
  page is up, so the scene the player died in stays exactly as it was. (With
  `ui_renderworld 0` the engine is not drawing a scene in the first place, and
  the stock opaque fill is kept.)
* **`GAME OVER`** in the main menu's wordmark handle (`hThemeLogo`, 46 virtual
  units, `THEME_TEXT_HI`, `THEME_LOGO_TRACKING`), centred, with its top at 35 %
  of the 768-unit height - where the original puts it.
* **Two items only**, `Load Game` and `Exit`, centred, in the main-menu item
  style, starting at 60 % of the height with a 36-unit pitch.
* Each line carries its own faint dark backing strip
  (`THEME_DEATH_BACKING`, 0 0 0 90, `UI_ThemeDeathBacking`), which is what the
  original does to stay readable over an arbitrary scene. The strip is sized to
  the text, not to the screen.
* **Escape is swallowed.** There is nothing to go back to: the page is the only
  window on the stack and dropping out of it would hand the player back to the
  gated client panel with no way to reach either choice.
* `Think()` closes the page as soon as `ClientInGame()` goes false or
  `cl_background` goes on, so the redirect's `menu_main` never ends up drawn
  over a page that still holds the scrim suppression.
* ~~**Since 2026-09-22** it also stops Cry of Fear's death music: `stopmp3` in
  `Show()`, and a one-shot repeat on the first `Think()` frame.~~ **REVERSED
  2026-09-22 (milestone 4b), by the user's own play feedback.** See §8.

### What each button does

| Button | What it runs | End state |
| --- | --- | --- |
| `Load Game` | `UI_LoadGame_Menu()` - our Load Game page, pushed over this one, so its `Cancel` comes back to `GAME OVER` exactly as the original's save/load panel did | loading a slot runs the page's own `stopmp3` + `load cofsaveN` + `UI_CloseMenu()`, which cleans the whole stack |
| `Exit` | `map c_game_menu1` when `cof_ui_menu_map_redirect` is on (the original link's own command), otherwise `cof_ui_menu_return` | the redirect's `disconnect` + `menu_main` + `map_background <scene>` - our main menu over the background map |

---

## 4. "Enable console" (`con_enable`)

**Measured: stock FWGS has no cvar for the console.** `host.allow_console` is a
bitfield in `host`, set once in `Host_InitCommon` (`engine/common/host.c:1042`)
from `DEFAULT_ALLOWCONSOLE`, `-dev`, `-console`, a dedicated server or a
`quake*` executable name. The only runtime route is
`Cmd_AddRestrictedCommand( "ui_allowconsole", … )`
(`engine/client/dll_int/cl_gameui.c:1474`), which is one-way - it sets
`host.allow_console = host.allow_console_init = true` and nothing can undo it -
and which upstream MainUI exposes as a *push button* on the multiplayer-only
Game Options page (`menus/GameOptions.cpp:126`). There is no archived cvar
gating `Con_ToggleConsole`, so a checkbox had nothing to bind to. (`con_enable`
itself was unused; the similar-looking `xrcon_enable` and `rcon_enable` are the
remote console.)

So the engine patch adds it:

* `con_enable`, **archived**, default `0`, registered in `Con_Init`
  (`engine/client/console.c`). `Con_Init` runs inside `Host_InitCommon`, long
  before `Host_Init` execs `config.cfg`, so a value stored there really reaches
  the cvar.
* `Con_ApplyEnable()` runs from `Con_RunConsole`, which `SCR_UpdateScreen` calls
  every frame in `ca_disconnected` (the menu) and `ca_active` (a session or a
  background map). It mirrors the cvar onto **both** `host.allow_console` and
  `host.allow_console_init`, because `CL_Disconnect` restores the former from
  the latter - the same pair `ui_allowconsole` writes - and it also updates the
  menu library's `developer` global.
* Turning it off never takes away a console the command line unlocked:
  `con_enable_boot` remembers `host.allow_console_init` as it was at `Con_Init`,
  so `con_enable 0` means "do not unlock it", not "lock it".

The checkbox is on the **Game** options page
(`3rdparty/mainui/menus/AdvancedControls.cpp`, which is that page in theme
mode), in the second checkbox column next to *Pause menu saves*, linked to
`con_enable` and written immediately on change like the pause-saves switch.

---

## 5. Verification

Fixture `stage1/ui-m1-menu-fixture-20260921` (the milestone-3 fixture: it
already carries the themed `menu.dll` and the Inter fonts), with the new engine
deployed over `root/xash.dll` and the new `menu.dll` over
`root/cryoffear/cl_dlls/menu.dll`. Drivers `run-death.ps1` (a wrapper around
`run-m2.ps1` that adds the `cof_ui_*` cvars) and `run-conenable.ps1`. Windowed
1280x720 unless stated, `+volume 0`. **No keyboard or mouse input was injected
in any run, `SetForegroundWindow`/`AppActivate` were never called, and nothing
was retried after a failure**; every command comes from the command line, from a
cfg the command line `exec`s, or from `maps/<map>_load.cfg`.

The baseline reproduction (§1.1) is in `stage1/ui-m1-engine-fixture-20260921`
with driver `run-death-case.ps1`.

| Run | Shows |
| --- | --- |
| `d0-baseline`, `d1-baseline-trace` (engine fixture) | the old flow reproduced with the pre-change engine, plus the full user-message trace. `d0-baseline-e.png` is the original `GAME OVER` screen |
| `d2-ours` | the `Cbuf_AddText` version: the hook fires (`death screen: … -> menu_cofdeath`) but the page never opens, because the test cfg's `wait` held the command buffer. This is why `CL_CoF_DeathPump` exists |
| `d4-ours` | the pump version: `user message "VGUIMenu" index 35 (2 bytes) -> menu_cofdeath`, `opening menu_cofdeath`, `input gate engaged (key_dest=2)` on consecutive lines. `d4-ours-c.png` is our death page over the live scene, with no Cry of Fear panel and no HUD |
| `d8-1080` | the same at 1920x1080 |
| `d10-ours` | the **shipped** engine `BD90FDB9…`: the same three lines, `d10-ours-b.png` is the page |
| `d11-console` | `toggleconsole` over the death page and again to close it: `d11-console-b.png` is the console, `d11-console-c.png` is the death page back |
| `d12-control` | the control on the shipped engine: `cof_ui_death_menu 0`, no death-screen line, `d12-control-b.png` is the old Cry of Fear panel |
| `d5-exit` | the `Exit` button's command from a cfg: `menu map redirect: "c_game_menu1" from map command -> disconnect + menu_main + map_background c_game_menu1`, `Host_EndGame`, `Spawn Server: c_game_menu1`; `d5-exit-c.png` is our main menu over the background map, death page gone |
| `d9-return` | the same with `cof_ui_menu_map_redirect 0`, using the page's fallback: `menu map redirect: "cof_ui_menu_return" from menu return command -> …`, same end state |
| `d6-load` | the `Load Game` button's page: `d6-load-b.png` is our Load Game panel over the death page, then `load cofsave1` -> `d6-load-c.png` is gameplay with the HUD back and no menu |
| `d7-control` | `cof_ui_death_menu 0` in the same binary: no death-screen log line, and `d7-control-b.png` is the old Cry of Fear `GAME OVER` panel - the stock flow, reproduced |
| `b1-con-on` / `b3-con-on` | no `-dev`, no `-console`, `+set con_enable 1`: `[cof-ui] con_enable 1: developer console unlocked`, `toggleconsole` opens the console (`b3-con-on-a.png`), and the Game page shows *Enable console* ticked (`b3-con-on-b.png`) |
| `b2-con-off` / `b4-con-off` | the same with `con_enable 0`: no log line, `toggleconsole` does nothing (`b4-con-off-a.png` is the main menu), checkbox unticked (`b4-con-off-b.png`). `cryoffear/config.cfg` carries `con_enable "0"` afterwards, so the cvar really is archived |

The `b3`/`b4` and `d10`-`d12` runs are on the shipped engine `BD90FDB9…`; the
`b1`/`b2` and `d4`-`d9` runs are on `C2A17F23…`, which differs from it only by
the `Con_ToggleConsole_f` term above.

Canonical game copy untouched across every run:
`evidence/canonical-death-before.txt` and `-after.txt` in both fixtures are
identical apart from the `taken=` line - 6 197 files, 4 702 274 797 bytes,
newest write `2026-09-18T20:33:58.9860178Z`.

### Still manual

1. **The two clicks.** Nothing was clicked - no input may be injected - so
   pressing *Load Game* and *Exit* on the page, and their hover states, are a
   manual test. Both buttons' commands were exercised from a cfg and produce the
   measured end states above.
2. **Ticking the "Enable console" checkbox.** The cvar binding is the same
   `CMenuCheckBox::LinkCvar` / `WriteCvar` pair every other checkbox on the page
   uses, and both cvar values were verified to be reflected and to take effect;
   the click itself is a manual test.
3. **Death music.** Settled in §8: the page leaves the client's MP3 player
   alone again, and the engine no longer pauses the world behind it, so
   `game_over.mp3` plays exactly as it does in the original. Audibility is
   still a one-click manual test, because every automated run passes
   `+volume 0`.
4. **Coop.** The page is single-player only by construction (`cl.maxclients > 1`
   returns early). Coop still gets the client's own panel, including its
   `RESTART` arm, which is the right behaviour until the coop bridge exists.

---

## 6. Applying

```powershell
pwsh -File .\scripts\apply-cof-ui-death-flow.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

after `apply-cof-ui-menu-map-redirect.ps1` (the death page's Exit reuses its
return sequence, and every `cl_main.c` hunk sits on the redirect's own lines),
after `apply-cof-ui-input-gate.ps1` (what keeps the client's panel off the
screen), and after `apply-cof-console-style.ps1` (the `con_enable` registration
uses the `cof_console_*` lines as hunk context). The script refuses a tree that
already carries the change, checks all three prerequisites by marker, verifies
sixteen concrete markers afterwards, reverse-checks the patch, and has a
`-Reverse` mode with its own checks.

**Verified** on `cof-fix/pristine-ui-m1-scratch` after the whole engine stack:
forward apply, duplicate-apply refusal, reverse, and forward again, with all
four touched files byte-identical to the working tree after every forward.

The menu side is part of `patches/cof-mainui-source-theme.patch`, regenerated in
place (41 files now; `controls/BackgroundBitmap.cpp` joins the list for the
scrim suppression). Its apply script gained markers for the death page and the
checkbox. **Verified** on the same scratch tree over the pinned MainUI baseline
plus the three earlier MainUI patches: forward, duplicate refusal, reverse,
forward again, with all 187 mainui files matching the working tree.

## 6a. Artefacts

| Artefact | Bytes | SHA-256 |
| --- | ---: | --- |
| `patches/cof-ui-death-flow.patch` | 15 383 | `FBF7BF107B2B920F104ED9DDDE9A5A92D0A337FE7DC8633954828BB025885244` |
| `patches/cof-mainui-source-theme.patch` | 170 228 | `AD1A3BC1D8CFBC3A8BBE732147668AB4A3F97AD37D44E517D8B0855750277BF2` |
| `xash.dll` (`build-cof-ui-m1-engine-20260921`) | 3 511 296 | `BD90FDB994053BD6AE42E5E5C15B7A8DCAB5934389E657D5D0D3813A5C3328DE` |
| `xash.pdb` | 36 417 536 | see the build directory |
| `menu.dll` (`build-cof-ui-m3-20260921`) | 1 470 976 | `1704D258E8125C89CA8514F48D5A5363C244ABDB15BBC22F1BC2E5831F58E627` |
| `menu.pdb` | 21 458 944 | see the build directory |

Build lines unchanged from the milestones they belong to; the engine used
`WAFLOCK=.lock-waf-cof-ui-m1-engine` and the menu
`WAFLOCK=.lock-waf-cof-ui-m3`, so neither disturbs the other build in the same
tree. `stage1/deploy-ui-m3-20260921.ps1` carries both hashes.

One other engine change rides along, on the coordinator's instruction: the blur
worker's inert `cof_ui_overlay_active` cvar mirror and its `V_PostRender` call
were removed from `engine/client/{cl_main.c,client.h,cl_view.c}`. Nothing else
referenced them, no tracked patch carried them, and `engine/client/cl_view.c` is
byte-identical to the pre-blur stack again.

## 7. Cvars and commands added

| Name | Kind | Default | Notes |
| --- | --- | --- | --- |
| `cof_ui_death_menu` | engine cvar, not archived | `1` | `0` = the client's own GAME OVER panel |
| `con_enable` | engine cvar, **archived** | `0` | unlocks the developer console; never locks one the command line unlocked |
| `cof_ui_menu_return` | engine command | - | the redirect's disconnect + background-map sequence |
| `menu_cofdeath` | menu command | - | opens `CMenuCoFDeath`; the engine runs it |

---

## 8. The world keeps running behind GAME OVER (`cof_ui_death_keep_running`)

Milestone 4b, 2026-09-22, from the user's play feedback on the deployed build:

> the world must keep sounding after death — the original keeps ambient sound
> and e.g. a chainsaw running; now everything goes silent, which looks wrong.

Two separate causes, both removed.

### 8.1 The menu-side `stopmp3` is gone (decision reversed)

`CMenuCoFDeath::Show()` used to issue the client's `stopmp3`, and `Think()`
repeated it once on the first frame. The measured ordering argument that
justified it still stands (§1.1: the client starts `game_over.mp3` while it
handles the very `VGUIMenu` message the engine latched, so a stop issued from
`Show()` always lands after it) — **the argument was right and the decision was
wrong.** The original death screen is a panel over a still-running game, and
its music is part of that. Both calls, the `m_bStopMusicAgain` latch and the
`StopDeathMusic()` helper are removed from `menus/CryOfFear.cpp`; nothing
replaces them. The Load Game and New Game pages keep their own `stopmp3`, which
is the unrelated question of music bleeding across a transition
(`cof_mp3_stop_on_map`).

### 8.2 The engine was pausing the game, and that is the bigger half

There is **no pause flag** involved, which is why this was not obvious:

| gate | file | what it does when a menu owns input |
| --- | --- | --- |
| `CL_IsInGame()` | `engine/client/cl_main.c` | returns `cls.key_dest == key_game`, i.e. **false** |
| `SV_IsSimulating()` | `engine/server/sv_main.c:582` | `!sv.paused && CL_IsInGame()` — so the world frame is not run and `sv.time` stops |
| `S_MixNormalChannelsToRoombuffer` | `engine/client/sound/s_mix.c:342` | skips every non-`FL_CHAN_LOCAL_SOUND` channel in single player — ambience, the chainsaw, everything |
| `S_StreamBackgroundTrack` | `engine/client/sound/s_stream.c:239` | pauses a track whose `source` is `key_game`, which is where the client's own `playmp3` ends up (`pfnMP3_InitStream` → `S_StartBackgroundTrack`) |

That is correct for the pause menu and wrong for GAME OVER. `cof_ui_death_keep_running`
(default `1`) makes the death page the one exception: `CL_CoF_DeathWorldLive()`
is true between the `VGUIMenu` latch and the disconnect or save load that ends
the session, `CL_IsInGame()` returns true while it is, and the two sound gates
name it explicitly.

**Input stays gated exactly as before.** `key_dest` is still `key_menu`, so the
client DLL gets no keys (`cof_ui_input_gate`) and `IN_EngineAppendMove` returns
early; and because `CL_IsInGame()` is now deliberately true, the movement gate
in `SV_ExecuteClientMessage` (`engine/server/sv_client.c:3350`) had to name
`CL_CoF_DeathWorldLive()` itself, so the player's commands are still zeroed.
The world runs, the player does not. Every other menu keeps the stock pause.

### 8.3 Verification

`stage1/ui-m4b-fixture-20260922`, `run-m4b.ps1`, `+load cofsave1` then `kill`
from `maps/c_forest3_load.cfg`, with the new `cof_world_probe` command printing
`sv.time`, the physics frame counter (`sv.framecount`, which `SV_RunGameFrame`
only ever advances while `sv.simulating`), and the three gates.

| run | probe after the page opened |
| --- | --- |
| `d4-control.log`, **`cof_ui_death_keep_running 0`** | `sv.time 12.658 worldframes 546 simulating 0 ingame 0` — and **identical** 600 and 1200 frames later. The bug, reproduced. |
| `d3-live.log`, default `1` | `sv.time 13.147 / 15.694 / 18.197`, `worldframes 670 / 1270 / 1870`, `simulating 1 ingame 1 deathpage 1` |
| `f1-final.log`, the shipped binaries | `sv.time 13.821 → 15.904`, `worldframes 810 → 1310`, `deathpage 1` |

No `stopmp3` appears anywhere near the death in any of those logs — the only
two in the file are `cof_mp3_stop_on_map`'s own, before the save load and
before the final disconnect.

`d5-page-{a,b,c}.png` are the page itself at 1920x1080 over the live scene;
the three differ, because the scene is still moving.

### 8.4 Cvar and command

| Name | Kind | Default | Notes |
| --- | --- | --- | --- |
| `cof_ui_death_keep_running` | engine cvar, not archived | `1` | `0` = the death page pauses the game like every other menu |
| `cof_world_probe` | engine command | - | developer/cfg test hook: one line with `sv.time`, `sv.framecount` and the gates |

Applied by `scripts/apply-cof-ui-death-live.ps1`
(`patches/cof-ui-death-live.patch`), after the death flow itself and after
`cof-mp3-stop-on-map`; the menu half rides in the regenerated
`patches/cof-mainui-source-theme.patch`.
