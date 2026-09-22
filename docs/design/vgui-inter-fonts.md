# The client's VGUI text rasterised from Inter (`cof_ui_inter_fonts`)

Unified UI milestone 4, the font half. The scaling half is
[the in-game UI scaled from the display](ui-scaling.md); this patch sits
on top of it and needs it.

Cry of Fear draws its VGUI text from bitmap strips at
`gfx/vgui/fonts/<res>_<scheme>.tga`. The client's resolution table caps at 1600
and the strips are byte-identical from the 1024 bucket upwards — the
`inventory` scheme never scaled at all — so above 1024 px wide every one of
those labels has a single fixed pixel size whatever the display is. This
replaces them with glyphs rasterised from the Inter faces the project already
ships, at a size derived from the render height.

## Read this first: most of the inventory is not text

The audit listed the inventory's `BAG`, `QUICK SELECT`, `POCKETS`, `NOTES`,
`SLOT 1..3`, `ITEM DESCRIPTION` and `CURRENT OBJECTIVE` under "VGUI bitmap
text, `inventory` scheme". **They are not text.** Every one of them is painted
into the panel artwork `gfx/vgui/640_inventory.tga`, a 748x480 image — which is
exactly the size of the inventory's inner frame panel in the measured panel
tree.

Measured: with the font substitution forced to **three times** its normal size,
the inventory panel is pixel-identical to the same frame with
`cof_ui_inter_fonts 0` (138 differing pixels, all of them in the developer
notify block in the top-left corner). No font change can touch those labels,
and none should be expected to.

What this patch does reach is the text that really is VGUI text: the notes and
document reader (`pager`), the chapter title cards (`chaptertitle`), the
credits (`credits`, `creditstitle`), the subtitle panel, the scoreboard, and
the two schemes that have **no strip at any resolution** and therefore render
nothing at all in the stock game (`Default Text`, `impact`) — those start
working for the first time.

Making the inventory labels scalable would mean redrawing that artwork, which
is a separate, asset-side job.

## The device/logical split

`cof_ui_scale` multiplies every VGUI quad on the way out, so a font that
reported its real pixel size would be magnified twice. Two sizes come out of
the engine for every role:

	devicePx  = fraction * render_height * cof_ui_scale_user
	logicalPx = devicePx / cof_ui_scale

Glyphs are rasterised at `devicePx`; every metric the client and the draw path
see is reported at `logicalPx`. The atlas then lands on exactly the device
pixels it was drawn for. Report the device size and the text is scaled twice;
rasterise at the logical size and it is a magnified bitmap again, which is what
this replaces.

`XashSurface::buildFontCache` packs and rasterises in device pixels
(`CofFont::deviceTall()` / `deviceABCwide()`); `drawPrintText` and every layout
query use the logical ones.

## The sizes

The fractions are the shipped point sizes at the 1024 bucket — the last one the
artists actually changed — read as a fraction of 768:

| role | shipped px at 1024 | fraction | face |
| --- | ---: | ---: | --- |
| `inventory` | 14 | 1.82 % | Inter Regular |
| `credits` | 14 | 1.82 % | Inter Regular |
| `pager` | (none) | 1.82 % | Inter Regular |
| `creditstitle` | 24 | 3.13 % | Inter SemiBold |
| `chaptertitle` | 30 | 3.91 % | Inter SemiBold |
| anything else, including `Default Text` and `impact` | — | 1.82 % | Regular, SemiBold for any `*title*` |

`* cof_ui_scale_user` on top, so the menu's HUD scale control moves the text
with the panels.

## How a font knows which role it is

It cannot be read off the font: the client builds every one of them as
`Font( "Arial", <tga bytes>, tall = 20, weight = 700 )`. What identifies it is
the strip it loaded first. The engine wraps the `COM_LoadFile` engfunc
(`CL_CoF_LoadFile`, `cl_game.c`) and latches the scheme out of any
`gfx/vgui/fonts/<digits>_<scheme>.tga` path; FreeVGUI's `Font` constructor hook
reads it back.

Two details that were measured the hard way:

* **The latch is sticky.** It is *not* cleared when read. The client builds more
  than one `Font` object per strip load and the first one is not always the one
  it draws with — clearing on read gave the `inventory` scheme's role to an
  object that was never drawn, and the font that did the drawing got nothing.
  The role now stays current until the next strip load replaces it.
* **The path filter has to be strict.** Matching any `vgui` `.tga` latched
  `pl`, `sv`, `speaker1`, `voiceblocked` and friends from the voice icons. The
  filter now requires the `fonts` directory and an all-digits resolution bucket
  before the underscore.

A font built before any strip load gets the body size rather than nothing,
which is how `Default Text` and `impact` come to render at all.

## The code page

Text reaches `drawPrintText` one byte at a time and the atlas is 256 cells —
the whole 8-bit pipeline the game and the language packs use. Rather than widen
it, each byte is decoded to Unicode inside the font, with the pack's code page,
immediately before the glyph lookup. One pack is one code page.

