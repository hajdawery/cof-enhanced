# Cry of Fear cheats, restored in the engine

`patches/cof-cheats.patch` brings back the Cry of Fear developer cheats that
version 1.6 removed, without touching a single game file. It is an engine-only
patch: the retail `hl.dll` and `client.dll` stay byte-for-byte what Steam ships.

```powershell
pwsh -File .\scripts\apply-cof-cheats.ps1 `
  -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

The player-facing list of commands is [CHEATS.md](../../CHEATS.md). This page is
the technical side: what each command writes, where the offsets come from, how
it is gated and what was measured.

## Where it goes in the stack

The patch adds two files (`engine/server/sv_cof_cheats.c`, `.h`) and four small
hooks:

| file | hunk |
| --- | --- |
| `engine/server/sv_client.c` | `#include "sv_cof_cheats.h"`; `SV_CoF_CheatsClientCommand( cl )` at the top of `SV_ExecuteClientCommand`, before the stock user-command table |
| `engine/server/sv_pmove.c` | `#include`; `SV_CoF_CheatsPostThink( cl )` in `SV_RunCmd` between the game DLL's `pfnPlayerPostThink` and `pfnCmdEnd` |
| `engine/common/zone.c`, `common.h` | `Mem_AllocatedSize( pool, ptr )`: the size of a live allocation, 0 if `ptr` is not the start of one (same chain walk as `Mem_IsAllocatedExt`) |

The `sv_client.c` hunk uses the menu-load trace's `cofload` lines as context, so
the patch needs `cof-menu-load-trace` and the entvars profile (both checked by
the script). Nothing else in the stack touches these hunks; put it **last in the
engine stack**, after `apply-cof-pmove-callback-view.ps1` (it was generated and
verified on top of the whole milestone 5a stack, see *Verification*). It also
applies cleanly (`git apply --check`) to the shared checkout with the in-flight
Polish and m5b edits in it. The script takes `-Reverse`.

## Why the stock commands do not work with the retail DLL

Measured in `stage1/cheats-verify-20260922` and statically in
`stage1/cheat-extract-20260922`:

- **noclip**: the engine command flips `movetype` to `MOVETYPE_NOCLIP` (8), and
  retail `CBasePlayer::PostThink` (`100EB203`) puts it back to
  `MOVETYPE_WALK` (3) on the next frame. Plain `noclip` therefore does nothing
  lasting.
- **notarget**: works, but thirteen retail code paths clear `FL_NOTARGET`
  (doors, coop doors, ladders, MDL cutscenes, `trigger_camera`, padlocks,
  `EndSave`, `TouchChangeLevel`, dev commentary, ...).
- **god**: sets `FL_GODMODE`, but retail `CBasePlayer::TakeDamage` (`100F6030`)
  never tests it, and `PostThink` clears it (`100EB219`). It has no effect; it
  is left exactly as stock and documented as useless.
- **give**: not in the retail `ClientCommand`; the engine forwards it and the
  game DLL prints `Unknown command: give`.
- CoF 1.6 removed `god`, `noclip`, `notarget`, `fly` and the named-save gate in
  its own `hw.dll`, which Xash replaces; named `save`/`load` already work.

## The gate

Everything this patch adds is gated twice, per command:

1. **`sv_cheats 1`** and a real game: `sv.state == ss_active`, not the menu
   background map, issuing client spawned.
2. **The loaded server DLL is the retail Cry of Fear 1.6 `hl.dll`**, identified
   by the SHA-256 of the module file:

   ```
   0036b91c01e92ed205513f52563053a55a66a32d257efb5f476b8f1f3dde0e63
   ```

   computed from the canonical `Cry of Fear\cryoffear\cl_dlls\hl.dll` (the game
   DLL CoF actually loads, `liblist.gam` `gamedll "cl_dlls/hl.dll"`; there is
   no `dlls\hl.dll` in this game). The engine hashes the file the loader mapped
   (`GetModuleFileNameW` on the module, falling back to the loader's resolved
   path), once per loaded game DLL, with a small in-file SHA-256. It is also
   compiled in only for Win32 x86 builds with `--enable-cof-entvars-legacy`;
   three `STATIC_ASSERT`s pin the CoF entvars layout it writes
   (`movetype` +0x108, `flags` +0x1A8, `air_finished` +0x200).

What happens when the gate is closed:

