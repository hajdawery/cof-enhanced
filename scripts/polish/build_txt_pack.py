#!/usr/bin/env python3
"""Build pack/languages/<lang>/txt/ and pack/languages/<lang>/inventoryitems/.

Part 1 of the native Cry of Fear language-pack generator suite: text files
only (no maps/.ent, textures, overlay assets, or DLL strings -- those are
built by the other scripts named in scripts/polish/README.md).

TASK A -- language-slot text (txt/):
    The canonical game already understands a per-language folder mechanism:
        cryoffear/txtfiles/languages/<lang>/   (9 files)
        cryoffear/notes/languages/<lang>/      (8 files)
    demonstrated by the existing dutch/french/german/norwegian/spanish/swedish
    folders. The mod instead ships its Polish text by overwriting the ROOT
    cryoffear/txtfiles/*.txt and cryoffear/notes/*.txt files. This script
    takes those same mod bytes and places them into the additive
    languages/<lang>/ slot instead, verbatim (no re-encoding -- the source
    bytes are already confirmed clean cp1250).

    credits.txt ships in the mod but has NO per-language folder slot in
    canonical (the base game never localizes credits.txt) -- it is
    deliberately excluded from txt/.

TASK B -- inventory item texts (inventoryitems/):
    Copies all cryoffear/inventoryitems/**/*.txt (incl. ammo/, weapons/)
    verbatim, EXCEPT two known-anomalous source files which are corrected
    in-flight (see _load_inventory_item_bytes docstring):
        weapons/weapon_sledgeshovel.txt  -- source is UTF-8, re-encoded to cp1250
        valve.txt                        -- source has a UTF-8-in-cp1250 mojibake
                                             bug ("ZawĂłr" -> "Zawór") fixed in-flight

Usage:
    python build_txt_pack.py --lang polish

Idempotent: safe to re-run, overwrites output files in place. Does not
require the game to run and never touches the read-only source trees.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import langpack_common as lc  # noqa: E402

# ---------------------------------------------------------------------------
# Task A: language-slot text file lists
# ---------------------------------------------------------------------------

# Canonical-relative subdirectories that hold the per-language folders, and
# the mod-root-relative source file each list of names is expected to
# overwrite at the flat root (mod ships these as root overwrites, not as a
# languages/<lang>/ folder of its own).
TXTFILES_SUBDIR = "txtfiles"
NOTES_SUBDIR = "notes"

# credits.txt exists in the mod's txtfiles/ but has no per-language folder
# slot anywhere in canonical -- deliberately excluded from TASK A.
EXCLUDED_FROM_LANGUAGE_SLOT = {"credits.txt"}


def _list_canonical_language_files(subdir: str, reference_lang: str = "german") -> list[str]:
    """Programmatically discover the authoritative filename list for a
    txtfiles/languages/<reference_lang>/ or notes/languages/<reference_lang>/
    folder in the canonical game tree, instead of hardcoding it.
    """
    ref_dir = lc.CANONICAL_ROOT / "cryoffear" / subdir / "languages" / reference_lang
    if not ref_dir.is_dir():
        raise SystemExit(f"Expected canonical reference folder missing: {ref_dir}")
    names = sorted(p.name for p in ref_dir.iterdir() if p.is_file())
    if not names:
        raise SystemExit(f"Canonical reference folder is empty: {ref_dir}")
    return names


def _verify_cp1250_clean(data: bytes, label: str) -> None:
    try:
        data.decode("cp1250")
    except UnicodeDecodeError as exc:
        raise SystemExit(f"{label}: expected clean cp1250 source but decode failed: {exc}")


def build_language_slot_text(lang: str, cfg: "lc.LanguageConfig") -> dict:
    """TASK A. Returns a small report dict for the caller to print/aggregate."""
    mod_root = cfg.mod_root
    out_base = lc.txt_dir(lang)

    report = {
        "txtfiles_written": [],
        "notes_written": [],
        "missing_from_mod_vs_german": {"txtfiles": [], "notes": []},
        "extra_beyond_expected": {"txtfiles": [], "notes": []},
        "credits_excluded": False,
    }

    for subdir, out_subpath, report_key in (
        (TXTFILES_SUBDIR, "txtfiles/languages/{lang}", "txtfiles_written"),
        (NOTES_SUBDIR, "notes/languages/{lang}", "notes_written"),
    ):
        expected_names = _list_canonical_language_files(subdir)
        mod_dir = mod_root / "cryoffear" / subdir
        if not mod_dir.is_dir():
            raise SystemExit(f"Mod source folder missing: {mod_dir}")

        mod_names = sorted(
            p.name for p in mod_dir.iterdir() if p.is_file() and p.suffix.lower() == ".txt"
        )

        # credits.txt (txtfiles only) is expected to be present in the mod
        # but excluded from the language-slot output -- everything else the
        # mod ships at this root should be one of the canonical language
        # filenames (a superset check).
        mod_names_for_slot = [n for n in mod_names if n not in EXCLUDED_FROM_LANGUAGE_SLOT]
        if "credits.txt" in mod_names:
            report["credits_excluded"] = True

        missing = sorted(set(expected_names) - set(mod_names_for_slot))
        extra = sorted(set(mod_names_for_slot) - set(expected_names))
        report["missing_from_mod_vs_german"][subdir if subdir != TXTFILES_SUBDIR else "txtfiles"] = missing
        report["extra_beyond_expected"][subdir if subdir != TXTFILES_SUBDIR else "txtfiles"] = extra

        out_dir = out_base / out_subpath.format(lang=lang)
        out_dir.mkdir(parents=True, exist_ok=True)

        for name in expected_names:
            src = mod_dir / name
            if not src.is_file():
                # Reported above as "missing"; nothing to write for this name.
                continue
            data = src.read_bytes()
            _verify_cp1250_clean(data, f"{subdir}/{name}")
            dest = out_dir / name
            lc.write_bytes_atomic(dest, data)
            report[report_key].append(str(dest))

    return report


# ---------------------------------------------------------------------------
# Task B: inventory item text files
# ---------------------------------------------------------------------------

# mod-root-relative paths (relative to cryoffear/inventoryitems/) with known
# byte-level anomalies that must be corrected in-flight rather than copied
# verbatim. See TEXT_ANALYSIS.md sections "Table 4" and "0. Summary".
ANOMALOUS_FILES = {
    "weapons/weapon_sledgeshovel.txt",
    "valve.txt",
}


def _fix_sledgeshovel(data: bytes) -> bytes:
    """Source is actually UTF-8 (contains byte 0x81, undefined in cp1250).
    Decode UTF-8, re-encode cp1250 for the output byte stream.
    """
    text = data.decode("utf-8")
    return text.encode("cp1250")


def build_inventory_items(lang: str, cfg: "lc.LanguageConfig") -> dict:
    """TASK B. Returns a small report dict for the caller to print/aggregate."""
    mod_root = cfg.mod_root
    src_base = mod_root / "cryoffear" / "inventoryitems"
    out_base = lc.inventoryitems_dir(lang)

    if not src_base.is_dir():
        raise SystemExit(f"Mod source folder missing: {src_base}")

    src_files = sorted(p for p in src_base.rglob("*.txt") if p.is_file())

    report = {
        "written": [],
        "anomalies_fixed": [],
    }

    for src in src_files:
        rel = src.relative_to(src_base).as_posix()
        data = src.read_bytes()

        if rel == "weapons/weapon_sledgeshovel.txt":
            out_bytes = _fix_sledgeshovel(data)
            # round-trip sanity check
            _verify_cp1250_clean(out_bytes, rel)
            assert out_bytes.decode("cp1250") == data.decode("utf-8"), (
                "weapon_sledgeshovel.txt: cp1250 round-trip text mismatch"
            )
            report["anomalies_fixed"].append(rel)
        elif rel == "valve.txt":
            # Pre-flight: confirm exact known mojibake substring bytes.
            cp1250_text = data.decode("cp1250")  # must succeed per TEXT_ANALYSIS.md
            mojibake_bytes = "\xc3\xb3"  # bytes C3 B3 read one-cp1250-char-per-byte
            # Build the actual decoded substring precisely from the raw bytes
            # C3 B3 decoded individually under cp1250, to avoid relying on a
            # hand-typed literal.
            broken_substring = bytes([0xC3, 0xB3]).decode("cp1250")
            count = cp1250_text.count(broken_substring)
            if count != 1:
                raise SystemExit(
                    f"valve.txt: expected exactly 1 occurrence of mojibake substring "
                    f"{broken_substring!r}, found {count}"
                )
            fixed_text = cp1250_text.replace(broken_substring, "ó")
            print("[valve.txt] corrected line preview:")
            for line in fixed_text.splitlines():
                if "ó" in line.lower() or "zaw" in line.lower():
                    print("   ", line)
            out_bytes = fixed_text.encode("cp1250")
            _verify_cp1250_clean(out_bytes, rel)
            report["anomalies_fixed"].append(rel)
        else:
            _verify_cp1250_clean(data, rel)
            out_bytes = data

        dest = out_base / rel
        lc.write_bytes_atomic(dest, out_bytes)
        report["written"].append(str(dest))

    return report


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--lang",
        required=True,
        help="Language code from langpack_common.LANGUAGES (e.g. polish). Required -- no default.",
    )
    args = parser.parse_args(argv)

    cfg = lc.get_language(args.lang)

    print(f"=== TASK A: language-slot text ({args.lang}) ===")
    report_a = build_language_slot_text(args.lang, cfg)
    print(f"  txtfiles/languages/{args.lang}: {len(report_a['txtfiles_written'])} files written")
    print(f"  notes/languages/{args.lang}: {len(report_a['notes_written'])} files written")
    print(f"  credits.txt present in mod and excluded from slot: {report_a['credits_excluded']}")
    for kind in ("txtfiles", "notes"):
        missing = report_a["missing_from_mod_vs_german"][kind]
        extra = report_a["extra_beyond_expected"][kind]
        if missing:
            print(f"  WARNING: {kind} missing vs german reference: {missing}")
        if extra:
            print(f"  WARNING: {kind} unexpected extra files beyond spec: {extra}")

    print(f"=== TASK B: inventory item texts ({args.lang}) ===")
    report_b = build_inventory_items(args.lang, cfg)
    print(f"  inventoryitems: {len(report_b['written'])} files written")
    print(f"  anomalies fixed: {report_b['anomalies_fixed']}")

    # Final sanity pass: every output file under both trees must decode
    # cleanly as cp1250.
    all_out_files = list((lc.txt_dir(args.lang)).rglob("*.txt")) + list(
        (lc.inventoryitems_dir(args.lang)).rglob("*.txt")
    )
    bad = []
    for f in all_out_files:
        try:
            f.read_bytes().decode("cp1250")
        except UnicodeDecodeError as exc:
            bad.append((str(f), str(exc)))
    if bad:
        print("ERROR: output files that failed final cp1250 sanity check:")
        for path, err in bad:
            print(f"  {path}: {err}")
        return 1

    print(f"OK: {len(all_out_files)} total output .txt files, all decode cleanly as cp1250.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
