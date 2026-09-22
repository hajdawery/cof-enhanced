#!/usr/bin/env python3
"""entpatch.py -- the language-pack entity patch format (".entpatch", version 1).

Reference implementation of the format the engine applies at map load
(engine/common/cof_entpatch.c in patches/cof-language-packs.patch). Both sides
implement the SAME matching and splicing rules; build_maps_entpatch.py checks
this Python applier against the fan translation, and the stage1 lang3 harness
checks the C applier against this one byte for byte.

File layout (bytes; values are in the pack's code page, everything else ASCII):

    // comment lines (outside blocks) are ignored
    {
    "@entity" "57"                 index of the entity in the base entity string (a hint)
    "@classname" "game_text"       selectors: the entity's FIRST value of that key must equal
    "@targetname" "hint3"            this exactly; any "@<key>" other than @entity, @op and
    "@origin" "-12 40 8"             "@crc:<key>" is a selector
    "@crc:message" "1a2b3c4d"      optional precondition: CRC-32 (zlib/IEEE, lowercase hex) of
                                     the value being replaced; a mismatch skips that key only
    "message" "Polski tekst"       plain keys: set this value (first occurrence of the key),
                                     or append the pair if the entity lacks the key
    }

    { "@op" "add"  "classname" "..." ... }    append a new entity (plain keys, in order)
    { "@op" "remove"  "@entity" "12" "@classname" "..." ... }   drop the selected entity

Entity selection for "edit" (default) and "remove" blocks:
  candidates = entities whose selectors all match;
  the candidate at @entity if there is one, else the only candidate, else the
  candidate nearest to @entity (a tie is ambiguous), else the block is skipped.

Splicing: the base string is never re-serialised. Only the bytes of replaced
values change; appended pairs go right before the entity's closing brace as
'"key" "value"\\n'; removed entities are cut from their '{' through the '}'
and one following newline; added entities are appended after the last
entity as '{\\n"k" "v"\\n...}\\n'. So a patch that only replaces values keeps
every other byte of the base entity string.
"""
from __future__ import annotations

import zlib
from dataclasses import dataclass, field
from typing import Optional

RESERVED = ("@entity", "@op")


def crc(value: bytes) -> str:
    return "%08x" % (zlib.crc32(value) & 0xFFFFFFFF)


# ---------------------------------------------------------------------------
# base entity string
# ---------------------------------------------------------------------------

@dataclass
class Entity:
    open_pos: int                      # offset of '{'
    close_pos: int                     # offset of '}'
    pairs: list = field(default_factory=list)   # [(key, value, vstart, vend)] bytes

    def first(self, key: bytes) -> Optional[tuple]:
        for p in self.pairs:
            if p[0] == key:
                return p
        return None


def parse_entities(data: bytes) -> list[Entity]:
    """Parse a GoldSrc entity string ('{ "k" "v" ... }' blocks) into entities
    with the byte spans of every value. Raises ValueError on malformed input.
    Stops at the first NUL."""
    n = len(data)
    nul = data.find(b"\0")
    if nul >= 0:
        n = nul
    i = 0
    ents: list[Entity] = []

    def skip_ws(i):
        while i < n and data[i] in b" \t\r\n":
            i += 1
        return i

    def quoted(i):
        if i >= n or data[i] != 0x22:
            raise ValueError(f"expected '\"' at {i}")
        j = data.find(b'"', i + 1, n)
        if j < 0:
            raise ValueError(f"unterminated string at {i}")
        return i + 1, j   # content span

    while True:
        i = skip_ws(i)
        if i >= n:
            break
        if data[i] != ord("{"):
            raise ValueError(f"expected '{{' at {i}")
        e = Entity(open_pos=i, close_pos=-1)
        i += 1
        while True:
            i = skip_ws(i)
            if i >= n:
                raise ValueError("EOF inside entity")
            if data[i] == ord("}"):
                e.close_pos = i
                i += 1
                break
            ks, ke = quoted(i)
            i = skip_ws(ke + 1)
            vs, ve = quoted(i)
            i = ve + 1
            e.pairs.append((data[ks:ke], data[vs:ve], vs, ve))
        ents.append(e)
    return ents


# ---------------------------------------------------------------------------
# patch file
# ---------------------------------------------------------------------------

def parse_patch(data: bytes) -> list[list[tuple[bytes, bytes]]]:
    """Blocks of (key, value) pairs, in file order."""
    n = len(data)
    i = 0
    blocks = []
    cur = None
    pending_key = None
    while i < n:
        c = data[i]
        if c in b" \t\r\n":
            i += 1
        elif data.startswith(b"//", i):
            j = data.find(b"\n", i)
            i = n if j < 0 else j + 1
        elif c == ord("{"):
            if cur is not None:
                raise ValueError(f"nested '{{' at {i}")
            cur = []
            i += 1
        elif c == ord("}"):
            if cur is None or pending_key is not None:
                raise ValueError(f"unexpected '}}' at {i}")
            blocks.append(cur)
            cur = None
            i += 1
        elif c == 0x22:
            j = data.find(b'"', i + 1)
            if j < 0 or cur is None:
                raise ValueError(f"bad string at {i}")
            tok = data[i + 1:j]
            i = j + 1
            if pending_key is None:
                pending_key = tok
            else:
                cur.append((pending_key, tok))
                pending_key = None
        else:
            raise ValueError(f"unexpected byte {c:#x} at {i}")
    if cur is not None:
        raise ValueError("EOF inside block")
    return blocks


