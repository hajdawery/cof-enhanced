# Field of view: `cof_fov` and `cof_viewmodel_fov`

> **Status (2026-09-22 docs pass):** the menu wiring this page asks for in its
> last section exists: FOV and viewmodel FOV sliders on the Video page
> ([UI theme](../design/ui-theme.md), "Field of view and viewmodel FOV on the Video page").

Two independent options, in two different binaries:

| cvar | lives in | flags | default | range | what it does |
|---|---|---|---|---|---|
| `cof_fov` | engine, `engine/client/cl_view.c` | `FCVAR_ARCHIVE` | `90` | 70..110 | the player's preferred **hip** field of view, as the 4:3-equivalent base value |
| `cof_fov_zoom_knee` | engine, `engine/client/cl_view.c` | none (developer) | `60` | 30..90 | the field of view the `cof_fov` offset has fully tapered out at |
| `cof_viewmodel_fov` | renderer, `ref/gl/gl_studio.c` | `FCVAR_GLCONFIG` | `0` | `0` = follow the world, else 55..90 | the field of view the **viewmodel pass alone** is drawn with |

Both are stored the way Cry of Fear stores its own 90 and the way Source stores
`fov_desired`: as the **4:3-equivalent base** value. FWGS still Hor+-corrects
them for a widescreen through `r_adjust_fov` (which stays `1` and is not an
option), so base 90 renders as 106.26 degrees horizontal at 16:9.

Patches: `patches/cof-fov.patch` (engine) and `patches/cof-viewmodel-fov.patch`
(`ref/gl`). Apply scripts: `scripts/apply-cof-fov.ps1`,
`scripts/apply-cof-viewmodel-fov.ps1`.

## Why a plain multiplier is not the option

The chain was disassembled and measured in
`stage1/fov-investigation-20260922/RESULTS.md`. In short:

* **`default_fov` does not exist in Cry of Fear.** The string is not in
  `client.dll` at all; the HL SDK cvar was replaced by a hard-coded `int 90`
  at VA `1018FEC0` (7 read sites, 0 write sites).
* The console `fov` command is forwarded to `hl.dll`, which answers
  `Unknown command: fov`. The `SetFOV` user message handler reads one byte and
  throws it away. FOV actually travels in the player's `vuser2[0]` entity-state
  field.
* `CHud::Think` picks `90` at the hip, `60` for the "zoom 2" state and `30` for
  the cinematic camera zoom, lerps `gHUD.m_flFOV` towards it, and
  `CHud::UpdateClientData` multiplies the result by the archived
  `cl_fovmultiplier` before writing `client_data_t.fov`. That is the only
  client -> engine FOV channel and it lands in `cl.local.scr_fov`.
* So a slider wired to `cl_fovmultiplier` rescales **every** FOV the game asks
  for. Measured: at multiplier 1.2222 the glock's ironsights go from base 50 to
  base 61, and scripted camera zooms scale with it too.

`cof_fov` is applied by the engine instead, after the client has had its say.

## The `cof_fov` formula

In `V_GetRefParams` (`engine/client/cl_view.c`), and nowhere else:

```
offset = bound( 70, cof_fov, 110 ) - 90
knee   = bound( 30, cof_fov_zoom_knee, 90 )
t      = bound( 0, ( requested - knee ) / ( 90 - knee ), 1 )
result = requested + offset * t

rvp->fov_x = bound( 10, result, 150 )
```

`requested` is `cl.local.scr_fov`, i.e. whatever the client asked for this
frame, `cl_fovmultiplier` already included. Only `rvp->fov_x` is written:
`cl.local.scr_fov`, the client's own `m_flFOV`, the mouse sensitivity the
client derives from it (`m_flFOV/90 * sensitivity * zoom_sensitivity_ratio`,
computed before the multiplier) and everything that gets saved are untouched.
The whole thing is gated on `GI->gamefolder == "cryoffear"`, like the rest of
the `cof_*` stack, and returns immediately when the offset is zero, so the
stock default is byte-identical to no patch at all.

