#!/usr/bin/env python3
"""build_maps_ent.py -- generate maps/<name>.ent entity-lump overrides for a
native language pack, by applying the translated key/value changes recorded
in the BSP analysis (analysis.json) on top of a byte-exact copy of each
canonical map's ENTITIES lump.

Mechanical exclusion rule (applied to every changed key/value pair, not just
the ones already flagged in BSP_ANALYSIS.md): if the CANONICAL value
(case-insensitive) ends with .wav, .mdl, .spr or .tga, OR contains a '/'
character, the change is an asset-path rewrite, not a translation -- the
canonical value is kept and the mod's value is discarded for that key.
Everything else is applied.

Entity-block splitting reuses the exact method
K:\\LLM\\COF_Fix\\stage1\\polish-mod-analysis-20260922\\bsp\\scripts\\bsp_lump_diff.py
uses (split_entity_blocks / KV_RE), so entity `index` numbering matches
analysis.json exactly. The block-drop convention (encode whole lump, set
mtime to "now" so the engine doesn't ignore an .ent older than its BSP) is
the same one used by
K:\\LLM\\COF_Fix\\cof-fix\\scripts\\make-cof-ent-override.py.

Text-encoding note: analysis.json's mod_value strings are the *raw*
latin1-decode of the mod's original CP1250 bytes (byte value N decoded as
Unicode codepoint N) -- verified empirically, NOT already correct Polish
text as one might assume from the field's name. The correct Polish string
is recovered with `raw.encode("latin1").decode(codepage)` before it is
spliced into the block text; the whole reassembled entity lump is then
encoded with `codepage` (CP1250 for Polish) to produce the on-disk bytes.

READ-ONLY against the canonical game tree and analysis.json. Writes only
under pack/languages/<lang>/maps/ (via langpack_common.maps_dir).

Usage:
    build_maps_ent.py --lang polish
"""
from __future__ import annotations

import argparse
import json
import os
import re
import struct
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import langpack_common as lc  # noqa: E402

ANALYSIS_JSON = lc.ANALYSIS_ROOT / "bsp" / "analysis.json"

EXCLUDE_EXTS = (".wav", ".mdl", ".spr", ".tga")

# ---------------------------------------------------------------------------
# Entity-lump split / parse -- kept byte-for-byte identical in approach to
# bsp_lump_diff.py's split_entity_blocks()/KV_RE, so entity `index` values
# line up exactly with analysis.json.
# ---------------------------------------------------------------------------


def split_entity_blocks(text: str) -> list[str]:
    """Top-level '{ ... }' blocks, respecting quoted strings. Returns each
    block WITHOUT the surrounding braces (matches bsp_lump_diff.py)."""
    blocks, i, n = [], 0, len(text)
    while i < n:
        if text[i] == "{":
            depth, j, in_q = 1, i + 1, False
            start = j
            while j < n:
                ch = text[j]
                if ch == '"':
                    in_q = not in_q
                elif not in_q:
                    if ch == "{":
                        depth += 1
                    elif ch == "}":
                        depth -= 1
                        if depth == 0:
                            break
                j += 1
            blocks.append(text[start:j])
            i = j + 1
        else:
            i += 1
    return blocks


KV_RE = re.compile(r'"([^"]*)"\s+"([^"]*)"')


def parse_pairs(block: str) -> list[tuple[str, str]]:
    return KV_RE.findall(block)


def first(pairs: list[tuple[str, str]], key: str, default: str = "") -> str:
    for k, v in pairs:
        if k == key:
            return v
    return default


def read_entity_lump_text(bsp_path: Path) -> str:
    data = bsp_path.read_bytes()
    (version,) = struct.unpack_from("<i", data, 0)
    if version != 30:
        raise SystemExit(f"{bsp_path}: unexpected BSP version {version} (expected 30)")
    offset, length = struct.unpack_from("<ii", data, 4)
    return data[offset : offset + length].decode("latin1")


def fix_mod_text(raw: str, codepage: str) -> str:
    """analysis.json's mod-side strings are a naive latin1 decode of the
    original codepage bytes; recover the correct Unicode string."""
    return raw.encode("latin1").decode(codepage)


# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------


