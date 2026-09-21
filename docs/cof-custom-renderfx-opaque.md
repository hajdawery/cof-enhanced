# Custom `renderfx` values must stay opaque (main-menu skyline fix)

`patches/cof-custom-renderfx-opaque.patch` makes FWGS classify a
rendermode-normal entity as opaque even when its `renderfx` carries a
mod-defined value, which is what GoldSrc does. It is the fix for the missing
Cry of Fear main-menu skyline. It is gated by the new `ref_gl` cvar
`cof_custom_renderfx_opaque` (`FCVAR_GLCONFIG`, default `1`).

## Root cause

`ref/gl/gl_rmain.c` `R_OpaqueEntity()` decides which draw list an entity joins:

```c
if( R_GetEntityRenderMode( ent ) == kRenderNormal )
{
        switch( ent->curstate.renderfx )
        {
        case kRenderFxNone:
        case kRenderFxDeadPlayer:
        case kRenderFxLightMultiplier:
        case kRenderFxExplode:
                return true;
        }
}
return false;
```

Upstream FWGS therefore accepts only a four-value whitelist of `renderfx`.
GoldSrc classifies by `rendermode` alone, so any `renderfx` value a mod invents
stays opaque there. Cry of Fear invents several: its client recognises sky
models purely by `curstate.renderfx` in `{70, 137, 184}`
(`stage1/sky-client-static-audit-20260921/RESULTS.md`, Finding 4, sites
`0x1005F66E`, `0x1005FAFC`, `0x1005FB50`, `0x10060606`, `0x1008D1BB`,
`0x1008D40F`, `0x1008D46F` in `client.dll` SHA-256
`D2A04641B301804F6F449AA68265042B13ADC360925B80033D417EC9F38C9C00`), and it
uses `renderfx` 92/93/94 as draw-distance cull flags (same report, Finding 7).

On `c_game_menu1` the sky sphere `models/Props/sky_sphere4.mdl` has
`rendermode 0` and `renderfx 137`, and the buildings model
`models/Props/Blandat/byggnader.mdl` has `rendermode 0` and runtime
`renderfx 92`. Both fall outside the whitelist, so both were sorted into the
translucent list, after every translucent brush entity.

The visible skyline is not the studio model at all. It is drawn by translucent
brush entity `*23` with `rendermode 2` (`kRenderTransTexture`), for which the
engine's own `R_SetRenderMode()` in `ref/gl/gl_rsurf.c` correctly calls
`pglDepthMask( GL_FALSE )`. The depth buffer therefore keeps the cleared value
`1.0` at those pixels. The sky sphere, drawn later in the same translucent list
inside the client's `glDepthRange( 0.8, 0.9 )`, writes window-z ~0.8950-0.8968
there, passes `GL_LEQUAL` against `1.0`, and paints over the skyline.

## Measured evidence

From `stage1/sky-depth-order-qa2-20260921/RESULTS.md` (diagnostic renderer
`ref_gl.diagnostic.dll` SHA-256
`7B53D289CF81DB91512DA8D04F719A7018C6EE0C6F6A5D7C4616F687946DB41A`, PDB
`EE9543497784D11E39017E7B050A75A8B1ED4DAF2FE83E8BE139B94A52E97999`; engine
`xash.dll` SHA-256
`65ACDEA266B66E7FFA44B15281B97C9938C63069E81411D84F9A5C6C00E79FAE`):

* The per-entity draw-list walk on `c_game_menu1` recorded
  `after-trans[0]-ent33-type3-rm0-byggnader.mdl`,
  `after-trans[3]-ent30-type0-rm2-*23` and
  `after-trans[9]-ent83-type3-rm0-sky_sphere4.mdl`. The solid list held only
  the world plus `models/player.mdl`.
* `trans[3]` (the translucent brush `*23`) is the draw that produces every
  measured building pixel, and it leaves depth at `1.000000`.
* `trans[9]` (the sky sphere) then writes 0.894972-0.896809 at those same ten
  pixels and replaces their colour with near-black.
* The known-good reference `r_studio_builtin_renderer 1` leaves depth at
  `1.0` at the skyline pixels and never paints the sphere over them, so
  "correct depth" was never the missing ingredient - draw order was.
* The attribute-stack run showed `GL_ATTRIB_STACK_DEPTH = 0/16` at all 105
  probe points and `GL_DEPTH_WRITEMASK = 1` after the client's first
  `StudioDrawModel`, so the client's `glPushAttrib`/`glPopAttrib` pair is
  balanced and is not the cause.

From `stage1/sky-client-static-audit-20260921/RESULTS.md` (read-only static
analysis of the original `client.dll`):

* The FX137 wrapper at `0x1008CEE0` changes only the modelview translation and
  the depth range (`0x1008D563` sets `(0.8, 0.9)`, `0x1008D5CC` restores
  `(0.0, 0.8)`). It never disables the depth test, never changes `glDepthFunc`
  and never clears depth.
* `client.dll` contains exactly one `glClear`, and its mask is
  `GL_STENCIL_BUFFER_BIT`; there is no `glClear( GL_DEPTH_BUFFER_BIT )`.
