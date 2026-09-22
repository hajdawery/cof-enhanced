# Language packs

`languages/<code>/` holds **native, engine-loadable language packs** for
Cry of Fear translations — data only, generated from a source translation
tree by the scripts in [`scripts/polish/`](../scripts/polish/README.md),
never by launching the game. That folder's README is the format spec: this
page just summarises it and records what lives under `languages/` today.

## What a language pack is

A pack is one folder per language code (`languages/polish/`, and later
`languages/ukrainian/`) with a fixed, generic layout — nothing in the
generator scripts hardcodes a language name or code page, only a
`LANGUAGES` table does. The pack is *not* a mirror of the `cryoffear/...`
game tree: different asset kinds need different mount strategies at deploy
time (per-language-slot text vs. a global loose-texture override vs. a
verbatim same-path overlay vs. a pure data table), so files are grouped by
mechanism instead, each subfolder internally using cryoffear-relative paths
where that matters. The format reference (every part, the entity-patch
and model-texture formats, the rules the generators enforce) is
[`docs/design/language-pack-format.md`](../docs/design/language-pack-format.md);
the generators and the regeneration command are in
[`scripts/polish/README.md`](../scripts/polish/README.md).

A pack holds **only what its translators authored** (pack reduction,
2026-09-22): translated text, the entity key/value pairs they changed, and the
textures and images they repainted. Nothing in a pack is identical to a game
file, and no pack contains a whole map, entity list or model.

## Layout

```
languages/
  README.md                  this file
  polish/
    README.md                pack-specific provenance, transforms, licensing
    manifest.txt              display name, codepage, subtitle_language (client slot), version, authors
    MANIFEST.tsv               path <TAB> bytes <TAB> sha256, every file under languages/polish/
    txt/                      language-slot text (txtfiles/languages/polish/, notes/languages/polish/), cp1250
    inventoryitems/           mirrors cryoffear/inventoryitems/ (incl. ammo/, weapons/), cp1250
    LICENSE-NOTE.md           terms of the pack (hand-maintained)
    maps/                     per-map .entpatch entity patches: the translated key/values only, cp1250
    textures/                 repainted world sign/poster textures, one TGA per unique texture name
    models/                   repainted textures embedded in studio models, <model path>/<texture>.bmp (8-bit)
    overlay/                  translated interface images, same path as the game's (TGA only)
    strings/dll-strings.tsv   English -> Polish DLL string table (client.dll / hl.dll)
    strings/menu-strings.tsv  English -> Polish strings of this project's menu (hand-maintained)
  dutch/ french/ german/ norwegian/ spanish/ swedish/
                              minimal packs (lang2 round 2): the game already ships these six
                              subtitle languages; each pack holds only README.md, manifest.txt
                              (codepage 1252, subtitle_language 2..7), MANIFEST.tsv,
                              strings/menu-strings.tsv (the menu, machine-drafted) and
                              LICENSE-NOTE.md (GPL-3.0-or-later: no game text in these six)
```

A **minimal pack** is the smallest thing the menu lists as a language: a
`manifest.txt` and a `strings/menu-strings.tsv`. With no `overlay/`, `txt/`,
`maps/`, `textures/` or `dll-strings.tsv` the engine mounts nothing, its DLL
string table stays empty (one warning line in the log) and the code page stays
1252; only the client subtitle slot and the menu strings change. The six
minimal packs use it to give the game's own Dutch ... Swedish subtitles a
translated menu.

## How the engine consumes this

`patches/cof-language-packs.patch` (see
[`docs/cof-language-packs.md`](../docs/cof-language-packs.md)) reads a pack
straight from `<game>/cryoffear/languages/<code>/`; nothing is copied or
renamed at install time and nothing in the game tree is modified. Copy the
folder there and set `cof_language <code>` (archived; empty is English):

- **`manifest.txt`** - `display_name`, `codepage` and `authors` are read; the
  code page goes into `cof_text_codepage` so the Inter font layer decodes the
  pack's bytes, and back to 1252 when the pack is turned off.
- **`overlay/cryoffear/`** is added on top of the engine search path (after
  every rescan), so its same-path files win over the game's.
- **`maps/<map>.entpatch`** is applied to the map's own entity string (the
  BSP lump, or a gamedir `.ent`) when the map loads: selected entities get the
  translated values, every other byte stays the game's. A full
  **`maps/<map>.ent`** in a pack (older packs) still replaces the whole lump
  and wins over the `.entpatch`; the "newer than the .bsp" rule is not applied
  to pack files.
- **`models/<model>/<texture>.bmp`** replaces that embedded texture of that
  studio model when the model loads (pixels and palette, same size), so no
  model file is shipped.
