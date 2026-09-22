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
`fix-ads-tape` and `lang3`). The deploy script points at `m7`.

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
  before and after the copy, refusing junctions;
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

Nothing has been released publicly yet. What a release archive contains, and
what it must never contain, is fixed in
[`release/RELEASE-MANIFEST.md`](../../release/RELEASE-MANIFEST.md); the licence
obligations behind it are in [LICENSING.md section 6](../../LICENSING.md#6-what-every-release-and-the-patcher-must-contain).
In short: build the whole [patch stack](patch-stack.md) end to end from the
pinned sources, stage it, fill the [player README template](../player-README-template.md),
attach a source archive, and publish free of charge.

The **patcher** (planned, not written yet) is a self-extracting installer that:

1. finds and verifies the player's Steam install of Cry of Fear (retail 1.6
   `hl.dll` / `client.dll` hashes);
2. backs up the three files it replaces (`CoFLaunchApp.exe`, `vgui.dll`,
   `FileSystem_Stdio.dll`) and never deletes one;
3. copies the release overlay with hash checks;
4. generates the game-derived files locally from the player's own install
   (`cryoffear\maps\c_game_menu1.ent`, `cryoffear\gameinfo.txt` with our keys
   merged in) - nothing derived from game data ships in the archive;
5. writes an uninstaller that restores the backups and removes what it added.
