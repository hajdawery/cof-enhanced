# Release manifest

What a public Cry of Fear: Enhanced release archive contains, where each file
goes in the player's game folder, where it comes from in this repository or the
build, and what must never be in it. The patcher round builds the archive and
the installer from this list; the licence reasons behind it are in
[LICENSING.md sections 6 and 7](../LICENSING.md#6-what-every-release-and-the-patcher-must-contain).

Paths on the left are relative to the Cry of Fear game folder
(`...\steamapps\common\Cry of Fear\`). "Add" means the file does not exist in a
Steam install; "replace" means the patcher backs the original up first and
restores it on uninstall.

Status: written 2026-09-22; implemented 2026-09-23 for the first public test
build, 0.4.0-test1, by [`scripts/build-release.ps1`](../scripts/build-release.ps1)
(builds the archives) and [`release/installer/`](installer/) (`Install.cmd`,
`Uninstall.cmd` and the PowerShell scripts they run). The items that said
**decide** are settled as noted in each section.

## 0. The archive (since 0.4.0-test1)

The player extracts `cof-enhanced-<version>.zip` straight into the Cry of Fear
folder and double-clicks `Install.cmd`:

| Archive path | What it is |
| --- | --- |
| `Install.cmd`, `Uninstall.cmd` | one-click wrappers; run `cof-enhanced\install.ps1` / `uninstall.ps1` with `-ExecutionPolicy Bypass`, then pause |
| `README.txt` | the [player README template](../docs/player-README-template.md), filled in and turned into plain text |
| `cof-enhanced\files\...` | the payload, laid out exactly like the game folder (sections 1-3) |
| `cof-enhanced\MANIFEST.sha256` | SHA-256 of every payload file; checked before and after copying |
| `cof-enhanced\install.ps1`, `uninstall.ps1`, `installer-common.ps1`, `release.txt` | the installer |
| `cof-enhanced\SOURCE.txt`, `CHEATS.md`, `LICENSE`, `LICENSING.md`, `THIRD-PARTY-NOTICES.md`, `DISCLAIMER.md`, `licenses\` | section 4 |

What the installer leaves in the game folder besides the payload:
`cof-enhanced-backup\` (the replaced game files, taken once and never
overwritten; `installed-files.tsv`, `backed-up-files.tsv`,
`created-folders.txt`; a copy of the uninstaller),
`cof-enhanced-install.log` and `cof-enhanced-version.txt`. It refuses to run
unless `CoFLaunchApp.exe` and the Steam `hl.dll` (SHA-256 `0036B91C...`) are
present, while the game runs from that folder, or when the folder is not
writable (it never asks for administrator rights). Running it again upgrades
in place. `Uninstall.cmd` removes only files whose hash is still the
installed one, restores the backups and removes the folders it created when
empty; saves and settings stay.

## 1. Binaries (from one clean end-to-end build of the [patch stack](../docs/dev/patch-stack.md))

| Game-folder path | Op | Source | Notes |
| --- | --- | --- | --- |
| `CoFLaunchApp.exe` | replace | `scripts\build-cof-launcher.ps1` output | our launcher; Steam starts it; loads `xash.dll` with `-game cryoffear -cof-pmove-legacy +set cof_save_root_compat 1` |
| `xash.dll` | add | `<out>\engine\xash.dll` | engine, all E patches |
| `ref_gl.dll` | add | `<out>\ref\gl\ref_gl.dll` | renderer, all R patches |
| `vgui.dll` | replace | `<out>\3rdparty\freevgui\vgui.dll` | FreeVGUI with our patches; must match `xash.dll` (same build) |
| `FileSystem_Stdio.dll` | replace | `<out>\filesystem\filesystem_stdio.dll` (target `filesystem_stdio`, built with the rest since 0.4.0-test1) | unmodified FWGS filesystem; on Windows this **is** the game's `FileSystem_Stdio.dll` (one case-insensitive name), so it is a replace, not an add; shipped under the game's spelling |
| `SDL2.dll` | add | `SDL2-devel-2.30.9-VC.zip`, `lib\x86\SDL2.dll` | unmodified |
| `cryoffear\cl_dlls\menu.dll` | add | `<out>\3rdparty\mainui\menu.dll` | the menu |

Debug symbols (`xash.pdb`, `ref_gl.pdb`, `vgui.pdb`, `menu.pdb`) are **not** in
the player archive. Settled for 0.4.0-test1: not published; they stay with the
staged build (`stage1\releases\v<version>\pdb\`) for reading crash reports.

## 2. Game-directory data (from `gamedata/cryoffear/`)

| Game-folder path | Op | Source |
| --- | --- | --- |
| `cryoffear\gfx\fonts\Inter-Regular.ttf` | add | `gamedata\cryoffear\gfx\fonts\` |
| `cryoffear\gfx\fonts\Inter-Medium.ttf` | add | same |
| `cryoffear\gfx\fonts\Inter-SemiBold.ttf` | add | same |
| `cryoffear\gfx\fonts\OFL.txt` | add | same (**required** beside the TTFs) |
| `cryoffear\fonts\cof_console0.fnt`, `cof_console1.fnt`, `cof_console2.fnt` | add | `gamedata\cryoffear\fonts\` |
| `cryoffear\fonts\cof_hudtext0.fnt`, `cof_hudtext1.fnt` | add | same |
| `cryoffear\fonts\OFL.txt` | add | same (**required** beside the atlases; the current deploy script forgets it) |
| `cryoffear\resource\cryoffear_english.txt` | add | `gamedata\cryoffear\resource\` (our own four menu strings) |
| `cryoffear\gfx\shell\kb_def.lst` | add | `gamedata\cryoffear\gfx\shell\` (the game ships none) |
| `cryoffear\scripts\chapterbackgrounds.txt` | add | `gamedata\cryoffear\scripts\` |

Generated on the player's machine by `install.ps1`, **never shipped**:

| Game-folder path | How |
| --- | --- |
| `cryoffear\gameinfo.txt` | converted from the player's own `cryoffear\liblist.gam`, then the keys in `gamedata\cryoffear\gameinfo.keys` merged in (`startmap "c_intro"`, `render_picbutton_text 1`), timestamped newer than `liblist.gam` so the engine does not reconvert over it |
| `cryoffear\maps\c_game_menu1.ent` | the logic of `scripts\make-cof-ent-override.py`, reimplemented in `install.ps1`, over the player's `c_game_menu1.bsp`, dropping `cof_gamemenu`; timestamped newer than the BSP (byte-identical to the script's output) |

The runtime icon (`assets\branding\runtime\cryoffear\cofmodern\branding\coffix.ico`)
is not shipped (settled for 0.4.0-test1): `gameinfo.txt` keeps the game's own
`coficon`; the launcher exe carries our icon either way.

## 3. Language packs (from `languages/`)

Each pack folder is copied as a whole to `cryoffear\languages\<code>\` and
verified against its `MANIFEST.tsv`:

| Pack | Contents |
| --- | --- |
| `polish` (Polski) | `README.md`, `LICENSE-NOTE.md`, `manifest.txt`, `MANIFEST.tsv`, `strings\`, `txt\`, `inventoryitems\`, `maps\`, `textures\`, `overlay\` |
| `dutch`, `french`, `german`, `norwegian`, `spanish`, `swedish` | `README.md`, `manifest.txt`, `MANIFEST.tsv`, `strings\menu-strings.tsv` |

Done before the first release: the Polish pack is reduced to
translator-authored content (1.2.0: entity patches, texture overrides, no
whole models or entity lists, nothing identical to the game), and every pack
has its `LICENSE-NOTE.md`. `build-release.ps1` checks each pack file against
its `MANIFEST.tsv` (`README.md` is the only unlisted file besides the manifest).

## 4. Documents (in the archive's `cof-enhanced\` folder, so they end up in the game folder's `cof-enhanced\`)

| File | Source |
| --- | --- |
| `README.txt` (archive root) | [`docs/player-README-template.md`](../docs/player-README-template.md) with every `{{...}}` field filled |
| `CHEATS.md` | repository root |
| `DISCLAIMER.md` | repository root |
| `LICENSE` | repository root (GPL-3.0 text with our notice) |
| `LICENSING.md` | repository root |
| `THIRD-PARTY-NOTICES.md` | repository root |
| `licenses\` (all 23 files) | repository root |
| `SOURCE.txt` | new per release: this repository's URL and release commit, the upstream commits of LICENSING.md section 3, the build configuration, and the name of the attached source archive (may instead be the player README's "Source code" section) |
| `MANIFEST.sha256` | new per release: every payload file (the release's `SHA256SUMS.txt` asset lists the archives themselves) |

The installer's backups (`CoFLaunchApp.exe`, `vgui.dll`, `FileSystem_Stdio.dll`)
go to `cof-enhanced-backup\` (the player README's `{{BACKUP_FOLDER}}`).

## 5. Separate release assets (same GitHub release, not inside the archive)

* `cof-enhanced-<version>-source.zip`: this repository at the release commit
  (`git archive`), `SOURCE.txt`, and under `engine-source/` the patched engine
  tree the binaries were built from, with the submodules the Windows build
  links (LICENSING.md section 6, item 7). Required.
* `SHA256SUMS.txt`: SHA-256 of the two archives.

## 6. Never in a release

* **Anything from Cry of Fear or Team Psykskallar**: `client.dll`, `hl.dll`,
  the original `CoFLaunchApp.exe`, maps (`.bsp`), full entity lumps (including
  `c_game_menu1.ent`), `liblist.gam`, models, sounds, music, videos, textures,
  fonts, text files, `scriptsettings.dat`, saves, configs. The only game-derived
  content allowed is the reduced translation packs in section 3.
* **Valve or Steam files**: `hw.dll`, the original `vgui.dll` and
  `FileSystem_Stdio.dll`, `steam_api.dll`, `steamclient.dll`, anything from the
  Steam runtime.
* **Patched game DLLs** of any kind, and nothing from
  `cof-cheats-kinda-restored` or from the Spolszczenie mod's binaries, fonts or
  startup video.
* **Development material**: `docs/` (except the rendered player README),
  `scripts/`, `patches/`, `tests/`, `launcher/` sources, `assets/` source art,
  `gamedata/README.md`, `gamedata/cryoffear/maps/README.md`,
  `gamedata/cryoffear/gameinfo.keys` (used by the patcher, not installed as a
  file), `languages/README.md`.
* **Workspace material**: `stage1/`, `pristine*/`, `build-*/`, the engine
  checkout, `artifacts/`, `prereq/`, the FWGS and SDL2 zips, `__pycache__/`,
  dumps, logs, screenshots, fixture manifests.
* PDBs inside the player archive (see section 1).

## 7. Checks before publishing

1. The binaries come from one build of the complete stack, stack-verified end
   to end ([patch stack](../docs/dev/patch-stack.md)), with `VERSION` bumped and
   `engine/cof_version.h` generated from the release commit (the corner stamp
   must not end in `+`).
2. LICENSING.md section 3 still matches the submodule commits built.
3. Every file in the archive is listed in `SHA256SUMS.txt`; no file in the
   archive is byte-identical to a file of the canonical game (rerun the legal
   audit's hash match, `stage1/legal-audit-20260922/hashmatch.py`).
4. The download is free of charge and not gated (Valve SDK header notice).