- **`textures/<name>.tga`** is probed before the embedded miptex of every
  world texture of that name (no `materials/` copy and no
  `host_allow_materials` needed).
- **`txt/`** and **`inventoryitems/`** replace the game's own `txtfiles/`,
  `notes/` and `inventoryitems/` reads, whether the game DLLs open them with
  their C runtime (an in-memory `CreateFileW` import hook of `client.dll` and
  `hl.dll`) or through the engine (`COM_LoadFileForMe`). The client's own
  `languages/<slot>/` folder in a path is ignored: the pack wins whatever
  subtitle language the game is set to.
- **`strings/dll-strings.tsv`** (UTF-8) is converted to the manifest's code
  page at load and replaces the strings compiled into the DLLs at draw time,
  exact match first, then `%s`/`%i`/`%d`-aware.

And the menu (`patches/cof-mainui-menu-strings.patch`,
`patches/cof-mainui-language-selector.patch`):

- **`strings/menu-strings.tsv`** (UTF-8) translates this project's own menu:
  main menu, every Options page, Extras, Unlockables, Credits, Save/Load,
  pause and death pages, dialogs, tooltips, the Controls list. Key = the
  English exactly as the menu draws it, same `%s`/`%d` rules. Missing rows
  stay English. Reloaded the moment `cof_language` changes.
- **`manifest.txt` `subtitle_language=`** is the client's own subtitle slot
  (`cof_subtitlelanguage`, 1 = English ... 7 = Swedish) that the menu's
  Language option sets together with `cof_language`; a missing key means 1.
  The menu has one language option (Options > Game > Language): English, then
  every installed pack sorted by its display name (Deutsch, Español, Français,
  Nederlands, Norsk, Polski, Svenska with the packs in this repository).

Text switches immediately, the menu included; map textures and entity
strings on the next map load; the client's VGUI art, which it loads once per
session, after a restart.

## Adding a language (template)

Nothing in the engine or the menu names a language: a pack folder is all it
takes. For a new language `<code>` (for example `ukrainian`, cp1251):

1. `languages/<code>/manifest.txt` (CRLF or LF, `key=value`):
   ```
   language_code=<code>
   display_name=<name in its own language, UTF-8>     e.g. Українська
   codepage=<1250|1251|1252>                           e.g. 1251
   subtitle_language=1
   pack_version=1.0.0
   authors=<translators>
   ```
2. The game's text as the generators produce it (`txt/`, `inventoryitems/`,
   `maps/`, `textures/`, `models/`, `overlay/`, `strings/dll-strings.tsv`),
   from a source translation: add the language to `LANGUAGES` in
   `scripts/polish/langpack_common.py` and run
   `python scripts/polish/build_all.py --lang <code> --out .`
   (see [`scripts/polish/README.md`](../scripts/polish/README.md)).
   Any subset works; what a pack lacks stays English.
3. The menu: `strings/menu-strings.tsv`. Start from the English list and
   check the result:
   ```
   powershell -File scripts\polish\extract-menu-strings.ps1 -MainUI <tree>\3rdparty\mainui -Out menu-strings.en.tsv
   (write languages\<code>\strings\menu-strings.tsv: english <TAB> translation)
   powershell -File scripts\polish\extract-menu-strings.ps1 -MainUI <tree>\3rdparty\mainui -Pack languages\<code>
   ```
   The check fails on a missing key, a dropped or added `%s`, or a character
   the menu fonts do not carry (they carry ASCII, Latin-1 from U+00A1, Latin
   Extended-A, Cyrillic U+0400-045F with Ґґ, and the cp1251 punctuation such as
   „ ” – — …). `languages/polish/strings/menu-strings.tsv` is the reference.
4. `MANIFEST.tsv`: `path <TAB> bytes <TAB> sha256` of every file but itself and
   `README.md`, sorted by path; and a `README.md` with the source, the
   permission and the creators (as `polish/README.md`).
5. Deploy: `stage1\deploy-ui-m3-20260921.ps1` copies a pack as a folder
   payload pinned by its `MANIFEST.tsv` hash and file count (one line in its
   `$packs` table per pack).

The pack then shows up in Options > Game > Language by its `display_name`.

## Licensing and attribution

Each pack's own `README.md` records its source, permissions and
attribution in full (see [`polish/README.md`](polish/README.md)). In
general: packs under `languages/` are derived from fan translations
incorporated into this repository with the originating team's explicit
permission, as a deliberate, recorded exception to this repository's
general no-game-assets policy — the translation text and derived overrides
here are licensed data, not a copy of the base game.
