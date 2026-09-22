# Cry of Fear native language-pack generators

The scripts here regenerate a **native, engine-loadable language pack** from
two read-only source trees:

- canonical game: `K:\LLM\COF_Fix\Cry of Fear` (never modified)
- source fan translation: `K:\LLM\COF_Fix\cof-spolszczenie-fanmade` (never
  modified; Polish is the only source so far)

The pack format, the engine side of every part and the two formats this
project defined (entity patches, model texture overrides) are documented in
[`docs/design/language-pack-format.md`](../../docs/design/language-pack-format.md).
This page is about the scripts.

Since the pack reduction of 2026-09-22 (lang3) a pack holds **only what the
translators authored**: translated text, the entity key/value pairs they
changed (`maps/*.entpatch`), and the world textures, model textures and
interface images they repainted. No generator writes a file identical to a
game file, a whole entity list or a whole model, and the last step checks the
whole pack for it.

## Command

From the repository root:

```
python scripts/polish/build_all.py --lang polish --out .
```

`--out <dir>` names the folder that holds `languages/`; `.` regenerates the
committed pack `languages/polish/` in place. Without `--out` the historical
build folder `stage1/polish-pack-20260922/pack/` is used. Hand-maintained
files are kept: `strings/menu-strings.tsv` (this project's menu) and
`LICENSE-NOTE.md`. The run takes about ten seconds and is deterministic: a
second run into an empty folder seeded with those two files reproduces the
committed pack byte for byte (checked 2026-09-22 in `stage1/lang3-20260922`).

## Steps

`build_all.py` runs, in order (each also runs alone with `--lang <code>`; set
`COF_LANGPACK_OUT=<dir>` for the output folder):

| Script | Output | Source |
|---|---|---|
| `build_txt_pack.py` | `txt/` (language-slot text), `inventoryitems/` | the translation's `txtfiles/`, `notes/`, `inventoryitems/`; files byte-identical to the game are skipped (nine `weapons/weapon_*.txt` in the Polish source); two encoding anomalies repaired |
| `build_maps_entpatch.py` | `maps/<map>.entpatch` | entity lumps of both BSP trees, compared entity by entity; asset-path rewrites (`.wav/.mdl/.spr/.tga` or `/` in the game's value) excluded; verified by applying each patch (`entpatch.py`) |
| `extract_sign_textures.py` | `textures/<name>.tga` | embedded miptex of both BSP trees; images identical to any game miptex or WAD texture of that name are dropped |
| `build_model_textures.py` | `models/<model>/<texture>.bmp` | both model trees: a model must differ only in texture pixels/palettes, else it is reported and left out |
| `copy_overlay_assets.py` | `overlay/` | the translation's changed TGAs (cryoffear/ and platform/), minus font strips, pixel-identical re-encodes and the review list |
| `build_dll_strings_tsv.py` | `strings/dll-strings.tsv` | the binary string-diff tables in `stage1/polish-mod-analysis-20260922/binaries/data/` and `string_overrides_polish.tsv` |
| `build_manifest.py` | `manifest.txt`, `README.md`, `MANIFEST.tsv` | the pack on disk; fails on any rule violation |

Shared code: `langpack_common.py` (paths, the `LANGUAGES` table, the
game-identity guard `write_pack_file`, a TGA decoder, the `EXCLUDED_ART`
review list), `entpatch.py` (the entity-patch format: parser, applier,
writer; the engine's `cof_entpatch.c` implements the same rules).

`extract-menu-strings.ps1` lists this project's menu strings and checks a
pack's `strings/menu-strings.tsv` (see `docs/cof-language-packs.md`).

## The review list (`EXCLUDED_ART`)

Some art the fan translation changed is not a translation: the game icon with
a Polish-flag background, keypad digits redrawn in the translators'
handwriting, a magazine page whose article and photograph were replaced, a
phone skin with only a brand logo added, 45 stray pixels on a keypad glow.
They are listed with the reason in `langpack_common.EXCLUDED_ART["polish"]`,
left out by the generators and listed in the pack README; deleting a line
ships that file again.

## Generic across languages

Nothing here hardcodes "polish" or a code page: every script takes `--lang`
and reads the source tree, code page, display name, subtitle slot and authors
from `LANGUAGES` in `langpack_common.py`. A `ukrainian` (cp1251) entry exists
as a stub without a source tree. To add a language: fill in its entry (and an
`EXCLUDED_ART` entry if needed), run `build_all.py --lang <code> --out .`,
and add `strings/menu-strings.tsv` and `LICENSE-NOTE.md` by hand.

## Why the world textures are one file per name

`textures/<name>.tga` is probed by the engine for every world texture of that
name in every map (`CoF_Lang_TextureReplacement`, before
`Mod_SearchForTextureReplacement`'s `materials/` paths and without
`host_allow_materials`). That is correct because every repainted miptex of a
given name is byte-identical across all maps that use it
(`extract_sign_textures.py` checks it and fails on a conflict). Names starting
with `{` (alpha-masked) keep the `{` in the file name and are written as
32-bit TGAs with palette index 255 transparent.
