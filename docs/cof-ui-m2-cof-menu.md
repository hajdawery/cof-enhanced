# Unified UI, milestone 2: the Cry of Fear main menu

Scope: make the FWGS engine menu (`mainui`) *be* Cry of Fear's menu — the right
items, in the right order, every one of them working — with no styling work.
Milestone 1 (`docs/cof-ui-m1-plumbing.md`) put the engine menu on screen over
the live `c_game_menu1` scene; this milestone replaces the stock item set and
adds the Cry of Fear pages behind it.

Everything was verified in the disposable fixture
`stage1/ui-m1-menu-fixture-20260921` (README there for the recipe), always
windowed at 1920x1080 with `+volume 0`. The canonical game copy at
`K:\LLM\COF_Fix\Cry of Fear` was never written to: 6 197 files,
4 702 274 797 bytes, newest mtime `2026-09-18T20:33:58.9860178Z`, identical
before and after.

Labels as in milestone 1: **measured** = seen in a screenshot, a log line or a
shipped binary at the given address; **inferred** = a reading of measured facts.

## What changed

One MainUI patch, `patches/cof-mainui-cof-menu.patch`, applied with
`scripts/apply-cof-mainui-cof-menu.ps1` on top of the pinned MainUI revision
`61263995592e93a278d764807243d043d3b97c54` **and** the two earlier MainUI
patches (`cof-mainui-menu-save.patch`, `cof-mainui-background-scrim.patch`),
plus two `gameinfo.txt` keys.

| File | Change |
| --- | --- |
| `menus/CryOfFear.cpp` (new) | the difficulty, custom-campaign, language and extras pages, the unlockables route, and `UI_IsCryOfFear()` |
| `menus/CryOfFear.h` (new) | their declarations |
| `menus/Main.cpp` | a Cry of Fear item set for `CMenuMain`, and the background-map restart after Quit to menu |
| `BaseMenu.h` | export `UI_StartBackGroundMap()`, which was file-local |
| `menus/LoadGame.cpp` | CoF save previews are read from the root `SAVE/` folder |

### How it hooks in

The same way the save integration already did: a runtime check of the game
directory, not a build flag and not a separate library.

```cpp
bool UI_IsCryOfFear( void );   // game dir basename == "cryoffear"
```

`CMenuMain::_Init` calls it once, stores `bCoF`, and branches to `InitCoF()`;
`CMenuMain::VidInit` branches to `VidInitCoF()`. For every other game the code
path is byte-for-byte the stock one. The new pages are ordinary `ADD_MENU`
entries, so they are also reachable as the console commands
`menu_cofdifficulty`, `menu_cofcampaign`, `menu_coflanguage`,
`menu_cofextras` — which is how every capture below was taken.

## The main menu

**Not connected** (the normal case, over the background map):

| Item | What it does | Command emitted |
| --- | --- | --- |
| New Game | CoF difficulty page | — (see below) |
| Load Game | the integrated MainUI save page | `load cofsaveN` from the page |
| Custom Campaign | CoF campaign page | — |
| Join Server | MainUI's internet server browser (`UI_InternetGames_Menu`) | — |
| Host Server | MainUI's create-server page (`UI_CreateGame_Menu`) | — |
| Language | CoF language page | — |
| Unlockables | the gallery map | `unlockablescmd` |
| Extras | CoF extras page | — |
| Options | MainUI options (`UI_Options_Menu`) | — |
| Quit | the stock quit confirmation | `quit "menu dialog"` |

**In game** (pause): Resume game, Save\Load Game, Options, Quit to menu, Quit.
`Quit to menu` is the stock `disconnect` confirmation dialog, which was hidden
in single-player in the stock layout.

Gone for Cry of Fear: Console, Training Room (no `coft_*` map ships),
Multiplayer, Previews, Change Game.

### The two white squares in the top-right corner

**Measured.** They are `CMenuMain::minimizeBtn` and `CMenuMain::quitButton`,
two `CMenuBitmap`s drawn at `uiStatic.width - 72, 13` and
`uiStatic.width - 36, 13`, 32x32 each (`menus/Main.cpp:322-323` upstream),
using `gfx/shell/min_n` and `gfx/shell/cls_n`. Cry of Fear ships **no**
`gfx/shell` button artwork at all — the folder contains only `kb_act.lst`, and
`gfx.wad` has no `min_*`/`cls_*` lumps — so `UI_DrawPic` fell back to the
engine's default white texture. The log lines
`Warning: FS_LoadImage: couldn't load "gfx/shell/min_n"` (and `cls_n`, `_f`,
`_d`) are in every fixture log from milestone 1 onwards.

