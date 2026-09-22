# The in-game UI scaled from the display (`cof_ui_scale`)

Unified UI milestone 4. Every Cry of Fear in-game surface — the inventory panel,
the HUD bars, the ammo counter, the phone, the notes, the hint and subtitle
text — was a fixed-pixel layout. The client asks the engine for the screen size
once, builds its whole VGUI panel tree from it, and never lays it out again; its
bitmap font strips stop growing at the 1024 bucket and its bucket table caps at
1600. So the fraction of the screen the UI occupies has fallen off as `1/height`
since 2012, and at 4K the inventory is a postage stamp.

The audit is `stage1/ingame-ui-scaling-20260922/RESULTS.md`; the implementation
evidence, every measurement quoted here and the full element coverage table are
in `stage1/ui-m4-scaling-20260922/RESULTS.md`.

## The lever the audit proposed cannot be used, and this is the key fact

The obvious approach — and the audit's recommendation — is to lie to the client
about the screen size through `clgame.scrInfo`, the way `hud_scale` already
does, and let `SPR_AdjustSize` magnify everything.

**That breaks Cry of Fear's 3D rendering.** The client builds its own renderer's
viewport and projection out of the same `gHUD.m_scrinfo` it lays its panels out
from, so a virtual screen size zooms and shifts the view, in game and on the
menu background map alike. It was reported from the user's runtime — the Video
page's "Auto scale HUD" checkbox wrote `hud_scale 2` into `config.cfg` — and
then measured.

> **Correction (2026-09-22 docs pass).** The measured effect below stands, but
> the mechanism named above was revised by the later FOV investigation
> (`stage1/fov-investigation-20260922/RESULTS.md`, [field of view](../patches/cof-fov.md)):
> the client builds no 3D projection of its own (no `glViewport`, only a
> texture-matrix `glFrustum` and one fixed 2D `glOrtho`). What a virtual
> `scrInfo` zooms and shifts is the client's full-screen 2D overlay pass, which
> is sized from the same screen info. The conclusion (never touch `scrInfo`,
> ignore `hud_scale` for Cry of Fear) is unchanged.

The measurement is a geometry check, not a pixel diff: the forest scene is not
deterministic frame to frame, so `fovcheck.py` masks the HUD corner, takes the
column-mean and row-mean brightness profile of two frames, resamples one about
the screen centre by a candidate scale and reports which scale correlates best.
An unchanged FOV leaves the peak at 1.0000.

| pair, both 2560x1440 | bit-identical px | best column scale | best row scale |
| --- | ---: | ---: | ---: |
| two stock runs, same settings (the noise floor) | 48.1 % | 1.0000 (0.9988) | 1.0000 (0.9974) |
| **`cof_ui_scale` auto (1.333x) vs off** | 47.4 % | **1.0000 (0.9992)** | **1.0000 (0.9982)** |
| `cof_ui_scale` auto (2.0x) vs off, at 3840x2160 | 51.3 % | 1.0000 (0.9995) | 1.0000 (0.9988) |
| **`hud_scale 2`, the rejected design** | **9.1 %** | 1.0000 (**0.8611**) | **1.2500** (0.6856) |

So this feature never touches `clgame.scrInfo`, and **`hud_scale` is ignored
outright for Cry of Fear** (`CL_CoF_HudScaleBlocked`). A stale archived value in
an existing `config.cfg` would otherwise still break the renderer, whatever the
menu offers. It logs one warning naming `cof_ui_scale` instead.

## The transform

    device = ( layout + anchorOffset ) * scale

    scale = clamp( render_height / 1080, 1, 4 )   cof_ui_scale 0, automatic
          = clamp( cof_ui_scale / 100,   1, 4 )   otherwise
    then  * cof_ui_scale_user, re-clamped

The automatic law keeps the client's fixed-pixel layout at exactly the fraction
of the screen it occupies at 1920x1080: an element of `p` layout pixels is drawn
`p * scale` device pixels tall, so `p*scale/height == p/1080` at every height.
Continuous in the render height, no per-resolution cases. It stays at 1 below
1080p deliberately — the design is a fixed pixel layout and shrinking it further
would only make an already 8 px label smaller.

The scale is applied in `VGUI_DrawQuad` and `VGUI_SetPaintOffset`
(`engine/client/vgui/vgui_draw.c`), with the exact inverse on
`VGUI_GetMousePos` and `VGui_MouseMove`. The client's 3D never goes through
those.

### The anchor half, and why it is needed

