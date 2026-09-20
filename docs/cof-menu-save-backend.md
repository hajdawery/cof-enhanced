# CoF menu-save backend checkpoint

This experimental backend adds the server-side transaction behind an optional
Cry of Fear pause-menu save. The paired MainUI checkpoint supplies the user
enable/disable choice and separate overwrite confirmation. The cvar
`cof_pause_menu_saves` still defaults to `0`.

When enabled together with `cof_save_root_compat 1`, `cof_menu_save 1` through
`cof_menu_save 5` share the original five CoF slots. The transaction refuses
the menu map, preserves `IsValidSave`, creates a timestamped `saveinfoN.cof`
label, and writes the save through the existing root-save adapter. Existing
save and label files are renamed to `.coffix-backup` before replacement. A
failed label write, save write, copy, close, or rename attempts rollback and
leaves recovery files when automatic cleanup cannot safely complete. The
normal tape-save path and its separate client command hook are unchanged.

Each pause-save label is deliberately `Pause Save (<active map name>) -
<timestamp>`, for example `Pause Save (c_forest3) - Thu May 16 16:46:02
2013`. It uses `sv.name` and does not inspect tape-recorder entities, so it
cannot imply that the player used a tape recorder or reuse a stale checkpoint
title. The final ` - <timestamp>` delimiter remains intact for MainUI's label
reader.

Runtime QA on 2026-09-20 used the frozen engine
`E7C1AB450835E6DCB4E7A6EEFF8C8126B62D02456C4CEC5AF2EEAD31415CBB80` and
MainUI `1CF46E49A3BE317D9A718435FDA1AC01FB4795E38DE5CA977B2AB514E7A6271B`.
With an enabled empty slot 3, it wrote the exact label
`Pause Save (c_forest3) - Sun Sep 20 21:02:25 2026`, reloaded
`c_forest3.HL1`, and left stock tape metadata in slots 1 and 2 unchanged.
The retained evidence is `stage1/pause-map-label-qa-20260920/RESULTS.md`;
this is a focused save/reload check, not a broad UI or renderer claim.

The I/O wrappers are scoped to the optional menu transaction. They track open,
short-write, close, read/copy, and copy-input failures, including intermediate
HL files copied by `SaveGameState`. The generic engine filesystem behavior is
not presented as fixed globally; this checkpoint only uses the tracking state
to decide whether to discard the menu transaction's recovery copy.

The helper requires the earlier root-save and pause-save plumbing markers,
confines `SourceRoot` inside this project, verifies forward markers, and
supports a checked reverse application:

```powershell
pwsh -NoProfile -File scripts/apply-cof-menu-save-backend.ps1 `
  -SourceRoot <source-tree>
```

Use `-Reverse` only on a source tree with this backend already applied. A
disposable fixture passed forward application, marker verification, reverse
checking, and reverse application. The current source also rejects
`c_game_menu1` by name before saving because some CoF menu-map sessions do not
register the `game_menu` cvar.

A bounded command-equivalent runtime smoke test reports the default-off state
unchanged, invalid slot arguments rejected, and an enabled empty slot 3 save
followed by reload succeeding. This does not validate a human GUI click,
visual parity, tape-recorder saves, or broad campaign behavior; retained
runtime evidence remains in the investigation reports.
