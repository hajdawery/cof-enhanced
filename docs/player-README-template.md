<!--
Template for the README.txt that every release archive ships to players.
scripts/build-release.ps1 fills the {{...}} fields and turns the Markdown
into plain text (headings, **bold**, `code` and <links> are simplified).
Keep the disclaimer, credits and source-code sections intact: they carry
licence obligations (see LICENSING.md section 6).
-->

# Cry of Fear: Enhanced {{VERSION}}

Cry of Fear on a modern open-source engine (Xash3D FWGS): a clean new menu,
a UI that scales to 1440p and 4K, readable text, proper widescreen options and
a pile of fixes, applied on top of your own Steam copy of the game.

Project site: <https://cofenhanced.haej.pl>
Source code and bug reports: <https://github.com/hajdawery/cof-enhanced>

## THIS IS AN EARLY TEST BUILD

There WILL be bugs. The game has NOT been completed in its entirety on this
engine. You may get stuck, cutscenes may not work, and the textures or fonts
might bug out. That is totally expected: this is still an early-stage project.

If you notice ANYTHING, please report it (see "Reporting bugs" below).
Screenshots, videos, steps to reproduce: it will help us massively.

Back up your saves before playing (the `SAVE` and `cryoffear\SAVE` folders in
your Cry of Fear folder). Existing saves should load, but this is a test build.

## Install

1. Find your Cry of Fear folder: in Steam, right-click Cry of Fear >
   Manage > Browse local files (usually `...\steamapps\common\Cry of Fear`).
2. Extract the WHOLE zip into that folder, so that `Install.cmd` sits next to
   `CoFLaunchApp.exe`.
3. Double-click `Install.cmd`. (If Windows asks whether to run it, choose
   Run.) It checks that this is the Steam version of Cry of Fear, backs up the
   game files it replaces into `{{BACKUP_FOLDER}}`, installs the new files and
   checks every one of them. No administrator rights are needed.
4. Start Cry of Fear from Steam as usual. The version is shown in the
   top-right corner of the main menu: `cofenhanced {{VERSION}} (...)`.

Running `Install.cmd` again (for example after Steam verified or updated the
game, or to install a newer test build over this one) upgrades in place; the
backup of your original files is kept as it is. What each run did is written to
`cof-enhanced-install.log`.

## Uninstall

Double-click `Uninstall.cmd` in the Cry of Fear folder. It removes every file
the installer added (a file you changed afterwards is left in place and
reported), puts the original game files back from `{{BACKUP_FOLDER}}` and
removes the folders it created. Your saves and settings are not touched.
Afterwards you can delete `Install.cmd`, `Uninstall.cmd`, `README.txt` and the
`cof-enhanced` folder.

Settings and caches the new engine wrote while you played (`opengl.cfg`,
`video.cfg`, `cryoffear\.fontcache` and similar) are left behind; they are
harmless and you may delete them.

## What the installer changes in your game folder

Added: `xash.dll`, `ref_gl.dll`, `SDL2.dll`, `cryoffear\cl_dlls\menu.dll`, the
fonts and configuration files under `cryoffear\`, and the language packs under
`cryoffear\languages\`. Written from your own game files during the install:
`cryoffear\gameinfo.txt` (from `liblist.gam`) and
`cryoffear\maps\c_game_menu1.ent` (the menu map's entity list without the old
menu's entity).

Replaced (the originals are backed up to `{{BACKUP_FOLDER}}` and restored on
uninstall): `CoFLaunchApp.exe`, `vgui.dll`, `FileSystem_Stdio.dll`.

The game's own code (`client.dll`, `hl.dll`), maps, models, sounds and your
saves are not modified.

## Reporting bugs

Open an issue at <https://github.com/hajdawery/cof-enhanced/issues>. Please
include the version line from the top-right corner of the main menu
(`cofenhanced {{VERSION}} ...`), your resolution and HUD scale, what you did and
what happened, and a screenshot or video if it is visual. If the installer
failed, attach `cof-enhanced-install.log`.

## Cheats

The cheats of the original game are back, behind `sv_cheats 1`. See
`cof-enhanced\CHEATS.md`.

## Disclaimer

Cry of Fear: Enhanced is an unofficial community compatibility project. It
is not affiliated with, endorsed by, or supported by Team Psykskallar, the
creators of Cry of Fear, nor by Valve Corporation. Cry of Fear and its
assets remain the property of Team Psykskallar.

Cry of Fear: Enhanced is a patcher applied on top of your own Steam
installation of Cry of Fear. You need your own copy of Cry of Fear from
Steam.

It contains no game assets of any kind, with the single exception of the
community translation packs (text, subtitles, translated signage and
interface graphics), included with their translators' permission and usable
only with a legally owned copy of the game. Everything else it installs is
the patched open-source engine, menu and UI libraries plus the project's own
configuration and font files.

Steam and Half-Life are trademarks or registered trademarks of Valve
Corporation. The Cry of Fear name belongs to Team Psykskallar.

## Credits and licences

- Cry of Fear by **Team Psykskallar**.
- Cry of Fear: Enhanced by **haej** (<https://cofenhanced.haej.pl>).
- Built on **Xash3D FWGS** by the Xash3D FWGS contributors
  (<https://github.com/FWGS/xash3d-fwgs>), GNU GPL version 3 or later.
- Menu: **mainui_cpp** (<https://github.com/FWGS/mainui_cpp>), GNU GPL.
- In-game UI library: **FreeVGUI** by Alibek Omarov
  (<https://github.com/FWGS/freevgui>), BSD-3-Clause.
- **SDL2** by Sam Lantinga and contributors, zlib licence.
- Typeface: **Inter** by The Inter Project Authors, SIL Open Font License
  1.1 (`OFL.txt` next to the fonts).
- Polish translation: **Cry of Fear: Spolszczenie** by Avioo, Mixdedemon,
  hexag0n and Izonka, included with their permission.

Our own changes are Copyright (c) 2026 haej (Cry of Fear: Enhanced
contributors), GNU GPL version 3 or later. Full licence texts and every
third-party copyright notice are in `LICENSE`, `LICENSING.md`,
`THIRD-PARTY-NOTICES.md`, `DISCLAIMER.md` and the `licenses` folder, all
inside the `cof-enhanced` folder of this release.

This software comes with ABSOLUTELY NO WARRANTY (GNU GPL sections 15-16).
It is free of charge; nobody may sell it to you.

## Source code

The complete source code for the binaries in this release is available at
no charge (details in `cof-enhanced\SOURCE.txt`):

- Project repository: <https://github.com/hajdawery/cof-enhanced>, tag
  `v{{VERSION}}`, commit `{{COF_FIX_COMMIT}}`.
- Source archive attached to the same GitHub release: `{{SOURCE_ARCHIVE_NAME}}`.
- Upstream: Xash3D FWGS commit `4857b389e6ba32ddaa68582aedcbc950c138f46a`;
  mainui_cpp `61263995592e93a278d764807243d043d3b97c54`; FreeVGUI
  `73bfb4659f3d9eb28b79e5b26baea8c6b888d5eb`; the other submodule commits
  and the exact build configuration are listed in `LICENSING.md`
  section 3 and in `SOURCE.txt`.
