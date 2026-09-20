# cof-fix

This repository contains a bounded, opt-in experiment for the original Steam Cry of Fear server and client DLLs on FWGS Xash3D.

The tested engine source is FWGS commit `4857b389e6ba32ddaa68582aedcbc950c138f46a`. The launch dump proves that the original DLL expects `physinfo` and the common playermove callbacks four bytes later than the current engine's `playermove_t`: the current table has `PM_Info_ValueForKey` at `+0x4F554`, while the original PM_Init helper reads its two-argument callback at `+0x4F558`. See [the adapter note](docs/pmove-adapter.md), which records the bounded runtime checkpoints and remaining ABI failure.

`patches/cof-pmove-legacy.patch` adds an experimental `-cof-pmove-legacy` engine option. It copies the native playermove object into a persistent four-byte-shifted view for the original DLL's PM_Init and PM_Move calls, then copies state back. The matching client overlay in `patches/cof-client-pmove-legacy.patch` translates the client DLL's two playermove entrypoints. The entvars and edict overlays are separately opt-in and documented in [the dedicated profile report](docs/dedicated-profile-test.md) and [the stride proposal](docs/edict-stride-proposal.md). These are diagnostic candidates: the historical missing fields are not identified and this is not a release compatibility claim.

The corrected client checkpoint initialized the renderer, menu, and VGUI, loaded `c_intro`, and completed bounded save/load smoke tests with no captured second-chance exception. The save preview was nonblank. This does not establish visual parity, human gameplay, campaign completeness, or Steam Play launch behavior; see [the client startup report](docs/client-pmove-adapter-test.md) and [the campaign/save-load report](docs/campaign-save-load-test.md).

The repo intentionally contains no game files, Steam DLLs, runtime archives, dumps, or built binaries. Build output belongs in the ignored source/build directories.

## Applying the patch

Use a clean checkout or extracted archive of the pinned FWGS revision and run:

```powershell
pwsh -File .\scripts\apply-pmove-adapter.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

For the complete client profile, apply the server adapter first, then the client adapter, entvars profile, and edict stride overlay with their ordered helpers:

```powershell
pwsh -File .\scripts\apply-cof-client-pmove-profile.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
pwsh -File .\scripts\apply-cof-entvars-profile.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
pwsh -File .\scripts\apply-cof-edict-stride-profile.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

The source tree must be inside this repository because the scripts scope patch application to the project workspace. Each helper checks concrete source markers after applying and reverse-checks the patch; a successful process exit alone is not evidence that the source changed. They refuse duplicate application and leave generated build output in ignored source/build directories.

The upstream Windows build requires the recursive dependencies and an SDL2 Visual Studio development package for a client build. The isolated client build attempt used the official SDL2 `2.30.9-VC` package (SHA-256 `8C91D91E5BCB997D062EC2B553C53832EBF95654D4AA35E8C02A954D4CE752AE`). Visual Studio 2022 BuildTools with Win32 tools and Windows SDK 10.0.26100 are installed on the research host. A dedicated x86 compile of the patched source completed locally; this repository does not provide a dependency lockfile or reproducible build script, and that artifact is not committed.
