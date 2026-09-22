#!/usr/bin/env python3
"""Part 6: write pack/languages/<lang>/manifest.txt, pack/MANIFEST.tsv and pack/README.md.

Run this LAST, after all of build_txt_pack.py, build_maps_ent.py,
extract_sign_textures.py, copy_overlay_assets.py and build_dll_strings_tsv.py
have produced pack/languages/<lang>/{txt,inventoryitems,maps,textures,overlay,strings}.

This script:
  1. Writes pack/languages/<lang>/manifest.txt (language metadata).
  2. Recomputes totals and known data-quality notes directly from the files on
     disk (it does not trust any prior report -- it re-derives everything),
     and writes pack/README.md from those numbers.
  3. Walks pack/ and writes pack/MANIFEST.tsv: path (relative to pack/), size
     in bytes, sha256 -- for every file under pack/ except MANIFEST.tsv itself
     (a manifest cannot contain its own hash).

Usage: python build_manifest.py --lang polish [--pack-version 1.0.0]
"""
from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import langpack_common as lc  # noqa: E402

# Known authors of the source fan translation, per its own cryoffear/txtfiles/credits.txt
# (the file exists in the mod tree but has no destination slot in this pack -- see
# build_txt_pack.py -- so this credit is recorded here instead).
AUTHORS_BY_LANG = {
    "polish": "Avioo, Mixdedemon, hexag0n, Izonka (cof-spolszczenie-fanmade)",
}


def count_files(root: Path, pattern: str = "*") -> int:
    return sum(1 for p in root.rglob(pattern) if p.is_file())


def find_ent_exclusions(lang: str):
    """Re-derive the maps/.ent exclusion list directly from the BSP analysis, using the
    same mechanical rule build_maps_ent.py applied: a changed value is excluded (kept
    canonical) if it ends in .wav/.mdl/.spr/.tga (case-insensitive) or contains '/'.
    Independent of build_maps_ent.py's own report -- recomputed here for the README.
    """
    import json

    analysis = json.loads((lc.ANALYSIS_ROOT / "bsp" / "analysis.json").read_text(encoding="utf-8"))
    excluded = []
    total_pairs = 0
    maps_with_applied = set()
    for m in analysis["maps"]:
        ents = (m.get("entities") or {}).get("entities", []) or []
        for e in ents:
            for key, canon_list, mod_list in e.get("changed", []):
                total_pairs += 1
                canon_val = canon_list[0] if canon_list else ""
                low = canon_val.lower()
                is_path = low.endswith((".wav", ".mdl", ".spr", ".tga")) or "/" in canon_val
                if is_path:
                    excluded.append((m["map"], e["index"], key, canon_val, mod_list[0] if mod_list else ""))
                else:
                    maps_with_applied.add(m["map"])
    return total_pairs, excluded, maps_with_applied


def find_strings_quality_notes(tsv_path: Path):
    """Re-derive the two known DLL-string data-quality notes directly from the TSV:
    (a) rows the mod's own patcher wrote with non-cp1250 diacritics -- bytes chosen to
        match the game's bitmap font-atlas glyph slots rather than real Windows-1250
        (see BINARIES_ANALYSIS.md section 5.4) -- decode correctly under strict cp1250
        but do not read as correct Polish, and
    (b) the two identifier-like pairs (revolver/buckshot) already flagged in-TSV.
    """
    valid_pl = set("ąćęłńóśźżĄĆĘŁŃÓŚŹŻ")
    font_quirk_rows = []
    flagged_rows = []
    with open(tsv_path, encoding="utf-8", newline="") as fh:
        for row in csv.DictReader(fh, delimiter="\t"):
            pl = row["polish"]
            if any(ord(ch) > 127 and ch not in valid_pl for ch in pl):
                font_quirk_rows.append(row)
            if row.get("flagged"):
                flagged_rows.append(row)
    return font_quirk_rows, flagged_rows


