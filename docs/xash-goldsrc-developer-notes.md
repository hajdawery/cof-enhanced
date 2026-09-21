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

## Native save writers can hide filesystem failures

**Verified in the pinned source:** the native save path issues many
`FS_Write`/`FS_Close` calls without consistently checking their return values;
`DirectoryCopy` also relied on the generic `FS_FileCopy` result. A save can
therefore reach its success return while a short write or close failure has
not been surfaced. The menu-save checkpoint adds scoped tracking and a
checked copy loop only around its optional transaction; it is not a general
engine-wide I/O fix. Any broader save reliability work needs its own error
propagation design and recovery policy.

## ABI adapters must preserve the native engine view

The tested CoF binaries exposed a four-byte PMove table shift after `physinfo`,
a four-byte shifted range in `entvars_s` (`sequence`, `health`, and `iuser1`),
and a separate `edict_s` stride discrepancy. These are ABI observations for
specific binaries. An adapter should keep the engine's native object for
engine callbacks, translate only at the original DLL boundary, use persistent
storage for the translated view, and remain behind an explicit opt-in profile.
Changing the default engine layout globally turns one compatibility fix into a
process-wide ABI regression.

## Engine/client surface records can be intentionally mutated

The original client exposes a mutable surface-array handoff: `numsurfaces` is
at `model + 0xB0`, the array pointer at `model + 0xB4`, and each record is
`array + i * 0x5C`; the client tests record `flags + 0x8` for
`SURF_DRAWSKY (0x04)` and negates the polygon `numverts` field at `poly + 8`.
A matched builder saw sky counts `4, 6, 6, 4`, then the same pointer negative
before the first normal callback; the intervening client mutation is not yet
attributed to a specific callback. The reusable lesson is that a negative
count is not automatically engine memory corruption or proof of the skyline
cause. Detailed evidence is in `stage1/gl-world-poly-qa-20260920/` and
`docs/cof-skyline-trace.md`.

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

## FWGS reclassifies custom `renderfx` entities as translucent; GoldSrc does not

GoldSrc decides opaque versus translucent from `curstate.rendermode` alone, so
an entity with `rendermode 0` is drawn in the solid pass no matter what value a
mod stores in `curstate.renderfx`. FWGS `R_OpaqueEntity()` in
`ref/gl/gl_rmain.c` instead accepts only `kRenderFxNone`,
`kRenderFxDeadPlayer`, `kRenderFxLightMultiplier` and `kRenderFxExplode`, so
any mod-defined `renderfx` silently demotes a solid entity into the translucent
list, where it is sorted after translucent brush geometry and drawn on top of
it.

Mods really do carry their own `renderfx` values. Cry of Fear identifies sky
models by `renderfx` in `{70, 137, 184}` and uses 92/93/94 as draw-distance
cull flags; its main-menu sky sphere (`rendermode 0`, `renderfx 137`) was being
drawn after the translucent brush entity that paints the skyline and covering
it. Because a translucent brush correctly leaves depth writes off, there is no
depth value protecting the skyline, so this is purely an ordering defect.

Runtime evidence: walk the draw lists entity by entity rather than reasoning
about depth state. Both the wrong draw order and the fix are visible in list
membership alone. See
[custom renderfx opaque classification](cof-custom-renderfx-opaque.md).

## Evidence convention

Record the pinned source revision, relative source path, evidence type
(`static`, `runtime`, `artifact`, or `unverified`), exact command/input route,
and deployed executable/DLL/PDB hashes. State the smallest claim supported by
the evidence. Keep proprietary DLLs/assets, raw dumps, saves, and machine-
specific paths out of this notebook; put detailed run chronology in the
corresponding investigation report.