A single scale about the origin walks the centred inventory off the right edge.
A single scale about the screen centre walks the bottom-left HUD bars off the
bottom — that is not hypothetical, it was the first implementation and the bars
vanished. So each top-level client UI surface is anchored, per axis, to
whichever screen edge it was laid out against:

| anchor | offset |
| --- | --- |
| low (left / top) | `0` |
| centre | `screen / (2*scale) - layout / 2` |
| high (right / bottom) | `screen / scale - layout` |

An axis is centred when the surface sits within 5 % of symmetric in the layout,
otherwise it anchors to the nearer edge.

This lives in `3rdparty/freevgui/platform/xash3d-fwgs/cofscale.cpp` and runs
from a hook at the end of `Panel::solve()`. **That is the whole reason hit
testing cannot drift**: `solve()` is the single place absolute coordinates are
produced, and both painting (`getAbsExtents`) and hit testing (`screenToLocal`)
read the `screenOrigin` it writes. Moving the panel there moves the mouse target
with it by construction, instead of by a second transform that has to be kept in
sync. `Panel`'s size is ABI-fixed — the game library allocates its own
subclasses — so the pass carries no new state on the class and reaches the
solved members through a `CofPanelAccess` friend struct.

**Which panel owns an anchor** was settled from a measured panel tree, not
guessed. At 2560x1440:

    d0 root                      2560x1440
     d1 client viewport          2560x1440
      d2 (overlay container)     2560x1440
      d2 HUD container           2560x1440
       d3 health bar group         32x160  at   32,1280   -> left + bottom
       d3 stamina bar group        32x160  at   64,1280   -> left + bottom
       d3 message strip          2560x64   at    0,720    -> centre + centre
       d3 letterbox strips       2560x75   at    0,-75 / 0,1440
      d2 inventory container     2560x1440
       d3 backdrop               2560x1440          (full screen, no anchor)
       d3 inventory outer frame   800x600  at  880,420   -> centre + centre
       d3 inventory inner frame   748x480  at  906,480   -> centre + centre
        d4 slots, icons, labels                         (inherit the centre)

Every full-screen panel is a container and every real surface hangs off one, so
the rule is: **the anchor owner is the outermost panel, below the root, that
does not cover the whole layout screen**, and its whole subtree inherits it.
Stopping the descent earlier — at a fixed depth, say — gives the HUD bars the
inventory's centre anchor and walks them off the corner.

### Full-screen pages are anchored as one piece (fix-ads-tape round)

One exception to that rule, found through the tape recorder: a full-screen
**page** - a full-screen panel with no full-screen child of its own, whose
visible children cover the whole layout screen between them - owns the anchor
for its whole subtree (`CofIsPage` in `cofscale.cpp`, checked while walking down
in `CofAnchorOwner`). Its pieces keep their places relative to each other and
the page is scaled as one picture about the screen centre; a full-screen page
anchors to the centre on both axes by the ordinary rule.

Measured (`stage1/fix-ads-tape-20260922`, a panel-tree dump at 1920x1080 and
150 percent, `evidence/tape7-tree.txt`): the recorder's SAVED GAMES page (the
client panel at viewport `+0x1464`, constructor `100309E0`) is a transparent
full-screen panel holding the 640x480 `save_load.tga` image at 640,300 and
**four opaque black mask panels** around it (0,0 640x1080; 1280,0 640x1080;
640,0 640x300; 640,780 640x300), so the game shows the picture on black.
Anchored one by one, the left mask stayed on the left edge, the right mask
moved to the right edge of a layout that is only 1280 layout pixels wide at
150 percent (so into the middle), the top and bottom masks to their edges,
while the picture stayed centred: at any scale above 1 the masks covered the
picture and the whole screen went black, with nothing to click (the user's
"black screen when saving at a tape recorder"; reproduced with the m5a and the
m6 sets, and inferred to be there since this anchor pass arrived in milestone
4, whenever the scale is above 1). As one page the masks frame the picture
exactly as the game laid them out (`fin2-b-recorder-page.png`).

The viewport, the HUD container and the inventory container are not pages
(the viewport holds full-screen children, the inventory its full-screen
backdrop, and the HUD container's bars and strips cover only a small part of
the screen), so their surfaces keep the per-edge anchors above; the inventory
was re-checked centred (`fin2-g-inventory.png`).

### The frozen-layout shift falls out of the same change

The client creates its viewport and every child panel exactly once, in a
constructor guarded by a non-NULL pointer, so a later video mode change leaves
the layout stranded at the old screen centre. That is the "inventory panel in
the lower-right quarter" bug.

