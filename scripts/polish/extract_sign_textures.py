#!/usr/bin/env python3
"""Extract the repainted sign/poster textures embedded in the fan
translation's BSP files as standalone TGA images, one file per texture name.

Part 3 of the native language-pack generator suite. The engine side
(patches/cof-language-packs.patch, CoF_Lang_TextureReplacement) probes
languages/<code>/textures/<name>.tga before the embedded miptex of every world
texture of that name.

Derived directly from the two BSP trees (lang3, 2026-09-22; no analysis
files): for every map both trees have, every EMBEDDED miptex of the
translation whose mip-0 indices + palette differ from the canonical map's
miptex of the same name is a candidate. A name must resolve to one image
across all maps (checked). A candidate identical to ANY canonical embedded
miptex or WAD texture of that name is dropped as a copy of the game's own art
(three such names in the Polish source: c2_statiosig1, c2_tbsignn5,
c2_tbsignn6), so the folder only carries art the translators repainted.

GoldSrc BSP TEXTURES lump (lump index 2) format, all little-endian:

    int32 nummiptex
    int32 dataofs[nummiptex]          -- offset from lump start, or -1 if absent

Each dataofs[i] (if >= 0) points to a mip_t:

    char   name[16]
    uint32 width, height
    uint32 offsets[4]                 -- offset from START OF THIS mip_t

Mip 0 is width*height palette indices (row-major, top-down), followed by mips
1-3, a uint16 palette count (256) and count*3 bytes of RGB palette.

Alpha masking: a name starting with "{" uses palette index 255 as the
transparency key and is written as a 32-bit BGRA TGA (alpha 0 for index 255);
all others as 24-bit BGR. The literal "{" stays in the file name.

Usage:
    python scripts/polish/extract_sign_textures.py --lang polish
"""
from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path
from typing import Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
import langpack_common  # noqa: E402


LUMP_TEXTURES = 2
BSP_HEADER_LUMP_COUNT = 15


# ---------------------------------------------------------------------------
# BSP / miptex parsing
# ---------------------------------------------------------------------------

class MiptexNotFound(Exception):
    pass


def read_texture_lump(bsp_path: Path) -> bytes:
    with open(bsp_path, "rb") as fh:
        data = fh.read()
    version = struct.unpack_from("<i", data, 0)[0]
    if version != 30:
        raise ValueError(f"{bsp_path}: unexpected BSP version {version} (expected 30)")
    off = 4 + 8 * LUMP_TEXTURES
    lump_off, lump_len = struct.unpack_from("<ii", data, off)
    return data[lump_off:lump_off + lump_len]


def find_miptex_offset(lump: bytes, name: str) -> int:
    """Return the dataofs[] value (offset into `lump`) of the miptex whose
    name matches `name` case-insensitively. Raises MiptexNotFound if absent.
    """
    nummiptex = struct.unpack_from("<i", lump, 0)[0]
    dataofs = struct.unpack_from(f"<{nummiptex}i", lump, 4)
    target = name.lower()
    matches = []
    for doff in dataofs:
        if doff < 0:
            continue
        raw_name = lump[doff:doff + 16].split(b"\x00", 1)[0]
        mip_name = raw_name.decode("latin1")
        if mip_name.lower() == target:
            matches.append(doff)
    if not matches:
        raise MiptexNotFound(name)
    # All cross-map-identical duplicates within one map should be byte
    # identical too; just use the first.
    return matches[0]


def extract_miptex(lump: bytes, doff: int) -> tuple[str, int, int, bytes, bytes]:
    """Returns (name, width, height, mip0_indices, palette_rgb_bytes)."""
    raw_name = lump[doff:doff + 16].split(b"\x00", 1)[0]
    name = raw_name.decode("latin1")
    width, height = struct.unpack_from("<II", lump, doff + 16)
    offsets = struct.unpack_from("<4I", lump, doff + 24)
    if offsets[0] == 0:
        raise ValueError(f"{name}: not embedded (offsets[0] == 0)")

    mip0_off = doff + offsets[0]
    mip0_len = width * height
    mip0 = lump[mip0_off:mip0_off + mip0_len]
    if len(mip0) != mip0_len:
        raise ValueError(f"{name}: truncated mip0 data ({len(mip0)} != {mip0_len})")

    # Palette follows mip level 3 data.
    mip3_off = doff + offsets[3]
    mip3_w, mip3_h = width // 8, height // 8
    mip3_len = mip3_w * mip3_h
    palette_count_off = mip3_off + mip3_len
    (palette_count,) = struct.unpack_from("<H", lump, palette_count_off)
    if palette_count != 256:
        raise ValueError(f"{name}: unexpected palette count {palette_count} (expected 256)")
    palette_off = palette_count_off + 2
    palette = lump[palette_off:palette_off + 256 * 3]
    if len(palette) != 256 * 3:
        raise ValueError(f"{name}: truncated palette ({len(palette)} != 768)")

    return name, width, height, mip0, palette


