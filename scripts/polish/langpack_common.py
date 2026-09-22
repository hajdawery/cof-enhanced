#!/usr/bin/env python3
"""Shared config and helpers for the Cry of Fear native language-pack generators.

This module is deliberately generic: every generator script under
scripts/polish/ imports LANGUAGES from here and takes a --lang argument
instead of hardcoding "polish" anywhere, so a future Ukrainian (or other)
language pack can reuse the exact same scripts by adding one entry below
and supplying its own source mod tree.

Directory layout this module encodes (see scripts/polish/README.md and
docs/design/language-pack-format.md for the full spec):

    <PACK_DIR>/languages/<lang>/        PACK_DIR = COF_LANGPACK_OUT (build_all.py --out)
        manifest.txt                       language metadata (see write_manifest_txt)
        txt/txtfiles/languages/<lang>/*.txt, txt/notes/languages/<lang>/*.txt
        inventoryitems/...                 mirrors cryoffear/inventoryitems/
        maps/<map>.entpatch                translated entity key/values (entpatch.py)
        textures/<texname>.tga             repainted world signs and posters
        models/<model path>/<tex>.bmp      repainted studio-model textures
        overlay/<cryoffear|platform>/...   translated interface images, same path
        strings/dll-strings.tsv            English -> localized DLL string table
        strings/menu-strings.tsv           hand-maintained (project menu)
        LICENSE-NOTE.md                    hand-maintained
        README.md, MANIFEST.tsv            written by build_manifest.py

Nothing in this module writes files; it only defines paths, config and small
pure helpers reused by the generator scripts.
"""
from __future__ import annotations

import hashlib
import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Fixed project roots (read-only sources; single writable pack root)
# ---------------------------------------------------------------------------

PROJECT_ROOT = Path(r"K:\LLM\COF_Fix")
CANONICAL_ROOT = PROJECT_ROOT / "Cry of Fear"           # read-only, canonical game
ANALYSIS_ROOT = PROJECT_ROOT / "stage1" / "polish-mod-analysis-20260922"  # read-only reports
# Output: <PACK_DIR>/languages/<lang>/. Default is the historical stage1 build
# folder; build_all.py --out <dir> (or the COF_LANGPACK_OUT environment
# variable) points it elsewhere, e.g. at a scratch copy of the repository's
# languages/ parent to regenerate the committed pack in place (see README.md).
PACK_ROOT = PROJECT_ROOT / "stage1" / "polish-pack-20260922"
PACK_DIR = Path(os.environ["COF_LANGPACK_OUT"]) if os.environ.get("COF_LANGPACK_OUT") else PACK_ROOT / "pack"


@dataclass(frozen=True)
class LanguageConfig:
    code: str                     # language slug used as folder name, e.g. "polish"
    display_name: str             # human-readable name in its own language, e.g. "Polski"
    codepage: str                 # python codec name used for on-disk bytes, e.g. "cp1250"
    codepage_label: str           # numeric Windows code page label for manifest.txt, e.g. "1250"
    mod_root: Optional[Path]      # read-only source mod tree for this language, or None if not built yet
    subtitle_language: int        # manifest.txt subtitle_language=: the client subtitle slot the menu's
                                  # Language option writes into cof_subtitlelanguage for this pack
                                  # (1 = English, the client default; 2..7 = the game's own six folders)
    notes: str = ""
    authors: str = ""             # translators, as credited in the pack README (manifest authors=)


LANGUAGES: dict[str, LanguageConfig] = {
    "polish": LanguageConfig(
        code="polish",
        display_name="Polski",
        codepage="cp1250",
        codepage_label="1250",
        mod_root=PROJECT_ROOT / "cof-spolszczenie-fanmade",
        # The canonical client's language-selector list (compiled into client.dll/hl.dll .text,
        # which the mod analysis found byte-identical to canonical -- see BINARIES_ANALYSIS.md
        # section 1) only enumerates dutch/french/german/norwegian/spanish/swedish (+ english
        # default) via cryoffear/txtfiles/languages/<lang>/ and notes/languages/<lang>/. No
        # "polish" slot exists in that hardcoded list and no config/text file overrides it
        # (checked: no languages.cfg or similar). Polish has no client slot of its own.
        # The engine serves the pack's txt/ files over whatever slot the client asks
        # for (docs/cof-language-packs.md 3.3), so the pack picks slot 1, English: the client
        # reads the English root paths and anything the pack lacks falls back to English.
        subtitle_language=1,
        notes="Source: the fan translation Cry of Fear: Spolszczenie (Steam Workshop 3164091802), "
        "incorporated with its authors' permission; see README.md.",
        authors="Avioo, Mixdedemon, hexag0n, Izonka",
    ),
    "ukrainian": LanguageConfig(
        code="ukrainian",
        display_name="Українська",
        codepage="cp1251",
        codepage_label="1251",
        mod_root=None,  # no source mod tree yet -- entry exists only to prove parameterisation
        subtitle_language=1,
        notes="Placeholder only: no source translation tree exists yet. Do not run the "
        "generators with --lang ukrainian until a mod_root is supplied.",
    ),
}


