# A failed sky load must not outlive its map (`cof_sky_reset_per_map`)

User report, 2026-09-22, with the console text:

> opening the Unlockables gallery map `c_unlockables` logs
> `Sky error: cant load sky face gfx/env/desertlf.tga` and
> `Use gl_customsky 1 to reenable sky`; after that, loading a save (`c_forest3`)
> has a white/blank sky, whereas it was fine before visiting the gallery.

Labels as elsewhere in this project: **measured** = seen in a log line, a
screenshot or a shipped binary; **inferred** = a reading of measured facts.

## The mechanism

Neither string is in Xash3D FWGS. Both are in the shipped Cry of Fear client
(**measured**, `cryoffear/cl_dlls/client.dll`, read-only, image base
`0x10000000`):

| VA | string |
| --- | --- |
| `1014D238` | `gl_customsky` |
| `1014D29C` | `Sky error: cant get sv_skyname value` |
| `1014D2C4` | `Use gl_customsky 1 to reenable sky` |
| `1014D2FC` | `Sky error: cant load sky face %s` |
| `1014D2E8` | `gfx/env/%s%s.tga` |
| `1014D320` | `Loaded skybox %s` |

The client owns a complete second sky implementation, part of its Paranoia
renderer, and drives it from a cvar of its own:

```
1006 3F6E  pfnRegisterVariable( "gl_customsky", "1", 0 )   -> cvar_t* at 104CE068
```

Flags **0**: not archived, not `FCVAR_GLCONFIG`, not reset by anything. That is
the whole bug in one line.

### The draw pass, VA `10063780`

```
100637A6  mov   eax, [104CE068]          ; the gl_customsky cvar_t
100637B0  movss xmm0, [eax + 0xC]        ; ->value
100637B5  ucomiss xmm0, 0
100637BC  jnp   10063F3A                 ; value == 0 -> draw nothing at all
100637C2  call  10063450                 ; else: load the sky if needed
100637C7  cmp   [104CE020], 0            ; the "loaded" flag
100637CE  je    10063F3A
...                                      ; six textured faces
```

### The loader, VA `10063450`

```
10063464  call  [101B2698]               ; GetMaxClients   (engfunc index 36)
1006346D  jle   100635E0                 ; <= 1 -> single player branch
...
1006360E  call  [101B2648]               ; GetCvarString("sv_skyname") (index 16)
10063639  ...                            ; if it equals the cached name, return
1006367D  mov   [104CE020], 0            ; loaded = 0
10063690  ... "gfx/env/%s%s.tga" ...     ; six faces, rt bk lf ft up dn
100636C4  je    10063735                 ; any face fails -> the failure path
...
1006370D  mov   [104CE020], 1            ; loaded = 1, cache the name
```

Failure path, VA `10063735` — **this is the mechanism**:

```
1006373C  push  1014D2FC                 ; "Sky error: cant load sky face %s"
10063741  call  1007D400                 ; Con_Printf
10063746  push  1014D2C4                 ; "Use gl_customsky 1 to reenable sky"
1006374B  call  1007D400
10063753  mov   dword ptr [esp], 0       ; 0.0f
1006375A  push  1014D238                 ; "gl_customsky"
1006375F  call  [101B269C]               ; Cvar_SetValue    (engfunc index 37)
```

The engine function table base is `0x101B2608` (**measured**: index 14
`pfnRegisterVariable` is `[101B2640]`, and `[101B264C]` / `[101B2650]` /
`[101B2668]` are `pfnAddCommand("skyangles")`, `pfnHookUserMsg("skymark_sky")`
and `pfnAngleVectors`, which pins the layout). `[101B269C]` is therefore index
37, `Cvar_SetValue`, and `[101B2698]` index 36, `GetMaxClients`.

So one map with missing sky faces writes `gl_customsky 0`, and because that cvar
has no archive flag and no per-map reset, the client's entire sky pass stays off
for the rest of the process. **Nothing in the engine or in ref_gl persists a
failed sky load**: `R_SetupSky` (`engine/client/dll_int/ref_common.c:104`) starts
every level by calling `ref.dllFuncs.R_SetupSky( NULL )`, which is
`R_UnloadSkybox()` in `ref/gl/gl_warp.c:312`, clearing `tr.skyboxTextures` and
`FWORLD_CUSTOM_SKYBOX`; it is called unconditionally from
`CL_ParseServerData`'s one-time block (`engine/client/parse/cl_parse.c:1706`) on
every level load. The engine side was already correct. **No ref_gl change was
needed and none was made.**

