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
where that matters. See
[`scripts/polish/README.md`](../scripts/polish/README.md) for the full
spec, the manifest.txt field list, the exact engine texture-override path
(`Mod_SearchForTextureReplacement`), and the regeneration commands.

## Layout

```
languages/
  README.md                  this file
  polish/
    README.md                pack-specific provenance, transforms, licensing
    manifest.txt              display name, codepage, client subtitle slot, version, authors
    MANIFEST.tsv               path <TAB> bytes <TAB> sha256, every file under languages/polish/
    txt/                      language-slot text (txtfiles/languages/polish/, notes/languages/polish/), cp1250
    inventoryitems/           mirrors cryoffear/inventoryitems/ (incl. ammo/, weapons/), cp1250
    maps/                     per-map .ent entity-lump overrides, cp1250, GoldSrc .ent text format
    textures/                 repainted sign/poster textures, one TGA per unique texture name
    overlay/                  verbatim same-path TGA/MDL overlay assets (UI textures, models)
    strings/dll-strings.tsv   English -> Polish DLL string table (client.dll / hl.dll)
```

## How the engine will consume this (planned, not implemented)

Nothing in the engine or game DLLs reads a `languages/<code>/` pack yet.
The consumer side is future engine/menu work; the plan recorded so far is:

- **Engine-loaded assets** (textures, maps, models under `textures/`,
  `maps/`, `overlay/`) mount through an engine-side `cryoffear_<lang>/`
  game directory, using FWGS's existing search-path layering — the same
  mechanism that already mounts `<gamedir>_<fs_language>/`.
- **Text the game DLLs open themselves** (`txt/`, `inventoryitems/`) is
  invisible to the engine filesystem: both `client.dll` and `hl.dll` open
  these files through a single static `KERNEL32!CreateFileW` import built
  from the bare game directory. The planned fix is a **runtime import
  hook** — the engine hooks that import thunk in each DLL at load time
  (in memory, disk untouched) and redirects read-only opens under
  `txtfiles\`, `notes\`, `\inventoryitems\` to the active pack.
- **Strings compiled into the DLLs** (`strings/dll-strings.tsv`) have no
  file-based slot at all, so they are substituted at **draw time** — a
  string table looked up at the engine's own text-drawing call sites
  (VGUI `TextImage::setText`, `CL_DrawString` / `CL_DrawStringLen`) rather
  than patched into the binaries.
- **Rendering** must be **code-page aware**: the pack's `manifest.txt`
  names a code page (`1250` for Polish), and the engine's font layer needs
  to decode each text byte through the pack's code page immediately before
  glyph lookup, rather than assuming a single fixed table.

None of this is wired up yet — this folder only carries the prepared data
so the engine/menu work can consume it once it lands.

## Licensing and attribution

Each pack's own `README.md` records its source, permissions and
attribution in full (see [`polish/README.md`](polish/README.md)). In
general: packs under `languages/` are derived from fan translations
incorporated into this repository with the originating team's explicit
permission, as a deliberate, recorded exception to this repository's
general no-game-assets policy — the translation text and derived overrides
here are licensed data, not a copy of the base game.