def is_excluded(canon_value: str) -> bool:
    lo = canon_value.lower()
    if lo.endswith(EXCLUDE_EXTS):
        return True
    if "/" in canon_value:
        return True
    return False


def plan_map(map_rec: dict, codepage: str):
    """Return (applied: {index: {key: fixed_mod_value}}, excluded: [dict], anomalies: [str])."""
    applied: dict[int, dict[str, str]] = {}
    excluded = []
    anomalies = []
    ent = map_rec.get("entities")
    if not ent or not ent.get("entities"):
        return applied, excluded, anomalies

    for e in ent["entities"]:
        idx = e["index"]
        classname = e.get("classname_canon") or e.get("classname_mod") or "?"
        for change in e.get("changed", []):
            key, canon_list, mod_list = change
            if len(canon_list) != 1 or len(mod_list) != 1:
                anomalies.append(
                    f"{map_rec['map']} entity {idx} key {key!r}: "
                    f"multi-valued change canon={canon_list!r} mod={mod_list!r} -- skipped"
                )
                continue
            canon_value = canon_list[0]
            mod_value_raw = mod_list[0]
            if is_excluded(canon_value):
                excluded.append(
                    {
                        "map": map_rec["map"],
                        "entity_index": idx,
                        "classname": classname,
                        "key": key,
                        "canon_value": canon_value,
                        "mod_value_raw": mod_value_raw,
                    }
                )
                continue
            mod_value_fixed = fix_mod_text(mod_value_raw, codepage)
            applied.setdefault(idx, {})[key] = mod_value_fixed
    return applied, excluded, anomalies


def encode_block_with_changes(block: str, kv_targets: dict[str, str], canon_pairs_for_idx, codepage: str) -> bytes:
    """Return the block's bytes with kv_targets applied.

    IMPORTANT: `block` is a latin1 decode of the canonical map's raw ENTITIES
    lump bytes -- i.e. codepoint N in `block` always corresponds to byte
    value N in the original file. The canonical lump has been observed to
    contain raw non-ASCII / non-text bytes in untouched keys (e.g. a
    corrupted "wad" value in c_bridge.bsp / c_start.bsp containing byte
    0xD8, which is not itself a valid CP1250 codepoint). To keep untouched
    bytes byte-for-byte identical to canonical, pass-through text is
    re-encoded with `latin1` (the exact inverse of the decode that produced
    `block`), and ONLY the substituted Polish value text is encoded with
    `codepage`. Encoding the whole block with `codepage` in one shot (which
    is what a naive reading of "encode the whole result with cp1250" would
    do) fails outright on these maps and would in any case silently corrupt
    any other non-ASCII pass-through byte that happens to collide with a
    different cp1250 codepoint.
    """
    spans = []  # (value_start, value_end, new_value) in `block` coordinates, sorted by start
    for key, new_value in kv_targets.items():
        canon_value = None
        for k, v in canon_pairs_for_idx:
            if k == key:
                canon_value = v
                break
        if canon_value is None:
            raise ValueError(f"key {key!r} not found in canonical block")
        pattern = re.compile(r'("' + re.escape(key) + r'"\s+")(' + re.escape(canon_value) + r')(")')
        m = pattern.search(block)
        if not m:
            raise ValueError(f"key {key!r} value {canon_value!r} not found in canonical block")
        if pattern.search(block, m.end()):
            raise ValueError(f"key {key!r} value {canon_value!r} is ambiguous (matches more than once)")
        spans.append((m.start(2), m.end(2), new_value))
    spans.sort()

    out = bytearray()
    cursor = 0
    for start, end, new_value in spans:
        out += block[cursor:start].encode("latin1")
        out += new_value.encode(codepage)
        cursor = end
    out += block[cursor:].encode("latin1")
    return bytes(out)