## Why `c_unlockables`

**Measured** from the shipped BSP entity lumps:

| map | worldspawn `skyname` |
| --- | --- |
| `c_unlockables` | **absent** (the lump has `MaxRange` and `wad`, no `skyname`) |
| `c_forest3` | `black` |
| `c_game_menu1` | `blue22` |

`SV_SpawnEntities` does `Cvar_Reset( "sv_skyname" )` on every map
(`engine/server/sv_game.c:5147`), and `sv_skyname`'s default is `"desert"`
(`engine/server/sv_main.c:102`, `DEFAULT_SKYBOX_NAME` in
`engine/common/com_strings.h:68`). A map with no `skyname` key therefore asks
for `desert`, and Cry of Fear ships **no desert faces anywhere**: a scan of the
canonical read-only copy finds `gfx/env/` holding exactly 18 files —
`black{bk,dn,ft,lf,rt,up}.tga`, `blue22*.TGA` and `sorgard*.tga` — and nothing
named `desert*` in the whole tree or in any of its 22 WADs (GoldSrc WADs hold
textures, never `.tga` sky faces).

**Inferred, and the reason this is not a Cry of Fear bug:** under real GoldSrc
the game directory falls back to `valve/`, which ships `gfx/env/desert*.tga`
with Half-Life, so the load succeeded and the failure path never ran. A
standalone Cry of Fear game directory under Xash has no such fallback — there is
no `valve` directory in the shipped tree at all — so a map that never set a
skyname now trips a code path the original game never reached.

Out of 235 shipped maps, 56 have no `skyname` key. Every one of them is a
`desert` request that cannot be satisfied.

## The fix

One engine patch, `patches/cof-sky-reset-per-map.patch`, applied with
`scripts/apply-cof-sky-reset-per-map.ps1`. New cvar:

```
cof_sky_reset_per_map   default 1, flags 0
```

`0` is stock behaviour, bit for bit: nothing is remembered and nothing is
restored.

Two halves, both in `engine/client/cl_main.c`:

* **`CL_CoF_SkyClientCvarSet( name, value )`** is called from the client DLL's
  own `Cvar_SetValue` callback. `engine/client/dll_int/cl_game.c` grew a
  `pfnCvarSetValue` wrapper for exactly this and the engfuncs table entry now
  points at the wrapper instead of at the raw `Cvar_SetValue` — the wrapper
  **replaces** the entry, it is not added next to it, because a second entry
  would shift every engfunc after index 37 and break the client's whole table
  (the apply script checks this). That callback is the only place in the engine
  that can tell a write *from the client* apart from one the user typed or a
  config exec'd. When the client writes `0` into `gl_customsky`, the engine
  remembers the value from a moment earlier and **lets the write through**, so
  the map that really has no sky faces behaves exactly as it does today: no
  per-frame retry, no console spam.
* **`CL_CoF_SkyResetPerMap()`** runs from `R_SetupSky` in
  `engine/client/dll_int/ref_common.c`, the engine's own per-map sky setup,
  reached on a level start, on a skyname change and on the `skybox` command. It
  puts the remembered value back before the client's first sky draw of the new
  map, so the client re-reads `sv_skyname` and loads the new map's faces.

Nothing else about `gl_customsky` changes, which is what "do not change
`gl_customsky` semantics for the user" required:

* a user who sets `gl_customsky 0` turns the draw pass off, so the loader never
  runs, never fails and never writes the cvar — nothing is remembered and
  nothing is ever restored;
* a user who sets `gl_customsky 1` on a map whose faces are missing gets the
  same two error lines and the same shutdown as before, confined to that map;
* the disabled state is never persisted: `gl_customsky` is not archived, and the
  engine's memory of it is a single `static qboolean` cleared on the next
  `R_SetupSky`.

## Verification

Fixture `stage1/ui-m1-engine-fixture-20260921`, windowed 1280x720, `+volume 0`,
no typed input and no mouse input anywhere: every command comes from the command
line, from a cfg the command line execs, or from `maps/<map>_load.cfg`. Engine
under test `06F1D1159320761FBF1C09770DD61A152D04F01D24E5A14E3379BBF0B7AF7E1B`.

