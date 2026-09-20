# Dedicated CoF entvars profile test

This is a bounded diagnostic result for the opt-in entvars profile. It is not
a gameplay or release result.

The profile was built from FWGS commit
`4857b389e6ba32ddaa68582aedcbc950c138f46a` with
`--enable-cof-entvars-legacy`, which exports
`XASH_COF_ENTVARS_LEGACY=1` to all engine compilation units. The executable
used for the corrected run is the dedicated `build-cof-entvars` output:

```text
SHA-256 xash.exe: 7635C6DBF44D18498AE43255C7528B3502979E69915AD0D7D5FAFFFA3CA42051
SHA-256 xash.pdb: 75B961F0A7E0FD7FFA83C981A9E92626D6C5147B6BC576CE8B2777B65FC6AA99
```

The private runtime copy was
`runtime-entvars-profile`. Its manifest records the source paths, hashes, and
runtime flags. The run used `-cof-pmove-legacy +map c_intro` with the local
`crash-capture.exe` helper. The helper's target PID was 30536. The private
copy was corrected after an initial deployment accidentally copied the older
PMove-only executable (`75EF27E...`); that earlier evidence is kept under
`invalid-old-adapter-evidence` and is not part of this result.

The corrected profile loaded the game DLL, enabled the PMove adapter, loaded
`c_intro`, built PHS, and passed the earlier `pfnPvAllocEntPrivateData(NULL)`
failure. The next first-chance exception was in the original `hl.dll` at RVA
`0x1EA1D`. The API table and disassembly identify this code as
`pfnServerActivate` (API slot 21). It iterates the entity list, checks
`edict + 0x7C` (`pvPrivateData`), and then faults at `mov eax,[ecx+4]` after
loading that pointer. This establishes a new callback-stage diagnostic
blocker; it does not by itself establish whether the private-data access is a
second ABI mismatch or a game-specific assumption.

The capture helper stops at a first-chance exception. Therefore this run is
not proof of an unhandled crash or playable map. No client, renderer, menu,
or gameplay claim follows from it.
