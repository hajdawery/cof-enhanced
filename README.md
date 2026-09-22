# Cry of Fear: Enhanced

<img src="assets/branding/coffix.png" alt="Cry of Fear: Enhanced emblem" width="160" align="right">

**Cry of Fear on a modern open-source engine: a clean new menu, a UI that
scales to 1440p and 4K, readable text, proper widescreen options and a pile of
fixes, applied on top of your own Steam copy of the game.**

[![License: GPL-3.0-or-later](https://img.shields.io/badge/license-GPL--3.0--or--later-blue.svg)](LICENSE)

Project site: <https://cofenhanced.haej.pl>

> **Cry of Fear: Enhanced is an unofficial community compatibility project.**
> It is not affiliated with, endorsed by, or supported by Team Psykskallar,
> the creators of Cry of Fear, nor by Valve Corporation. Cry of Fear and its
> assets remain the property of Team Psykskallar. Cry of Fear: Enhanced is a
> patcher applied on top of your own Steam installation: you need your own
> copy of Cry of Fear from Steam. It contains no game assets of any kind,
> with the single exception of the community translation packs (text,
> subtitles, translated signage and interface graphics); everything else it
> installs is the patched open-source engine, menu and UI libraries plus the
> project's own configuration and font files.
>
> Built on [Xash3D FWGS](https://github.com/FWGS/xash3d-fwgs) (GPL-3.0-or-later)
> with [mainui_cpp](https://github.com/FWGS/mainui_cpp) and
> [FreeVGUI](https://github.com/FWGS/freevgui) (BSD-3-Clause). Our patches are
> GPL-3.0-or-later; see [LICENSING.md](LICENSING.md),
> [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) and
> [DISCLAIMER.md](DISCLAIMER.md). Steam is a trademark of Valve Corporation.

**Status:** version 0.4, pre-release. The whole game is playable from a build
of this repository, and the first public release (with an installer) is being
prepared. There is no download yet.

> ⚠️ **There WILL be bugs.** The game has NOT been completed in its entirety
> on this engine. You may get stuck, cutscenes may not work, and the textures
> or fonts might bug out. That is totally expected: this is still an
> early-stage project.
>
> If you notice ANYTHING, please report it via the
> [issues](https://github.com/hajdawery/cof-enhanced/issues). Screenshots,
> videos, steps to reproduce. It will help us massively.

## What it is

Cry of Fear runs on Valve's old GoldSrc engine. Cry of Fear: Enhanced swaps
that engine for [Xash3D FWGS](https://github.com/FWGS/xash3d-fwgs), an
open-source GoldSrc-compatible engine, and teaches it everything this
particular game needs. **The game itself is untouched**: its own `client.dll`
and `hl.dll` from your Steam install run as they are; the work happens in the
engine, the menu and the UI library around them.

## What it fixes and adds

**Runs the Steam game on Xash3D FWGS**
- The Steam version's game code runs unmodified on a modern engine
  (engine-side compatibility layers bridge the differences).
- Your existing saves load; tape-recorder saves work as before, using the same
  five save slots.
- No more getting stuck in crouch and crawl sections.

**Rendering and sound fixes**
- The main-menu city skyline is back (and the texture flicker on the train is gone).
- One map with a broken sky no longer kills the sky for the rest of the session.
- Changing resolution or window mode no longer strips the menu's scene of its
  sky, fog and snow.
- Music no longer bleeds across loading a save, starting a new game or quitting
  to the menu, but still carries across in-game level transitions as intended.
- No console spam from the tape recorder's blinking light.

**One unified, Source-style interface**
- A minimalist menu drawn over the live, animated menu scene: New Game (with a
  difficulty page and a *Skip prologue* option), Load Game, Custom Campaign,
  Extras (co-op, Unlockables, Links, Credits), Options, Quit.
- The pause menu is a translucent list over the paused game, with separate
  Save Game and Load Game.
- Options: Game, Controls, Audio, Video. Only settings that actually do
  something in Cry of Fear; gamma, brightness and contrast drive the game's own
  renderer.
- The Unlockables page shows what you have really unlocked, and Nightmare mode
  is offered only once you have.
- Death brings up a clean GAME OVER page (Load Game, Exit) while the world
  keeps sounding behind it.
- Every "back to main menu" in the game lands on the new menu.
- Optional saving from the pause menu (off by default) into the same five
  slots, with overwrite confirmation.
- Extras links open in your web browser.

**Scaling and readable text**
- The whole in-game UI scales with your resolution: inventory, HUD, ammo,
  phone, notes, subtitles, pickup messages, boss bars. HUD scale option: Auto,
  100, 125, 150, 200 %.
- Fonts: the menu, notes, subtitles, chapter titles and credits use the
  [Inter](https://rsms.me/inter/) typeface, sized for your display.
- Hints, subtitles and pickup messages get a subtle backing strip and a fixed,
  comfortable height on screen.
- The console is a Source-style window that opens and closes instantly, scales
  with the display, and can be switched on from Options > Game (*Enable console*).

**Controls and view**
- Field of view slider (70-110) that leaves iron sights and cutscene zooms
  exactly as the game framed them, plus a separate viewmodel FOV (55-90 or
  "follow").
- Aim down sights: Hold or Toggle. (The game's own hold mode is broken; this
  one works.) Right mouse button aims by default.
- The stray line through the chapter title cards is gone.

**Languages** - one *Language* option in Options > Game:
- **Polski** - the full Polish fan translation *Cry of Fear: Spolszczenie*
  (text, subtitles, notes, signs), built into the game with its authors'
  permission.
- **Deutsch, Español, Français, Nederlands, Norsk, Svenska** - the game's own
  subtitles in those languages, plus a translated menu.
- The menu switches language instantly; signs change on the next map.
- A pack holds only what its translators authored: text, the entity values
  they changed (applied to the game's maps at load), and the textures and
  images they repainted; it never ships a map, an entity list, a model or any
  file identical to the game. Format:
  [docs/design/language-pack-format.md](docs/design/language-pack-format.md).

**Co-op**
- *Host co-op* and *Join co-op* pages (Story co-op, Manhunt, Survival 1-4) that
  replace the old buttons, which did nothing outside the original engine.
- Leaving or losing a co-op session puts you back on the main menu.

**Cheats are back**
- `noclip`, `fly`, `notarget`, `give`, infinite ammo and stamina, no damage,
  night vision, ending select and more, for the Steam version's game files. See
  **[CHEATS.md](CHEATS.md)**.

## Requirements

- **Cry of Fear from Steam**, installed (the current Steam version, 1.6).
- **Windows.** Developed and tested on Windows 11. Linux (Wine / Proton) and
  macOS are untested.
- A graphics card with working OpenGL drivers.

## Install and uninstall

> **Coming with the first public release.** The installer does not exist yet;
> this is how it is meant to work.

1. Download the release from the project site or the GitHub releases page.
2. Run the patcher. It finds your Steam copy of Cry of Fear and checks that it
   is the Steam version.
3. It backs up the three game files it replaces (`CoFLaunchApp.exe`,
   `vgui.dll`, `FileSystem_Stdio.dll`), copies in the new engine, menu, fonts
   and language packs, and creates two small files from your own install.
4. Start Cry of Fear from Steam as usual.

To uninstall, run the uninstaller the patcher leaves behind: it restores the
three backed-up files and removes everything it added. Your saves are never
touched either way (backing them up first is still a good idea).

Want it before then? You can [build it yourself](docs/dev/building.md).

## Known issues

- **Menu translations are machine-drafted.** The menus in all seven languages
  are waiting for review by native speakers (the Polish in-game text is the
  fan translation). Corrections are welcome.
- Polish: notes, phone messages and the credits have not been checked in game
  yet. After switching language in a running game, some of the game's own
  interface art stays in the old language until you restart.
- Co-op has only been tested with two copies on one PC. LAN discovery, a second
  machine and internet play are untested.
- Some water surfaces may look different from the original game.
- A viewmodel FOV different from the world FOV moves the iron sights off
  centre.
- The dynamic crosshair does not scale. Changing the aspect ratio in the middle
  of a game stretches the in-game UI.
- The inventory's headings (BAG, POCKETS, ...) are part of the game's artwork,
  so they keep the original font.
- `god` does nothing in Cry of Fear (the game never checks it); use
  `cof_nodamage 1`. See [CHEATS.md](CHEATS.md).
- Not available yet: chapter select, controller support.

## FAQ

**Is this a recompile or a decompile of Cry of Fear?**
No. The game's own code (`client.dll`, `hl.dll`) runs exactly as Steam installed
it. What is replaced is the engine underneath (with open-source Xash3D FWGS),
the menu and the UI library, all built from public source code plus this
project's patches.

**Does it change my game files?**
It adds files and replaces three: `CoFLaunchApp.exe` (so Steam's Play button
starts the new engine), `vgui.dll` and `FileSystem_Stdio.dll`. All three are
backed up first and restored when you uninstall. The game's DLLs, maps and
saves are never modified.

**Will my saves work?**
Yes: existing saves load, and tape-recorder saves still use the game's five
slots.

**Do Steam achievements and the Steam overlay work?**
The Steam overlay works. Cry of Fear has no Steam achievements, so there is
nothing to lose there. The engine itself does not load the Steam API, which is
why the original menu's Steam-overlay links now open in your browser instead.

**What if Steam verifies or updates the game?**
Steam will probably put its own versions of the three replaced files back; run
the patcher again. (Unverified, since there is no patcher yet.)

**Do I need the old "cheats restored" DLL pack?**
No, and please don't use it: the cheats are built into Cry of Fear: Enhanced
and work with the original game files. See [CHEATS.md](CHEATS.md).

**Can I play co-op with someone on the original game?**
Untested. Co-op has only been tried between two copies of Cry of Fear: Enhanced.

**Do custom campaigns work?**
Custom campaigns installed in the game's `maps` folder show up under Custom
Campaign. Playing through them has not been tested widely.

## Reporting bugs

Open an issue at <https://github.com/hajdawery/cof-enhanced/issues>. Please include
the version line from the bottom-right corner of the main menu
(`cofenhanced ...`), your resolution and HUD scale, what you did and what
happened, and a screenshot if it is visual. More in
[CONTRIBUTING.md](CONTRIBUTING.md).

## Building and contributing

This repository holds the patches, scripts and data, not the engine itself.
Start with the [documentation index](docs/README.md): building, the
[patch stack](docs/dev/patch-stack.md), testing rules and the design notes.
[CONTRIBUTING.md](CONTRIBUTING.md) explains how contributions are licensed.

## Credits

- **Cry of Fear** by **Team Psykskallar**. Cry of Fear: Enhanced is not
  affiliated with or endorsed by them; buy the game on Steam.
- **Cry of Fear: Enhanced** by **haej** (<https://cofenhanced.haej.pl>).
- **Polish translation** *Cry of Fear: Spolszczenie* by **Avioo**
  (translation, graphics, testing), **Mixdedemon** (translation), **hexag0n**
  (technical work, testing) and **Izonka** (testing), included with their
  permission ([Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3164091802)).
  The game's own Dutch, French, German, Norwegian, Spanish and Swedish text is
  Team Psykskallar's.
- **[Xash3D FWGS](https://github.com/FWGS/xash3d-fwgs)** by the Xash3D FWGS
  contributors: the engine, renderer and filesystem.
- **[mainui_cpp](https://github.com/FWGS/mainui_cpp)**: the menu library, with
  **[MiniUTL](https://github.com/FWGS/miniutl)**.
- **[FreeVGUI](https://github.com/FWGS/freevgui)** by Alibek Omarov: the
  in-game UI library.
- **[Inter](https://github.com/rsms/inter)** by The Inter Project Authors: the
  typeface.
- **[SDL 2](https://www.libsdl.org/)** by Sam Lantinga and contributors.
- **[stb_truetype](https://github.com/nothings/stb)** by Sean Barrett.
- Built into the engine as well: [Opus](https://github.com/xiph/opus),
  [opusfile](https://github.com/xiph/opusfile), [libogg](https://github.com/xiph/ogg)
  and [libvorbis](https://github.com/xiph/vorbis) (Xiph.Org Foundation),
  [bzip2](https://gitlab.com/bzip2/bzip2) (Julian Seward),
  [MultiEmulator](https://github.com/FWGS/MultiEmulator) (Alexander Belkin,
  with SHA code by George Anescu), [library-suffix](https://github.com/FWGS/library-suffix),
  miniz (Rich Geldreich, RAD Game Tools and Valve), the mpg123 decoder (the
  mpg123 project), [whereami](https://github.com/gpakosz/whereami) (Gregory
  Pakosz), getopt (University of California), `vgui_api.h` (Mittorn), and
  Valve's Half-Life SDK headers.

The full copyright notices for all of these are in
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

## Licences

- Our code (patches, scripts, launcher, tests, docs): **GPL-3.0-or-later**,
  see [LICENSE](LICENSE). Our changes to FreeVGUI stay **BSD-3-Clause**.
- Fonts (Inter and the atlases generated from it): **SIL Open Font License 1.1**.
- Language packs: not GPL; translation data shared with the translators'
  permission, for use with a legally owned copy of Cry of Fear (each pack's
  README and `LICENSE-NOTE.md`). The six menu-only packs (Deutsch, Español,
  Français, Nederlands, Norsk, Svenska) hold no game text and are
  GPL-3.0-or-later.
- The emblem: original artwork by haej, redistributable unmodified with the
  project.
- Cry of Fear itself belongs to Team Psykskallar and is not in this repository.

Details, the source-code offer and what every release must contain:
[LICENSING.md](LICENSING.md). Third-party notices:
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) and [licenses/](licenses/).
Disclaimer: [DISCLAIMER.md](DISCLAIMER.md).