def generate_map(map_rec: dict, lang_cfg, applied: dict[int, dict[str, str]]) -> Path:
    map_name = map_rec["map"]
    bsp_path = lc.CANONICAL_ROOT / "cryoffear" / "maps" / map_name
    text = read_entity_lump_text(bsp_path)
    blocks = split_entity_blocks(text)

    block_bytes: list[bytes] = []
    for idx, block in enumerate(blocks):
        if idx in applied:
            canon_pairs = parse_pairs(block)
            block_bytes.append(encode_block_with_changes(block, applied[idx], canon_pairs, lang_cfg.codepage))
        else:
            # untouched block: byte-exact pass-through of the canonical bytes
            block_bytes.append(block.encode("latin1"))

    # reassemble: each block is stored WITHOUT braces (matches
    # split_entity_blocks' return convention) -- wrap them back.
    wrapped = [b"{" + b + b"}" for b in block_bytes]
    out_bytes = b"\n".join(wrapped) + b"\n"

    out_path = lc.maps_dir(lang_cfg.code) / (Path(map_name).stem + ".ent")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "wb") as fh:
        fh.write(out_bytes)
    now = time.time()
    os.utime(out_path, (now, now))
    return out_path


# ---------------------------------------------------------------------------
# Verification -- re-parses the OUTPUT .ent file from scratch.
# ---------------------------------------------------------------------------