The anchors are recomputed from the **current** render size against the
**pinned** layout size (the render size at the client's first `VidInit`,
`CL_CoF_UIPinLayout`) on every solve, so a layout built for 1920x1080 and then
shown at 1280x720 is simply re-anchored. Measured, `vid_setmode 1280 720` in
game after loading at 1920x1080:

| | inventory frame | centre vs screen centre |
| --- | --- | --- |
| before | 495x329 at (593,283) | (840,447) vs (640,360) — clipped into the corner |
| **after** | **729x504 at (273,108)** | **(637.0,359.5) vs (640,360)** |

which is identical to a native 1280x720 launch.

## The classic HUD sprite path

The ammo counter is not VGUI. `CHudAmmo::Draw` (client VA `100177C0`) reads
`ScreenWidth`/`ScreenHeight` 22 times, positions every digit through
`CHud::DrawHudNumber` (`10072160`) and draws through `pfnSPR_Set` +
`pfnSPR_DrawHoles` / `pfnSPR_DrawAdditive`. (`pfnSPR_Draw` itself has **zero**
call sites in this client — a hook covering only it would cover nothing. All of
them funnel through `SPR_DrawGeneric`.) The weapon selection overlay, the pickup
history icons, the secondary ammo readout, the status icons, the train controls
and the logo sprite are on the same path.

These are *not* in the frozen layout space: the client re-reads
`pfnGetScreenInfo` in `CHud::VidInit`, which does run on every mode change, so
HUD sprite coordinates always follow the live render size. They get a plain
anchored scale about the current screen, in `SPR_DrawGeneric`.

**A size cap was needed.** Scaling every native-size sprite draw banded the
picture into a 3x3 grid: the client paints `sprites/subtle_noise.spr` as a
256x256 grid over the whole screen, 60 draws a frame, and anchoring each tile to
its own nearest edge makes them overlap. Traced with `cof_ui_scale_sprites 2`:

| sprite | size | draws / frame at 2560x1440 |
| --- | --- | ---: |
| `sprites/subtle_noise.spr` | 256x256 | **60** |
| `sprites/cof_glock_mag.spr` | 32x128 | 1 |
| `sprites/cof_glock_mag_icon.spr` | 32x32 | 1 |
| `sprites/cof_ammohud.spr` | 20x24 | 1 |
| `sprites/cof_mag_cross.spr` | 16x16 | 1 |

A HUD sprite authored for a 640x480 layout is never larger than **128 design
pixels** on an axis; a screen overlay tile always is. So that is the cap, and it
cannot be fooled by how often a sprite is drawn.

`pfnFillRGBA` / `pfnFillRGBABlend` are **deliberately not scaled**: the client
uses them for screen-covering effects assembled from adjoining rectangles. The
visible cost is that the dynamic crosshair (four one-pixel lines at the tail of
`CHud::Redraw`) keeps its size; its gap is already `ScreenWidth/640`-relative.

## The engine HUD font

`cls.creditsFont` is the font behind `pfnDrawCharacter`, which is how the client
draws hints, "Using Gas Mask" prompts and `HudText` messages. The client lays
that text out itself from `gHUD.m_scrinfo.charWidths[]` and `iCharHeight`, and
`SCR_LoadCreditsFont` copies those two fields out of this very font — so
resizing the font moves the client's own centring, line pitch and wrap points
with it, and no client-side layout has to be understood or touched.

    target = render_height * cof_hud_text_height_pct / 100
             * hud_fontscale * cof_ui_scale_user
             clamped to [6, 192] px, and never below the shipped size

| render height | target | glyph scale | charHeight |
| ---: | ---: | ---: | ---: |
| 720 | 12.7 px | 1.000 | **19 px** (floored at the shipped size) |
| 1080 | 19.0 px | 1.000 | **19 px** — identical to stock |
| 1440 | 25.3 px | 1.334 | **25 px** |
| 2160 | 38.0 px | 2.001 | **38 px** |

`1.76` is chosen so the shipped 19 px glyph is reproduced exactly at 1920x1080:
a 1080p player sees no change at all.

## Cvars

| cvar | default | flags | meaning |
| --- | --- | --- | --- |
| `cof_ui_scale` | `0` | `FCVAR_ARCHIVE` | in-game UI scale in percent of the client's own layout; `0` = automatic from the render height |
| `cof_ui_scale_user` | `1.0` | `FCVAR_ARCHIVE` | the menu's "HUD scale" multiplier, applied to the UI and the HUD text together; clamped to 1.0–2.0 |
| `cof_ui_scale_sprites` | `1` | `FCVAR_ARCHIVE` | also scale the classic HUD sprite path; `0` = native size, `2` = trace every draw with its sprite name |
| `cof_hud_text_height_pct` | `1.76` | `FCVAR_ARCHIVE` | engine HUD font height as a percentage of the render height, never below the shipped size; `0` = stock |