* Sky-flagged **sprite** models are removed from the engine list by
  `HUD_AddEntity` and drawn from the client's own array; sky-flagged **studio**
  models such as `sky_sphere4.mdl` are *not* diverted and are drawn at their
  normal position in the engine's entity list. Nothing in the client reorders
  them.

From `stage1/map-renderfx-scan-20260921/RESULTS.md`: across all 235 CoF `.bsp`
files, `renderfx 137` appears on 99 entities in **74** maps, `renderfx 70` on
26 entities in 26 maps and `renderfx 184` on 5 entities in 5 maps. The defect
is therefore campaign-wide, not specific to the menu map.

## The fix

`R_OpaqueEntity()` gains one early-out, before the existing switch:

```c
if( cof_custom_renderfx_opaque.value && ent->curstate.renderfx > kRenderFxLightMultiplier )
        return true;
```

`kRenderFxLightMultiplier` is the last entry of the standard `renderfx` enum in
`common/const.h`, so "greater than" means exactly "outside the standard enum",
i.e. a mod-defined value. Such an entity is put in the solid list, drawn in the
solid pass before any translucent entity, and can no longer overwrite
translucent brush geometry.

The cvar `cof_custom_renderfx_opaque` is declared in `ref/gl/gl_local.h`,
defined and registered next to the other `cof_` cvars in `ref/gl/gl_opengl.c`,
defaults to `1`, and is `FCVAR_GLCONFIG` so it persists in `opengl.cfg`.
Setting it to `0` restores the previous upstream behaviour for comparison.

## Applying

```powershell
pwsh -File .\scripts\apply-cof-custom-renderfx-opaque.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

The helper scopes application to this workspace, requires the GL stage,
solid-entity and transparent-triangle trace prerequisites, refuses duplicate
application, verifies the cvar and `R_OpaqueEntity` markers after applying, and
reverse-checks the patch. `-Reverse` removes it and refuses when it is absent.

## Validation

Build `build-cof-renderfx-opaque-20260921` (configure line identical to
`build-cof-savecompat` with `--out` changed, then
`python waf build -j8 --targets=ref_gl`):

| File | SHA-256 |
| --- | --- |
| `ref/gl/ref_gl.dll` (1,095,680 bytes) | `125E32E3115751374773ABA0858B2CDB298F6F23D5D799824FFB269B7DE9A9E5` |
| `ref/gl/ref_gl.pdb` (9,555,968 bytes) | `15BB13E3FC2F7C734AC62F61254521E8902A78ACBC15F894FDF507A78A77FDDB` |

Runtime `stage1/launch-prototype-20260920`, 1920x1080 windowed, `+volume 0`,
`r_studio_builtin_renderer 0` and every other `cof_*` selector `0`. Evidence is
in `stage1/renderfx-opaque-qa-20260921`.

* With `cof_custom_renderfx_opaque 1` the skyline buildings, lit windows and
  spires are present. With `0` they are gone. The two frames differ only in
  that cvar.
* Draw-list membership, using only the pre-existing `cof_skyline_trace` and
  `cof_gl_trace` markers: with the cvar at `1`, `[cof-skyline] entry ent=33`
  and `entry ent=83` are logged **before**
  `[cof-world-poly] before_client_normal_triangles`; with the cvar at `0` they
  are logged **after** `after_client_normal_triangles`. Since
  `R_DrawEntitiesOnList()` runs solid entities, then
  `pfnDrawNormalTriangles()`, then translucent entities, this places both
  models in the solid list when the fix is on and in the translucent list when
  it is off.
* Diff fraction against the known-good builtin reference frame, restricted to
  the skyline band (window rows 400-620, origin bottom-left; any channel
  differing by more than 8), reproducing the previous worker's method: the fix
  scores 20.45 % against `skysphere-builtin-c-game-menu1-20260921.png`, the
  same frame the 20.08 % sphere-first figure was measured against, versus
  38.66 % with the cvar at `0`. The residual is the map's animated
  film-grain/snow overlay, which differs between any two frames; two
  independent known-good frames differ by 16.56 % in the same band.
* Bounded transition smoke checks with the new renderer: `+map c_loadgame`
  reached `Spawn Server: c_loadgame`, `level loaded at 0.52 sec` and
  `client connected`; a direct `+map c_forest3` gameplay load reached
  `Spawn Server: c_forest3`, `level loaded at 0.66 sec` and `client connected`.
  `+beginspgame` produced no map spawn, but a control run with the baseline
  renderer `F3B1D4B9F3C2237C50447D956EE43070B22BF578C9E15CD0ED67D30B30E6F172`
  behaved identically, so that is a pre-existing harness limitation and not a
  regression from this patch.

The runtime renderer was restored to
`F3B1D4B9F3C2237C50447D956EE43070B22BF578C9E15CD0ED67D30B30E6F172` and PDB
`382A95B9B30EA4AEF9F3EFA9926DFD64115A27F218134F9ADD1CE94DD27D2340` afterwards,
the `SAVE` directory was byte-identical before and after, and no game process
remained.

## Limits

This is a renderer classification change for rendermode-normal entities only.
It does not touch blending, depth state, the client's depth-range slab, the
`GL_INVALID_VALUE` diagnostics, or water. Visual parity for the rest of the
campaign is not claimed; only the menu map was measured.