`cof_text_codepage` selects it: **1252** (Western, the default), **1250**
(Central European — Polish) or **1251** (Cyrillic — Ukrainian, Russian). The
tables are generated from the Windows code pages and live in
`3rdparty/freevgui/platform/xash3d-fwgs/coffont.cpp`; Inter covers Latin
Extended-A and Cyrillic, so both packs are the same job with a different table.

This is what
[`stage1/polish-file-access-20260922/RESULTS.md`](../../../stage1/polish-file-access-20260922/RESULTS.md)
section 4 asks for, and it bypasses the engine console's `con_charset` path
entirely — that one has no CP1250 at all and a CP1252 stub.

### Checking it: `cof_font_probe`

There is no other way to see a code page working. The game draws only English,
the inventory's labels are artwork, and every other VGUI text surface needs a
map event or a mouse click. So the support library draws one developer string
over everything, with a real engine font:

```
cof_text_codepage 1250
cof_font_probe "chaptertitle Zazolc gesla jazn"
```

An optional leading word naming a known scheme picks the size. Setting it to
the empty string turns it off. The bytes are taken as-is, so a probe cfg has to
be written in the pack's own 8-bit encoding, not UTF-8 — which is exactly what
a language pack file is.

## Cvars

| cvar | default | flags | meaning |
| --- | --- | --- | --- |
| `cof_ui_inter_fonts` | `1` | `FCVAR_ARCHIVE` | rasterise the client's VGUI text from Inter; `0` restores the game's own bitmap strips exactly |
| `cof_text_codepage` | `1252` | `FCVAR_ARCHIVE` | 1250, 1251 or 1252; language packs set this |
| `cof_font_probe` | `""` | — | developer: draw this string with an engine font |

## Signed `char`, and why it had to be fixed first

The library passed a plain `char` into `getCharABCwide` in five places, and
`TextImage` — the layout path behind every client label — did the same thing in
**eight more** with `int ch = text[i]` on a `char *`. Bytes `0x80..0xFF`
sign-extend to a negative int there. That was harmless only because the game's
own font override re-masks with `movzx`; an engine-supplied font does not, and
a negative index into a 256-entry table is a wild read at exactly the bytes
Polish and Cyrillic use. All thirteen are fixed in
`patches/cof-vgui-anchor.patch`, which this patch depends on.

## Atlas pages

`MAX_FONT_PAGES` went from 8 to 16. The chapter title is 3.91 % of the render
height, which at 2160p with the HUD scale at 200 % is a 169 px cell — about 18
glyphs to a page, so eight pages truncated the set. Pages are still uploaded
only as they fill, so the usual case (four pages for a title font at 2160p)
costs nothing extra.

## Where the work happens

| file | what |
| --- | --- |
| `engine/client/cl_main.c` | `cof_ui_inter_fonts`, `cof_text_codepage`, `cof_font_probe`; the role fractions, the size derivation, the latch, and the Inter file loader |
| `engine/client/dll_int/cl_game.c` | `CL_CoF_LoadFile`, the `COM_LoadFile` engfunc wrapper that latches the scheme |
| `engine/client/vgui/vgui_draw.c` | four thunks into the above |
| `engine/vgui_api.h` | `cof_vgui_font_t` and four appended `vguiapi_t` entries |
| `3rdparty/freevgui/platform/xash3d-fwgs/coffont.{h,cpp}` | the rasteriser, the code page tables, the role cache, the substitution hook |
| `3rdparty/freevgui/platform/xash3d-fwgs/stb_truetype.h` | vendored, byte-identical to the copy `3rdparty/mainui` already carries |
| `3rdparty/freevgui/platform/xash3d-fwgs/surface.cpp` | substitution in `drawSetTextFont`, device metrics in `buildFontCache`, the probe draw |
| `3rdparty/freevgui/font.{h,cpp}` | `Font_Active()` and the two hooks |
| `3rdparty/freevgui/image.cpp`, `controls/text.cpp`, `controls/edit.cpp` | every metric query routed through `Font_Active()` |

`Font_Active()` is not optional anywhere: the game **overwrites the vtable** of
the font objects it builds, so a virtual call on one of them reaches its own
`getCharABCwide` and its shipped `.chw` widths, not ours.

## Applying

After the scaling pair:

```powershell
pwsh -File .\scripts\apply-cof-ui-scale.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
pwsh -File .\scripts\apply-cof-vgui-anchor.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
pwsh -File .\scripts\apply-cof-vgui-inter-fonts.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
python waf build -j8 --targets=xash,vgui
```

The fonts themselves are the ones the menu theme already ships under
`gamedata/cryoffear/gfx/fonts` (Inter, SIL OFL, with the licence). No new
gamedata file is needed, but `gfx/fonts/Inter-Regular.ttf` and
`Inter-SemiBold.ttf` must be present in the game directory or the patch logs
one warning and leaves the client's strips in place.