def format_block(pairs: list[tuple[bytes, bytes]]) -> bytes:
    for k, v in pairs:
        if b'"' in k or b'"' in v or b"\0" in v:
            raise ValueError(f"unencodable pair {k!r} {v!r}")
    return b"{\n" + b"".join(b'"' + k + b'" "' + v + b'"\n' for k, v in pairs) + b"}\n"


# ---------------------------------------------------------------------------
# apply
# ---------------------------------------------------------------------------

@dataclass
class ApplyReport:
    blocks: int = 0
    edited: int = 0          # values replaced or appended
    removed: int = 0
    added: int = 0
    skipped: list = field(default_factory=list)   # human-readable reasons


def select(ents: list[Entity], removed: set, block) -> tuple[Optional[int], str]:
    hint = -1
    sels = []
    for k, v in block:
        if k == b"@entity":
            try:
                hint = int(v)
            except ValueError:
                return None, f"bad @entity {v!r}"
        elif k == b"@op" or k.startswith(b"@crc:"):
            continue
        elif k.startswith(b"@"):
            sels.append((k[1:], v))
    cands = []
    for idx, e in enumerate(ents):
        if idx in removed:
            continue
        ok = True
        for sk, sv in sels:
            p = e.first(sk)
            if p is None or p[1] != sv:
                ok = False
                break
        if ok:
            cands.append(idx)
    if not cands:
        return None, "no entity matches"
    if hint in cands:
        return hint, ""
    if len(cands) == 1:
        return cands[0], ""
    if hint < 0:
        return None, f"{len(cands)} entities match and no @entity hint"
    best = sorted(cands, key=lambda c: abs(c - hint))
    if abs(best[0] - hint) == abs(best[1] - hint):
        return None, f"ambiguous: entities {best[0]} and {best[1]} are equally near @entity {hint}"
    return best[0], ""


def apply(base: bytes, patch: bytes) -> tuple[bytes, ApplyReport]:
    """Apply `patch` to the entity string `base` (a trailing NUL, if any, is
    dropped from the result). Returns (new entity string, report)."""
    nul = base.find(b"\0")
    if nul >= 0:
        base = base[:nul]
    ents = parse_entities(base)
    blocks = parse_patch(patch)
    rep = ApplyReport(blocks=len(blocks))
    removed: set = set()
    # per entity: {pair index: new value}, [appended pairs]
    newval: dict = {}
    appended: dict = {}
    adds = []

    for bi, block in enumerate(blocks):
        op = b"edit"
        for k, v in block:
            if k == b"@op":
                op = v
        if op == b"add":
            pairs = [(k, v) for k, v in block if not k.startswith(b"@")]
            adds.append(pairs)
            rep.added += 1
            continue
        if op not in (b"edit", b"remove"):
            rep.skipped.append(f"block {bi}: unknown @op {op!r}")
            continue
        idx, why = select(ents, removed, block)
        if idx is None:
            rep.skipped.append(f"block {bi}: {why}")
            continue
        if op == b"remove":
            removed.add(idx)
            rep.removed += 1
            continue
        e = ents[idx]
        crcs = {k[5:]: v for k, v in block if k.startswith(b"@crc:")}
        for k, v in block:
            if k.startswith(b"@"):
                continue
            pi = next((j for j, p in enumerate(e.pairs) if p[0] == k), None)
            if pi is None:
                appended.setdefault(idx, []).append((k, v))
                rep.edited += 1
                continue
            cur = newval.get(idx, {}).get(pi, e.pairs[pi][1])
            if k in crcs and crc(cur) != crcs[k].decode("ascii", "replace").lower():
                rep.skipped.append(f"block {bi}: entity {idx} key {k!r}: value changed (crc)")
                continue
            newval.setdefault(idx, {})[pi] = v
            rep.edited += 1

    # splice
    out = bytearray()
    cur = 0
    for idx, e in enumerate(ents):
        if idx in removed:
            out += base[cur:e.open_pos]
            end = e.close_pos + 1
            if end < len(base) and base[end:end + 1] == b"\n":
                end += 1
            cur = end
            continue
        for pi, v in sorted(newval.get(idx, {}).items()):
            vs, ve = e.pairs[pi][2], e.pairs[pi][3]
            out += base[cur:vs]
            out += v
            cur = ve
        if idx in appended:
            out += base[cur:e.close_pos]
            for k, v in appended[idx]:
                out += b'"' + k + b'" "' + v + b'"\n'
            cur = e.close_pos
    out += base[cur:]
    if adds:
        if out and not out.endswith(b"\n"):
            out += b"\n"
        for pairs in adds:
            out += format_block(pairs)
    return bytes(out), rep
