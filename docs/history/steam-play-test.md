# Temporary Steam launch test

> **Historical record (2026-09-20/21).** Kept for its evidence. Its open questions
> and "next gate" lists were resolved by later work; see [engine and game facts](engine-and-game-facts.md)
> and [milestones](milestones.md) for the current state.

Test date: 2026-09-20. The test used the user-approved temporary overlay in the installed Steam root. The installation was restored before this report was written.

The launch request was issued through Steam's app IPC with `-applaunch 223710`. This was a command-line Steam launch, rather than a simulated click on the Play button. The resulting game process proves the Steam parent/child launch edge:

- Steam parent: the running `steam.exe` process;
- child: `CoFLaunchApp.exe` from the installed Cry of Fear game root;
- child command line: the launcher executable with no additional arguments;
- window title observed: `Cry of Fear`;
- user observation during the bounded run: the main menu appeared.

The child loaded the reviewed root-colocated prototype modules, including `xash.dll`, `SDL2.dll`, `filesystem_stdio.dll`, `ref_gl.dll`, `menu.dll`, and `vgui.dll`. The preserved original CoF `client.dll` and `hl.dll` were also loaded. The exact prototype hashes were:

| file | SHA-256 |
|---|---|
| `CoFLaunchApp.exe` | `7B3FD518F10A780EDA6932934AF619C1241FDB852B362943F4737DF20DC086A9` |
| `xash.dll` | `65ACDEA266B66E7FFA44B15281B97C9938C63069E81411D84F9A5C6C00E79FAE` |
| `FileSystem_Stdio.dll` | `D7594A89C326E747AD23D54013E60EADA605090A091EF0641756D4A47992C2CF` |
| `SDL2.dll` | `68C78590D1997122C30C992EC79857D32E5E976A0F17C0A69A2E29EAB0101D70` |
| `menu.dll` | `EE426DA222D6D5E995A514A5D8B104D47114A292C4C1FCBEBF6F0AE343A1DB68` |
| `ref_gl.dll` | `F3B1D4B9F3C2237C50447D956EE43070B22BF578C9E15CD0ED67D30B30E6F172` |
| `vgui.dll` | `B839D47942F0AF487F12D433D3EBEC862878C5C436E3254900EB7BE6D9775A74` |
| `cryoffear/gameinfo.txt` | `6EEA04D3455DCB4D3FB43C6EDC8706189F6BFC0D65718C212E7C9FDE38C17E23` |

The bounded run was stopped after module and menu evidence was captured. No campaign map, gameplay, save, or Steam Play-button test was attempted in this live-install run.

## Rollback

The baseline backup and machine-readable evidence remain under a local,
ignored test directory outside the repository.

- The original `CoFLaunchApp.exe`, `FileSystem_Stdio.dll`, and `vgui.dll` were restored and their hashes match the pre-test manifest.
- Added `xash.dll`, `SDL2.dll`, `menu.dll`, `ref_gl.dll`, and `cryoffear/gameinfo.txt` were removed.
- Original `cryoffear/cl_dlls/client.dll` (`D2A04641B301804F6F449AA68265042B13ADC360925B80033D417EC9F38C9C00`) and `hl.dll` (`0036B91C01E92ED205513F52563053A55A66A32D257EFB5F476B8F1F3DDE0E63`) were retained and verified unchanged.
- Root and game configs were restored byte-for-byte.
- Both save directories were compared against the backup; all original files match and no extra save files remained.
- The test-created `cryoffear/.xash_id` was removed.
- No CoF/Xash process remained after cleanup. The pre-existing Steam client was left running.

This establishes a Steam-parented launch and a visible main menu for the reviewed prototype. It does not establish visual parity, campaign playability, save/load behavior through Steam, or compatibility with the unattributed cheat DLL pack.
