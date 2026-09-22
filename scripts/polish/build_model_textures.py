#!/usr/bin/env python3
"""Build <pack>/models/ -- translated textures of studio models, not models.

The fan translation ships 23 whole .mdl files whose only change is the
embedded textures that carry text (phone screens, newspapers, book pages,
signs). The pack carries just those textures:

    models/<model path without .mdl>/<texture name>      8-bit indexed BMP

e.g. models/weapons/mobile/v_mobile/fullbright_mess1.bmp. The engine
(patches/cof-language-packs.patch, CoF_Lang_StudioTextures) writes them into
its private copy of the model at load, before the textures are uploaded.

For every .mdl of the translation's cryoffear/models/ tree that differs from
the canonical file of the same (case-insensitive) path:
  1. both files must have the same length, header and texture table (names,
     sizes, data offsets); every byte OUTSIDE the texture pixel + palette
     blocks must be identical -- otherwise the model differs in geometry,
     animation or skins and is REPORTED and left out (exit code 1);
  2. every texture whose pixels or palette differ is a candidate; candidates
     in langpack_common.EXCLUDED_ART[<lang>]["model"] (changed for reasons
     other than translation) are left out and listed;
  3. the rest are written as 8-bit BMPs (bottom-up rows, 256-entry palette)
     through langpack_common.write_pack_file (refuses game-identical bytes)
     and read back to confirm the exact indices and palette.

Usage:
    python scripts/polish/build_model_textures.py --lang polish
"""
from __future__ import annotations

import argparse
import shutil
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import langpack_common as lc  # noqa: E402

TEX_STRUCT = 80  # mstudiotexture_t: name[64], flags, width, height, index


def texture_table(data: bytes) -> list[dict]:
    if data[:4] != b"IDST":
        raise ValueError("not a studio model")
    num, tindex, _tdata = struct.unpack_from("<3i", data, 180)
    out = []
    for i in range(num):
        o = tindex + TEX_STRUCT * i
        name = data[o:o + 64].split(b"\0")[0].decode("latin1")
        flags, w, h, idx = struct.unpack_from("<4i", data, o + 64)
        out.append(dict(name=name, flags=flags, w=w, h=h, idx=idx))
    return out


def bmp8(w: int, h: int, pixels: bytes, palette: bytes) -> bytes:
    row = (w + 3) & ~3
    pal = b"".join(bytes((palette[i * 3 + 2], palette[i * 3 + 1], palette[i * 3], 0)) for i in range(256))
    off = 14 + 40 + len(pal)
    size = off + row * h
    fh = b"BM" + struct.pack("<IHHI", size, 0, 0, off)
    ih = struct.pack("<IiiHHIIiiII", 40, w, h, 1, 8, 0, row * h, 2835, 2835, 256, 0)
    rows = b"".join(pixels[y * w:(y + 1) * w] + b"\0" * (row - w) for y in range(h - 1, -1, -1))
    return fh + ih + pal + rows


def read_bmp8(data: bytes) -> tuple:
    off = struct.unpack_from("<I", data, 10)[0]
    hsz, w, h, _pl, bpp, comp = struct.unpack_from("<IiiHHI", data, 14)
    assert bpp == 8 and comp == 0
    pal = data[14 + hsz:14 + hsz + 1024]
    palette = b"".join(bytes((pal[i * 4 + 2], pal[i * 4 + 1], pal[i * 4])) for i in range(256))
    row = (w + 3) & ~3
    ah = abs(h)
    rows = [data[off + y * row:off + y * row + w] for y in range(ah)]
    if h > 0:
        rows.reverse()
    return w, ah, b"".join(rows), palette


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--lang", required=True)
    args = ap.parse_args(argv)
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
    except Exception:
        pass

    cfg = lc.get_language(args.lang)
    excluded = lc.EXCLUDED_ART.get(args.lang, {}).get("model", {})
    out_root = lc.models_dir(args.lang)
    if out_root.exists():
        shutil.rmtree(out_root)

    mod_game = cfg.mod_root / "cryoffear"
    written, skipped, rejected, identical_models = [], [], [], 0
    changed_models = 0
    for src in sorted((mod_game / "models").rglob("*"), key=lambda p: p.as_posix().lower()):
        if not src.is_file() or src.suffix.lower() != ".mdl":
            continue
        rel = src.relative_to(mod_game).as_posix()          # models/.../x.mdl
        canon = lc.find_ci(lc.CANONICAL_ROOT / "cryoffear" / rel)
        if canon is None:
            rejected.append((rel, "no canonical model of that path"))
            continue
        a, b = src.read_bytes(), canon.read_bytes()
        if a == b:
            identical_models += 1
            continue
        changed_models += 1
        try:
            ta, tb = texture_table(a), texture_table(b)
        except (ValueError, struct.error) as exc:
            rejected.append((rel, f"unreadable: {exc}"))
            continue
        if len(a) != len(b) or [(t["name"], t["w"], t["h"], t["idx"]) for t in ta] != \
                [(t["name"], t["w"], t["h"], t["idx"]) for t in tb]:
            rejected.append((rel, "different length or texture table: not a texture-only change"))
            continue
        # every byte outside the texel + palette blocks must match
        mask = bytearray(len(a))
        for t in ta:
            e = t["idx"] + t["w"] * t["h"] + 768
            mask[t["idx"]:e] = b"\1" * (e - t["idx"])
        other = sum(1 for i in range(len(a)) if not mask[i] and a[i] != b[i]) if a != b else 0
        if other:
            rejected.append((rel, f"{other} byte(s) differ outside the textures (geometry/animation/skins)"))
            continue
        model_base = rel[:-4]                                 # models/.../x
        for t, u in zip(ta, tb):
            s, n = t["idx"], t["w"] * t["h"]
            if a[s:s + n + 768] == b[s:s + n + 768]:
                continue
            key = f"{rel.lower()}:{t['name'].lower()}"
            reason = excluded.get(key) or excluded.get(f"*:{t['name'].lower()}")
            if reason:
                skipped.append((rel, t["name"], reason))
                continue
            pixels, palette = a[s:s + n], a[s + n:s + n + 768]
            name = t["name"] if t["name"].lower().endswith(".bmp") else t["name"] + ".bmp"
            out = lc.lang_pack_dir(args.lang) / model_base / name
            data = bmp8(t["w"], t["h"], pixels, palette)
            lc.write_pack_file(out, data)
            if read_bmp8(out.read_bytes()) != (t["w"], t["h"], pixels, palette):
                raise SystemExit(f"{out}: read-back mismatch")
            written.append((rel, t["name"], t["w"], t["h"]))

    print(f"translation models differing from the game: {changed_models} (identical: {identical_models})")
    print(f"model textures written: {len(written)}")
    for rel, name, w, h in written:
        print(f"  {rel[:-4]}/{name}  {w}x{h}")
    print(f"left out (review list, not a translation): {len(skipped)}")
    for rel, name, why in skipped:
        print(f"  {rel}:{name}: {why}")
    if rejected:
        print(f"MODELS LEFT OUT (not texture-only): {len(rejected)}")
        for rel, why in rejected:
            print(f"  {rel}: {why}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
