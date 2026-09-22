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

Status: written 2026-09-22, before any public release and before the patcher
exists. Items marked **decide** need a decision in the patcher round.

## 1. Binaries (from one clean end-to-end build of the [patch stack](../docs/dev/patch-stack.md))

| Game-folder path | Op | Source | Notes |
| --- | --- | --- | --- |
| `CoFLaunchApp.exe` | replace | `scripts\build-cof-launcher.ps1` output | our launcher; Steam starts it; loads `xash.dll` with `-game cryoffear -cof-pmove-legacy +set cof_save_root_compat 1` |
| `xash.dll` | add | `<out>\engine\xash.dll` | engine, all E patches |
| `ref_gl.dll` | add | `<out>\ref\gl\ref_gl.dll` | renderer, all R patches |
| `vgui.dll` | replace | `<out>\3rdparty\freevgui\vgui.dll` | FreeVGUI with our patches; must match `xash.dll` (same build) |
| `filesystem_stdio.dll` | replace | `<out>\filesystem\filesystem_stdio.dll` (**unverified path**; not rebuilt in the recent rounds, add its target to the release build) | unmodified FWGS filesystem; on Windows this **is** the game's `FileSystem_Stdio.dll` (one case-insensitive name), so it is a replace, not an add |
| `SDL2.dll` | add | `SDL2-devel-2.30.9-VC.zip`, `lib\x86\SDL2.dll` | unmodified |
| `cryoffear\cl_dlls\menu.dll` | add | `<out>\3rdparty\mainui\menu.dll` | the menu |

Debug symbols (`xash.pdb`, `ref_gl.pdb`, `vgui.pdb`, `menu.pdb`) are **not** in
the player archive. **Decide:** publish them as a separate
`cofenhanced-<version>-symbols.zip` release asset (useful for crash reports) or
not at all.

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

Generated on the player's machine by the patcher, **never shipped**:

| Game-folder path | How |
| --- | --- |
| `cryoffear\gameinfo.txt` | converted from the player's own `cryoffear\liblist.gam`, then the keys in `gamedata\cryoffear\gameinfo.keys` merged in (`startmap "c_intro"`, `render_picbutton_text 1`), timestamped newer than `liblist.gam` so the engine does not reconvert over it |
| `cryoffear\maps\c_game_menu1.ent` | `scripts\make-cof-ent-override.py` over the player's `c_game_menu1.bsp`, dropping `cof_gamemenu`; timestamped newer than the BSP |

**Decide:** the runtime icon (`assets\branding\runtime\cryoffear\cofmodern\branding\coffix.ico`
plus the `icon` line from `gameinfo-icon.fragment.txt`). The play runtime still
uses the game's own `coficon`; the launcher exe carries our icon either way.

## 3. Language packs (from `languages/`)

Each pack folder is copied as a whole to `cryoffear\languages\<code>\` and
verified against its `MANIFEST.tsv`:

| Pack | Contents |
| --- | --- |
| `polish` (Polski) | `README.md`, `LICENSE-NOTE.md`, `manifest.txt`, `MANIFEST.tsv`, `strings\`, `txt\`, `inventoryitems\`, `maps\`, `textures\`, `overlay\` |
| `dutch`, `french`, `german`, `norwegian`, `spanish`, `swedish` | `README.md`, `manifest.txt`, `MANIFEST.tsv`, `strings\menu-strings.tsv` |

Blocking for the first release: the Polish pack must first be **reduced to
translator-authored content** (user decision after the legal audit: `.ent`
files as key/value patches, only translated textures, no whole models, no files
identical to the game's). Ship the reduced pack, not today's. Open: the six
minimal packs have no `LICENSE-NOTE.md` although LICENSING.md section 6 asks
for one per pack (their only content is our machine-drafted menu strings; the
language worker should add one or LICENSING.md should say they need none).

## 4. Documents (installed to `cofenhanced\` in the game folder; **decide** the folder name)

| File | Source |
| --- | --- |
| `README.md` (or `.txt`) | [`docs/player-README-template.md`](../docs/player-README-template.md) with every `{{...}}` field filled |
| `CHEATS.md` | repository root |
| `DISCLAIMER.md` | repository root |
| `LICENSE` | repository root (GPL-3.0 text with our notice) |
| `LICENSING.md` | repository root |
| `THIRD-PARTY-NOTICES.md` | repository root |
| `licenses\` (all 23 files) | repository root |
| `SOURCE.txt` | new per release: this repository's URL and release commit, the upstream commits of LICENSING.md section 3, the build configuration, and the name of the attached source archive (may instead be the player README's "Source code" section) |
| `SHA256SUMS.txt` | new per release: every file above |

The patcher's backups (`CoFLaunchApp.exe`, `vgui.dll`, `FileSystem_Stdio.dll`)
go to the folder the player README calls `{{BACKUP_FOLDER}}`.

## 5. Separate release assets (same GitHub release, not inside the archive)

* `cofenhanced-<version>-source.zip`: the patched engine tree with its
  submodules at the "used" commits plus this repository at the release commit
  (LICENSING.md section 6, item 7). Required.
* The symbols archive, if decided (section 1).

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
