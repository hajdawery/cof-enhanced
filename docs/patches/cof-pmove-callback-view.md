# CoF playermove callback view and the corrected shift boundary

> **Stack position (2026-09-22 docs pass):** the verified order applies it in the
> milestone-5 group, after the MainUI patches and before `cof-viewmodel-fov`;
> it only needs the two playermove adapters. [The patch stack](../dev/patch-stack.md)
> is authoritative.

`patches/cof-pmove-callback-view.patch` fixes the reported "it is very easy to
get stuck, especially in crouch sections" bug and corrects the one field range
the playermove adapter still mismaps. It is applied on top of
`patches/cof-pmove-legacy.patch` and `patches/cof-client-pmove-legacy.patch`:

```powershell
pwsh -File .\scripts\apply-cof-pmove-callback-view.ps1 `
  -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

It edits only `engine/server/sv_pmove.c` and `engine/client/dll_int/cl_pmove.c`,
which no other patch in the stack touches, so it goes **last in the engine
stack, after `scripts/apply-cof-ui-scale.ps1`**. Its only real prerequisites are
the two playermove adapters. The script takes `-Reverse`.

Everything here was measured on 2026-09-22; the investigation, the logs and the
scratch build are in `stage1/crouch-stuck-20260922`.

## What was wrong

### 1. The engine's playermove callbacks read a stale object

`-cof-pmove-legacy` keeps the engine's own `playermove_t` and hands the game DLL
a four-byte-shifted copy, synchronising it around `PM_Init` and `PM_Move`
(`sv_pmove.c` `SV_CoF_CopyToLegacyPMove` / `SV_CoF_CopyFromLegacyPMove`, and the
client mirror in `cl_pmove.c`). Engine callbacks were deliberately left pointing
at the native object so the callback table itself would not have to shift.

But those callbacks do not only *write* results - they *read* playermove state:

| callback | reads |
| --- | --- |
| `pfnPlayerTrace`, `pfnPlayerTraceEx` | `pmove->usehull` (hull selection), `numphysent`, `physents` |
| `pfnTestPlayerPosition`, `pfnTestPlayerPositionEx` | `pmove->usehull`, `pmove->origin` |
| `pfnTraceLine`, `pfnTraceLineEx`, `pfnHullForBsp`, `pfnTraceModel` | `pmove->usehull` |
| `pfnStuckTouch` | `pmove->velocity`, `numtouch`, `touchindex` |

The hull comes from `pmove->usehull` in `engine/common/pm_trace.c` (lines 148,
167, 183, 370-371, 385, 392-393, 416, 433, 567). While the DLL is inside
`PM_Move` it is changing `usehull` **in the shifted copy**, so every trace it
then asks the engine for is answered with the value `SV_SetupPMove` wrote before
the call - the *previous* frame's hull. In stock FWGS the DLL and the engine
share one object and this cannot happen.

`usehull` is exactly the field `PM_Duck` and `PM_UnDuck` change and immediately
trace with:

* `PM_FinishDuck` (`cl_dlls/hl.dll` `0x1000560F`) sets `usehull = 1`, does
  `origin[2] -= 18`, then calls `PM_FixPlayerCrouchStuck` and
  `PM_CategorizePosition`. The engine tests the lowered origin with the
  **standing** hull, answers "solid", and the nudge loop lifts the origin back
  by the same 18 units. The duck's origin correction is undone; the player is
  left 18 units above the floor with the duck hull and free-falls.
* `PM_UnDuck` (`0x100095B0`) sets `usehull = 0` and then traces to ask "would I
  fit standing here?". The engine answers with the **duck** hull, so the test
  always passes. `FL_DUCKING` is cleared under a low ceiling, the next frame
  gives the edict the 72-unit hull inside solid geometry, and `PM_CheckStuck`
  aborts `PM_PlayerMove` every frame after that. That is the stuck.

### 2. The four-byte gap was inserted one field too late

