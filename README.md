# cof-fix

This repository contains a bounded, opt-in experiment for the original Steam Cry of Fear server DLL on FWGS Xash3D.

The tested engine source is FWGS commit `4857b389e6ba32ddaa68582aedcbc950c138f46a`. The launch dump proves that the original DLL expects `physinfo` and the common playermove callbacks four bytes later than the current engine's `playermove_t`: the current table has `PM_Info_ValueForKey` at `+0x4F554`, while the original PM_Init helper reads its two-argument callback at `+0x4F558`. See [the adapter note](docs/pmove-adapter.md), which records the bounded runtime checkpoints and remaining ABI failure.

`patches/cof-pmove-legacy.patch` adds an experimental `-cof-pmove-legacy` engine option. It copies the native playermove object into a persistent four-byte-shifted view for the original DLL's PM_Init and PM_Move calls, then copies state back. The engine keeps its native object and callback implementations. The adapter is a diagnostic candidate: the historical missing field is not identified and this is not a release compatibility claim.

The repo intentionally contains no game files, Steam DLLs, runtime archives, dumps, or built binaries. Build output belongs in the ignored source/build directories.

## Applying the patch

Use a clean checkout or extracted archive of the pinned FWGS revision and run:

```powershell
pwsh -File .\scripts\apply-pmove-adapter.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

The source tree must be inside this repository because the script scopes patch application to the project workspace. The script verifies `engine/server/sv_pmove.c` and applies the one-file patch. It refuses a source tree whose file already contains the adapter; rerun it with a clean pinned source tree instead of attempting a duplicate patch.

The upstream Windows build requires the recursive dependencies and an SDL2 Visual Studio development package for a client build. The isolated client build attempt used the official SDL2 `2.30.9-VC` package (SHA-256 `8C91D91E5BCB997D062EC2B553C53832EBF95654D4AA35E8C02A954D4CE752AE`). Visual Studio 2022 BuildTools with Win32 tools and Windows SDK 10.0.26100 are installed on the research host. A dedicated x86 compile of the patched source completed locally; this repository does not provide a dependency lockfile or reproducible build script, and that artifact is not committed.
