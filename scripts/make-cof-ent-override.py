#!/usr/bin/env python3
"""Write a maps/<name>.ent entity-lump override with one classname removed.

FWGS reads maps/<name>.ent as a full replacement for the world entity lump
(engine/common/mod_bmodel.c:2304-2345) provided the .ent file is not older
than the BSP. Everything else in the map is untouched, so this is the
asset-only way to drop a single server entity.

Usage:
    make-ent-override.py <input.bsp> <output.ent> <classname-to-drop> [...]
"""
import struct
import sys
import os
import time


def read_entity_lump(bsp_path):
    with open(bsp_path, "rb") as fh:
        head = fh.read(12)
        version, = struct.unpack_from("<i", head, 0)
        if version != 30:
            raise SystemExit("unexpected BSP version %d (expected 30)" % version)
        # lump 0 is LUMP_ENTITIES: int fileofs, int filelen
        offset, length = struct.unpack_from("<ii", head, 4)
        fh.seek(offset)
        return fh.read(length), offset, length


def split_entities(blob):
    """Split the lump into a list of raw '{...}' blocks, preserving text."""
    text = blob.split(b"\x00", 1)[0].decode("latin-1")
    blocks, depth, start = [], 0, None
    for i, ch in enumerate(text):
        if ch == "{":
            if depth == 0:
                start = i
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                blocks.append(text[start:i + 1])
    return blocks


def classname_of(block):
    for line in block.splitlines():
        line = line.strip()
        if line.startswith('"classname"'):
            return line.split('"')[3]
    return ""


def main():
    if len(sys.argv) < 4:
        raise SystemExit(__doc__)
    bsp, out = sys.argv[1], sys.argv[2]
    drop = set(sys.argv[3:])

    blob, offset, length = read_entity_lump(bsp)
    blocks = split_entities(blob)
    kept = [b for b in blocks if classname_of(b) not in drop]
    removed = [b for b in blocks if classname_of(b) in drop]

    with open(out, "wb") as fh:
        fh.write(("\n".join(kept) + "\n").encode("latin-1"))

    # the engine ignores an entity patch older than the BSP
    now = time.time()
    os.utime(out, (now, now))

    print("bsp            : %s" % bsp)
    print("lump offset/len: %d / %d" % (offset, length))
    print("entities       : %d -> %d" % (len(blocks), len(kept)))
    for b in removed:
        print("removed        : %s" % " | ".join(
            l.strip() for l in b.splitlines() if l.strip() not in ("{", "}")))
    print("written        : %s (%d bytes)" % (out, os.path.getsize(out)))


if __name__ == "__main__":
    main()
