#!/usr/bin/env python3
"""Run every language-pack generator in order for one language.

    python build_all.py --lang polish

Equivalent to running, in this order (parts 1-5 are independent of each
other and could run in any order or in parallel; part 6 must run last
because it reads the output of all the others):

    build_txt_pack.py         --lang <lang>   # txt/ + inventoryitems/
    build_maps_ent.py         --lang <lang>   # maps/*.ent
    extract_sign_textures.py  --lang <lang>   # textures/*.tga
    copy_overlay_assets.py    --lang <lang>   # overlay/...
    build_dll_strings_tsv.py  --lang <lang>   # strings/dll-strings.tsv
    build_manifest.py         --lang <lang>   # manifest.txt, MANIFEST.tsv, README.md

Every step is idempotent (safe to re-run) and only reads the two read-only
source trees named in langpack_common.py plus each other's output under
pack/languages/<lang>/ -- never the game or the engine.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

STEPS = [
    "build_txt_pack.py",
    "build_maps_ent.py",
    "extract_sign_textures.py",
    "copy_overlay_assets.py",
    "build_dll_strings_tsv.py",
    "build_manifest.py",  # must be last: reads every other step's output
]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--lang", required=True)
    args, extra = ap.parse_known_args()

    for step in STEPS:
        script = HERE / step
        if not script.exists():
            raise SystemExit(f"missing generator script: {script}")
        cmd = [sys.executable, str(script), "--lang", args.lang, *extra]
        print(f"\n=== {step} ===")
        print(" ".join(cmd))
        subprocess.run(cmd, check=True)

    print("\nAll steps completed for --lang", args.lang)


if __name__ == "__main__":
    main()