The adapter note records the shift from `physinfo` onwards. Disassembly of the
shipped `cl_dlls/hl.dll` (SHA-256 `0036B91C...`, `DLL_FUNCTIONS` table at VA
`0x102119F8`) shows where the original layout actually diverges:

| field | current FWGS | shipped `hl.dll` | site in `hl.dll` |
| --- | ---: | ---: | --- |
| `multiplayer` | `0x008` | `0x008` | `PM_Move` `0x10006F75` |
| `frametime` | `0x010` | `0x010` | `0x10007058` |
| `origin` | `0x038` | `0x038` | `PM_UnDuck` `0x100095DB` |
| `view_ofs[2]` | `0x088` | `0x088` (`28.0f`) | `PM_UnDuck` `0x1000973E` |
| `flDuckTime` | `0x08C` | `0x08C` | `PM_Duck` `0x10005543` |
| `bInDuck` | `0x090` | `0x090` | `PM_Duck` `0x10005552` |
| `flags` (`FL_DUCKING 0x4000`) | `0x0B8` | `0x0B8` | `0x1000562D`, `0x10009720` |
| `usehull` | `0x0BC` | `0x0BC` | `0x1000560F`, `0x100096B2`, `0x10009705` |
| `friction` | `0x0C4` | `0x0C4` | `0x10006F84` |
| `onground` | `0x0E0` | `0x0E0` | `0x10006F51` |
| `numphysent` | `0x24C` | `0x24C` | 167 sites |
| `cmd.forwardmove` | `0x45468` | `0x45468` | `0x10006FA5` |
| `cmd.buttons` | `0x45476` | `0x45476` | 16 sites |
| **`numtouch`** | **`0x4548C`** | **`0x45490`** | `PM_AddToTouched` `0x10003872`, `0x10003942`; `PM_PlayerMove` `0x10008A1C` |
| **`touchindex`** | **`0x45490`** | **`0x45494`** | `0x10003904`, stride `0x44`, cap `0x258` |
| `physinfo` | `0x4F3F0` | `0x4F3F4` | 17 sites |
| `movevars` | `0x4F4F0` | `0x4F4F4` | 21 sites |
| `player_mins` | `0x4F4F4` | `0x4F4F8` | `PM_Duck` `0x10005660`, `PM_UnDuck` `0x1000961F` |
| `PM_PlayerTrace` | `0x4F580` | `0x4F584` | `0x10009662` |

Everything from `numtouch` on is `+4`; everything before it, `cmd` included, is
identical. So the gap belongs before `numtouch`, not before `physinfo`.
Inserting it at `physinfo` leaves `numtouch` and `touchindex[600]` mismapped by
four bytes in both directions: the DLL's touch records land on the engine's
`touchindex[0].startsolid` onwards, the engine's `numtouch` is never written, and
the `SV_Impact` loop in `SV_RunCmd` (`sv_pmove.c`, just after `SV_FinishPMove`)
therefore never runs. Every playermove touch impact is silently dropped.
`PM_StuckTouch` writes the engine-side `touchindex`, which the copy-back then
overwrites, so even those are lost.

Note that **the duck fields were never mismapped**: `usehull`, `view_ofs`,
`flDuckTime`, `bInDuck`, `flTimeStepSound` and `flags` all live in the unshifted
prefix and round-trip correctly. And the hull sizes are stock - Cry of Fear's
`pfnGetHullBounds` (slot 46, RVA `0x1E080`) returns TRUE for hulls 0/1/2 and
never writes `mins`/`maxs`, so the engine defaults stand (32x32x72 standing,
32x32x36 crouched), as every run's `SV: hull0 ...` line confirms.

## What the patch does

**(a) A live view for the callbacks.** `cof_pmove_legacy_active` is set only
around the two DLL entry points, and `SV_CoF_SyncLegacyToNative()` /
`CL_CoF_SyncLegacyToNative()` mirror `usehull`, `origin` and `velocity` - the
three fields the callbacks read, all in the unshifted prefix - at the top of
each of them (13 sites on the server, 8 on the client). Three field copies per
trace, not a struct copy. Behind `cof_pmove_legacy_hullsync` and
`cof_pmove_legacy_hullsync_cl`, both default `1`, both readable per call so the
old behaviour can be reproduced live.