Milestone 4b adds `cof_hud_text_font`, `cof_hud_text_backing`, `cof_hud_text_y`
and `cof_hud_text_y_shift` on top of this one, and replaces the "glyph scale
never below 1" floor with the equivalent floor in pixels, so a generated atlas
of its own base height obeys it too. It also establishes, statically and at
runtime, that this font's size **does not move** the client's messages: they sit
at `0.70 * ScreenHeight` whatever `iCharHeight` is. See
[the engine HUD text made readable](../patches/cof-hud-text-legibility.md).

All four are live. `CL_CoF_CheckUIScaleChanged`, called once a frame from
`CL_DrawHUD`, re-runs `SCR_VidInit` when any of them changes, which reloads the
HUD font and makes the client re-read `charWidths[]`/`iCharHeight`. The client's
VGUI panel tree is deliberately *not* rebuilt — its constructor is guarded and
runs once per session, which is exactly why the surface transform anchors
against the pinned layout size instead.

## Measured sizes

`cof_ui_scale` auto, native pixels, `m4measure.py`.

| render size | scale | inventory frame | height as % of screen | HUD bars | bottom gap |
| --- | ---: | --- | ---: | --- | ---: |
| 1280x720 | 1.000 | 729x504 | 70.00 % | 47x155 | 3 |
| 1920x1080 | 1.000 | 729x513 | **47.50 %** | 47x155 | 3 |
| 2560x1440 | 1.333 | 973x679 | **47.15 %** | 62x206 | 4 |
| 3840x2160 | 2.000 | 1458x1019 | **47.18 %** | 94x310 | 6 |
| 3840x2160, off | 1.000 | 729x513 | 23.75 % | 47x155 | 3 |

Ammo counter: 16x106 at 1920x1080, 32x212 at 3840x2160, still anchored to the
bottom-right corner.

`cof_ui_scale_user` at 1920x1080: 1.0 → scale 1.000 / 19 px text, 1.5 → 1.500 /
29 px, 2.0 → 2.000 / 38 px.

**At 1920x1080 with the defaults the feature is a no-op**: the inventory capture
is SHA-256 `BF3D03BC…`, byte-identical to the pre-milestone baseline.

## Known limits

* An aspect-ratio change stretches the frozen VGUI layout non-uniformly instead
  of displacing it. Cosmetic and recoverable; a displacement is not.
* The dynamic crosshair does not scale (the fill path is left alone).
* The TV noise / scanline overlay does not scale, by the 128 px cap, which is
  correct — it already covers the screen.
* Client GL overlays are out of scope: screen blur (`10071DF0`, whose step sizes
  are hardcoded `ScreenWidth/640`), post-process and colour grading
  (`1005D7A0`), the gas-mask and sniper-scope overlays (`10093300`). They are
  already screen-relative.
* Mouse hit testing in the inventory at 1440p and 2160p has not been clicked —
  this project may not inject mouse input. The transform makes drawing and hit
  testing share one coordinate, so they cannot disagree, but it is on the
  manual list.

## Applying

The engine half and the support-library half are one feature and both are
needed; the engine half alone scales the panels without re-anchoring them, which
is how the HUD leaves the screen. Apply after the text autoscale:

```powershell
pwsh -File .\scripts\apply-cof-ui-scale.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
pwsh -File .\scripts\apply-cof-vgui-anchor.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
python waf build -j8 --targets=xash,vgui
```

Both scripts refuse a tree that already carries the change, check their
prerequisites by marker, verify concrete markers in every touched file
afterwards, and take `-Reverse`. Verified 2026-09-22 on a fresh copy of
`pristine-clean` with the whole engine stack applied: forward apply,
duplicate-apply refusal, reverse, and a clean round trip back to the same 14
hashes, with all 15 patched files matching the built source.

`cof-hud-text-scale` is **not** a separate patch. The HUD font sizing shares
`cl_main.c`, `client.h` and `cl_scrn.c` with the surface transform and is driven
by the same `cof_ui_scale_user` multiplier, so splitting it would only produce
two patches that can never be applied apart.

**`vgui.dll` is new to the deploy set.** This is the first milestone to change
the VGUI support library, so `--targets=xash,vgui` and the extra deploy entry
are both required.
