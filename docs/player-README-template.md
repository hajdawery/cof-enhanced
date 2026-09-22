<!--
Template for the README.txt / README.md the patcher and every release
archive ship to players. The release tooling replaces the {{...}} fields.
Keep the disclaimer, attribution and source-offer sections intact: they
carry licence obligations (see LICENSING.md section 6).
-->

# Cry of Fear: Enhanced {{VERSION}}

Project site: <https://cofenhanced.haej.pl>

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

## What the patcher changes in your game folder

Added: `xash.dll`, `ref_gl.dll`, `SDL2.dll`,
`cryoffear/cl_dlls/menu.dll`, the fonts and configuration files under
`cryoffear/`, and the language packs under `cryoffear/languages/`.

Replaced (the originals are backed up to `{{BACKUP_FOLDER}}` and restored on
uninstall): `CoFLaunchApp.exe`, `vgui.dll`, `FileSystem_Stdio.dll` (the
engine's `filesystem_stdio.dll`; Windows treats the two names as one file).

Your saves and the game's own files are not modified.

## Credits and licences

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
- Cry of Fear by **Team Psykskallar**.

Our own changes are Copyright (c) 2026 haej (Cry of Fear: Enhanced
contributors), GNU GPL version 3 or later. Full licence texts and every
third-party copyright notice are in `LICENSE`, `LICENSING.md`,
`THIRD-PARTY-NOTICES.md` and the `licenses/` folder that come with this
release.

This software comes with ABSOLUTELY NO WARRANTY (GNU GPL sections 15-16).

## Source code

The complete source code for the binaries in this release is available at
no charge:

- Project repository: <https://github.com/hajdawery/cof-enhanced>, commit
  `{{COF_FIX_COMMIT}}`.
- Source archive attached to this release: `{{SOURCE_ARCHIVE_NAME}}`.
- Upstream: Xash3D FWGS commit `4857b389e6ba32ddaa68582aedcbc950c138f46a`;
  mainui_cpp `61263995592e93a278d764807243d043d3b97c54`; FreeVGUI
  `73bfb4659f3d9eb28b79e5b26baea8c6b888d5eb`; the other submodule commits
  and the exact build configuration are listed in `LICENSING.md`
  section 3. {{UPDATE_IF_PINS_CHANGE}}