They are now simply not added to the window for Cry of Fear. No artwork is
shipped: the menu already has its own Quit item and the OS window frame has the
real minimize and close buttons.

## New Game and the difficulty page

**Measured**, from `gfx/vgui/640_difficulty.tga` and
`gfx/vgui/640_difficultylocked.tga` in the canonical copy: the original page is
titled `CHOOSE A DIFFICULTY` and has four rows plus `RETURN TO MENU`:

| Row | `skillset` | Note |
| --- | --- | --- |
| EASY | 1 | |
| MEDIUM | 2 | |
| DIFFICULT | 3 | |
| NIGHTMARE | 4 | replaced by `LOCKED` in the second TGA |

The engine page reproduces exactly that, plus the original page's
`Enable developer commentary` checkbox (`dev_commentary` cvar; the client's own
strings `dev_commentary 0` / `dev_commentary 1` sit next to the difficulty art
in `client.dll`'s `.rdata`).

### What a difficulty row emits

The original client panel does two `ServerCmd`s, in this order and only this
order (`client.dll` VA `100402AA`-`1004047C`, one block per difficulty):

```
if( a custom campaign is selected )  ServerCmd( "campaign <firstmap>" )
ServerCmd( "skillset N" )
```

`ServerCmd` is `cmd <text>` from a console point of view. The engine menu is
drawn over a live background map, which is a **real local server**, so the same
two commands can simply be forwarded and `cl_dlls/hl.dll` does the rest: it
sets the `difficulty` cvar, plays `inventory/game_start.wav`, runs a five second
white `UTIL_ScreenFade`, and only then changes level. That is the authentic
sequence, not an imitation of it.

**Measured, `evidence/m2-newgame2.log`:**

```
Spawn Server: c_game_menu1
"difficulty" is "1"
COFM2-press-medium
"difficulty" changed to "2"
Spawn Server: c_intro
"difficulty" is "2"
```

So a new game started from the engine menu reaches `c_intro` with `difficulty`
set correctly. The same run through the campaign page
(`evidence/m2-campaign-start.log`) gives `"difficulty" changed to "1"` and
`Spawn Server: c_rumpel1`.

**Fallback.** If no server is running at all (nothing to forward `cmd` to, for
example immediately after Quit to menu and before the background map is back)
the page sets the `difficulty` cvar itself and issues `map c_intro` or
`map <firstmap>`. This path exists for robustness; the measured runs all took
the forwarding path.

### Nightmare is locked, and the menu cannot see the real flag

**Measured.** `skillset 4` is gated in `client.dll` on a global byte at VA
`10542A68` (`cmp dword ptr ds:[10542A68h],0; je <skip>` at VA `10040425`),
which is set while parsing `cryoffear/scriptsettings.dat` — 101 fixed-width
20-byte lines compared against a table of 34 pairs of compiled-in tokens
(`stage1/ui-data-research-20260921/RESULTS.md` §1.2-1.3). The per-flag mapping
is undecoded, the file is deliberately obfuscated, and **nothing exposes the
flag as a cvar, a user message or a server command** — checked across
`client.dll`, `hl.dll`, `GameUI.dll` and `hw.dll` strings.

So the page greys Nightmare out and labels it `Locked` unless the archived cvar
`cof_nightmare_unlocked` is `1`, with the status line
`Nightmare mode has to be unlocked in game (cof_nightmare_unlocked)`. The
`StartGame` path refuses `skillset 4` while the cvar is `0`, the same way the
original panel refuses the click.

**Needs an engine change to do properly** (see *Open* below): a small client
hook that reads the flag the client already computed and mirrors it into a
cvar, so the menu greys out for the same reason the game does.

### `startmap` in `gameinfo.txt`

Milestone 1 set `startmap "c_difficulty_settings"` so that MainUI's New Game
would enter the client's own difficulty map, plus `noskills 1` so MainUI would
not show its own Easy/Medium/Hard page first. Neither is needed now:

```
startmap "c_intro"      (was "c_difficulty_settings")
noskills                removed
```

`startmap` still has to name a real map, because `CMenuMain` greys New Game out
when it is empty (`menus/Main.cpp:246-247`) and the restricted `newgame`
command loads it (`engine/server/sv_cmds.c:355-360` -> `COM_NewGame`).
Cry of Fear's New Game button no longer runs `newgame` at all.

## Custom Campaign

`cryoffear/maps/*.custom` are three-line files of quoted key/value pairs
(`firstmap`, `description`, `author`), not a KeyValues block. The page globs
them through `EngFuncs::GetFilesList( "maps/*.custom", …)`, parses them with
`EngFuncs::COM_ParseFile`, and lists description / author / first map in a
`CMenuTable`. Values are used verbatim, trailing spaces included, so the text
reads as it does in the original.

**Correction to the data research (measured).** There are **12** campaign
files, not 11: `her.CUSTOM` has an upper-case extension and was missed by a
case-sensitive `*.custom` glob. The engine's own file listing is
case-insensitive on Windows and finds it; the page shows
`HER / Lockdown / c_her1` (`evidence/m2-final-campaign.png`).

Selecting a row opens the difficulty page with that campaign pending, and the
difficulty row then emits `cmd campaign <firstmap>` followed by
`cmd skillset N`. This also **resolves the open question** in the data research
(§3.4): the argument to `campaign` is the **`firstmap` map name**, not the
`.custom` base name — `hl.dll`'s handler at VA `10019C91` stores `argv(1)` and
the think at VA `100DFC10` runs `map %s` with it, and
`cmd campaign c_rumpel1` + `cmd skillset 1` measurably spawns `c_rumpel1`.

Entries whose `firstmap` is missing, malformed, or names a map that is not
installed are skipped with a console line rather than listed; all 12 shipped
campaigns pass.

## Language

Seven rows — English, Dutch, French, German, Norwegian, Spanish, Swedish —
emitting `cmd subtitleset 1` … `cmd subtitleset 7`, and a label showing the
current choice.

**Where the choice persists (measured).** The client answers `subtitleset N` by
writing the archived cvar `cof_subtitlelanguage`, which the engine saves into
`cryoffear/config.cfg`. In `evidence/m2-probe-campaign.log`:

```
"cof_subtitlelanguage" is "1"
"cof_subtitlelanguage" changed to "4"
```

and a later, *separate* launch (`evidence/m2-language.png`) came up showing
`Subtitle language: German` — i.e. the choice survived a restart exactly as the
original does. English is `1` and has no folder; `2`..`7` are the six
`cryoffear/txtfiles/languages/<name>` folders in alphabetical order. This
confirms the data research's inferred ordering end to end for index 4.

## Unlockables

The gallery's state lives in the obfuscated `scriptsettings.dat`, so the menu
cannot draw it. The item runs the client's own entry command,
`unlockablescmd` (registered by `client.dll`, VA `1006E3B0`), which loads
`maps/c_unlockables.bsp` where the real gallery entity draws the real state.

**Measured.** `evidence/m2-unlockables-a.png` is the genuine `UNLOCKABLES`
board with its 21 `?` tiles and `MAIN MENU` button;
`evidence/m2-unlockables-b.png` is the frame after `escape`, showing the engine
pause menu (Resume game / Save\Load Game / Options / Quit to menu / Quit) over
it — so Escape gets out of the gallery and back to the engine menu.

## Extras

Six rows with the original targets (`client.dll` `.rdata`
`10143044`-`101430D4`):

| Row | URL |
| --- | --- |
| Donate | `http://www.cry-of-fear.com/donate.php` |
| Soundtrack 1 | `http://www.cdbaby.com/cd/andreasronnberg` |
| Soundtrack 2 | `http://www.cdbaby.com/cd/andreasronnberg2` |
| Clothes | `http://teampsykskallar.spreadshirt.se/` (merch store, *not* the in-game costume picker) |
| Afraid of Monsters DC | `http://www.moddb.com/mods/afraid-of-monsters-dc` |
| Facebook | `http://www.facebook.com/CryOfFearOfficial` |

The original opened these with
`SteamFriends()->ActivateGameOverlayToWebPage(url)` and had no fallback, so
under FWGS — where `steam_api.dll` is not loaded — every one of them was a
silent no-op. The page uses `EngFuncs::ShellExecute` instead, which reaches
`ShellExecuteA( NULL, "open", url, … )`
(`engine/client/dll_int/cl_gameui.c:1111` -> `Platform_ShellExecute`,
`engine/platform/win32/sys_win.c:112-114`).

**Measured, but not with a browser.** A throwaway diagnostic build wired an
extra console command to the same `EngFuncs::ShellExecute` call the Extras
buttons make, pointed at `cmd.exe /c echo … > <file>` instead of a URL; the
file was written, so the call reaches the OS from this page
(`evidence/m2-shellexec.log`, `evidence/m2-shellexec.png`). A browser was
already running on the test host with a session of the user's own, and a URL
test would have left a tab behind in it, so **the "a browser window actually
opens" step is left as a one-click manual test**.

## Load Game, and a preview fix

The save page is the one from `cof-mainui-menu-save.patch`; it still lists the
five Cry of Fear slots with their `SAVE/saveinfoN.cof` labels and timestamps
(`evidence/m2-loadgame.png`: `Slot 1 / Forest Field / Thu May 16 16:46:02 2024`
through `Slot 5 / c_trainride / Mon Sep 21 18:24:44 2026`).

**Previews never worked for these slots.** `CMenuSavePreview::SetSaveName`
looked the thumbnail up as `save/<name>.bmp` with `gamedironly = true`, but
`cof_save_root_compat` keeps Cry of Fear's `.sav` **and** `.bmp` files in the
*runtime root* `SAVE/` folder — which is exactly where the patched slot list
already reads them from, with `gamedironly = false`. Every slot therefore drew
`No preview`, thumbnail or not (`evidence/m2-loadgame2.png`, taken with a
thumbnail present for slot 1).

This milestone makes the preview use the same root lookup for Cry of Fear.
`evidence/m2-loadgame3.png` shows the thumbnail rendering.

## Quit to menu and the background map

`Quit to menu` runs the stock disconnect confirmation and `DisconnectCb`. One
extra step was needed: MainUI only ever starts a background map **once per
process** — `UI_UpdateMenu` has a `static bool first` latch around
`UI_StartBackGroundMap` (`BaseMenu.cpp:658-672`) — so after a disconnect the
Cry of Fear menu would have come back over MainUI's flat Steam-background
bitmap instead of its own scene.

`CMenuMain::Think` now re-arms it for Cry of Fear, but only after the engine
has looked completely idle (`!ClientInGame()`, `cl_background == 0`,
`host_serverstate == 0`) for 30 consecutive frames, so it can never race a
level change that is still sitting in the command buffer.

**Measured, `evidence/m2-final-quittomenu2.log`:**

```
COFM2-quit-to-menu
Host_EndGame: disconnected from server
Spawn Server: c_game_menu1
```

and the resulting frame is byte-identical to a cold-start main menu.

## Artefacts

| Artefact | Bytes | SHA-256 |
| --- | ---: | --- |
| `patches/cof-mainui-cof-menu.patch` | 35 478 | `B8D55B5BC12F9C572FB2F0D5B4DACB79F3386F7404EAFAE035DD6EF8B8A3E6C1` |
| `menu.dll` (`build-cof-ui-m2-20260921`) | 1 332 736 | `8BA2EDA2EFADCFF7CDCAABE922B4FEB202AF84878F7DB805402FDAA47EB6AEEC` |
| `menu.pdb` | 14 536 704 | `4499F7652424F285FDC6C89F9EF2B6185513DEFB5FD1BAF531FF24442F395947` |
| engine `xash.dll` used for every run (milestone 1) | | `B22D83CEBA5EDC9944FF8A07BA9485B22088F4B3E0C660006474F652FEE5220E` |

Build: `python waf configure -4 --out=build-cof-ui-m2-20260921
--sdl2=..\prereq\sdl2-2.30.9-vc\SDL2-2.30.9 -T release --notests
--disable-mbedtls --enable-cof-entvars-legacy`, then
`python waf build -j8 --targets=menu`, from the pinned FWGS checkout with the
x86 MSVC environment and `WAFLOCK=.lock-waf-cof-ui-m2` so a concurrent build in
the same tree is not disturbed.

New cvars, both archived: `cof_nightmare_unlocked` (default `0`) and
`dev_commentary` (default `0`, the name the client itself uses).

**Superseded 2026-09-22:** `cof_nightmare_unlocked` is removed. The gate now
reads the real flag out of `cryoffear/scriptsettings.dat` line 83; see the
*Unlockables round* section of [the milestone 3 theme](cof-ui-m3-theme.md).
Every mention of that cvar below is history.

## Open, and what needs an engine change

1. **The Nightmare unlock flag is not observable.** The menu needs a cvar
   mirror of the client-side flag at `client.dll` VA `10542A68`. Everything
   else about the difficulty page is faithful. Engine or client-hook work.
2. **`newgame` from the console crashes the engine while a background map is
   running.** Repro: start the fixture, let `map_background c_game_menu1` come
   up, run `newgame`. `COM_NewGame` calls `SV_ShutdownGame`, the queued
   `levelshot` command then runs with no world, and `CL_LevelShot_f` passes
   `cl.worldmodel->name` to `FS_FileTime` with `cl.worldmodel == NULL`
   (`engine/client/cl_cmds.c:322` -> `FS_FindFile` -> `FS_FixFileCase`,
   `filesystem/dir.c:294`). Log: `evidence/m2-startmap.log`. **No Cry of Fear
   menu item reaches this path** — New Game goes to the difficulty page — but
   it is a one-line engine fix (`if( !cl.worldmodel ) return;`) and it is the
   only crash seen in this milestone. The menu side now refuses to emit a level
   change with an empty or malformed map name regardless
   (`UI_CoFMapNameIsSane`).
3. **The Quit confirmation dialog was not captured.** `menu_quit` is the OS
   window-close handler, not the Quit button: with no live game it quits
   immediately (`menus/Main.cpp:420-433`), so it cannot stand in for the
   button. The button itself is stock, unchanged code
   (`quit.onReleased = QuitDialogCb`). Manual test.
4. **The browser step of Extras.** See above — manual, one click.
5. **Styling.** None of this is styled. Pic buttons render as blurred TTF text
   (`render_picbutton_text 1`), the difficulty checkbox has no `gfx/shell/cb_*`
   art so it carries a `[ON ]`/`[OFF]` text marker like the save toggle, and
   the CoF list is laid out top-down from the usual first-button line because
   ten items do not fit the stock bottom-anchored WON layout. Milestone 3.
6. **Co-op is only the generic pages.** Join Server and Host Server open
   MainUI's own server browser and create-server pages and were verified to
   open and to list Cry of Fear's co-op maps (`cof_campaign_01`,
   `cof_suicide1..4`, `cof_manhunt_campaign`). Nothing bridges to the Cry of
   Fear lobby flow (`buildcoopsettings`, `readylobby`, `c_server_settings`);
   that is its own piece of work.