def get_language(code: str) -> LanguageConfig:
    try:
        cfg = LANGUAGES[code]
    except KeyError as exc:
        raise SystemExit(
            f"Unknown language {code!r}. Known languages: {', '.join(LANGUAGES)}"
        ) from exc
    if cfg.mod_root is None:
        raise SystemExit(
            f"Language {code!r} has no mod_root configured yet (see langpack_common.py); "
            "nothing to generate."
        )
    return cfg


# ---------------------------------------------------------------------------
# Pack layout helpers (all under PACK_DIR / "languages" / <lang>)
# ---------------------------------------------------------------------------

def lang_pack_dir(lang: str) -> Path:
    return PACK_DIR / "languages" / lang


def manifest_txt_path(lang: str) -> Path:
    return lang_pack_dir(lang) / "manifest.txt"


def txt_dir(lang: str) -> Path:
    """cryoffear-relative text root: txt/txtfiles/languages/<lang>/ and txt/notes/languages/<lang>/"""
    return lang_pack_dir(lang) / "txt"


def inventoryitems_dir(lang: str) -> Path:
    """cryoffear-relative: mirrors cryoffear/inventoryitems/ (incl. ammo/, weapons/ subfolders)."""
    return lang_pack_dir(lang) / "inventoryitems"


def maps_dir(lang: str) -> Path:
    """cryoffear-relative: maps/<mapname>.ent"""
    return lang_pack_dir(lang) / "maps"


def textures_dir(lang: str) -> Path:
    """Sign/poster texture overrides, one file per unique texture name.

    NOTE this is a pack-internal folder name, not the literal deploy path. The
    FWGS engine's actual loose-texture override lookup for an embedded BSP
    miptex is Mod_SearchForTextureReplacement() in
    engine/common/mod_bmodel.c (search order: materials/<mapname>/<tex>.tga
    then materials/common/<tex>.tga), gated by the archived cvar
    host_allow_materials (default "0", must be set to 1). Since this mod's
    repainted miptex blobs are byte-identical across every map that uses a
    given name (BSP_ANALYSIS.md section 3), the correct deploy path for every
    file here is cryoffear/materials/common/<texname>.tga. See
    scripts/polish/README.md for the full citation.
    """
    return lang_pack_dir(lang) / "textures"


def overlay_dir(lang: str) -> Path:
    """cryoffear-relative verbatim-copy root for changed TGA/MDL assets."""
    return lang_pack_dir(lang) / "overlay"


def models_dir(lang: str) -> Path:
    """Studio-model texture overrides: models/<model path without .mdl>/<texture name>
    (8-bit BMP), applied by the engine at model load (CoF_Lang_StudioTextures)."""
    return lang_pack_dir(lang) / "models"


def strings_dir(lang: str) -> Path:
    return lang_pack_dir(lang) / "strings"


def dll_strings_tsv_path(lang: str) -> Path:
    return strings_dir(lang) / "dll-strings.tsv"


