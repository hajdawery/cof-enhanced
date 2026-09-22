#!/usr/bin/env python3
"""Extract the repainted sign/poster textures embedded in the Polish mod's BSP
files as standalone TGA images, one file per unique texture name.

Part 3 of 6 of the Cry of Fear native Polish language pack. See
scripts/polish/README.md section "Engine texture-override path (part 3)" for
the full engine-citation context on why this pack-internal ``textures/``
folder maps to the real deploy path ``cryoffear/materials/common/<name>.tga``
at runtime.

Source of truth for *which* 110 names to extract and *which* map to pull each
one from is
``stage1/polish-mod-analysis-20260922/bsp/texture_crossref.json``
(``changed_texture_names`` + ``per_map``), cross-checked against
``analysis.json``'s per-map ``textures.changed[].mod`` width/height records.
BSP_ANALYSIS.md section 3 established that every repainted miptex blob is
byte-identical across all maps that contain it, so extracting one
representative map per name is sufficient (and this script spot-checks that
assumption -- see ``_sanity_check_cross_map_identical``).

GoldSrc BSP TEXTURES lump (lump index 2) format, all little-endian:

    int32 nummiptex
    int32 dataofs[nummiptex]          -- offset from lump start, or -1 if absent

Each dataofs[i] (if >= 0) points to a mip_t:

    char   name[16]
    uint32 width, height
    uint32 offsets[4]                 -- offset from START OF THIS mip_t

If offsets[0] > 0 the texture is embedded: width*height bytes of palette
index at dataofs[i]+offsets[0] (mip 0, row-major top-to-bottom), followed by
mips 1-3 (half-size each), followed by a uint16 palette count (256) and then
count*3 bytes of RGB palette.

Alpha masking: a texture name starting with ``{`` uses palette index 255 as
a transparency key (alpha=0 for that index, alpha=255 otherwise) per GoldSrc
convention, and is written as a 32-bit BGRA TGA. All other textures are
written as 24-bit BGR TGA. The engine only ever special-cases a leading
``*``, never ``{``, when building the replacement path, so the literal ``{``
is kept in the output filename.

Usage:
    python scripts/polish/extract_sign_textures.py --lang polish
"""
from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path
from typing import Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
import langpack_common  # noqa: E402

ANALYSIS_BSP_DIR = langpack_common.ANALYSIS_ROOT / "bsp"
CROSSREF_JSON = ANALYSIS_BSP_DIR / "texture_crossref.json"
ANALYSIS_JSON = ANALYSIS_BSP_DIR / "analysis.json"

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

def load_crossref() -> dict:
    with open(CROSSREF_JSON, "r", encoding="utf-8") as fh:
        return json.load(fh)


def load_analysis() -> dict:
    with open(ANALYSIS_JSON, "r", encoding="utf-8") as fh:
        return json.load(fh)


def build_representative_map(crossref: dict) -> dict[str, str]:
    """name -> one map filename from per_map that contains it (first hit,
    in per_map's insertion order, which is deterministic)."""
    per_map = crossref["per_map"]
    rep: dict[str, str] = {}
    for mapname, names in per_map.items():
        for n in names:
            if n not in rep:
                rep[n] = mapname
    return rep


def build_analysis_dims(analysis: dict) -> dict[tuple[str, str], tuple[int, int]]:
    """(mapname, texname) -> (width, height) from analysis.json's mod dims."""
    out: dict[tuple[str, str], tuple[int, int]] = {}
    for m in analysis["maps"]:
        mapname = m["map"]
        changed = m.get("textures", {}).get("changed") or []
        for entry in changed:
            name = entry["name"]
            mod_variants = entry.get("mod") or []
            if not mod_variants:
                continue
            w, h, _has_mip0 = mod_variants[0]
            out[(mapname, name)] = (w, h)
    return out


