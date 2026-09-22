# Cry of Fear ABI findings

> **Historical record (2026-09-20/21).** Kept for its evidence. Its open questions
> and "next gate" lists were resolved by later work; see [engine and game facts](engine-and-game-facts.md)
> and [milestones](milestones.md) for the current state.

## 2026-09-20 runtime evidence

The original copied Steam `hl.dll` and the pinned FWGS x86 diagnostic build
were tested only below `stage1/launch-proof`; the installed game directory was
not modified. The adapter executable used for the bounded comparison was
`xash-cof-adapter.exe`, SHA-256
`75EF27E461D39C561F4ED52F7E81C5813319AEA6FF96A030435A93F867C38`.

The same executable without `-cof-pmove-legacy` fails during
`SV_InitClientMove`: the original DLL reads at RVA `0x6288`, with a null-near
read at address `0x8`. With the opt-in PMove adapter, startup passes that
helper, loads `c_intro`, builds PHS, and reaches map entity spawning before a
second fault.

## Verified entvars shift

The corrected PE-aware descriptor parse now corroborates the boundary: the
first named shift follows `light_level` (`sequence` is `0x12C` in the original
table versus `0x128` in current Xash), and later records include `health` at
`0x164` versus `0x160` and `iuser1` at `0x248` versus `0x244`. See the
[concise descriptor analysis](entvars-layout-analysis.md) and the
[project parser](../../scripts/parse-entvars-descriptors.ps1). The table proves a
four-byte shifted range; it does not identify the omitted engine-only member.

The `pfnPvAllocEntPrivateData` trace below is retained as evidence from the
earlier PMove-only adapter binary. It is not a result of the opt-in entvars
profile; the corrected profile run is recorded in
[dedicated-profile-test.md](dedicated-profile-test.md).

The adapter run's second dump records `0xC0000005` at
`pfnPvAllocEntPrivateData` (`sv_game.c:2932`) with a write to `0x7C`. The
faulting bytes are `89 46 7C` and `ESI=0`. At the fault's stack, the callback
arguments are `pEdict=0` and `cb=0x500`.

The copied `hl.dll` base in that dump is `0x5AF00000`, so the callback return
address `0x5B02049E` is RVA `0x12049E`. Its existing disassembly at preferred
address `0x10120460` shows this call sequence:

```text
mov esi,[ebp+8]
...
mov ecx,[esi+0x20C]
...
push 0x500
push ecx
call [0x10223044]       ; engine pfnPvAllocEntPrivateData
```

DIA symbols from the runtime's matching Xash PDB report:

```text
entvars_s::pContainingEntity  0x208
entvars_s::playerclass        0x20C
```

Therefore the shipped DLL reads `pContainingEntity` four bytes later than the
current engine places it. It sees the zero `playerclass` field and passes a
null edict pointer, explaining the write fault in the engine allocator.

The disassembly contains numerous accesses to the surrounding legacy entity
state, including offsets through `0x204`, but this map-spawn trace is the
first one directly tied to a verified engine callback and identifies the
`pContainingEntity` boundary at `0x208/0x20C`. The dump alone does not justify
skipping allocation or treating the null callback argument as valid behavior.

This checkpoint proves progress beyond the PM_Init mismatch only. It does not
prove client loading, rendering, menu, save/load, or Steam Play launch.