def verify_map(map_rec: dict, lang_cfg, applied: dict[int, dict[str, str]]) -> tuple[bool, list[str]]:
    map_name = map_rec["map"]
    problems: list[str] = []

    bsp_path = lc.CANONICAL_ROOT / "cryoffear" / "maps" / map_name
    canon_text = read_entity_lump_text(bsp_path)  # latin1: codepoint N == original byte N
    canon_blocks = split_entity_blocks(canon_text)
    canon_pairs_list = [parse_pairs(b) for b in canon_blocks]

    out_path = lc.maps_dir(lang_cfg.code) / (Path(map_name).stem + ".ent")
    out_bytes = out_path.read_bytes()

    # Sanity check (verification step 1, literally): the whole file must be a
    # well-formed cp1250 byte stream -- CP1250 decode is a total mapping over
    # all 256 byte values, so this only fails if the file isn't single-byte
    # text at all.
    try:
        out_bytes.decode(lang_cfg.codepage)
    except UnicodeDecodeError as e:
        return False, [f"output .ent does not decode as {lang_cfg.codepage}: {e}"]

    # For the structural/byte comparisons below we decode via latin1 instead
    # of cp1250: latin1 is a bijective byte<->codepoint mapping, so slicing
    # and re-encoding (`s.encode('latin1')`) recovers the EXACT original
    # bytes for any substring -- which is what "byte-identical" (step 5) and
    # "round-trip through cp1250" (step 6, done explicitly below) require.
    # Decoding untouched non-ASCII pass-through bytes directly as cp1250
    # instead would not be byte-preserving (proven by c_bridge.bsp /
    # c_start.bsp, whose canonical "wad" value contains a raw 0xD8 byte that
    # cp1250 decodes to a DIFFERENT character than latin1 does).
    out_text = out_bytes.decode("latin1")
    out_blocks = split_entity_blocks(out_text)
    out_pairs_list = [parse_pairs(b) for b in out_blocks]

    # 2) entity count
    if len(out_blocks) != len(canon_blocks):
        problems.append(f"entity count mismatch: canon={len(canon_blocks)} out={len(out_blocks)}")
        return False, problems

    # 3) classname sequence
    canon_classnames = [first(p, "classname", "") for p in canon_pairs_list]
    out_classnames = [first(p, "classname", "") for p in out_pairs_list]
    if canon_classnames != out_classnames:
        for i, (c, o) in enumerate(zip(canon_classnames, out_classnames)):
            if c != o:
                problems.append(f"classname mismatch at entity {i}: canon={c!r} out={o!r}")

    # 4) targetname sequence
    canon_targetnames = [first(p, "targetname", "") for p in canon_pairs_list]
    out_targetnames = [first(p, "targetname", "") for p in out_pairs_list]
    if canon_targetnames != out_targetnames:
        for i, (c, o) in enumerate(zip(canon_targetnames, out_targetnames)):
            if c != o:
                problems.append(f"targetname mismatch at entity {i}: canon={c!r} out={o!r}")

    # 5) & 6) per-key value checks, at the RAW BYTE level
    for idx in range(len(canon_pairs_list)):
        canon_pairs = canon_pairs_list[idx]
        out_pairs = out_pairs_list[idx]
        targets = applied.get(idx, {})
        if len(canon_pairs) != len(out_pairs):
            problems.append(
                f"entity {idx}: key count mismatch canon={len(canon_pairs)} out={len(out_pairs)}"
            )
            continue
        for (ck, cv), (ok, ov) in zip(canon_pairs, out_pairs):
            if ck != ok:
                problems.append(f"entity {idx}: key order mismatch canon key={ck!r} out key={ok!r}")
                continue
            out_raw_bytes = ov.encode("latin1")
            if ck in targets:
                expected_str = targets[ck]
                expected_bytes = expected_str.encode(lang_cfg.codepage)
                if out_raw_bytes != expected_bytes:
                    problems.append(
                        f"entity {idx} key {ck!r}: expected applied bytes {expected_bytes!r}, got {out_raw_bytes!r}"
                    )
                    continue
                # round-trip: decoding those bytes back as cp1250 must
                # exactly reproduce the mod's translated string
                if out_raw_bytes.decode(lang_cfg.codepage) != expected_str:
                    problems.append(
                        f"entity {idx} key {ck!r}: cp1250 round-trip mismatch, expected {expected_str!r}"
                    )
            else:
                canon_raw_bytes = cv.encode("latin1")
                if out_raw_bytes != canon_raw_bytes:
                    problems.append(
                        f"entity {idx} key {ck!r}: expected canonical bytes {canon_raw_bytes!r} unchanged, got {out_raw_bytes!r}"
                    )

    return (len(problems) == 0), problems


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--lang", default="polish", help="language code from langpack_common.LANGUAGES")
    args = ap.parse_args()

    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
        sys.stderr.reconfigure(encoding="utf-8", errors="backslashreplace")
    except Exception:
        pass

    lang_cfg = lc.get_language(args.lang)

    data = json.loads(ANALYSIS_JSON.read_text(encoding="utf-8"))
    maps = data["maps"]

    written = []
    skipped_zero_changes = []
    skipped_no_entity_diff = []
    all_excluded = []
    all_anomalies = []
    fail_list = []

    for map_rec in maps:
        map_name = map_rec["map"]
        ent = map_rec.get("entities")
        if not ent or not ent.get("entities"):
            skipped_no_entity_diff.append(map_name)
            continue

        applied, excluded, anomalies = plan_map(map_rec, lang_cfg.codepage)
        all_excluded.extend(excluded)
        all_anomalies.extend(anomalies)

        if not applied:
            skipped_zero_changes.append(map_name)
            continue

        try:
            out_path = generate_map(map_rec, lang_cfg, applied)
        except Exception as e:
            fail_list.append((map_name, f"generation error: {type(e).__name__}: {e}"))
            continue

        ok, problems = verify_map(map_rec, lang_cfg, applied)
        status = "PASS" if ok else "FAIL"
        n_applied = sum(len(v) for v in applied.values())
        print(f"[{status}] {map_name}: {n_applied} value(s) applied across {len(applied)} entit(y/ies) -> {out_path.name}")
        if ok:
            written.append(map_name)
        else:
            fail_list.append((map_name, problems))
            for p in problems[:20]:
                print(f"         - {p}")

    print()
    print("=" * 70)
    print(f"maps with .ent written & PASS : {len(written)}")
    print(f"maps skipped (no entity diff) : {len(skipped_no_entity_diff)}")
    print(f"maps skipped (0 surviving chg): {len(skipped_zero_changes)}  {skipped_zero_changes}")
    print(f"maps FAILED verification      : {len(fail_list)}")
    for name, problems in fail_list:
        print(f"  FAIL {name}: {problems if isinstance(problems, str) else problems[:5]}")
    print(f"total excluded key/value pairs: {len(all_excluded)}")
    for exc in all_excluded:
        print(
            f"  EXCLUDED map={exc['map']} entity={exc['entity_index']} "
            f"classname={exc['classname']} key={exc['key']} "
            f"canon={exc['canon_value']!r} mod_raw={exc['mod_value_raw']!r}"
        )
    if all_anomalies:
        print(f"anomalies (multi-valued changes, not auto-applied): {len(all_anomalies)}")
        for a in all_anomalies:
            print(f"  ANOMALY {a}")

    if fail_list:
        sys.exit(1)


if __name__ == "__main__":
    main()
