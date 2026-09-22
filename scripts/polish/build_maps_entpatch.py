#!/usr/bin/env python3
"""build_maps_entpatch.py -- per-map entity patches (maps/<map>.entpatch).

Replaces build_maps_ent.py (full .ent entity lumps, 2026-09-22; retired by
the pack reduction of 2026-09-22, lang3): the pack now carries only the
key/value pairs the translators changed, as an .entpatch the engine applies
to the map's own entity string at load (format: entpatch.py).

Source: the fan translation's BSPs and the canonical BSPs, read directly
(no analysis files). For every map both trees have:

  1. read both ENTITIES lumps (BSP v30, lump 0) as raw bytes;
  2. pair entities by index (the translation added or removed none; a
     different entity count or classname sequence is a hard error);
  3. per entity, compare key -> values; a key whose value differs is a
     translation candidate, EXCEPT
       - keys occurring more than once in the entity (ambiguous; reported),
       - asset-path rewrites: the canonical value ends with .wav/.mdl/.spr/.tga
         or contains '/' (the translators' find-and-replace broke four sound
         paths, e.g. "docks" -> "Doki.wav"; the canonical value is kept);
  4. write one block per changed entity: @entity index, @classname plus
     @targetname / @origin / @model when the entity has them, @crc:<key> of
     the canonical value, and the translated value (raw bytes, the pack's
     code page);
  5. verify: entpatch.apply(canonical lump, patch) re-parsed must equal the
     canonical entity list with exactly the planned values replaced, byte for
     byte, and no block may be skipped.

A map whose entity lumps are identical, or whose only differences are
excluded, gets no file. Output: <pack>/maps/<map>.entpatch; stale .ent and
.entpatch files in that folder are removed first.

Usage:
    python build_maps_entpatch.py --lang polish
"""
from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import langpack_common as lc  # noqa: E402
import entpatch as ep  # noqa: E402

EXCLUDE_EXTS = (b".wav", b".mdl", b".spr", b".tga")
SELECTOR_KEYS = (b"classname", b"targetname", b"origin", b"model")
FORMAT_LINE = b"// Cry of Fear: Enhanced entity patch (entpatch 1); format: scripts/polish/entpatch.py, docs/cof-language-pack-format.md"


def entity_lump(bsp: Path) -> bytes:
    data = bsp.read_bytes()
    (version,) = struct.unpack_from("<i", data, 0)
    if version != 30:
        raise SystemExit(f"{bsp}: BSP version {version}, expected 30")
    ofs, ln = struct.unpack_from("<ii", data, 4)
    return data[ofs:ofs + ln]


def is_excluded(canon_value: bytes) -> bool:
    lo = canon_value.lower()
    return lo.endswith(EXCLUDE_EXTS) or b"/" in canon_value


def plan_map(canon: bytes, mod: bytes, name: str):
    ce = ep.parse_entities(canon)
    me = ep.parse_entities(mod)
    if len(ce) != len(me):
        raise SystemExit(f"{name}: entity count differs (canonical {len(ce)}, translation {len(me)}); "
                         "add/remove blocks are not generated automatically - inspect this map")
    changes = {}      # idx -> [(key, canon_value, mod_value)]
    excluded, ambiguous = [], []
    for idx, (c, m) in enumerate(zip(ce, me)):
        cc = (c.first(b"classname") or (b"", b""))[1]
        mc = (m.first(b"classname") or (b"", b""))[1]
        if cc != mc:
            raise SystemExit(f"{name}: entity {idx} classname differs ({cc!r} vs {mc!r})")
        ck, mk = {}, {}
        for k, v, _, _ in c.pairs:
            ck.setdefault(k, []).append(v)
        for k, v, _, _ in m.pairs:
            mk.setdefault(k, []).append(v)
        for k in list(dict.fromkeys(list(ck) + list(mk))):
            cv, mv = ck.get(k, []), mk.get(k, [])
            if cv == mv:
                continue
            if len(cv) != 1 or len(mv) != 1:
                ambiguous.append((idx, k, cv, mv))
                continue
            if is_excluded(cv[0]):
                excluded.append((idx, cc, k, cv[0], mv[0]))
                continue
            changes.setdefault(idx, []).append((k, cv[0], mv[0]))
    return ce, changes, excluded, ambiguous


