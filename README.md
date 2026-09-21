# cof-fix

<img src="assets/branding/coffix.png" alt="COF Fix emblem" width="180">

This repository contains a bounded, opt-in experiment for the original Steam Cry of Fear server and client DLLs on FWGS Xash3D.

The tested engine source is FWGS commit `4857b389e6ba32ddaa68582aedcbc950c138f46a`. The launch dump proves that the original DLL expects `physinfo` and the common playermove callbacks four bytes later than the current engine's `playermove_t`: the current table has `PM_Info_ValueForKey` at `+0x4F554`, while the original PM_Init helper reads its two-argument callback at `+0x4F558`. See [the adapter note](docs/pmove-adapter.md), which records the bounded runtime checkpoints and remaining ABI failure.

`patches/cof-pmove-legacy.patch` adds an experimental `-cof-pmove-legacy` engine option. It copies the native playermove object into a persistent four-byte-shifted view for the original DLL's PM_Init and PM_Move calls, then copies state back. The matching client overlay in `patches/cof-client-pmove-legacy.patch` translates the client DLL's two playermove entrypoints. The entvars and edict overlays are separately opt-in and documented in [the dedicated profile report](docs/dedicated-profile-test.md) and [the stride proposal](docs/edict-stride-proposal.md). These are diagnostic candidates: the historical missing fields are not identified and this is not a release compatibility claim.

The corrected client checkpoint initialized the renderer, menu, and VGUI, loaded `c_intro`, and completed bounded save/load smoke tests with no captured second-chance exception. The save preview was nonblank. This does not establish visual parity, human gameplay, campaign completeness, or Steam Play launch behavior; see [the client startup report](docs/client-pmove-adapter-test.md) and [the campaign/save-load report](docs/campaign-save-load-test.md).

The repo intentionally contains no game files, Steam DLLs, runtime archives, dumps, or built binaries. Build output belongs in the ignored source/build directories.

For reusable engine/game development lessons from this investigation, see the [Xash/GoldSrc developer notes](docs/xash-goldsrc-developer-notes.md).
For the detailed custom CoF UI ownership, coordinate-space, and scaling research, see [the custom UI scaling note](docs/cof-custom-ui-scaling-research.md).
For the disposable-runtime and per-run evidence policy used by isolated
runtime checks, see the [launcher fixture workflow](docs/steam-launch-prototype.md#reusable-fixture-workflow).

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

The optional CoF save-menu checkpoint has a separate ordered application. Apply
the existing menu-load trace prerequisite and root-save compatibility first,
then the pause list/comment plumbing, server menu backend, client tape-command
hook, and finally the nested MainUI files:

```powershell
pwsh -File .\scripts\apply-cof-menu-load-trace.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
pwsh -File .\scripts\apply-cof-save-root-compat.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
pwsh -File .\scripts\apply-cof-pause-save-plumbing.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
pwsh -File .\scripts\apply-cof-menu-save-backend.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
pwsh -File .\scripts\apply-cof-tape-save-command.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
pwsh -File .\scripts\apply-cof-mainui-menu-save.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

The menu backend and nested MainUI integration are both required for a GUI
save action. `cof_save_root_compat` remains an explicit runtime enablement;
`cof_pause_menu_saves` defaults to `0` and is the user's separate menu-save
choice. The implementation shares the original five slots and keeps the tape
save path separate. See [root-save compatibility](docs/cof-save-root-compat.md),
[pause plumbing](docs/cof-pause-save-plumbing.md),
[menu backend](docs/cof-menu-save-backend.md),
[tape command](docs/cof-tape-save-command.md), and
[MainUI integration](docs/cof-mainui-menu-save.md) for scope and validation
limits. These checkpoints are source/apply experiments; runtime menu-save
success and visual parity are not implied.

The renderer fix for the missing Cry of Fear main-menu skyline is applied after
the GL stage, solid-entity, and transparent-triangle trace patches:

```powershell
pwsh -File .\scripts\apply-cof-custom-renderfx-opaque.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

It restores GoldSrc's rule that `rendermode`-normal entities stay opaque
whatever their `renderfx` is, behind the `cof_custom_renderfx_opaque` cvar
(default `1`). See [custom renderfx opaque classification](docs/cof-custom-renderfx-opaque.md)
for the root cause, the measured evidence, and the validation.

Milestone 1 of the unified UI stack is the engine-side input and paint gate. It
is applied after the engine save/menu patches above; it is independent of the
`ref/gl` patches and may be applied before or after them:

```powershell
pwsh -File .\scripts\apply-cof-ui-input-gate.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

With `cof_ui_input_gate 1` (default) the Cry of Fear client neither paints its
VGUI/HUD layer nor receives keyboard and mouse input while the engine menu, the
console or the chat line has focus, and `Escape` always reaches `CL_Escape_f` so
the engine menu opens even while a CoF VGUI panel is up. Game focus is
unchanged. The patch also packages the previously untracked
`cof_skip_client_hud_redraw` and `cof_skip_vgui_paint` diagnostics (both default
`0`).

The same patch carries the sibling cvar `cof_ui_deferred_cmd_guard` (default
`1`). Cry of Fear's `HUD_Init` issues `map c_game_menu1` before the engine is
initialised, so the engine parks it in `host.deferred_cmd` and replays it the
first frame the engine menu becomes visible: from gameplay that threw the loaded
save away, and on a plain boot it replaced MainUI's `map_background` with a real
map. The guard drops that stale boot command instead and reports it once at
developer level. Setting the cvar to `0` restores the stock path and reproduces
both effects. See [unified UI input gate](docs/cof-ui-input-gate.md) for the
design, the disassembly and log evidence, and the limits.

The first milestone of the unified UI stack puts the engine menu on screen over
the live Cry of Fear scene. It is one small MainUI change plus game-directory
data files:

```powershell
pwsh -File .\scripts\apply-cof-mainui-background-scrim.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

The patch makes the in-game menu background a translucent scrim instead of an
opaque fill while `ui_renderworld` is on, behind the new `ui_scrim_alpha` cvar
(default `150`, `255` reproduces the previous behaviour). The data files that
go with it live in [`gamedata/`](gamedata/README.md), which is an overlay for a
runtime's `cryoffear/` folder and contains no game assets. See
[UI milestone 1 plumbing](docs/cof-ui-m1-plumbing.md) for what was verified,
the Cry of Fear menu-map command table, and the font-backend finding.

The upstream Windows build requires the recursive dependencies and an SDL2 Visual Studio development package for a client build. The isolated client build attempt used the official SDL2 `2.30.9-VC` package (SHA-256 `8C91D91E5BCB997D062EC2B553C53832EBF95654D4AA35E8C02A954D4CE752AE`). Visual Studio 2022 BuildTools with Win32 tools and Windows SDK 10.0.26100 are installed on the research host. A dedicated x86 compile of the patched source completed locally; this repository does not provide a dependency lockfile or reproducible build script, and that artifact is not committed.