7. **No native mouse interaction anywhere.** Every capture is a console command
   from a `maps/<map>_load.cfg`. The button callbacks that cannot be reached
   that way (difficulty rows, campaign rows, Quit to menu) were exercised with
   a throwaway diagnostic build that wired console commands directly to the
   same callbacks; those diagnostics are **not** in the shipped patch and the
   shipped binary was re-verified afterwards.
8. **One resolution only**, 1920x1080 windowed.

## Evidence index

All under `stage1/ui-m1-menu-fixture-20260921/evidence/`.

| File | Shows |
| --- | --- |
| `m2-ship2-main.png` | the shipped main menu, ten items, no white squares |
| `m2-ship-difficulty.png` | the difficulty page with Nightmare locked |
| `m2-nightmare.png` | the same page with `cof_nightmare_unlocked 1`, Nightmare selectable |
| `m2-final-campaign.png` | all 12 custom campaigns |
| `m2-language.png` | the language page, persisted German selection |
| `m2-extras.png` | the six Extras rows |
| `m2-join.png`, `m2-host.png` | the server browser and create-server pages |
| `m2-loadgame.png`, `m2-loadgame3.png` | the five CoF slots; a working preview |
| `m2-unlockables-a.png`, `-b.png` | the gallery map; Escape back to the engine menu |
| `m2-pause.png` | the in-game item set over the live scene |
| `m2-newgame2.log`, `m2-campaign-start.log` | the measured difficulty/campaign starts |
| `m2-final-quittomenu2.log` | Quit to menu and the background map coming back |
| `m2-startmap.log` | the `newgame` engine crash of *Open* item 2 |
| `canonical-manifest-m2-before.txt`, `-after.txt` | the canonical tree unchanged |
