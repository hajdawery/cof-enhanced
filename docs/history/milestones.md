# Milestones

How the project got from "the retail DLLs crash in `PM_Init`" to a playable
game with a new UI. Dates are 2026; commit hashes are this repository's.
Detailed state and decisions live in the per-patch pages
([index](../patches/README.md)); the reusable technical lessons are in
[engine and game facts](engine-and-game-facts.md).

## Stage 1: make the retail game run on Xash3D FWGS (19-21 September)

* **ABI adapters.** The retail `hl.dll` / `client.dll` expect `playermove_t`,
  `entvars_t` and `edict_t` laid out differently from FWGS 4857b38. Opt-in
  adapters (`cof-pmove-legacy`, `cof-client-pmove-legacy`, `cof-entvars-legacy`,
  `cof-edict-stride-legacy`) got the game past `PM_Init`, entity spawn and
  `ServerActivate`, then to the menu and `c_intro`
  ([ABI findings](abi-findings.md), [client checkpoint](client-pmove-adapter-test.md),
  [dedicated profile test](dedicated-profile-test.md)).
* **Launcher.** `CoFLaunchApp.exe` replaces the game's launcher, loads the
  colocated `xash.dll` and passes the Cry of Fear switches
  ([launcher](../dev/steam-launch-prototype.md)). A Steam-parented launch to the
  main menu was tested once, with the Steam install restored afterwards
  ([Steam test](steam-play-test.md)).
* **Saves.** Existing Steam saves in the root `SAVE\` folder load
  (`cof-save-root-compat`); optional pause-menu saving shares the game's five
  slots; tape-recorder saves keep their own path. Commits `6cc5cf5`, `ae90541`.
* **Console font.** The game's variable-width `CONCHARS` rendered as garbage
  (`cof-console-variable-font-fallback`), commit `1cecb5c`.
* **Menu transitions** from the original menu into a save were traced and the
  main-menu -> Load Game -> stock save route was user-confirmed
  ([menu transition investigation](menu-transition-investigation.md)).
* **Main-menu skyline.** Traced over several days to the draw order of one
  sky sphere and fixed in the renderer (`cof-custom-renderfx-opaque`), commit
  `becd68c`. The same fix removed texture flicker on the train.

## Unified UI (21-22 September)

The user's decision: one Source-style UI stack for the main menu, pause menu,
options, dialogs and console, drawn over the live scene; in-game HUD,
inventory and phone stay the game's own.

* **Milestone 1** (`a8d4bb4`): the engine menu over the live `c_game_menu1`
  scene, the client's own menu removed by an entity override, a translucent
  pause scrim, the input gate and the deferred-command guard.
* **Milestone 2** (`fd2ee83`): Cry of Fear's own menu set in the engine menu
  (difficulty, custom campaigns, unlockables, extras), the menu scene surviving
  video mode changes, the `newgame` levelshot crash guard.
* **Milestone 3** (`f105554`, feedback round `aeab639`): the Source-era theme
  with Inter, the styled console, the menu-map redirect (every "back to main
  menu" in the game lands on the new menu), the GAME OVER page, "Enable
  console", real Unlockables status, console text sized from the display,
  music stopping on load/new game/quit, the sky fix, the build stamp, menu
  sound volume, the Options restructure (Game, Controls, Audio, Video), Skip
  prologue and the Credits page. Blur behind the menus was tried and
  **cancelled** by the user; it is not to be revisited.
* **Milestone 4** (`7efc978`): the whole in-game UI scaled from the display
  (`cof_ui_scale`, HUD scale option), the client's VGUI text drawn from Inter,
  and the Polish pack data. **4b/4c**: the world keeps running behind GAME
  OVER; readable HUD text and pickup/dialogue lines on a backing strip at a
  fixed height.
* **Milestone 5** (`22677fe`, the latest commit): field of view and viewmodel
  field of view, the crouch/crawl stuck fix, death audio, HUD text legibility.
  **5a**: text clipped above 1440p fixed, the Load page layout fixed, instant
  console. **5b**: Aim down sights Hold/Toggle, MOUSE2 aims by default, the
  chapter-card rule removed, the `glow01.spr` warning flood silenced, the sky
  fix extended to every level start, separate pause Save Game / Load Game.

## After milestone 5 (22 September, not committed yet)

* **Milestone 6**: native language packs (`cof_language`, the Polish pack, the
  Language option) and the restored cheats.
* **Co-op bridge**: Host co-op / Join co-op pages and the engine shims.
* **lang2**: one Language option driving both our packs and the game's own
  subtitle slot, the menu translated per pack, six minimal packs for the
  game's built-in languages.
* **fix-ads-tape**: the Hold mode reworked (the game's own Hold is broken), the
  SAVED GAMES page kept together at HUD scale above 100 %.
* **Legal audit**: `LICENSE`, `LICENSING.md`, `THIRD-PARTY-NOTICES.md`,
  `DISCLAIMER.md`, `licenses/`; decisions recorded in LICENSING.md.
* **Repository clean-up**: this documentation structure, the player README,
  `CONTRIBUTING.md` and the release manifest.

Staged binaries for these rounds are in `stage1\releases\` (see
[releases](../dev/releases-and-deploy.md)); the next step is one combined m7
build of the whole stack.

## Road to the first public release

In the user's order (22 September): version bump (done, `0.4` / `m6`), the
Language option (done), the co-op bridge (done), the weapon-action crash look
(closed: not a crash, see [engine and game facts](engine-and-game-facts.md)), then the Polish pack
reduced to translator-authored diffs (legal decision), one clean end-to-end
build, the patcher, and the player README. Parked: an inventory background
asset for scaled labels, chapter select (needs community-recorded saves),
controller support, a Ukrainian pack.
