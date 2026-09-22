#!/usr/bin/env python3
"""Rasterise a TrueType face into the GoldSrc/Xash ``.fnt`` console atlas format.

Cry of Fear unified UI, milestone 4.  The engine console draws every glyph out
of a bitmap atlas, so the shipped ``gfx.wad`` ``CONCHARS`` (12 px tall, amber,
aliased) stays 12 px tall whatever the display is.  ``cof_text_autoscale`` now
stretches the atlas to a target height derived from the render height, and a
12 px master stretched to 37 px at 2160p is mush.  This script produces the
master the engine actually wants: Inter, antialiased, at three base sizes, in
the exact container ``Con_LoadVariableWidthFont`` and ``Image_LoadFNT`` read.

Container layout, from ``engine/common/imagelib/img_wad.c`` (``Image_LoadFNT``)
and ``engine/client/cl_font.c`` (``Con_LoadVariableWidthFont``):

    offset 0      int32   width          texture width / 16
    offset 4      int32   height         texture height
    offset 8      int32   rowcount       number of glyph rows (informational)
    offset 12     int32   rowheight      glyph cell height, the line height
    offset 16     charinfo fontinfo[256] { int16 startoffset; int16 charwidth; }
    offset 1040   byte    pixels[w*h]    8-bit indices, w = width * 16
    +w*h          int16   numcolors      768
    +2            byte    palette[768]
    +768          byte    pad[64]

``startoffset`` is read back as a 16-bit *unsigned* linear pixel offset
(``left = startoffset % texwidth``, ``top = startoffset / texwidth``), so the
whole atlas has to fit in 65536 pixels.  That is the only hard limit here and
it is what caps the largest usable base height.

The palette is written as the identity grey ramp ``pal[i] = (i, i, i)``.  The
engine recognises that exact palette as an 8-bit coverage mask and decodes it
through ``LUMP_GRADIENT`` (white, alpha = index) instead of ``LUMP_MASKED``
(opaque, one colour keyed out), which is what keeps the antialiasing as real
alpha so ``cof_console_text_color`` and the ``^N`` codes still mean something.
Any other palette keeps the stock masked behaviour, so no existing font
changes.  Without that engine hunk this file still loads, it just renders with
hard edges.

Usage (defaults produce exactly what the patch ships):

    python scripts/make-cof-console-font.py \
        --ttf gamedata/cryoffear/gfx/fonts/Inter-Regular.ttf \
        --out gamedata/cryoffear/fonts

Milestone 4b uses the same generator for the engine HUD font behind
``pfnDrawCharacter`` (hints, ``HudText`` messages, prompts), from a heavier face
and at its own base sizes -- see ``docs/cof-hud-text-legibility.md``:

    python scripts/make-cof-console-font.py \
        --ttf gamedata/cryoffear/gfx/fonts/Inter-SemiBold.ttf \
        --out gamedata/cryoffear/fonts --name cof_hudtext --sizes 14,19

The two base sizes are not a preference: ``startoffset`` caps the atlas at
65536 pixels, and above a ~20 px base the packer starts dropping glyphs out of
the 216-character cp1252 set the language packs need.
"""

import argparse
import os
import struct
import sys

from PIL import Image, ImageDraw, ImageFont

NUM_GLYPHS = 256
QCHAR_WIDTH = 16          # engine/common/common.h
HEADER_SIZE = 1044        # sizeof( qfont_t )
PIXELS_AT = HEADER_SIZE - 4
MAX_ATLAS_PIXELS = 1 << 16  # startoffset is a 16-bit unsigned linear offset
MAX_DIM = 1024            # LUMP_MAXWIDTH / LUMP_MAXHEIGHT in engine/common/imagelib
GAP = 2                   # transparent gutter between cells, stops filter bleed


def build_charset(charset):
    """Byte value -> unicode character, for the bytes we rasterise."""
    out = {}
    for b in range(32, 127):
        out[b] = chr(b)
    if charset == "ascii":
        return out
    for b in range(128, 256):
        try:
            ch = bytes([b]).decode(charset)
        except (UnicodeDecodeError, LookupError):
            continue
        if ch.isprintable():
            out[b] = ch
    return out


def pick_size(ttf, rowheight):
    """Largest point size whose ascent+descent still fits rowheight."""
    best = None
    for size in range(4, 400):
        font = ImageFont.truetype(ttf, size)
        ascent, descent = font.getmetrics()
        if ascent + descent > rowheight:
            break
        best = (size, font, ascent, descent)
    if best is None:
        raise SystemExit("rowheight %d is too small for %s" % (rowheight, ttf))
    return best


def measure(font, chars):
    widths = {}
    for b, ch in chars.items():
        adv = font.getlength(ch)
        w = int(round(adv))
        if ch == " ":
            w = max(w, 1)
        # a glyph may paint wider than its advance (italics, overhangs); the
        # engine's rect is the advance, so clamp the ink to it below
        widths[b] = max(1, min(w, 255))
    return widths


def priority(chars):
    """Byte values in the order they earn atlas space: ASCII, accented
    letters, then the rest of the upper range."""
    order = [b for b in range(32, 127) if b in chars]
    order += [b for b in range(192, 256) if b in chars]
    order += [b for b in range(160, 192) if b in chars]
    order += [b for b in range(128, 160) if b in chars]
    return order