| command | `sv_cheats 0` | wrong / unreadable DLL |
| --- | --- | --- |
| `noclip`, `notarget` | stock engine path (which itself needs `sv_cheats`) | stock engine path |
| `give` | `give: needs sv_cheats 1` | forwarded to the game DLL as before (a mod with its own `give` keeps it) |
| `fly`, every `cof_*` | `<cmd>: needs sv_cheats 1` | `<cmd>: refused: the loaded hl.dll is not the retail Cry of Fear 1.6 build (offsets unknown)` |
| `cof_cheats` (status) | prints | prints, says why the cheats are off |

On the menu background the commands print `needs a loaded game`. A `cof_`
name this patch does not own is passed on to the game DLL untouched.

### Validation before every write

The player object is `CBasePlayer* = edict->pvPrivateData`. Before any read or
write the engine checks:

- the client is spawned, the edict is valid and its classname is `player`;
- `pvPrivateData` is the start of a live allocation in the server-edicts pool
  (`Mem_AllocatedSize`), and that allocation is at least `0x2304` bytes (the
  highest field used plus four); the result is cached per client slot and
  re-validated whenever the pointer changes (every load and changelevel);
- `*(entvars_t **)(pv + 4) == &edict->v` - `CBaseEntity::pev` points back at
  this very edict;
- the value about to be replaced is one the game can hold: `bool` fields must
  read 0 or 1, the nightvision state must be 0, 1, 0x64 or 0x65, the tape
  counter 0..100000. Anything else is refused with a message (and a latched
  cheat that finds an unexpected value switches itself off) instead of being
  written.

Door entities get the same allocation-size and `pev` back-pointer check.

## Commands

All of them are client commands handled on the server (`SV_ExecuteClientCommand`),
so they work from the console (unknown commands are forwarded to the server),
from a cfg and in coop, and act on **the player who typed them**.

### Bucket A - engine-owned state

