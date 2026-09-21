# Video mode changes and the Cry of Fear menu scene (`cof_vid_restart_background`)

Changing the resolution or toggling fullscreen from the main menu used to strip
the Cry of Fear background scene: the custom sky, the atmosphere and the snow
disappeared and the map's plain `blue22` skybox was left behind. Reloading the
map restored everything. This patch restores the scene automatically.

Two cvars, both deliberately **not** `FCVAR_ARCHIVE` so an old `config.cfg`
cannot pin them:

| cvar | default | effect |
| --- | --- | --- |
| `cof_vid_restart_background` | `1` | after a completed mode change, restart the background map so the client's per-level init reruns |
| `cof_vid_skip_redundant_vidinit` | `0` | on a mode change that does not change the render size, skip the client `pfnVidInit` call entirely |

## Why the scene is lost

FWGS keeps the GL context across a mode change. `R_ChangeDisplaySettings()`
only resizes or re-flags the SDL window; no texture, sprite or font is lost.
What the engine does do is call `SCR_VidInit()`
(`engine/client/cl_scrn.c:902`), which ends with

```c
if( gameui.hInstance ) gameui.dllFuncs.pfnVidInit();
if( clgame.hInstance ) clgame.dllFuncs.pfnVidInit();
```

For Cry of Fear `pfnVidInit` is `HUD_VidInit`, and in this client that is a
**per-level** entry point, not a "the screen got bigger" callback. It rebuilds
the screen-sized state *and* resets the one-shot state the map established at
spawn. The measured signature in the log is the client re-reading the map's
detail-texture list right after the mode change:

```
VID_SetScreenResolution: Setting video mode to 1280x720 windowed
No detail textures file maps/c_game_menu1_detail.txt
```

Nothing replays what the server sent once at spawn. `Sending enabling rain
message` - the snow - appears exactly once per level load and is never resent,
so after `HUD_VidInit` the client has a reset weather/sky state and no way back.
The map's own `blue22` skybox is what remains visible.

(Evidence for the pre-patch behaviour: `stage1/vidmode-switch-qa-20260921`,
cases A, B, D and E.)

## The two call sites

`SCR_VidInit()` is reached from exactly two places in the mode-change path, and
which one fires depends on whether the render size actually changed:

| path | what happens |
| --- | --- |
| `vid_setmode W H` -> `VID_Mode_f` -> `R_ChangeDisplaySettings` -> `VID_SetScreenResolution` -> `VID_SaveWindowSize` -> `R_SaveVideoMode` | `R_SaveVideoMode` returns early unless `refState.width/height` changed, so `SCR_VidInit()` runs once, on a real resize. It also clears `host.renderinfo_changed`, so `VID_CheckChanges` does not fire afterwards. |
| `fullscreen 0/1` (any `FCVAR_VIDRESTART` cvar) -> `host.renderinfo_changed` -> `VID_CheckChanges` -> `VID_SetMode` | at an unchanged resolution `R_SaveVideoMode` returns early, so the `SCR_VidInit()` in `VID_CheckChanges` is the **only** one - and it is redundant, because nothing screen-sized moved. |

Both call `CL_CoF_VidModeChanged()` immediately after `SCR_VidInit()`. A
resolution change that also crosses a window mode reaches the hook twice; a
pending-restart flag makes the second call a no-op.

## What the patch does

`CL_CoF_VidModeChanged()` (`engine/client/cl_main.c`):

* `cls.state != ca_active` - nothing is loaded, or a level change is already
  running: clear the pending flag and do nothing.
* `cls.demoplayback` - startup demos and demo playback own their own level
  flow: do nothing.
* `!cl.background` - **a real game is in progress**. A reload would throw the
  session away, so the engine only reports it once, at developer level:
  `[cof-vid] video mode changed during a live game: the client's per-level setup
  is not rebuilt (map "c_forest3")`. This is the documented hook for a later fix
  (the client would have to be told to replay its per-level setup); the user has
  accepted that in-game video changes stay as they are for now.
