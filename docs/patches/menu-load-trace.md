# CoF menu-load dispatch trace

The optional `patches/cof-menu-load-trace.patch` adds the diagnostic cvar
`cof_trace_menu_load`, defaulting to `0`. The patch does not forward commands,
change save handling, or accept commands that the engine would otherwise
reject. Apply it after the existing PMove, entvars, and edict compatibility
profiles with:

```powershell
.\scripts\apply-cof-menu-load-trace.ps1 `
  -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

Build the client engine in a separate Waf output. The verified diagnostic
checkpoint used:

```text
Output: xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a\build-cof-trace-client\engine\xash.dll
SHA-256: 6E9A03CEEE2FDE7A8282ABD657117635EB8F880F279309F519E8D8965264D6C2
PDB:     7BFE4AC6A2677EB9A04A8F19DD564EF6FA7740207C153756DDD0F361E92AA354
Defines: XASH_COF_ENTVARS_LEGACY=1, XASH_REF_GL_ENABLED=1, XASH_SDL=2
         XASH_DEDICATED is undefined
```

Set `cof_trace_menu_load 1` in the isolated test copy. The trace is restricted
to the known Cry of Fear path:

* `forward cofload N` and a not-connected rejection identify local command
  forwarding;
* `clc_stringcmd cofload packet` identifies a received client packet;
* `server received cofload N` and `hl ClientCommand returned` bracket the
  original DLL `ClientCommand` callback;
* `hl pfnServerCommand: load cofsaveN` identifies the DLL-originated load;
* `SV_LoadGame entry`, a specific rejection reason, or `load accepted: map=...`
  identifies save-loader progress.

This is a source/build diagnostic checkpoint. The related investigation records
one command-equivalent stock-save acceptance after the save is placed in the
engine's game-directory path, but this trace alone makes no GUI, clean-render,
gameplay, or visual-parity claim.