| command | effect | kind |
| --- | --- | --- |
| `noclip [0\|1]` | `movetype = MOVETYPE_NOCLIP` and a per-client latch; after every `PlayerPostThink` the engine sets it again **if the game handed back `MOVETYPE_WALK`** and the player is alive. Anything else the game chose (ladder `MOVETYPE_FLY`, a cutscene freeze, death) is left alone, and the latch takes over again when the game returns to `WALK`. No argument toggles. | latched |
| `fly [0\|1]` | new command (FWGS has none): `MOVETYPE_FLY` (5), same re-assert rule. `noclip` and `fly` switch each other off. | latched |
| `notarget [0\|1]` | `FL_NOTARGET`, re-set after every `PostThink` while latched and alive, so the thirteen clearing sites cannot drop it. | latched |
| `give <classname>` | what `CBasePlayer::GiveNamedItem` does, in the engine: `SV_CreateNamedEntity` (the creation `ent_create` uses) at the player's origin, `SF_NORESPAWN`, `pfnSpawn`, then the player **uses** it with `IN_USE` held for the call - CoF picks items up by use (`CBasePlayerItem::DefaultUse` / `CBasePlayerAmmo::DefaultUse` both just call `DefaultTouch`, `10017AB0`/`10017AC0`; the ammo path additionally requires a button in `pev->button`, `1011C620`) - and `pfnTouch` as a fallback. `sv_enttools_enable` is not needed. Only `weapon_*`, `item_*` and `ammo_*` classnames (anything else can take the game DLL down; `ent_create` is still there for that). Reports whether the game took it (weapon attached to the player, entity removed, or its touch and use functions cleared as the ammo pickup does). | one-shot |
| `god` | unchanged stock command. Has **no effect** in Cry of Fear (see above); use `cof_nodamage`. | - |
| `save <name>` / `load <name>` | unchanged; work already (named saves land in the root `SAVE\` folder with `cof_save_root_compat 1`). | - |

### Bucket B - writes into the retail player object

Offsets are from `CBasePlayer*` (= `pvPrivateData`) in the retail 1.6 `hl.dll`,
taken from its own `TYPEDESCRIPTION` save table (player table at VA `10217FE8`,
207 records) and the code that reads them (VAs are preferred-base `0x10000000`).

| command | field(s) | write | kind |
| --- | --- | --- | --- |
| `cof_infammo 0\|1` | `+0x21EA` `bool m_bInfiniteAmmo` | 1 while latched (re-written every frame, so it survives loading an older save), 0 once when switched off. Retail skips `m_iClip--` in every firearm `Shoot` and the syringe / flare decrements when it is set; nothing in the game ever sets it. | latched |
| `cof_infstamina 0\|1` | `+0x21E8` `bool m_bInfiniteStamina` | as above; skips the `m_fStamina` (`+0x21F0`) drain in sprint, dodge, jump and melee push. | latched |
| `cof_nodamage 0\|1` | `+0x1EA4` `bool b_GoingThroughADoor` | 1 after every `PostThink` while latched, 0 once when off. It is the first test in player `TakeDamage` (`100F603B`, returns 0) and `TraceAttack` (`100F6955`). **Single player only** (see side effects). | latched |
| `cof_nodrown 0\|1` | engine field `pev->air_finished` | `time + 12` after every `PostThink` while latched. Engine-owned entvars, no `hl.dll` member. | latched |
| `cof_nightvision [0\|1]` | `+0x434` `bool m_bHasNightVision`, `+0x2300` `int m_iHeadShieldOn` | sets `m_bHasNightVision = 1` (what picking up `item_nightvision` does) and writes the request value the game's own `flashlight` command writes once its gates pass: `0x65` to turn on (from 0), `0x64` to turn off (from 1). `PostThink` plays the goggles animation and completes the switch to 1/0 (`100EB92A`, `100EBB23`). This bypasses the single-player, map-prefix, unlockable and cooldown gates of `flashlight`. A request while a switch is still running is refused ("try again"). No argument toggles. | one-shot |
| `cof_ending 1..5` | `+0x4CD` `m_b_Ending_RoofBossKilled`, `+0x4CE` `m_b_Ending_GivenP345`, `+0x4CF` `m_b_Ending_DeliveredPackage` | 1:(0,0,0) 2:(0,1,0) 3:(1,0,0) 4:(1,1,0) 5:(1,1,1). Read by `CInterDoor::EndSequence` (`100481FF-1004828B`) at the ending door in Simon's house; the package flag overrides to ending 5. Saved with the game. | one-shot |
| `cof_tapes <0..999>` | `+0x1EF4` `int m_iTapes` | saves left on the current cassette (nightmare tape recorder). `PreSave` decrements it; picking up a cassette sets 5. `TapeUse` still requires the `cassettetape` item in the inventory. Saved with the game. | one-shot |
| `cof_unlockdoors` | `inter_door` `+0x190/+0x194`, `inter_door_coop` `+0x114/+0x118`, `func_valve` `+0x180/+0x184` (`string_t m_sLockedBy`, `m_sLockedMsg`) | zeroes both on every door of this map that is locked (`CInterDoor::IsLocked` `10048540` is `m_sLockedBy != 0`). Prints how many. | one-shot, per map |
| `cof_cheats` | - | status: `sv_cheats`, whether the hash matched (and the hash), every latch, and a read-back of the player fields above. Needs no `sv_cheats`; reads only. | - |

### Side effects and limits

- **`cof_nodamage`** borrows the "going through a door" flag. While it is set the
  game also skips `100E2560`, the "Stranger nearby" proximity routine
  (`m_bNearStranger`, `+0x1F04`), and in multiplayer `PostThink` (`100EBD75`)
  sets `EF_NODRAW` on the player - that is why the command refuses in coop.
  Door and transition code writes the flag itself (`100483E4`, `10048CEB`,
  `1004AF78`, `1004BBD2`, `1004C29D`, `100A7B2C`, `100E5AB5`, `100E96EE`); the
  latch simply writes it back after the next `PostThink`. A scan of every
  instruction with a `+0x1EA4` displacement in the retail DLL finds no other
  read: doors do not refuse to open while it is set. `kill` still kills
  (`pfnClientKill` does not go through `TakeDamage`).
- **`cof_unlockdoors`** does not fire the door's unlock target (`m_sUseUnlock`,
  `+0x1A0`) the way the key path does (`10048EB8`). A door whose unlock also
  triggers something (a light, a scripted scene, a counter) will open without
  that happening - the same "bad door" caveat the old cheat pack had. Doors that
  spawn later, or on another map, are not affected; run it again. Padlocks,
  keypads and scripted item use are code, not data, and are not affected.
- **`cof_tapes`** only refills the counter; the cassette item is still needed.
- **`cof_ending`** must be set before the ending door in Simon's house is used.
- **`give`**: a model the map did not precache is loaded late (Xash warns
  `late precache of models/...` and loads it; GoldSrc would have refused). Items
  the player already carries or cannot take (inventory full, the donator TMP,
  the mapper MP5, a second lantern) are left at the player's feet and reported.
- `god` stays the stock command and does nothing useful in this game.

## Save / load behaviour

The latches (`noclip`, `fly`, `notarget`, `cof_infammo`, `cof_infstamina`,
`cof_nodamage`, `cof_nodrown`) are engine memory, one set per client slot. They
survive `changelevel`, `save` and `load` for the rest of the session and are
re-applied on the first frame of whatever player object the slot has after a
load - including a save written *before* the cheat was switched on. They are
not written into saves and are gone when the game is closed.

The game-side fields persist in saves by themselves (they are in the player
save table): `m_bInfiniteAmmo`, `m_bInfiniteStamina`, the ending flags,
`m_bHasNightVision`, `m_iTapes`, `b_GoingThroughADoor`. So a save made while
`cof_infammo` was on still has infinite ammo after a restart; `cof_infammo 0`
clears it. `cof_ending`, `cof_tapes` and `cof_nightvision` are one-shots that
live on in the save.

`sv_cheats 0` releases every latch on the next frame and puts the defaults back
(`MOVETYPE_WALK`, `FL_NOTARGET` cleared, the three `bool` fields 0). While the
menu background map runs the latches are simply not applied.

## Verification (2026-09-22)

Fixture `stage1/cheats-impl-20260922/root`: the retail `client.dll` and
`hl.dll` (SHA-256 above), the m5a `vgui.dll`, `ref_gl.dll`, `menu.dll`, and the
cheats engine. Five launches, every command from `maps/<map>_load.cfg` or
`+exec`, `+volume 0`, windowed. Logs and screenshots in
`stage1/cheats-impl-20260922/evidence`, summary in its `RESULTS.md`.

| check | result |
| --- | --- |
| hash gate, match | the engine reports the retail hash; all commands run |
| hash gate, mismatch (test-only override, removed from the staged build) | all eight `cof_*` and `fly` print the one-line refusal; `give` reaches the game DLL (`Unknown command: give`); `noclip` is the stock command and the retail reset shows (`noclip ON` twice) |
| `noclip` persists | `movetype 8` at three reads over several seconds; `+moveup` climbs 45 -> 105 |
| `fly`, `notarget` persist | `movetype 5`; `flags 0x288` over 150 frames |
| `cof_infstamina` | sprint without: stamina 100 -> 73; with: 81 -> 81 over the same sprint |
| `cof_infammo` | glock HUD bar 15 -> 12 after three shots, then 12 -> 12 after three more with the cheat on (`evidence/l2-city-ammo-bar-a-b-c.png`) |
| `cof_nightvision` | state 0x65 -> 1, green view (`l2-city-d-nv-on.png`), off -> 0 (`l2-city-e-nv-off.png`) on a save without the unlock |
| `give` | "You got the Remington 870", revolver drawn with its cylinder HUD, "Picked up a glock magazine with 15 rounds"; `give monster_zombie` refused |
| `cof_nodamage` | `env_explosion` (magnitude 80) at 100 units: health stays 100 with it, 100 -> 56 without |
| `cof_ending`, `cof_tapes`, `cof_unlockdoors` | read back 100 / 7; one locked `inter_door` unlocked on `c_forest3` (the door itself not used) |
| latches across load | clean save first, latches switched on, clean save loaded: `movetype 8`, `flags 0x288`, `infammo 1`, `infstamina 1`, door flag 1 re-applied |
| `sv_cheats 0` | latches released, fields back to 0 / `WALK`; `cof_infammo` and `give` say `needs sv_cheats 1` |

Not exercised in game: `cof_nodrown` (needs water; engine field, static only),
the effect of an unlocked door when used, an ending actually played out, a tape
save with a refilled counter, coop.

Stack verification (`stage1/cheats-impl-20260922/stackverify-cheats.ps1`): a
fresh `pristine-clean` copy with the whole documented stack from cof-fix HEAD
(engine, ref, mainui, fov, pmove callback view), then `apply-cof-cheats.ps1`,
`-Reverse` (the four hooked files restored byte-for-byte, the two new files
removed), apply again; the resulting `engine\` is identical to the tree the
staged engine was built from (285 files; only the generated, uncommitted
`engine/cof_version.h` stamp differs).