* otherwise, with `cof_vid_restart_background` on, print
  `[cof-vid] restarting background map "<map>" after a video mode change` and
  `Cbuf_AddTextf( "map_background %s\n", clgame.mapname )`.

`map_background` is the same command `mainui`'s `UI_StartBackGroundMap` issues
(`3rdparty/mainui/BaseMenu.cpp:580`), and `SV_MapBackground_f` explicitly allows
it while a background map is already active. Going through the command buffer
means the reload starts at the next `Cbuf_Execute` rather than inside the video
code, and `SV_SpawnServer` then resends the level's messages, so the client's
per-level init runs in full. `cl.background` stays `1` across the reload, so the
engine menu keeps its place over the live scene.

`CL_CoF_VidRestartForget()` clears the pending flag from `CL_ClearState()`, so a
restart that never reached the server (an invalid map name, a level load that
was overtaken) cannot latch the guard on for the rest of the session.

### `cof_vid_skip_redundant_vidinit` (default `0`, off)

`VID_CheckChanges` compares `refState.width/height` before and after
`VID_SetMode()`. When they are unchanged and this cvar is on, the client
`pfnVidInit` is not called at all and the engine reports

```
[cof-vid] skipped the redundant client VidInit: render size unchanged (1920x1080)
```

Nothing then needs rebuilding and no map is reloaded. Measured on 2026-09-21
(`w4-fullscreen-skipvidinit`): a `fullscreen 1` / `fullscreen 0` pair at
1920x1080 produced two skip lines, **one** `Spawn Server`, and a scene with the
custom sky, the snow and the skyline fully intact. It is the cheaper and less
disruptive repair for that case.

It ships **off** because the argument for it is a code-review argument, not an
exhaustive measurement:

* `R_ChangeDisplaySettings` in `engine/platform/sdl2/vid_sdl2.c` never destroys
  the GL context when `host.hWnd` already exists; it only calls
  `VID_SetScreenResolution`, so textures, sprites and fonts stay valid;
* everything `SCR_VidInit()` does is either screen-size dependent
  (`gameui.globals->scrWidth/scrHeight`, `VGui_Startup`, `Con_VidInit`,
  `Touch_NotifyResize`) or a texture re-registration
  (`CL_ClearSpriteTextures`, `Con_LoadConchars`), and at an unchanged size none
  of it has anything to do;
* but it was only exercised on this SDL2/Windows/`ref_gl` path, with this
  client. A backend that *does* recreate the context on a fullscreen toggle
  would lose its textures with the skip on. `vid_scale` and `vid_rotate` are
  also `FCVAR_VIDRESTART` and do change `refState.width/height`, so they take
  the normal path, but a future transform that changes rendering without
  changing those two numbers would be missed.

Turn it on to compare, or leave it off and let `cof_vid_restart_background`
handle the toggle with a reload.

## Validation

Fixture `stage1/ui-m1-engine-fixture-20260921` in the milestone-1 configuration
(engine menu over the `c_game_menu1` background map). Build
`build-cof-ui-m1-engine-20260921`, `engine/xash.dll` SHA-256
`DC200932C8189C0E787CFB1750EBDC1CDC1A2CACEB7635B4078F3884D08F0786`.
Every launch windowed, `+volume 0`, `-dev 2`, `+set developer 2`.

No keystrokes are typed in these runs. Commands come from the command line,
from a cfg it `exec`s, and from `maps/c_game_menu1_load.cfg`, which
`SV_SpawnServer` runs on every load of the map
(`engine/server/sv_init.c:971`) and which is therefore the "the map is up"
event the case scripts step on. The only key event sent is a single `Escape`,
after `GetForegroundWindow` confirmed the engine owns the foreground.
Driver: `stage1/ui-m1-engine-fixture-20260921/run-vidmode-cfg-case.ps1`.