# ---------------------------------------------------------------------------
# Small generic helpers
# ---------------------------------------------------------------------------

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def write_bytes_atomic(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    with open(tmp, "wb") as fh:
        fh.write(data)
    os.replace(tmp, path)


def iter_pack_files(root: Path = PACK_DIR):
    for dirpath, _dirnames, filenames in os.walk(root):
        for name in filenames:
            yield Path(dirpath) / name


def write_manifest_txt(lang: str, *, pack_version: str, extra: Optional[dict] = None) -> Path:
    """Write pack/languages/<lang>/manifest.txt (display name, codepage, subtitle slot,
    version, authors, plus whatever extra key/value pairs the caller supplies).
    """
    cfg = LANGUAGES[lang]
    lines = [
        f"language_code={cfg.code}",
        f"display_name={cfg.display_name}",
        f"codepage={cfg.codepage_label}",
        f"codepage_name={cfg.codepage}",
        f"subtitle_language={cfg.subtitle_language}",
        f"pack_version={pack_version}",
        f"authors={cfg.authors}",
        f"notes={cfg.notes}",
    ]
    if extra:
        for k, v in extra.items():
            lines.append(f"{k}={v}")
    out = manifest_txt_path(lang)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return out


# ---------------------------------------------------------------------------
# Pack reduction guards (lang3, 2026-09-22): the pack carries only what the
# translators authored, never a file identical to the game.
# ---------------------------------------------------------------------------

def find_ci(path: Path) -> Optional[Path]:
    """`path` resolved case-insensitively (the game and the translation do not
    agree on case), or None."""
    if path.exists():
        return path
    cur = Path(path.anchor)
    for part in path.parts[1:]:
        try:
            match = [c for c in os.listdir(cur) if c.lower() == part.lower()]
        except OSError:
            return None
        if not match:
            return None
        cur = cur / match[0]
    return cur


_CANON_BY_SIZE: Optional[dict] = None
_CANON_HASH_CACHE: dict = {}


def game_identical(data: bytes) -> Optional[Path]:
    """The canonical game file whose bytes equal `data`, or None. Files are
    bucketed by size (one directory walk), and only same-size files are read."""
    global _CANON_BY_SIZE
    if _CANON_BY_SIZE is None:
        by = {}
        for p in iter_pack_files(CANONICAL_ROOT):
            try:
                by.setdefault(p.stat().st_size, []).append(p)
            except OSError:
                pass
        _CANON_BY_SIZE = by
    h = hashlib.sha256(data).hexdigest()
    for p in _CANON_BY_SIZE.get(len(data), []):
        if p not in _CANON_HASH_CACHE:
            _CANON_HASH_CACHE[p] = sha256_file(p)
        if _CANON_HASH_CACHE[p] == h:
            return p
    return None


class GameIdenticalError(SystemExit):
    pass


def write_pack_file(path: Path, data: bytes) -> None:
    """Every generator writes pack content through here: refuses bytes that
    are identical to ANY file of the canonical game."""
    same = game_identical(data)
    if same is not None:
        raise GameIdenticalError(f"refusing to write {path}: byte-identical to the game's {same}")
    write_bytes_atomic(path, data)


def decode_tga(data: bytes) -> tuple:
    """(width, height, RGBA bytes top-down) of an uncompressed or RLE TGA
    (types 2, 3, 10, 11; 8/24/32 bit). Used to tell a re-encoded copy of a
    game image from a repainted one."""
    idlen, cmtype, typ = data[0], data[1], data[2]
    cmlen = data[5] | data[6] << 8
    cmbits = data[7]
    w = data[12] | data[13] << 8
    h = data[14] | data[15] << 8
    bpp, desc = data[16], data[17]
    if cmtype or typ not in (2, 3, 10, 11) or bpp not in (8, 24, 32):
        raise ValueError(f"unsupported TGA type {typ} / {bpp} bpp / colour map {cmtype}")
    px = bpp // 8
    n = w * h
    off = 18 + idlen + (cmlen * ((cmbits + 7) // 8) if cmtype else 0)
    if typ in (2, 3):
        raw = data[off:off + n * px]
    else:
        out = bytearray()
        i = off
        need = n * px
        while len(out) < need:
            c = data[i]
            i += 1
            cnt = (c & 0x7F) + 1
            if c & 0x80:
                out += data[i:i + px] * cnt
                i += px
            else:
                out += data[i:i + px * cnt]
                i += px * cnt
        raw = bytes(out[:need])
    if len(raw) != n * px:
        raise ValueError("truncated TGA")
    rgba = bytearray(n * 4)
    if px == 1:
        rgba[0::4] = raw
        rgba[1::4] = raw
        rgba[2::4] = raw
        rgba[3::4] = b"\xff" * n
    else:
        rgba[0::4] = raw[2::px]
        rgba[1::4] = raw[1::px]
        rgba[2::4] = raw[0::px]
        rgba[3::4] = raw[3::px] if px == 4 else b"\xff" * n
    rows = [bytes(rgba[y * w * 4:(y + 1) * w * 4]) for y in range(h)]
    if not (desc & 0x20):
        rows.reverse()
    if desc & 0x10:
        rows = [b"".join(r[x * 4:x * 4 + 4] for x in range(w - 1, -1, -1)) for r in rows]
    return w, h, b"".join(rows)


# Art the fan translation changed that is NOT a translation (no language
# content, or a change beyond repainting text), found by the lang3 review of
# 2026-09-22 (stage1/lang3-20260922/RESULTS.md). The generators leave these
# out and list them in the pack README; delete a line to ship that file again.
#   overlay:  cryoffear- or platform-relative path, lower case, "/" separators
#   model:    "<model path>.mdl:<texture name>", lower case ("*" = any model)
EXCLUDED_ART: dict = {
    "polish": {
        "overlay": {
            "cryoffear/coficon.tga": "game icon repainted with a Polish-flag background; no text",
            "cryoffear/coficon_big.tga": "game icon repainted with a Polish-flag background; no text",
            "platform/resource/icon_steam.tga": "Steam browser icon repainted with a Polish-flag background; no text",
            "platform/resource/icon_steam_disabled.tga": "Steam browser icon repainted with a Polish-flag background; no text",
            **{f"cryoffear/gfx/vgui/notes/code_{d}.tga": "keypad-note digit redrawn in the translators' handwriting; no language content"
               for d in range(10)},
            "cryoffear/gfx/vgui/640_magazineart.tga": "magazine page: text translated, but the article topic "
            "(weight loss -> alcohol) and the photograph (a different person) were replaced as well",
        },
        "model": {
            "*:buttons_fullbright.bmp": "45 stray pixels changed, no text (phone keypad glow)",
            "models/weapons/mobile/w_mobile.mdl:tex1.bmp": "phone skin: only a 'Sony Ericsson' logo added, no text",
        },
    },
}
