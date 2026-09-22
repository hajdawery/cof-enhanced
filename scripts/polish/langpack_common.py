#!/usr/bin/env python3
"""Shared config and helpers for the Cry of Fear native language-pack generators.

This module is deliberately generic: every generator script under
scripts/polish/ imports LANGUAGES from here and takes a --lang argument
instead of hardcoding "polish" anywhere, so a future Ukrainian (or other)
language pack can reuse the exact same scripts by adding one entry below
and supplying its own source mod tree.

Directory layout this module encodes (see scripts/polish/README.md for the
full spec and rationale):

    <PACK_ROOT>/pack/languages/<lang>/
        manifest.txt                       language metadata (see write_manifest_txt)
        txt/
            txtfiles/languages/<lang>/*.txt   cryoffear-relative: language-slot subtitles/notes text
            notes/languages/<lang>/*.txt
        inventoryitems/
            <mirrors cryoffear/inventoryitems/ ...>   pickup/weapon nice_name + description text
        maps/
            <mapname>.ent                     entity-lump overrides (cp1250 bytes, GoldSrc .ent format)
        textures/
            <texname>.tga                     sign/poster texture overrides (deploy target:
                                               cryoffear/materials/common/<texname>.tga -- see README)
        overlay/
            <cryoffear-relative path>          verbatim changed TGA/MDL assets, same relative path
        strings/
            dll-strings.tsv                    English -> localized DLL string table

    <PACK_ROOT>/pack/MANIFEST.tsv          path, bytes, sha256 for every file under pack/
    <PACK_ROOT>/pack/README.md             human-readable summary of the whole pack

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
PACK_ROOT = PROJECT_ROOT / "stage1" / "polish-pack-20260922"             # only writable location
PACK_DIR = PACK_ROOT / "pack"


@dataclass(frozen=True)
class LanguageConfig:
    code: str                     # language slug used as folder name, e.g. "polish"
    display_name: str             # human-readable name in its own language, e.g. "Polski"
    codepage: str                 # python codec name used for on-disk bytes, e.g. "cp1250"
    codepage_label: str           # numeric Windows code page label for manifest.txt, e.g. "1250"
    mod_root: Optional[Path]      # read-only source mod tree for this language, or None if not built yet
    client_subtitle_slot: str     # value to record in manifest.txt; "none" if not wired into the client
    notes: str = ""


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
        # (checked: no languages.cfg or similar). So there is currently no in-menu selector for
        # this pack; the loader must select it some other way (out of scope for this data pack).
        client_subtitle_slot="none (not present in the client's hardcoded language list; "
        "menu wiring is future engine/menu work, not part of this data pack)",
        notes="Source: cof-spolszczenie-fanmade fan translation. No credits/readme file identifying "
        "individual translators was found in the mod tree; authors are recorded as unknown.",
    ),
    "ukrainian": LanguageConfig(
        code="ukrainian",
        display_name="Українська",
        codepage="cp1251",
        codepage_label="1251",
        mod_root=None,  # no source mod tree yet -- entry exists only to prove parameterisation
        client_subtitle_slot="none (not present in the client's hardcoded language list)",
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
        f"client_subtitle_slot={cfg.client_subtitle_slot}",
        f"pack_version={pack_version}",
        f"source_mod_root={cfg.mod_root}",
        f"notes={cfg.notes}",
    ]
    if extra:
        for k, v in extra.items():
            lines.append(f"{k}={v}")
    out = manifest_txt_path(lang)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return out