def sanity_check_cross_map_identical(crossref: dict, mod_maps_dir: Path, name: str) -> Optional[bool]:
    """Pick a texture name that appears in >=2 maps, extract raw mip0+palette
    bytes from two different maps, and compare. Returns True/False/None
    (None if fewer than 2 maps contain it)."""
    maps_with_name = [m for m, names in crossref["per_map"].items() if name in names]
    if len(maps_with_name) < 2:
        return None
    blobs = []
    for mapname in maps_with_name[:2]:
        lump = read_texture_lump(mod_maps_dir / mapname)
        doff = find_miptex_offset(lump, name)
        _n, _w, _h, mip0, palette = extract_miptex(lump, doff)
        blobs.append(mip0 + palette)
    return blobs[0] == blobs[1]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--lang", default="polish", help="language code (default: polish)")
    args = ap.parse_args()

    cfg = langpack_common.get_language(args.lang)
    mod_maps_dir = cfg.mod_root / "cryoffear" / "maps"
    out_dir = langpack_common.textures_dir(args.lang)
    out_dir.mkdir(parents=True, exist_ok=True)

    crossref = load_crossref()
    names = crossref["changed_texture_names"]
    assert len(names) == len(set(names)), "duplicate names in changed_texture_names"
    assert len(names) == 110, f"expected 110 names, got {len(names)}"

    braced = sorted(n for n in names if n.startswith("{"))
    print(f"Alpha-masked ({{-prefixed) names: {braced}")

    rep_map = build_representative_map(crossref)
    missing_rep = [n for n in names if n not in rep_map]
    if missing_rep:
        raise SystemExit(f"No representative map found for: {missing_rep}")

    analysis = load_analysis()
    analysis_dims = build_analysis_dims(analysis)

    # Cache parsed TEXTURES lumps per map (many names share a representative map).
    lump_cache: dict[str, bytes] = {}

    written = []
    dim_mismatches = []
    parse_failures = []

    for name in names:
        mapname = rep_map[name]
        try:
            lump = lump_cache.get(mapname)
            if lump is None:
                lump = read_texture_lump(mod_maps_dir / mapname)
                lump_cache[mapname] = lump
            doff = find_miptex_offset(lump, name)
            mip_name, width, height, mip0, palette = extract_miptex(lump, doff)
        except Exception as exc:  # noqa: BLE001
            parse_failures.append((name, mapname, str(exc)))
            continue

        expected = analysis_dims.get((mapname, name))
        if expected is not None and expected != (width, height):
            dim_mismatches.append((name, mapname, expected, (width, height)))

        is_alpha = name.startswith("{")
        if is_alpha:
            pixels = indices_to_bgra(mip0, palette)
        else:
            pixels = indices_to_bgr(mip0, palette)

        out_path = out_dir / f"{name}.tga"
        write_tga(out_path, width, height, pixels, has_alpha=is_alpha)
        written.append((name, mapname, width, height, is_alpha))

    print(f"Wrote {len(written)} / {len(names)} textures to {out_dir}")

    if parse_failures:
        print("PARSE FAILURES:")
        for name, mapname, err in parse_failures:
            print(f"  {name} (from {mapname}): {err}")

    if dim_mismatches:
        print("DIMENSION MISMATCHES vs analysis.json:")
        for name, mapname, expected, got in dim_mismatches:
            print(f"  {name} (from {mapname}): expected {expected}, got {got}")

    # --- Self-verification pass: re-read every written TGA -----------------
    verify_errors = []
    alpha_report = []
    out_files = sorted(out_dir.glob("*.tga"))
    if len(out_files) != 110:
        verify_errors.append(f"Expected 110 output files, found {len(out_files)}")

    written_by_name = {w[0]: w for w in written}
    for f in out_files:
        name = f.stem
        if name not in written_by_name:
            verify_errors.append(f"Unexpected extra output file: {f.name}")
            continue
        _n, mapname, exp_w, exp_h, is_alpha = written_by_name[name]
        hdr, pixel_data = read_tga_pixels(f)
        if hdr["width"] != exp_w or hdr["height"] != exp_h:
            verify_errors.append(
                f"{f.name}: header dims {(hdr['width'], hdr['height'])} != expected {(exp_w, exp_h)}"
            )
        exp_depth = 32 if is_alpha else 24
        if hdr["depth"] != exp_depth:
            verify_errors.append(f"{f.name}: depth {hdr['depth']} != expected {exp_depth}")
        if not (hdr["descriptor"] & 0x20):
            verify_errors.append(f"{f.name}: top-down bit not set in image descriptor")

        if is_alpha:
            bpp = 4
            npix = hdr["width"] * hdr["height"]
            alpha_bytes = pixel_data[3::bpp]
            transparent_count = sum(1 for a in alpha_bytes if a == 0)
            opaque_count = npix - transparent_count
            if transparent_count > 0:
                # verify alpha=0 exactly where pixel used palette index 255
                lump = lump_cache[mapname]
                doff = find_miptex_offset(lump, name)
                _n2, _w2, _h2, mip0, _pal = extract_miptex(lump, doff)
                idx255_count = sum(1 for b in mip0 if b == 255)
                if idx255_count != transparent_count:
                    verify_errors.append(
                        f"{f.name}: transparent pixel count {transparent_count} != "
                        f"palette-index-255 usage count {idx255_count}"
                    )
                alpha_report.append((name, transparent_count, npix))
            else:
                alpha_report.append((name, 0, npix))

    print("\nAlpha-masked texture verification:")
    for name, transparent_count, npix in alpha_report:
        if transparent_count > 0:
            print(f"  {name}: {transparent_count}/{npix} pixels transparent (index 255 used) - OK")
        else:
            print(f"  {name}: index 255 NOT used in this image (0 transparent pixels) - not an error")

    if verify_errors:
        print("\nVERIFICATION ERRORS:")
        for e in verify_errors:
            print(f"  {e}")
    else:
        print("\nSelf-verification: all checks passed.")

    # --- Cross-map identical sanity check -----------------------------------
    print("\nCross-map identical sanity check:")
    checked = 0
    for name in names:
        maps_with_name = [m for m, ns in crossref["per_map"].items() if name in ns]
        if len(maps_with_name) >= 2:
            result = sanity_check_cross_map_identical(crossref, mod_maps_dir, name)
            print(f"  {name}: compared {maps_with_name[0]} vs {maps_with_name[1]} -> "
                  f"{'IDENTICAL' if result else 'DIFFERENT!'}")
            checked += 1
            if checked >= 3:
                break

    if parse_failures or dim_mismatches or verify_errors:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