def build_patch(name: str, ce, changes, codepage: str) -> bytes:
    nvals = sum(len(v) for v in changes.values())
    out = [FORMAT_LINE,
           f"// map {name}: {len(ce)} entities in the BSP entity lump; {nvals} value(s) in {len(changes)} entities; values are {codepage} bytes".encode("ascii")]
    for idx in sorted(changes):
        e = ce[idx]
        pairs = [(b"@entity", str(idx).encode("ascii"))]
        for sk in SELECTOR_KEYS:
            p = e.first(sk)
            if p is not None:
                pairs.append((b"@" + sk, p[1]))
        for k, cv, mv in changes[idx]:
            pairs.append((b"@crc:" + k, ep.crc(cv).encode("ascii")))
            pairs.append((k, mv))
        out.append(ep.format_block(pairs).rstrip(b"\n"))
    return b"\n".join(out) + b"\n"


def verify(canon: bytes, patch: bytes, ce, changes) -> list[str]:
    problems = []
    result, rep = ep.apply(canon, patch)
    if rep.skipped:
        problems += [f"skipped: {s}" for s in rep.skipped]
    re_ = ep.parse_entities(result)
    if len(re_) != len(ce):
        return problems + [f"entity count {len(re_)} != {len(ce)}"]
    for idx, (a, b) in enumerate(zip(ce, re_)):
        want = {k: mv for k, cv, mv in changes.get(idx, [])}
        if len(a.pairs) != len(b.pairs):
            problems.append(f"entity {idx}: pair count")
            continue
        for (ak, av, _, _), (bk, bv, _, _) in zip(a.pairs, b.pairs):
            exp = want.get(ak, av)
            if ak != bk or bv != exp:
                problems.append(f"entity {idx} key {ak!r}: got {bv!r}, expected {exp!r}")
    # untouched bytes: the result must be the canonical string with only the value spans swapped
    nul = canon.find(b"\0")
    base = canon[:nul] if nul >= 0 else canon
    if len(result) - len(base) != sum(len(mv) - len(cv) for v in changes.values() for _, cv, mv in v):
        problems.append("length delta does not match the replaced values")
    return problems


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--lang", required=True)
    args = ap.parse_args()
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
    except Exception:
        pass
    cfg = lc.get_language(args.lang)
    mod_maps = cfg.mod_root / "cryoffear" / "maps"
    canon_maps = lc.CANONICAL_ROOT / "cryoffear" / "maps"
    out_dir = lc.maps_dir(args.lang)
    out_dir.mkdir(parents=True, exist_ok=True)
    for stale in list(out_dir.glob("*.ent")) + list(out_dir.glob("*.entpatch")):
        stale.unlink()

    written, identical, only_excluded, fails = [], [], [], []
    all_excluded, all_ambiguous = [], []
    total_vals = 0
    for mod_bsp in sorted(mod_maps.glob("*.bsp"), key=lambda p: p.name.lower()):
        canon_bsp = lc.find_ci(canon_maps / mod_bsp.name)
        if canon_bsp is None:
            print(f"  (no canonical map for {mod_bsp.name}; skipped)")
            continue
        canon, mod = entity_lump(canon_bsp), entity_lump(mod_bsp)
        if canon == mod:
            identical.append(mod_bsp.name)
            continue
        name = mod_bsp.stem
        ce, changes, excluded, ambiguous = plan_map(canon, mod, mod_bsp.name)
        all_excluded += [(mod_bsp.name,) + x for x in excluded]
        all_ambiguous += [(mod_bsp.name,) + x for x in ambiguous]
        if not changes:
            only_excluded.append(mod_bsp.name)
            continue
        patch = build_patch(name, ce, changes, cfg.codepage)
        problems = verify(canon, patch, ce, changes)
        if problems:
            fails.append((mod_bsp.name, problems))
            continue
        lc.write_pack_file(out_dir / (name + ".entpatch"), patch)
        n = sum(len(v) for v in changes.values())
        total_vals += n
        written.append(name)
        print(f"[PASS] {mod_bsp.name}: {n} value(s) in {len(changes)} entities -> {name}.entpatch ({len(patch)} bytes)")

    print("=" * 70)
    print(f"entpatch files written      : {len(written)} ({total_vals} values)")
    print(f"maps with identical entities: {len(identical)}")
    print(f"maps with only excluded     : {len(only_excluded)} {only_excluded}")
    print(f"excluded asset-path values  : {len(all_excluded)}")
    for x in all_excluded:
        print(f"  EXCLUDED {x[0]} entity {x[1]} ({x[2].decode('latin1')}) {x[3].decode('latin1')}: "
              f"{x[4].decode('latin1')!r} -> {x[5].decode('latin1')!r}")
    if all_ambiguous:
        print(f"multi-valued keys skipped   : {len(all_ambiguous)}")
        for x in all_ambiguous:
            print(f"  AMBIGUOUS {x}")
    for name, problems in fails:
        print(f"  FAIL {name}: {problems[:5]}")
    return 1 if fails else 0


if __name__ == "__main__":
    raise SystemExit(main())