**(b) The corrected boundary.** `SV_CoF_LegacyTail()` / `CL_CoF_LegacyTail()`
return `offsetof(playermove_t, numtouch)` instead of
`offsetof(playermove_t, physinfo)`. Nothing at or after `physinfo` moves - it
stays at `+4` - so `PM_Init`, the callback table, `movevars` and `player_mins`
are unaffected; only `numtouch` and `touchindex` come back into line. Behind
`cof_pmove_legacy_touchfix` and `cof_pmove_legacy_touchfix_cl`, both default `1`.
These two are **latched** at `SV_InitClientMove` / `CL_InitClientMove`: the game
DLL keeps the pointer `PM_Init` was handed, so the shape of the view must not
change mid-session.

## Evidence

One session, one spot on `c_bridge` (`-993 1281 -730`), the cvar toggled between
the two phases, probe `ent_info 1` every two frames
(`stage1/crouch-stuck-20260922/evidence/crawl6-within-ab.log`, repeated with the
packaged build in `crawl8-packaged-ab.log`). `FL_ONGROUND` is `0x200`,
`FL_DUCKING` is `0x4000`, `FL_CLIENT` is `0x8`.

`cof_pmove_legacy_hullsync 1` - correct GoldSrc behaviour:

```
A_DUCK_67  origin: -993 1281 -730   flags: 0x208
A_DUCK_68  origin: -993 1281 -748   flags: 0x4208    <- -18 in ONE frame, still on ground
A_UND_0    origin: -993 1281 -748   flags: 0x4208
A_UND_1    origin: -993 1281 -730   flags: 0x208     <- +18 in ONE frame, still on ground
```

`cof_pmove_legacy_hullsync 0` - the behaviour that was shipping:

```
B_DUCK_69  origin: -993 1281 -730   flags: 0x208
B_DUCK_70  origin: -993 1281 -730   flags: 0x4008    <- ducked, origin NOT moved, ground LOST
B_DUCK_74  origin: -993 1281 -731   flags: 0x4008    <- free-falling instead
   ...     falls to -743 over about 0.4 s
B_UND_0    origin: -993 1281 -743   flags: 0x4008
B_UND_1    origin: -993 1281 -743   flags: 0x8       <- stood up inside geometry
B_UND_2..59 origin: -993 1281 -743  flags: 0x8       <- STUCK for every remaining probe
```

`flags 0x8` for 60 consecutive probes is the reported failure: no ground, no
ducking, origin frozen, nothing the player presses moves them.

There is no control without the adapter. With `-cof-pmove-legacy` off the engine
faults in `PM_Init` before any map loads
(`evidence/crawl7-noadapter.log`: `Crash: address 58CF6288, code C0000005`,
`hl.dll` RVA `0x6288`, called from `SV_InitClientMove`), exactly as
[the adapter note](pmove-adapter.md) records.

## Limits

* Part (b) is not positively validated by these runs. Nothing in them depends on
  playermove touch impacts; pushables, `func_` impacts and momentary entities
  are where a regression or an improvement would show. It was active in every
  scratch run without a regression.
* A separate, still-open geometry block: inside the `c_bridge` duct at
  `(-998, 1281, -744)` the player does not advance with `+forward` held even
  with the fix on, while `+back` moves freely. The runs cannot steer - keyboard
  and mouse injection are not allowed, so the yaw is whatever the spawn gives -
  so this looks like plain geometry and not a second stuck. A human play test of
  the `c_bridge` crawl is the outstanding check.
* The mirror deliberately copies three fields and no more. `numphysent`,
  `physents`, `numvisent`, `visents`, `movevars`, `player_index` and `server`
  are engine-owned or constant for the duration of the call; `numtouch` and
  `touchindex` are handled by part (b) instead.
