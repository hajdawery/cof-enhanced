# Experimental CoF playermove adapter

## Evidence

The original Steam `cryoffear/cl_dlls/hl.dll` exported PM_Init at RVA `0x61D0`. Its helper around RVA `0x6200` reads `pmove + 0x4F3F4` as the physics-info string and calls the function at `pmove + 0x4F558` with `(physinfo, "mtl")`. In the FWGS dump, `pmove + 0x4F558` is current `pfnParticle`; current `Info_ValueForKey` is at `+0x4F554`. The resulting call reaches `hl.dll+0x6288`, with `ECX=8` and a string dereference fault.

An x86 MSVC `offsetof` check against the FWGS/CoF header reports `physinfo=0x4F3F0`, `PM_Info_ValueForKey=0x4F554`, `PM_Particle=0x4F558`, `COM_FileSize=0x4F5A0`, and `COM_LoadFile=0x4F5A4`. The original binary uses each post-physinfo field at `+4` relative to those values. The exact historical field that caused the shift is not available in the Steam DLL's SDK provenance.

## Adapter behavior

With `-cof-pmove-legacy`, `engine/server/sv_pmove.c` keeps the engine's `svgame.pmove` object unchanged and allocates a persistent aligned byte view of `sizeof(playermove_t)+4`. It copies the prefix through `physinfo`, inserts four zero bytes, and copies the remaining bytes four bytes later. PM_Init receives that view and retains it. Before each PM_Move call the current object is copied to the view; after the call both prefix and shifted tail are copied back. Engine callback functions continue to use the native object, avoiding a global callback-table shift.

This tests the first proven ABI discrepancy and supports PM_Init/PM_Move state exchange. It does not assert that the unknown field is semantically zero, that all later interfaces match, or that the original client renderer will work. It must remain opt-in until the tester records a new dump/log and validates movement.

## Build/test gate

Build an x86 engine from the exact FWGS source with its recursive dependencies and the official SDL2 Visual Studio development package. Add `-cof-pmove-legacy -minidumps -log cof-adapter.log -game cryoffear` only in a copied test directory. A successful result must show the adapter warning, `Dll loaded for game "Cry of Fear"`, and progress beyond PM_Init; retain any dump. Do not deploy it over the original installation.

## Runtime checkpoint (2026-09-20)

The diagnostic executable was copied to the isolated `stage1/launch-proof/runtime` tree as `xash-cof-adapter.exe`. Its SHA-256 was `75EF27E461D39C561F4ED52F7E81C5813319AEA6FF96A030435A93F867C38`.

The same executable without `-cof-pmove-legacy`, using `+map c_intro`, reproduced the original PM initialization failure. The log `stage1/launch-proof/runtime-built-control-cintro-20260920.log` records `hl.dll` RVA `0x6288` (read at address `0x8`) called by `SV_InitClientMove` at `sv_pmove.c:547`.

With `-cof-pmove-legacy`, the engine logged the adapter warning, loaded the Cry of Fear server DLL, built the `c_intro` PHS, and then reached a different ABI/runtime failure while spawning `weaponbox`. The minidump `stage1/launch-proof/runtime/xash-cof-adapter_[]_crash_20260920_135113.mdmp` records `0xC0000005` with a write to `0x7C` at `pfnPvAllocEntPrivateData` (`sv_game.c:2932`), called by `hl.dll` and then `SV_ParseEdict`. The faulting bytes are `89 46 7C`; the captured `ESI` is zero, so the engine attempted to write `pEdict->pvPrivateData` through a null edict pointer during map entity spawn.

This is concrete progress past the PM_Init callback mismatch, but it is not menu, client, rendering, save/load, or Steam launch proof. The installed `Cry of Fear` directory was not modified, and no test processes remained after the bounded runs.

The second crash also has a verified layout cause. The dump's return address `0x5B02049E` is RVA `0x12049E` from the copied `hl.dll` base `0x5AF00000`. Existing disassembly at preferred address `0x10120460` loads `[esi+0x20C]` and passes it as the first argument to the engine's `pfnPvAllocEntPrivateData` with `cb=0x500`. DIA symbols for the current Xash build report `entvars_s::pContainingEntity` at `0x208` and `playerclass` at `0x20C`. The shipped DLL therefore reads the containing-entity field four bytes later than the current engine provides; it reads the zero `playerclass` field and passes a null edict pointer. This explains the adapter run's `pfnPvAllocEntPrivateData` write fault at `sv_game.c:2932` without treating the null argument as intentional game behavior.
