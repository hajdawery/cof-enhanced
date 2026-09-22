#!/usr/bin/env python3
"""Build <pack>/overlay/ -- the translated interface images (TGA), same path.

Part 4 of the native language-pack generator suite. The engine pushes
languages/<code>/overlay/cryoffear/ onto the search path, so a file here
replaces the game's image of the same cryoffear-relative path.

Since the pack reduction (lang3, 2026-09-22) this step:
  * derives its list directly from the two trees (no analysis files): every
    .tga under the translation's cryoffear/ and platform/ trees that has a
    canonical counterpart (case-insensitive path) and different bytes;
  * skips the repainted bitmap-font strips (gfx/vgui/fonts/), which the pack
    replaces with its own code-page-aware font rendering;
  * decodes both images and skips a file whose PIXELS equal the game's (a
    re-encoded copy of the game's art, not a translation);
  * skips everything in langpack_common.EXCLUDED_ART[<lang>]["overlay"] (art
    changed for reasons other than translation; listed in the pack README);
  * copies what is left byte for byte (the translators' own files), through
    langpack_common.write_pack_file, which refuses anything identical to a
    game file;
  * ships NO models: translated model textures are models/ (see
    build_model_textures.py), never whole .mdl files.

Usage:
    python scripts/polish/copy_overlay_assets.py --lang polish
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import langpack_common as lc  # noqa: E402

TREES = ("cryoffear", "platform")
FONT_DIR = "cryoffear/gfx/vgui/fonts/"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--lang", required=True)
    args = ap.parse_args(argv)
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
    except Exception:
        pass

    cfg = lc.get_language(args.lang)
    excluded = lc.EXCLUDED_ART.get(args.lang, {}).get("overlay", {})
    out_root = lc.overlay_dir(args.lang)
    if out_root.exists():
        shutil.rmtree(out_root)

    copied, same_pixels, fonts, no_canon, skipped_review = [], [], [], [], []
    for tree in TREES:
        base = cfg.mod_root / tree
        if not base.is_dir():
            continue
        for src in sorted(base.rglob("*"), key=lambda p: p.as_posix().lower()):
            if not src.is_file() or src.suffix.lower() != ".tga":
                continue
            rel = src.relative_to(cfg.mod_root).as_posix()
            low = rel.lower()
            if low.startswith(FONT_DIR):
                fonts.append(rel)
                continue
            canon = lc.find_ci(lc.CANONICAL_ROOT / rel)
            if canon is None:
                no_canon.append(rel)
                continue
            data = src.read_bytes()
            cdata = canon.read_bytes()
            if data == cdata:
                continue
            try:
                if lc.decode_tga(data) == lc.decode_tga(cdata):
                    same_pixels.append(rel)
                    continue
            except ValueError as exc:
                raise SystemExit(f"{rel}: {exc}")
            if low in excluded:
                skipped_review.append((rel, excluded[low]))
                continue
            lc.write_pack_file(out_root / rel, data)
            copied.append(rel)

    print(f"overlay TGAs copied (translated): {len(copied)}")
    print(f"skipped, pixel-identical to the game: {len(same_pixels)} {same_pixels}")
    print(f"skipped, bitmap-font strips: {len(fonts)}")
    print(f"skipped, no canonical counterpart: {len(no_canon)} {no_canon}")
    print(f"skipped, review list (not a translation): {len(skipped_review)}")
    for rel, why in skipped_review:
        print(f"  {rel}: {why}")
    missing = sorted(set(excluded) - {r.lower() for r, _ in skipped_review})
    if missing:
        print(f"WARNING: review entries that matched nothing: {missing}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