| Run | cfg | Decisive lines |
| --- | --- | --- |
| `sk1-fix-on` | `skycase1.cfg` | `Spawn Server: c_unlockables`, `SKY:  failed`, `Sky error: cant load sky face gfx/env/desertlf.tga`, `Use gl_customsky 1 to reenable sky`, then **`[cof-sky] the client turned "gl_customsky" off after a failed sky load on "c_unlockables"; "1" will be restored on the next map load`**; gallery screenshot with `"gl_customsky" is "0"`; then `Spawn Server: c_forest3`, **`[cof-sky] restored "gl_customsky" to "1" for the new map`**, `SKY:  blackrt, blackbk, blacklf, blackft, blackup, blackdn. done`, and `"gl_customsky" is "1"` on the forest screenshot |
| `sk2-fix-off` | `skycase2.cfg`, `+set cof_sky_reset_per_map 0` | the same binary, the control: the same two error lines, **no `[cof-sky]` line anywhere**, and `"gl_customsky" is "0"` still on the forest screenshot |
| `sk3-reference` | `skycase3.cfg`, `+load cofsave1` | the direct load with no gallery visit: `"gl_customsky" is "1"` |

`sk1-fix-on-c.png` (the forest after the gallery, fix on) and
`sk3-reference-c.png` (the forest loaded directly) are the requested screenshot
pair.

### What the screenshots can and cannot show

**Measured, and worth being explicit about:** the pixel difference between a
working and a dead client sky pass could **not** be isolated on `c_forest3`.
Two reasons, both measured:

1. `cofsave1` leaves the player looking at the ground under trees; no sky
   surface is in the frame. The client's own `+lookup` console command was
   tried from the case cfg (`skycase5.cfg`) and did not move the view.
2. Every Cry of Fear map except `c_game_menu1` and the eleven `outofit` maps
   uses the all-black skybox, so even a correct sky is black there.

A direct A/B of `gl_customsky` `0` against `1` on the same save and the same
camera (`ab0-customsky-0-c.png` / `ab1-customsky-1-c.png`) and on the
background map (`bg0`/`bg1`, mean absolute difference 0.125, no pixel differing
by more than 8) confirms that neither of those viewpoints shows the pass at all.

So the evidence for this fix is the cvar state and the log, which is decisive
and exactly describes the reported mechanism; the user-visible white sky is
**marked for the user's manual test** on a viewpoint that actually has sky in
frame.

## Artefacts

| Artefact | Bytes | SHA-256 |
| --- | ---: | --- |
| `patches/cof-sky-reset-per-map.patch` | 10 367 | `0EE80BE61F77FDAE0A023C3A8B1F00D251AEF03C4E162C5E493D3ADCFE9BEBB0` |
| `xash.dll` (`build-cof-ui-m1-engine-20260921`) | 3 519 488 | `06F1D1159320761FBF1C09770DD61A152D04F01D24E5A14E3379BBF0B7AF7E1B` |

Build line unchanged from milestone 1:

```
python waf configure -4 --out=build-cof-ui-m1-engine-20260921 \
  --sdl2=..\prereq\sdl2-2.30.9-vc\SDL2-2.30.9 \
  -T release --notests --disable-mbedtls --enable-cof-entvars-legacy
python waf build -j8 --targets=xash
```

from the pinned FWGS checkout with the x86 MSVC environment
(`vcvarsall.bat amd64_x86`) and `WAFLOCK=.lock-waf-cof-ui-m1-engine`.

**Patch safety, verified** on `cof-fix/pristine-ui-m1-scratch`, which carries
the `ref/gl` stack (gl trace patches, skyline trace, renderfx opaque) and the
engine stack (input gate, deferred command guard, vid restart, levelshot guard,
console style, menu-map redirect, death flow, text autoscale, MP3 stop): forward
apply, duplicate-apply refusal, and after the apply all four files hashed
identical to the working tree; then `-Reverse` restored all four to their
pre-apply hashes with the earlier CoF patches and the stock engfuncs table
intact.

## Canonical tree

`stage1/ui-m1-engine-fixture-20260921/evidence/canonical-sky-before.txt` and
`canonical-sky-after.txt` bracket every run: 6 197 files, 4 702 274 797 bytes,
newest write `2026-09-18T20:33:58.9860178Z`, identical apart from the `taken=`
timestamp.