| Run | Configuration | Result |
| --- | --- | --- |
| `w1-vidsetmode-on` | 1920x1080, `vid_setmode 1280 720` | `[cof-vid] restarting background map "c_game_menu1"`, one extra `Spawn Server`, `Sending enabling rain message` again; `-b.png` and `-c.png` show the custom sky, the snow and the skyline |
| `w2-vidsetmode-off` | same with `cof_vid_restart_background 0` | the bug, reproduced in the same binary: no restart, `-b.png` is the flat `blue22` gradient with no snow and no cloud detail |
| `w3-fullscreen-toggle-on` | 1920x1080, `fullscreen 1` then `fullscreen 0` | a restart after each toggle, three `Spawn Server` in total, scene intact in `-b`, `-c` and `-d` |
| `w4-fullscreen-skipvidinit` | same toggle with `cof_vid_skip_redundant_vidinit 1` | two `skipped the redundant client VidInit` lines, **one** `Spawn Server`, scene intact |
| `w5-ingame-vidsetmode` | `+load cofsave1` (map `c_forest3`), then `vid_setmode 1280 720` | one `Spawn Server`, no reload, the live-game notice printed and visible on screen |
| `w6-ingame-menu-escape` | same, then `menu_main` and one real `Escape` | `input gate engaged (key_dest=2)` then `released (key_dest=1)`, still one `Spawn Server`: the engine menu opens and closes normally after the change |

The screenshots are night scenes; the evidence folder also holds a `.bright.png`
of each (linear x6) because the difference is invisible at the original
exposure. The channel means are a usable signature on their own: with the scene
intact the red mean exceeds the blue mean (grey-green overcast sky), with the
`blue22` skybox showing through the blue mean is the highest.

`menu_main` after the change was exercised in `w1` (`-c.png`), `w3` (`-d.png`)
and `w6` (`-b.png`); `Escape` closing the menu was exercised in `w6`.

The canonical tree `K:\LLM\COF_Fix\Cry of Fear` was manifested before and after
the runs (`evidence/canonical-vidfix-before.txt`,
`evidence/canonical-vidfix-after.txt`): 6197 files, newest write
2026-09-18T20:33:58Z, unchanged.

## Risks and limits

* The background map really is reloaded. It is a full `SV_SpawnServer`, about a
  second in this fixture, and the engine menu is redrawn over it afterwards.
  Anything the menu had scrolled to survives, because the menu itself is not
  reset, but the scene restarts from its first frame.
* A user who changes resolution and window mode in one step gets **one**
  reload, not two - but if a video options page applies several
  `FCVAR_VIDRESTART` cvars in separate frames, each completed mode change is one
  reload. Batching them is the mainui side's job.
* `clgame.mapname` is the client's copy of the server's map name. If a mod runs
  a background map whose name the client never receives, the hook does nothing
  (guarded by `COM_StringEmpty`).
* The live-game case is deliberately not fixed. The notice is the hook; the real
  repair needs the client to replay its per-level setup without a level change,
  which this engine has no callback for.
* `cof_vid_skip_redundant_vidinit` is off by default for the reasons listed
  above. It was not tested on any backend other than SDL2 + `ref_gl` on Windows.
* Not measured: a mode change while a background map is mid-load, and a mode
  change during demo playback (both are early-returned, by code review only).

## Applying

Apply after `scripts\apply-cof-ui-input-gate.ps1`; the script refuses a tree
that does not already carry the gate, because the patch's hunk context is the
gate's own cvar block.

```powershell
pwsh -File .\scripts\apply-cof-vid-restart-background.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

The script refuses a tree that already has the change, verifies concrete
markers in all three touched files afterwards, and reverse-checks the patch.
Verified on 2026-09-21 against `cof-fix\pristine-ui-m1-scratch` with the
input-gate patch applied first: apply, byte-identical result to the build tree,
and clean reverse.
