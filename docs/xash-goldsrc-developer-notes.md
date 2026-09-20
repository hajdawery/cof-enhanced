# Xash/GoldSrc developer notes

These notes keep only consequential, reusable findings from the bounded Cry of
Fear/Xash investigation. They refer to the pinned FWGS source revision
`4857b389e6ba32ddaa68582aedcbc950c138f46a`; CoF observations are examples for
the tested binaries, not general compatibility guarantees.

## Stock saves can be in the wrong filesystem root

The pinned server loader checks save files with a game-directory-only lookup
(`engine/server/sv_save.c:2141-2145`). Stock Cry of Fear installations keep
`SAVE/` beside the runtime game directory, while the normal Xash lookup for
`save/` resolves under `cryoffear/`. A bounded command-equivalent probe
accepted and spawned a stock save only after an exact-hash copy was placed in
`cryoffear/SAVE/`.

This is a deployment save-location compatibility requirement, not a
filename-casing issue or a generic loader failure. A compatibility layer must
map the locations deliberately, keep the behavior opt-in, and cover the
embedded sidecar extraction path as well as the `.sav` lookup. Save acceptance
still does not prove the GUI route, camera handoff, playable gameplay, or
visual parity; the tested post-load frame had severe white/orange corruption.

The save container and restore contracts are separate. The loader validates
the header, embedded directory payload, map, and game-DLL restore callbacks
(`engine/server/sv_save.c:1770-1813` and `2111-2180`). Entity field tables,
pointer offsets, and entity stride can therefore fail after a file has been
found and opened.

## ABI adapters must preserve the native engine view

The tested CoF binaries exposed a four-byte PMove table shift after `physinfo`,
a four-byte shifted range in `entvars_s` (`sequence`, `health`, and `iuser1`),
and a separate `edict_s` stride discrepancy. These are ABI observations for
specific binaries. An adapter should keep the engine's native object for
engine callbacks, translate only at the original DLL boundary, use persistent
storage for the translated view, and remain behind an explicit opt-in profile.
Changing the default engine layout globally turns one compatibility fix into a
process-wide ABI regression.

## Generated headers select the real target

The client build exposed a C preprocessor trap: `#ifdef XASH_DEDICATED` treats
`#define XASH_DEDICATED 0` as enabled. A stale generated header can therefore
produce a dedicated-style client artifact even when the configure command
appears to request a client. Use a fresh output directory and inspect the
generated defines and matching executable/DLL/PDB before interpreting runtime
results. A successful compile alone is not proof that the intended target was
built.

## Custom menus are not automatically engine UI

CoF's `GameMenu.res` selects maps and commands, including `engine map
c_loadgame`; the visible menu scene can still be drawn by the original client
DLL or map entities. A menu camera or footsteps can persist while a command is
being processed. A map transition or console-equivalent command therefore
does not prove mouse hit testing, input focus, camera handoff, or the original
client''s inventory/phone UI path.

## Evidence convention

Record the pinned source revision, relative source path, evidence type
(`static`, `runtime`, `artifact`, or `unverified`), exact command/input route,
and deployed executable/DLL/PDB hashes. State the smallest claim supported by
the evidence. Keep proprietary DLLs/assets, raw dumps, saves, and machine-
specific paths out of this notebook; put detailed run chronology in the
corresponding investigation report.
