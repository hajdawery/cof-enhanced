# Console and overlay text sized from the display (`cof_text_autoscale`)

Unified UI milestone 4, first part. The engine console, its notify lines and
every engine-drawn corner overlay were a fixed number of **pixels** tall
whatever the display was, because they all draw out of one bitmap atlas. Cry of
Fear ships a 12 px `CONCHARS` in `gfx.wad`; that is already small at 1920x1080
and unreadable on the user's 3840x2160 display. The user's requirement
(2026-09-22): the glyph height must be **a fraction of the screen height,
continuous, with no per-resolution cases**.

## The size formula

One number, derived once per load and baked into the font:

```
target_px = render_height * cof_text_height_pct / 100 * con_fontscale
            clamped to [6, 192] px
cof_text_height_pct is clamped to [0.4, 12.0]
```

`Con_TextTargetHeight()` in `engine/client/console.c`. With the default
`cof_text_height_pct 1.7` and `con_fontscale 1.0`:

| Render height | target | atlas chosen | atlas base | glyph scale | measured `charHeight` |
| --- | --- | --- | --- | --- | --- |
| 720 | 12.2 px | `cof_console0.fnt` | 16 px | 0.765 | **12 px** |
| 1080 | 18.4 px | `cof_console0.fnt` | 16 px | 1.147 | **18 px** |
| 1440 | 24.5 px | `cof_console1.fnt` | 24 px | 1.020 | **24 px** |
| 2160 | 36.7 px | `cof_console2.fnt` | 34 px | 1.080 | **37 px** |

(`charHeight` as the engine logged it in the verification runs below - it is
`round( base * scale )`, so it tracks the target to the pixel.)

`con_fontscale` **multiplies** the target rather than being replaced by it, so a
user who has already set `con_fontscale 1.5` keeps that 1.5 on top.

### What the size applies to

The target is written into the loaded `cl_font_t`'s `scale`, `charHeight` and
`charWidths[]` (`Con_ScaleConsoleFont()`), and **every** console font in the set
gets the same one, so no drawing code has to know the feature exists. That
covers, all verified on screen:

* the styled console panel and the stock console (`cof_console_style 0`), their
  log area, backscroll, and the build string in the title band;
* the input line, its prompt, caret and completion tail;
* the notify lines over the game (`Con_DrawNotify`);
* `Con_DrawDebug` / `Con_DrawDebugLines` (the client's `pfnDrawConsoleString`
  notify block);
* `cl_showfps` (all three modes) and `r_speeds`, in `cl_scrn.c`;
* `net_speeds` (`SCR_NetSpeeds`) and the `SCR_DrawPos`-style block;
* the net graph's label rows, in `cl_netgraph.c`;
* the engine version string, `Con_DrawVersion` (its colour is the stock
  `g_color_table[7]` amber, which this patch does not change).

Three call sites carried hard-coded pixel constants that only worked for 8x12
glyphs and had to be re-derived rather than scaled:

* `SCR_NetSpeeds` and `SCR_RSpeeds` placed their block at `width - 320 * scale`
  and `width - 340 * scale`. The block is now **measured** with
  `CL_DrawStringLen()` and right-aligned, so it cannot run off the edge.
* the net graph used a 15 px row pitch, a 75 px "ms" column and a graph-relative
  position for the `%i/s` labels. Row pitch and column follow the font; the
  label block is lifted until its last row fits above the bottom edge, the
  `%i/s` column is clamped to the right edge, and the block is then pushed left
  so the two cannot overlap. Without this the `loss:/choke:` row was off the
  bottom of a 2160p screen and `20/s` was cut in half by the right edge.
* `Con_CheckResize()` wraps a line at `con.linewidth` when it is *added*, long
  before the styled panel exists, so it now wraps to the panel's log area
  (`Con_StyleLogWidth()`) instead of the whole screen. A long line is rewrapped
  inside the panel instead of being clipped at its edge.

## The Inter atlas

