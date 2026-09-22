#!/usr/bin/env python3
"""Build pack/languages/<lang>/overlay/ -- verbatim changed TGA + MDL assets.

Part 4 of 6 of the native Cry of Fear language-pack generator suite. Copies
every mod-changed `.tga` (excluding `gfx\\vgui\\fonts\\`, which is a separate
worker's scope) and every mod-changed `.mdl` file byte-for-byte into
pack/languages/<lang>/overlay/<cryoffear-or-platform-relative-path>, mirroring
the mod root's own two top-level trees (`cryoffear\\` and `platform\\`).

Source of truth for "changed" (mod hash != canonical hash at the same
relative path) is the machine-readable compare data produced by the asset
analysis, NOT a re-derivation from scratch:
    stage1/polish-mod-analysis-20260922/assets/data/tga_compare.json
    stage1/polish-mod-analysis-20260922/assets/data/mdl_compare.json
Each entry has a "rel" key (mod-root-relative path, backslash-separated) and
an "identical" bool; changed == (not identical). See
stage1/polish-mod-analysis-20260922/assets/ASSETS_ANALYSIS.md for the full
writeup (202 TGA + 23 MDL changed, expected totals).

Guardrails enforced at runtime (see _load_changed_rels and main):
  - zero source paths under gfx\\vgui\\fonts\\ (font TGAs are out of scope;
    the analysis doc's 202 count already excludes that folder)
  - output extensions are only .tga / .mdl (no .chw/.res/.scr/media/exe/dll)
  - every copied file's SHA-256 matches its mod source (straight-copy proof)
  - every copied file's SHA-256 differs from the canonical file at the same
    relative path (proof we only copied genuinely "changed" files)

Usage:
    python copy_overlay_assets.py --lang polish

Idempotent: safe to re-run, overwrites output files in place (same bytes).
Read-only against Cry of Fear/ and cof-spolszczenie-fanmade/; only writes
under pack/languages/<lang>/overlay/.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import langpack_common as lc  # noqa: E402

ANALYSIS_DATA_DIR = lc.ANALYSIS_ROOT / "assets" / "data"
TGA_COMPARE_JSON = ANALYSIS_DATA_DIR / "tga_compare.json"
MDL_COMPARE_JSON = ANALYSIS_DATA_DIR / "mdl_compare.json"

EXPECTED_TGA_COUNT = 202
EXPECTED_MDL_COUNT = 23

FONT_DIR_MARKER = "gfx\\vgui\\fonts\\"


def _load_changed_rels(json_path: Path, ext: str) -> list[str]:
    """Return the list of mod-root-relative paths with identical == False.

    ext is the expected lowercase extension (without dot); every entry is
    asserted to end with it, as a defensive check against the source JSON
    ever mixing in another asset type.
    """
    if not json_path.is_file():
        raise SystemExit(f"Missing source compare data: {json_path}")
    data = json.loads(json_path.read_text(encoding="utf-8"))
    changed = [entry["rel"] for entry in data if not entry["identical"]]

    bad_ext = [rel for rel in changed if not rel.lower().endswith("." + ext)]
    if bad_ext:
        raise SystemExit(
            f"{json_path.name}: found non-.{ext} paths in changed set (unexpected asset "
            f"type leaked in): {bad_ext}"
        )

    if ext == "tga":
        font_paths = [rel for rel in changed if FONT_DIR_MARKER in rel.lower()]
        if font_paths:
            raise SystemExit(
                "DISCREPANCY: found gfx\\vgui\\fonts\\ paths in tga_compare.json's changed "
                f"set (expected zero per ASSETS_ANALYSIS.md scope): {font_paths}"
            )

    return changed


def _copy_one(mod_root: Path, canonical_root: Path, out_root: Path, rel: str) -> dict:
    """Copy one mod-root-relative file verbatim into out_root, verify hashes.

    Returns a small report dict; raises SystemExit on any verification
    failure (wrong bytes copied, or destination turns out identical to
    canonical after all).
    """
    src = mod_root / rel
    canon = canonical_root / rel
    dest = out_root / rel

    if not src.is_file():
        raise SystemExit(f"Mod source file missing (should exist per compare data): {src}")

    data = src.read_bytes()
    lc.write_bytes_atomic(dest, data)

    src_hash = lc.sha256_file(src)
    dest_hash = lc.sha256_file(dest)
    if dest_hash != src_hash:
        raise SystemExit(
            f"VERIFY FAILED: destination hash != mod source hash for {rel}\n"
            f"  src:  {src_hash}\n  dest: {dest_hash}"
        )

    canon_hash = None
    if canon.is_file():
        canon_hash = lc.sha256_file(canon)
        if canon_hash == dest_hash:
            raise SystemExit(
                f"VERIFY FAILED: destination hash == canonical hash for {rel} "
                "(this file is not actually changed; refusing to treat it as an overlay asset)"
            )
    else:
        raise SystemExit(
            f"VERIFY FAILED: no canonical counterpart exists at {canon} "
            f"(compare data should only include files with a canonical match)"
        )

    return {"rel": rel, "dest": str(dest), "src_hash": src_hash, "canon_hash": canon_hash}


def copy_overlay_assets(lang: str, cfg: "lc.LanguageConfig") -> dict:
    mod_root = cfg.mod_root
    canonical_root = lc.CANONICAL_ROOT
    out_root = lc.overlay_dir(lang)

    tga_rels = _load_changed_rels(TGA_COMPARE_JSON, "tga")
    mdl_rels = _load_changed_rels(MDL_COMPARE_JSON, "mdl")

    report = {
        "tga_copied": [],
        "mdl_copied": [],
        "tga_expected": EXPECTED_TGA_COUNT,
        "mdl_expected": EXPECTED_MDL_COUNT,
        "failures": [],
    }

    for rel in tga_rels:
        info = _copy_one(mod_root, canonical_root, out_root, rel)
        report["tga_copied"].append(info)

    for rel in mdl_rels:
        info = _copy_one(mod_root, canonical_root, out_root, rel)
        report["mdl_copied"].append(info)

    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--lang",
        required=True,
        help="Language code from langpack_common.LANGUAGES (e.g. polish). Required -- no default.",
    )
    args = parser.parse_args(argv)

    cfg = lc.get_language(args.lang)

    print(f"=== overlay assets (TGA + MDL) for --lang {args.lang} ===")
    report = copy_overlay_assets(args.lang, cfg)

    n_tga = len(report["tga_copied"])
    n_mdl = len(report["mdl_copied"])
    print(f"  TGA copied: {n_tga} (expected {report['tga_expected']})")
    print(f"  MDL copied: {n_mdl} (expected {report['mdl_expected']})")
    if n_tga != report["tga_expected"]:
        print(f"  DISCREPANCY: TGA count {n_tga} != expected {report['tga_expected']}")
    if n_mdl != report["mdl_expected"]:
        print(f"  DISCREPANCY: MDL count {n_mdl} != expected {report['mdl_expected']}")

    # Defensive final sweep: every file actually present under overlay/ must
    # be one we just verified (extension-only check on the produced tree,
    # to catch any stale file left over from a previous run with different
    # scope).
    out_root = lc.overlay_dir(args.lang)
    all_out_files = sorted(p for p in out_root.rglob("*") if p.is_file())
    bad_ext = [str(p) for p in all_out_files if p.suffix.lower() not in (".tga", ".mdl")]
    if bad_ext:
        print("ERROR: overlay/ contains files with unexpected extensions:")
        for p in bad_ext:
            print(f"  {p}")
        return 1

    expected_dest_count = n_tga + n_mdl
    if len(all_out_files) != expected_dest_count:
        print(
            f"WARNING: overlay/ contains {len(all_out_files)} files but this run copied "
            f"{expected_dest_count}; there may be stale files from a prior run with "
            "different scope (harmless if you know why, otherwise investigate)."
        )

    print(f"OK: {n_tga + n_mdl} total files copied and verified "
          "(hash matches mod source, hash differs from canonical).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
