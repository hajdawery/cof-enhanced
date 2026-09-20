# Client PMove adapter checkpoint

The client adapter is in `engine/client/dll_int/cl_pmove.c` and is distributed
as `patches/cof-client-pmove-legacy.patch`. It is enabled only by
`-cof-pmove-legacy`. A persistent aligned `playermove_t` buffer inserts four
bytes immediately before `physinfo`; the native engine object remains in use
and is synchronized around `HUD_PlayerMoveInit` and `HUD_PlayerMove`. The
`HUD_PostRunCmd` callback is unchanged because it has no `playermove_t`
argument.

Apply the server adapter first, then the client adapter helper, to a clean
ignored source copy:

```powershell
pwsh -File .\scripts\apply-pmove-adapter.ps1 `
  -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
pwsh -File .\scripts\apply-cof-client-pmove-profile.ps1 `
  -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

The helpers verify source markers after applying and reverse-check the patch;
an exit code alone is not evidence that a patch changed the source.

The corrected client build used the separate Waf output
`build-cof-client-corrected`, with `CLIENT=True`, `LAUNCHER=True`,
`XASH_COF_ENTVARS_LEGACY=1`, and no `XASH_DEDICATED` define. The complete
build finished 525/525 after a clean rebuild. The engine PDB query on the
deployed `xash.pdb` reports `edict_s size=812 (0x32C)`, `pvPrivateData=0x7C`,
`v=0x80`, and `cof_legacy_edict_tail=0x328`.

The deployed engine hash is:

```
65ACDEA266B66E7FFA44B15281B97C9938C63069E81411D84F9A5C6C00E79FAE  xash.dll
```

The other matched client components were copied from the same build output:
`xash3d.exe`, `ref_gl.dll`, `menu.dll`, `vgui.dll`, and
`filesystem_stdio.dll`. The runtime is the isolated directory
`stage1/launch-proof/client-runtime-corrected`; the original installation was
not modified.

For the bounded no-map test, the command was:

```
xash3d.exe -game cryoffear -dev 2 -cof-pmove-legacy -minidumps -log client-startup-clientpmove-adapter-812.log -console -ref gl -windowed -width 800 -height 600
```

The process-local second-chance helper ran for 15 seconds without an
exception event, then the helper and target were stopped. The log is
`stage1/launch-proof/client-runtime-corrected/client-startup-clientpmove-adapter-812.log`.
It records renderer initialization, `UI_LoadProgs` extended Menu API
initialization, `VGui_LoadProgs`, client hull setup, automatic spawn of
`c_game_menu1` despite no map argument, `VidInit`, and OpenGL texture uploads.
This is textual startup/menu evidence; it is not a visual screenshot. The log
also retains pre-existing asset/config warnings such as the missing
`is_donator` delta field and missing `overviews/c_game_menu1.txt`.

The same verified runtime completed a bounded `+map c_intro` run. The log
`stage1/launch-proof/client-runtime-corrected/client-startup-clientpmove-adapter-812-c_intro.log`
records `Spawn Server: c_intro`, `loading maps/c_intro.bsp`, level load at
about 1.03 seconds, client connection, renderer initialization, and no
second-chance exception during the bounded run.

Save/load was exercised in the isolated copy. A temporary map load config
issued `save luna_stage1` after the player became active; it was removed after
the test. The resulting `cryoffear/SAVE/luna_stage1.sav` was 158804 bytes
(SHA256 `0804FEE0063A9D260204FF1B1ACE6F85022CBEA63B2ECEC0BB1549E5ACB7428D`).
A second bounded run with `+load luna_stage1` logged `Loading game from
save/luna_stage1.sav`, spawned `c_intro`, loaded the BSP, reached level load,
and connected the client without a captured second-chance exception. The save
and logs are test artifacts in the isolated runtime and are excluded from the
repository checkpoint.

It does not prove Steam launch.