# ---------------------------------------------------------------------------
# TGA writing / reading
# ---------------------------------------------------------------------------

def write_tga(path: Path, width: int, height: int, pixels_bgr_or_bgra: bytes, *, has_alpha: bool) -> None:
    depth = 32 if has_alpha else 24
    bpp = 4 if has_alpha else 3
    assert len(pixels_bgr_or_bgra) == width * height * bpp

    image_descriptor = 0x20  # bit5 set: top-down
    if has_alpha:
        image_descriptor |= 0x08  # 8 alpha bits

    header = struct.pack(
        "<BBBHHBHHHHBB",
        0,          # id length
        0,          # colormap type
        2,          # image type: uncompressed truecolor
        0,          # colormap first entry index (part of 5-byte colormap spec)
        0,          # colormap length
        0,          # colormap entry size
        0,          # x origin
        0,          # y origin
        width,
        height,
        depth,
        image_descriptor,
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    with open(tmp, "wb") as fh:
        fh.write(header)
        fh.write(pixels_bgr_or_bgra)
    import os
    os.replace(tmp, path)


def read_tga_header(path: Path) -> dict:
    with open(path, "rb") as fh:
        header = fh.read(18)
    (idlen, cmtype, imgtype, cm_first, cm_len, cm_entry_size,
     x0, y0, width, height, depth, descriptor) = struct.unpack("<BBBHHBHHHHBB", header)
    return dict(
        idlen=idlen, cmtype=cmtype, imgtype=imgtype,
        width=width, height=height, depth=depth, descriptor=descriptor,
    )


def read_tga_pixels(path: Path) -> tuple[dict, bytes]:
    with open(path, "rb") as fh:
        data = fh.read()
    hdr = read_tga_header(path)
    bpp = hdr["depth"] // 8
    pixel_data = data[18:18 + hdr["width"] * hdr["height"] * bpp]
    return hdr, pixel_data


# ---------------------------------------------------------------------------
# Conversion
# ---------------------------------------------------------------------------

def indices_to_bgr(indices: bytes, palette: bytes) -> bytes:
    out = bytearray(len(indices) * 3)
    for i, idx in enumerate(indices):
        r = palette[idx * 3]
        g = palette[idx * 3 + 1]
        b = palette[idx * 3 + 2]
        out[i * 3] = b
        out[i * 3 + 1] = g
        out[i * 3 + 2] = r
    return bytes(out)


def indices_to_bgra(indices: bytes, palette: bytes) -> bytes:
    out = bytearray(len(indices) * 4)
    for i, idx in enumerate(indices):
        r = palette[idx * 3]
        g = palette[idx * 3 + 1]
        b = palette[idx * 3 + 2]
        a = 0 if idx == 255 else 255
        out[i * 4] = b
        out[i * 4 + 1] = g
        out[i * 4 + 2] = r
        out[i * 4 + 3] = a
    return bytes(out)


# ---------------------------------------------------------------------------
# Main extraction
# ---------------------------------------------------------------------------

def embedded_miptex(lump: bytes) -> dict:
    """lowercase name -> mip0 + palette of every embedded miptex (first one wins)."""
    out = {}
    nummiptex = struct.unpack_from("<i", lump, 0)[0]
    for doff in struct.unpack_from(f"<{nummiptex}i", lump, 4):
        if doff < 0:
            continue
        try:
            name, _w, _h, mip0, palette = extract_miptex(lump, doff)
        except ValueError:
            continue
        out.setdefault(name.lower(), mip0 + palette)
    return out


def wad_miptex(wad_path: Path) -> dict:
    data = wad_path.read_bytes()
    if data[:4] not in (b"WAD2", b"WAD3"):
        return {}
    num, diro = struct.unpack_from("<ii", data, 4)
    out = {}
    for i in range(num):
        e = diro + 32 * i
        filepos, _disk, _size, typ = struct.unpack_from("<iiiB", data, e)
        if typ != 0x43:
            continue
        try:
            name, _w, _h, mip0, palette = extract_miptex(data, filepos)
        except (ValueError, struct.error):
            continue
        out.setdefault(name.lower(), mip0 + palette)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--lang", required=True, help="language code from langpack_common.LANGUAGES")
    args = ap.parse_args()

    cfg = langpack_common.get_language(args.lang)
    mod_maps_dir = cfg.mod_root / "cryoffear" / "maps"
    canon_game = langpack_common.CANONICAL_ROOT / "cryoffear"
    out_dir = langpack_common.textures_dir(args.lang)
    out_dir.mkdir(parents=True, exist_ok=True)
    for stale in out_dir.glob("*.tga"):
        stale.unlink()

    # every canonical image of every name: embedded in any map, or in a WAD
    canon_any = {}
    for bsp in sorted((canon_game / "maps").glob("*.bsp")):
        for name, blob in embedded_miptex(read_texture_lump(bsp)).items():
            canon_any.setdefault(name, set()).add(blob)
    for wad in sorted(canon_game.glob("*.wad")):
        for name, blob in wad_miptex(wad).items():
            canon_any.setdefault(name, set()).add(blob)

    # candidates: translation map vs the same canonical map, per name
    cand = {}
    display = {}
    dims = {}
    for mod_bsp in sorted(mod_maps_dir.glob("*.bsp"), key=lambda p: p.name.lower()):
        canon_bsp = langpack_common.find_ci(canon_game / "maps" / mod_bsp.name)
        if canon_bsp is None:
            continue
        mlump = read_texture_lump(mod_bsp)
        clump = embedded_miptex(read_texture_lump(canon_bsp))
        nummiptex = struct.unpack_from("<i", mlump, 0)[0]
        seen = set()
        for doff in struct.unpack_from(f"<{nummiptex}i", mlump, 4):
            if doff < 0:
                continue
            try:
                name, w, h, mip0, palette = extract_miptex(mlump, doff)
            except ValueError:
                continue
            key = name.lower()
            if key in seen:
                continue
            seen.add(key)
            blob = mip0 + palette
            if clump.get(key) == blob:
                continue
            cand.setdefault(key, {}).setdefault(blob, []).append(mod_bsp.name)
            display.setdefault(key, name)
            dims[key] = (w, h)

    conflicts = {k: v for k, v in cand.items() if len(v) > 1}
    game_copies = sorted(k for k, v in cand.items() if len(v) == 1 and next(iter(v)) in canon_any.get(k, set()))

    written = []
    for key in sorted(cand):
        if key in conflicts or key in game_copies:
            continue
        (blob, maps), = cand[key].items()
        w, h = dims[key]
        mip0, palette = blob[:w * h], blob[w * h:]
        name = display[key]
        is_alpha = name.startswith("{")
        pixels = indices_to_bgra(mip0, palette) if is_alpha else indices_to_bgr(mip0, palette)
        out_path = out_dir / f"{name}.tga"
        write_tga(out_path, w, h, pixels, has_alpha=is_alpha)
        if langpack_common.game_identical(out_path.read_bytes()):
            raise SystemExit(f"{out_path}: byte-identical to a game file")
        hdr, px = read_tga_pixels(out_path)
        if (hdr["width"], hdr["height"]) != (w, h) or px != pixels:
            raise SystemExit(f"{out_path}: re-read mismatch")
        written.append((name, maps[0], len(maps)))

    print(f"Wrote {len(written)} repainted textures to {out_dir}")
    for name, first, n in written:
        print(f"  {name}.tga  (from {first}; {n} map(s))")
    print(f"Dropped as identical to the game's own art: {len(game_copies)} {[display[k] for k in game_copies]}")
    if conflicts:
        print("CONFLICTS (one name, several different images; not written):")
        for k, v in conflicts.items():
            print(f"  {display[k]}: " + "; ".join(",".join(m) for m in v.values()))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
