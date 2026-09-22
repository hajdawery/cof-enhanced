#!/usr/bin/env python3
"""Run every language-pack generator in order for one language.

    python scripts/polish/build_all.py --lang polish --out .

--out is the folder that holds languages/ (the repository root regenerates
the committed pack in place: <out>/languages/<lang>/); without it the
historical stage1 build folder of langpack_common.py is used. Hand-maintained
files in the pack (strings/menu-strings.tsv, LICENSE-NOTE.md) are kept.

Steps, in this order (the first six are independent of each other; the
last one must run last because it checks and lists the output of all):

    build_txt_pack.py         --lang <lang>   # txt/ + inventoryitems/
    build_maps_entpatch.py    --lang <lang>   # maps/*.entpatch
    extract_sign_textures.py  --lang <lang>   # textures/*.tga
    build_model_textures.py   --lang <lang>   # models/<model>/<texture>.bmp
    copy_overlay_assets.py    --lang <lang>   # overlay/... (translated interface images)
    build_dll_strings_tsv.py  --lang <lang>   # strings/dll-strings.tsv
    build_manifest.py         --lang <lang>   # manifest.txt, README.md, MANIFEST.tsv, pack checks

Every step is idempotent and only reads the canonical game, the source
translation and (build_dll_strings_tsv.py) the binary string-diff tables -
never the running game or the engine. Any step failing stops the run.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

STEPS = [
    "build_txt_pack.py",
    "build_maps_entpatch.py",
    "extract_sign_textures.py",
    "build_model_textures.py",
    "copy_overlay_assets.py",
    "build_dll_strings_tsv.py",
    "build_manifest.py",  # must be last: checks and lists every other step's output
]


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--lang", required=True)
    ap.add_argument("--out", help="folder holding languages/<lang>/ (e.g. the repository root)")
    args, extra = ap.parse_known_args()

    env = dict(os.environ)
    if args.out:
        env["COF_LANGPACK_OUT"] = str(Path(args.out).resolve())
    env.setdefault("PYTHONIOENCODING", "utf-8")

    for step in STEPS:
        script = HERE / step
        if not script.exists():
            raise SystemExit(f"missing generator script: {script}")
        cmd = [sys.executable, str(script), "--lang", args.lang, *extra]
        print(f"\n=== {step} ===", flush=True)
        print(" ".join(cmd), flush=True)
        subprocess.run(cmd, check=True, env=env)

    print("\nAll steps completed for --lang", args.lang)


if __name__ == "__main__":
    main()