def pack(order, widths, rowheight, texwidth, budget):
    """Greedy left-to-right packing that stops when the atlas would blow the
    65536-pixel budget; returns the placements it managed to fit."""
    places = {}
    x, y = 0, 0
    for b in order:
        w = widths[b]
        nx, ny = x, y
        if nx + w > texwidth:
            nx = 0
            ny = y + rowheight + GAP
        used_h = ((ny + rowheight + 3) // 4) * 4
        if texwidth * used_h > budget:
            break
        places[b] = (nx, ny)
        x, y = nx + w + GAP, ny
    used_h = ((y + rowheight + 3) // 4) * 4
    rows = y // (rowheight + GAP) + 1
    return places, used_h, rows


def render_atlas(ttf, rowheight, charset, verbose=True):
    size, font, ascent, _descent = pick_size(ttf, rowheight)
    chars = build_charset(charset)
    widths = measure(font, chars)
    order = priority(chars)

    best = None
    # LUMP_MAXWIDTH/LUMP_MAXHEIGHT in the engine's imagelib are 1024
    for texwidth in (256, 512, 1024):
        places, texheight, rows = pack(order, widths, rowheight, texwidth,
                                       MAX_ATLAS_PIXELS)
        if texheight < rowheight or texheight > MAX_DIM or not places:
            continue
        # most glyphs wins; then the squarest, then the smallest
        key = (len(places), -max(texwidth, texheight), -texwidth * texheight)
        if best is None or key > best[0]:
            best = (key, places, texwidth, texheight, rows)

    if best is None:
        raise SystemExit("cannot fit a %d px atlas into %d pixels"
                         % (rowheight, MAX_ATLAS_PIXELS))

    _key, places, texwidth, texheight, rows = best
    active = [b for b in order if b in places]
    if verbose:
        missing = len(order) - len(active)
        print("  base %2d px: ttf size %d, %d/%d glyphs%s, atlas %dx%d (%d rows)"
              % (rowheight, size, len(active), len(order),
                 ", %d dropped for space" % missing if missing else "",
                 texwidth, texheight, rows))

    img = Image.new("L", (texwidth, texheight), 0)
    for b in active:
        ch = chars[b]
        if not ch.strip():
            continue
        x, y = places[b]
        cell = Image.new("L", (widths[b], rowheight), 0)
        ImageDraw.Draw(cell).text((0, ascent), ch, fill=255, font=font,
                                  anchor="ls")
        img.paste(cell, (x, y))
    return img, places, widths, active, rowheight, rows


def write_fnt(path, img, places, widths, active, rowheight, rows):
    texwidth, texheight = img.size
    if texwidth % QCHAR_WIDTH:
        raise SystemExit("texture width must be a multiple of %d" % QCHAR_WIDTH)

    info = [(0, 0)] * NUM_GLYPHS
    for b in active:
        x, y = places[b]
        off = y * texwidth + x
        if off > 0xFFFF:
            raise SystemExit("glyph %d lands at offset %d, past the 16-bit limit" % (b, off))
        info[b] = (off, widths[b])

    out = bytearray()
    out += struct.pack("<4i", texwidth // QCHAR_WIDTH, texheight, rows, rowheight)
    for off, w in info:
        # startoffset is read back through (word), so write the raw 16 bits
        out += struct.pack("<Hh", off & 0xFFFF, w)
    assert len(out) == PIXELS_AT, len(out)
    out += img.tobytes()
    out += struct.pack("<h", 768)
    for i in range(256):                     # identity grey ramp: alpha = index
        out += bytes((i, i, i))
    out += bytes(64)

    expected = PIXELS_AT + texwidth * texheight + 2 + 768 + 64
    if len(out) != expected:
        raise SystemExit("bad file size %d, expected %d" % (len(out), expected))

    with open(path, "wb") as fh:
        fh.write(out)
    return len(out)


def main():
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ttf", default=os.path.join(
        here, "gamedata", "cryoffear", "gfx", "fonts", "Inter-Regular.ttf"))
    ap.add_argument("--out", default=os.path.join(
        here, "gamedata", "cryoffear", "fonts"))
    ap.add_argument("--name", default="cof_console",
                    help="base file name; files are <name>0.fnt .. <name>N.fnt")
    ap.add_argument("--sizes", default="16,24,34",
                    help="base glyph heights, one atlas each, small to large")
    ap.add_argument("--charset", default="cp1252",
                    choices=("ascii", "cp1252", "cp1251"),
                    help="how bytes 128..255 are interpreted")
    args = ap.parse_args()

    if not os.path.isfile(args.ttf):
        raise SystemExit("no such font file: %s" % args.ttf)
    os.makedirs(args.out, exist_ok=True)

    print("font:    %s" % args.ttf)
    print("charset: %s" % args.charset)
    for i, s in enumerate(int(v) for v in args.sizes.split(",")):
        img, places, widths, active, rowheight, rows = render_atlas(
            args.ttf, s, args.charset)
        path = os.path.join(args.out, "%s%d.fnt" % (args.name, i))
        n = write_fnt(path, img, places, widths, active, rowheight, rows)
        print("  -> %s (%d bytes)" % (path, n))
    return 0


if __name__ == "__main__":
    sys.exit(main())
