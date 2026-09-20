# Steam-compatible launcher prototype

This is a reviewable launcher proof for the Stage 1 compatibility build. It does not modify a Steam installation and is not a Steam Play result.

## Launcher contract

`launcher/cof_launch.cpp` resolves the directory containing `CoFLaunchApp.exe`, sets `XASH3D_BASEDIR` and the process current directory to that directory, loads the colocated `xash.dll`, and invokes its exported `Host_Main(int, char**, const char*, int, pfnChangeGame)`. Caller supplied `-game` and `-cof-pmove-legacy` arguments are removed; the launcher appends `-game cryoffear -cof-pmove-legacy` and preserves other arguments. This uses FWGS's supported root and game selection interfaces and avoids developer checkout paths. The colocated root remains the engine's DLL search directory, so ordinary Windows DLL resolution applies to all files in that root.

Build the x86 launcher with the pinned local VS2022 toolchain:

```powershell
.\scripts\build-cof-launcher.ps1
```

The script discovers the Visual Studio installation with `vswhere` or `VSINSTALLDIR`; pass `-VcVarsPath` when neither is available. The output is `build-launcher\\CoFLaunchApp.exe` (SHA256 `7B3FD518F10A780EDA6932934AF619C1241FDB852B362943F4737DF20DC086A9`). Existing binary ignore rules exclude the output.

## Isolated proof package

The proof used a fresh complete vanilla-layout copy under `stage1/launch-prototype-20260920`. Its baseline was an isolated copy of the original game root. The following overlay was then applied; files marked “replace” were present in the baseline, and “add” files were absent there.

| Relative path | Operation | SHA256 |
| --- | --- | --- |
| `CoFLaunchApp.exe` | replace | `7B3FD518F10A780EDA6932934AF619C1241FDB852B362943F4737DF20DC086A9` |
| `xash.dll` | add | `65ACDEA266B66E7FFA44B15281B97C9938C63069E81411D84F9A5C6C00E79FAE` |
| `FileSystem_Stdio.dll` (same Windows path as `filesystem_stdio.dll`) | replace | `D7594A89C326E747AD23D54013E60EADA605090A091EF0641756D4A47992C2CF` |
| `SDL2.dll` | add | `68C78590D1997122C30C992EC79857D32E5E976A0F17C0A69A2E29EAB0101D70` |
| `menu.dll` | add | `EE426DA222D6D5E995A514A5D8B104D47114A292C4C1FCBEBF6F0AE343A1DB68` |
| `ref_gl.dll` | add | `F3B1D4B9F3C2237C50447D956EE43070B22BF578C9E15CD0ED67D30B30E6F172` |
| `vgui.dll` | replace | `B839D47942F0AF487F12D433D3EBEC8628788C5C436E3254900EB7BE6D9775A74` |
| `cryoffear\\cl_dlls\\client.dll` | retain baseline; no overlay write | `D2A04641B301804F6F449AA68265042B13ADC360925B80033D417EC9F38C9C00` |
| `cryoffear\\cl_dlls\\hl.dll` | retain baseline; no overlay write | `0036B91C01E92ED205513F52563053A55A66A32D257EFB5F476B8F1F3DDE0E63` |
| `cryoffear\\gameinfo.txt` | add | `6EEA04D3455DCB4D3FB43C6EDC8706189F6BFC0D65718C212E7C9FDE38C17E23` |
| `opengl32.dll` | retain baseline; no overlay write | — |

The colocated layout is required because the Windows loader resolves the engine's SDL and renderer dependencies beside `xash.dll`, while the engine resolves the game modules through the root's `cryoffear` directory. The original root `opengl32.dll`, Steam runtime files, and game assets were retained in the isolated copy. No modified game DLL or cheat pack was used. The two spellings of `filesystem_stdio.dll` above are one case-insensitive Windows destination; they must not be treated as separate files.

## Proof result

Two process-local second-chance wrapper runs were made from the isolated root. The no-argument smoke run stayed alive for approximately 25 seconds without producing a dump. A logged menu run stayed alive for 12 seconds and produced `launcher-menu.log` (226855 bytes) with:

- `Program args: CoFLaunchApp.exe ... -game cryoffear -cof-pmove-legacy`;
- successful `filesystem_stdio` initialization;
- `Dll loaded for game "Cry of Fear"`;
- both server and client legacy playermove adapter warnings;
- `ref_gl.dll` renderer initialization and extended menu API initialization;
- `Spawn Server: c_game_menu1` and successful map load.

The process was then stopped by its recorded launcher PID. No launcher or engine process remains, and no `crash-capture-secondchance.dmp` was created. The log contains repeated `GL_INVALID_VALUE` diagnostics from the existing renderer path and an `is_donator` delta-field warning; these did not terminate the process and are retained as runtime limitations. This proof covers launcher, root selection, module loading, and menu background startup. It does not claim `c_intro` gameplay, Steam Play, or release readiness.

## Rollback

For a test root, remove the overlay files listed above. The untouched isolated baseline copy is the restoration source for replaced files; original assets and DLLs outside the test root are not modified. The real Steam installation and Steam configuration remain untouched.

## Proposed real-Steam file change list

No real-Steam change has been performed. If a later, separately approved test
uses the Steam game root, the proposed relative changes are exactly the table
above: replace `CoFLaunchApp.exe`, `FileSystem_Stdio.dll`, and `vgui.dll`; add
`xash.dll`, `SDL2.dll`, `menu.dll`, `ref_gl.dll`, and
`cryoffear\\gameinfo.txt`. The original
`cryoffear\\cl_dlls\\client.dll` and `cryoffear\\cl_dlls\\hl.dll` already
match the tested baseline and remain untouched. `opengl32.dll`, Steam runtime
files, and all game assets remain unchanged. The Windows case-insensitive
`FileSystem_Stdio.dll` destination must be backed up once under its existing spelling
before replacement.

Rollback would stop the launcher and engine, restore each replaced file from
its pre-change backup, remove each added file, and restore or remove
`cryoffear\\gameinfo.txt` according to its pre-change state. A failed or
cancelled test would leave the backup set available for this exact reversal;
no Steam write is authorized by this prototype document.
