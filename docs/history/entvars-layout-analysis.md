# Cry of Fear entvars layout evidence

> **Historical record (2026-09-20/21).** Kept for its evidence. Its open questions
> and "next gate" lists were resolved by later work; see [engine and game facts](engine-and-game-facts.md)
> and [milestones](milestones.md) for the current state.

This note records the corrected, read-only descriptor parse and the matching
current Xash layout. It constrains the next experimental profile; it does not
claim a complete reconstruction of the original `entvars_t` declaration.

The project parser is [parse-entvars-descriptors.ps1](../../scripts/parse-entvars-descriptors.ps1).
It reads PE section metadata, translates the descriptor name pointers, and
parses 16-byte `TYPEDESCRIPTION` records as `{ fieldType, namePointer,
fieldOffset, fieldSizeAndFlags }`. It emits field metadata only and does not
write or copy the input binary.

The original table's first verified shifted named records are:

| Field | Original DLL descriptor | Current Xash layout | Difference |
| --- | ---: | ---: | ---: |
| `light_level` | `0x124` | `0x124` | none |
| `sequence` | `0x12C` | `0x128` | `+4` |
| `frame` | `0x134` | `0x130` | `+4` |
| `health` | `0x164` | `0x160` | `+4` |
| `iuser1` | `0x248` | `0x244` | `+4` |

The named descriptors continue to show the same four-byte shift through the
later user fields. The table omits engine-only members, so it proves the
boundary and shifted range without identifying the inserted member.

The separate runtime callback trace anchors the semantic field. Current Xash
symbols place `entvars_s::pContainingEntity` at `0x208` and
`entvars_s::playerclass` at `0x20C`; the original code reads the containing
entity at `+0x20C` before calling `pfnPvAllocEntPrivateData`. This explains the
observed null-edict allocation fault when the current layout is passed to the
legacy DLL. It does not justify skipping allocation or treating a null edict
as valid behavior.

The explicit four-byte legacy view inserted after `light_level` has now passed
the earlier private-data allocation fault in a dedicated diagnostic run. That
run stops at a first-chance exception later in the original server DLL; it does
not establish whether the private-data access is a second ABI mismatch or a
game-specific assumption. The evidence does not establish the identity of the
inserted slot, and it does not prove client loading, rendering, menu, VGUI,
save/load, or Steam launch.