A 12 px aliased master stretched to 37 px is mush, so the patch ships a master
that was drawn to be resized. `scripts/make-cof-console-font.py` rasterises the
project's Inter Regular (already shipped under `gamedata/cryoffear/gfx/fonts`
with its OFL licence) into three `.fnt` atlases at base heights 16, 24 and 34 px,
installed as `gamedata/cryoffear/fonts/cof_console{0,1,2}.fnt`.
`Con_LoadConchars()` picks whichever needs the **least resampling** to reach the
target, measured as the ratio, so magnifying 1.20x loses to minifying 1.10x.

Two engine changes make that atlas render correctly:

* **Linear filtering.** A target height is almost never an integer multiple of
  the atlas, and a nearest-filtered 1.15x stretch turns a glyph stem into an
  alternating one and two pixels. `Con_LoadConsoleFont()` clears `TF_NEAREST`
  whenever a target is in force. `CL_DrawCharacter()` already insets half a
  texel per glyph rect when it magnifies, which is exactly the case that inset
  exists for, and the generator keeps a two-pixel transparent gutter between
  cells for the minifying case.
* **An alpha ramp instead of a colour key.** `Image_LoadFNT()` decoded every
  `.fnt` palette through `LUMP_MASKED`, which flattens every partly covered
  pixel to fully opaque and keys out only index 255 - a hard halo around an
  antialiased glyph. The generator writes the identity grey ramp
  `pal[i] == (i,i,i)`, and `img_wad.c` recognises **that exact palette** and
  decodes it through `LUMP_GRADIENT` instead: one colour taken from the last
  palette entry (white), alpha = the index. No shipped font has that palette, so
  every existing `.fnt` keeps the masked behaviour byte for byte.

The atlas is loaded through the same `Con_LoadVariableWidthFont()` as any other
console font, so `cof_console_font_grayscale` (`TF_LUMINANCE`) and the whole
styled-console colour path work on it unchanged.

### Regenerating the atlases

```powershell
python .\scripts\make-cof-console-font.py
# --ttf, --out, --sizes 16,24,34, --charset cp1252 all have defaults that
# reproduce the shipped files byte for byte
```

Verified 2026-09-22: a fresh run reproduces all three files with identical
SHA-256:

| file | bytes | SHA-256 |
| --- | --- | --- |
| `cof_console0.fnt` | 38738 | `8BCDC8A60ED35C86DF6A8CE231FB2966D3B21DF7A7DE58A66669BA5E7BBA434C` |
| `cof_console1.fnt` | 67410 | `34AF13D9D6855CEE535B8659D6C83C65D21A75080727B3DE4974910BA42EB40C` |
| `cof_console2.fnt` | 66386 | `B4AF38C2272F5BE237731A219B1A48F603B4E1A0A06B170C1E48B6B236BFB674` |

**Known limit of the container.** A `.fnt` glyph's `startoffset` is read back as
a 16-bit *unsigned* linear pixel offset, so the whole atlas must fit in 65536
pixels. At base 16 px all 216 cp1252 glyphs fit (256x144); at 24 px 200 fit; at
34 px only 102 do - all 95 printable ASCII plus seven accented letters. Engine
console output is ASCII, so the practical effect is that a few accented
characters are missing from the console **only at 4K and above**. A glyph that
did not fit has `charWidths[b] == 0` and simply draws nothing.

## Cvars

| Cvar | Default | Flags | Meaning |
| --- | --- | --- | --- |
| `cof_text_autoscale` | `1` | `FCVAR_ARCHIVE` | size console and overlay text from the render height; `0` is the stock fixed bitmap size |
| `cof_text_height_pct` | `1.7` | `FCVAR_ARCHIVE` | target glyph height as a percentage of the render height, clamped to 0.4-12.0 |
| `cof_text_font` | `1` | `FCVAR_ARCHIVE` | load `fonts/cof_console*.fnt`; `0` falls through to the stock `con_oldfont` / `gfx.wad CONCHARS` chain |

These three are archived, unlike the `cof_console_*` look cvars, because they are
display preferences that have to survive a restart. `Con_CheckTextScale()`
re-derives the target from `Con_VidInit()` (a mode change), from
`Con_RunConsole()` and from `Con_DrawConsole()` (the connecting states), so a
runtime change to any of the three reloads the fonts on the next frame; it is a
float comparison otherwise. It logs one developer line per reload:

```
[cof-text] 3840x2160: target 36.7 px (cof_text_height_pct 1.70, con_fontscale 1.00) -> font 2 base 34 px, glyph scale 1.080, charH 37 px
```

If the atlases are not present in the game directory the loader falls straight
through to the stock chain and the *scaling* still works on `CONCHARS`; it just
looks like a stretched 12 px bitmap. That is exactly what the
`cof_text_autoscale 0 + cof_text_font 0` control run shows.

## Validation

Fixture `stage1/ui-m1-engine-fixture-20260921`, wrapper
`run-textscale-case.ps1` over `run-vidmode-cfg-case.ps1`. No keyboard or mouse
injection of any kind, no `SetForegroundWindow`/`AppActivate`, no retry after a
failure; every command comes from the command line, from `tscase1.cfg` /
`tscase2.cfg`, or from `maps/<map>_load.cfg`, and each case ends with `quit`.
Windowed, `+volume 0`, `-dev 2 +set developer 2`. The 3840x2160 window is larger
than the desktop; the screenshot captures the render target, which is what is
being measured. The wrapper restores `root/cryoffear/config.cfg` from
`evidence/config-textscale-baseline.cfg` first, because these cvars are
archived and would otherwise leak between runs.

Engine under test:
`96F0BA9CCEE3CA36FB1F125BA8C07416F24AFF94C500A4225066299F0EB92C17`
(`build-cof-ui-m1-engine-20260921/engine/xash.dll`). The three `.fnt` files were
copied into `root/cryoffear/fonts`.

| Run | What it shows |
| --- | --- |
| `f1-bg-1280`, `f1-bg-1920`, `f1-bg-2560`, `f1-bg-3840` | the styled console over the background map at each size. `-c.png` carries the Inter atlas, the `^N` colour codes, and the deliberately long line rewrapped **inside** the panel. The `[cof-text]` line in each log gives the table above |
| `f1-game-1280/1920/2560/3840` | a real game (`+load cofsave1`, `c_forest3`) with the console never opened: notify lines top-left, `cl_showfps 2` and `r_speeds` top-right, `net_speeds` below them, the net graph labels bottom-right, all scaled and none clipped |
| `f0-bg-1920`, `f0-bg-3840`, `f0-game-3840` | the control: `cof_text_autoscale 0 cof_text_font 0`. Each log carries both lines - the boot default, then `target 0.0 px … font 2 base 12 px, glyph scale 1.000, charH 12 px` once the command line is applied - and the screenshots are the stock amber 12 px console |
| `f1-inputline-strip.png` | the input line at all four sizes, cropped at **native pixels** and stacked, so the 12 -> 18 -> 24 -> 37 px progression is directly visible |
| `f1-netgraph-strip.png` | the net graph label block at all four sizes: four rows on screen, `20/s` clear of the block, nothing clipped |
| `f-control-vs-autoscale-3840.png` | the same crop of the same console at 3840x2160 with the feature off (top) and on (bottom) |

Canonical tree bracketed by `evidence/canonical-final-before.txt` and
`evidence/canonical-final-after.txt`: 6197 files, 4702274797 bytes, newest write
`2026-09-18T20:33:58Z`, identical apart from the `taken=` timestamp.

**Marked for the user's manual test:** how 1.7 percent actually reads on the
user's own 4K display, and whether `cof_text_height_pct` wants a different
default. Everything in this patch is one cvar away from any other value.

## Applying

After the Source-style console **and** the death flow - the console.c hunks use
lines from both as context, and the real stack order is styled console first,
then the death flow, then this:

```powershell
pwsh -File .\scripts\apply-cof-text-autoscale.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

The script refuses a tree that already carries it, checks all three
prerequisites by marker, verifies concrete markers in all four touched files
afterwards, and reverse-checks the patch. Verified 2026-09-22 on
`cof-fix/pristine-ui-m1-scratch` (apply, then a byte comparison of all four
files against the built source) and on a fresh copy of `cof-fix/pristine-clean`
with the whole engine stack applied in order.
