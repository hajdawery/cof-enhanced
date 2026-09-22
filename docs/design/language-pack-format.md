# Language pack format

A language pack is one folder, `languages/<code>/`, that the engine reads in
place from `<game>/cryoffear/languages/<code>/` when `cof_language <code>` is
set (Options > Game > Language does that). This page is the format reference:
what may be in a pack, how the engine applies each part, the two formats this
project defined (entity patches and model texture overrides), and how the
Polish pack is generated. The engine side is `patches/cof-language-packs.patch`
(see [`language-packs.md`](language-packs.md) for its design and cvars);
the menu side is `cof-mainui-language-selector.patch` and
`cof-mainui-menu-strings.patch`.

A pack carries **only what its translators wrote**: text, the entity values
they changed, and the images and textures they repainted. It never contains a
file identical to the game, a whole map, a whole entity list or a whole model.
The Polish generators enforce this (see [Rules](#rules-checked-by-the-generators)).

## Layout

```
languages/<code>/
  manifest.txt                      required: key=value metadata (below)
  README.md                         creators, source, permission, contents
  LICENSE-NOTE.md                   terms of the pack (packs are not GPL)
  MANIFEST.tsv                      path <TAB> bytes <TAB> sha256 of every file except itself and README.md
  txt/txtfiles/languages/<code>/*.txt   subtitles, hints, conclusions, phone messages (pack code page)
  txt/notes/languages/<code>/*.txt      readable notes (pack code page)
  inventoryitems/**/*.txt           item and weapon names/descriptions, mirrors cryoffear/inventoryitems/
  maps/<map>.entpatch               entity patch: the map's translated key/value pairs
  textures/<texname>.tga            repainted WORLD texture (BSP miptex of that name, any map)
  models/<model path>/<tex>.bmp     repainted texture EMBEDDED in a studio model
  overlay/cryoffear/**              interface images etc., same path as the game's file
  strings/dll-strings.tsv           English -> translation of strings compiled into client.dll / hl.dll
  strings/menu-strings.tsv          English -> translation of this project's menu
```

Every part is optional; what a pack lacks stays English. The smallest pack the
menu lists is `manifest.txt` + `strings/menu-strings.tsv` (the six "minimal"
packs for the game's own subtitle languages).

### manifest.txt

```
language_code=polish
display_name=Polski
codepage=1250                 1250 | 1251 | 1252: the bytes of txt/, inventoryitems/, maps/
codepage_name=cp1250
subtitle_language=1           client subtitle slot the Language option sets (1 = English)
pack_version=1.2.0
authors=Avioo, Mixdedemon, hexag0n, Izonka
notes=free text
```

The engine reads `display_name`, `codepage` and `authors`; the menu reads
`display_name` and `subtitle_language`.

## How each part is applied

| Part | When | Mechanism |
|---|---|---|
| `txt/`, `inventoryitems/` | every open | the game DLLs' own file opens (a `CreateFileW` import hook of client.dll/hl.dll) and their engine-FS loads are redirected to the pack's file when it has one |
| `strings/dll-strings.tsv` | draw time | FreeVGUI `TextImage::setText` and the engine font path substitute exact and `%s`-aware matches |
| `overlay/cryoffear/` | search path | mounted on top of the game directory after every rescan: a file there replaces the game's file of the same path |
| `textures/<name>.tga` | map load | probed before the embedded miptex of every world texture of that name, without `host_allow_materials` |
| `maps/<map>.entpatch` | map load | applied to the map's entity string (below) |
| `models/.../<tex>.bmp` | model load | written into the engine's copy of the model before its textures are uploaded (below) |
| `strings/menu-strings.tsv` | draw time (menu) | the menu's `L()` layer |

Text switches at once; map text, world textures and model textures on the
next load of that map or model (a model already in memory keeps its textures
until it is loaded again, usually the next map; a restart always does it);
the client's VGUI art after a restart.

## Entity patches (`maps/<map>.entpatch`)

The fan translation changed only values in the maps' entity lumps (door
"locked" lines, trigger messages, chapter titles, objective boards, ...). A
pack carries just those values, addressed by selectors, instead of the whole
entity list.

### Format (entpatch 1)

Plain bytes: ASCII syntax, values in the pack's code page, `\n` line ends.
`//` starts a comment outside a block. Each block is `{ "key" "value" ... }`:

```
// Cry of Fear: Enhanced entity patch (entpatch 1)
{
"@entity" "401"                 index of the entity in the base entity string (a hint)
"@classname" "inter_door"       selectors: the entity's FIRST value of that key must be exactly this
"@model" "*12"                  any "@<key>" other than @entity, @op, @crc:<key> is a selector
"@crc:lockedmsg" "5b81aec3"     optional precondition: CRC-32 (IEEE/zlib, lowercase hex)
                                of the value being replaced; a mismatch skips that key
"lockedmsg" "Drzwi ani drgną."  plain key: replace the entity's first value of that key,
                                or append the pair if the entity has no such key
}
{ "@op" "remove" "@entity" "12" "@classname" "info_target" "@targetname" "x" }   drop an entity
{ "@op" "add" "classname" "info_target" "targetname" "y" "origin" "0 0 0" }        append an entity
```

The Polish generator writes `@entity`, `@classname`, and `@targetname`,
`@origin`, `@model` when the entity has them, plus `@crc:<key>` for every
replaced value. It does not emit `add`/`remove` (the translation added or
removed no entity); the engine supports both.

### Semantics (engine and Python reference are identical)

1. **Base string.** The entity string the map would load anyway, after the
   normal override logic: the BSP's entity lump, or a newer gamedir
   `maps/<map>.ent`. If the pack itself has a full `maps/<map>.ent` (older
   packs), that replaces the string and the `.entpatch` is ignored.
2. **Selection** (for edit and remove blocks, in file order): candidates are
   the entities not yet removed whose selectors all match; take the one at
   `@entity` if it is a candidate, else the only candidate, else the
   candidate nearest to `@entity` (a tie is ambiguous). No candidate or an
   ambiguous one: the block is skipped and logged. So a patch still lands
   when an override before it removed or added entities (index shift), and
   never guesses between two equal matches.
3. **Edit.** For each plain key: if the entity has it, the CRC precondition
   (if any) is checked against the entity's current value, then the value is
   replaced; if the entity lacks it, `"key" "value"` is appended before the
   closing brace.
4. **Splicing.** The base string is never re-serialised: only the bytes of
   replaced values change, appended pairs go before the `}`, removed entities
   are cut from `{` through `}` and one following newline, added entities are
   appended at the end. Everything else stays byte for byte, so the result is
   exactly what a hand-made full `.ent` with those values would be.

The engine logs `Applied entity patch: languages/<code>/maps/<map>.entpatch
(N value(s), R removed, A added, S skipped)` and one warning line per skipped
block or key. Code: `engine/common/cof_entpatch.c` (plain C, no engine
dependencies), called from `Mod_LoadEntities` and `SV_ReadEntityScript`
through `CoF_Lang_ApplyEntityPatch`. Reference implementation:
`scripts/polish/entpatch.py`.

## Model texture overrides (`models/<model>/<texture>.bmp`)

The signs, newspapers, phone screens and book pages the translators repainted
on props and weapons are textures embedded in `.mdl` files. A pack carries
only those textures:

```
languages/<code>/models/<model path without .mdl>/<texture name>
languages/polish/models/weapons/mobile/v_mobile/fullbright_mess1.bmp
languages/polish/models/Props/UtomhusD/sandlada/sand1.bmp
```

The texture name is the name stored in the model (`mstudiotexture_t.name`,
extension included; `.bmp` is appended if the name has none). The file is an
**8-bit indexed BMP** (BITMAPINFOHEADER, no compression, up to 256 palette
entries, bottom-up or top-down rows) with **exactly the texture's width and
height**. When the engine loads a studio model (`Mod_LoadStudioModel`, both
the embedded-texture path and the `<model>T.mdl` path), it looks up every
texture of the model in the pack and copies the BMP's indices and palette over
the texture's pixels and palette in its own copy of the model, before the
renderer uploads the textures. The client's studio renderer and the engine's
see the same data; the file on disk, the model CRC and everything else in the
model are untouched. A BMP of the wrong size or format is refused with a
warning and the model keeps its own texture. Log: `Model textures from the
language pack: <model> (N)`; per texture with `developer 1`.

Model texture flags (fullbright, chrome, masked) are the model's own; a pack
cannot change them. Paths are matched as the game requests them; on a
case-sensitive file system the pack's folder and file names must match the
model and texture names' case.

## Rules checked by the generators

`scripts/polish/build_all.py` (Polish, and any language added to
`LANGUAGES` in `langpack_common.py`) fails when the pack would break them:

- no file byte-identical to any file of the game (every generator writes
  through `langpack_common.write_pack_file`; `build_manifest.py` re-checks the
  whole pack);
- no overlay image whose pixels equal the game's image at that path, and no
  world texture identical to any game miptex or WAD texture of that name;
- no `.mdl` and no `.ent` in the pack; a translation model that differs from
  the game outside its texture pixels and palettes is reported and left out;
- art listed in `langpack_common.EXCLUDED_ART` (changed for reasons other
  than translation) is left out and listed in the pack README.

## Generating the Polish pack

From the repository root, with the canonical game at `K:\LLM\COF_Fix\Cry of
Fear` and the fan translation at `K:\LLM\COF_Fix\cof-spolszczenie-fanmade`
(both read-only; paths in `scripts/polish/langpack_common.py`):

```
python scripts/polish/build_all.py --lang polish --out .
```

This rewrites every generated part of `languages/polish/` in place and keeps
the hand-maintained `strings/menu-strings.tsv` and `LICENSE-NOTE.md`. Steps:

| Script | Output |
|---|---|
| `build_txt_pack.py` | `txt/`, `inventoryitems/` (skips files identical to the game) |
| `build_maps_entpatch.py` | `maps/*.entpatch` from the two BSP trees' entity lumps |
| `extract_sign_textures.py` | `textures/*.tga` from the two BSP trees' embedded miptex |
| `build_model_textures.py` | `models/**/<tex>.bmp` from the two model trees |
| `copy_overlay_assets.py` | `overlay/` (translated TGAs, byte-for-byte) |
| `build_dll_strings_tsv.py` | `strings/dll-strings.tsv` (reads the binary string-diff tables in `stage1/polish-mod-analysis-20260922/binaries/data/` and `string_overrides_polish.tsv`) |
| `build_manifest.py` | `manifest.txt`, `README.md`, `MANIFEST.tsv`, pack-wide checks |

`--out <dir>` writes to `<dir>/languages/polish/` instead (copy the two
hand-maintained files there first to reproduce the committed pack byte for
byte). Without `--out` the historical stage1 folder is used.

Adding a language: an entry in `LANGUAGES` (`langpack_common.py`) with its
source tree, code page and subtitle slot, optionally an `EXCLUDED_ART` entry,
then `build_all.py --lang <code> --out .`, a `menu-strings.tsv` and a
`LICENSE-NOTE.md`.
