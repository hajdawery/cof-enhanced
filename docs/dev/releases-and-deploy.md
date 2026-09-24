# Staging, deploying and releasing

Three different things, kept apart on purpose:

| Step | Where | For whom |
| --- | --- | --- |
| **stage** a verified build | `stage1\releases\<name>\` (outside the repo) | the project: a frozen, hashed copy |
| **deploy** it to the play runtime | `stage1\deploy-ui-m3-20260921.ps1` -> `stage1\launch-prototype-20260920` | the user's own test play |
| **release** it publicly | a GitHub release archive built from [`release/RELEASE-MANIFEST.md`](../../release/RELEASE-MANIFEST.md), installed by the patcher | players |

## Staging rule (since 2026-09-22 17:50)

A worker rebuilt the shared build folder while the user was deploying, and the
deploy failed its hash check. Since then:

1. Every round builds into **its own** out directory, preferably in its own
   private tree (`pristine-<round>-<date>`).
2. The verified binaries (with their PDBs) are **copied** into a new
   `stage1\releases\<name>-<date>\`, with a `SHA256SUMS.txt` and, where it
   helps, `DEPLOY-NOTES.md`. A staged folder is never modified afterwards.
3. The deploy script reads **only** from `stage1\releases\`. A round that
   changes what is deployed updates the script's hashes in **one** edit, and
   only one worker owns that edit at a time.

Staged so far: `m4`, `m4-fonts`, `m4b`, `m4c`, `m5`, `m5a`, `fov`,
`fovmenu`, `m5b`, `lang`, `cheats`, `m6`, `coop`, `lang2`, `fix-ads-tape`,
`lang3` (all `-20260922`) and `m7-20260923`, the first build of the complete
[patch stack](patch-stack.md) in one run (it folds in `coop`, `lang2`,
`fix-ads-tape` and `lang3`), then `gamepad`, `panels`, `options` (all
`-20260923`, each on its own) and `m8-20260923`, the second full-stack build
(m7 + those three rounds, cheats last). The deploy script points at `m8`.

## The deploy script

`stage1\deploy-ui-m3-20260921.ps1` (outside the repository) copies a
hash-pinned payload into the runtime and keeps a backup:

* files: `xash.dll`, `vgui.dll`, `ref_gl.dll`, `cryoffear\cl_dlls\menu.dll`
  (each with its PDB), the Inter TTFs and `OFL.txt` under
  `cryoffear\gfx\fonts\`, the five atlases under `cryoffear\fonts\`,
  `cryoffear\resource\cryoffear_english.txt`, `cryoffear\gfx\shell\kb_def.lst`,
  and (since m7) `OFL.txt` beside the atlases under `cryoffear\fonts\`;
* folders: all seven language packs, `languages\<code>` -> `cryoffear\languages\<code>`,
  each pinned by its `MANIFEST.tsv` hash and file count, checked file by file
  before and after the copy, refusing junctions; and (since m8) the gamepad
  art, the staged release's `gfx\shell\gamepad` (36 files) ->
  `cryoffear\gfx\shell\gamepad`, pinned by the release's
  `gamepad-SHA256SUMS.txt` (whose own hash is in the script) and handled like
  a pack;
* `-Rollback` restores the backup, removes files and packs that were not there
  before, and puts back a pack that was (since m7 a deploy also drops a stale
  backup copy of a file it finds absent, so rollback removes that file instead
  of restoring an older deploy's copy).

The Polish pack (1.2.0, entity patches and model textures) and the engine go
together: an older engine ignores `.entpatch` files and `models/` textures.

The base overlay that the UI deploys sit on (launcher, `SDL2.dll`,
`filesystem_stdio.dll`, `cryoffear\gameinfo.txt`,
`cryoffear\scripts\chapterbackgrounds.txt`, `cryoffear\maps\c_game_menu1.ent`)
came from the earlier `stage1\deploy-working-overlay-20260921.ps1` and
`stage1\deploy-ui-m1-20260921.ps1`.

## Public release

What a release archive contains, and what it must never contain, is fixed in
[`release/RELEASE-MANIFEST.md`](../../release/RELEASE-MANIFEST.md); the licence
obligations behind it are in [LICENSING.md section 6](../../LICENSING.md#6-what-every-release-and-the-patcher-must-contain).
The first public build is **0.4.0-test1** (tag `v0.4.0-test1`, a GitHub
pre-release). The steps:

1. Bump `VERSION` (line 1 the version, line 2 the milestone) and commit it.
2. Build the whole [patch stack](patch-stack.md) end to end into a private
   tree, run `scripts\write-cof-version.ps1` against it (the stamp must not end
   in `+`), build `xash`, `vgui`, `ref_gl`, `menu` and `filesystem_stdio`, and
   the launcher with `scripts\build-cof-launcher.ps1` (it takes its version
   resource - ProductName "Cry of Fear Enhanced", ProductVersion = `VERSION`
   line 1 - from the bumped `VERSION`; check it with
   `(Get-Item CoFLaunchApp.exe).VersionInfo`, see
   [building](building.md#the-games-name-in-windows)).
3. Stage the binaries in `stage1\releases\v<version>\` (game-folder layout,
   PDBs under `pdb\`, `SHA256SUMS.txt`, and `BUILD-INFO.txt` with
   `binaries_commit=` and `stamp=`).
4. Commit anything else the release needs (docs, installer), then run
   `scripts\build-release.ps1 -Version <v> -Binaries stage1\releases\v<v>
   -OutDir <dist> -EngineTree <private tree> -CanonicalGame <untouched game>`
   on the clean checkout. It refuses tracked changes, checks every binary and
   language pack against its hashes, refuses PDBs and game files, and writes
   `cof-enhanced-<v>.zip`, `cof-enhanced-<v>-source.zip` and `SHA256SUMS.txt`.
   It also refuses when anything compiled into a binary (patches, launcher,
   `VERSION`, gamedata, packs) changed after `binaries_commit`.
5. Test the zip on a scratch copy of the game (never the play runtime):
   extract, `Install.cmd`, one launch, `Install.cmd` again, `Uninstall.cmd`,
   compare with the canonical game; `Install.cmd` in a wrong folder must refuse.
6. Tag the release commit (annotated), push, and create the GitHub release as
   a draft pre-release with the three files; the owner publishes it.

The installer itself (`release/installer/`): `Install.cmd` runs
`cof-enhanced\install.ps1`, which checks the folder (`CoFLaunchApp.exe`, the
Steam `hl.dll`), backs up the game files it replaces into
`cof-enhanced-backup\` once, copies the payload, writes `gameinfo.txt` and
`maps\c_game_menu1.ent` from the player's own files, and verifies everything
against `MANIFEST.sha256`; `Uninstall.cmd` reverses it. Details in the release
manifest, section 0.