The taper is the point. At the hip the client asks for 90 and gets the whole
offset. As it lerps down into a zoom the offset ramps out, and at or below the
knee it is gone, so the zoom keeps the framing its author chose. The default
knee 60 is Cry of Fear's own "zoom 2" constant and sits above every ironsights
value measured so far (the glock's is base 50), which is why ironsights come
out **pixel-identical** at every `cof_fov` (measured below). Set
`cof_fov_zoom_knee 30` for the wider taper down to the cinematic zoom, which
also moves ironsights by a third of the offset - that is a deliberate choice,
not the default.

Requests above 90 (a `cl_fovmultiplier` above 1, say) keep the full offset,
because `t` is clamped at 1.

## The `cof_viewmodel_fov` override

`ref/gl` builds exactly one projection matrix per frame, in
`R_SetupProjectionMatrix` from `RI.rvp.fov_x/fov_y`, so the viewmodel has
always scaled with the world FOV. `R_DrawViewModel` (`ref/gl/gl_studio.c`) is
the last thing in the scene and already brackets its draw with its own
`glDepthRange( gldepthmin, gldepthmin + 0.3 * (gldepthmax - gldepthmin) )`, so
a second projection is pushed inside that bracket and popped again:

```
R_CoFViewModelProjection():
    fov_x = bound( 55, cof_viewmodel_fov, 90 )        // 4:3-equivalent base
    fov_y = V_CalcFov ( fov_x, viewport w, h )         // same maths as the engine
    if wideScreen and r_adjust_fov: V_AdjustFov(...)   // same Hor+ as the world
    zNear 4, zFar max( 256, RI.farClip )               // same planes as the world
    -> Matrix4x4_CreateProjection

R_DrawViewModel():
    pglDepthRange( ... 0.3 ... )          <- stock
      save RI.projectionMatrix / RI.worldviewProjectionMatrix
      swap in the viewmodel projection, reconcat worldviewProjection
      pglMatrixMode( GL_PROJECTION ); pglPushMatrix(); GL_LoadMatrix( vm )
      draw
      pglMatrixMode( GL_PROJECTION ); pglPopMatrix()
      restore RI.*
    pglDepthRange( gldepthmin, gldepthmax )   <- stock
```

`RI.projectionMatrix` and `RI.worldviewProjectionMatrix` are swapped along with
the GL state so `pfnWorldToScreen` would agree with what is on screen. The
depth range is the stock one and the near/far planes are the world's, so the
0.3 depth-range hack that keeps the viewmodel out of walls still lands exactly
where it used to.

The Cry of Fear client cannot notice the swap. Measured statically on
`client.dll` `D2A04641…` (see the investigation): it never calls `glViewport`,
its only `glFrustum` call site is issued under `GL_TEXTURE` for projected
lights, its only `GL_PROJECTION` work is a balanced push / `glOrtho(0,1,1,0)` /
pop inside one full-screen post-process, and it never reads a matrix back
(`glGetDoublev` is never called, `GL_PROJECTION_MATRIX` never appears). The
FX137 depth-range wrapper it uses for the custom sky only calls
`glDepthRange`, which is orthogonal to the projection matrix and is restored by
`R_DrawViewModel` anyway.

`cof_viewmodel_fov 0` returns `false` before anything is touched, so the
default render path is the stock one.

At developer level the renderer reports the pass it built whenever the value
changes:

```
[cof-fov] viewmodel pass fov_x 75.18 fov_y 46.83 (cof_viewmodel_fov 60, world fov_x 106.26, viewport 1920x1080)
```

## Measured

Evidence: `stage1/fov-impl-20260922/` (cases A, B, C, D, E, F, Z), 1920x1080
windowed, map `c_forest3` (save `cofsave1`) and `c_park` (save `quick`), all
driven from cfgs with no keyboard or mouse injection. Horizontal FOV is fitted
from the screenshots with `stage1/fov-investigation-20260922/fovscale2d.py`,
which searches for the centre magnification `k = tan(A/2)/tan(B/2)` that
maximises the normalised cross-correlation between two frames of the same
standing view.

### World FOV at the hip (case A, repeated on the staged binaries as case Z)

| `cof_fov` | measured k vs. the 90 frame | rendered hFOV | closed form |
|---|---|---|---|
| 90 (default) | 1.0000 | 106.26 | 106.26 |
| 70 | 0.7005 | 86.09 | 86.04 |
| 110 | 1.4284 | 124.60 | 124.58 |
| back to 90 | 1.0011 | 106.32 | 106.26 |
| 200 (clamps to 110) | 1.0011 vs. the 110 frame | same frame | clamp |
| 10 (clamps to 70) | 1.0006 vs. the 70 frame | same frame | clamp |

The 0.001 residual is the search grid. These are the same numbers the
investigation measured for the equivalent `cl_fovmultiplier` values, which is
the point: `cof_fov` gives the identical hip view without the side effects.

### Ironsights (case B, `c_park`, glock, entered with `+attack3` and held)

| frames compared | change while in ironsights | measured k |
|---|---|---|
| hip 90 -> hip 110 | `cof_fov 90 -> 110` | **1.4284** (the hip does move) |
| ADS 110 -> ADS 90 | `cof_fov 110 -> 90` | **0.9986** |
| ADS 110 -> ADS 70 | `cof_fov 110 -> 70` | **0.9986** |
| ADS 90 -> ADS 70 | `cof_fov 90 -> 70` | **0.9986** |
| ADS 90 -> ADS back to 90 | (control) | 1.0011 |
| ADS 90 -> ADS 110 with `cof_fov_zoom_knee 30` | the wider taper | **1.1567** |

So with the default knee the ironsights view is the same frame at `cof_fov`
70, 90 and 110 - the taper has fully removed the offset by the time the client
asks for base 50. With the knee at 30 the same change scales ironsights by
1.1567; the closed form for base 50 -> 56.67 (a third of a +20 offset) is
1.1565.

### Viewmodel (cases C, D, E, F, Z)

Engine-side numbers, read from the renderer's own report (case F, repeated in
case Z on the staged binaries), against the closed form of the same chain:

| `cof_viewmodel_fov` | reported fov_x / fov_y | closed form | world fov_x |
|---|---|---|---|
| 0 | (no override) | - | 106.26 |
| 90 | 106.26 / 73.74 | 106.26 / 73.74 | 106.26 |
| 80 | 96.42 / 64.37 | 96.42 / 64.38 | 106.26 |
| 70 | 86.07 / 55.41 | 86.08 / 55.44 | 106.26 |
| 60 | 75.18 / 46.83 | 75.19 / 46.83 | 106.26 |
| 55 | 69.53 / 42.65 | 69.52 / 42.63 | 106.26 |
| 200 | 106.26 / 73.74 | clamps to 90 | 106.26 |
| 10 | 69.53 / 42.65 | clamps to 55 | 106.26 |

`world fov_x` is 106.26 in every line, and changing `cof_fov` during the same
run produced no new report line, because the viewmodel FOV does not follow the
world FOV once it is set.

Pixel side, on `c_forest3` (the lantern viewmodel, case C):

* **The world does not move.** `fovscale2d.py` over a world-only region
  (x 0.18..0.58, y 0.18..0.88 of the frame) fits k = 1.0006, 0.9991, 0.9991,
  1.0006 and 1.0006 at `cof_viewmodel_fov` 90, 80, 60, 55 and 10, with a
  correlation of 0.958..0.964 - i.e. identical to within the search grid.
* **The viewmodel does.** Its silhouette (`|frame - frame with
  r_drawviewmodel 0|`) grows monotonically as the FOV narrows. Measured by the
  radius of the point of the silhouette nearest the projection centre, relative
  to `cof_viewmodel_fov 0`: 0.94-1.00 for the settings that must not change it
  (0, 90, 200), 1.157 at 80, 1.566 at 60, 1.644 at 55, and 1.641 at 10 - which
  lands on the 55 value, confirming the low clamp in pixels as well. Those
  ratios read low against the closed-form 1.19 / 1.73 / 1.92 because the
  lantern's lamp lights the ground it points at (that lit patch is part of the
  difference image and does not scale) and because the model clips out of the
  frame at the narrow settings. That is why the exact degrees are taken from
  the renderer's report above rather than from a fit.
* Ironsights still work with a viewmodel FOV set (case D: `+attack3` with
  `cof_viewmodel_fov 70`, the zoom happens normally). Note that a viewmodel FOV
  other than the world's will move the weapon's iron sights off the screen
  centre, because only the viewmodel's projection changed - that is inherent to
  the feature and is why the default is "follow the world".

## Limits and notes

* The `cof_fov` taper is a function of the FOV the client asks for, not of
  which weapon is out. A weapon whose ironsights FOV is *between* the knee and
  90 would get a partial offset. Only the glock's (base 50) has been measured.
* `cl_fovmultiplier` keeps working and multiplies before `cof_fov` is added, so
  the two compose; the engine clamp `bound(10, fov, 150)` is still the final
  word.
* `r_adjust_fov` stays `1` and should not be exposed: with it off the same base
  90 renders as 90 degrees horizontal / 58.7 vertical at 16:9, which is a
  strictly worse "vert-" look.
* `hud_scale` is ignored for Cry of Fear (milestone 4) and does not interact
  with either option: the client builds no 3D projection at all.
* Menu wiring is not part of these patches. The menu worker needs
  `cof_fov` (slider 70..110, default 90) and `cof_viewmodel_fov`
  (slider 55..90 plus an off position writing 0, default 0 = follow world).
  `cof_fov_zoom_knee` is a developer cvar and should not be exposed.