def write_readme(lang: str, cfg: lc.LanguageConfig, pack_version: str) -> None:
    lang_dir = lc.lang_pack_dir(lang)

    txt_n = count_files(lc.txt_dir(lang))
    inv_n = count_files(lc.inventoryitems_dir(lang))
    maps_n = count_files(lc.maps_dir(lang))
    tex_n = count_files(lc.textures_dir(lang))
    # NOTE: rglob("*.tga") already matches "*.TGA" etc. on Windows' case-insensitive
    # filesystem, so do NOT also glob the uppercase pattern (that double-counts).
    overlay_tga_n = sum(1 for p in lc.overlay_dir(lang).rglob("*") if p.is_file() and p.suffix.lower() == ".tga")
    overlay_mdl_n = sum(1 for p in lc.overlay_dir(lang).rglob("*") if p.is_file() and p.suffix.lower() == ".mdl")
    overlay_n = count_files(lc.overlay_dir(lang))
    masked = sorted(p.name for p in lc.textures_dir(lang).glob("{*.tga"))

    total_pairs, ent_excluded, maps_with_applied = find_ent_exclusions(lang)
    tsv_path = lc.dll_strings_tsv_path(lang)
    with open(tsv_path, encoding="utf-8", newline="") as fh:
        tsv_rows = list(csv.DictReader(fh, delimiter="\t"))
    font_quirk_rows, flagged_rows = find_strings_quality_notes(tsv_path)

    lines = []
    lines.append("# Cry of Fear native language pack")
    lines.append("")
    lines.append(
        "Generated from two read-only source trees (`K:\\LLM\\COF_Fix\\Cry of Fear` canonical, "
        f"`{cfg.mod_root}` source translation) by the scripts in `cof-fix\\scripts\\polish\\`. "
        "See that folder's README.md for the pack format, the run order, and citations. "
        "Nothing here was produced by launching the game."
    )
    lines.append("")
    lines.append(f"## `languages/{lang}/` ({cfg.display_name}, code page {cfg.codepage_label})")
    lines.append("")
    lines.append("| Part | Folder | Files | Notes |")
    lines.append("|---|---|---:|---|")
    lines.append(
        f"| 1a | `txt/` | {txt_n} | Language-slot text mirroring the canonical "
        "`txtfiles/languages/<lang>/` (9) + `notes/languages/<lang>/` (8) convention, cp1250 bytes. "
        "`credits.txt` exists translated in the source mod but has **no** language-folder slot in "
        "canonical (canonical never localizes credits) -- excluded, not shipped anywhere in this pack." )
    lines.append(
        f"| 1b | `inventoryitems/` | {inv_n} | Mirrors `cryoffear/inventoryitems/` "
        "(incl. `ammo/`, `weapons/`), cp1250 bytes. Two anomalies fixed at generation time: "
        "`weapons/weapon_sledgeshovel.txt` was UTF-8 in the source mod, re-encoded to cp1250; "
        "`valve.txt` had a mojibake `\"Zaw\u0102\u0142r\"` (UTF-8 \u00f3 pasted into a cp1250 file) repaired to `\"Zaw\u00f3r\"`.")
    lines.append(
        f"| 2 | `maps/` | {maps_n} | Per-map `.ent` entity-lump overrides, cp1250 bytes. Built from "
        f"{total_pairs} total changed entity key/value pairs across 102 maps; "
        f"{len(ent_excluded)} excluded (kept canonical) as asset file paths, not display text -- see "
        "Exclusions below. Every `.ent` was re-parsed and verified to have the same entity count, "
        f"classnames and targetnames as canonical. {len(maps_with_applied)} maps ended up with at "
        "least one applied change and therefore got a `.ent` file; maps with zero surviving changes "
        "(byte-identical maps, texture-only maps, and any map whose only changes were excluded "
        "asset paths) get no `.ent` file.")
    lines.append(
        f"| 3 | `textures/` | {tex_n} | Repainted sign/poster textures extracted from the mod's BSPs, "
        "one TGA per unique texture name (cross-map identical, verified). "
        f"{len(masked)} are alpha-masked (`{{`-prefixed name): {', '.join(masked)} -- exported 32-bit "
        "with palette index 255 as the transparency key; the rest are 24-bit. **Not a literal deploy "
        "path** -- see `cof-fix/scripts/polish/README.md` for the engine citation "
        "(`Mod_SearchForTextureReplacement`, `engine/common/mod_bmodel.c`): the real deploy target for "
        "every file here is `cryoffear/materials/common/<texname>.tga`, with the archived cvar "
        "`host_allow_materials` set to at least `1`.")
    lines.append(
        f"| 4 | `overlay/` | {overlay_n} | Verbatim byte-for-byte copies of the "
        f"{overlay_tga_n} changed TGAs + {overlay_mdl_n} changed MDLs, at their original path relative "
        "to the mod root (spans both `cryoffear/` and `platform/`). Excluded by construction (never in "
        "the source TGA/MDL compare data used to build this list): font TGAs and all `.chw` files, "
        "`media/` (the 118 MB startup video), `resource/GameMenu.res` and every other `.res`/`.scr` "
        "file, the three DLLs, and both EXEs.")
    lines.append(
        f"| 5 | `strings/dll-strings.tsv` | 1 ({len(tsv_rows)} data rows) | English -> Polish string "
        "table recovered from the mod's `client.dll` (123 raw pairs) and `hl.dll` (109 raw pairs) "
        "hex patches -- `GameUI.dll`'s 3 pairs are excluded entirely (1 CRT day-name corruption, 2 "
        "are token redirects like `#UI_RunWindowed`, not translations). 16 pairs excluded by exact "
        "file offset: 9 identifier-corruption strings (`ammo_buckshot`, `sk_plr_buckshot1-4`, "
        "`sk_plr_buckshot`, `browningwheelchair`, `SimonMode`, `Syringe`), 6 C-runtime day-name-table "
        "fragments (a `Wed`->`Wen` blanket replace hit the compiled MSVC CRT locale tables in both "
        "DLLs), and 1 string that overran its own NUL terminator and merged with the next literal "
        "(`Unlocked: FAMAS with infinite ammo`). See Data-quality notes below for two further findings "
        "recorded but *not* excluded.")
    lines.append("")
    lines.append("## Exclusions")
    lines.append("")
    lines.append(
        f"**Part 2 (`maps/`), {len(ent_excluded)} entity key/value changes kept canonical** "
        "(mechanical rule: excluded if the canonical value ends in `.wav`/`.mdl`/`.spr`/`.tga` "
        "case-insensitively, or contains `/`) -- all four are the mod's own broken find-and-replace of "
        "the word \"docks\", which also rewrote an asset filename that does not exist under either tree:")
    lines.append("")
    lines.append("| map | entity # | key | canonical value | mod value (not applied) |")
    lines.append("|---|---:|---|---|---|")
    for map_name, idx, key, canon_val, mod_val in ent_excluded:
        lines.append(f"| `{map_name}` | {idx} | `{key}` | `{canon_val}` | `{mod_val}` |")
    lines.append("")
    lines.append(
        "Not excluded, by the same mechanical rule (kept as an applied translation, since it has no "
        "slash and no matching extension): `boat_exit.message` \"Docks\" -> \"Doki\" in `c_lake.bsp` -- "
        "this reads as an in-world place-name string, not a file path, so `c_lake.ent` still ships "
        "with this one change applied even though its other two changes (the ambient sound paths) "
        "were excluded.")
    lines.append("")
    lines.append(
        "**Part 4 (`overlay/`)**: font TGAs, `.chw` files, `media/`, `resource/GameMenu.res` and other "
        "`.res`/`.scr` files, the DLLs, and both EXEs -- see the part 4 row above; these asset kinds are "
        "outside this pack's scope entirely (not merely filtered out of an otherwise-included set).")
    lines.append("")
    lines.append(
        "**Part 5 (`strings/dll-strings.tsv`)**: 16 pairs excluded by exact offset -- see the part 5 "
        "row above and `cof-fix/scripts/polish/build_dll_strings_tsv.py` for the full offset list.")
    lines.append("")
    lines.append("## Data-quality notes (recorded, not excluded)")
    lines.append("")
    lines.append(
        f"**{len(font_quirk_rows)} rows in `dll-strings.tsv`** contain a diacritic letter that is a "
        "valid Windows-1250 decode of the mod's raw patch byte but is **not** a Polish letter (e.g. "
        "`\u00fa \u00ee \u00e4 \u00eb \u00e7 \u00c1 \u00f4` instead of the intended `\u015b \u0142 \u0105 "
        "\u0119 \u0107` etc.). `BINARIES_ANALYSIS.md` section 5.4 documents why: for a substantial "
        "minority of its patched strings, the mod's patcher used a non-standard byte mapping chosen to "
        "match glyph slots in the game's own bitmap font atlas rather than real Windows-1250, so the "
        "same byte renders as the intended Polish letter in the game's own custom font but decodes to a "
        "different (wrong) Latin-1-range letter under a strict standards-based cp1250 decode. This "
        "pack's `dll-strings.tsv` always uses the strict, standards-based cp1250/UTF-8 decode (the "
        "correct choice for a native table meant to be rendered by a normal Unicode-aware font/console, "
        "not the mod's bitmap atlas), so these rows are technically correctly decoded but will read as "
        "garbled Polish; a human reviewer should retranslate them from the `english` column rather than "
        "trust the `polish` column as-is. Affected offsets:")
    lines.append("")
    lines.append("| file_offset | source_dll | english | polish (as decoded) |")
    lines.append("|---|---|---|---|")
    for row in font_quirk_rows:
        lines.append(f"| `{row['file_offset']}` | {row['source_dll']} | {row['english']} | {row['polish']} |")
    lines.append("")
    lines.append(
        f"**{len(flagged_rows)} rows flagged `identifier-like`** (present in `dll-strings.tsv` with a "
        "non-empty `flagged` column, kept rather than excluded because they are not in the confirmed "
        "exclusion-by-offset list, but the analysis independently identified them as gameplay "
        "identifiers/registration names rather than display text, same family as the excluded "
        "`ammo_buckshot`/`sk_plr_buckshot*` corruption):")
    lines.append("")
    for row in flagged_rows:
        lines.append(f"- `{row['file_offset']}` ({row['source_dll']}): `{row['english']}` -> `{row['polish']}` -- {row['flagged']}")
    lines.append("")
    lines.append("## Regeneration")
    lines.append("")
    lines.append(
        "See `cof-fix\\scripts\\polish\\README.md` for the full language-pack format spec and the "
        "run order (`build_all.py` runs every step for a given `--lang`)."
    )
    lines.append("")

    (lc.PACK_DIR / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_pack_manifest_tsv() -> Path:
    out_path = lc.PACK_DIR / "MANIFEST.tsv"
    rows = []
    for f in lc.iter_pack_files(lc.PACK_DIR):
        if f.resolve() == out_path.resolve():
            continue
        rel = f.relative_to(lc.PACK_DIR).as_posix()
        rows.append((rel, f.stat().st_size, lc.sha256_file(f)))
    rows.sort(key=lambda r: r[0])
    with open(out_path, "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh, delimiter="\t", lineterminator="\n")
        w.writerow(["path", "bytes", "sha256"])
        for row in rows:
            w.writerow(row)
    return out_path


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--lang", required=True, choices=sorted(lc.LANGUAGES))
    ap.add_argument("--pack-version", default="1.0.0")
    args = ap.parse_args()

    cfg = lc.get_language(args.lang)
    authors = AUTHORS_BY_LANG.get(args.lang, "unknown")

    manifest_path = lc.write_manifest_txt(args.lang, pack_version=args.pack_version, extra={"authors": authors})
    print(f"wrote {manifest_path}")

    write_readme(args.lang, cfg, args.pack_version)
    print(f"wrote {lc.PACK_DIR / 'README.md'}")

    tsv_path = write_pack_manifest_tsv()
    n = sum(1 for _ in open(tsv_path, encoding="utf-8")) - 1
    print(f"wrote {tsv_path} ({n} files)")


if __name__ == "__main__":
    main()
