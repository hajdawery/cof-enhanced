# Cry of Fear native language-pack generators

Scripts here regenerate a **native, engine-loadable language pack** from two
read-only source trees:

- Canonical game: `K:\LLM\COF_Fix\Cry of Fear` (never modified)
- Source fan translation: `K:\LLM\COF_Fix\cof-spolszczenie-fanmade` (never modified, Polish only for now)

Output goes only to `K:\LLM\COF_Fix\stage1\polish-pack-20260922\pack\`. Nothing
under `cof-fix\` is written except this `scripts\polish\` folder. Nothing is
committed and the game is never launched by these scripts.

Analysis this is built from lives under
`K:\LLM\COF_Fix\stage1\polish-mod-analysis-20260922\` (`bsp\`, `text\`,
`assets\`, `binaries\`, `fonts\`) and is treated as read-only input.

## Why a "language pack" format, not a game-tree overlay

The pack is deliberately **generic across languages**, not Polish-specific,
so a Ukrainian (or other) pack can be produced later by the same scripts:
every script takes `--lang <code>` and reads its config (display name, code
page, source mod tree) from `LANGUAGES` in `langpack_common.py`. Nothing in
any script hardcodes "polish" or "cp1250" — only `langpack_common.py`'s
`LANGUAGES` table does, and only for the `polish` entry (a `ukrainian` stub
with `cp1251` exists already, disabled until a source tree is supplied).

The pack does **not** mirror the raw `cryoffear/...` game-tree paths at its
top level. Different asset kinds need different mount strategies at deploy
time (per-language-slot text vs. a global loose-texture override vs. a
verbatim same-path overlay vs. a pure data table), so the pack groups files
by *mechanism* instead, each subfolder internally using cryoffear-relative
paths where that matters. How the pack is *mounted* into a running game tree
is a decision for later work; these scripts only produce the data.

## Layout

```
pack/
  MANIFEST.tsv                         path <TAB> bytes <TAB> sha256, every file under pack/
  README.md                            this pack's contents, totals, exclusions
  languages/
    polish/
      manifest.txt                     display name, codepage, client subtitle slot, version, authors
      txt/
        txtfiles/languages/polish/*.txt   cryoffear-relative -- subtitles/hints/conclusions/phone text
        notes/languages/polish/*.txt      cryoffear-relative -- readable in-world notes
      inventoryitems/
        ...mirrors cryoffear/inventoryitems/ (incl. ammo/, weapons/ subfolders)...
      maps/
        <mapname>.ent                  entity-lump overrides, cp1250 bytes, GoldSrc .ent text format
      textures/
        <texname>.tga                  repainted sign/poster textures, one file per unique name
      overlay/
        ...cryoffear-relative paths for verbatim-copied changed TGA/MDL assets...
      strings/
        dll-strings.tsv                English -> Polish DLL string table (client.dll / hl.dll)
    ukrainian/                          (future; not generated yet -- no source tree)
```

Every generator is idempotent and safe to re-run: it recomputes its slice of
`pack/languages/<lang>/` from the two source trees and overwrites in place.

## manifest.txt fields

`language_code`, `display_name`, `codepage` (numeric label, e.g. `1250`),
`codepage_name` (Python codec name, e.g. `cp1250`), `client_subtitle_slot`
(currently `none` for Polish -- see below), `pack_version`,
`source_mod_root`, `notes`.

**Client subtitle slot:** the canonical client's language selector only
enumerates `dutch/french/german/norwegian/spanish/swedish` (+ English
default) via the existing `cryoffear/txtfiles/languages/<lang>/` and
`cryoffear/notes/languages/<lang>/` folder convention; that list is compiled
into `client.dll`/`hl.dll` `.text`, which the mod's own binary analysis found
byte-identical to canonical (no code was changed by the mod at all -- see
`stage1/polish-mod-analysis-20260922/binaries/BINARIES_ANALYSIS.md` section
1). No text/config file overrides that list. So there is currently **no
in-menu way to select Polish**; wiring a menu entry is future engine/menu
work and out of scope for this data-preparation pack. The pack's `txt/`
folder still follows the exact same `languages/polish/` naming convention
the client already understands for file *lookup*, so a future menu change
(or a direct `cof_subtitlelanguage`-style override) can point at it without
any data migration.

## Engine texture-override path (part 3)

`textures/<texname>.tga` in this pack is **not** the literal in-game deploy
path. The FWGS engine's actual lookup for an external replacement of an
embedded BSP miptex is `Mod_SearchForTextureReplacement()` in
`engine/common/mod_bmodel.c` (checked against
`K:\LLM\COF_Fix\cof-fix\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a`):

```c
static qboolean Mod_SearchForTextureReplacement( char *out, size_t size, const char *modelname, const char *texname, const char *type )
{
	const char *subdirs[] = { modelname, "common" };

	for( int i = 0; i < ARRAYSIZE( subdirs ); i++ )
	{
		if( Q_snprintf( out, size, "materials/%s/%s%s.tga", subdirs[i], texname, type ) < 0 )
			continue; // truncated name

		if( g_fsapi.FileExists( out, false ))
			return true; // found, load it
	}
	...
}
```

called from `Mod_LoadTextureData()` (same file) before falling back to the
BSP's embedded WAD/internal miptex, and gated by
`Mod_AllowMaterials()` (`engine/common/common.h:166`), which requires the
archived cvar `host_allow_materials` to be non-zero (default `"0"`, defined
`engine/common/host.c:82`; verbose per-texture load reporting needs it set
to exactly `2`).

`modelname` is the loading model's own name (e.g. `maps/c_apartment1.bsp`
for a world texture), so a true per-map override would live at
`materials/maps/<map>.bsp/<texname>.tga`. But `BSP_ANALYSIS.md` section 3
established that every repainted miptex with a given name is byte-identical
across all maps that use it, so a single **`materials/common/<texname>.tga`**
override is correct and sufficient for all 110 textures — this is exactly
why the analysis asked for "one file per unique texture name" rather than
per-map duplicates. **Deploy target for every file under `textures/` in this
pack is therefore `cryoffear/materials/common/<texname>.tga`**, with
`host_allow_materials` set to at least `1` at runtime.

Alpha-masked textures (name starts with `{`) keep that literal `{` in the
filename (the engine only replaces a leading `*` with `!`, never touches
`{`), so e.g. `{c3_asyrules` -> `textures/{c3_asyrules.tga`.

## Regeneration

Run `build_all.py`, which runs every step below in order for one language:

```
python scripts/polish/build_all.py --lang polish
```

Equivalent to running each generator individually (parts 1-5 are mutually
independent and only read the two source trees + `langpack_common.py`; part
6 must run last since it reads every other part's output):

```
python scripts/polish/build_txt_pack.py         --lang polish   # txt/ + inventoryitems/
python scripts/polish/build_maps_ent.py         --lang polish   # maps/*.ent
python scripts/polish/extract_sign_textures.py  --lang polish   # textures/*.tga
python scripts/polish/copy_overlay_assets.py    --lang polish   # overlay/...
python scripts/polish/build_dll_strings_tsv.py  --lang polish   # strings/dll-strings.tsv
python scripts/polish/build_manifest.py         --lang polish   # manifest.txt + pack/MANIFEST.tsv + pack/README.md
```

Every script is idempotent: re-running any of them overwrites its slice of
`pack/languages/<lang>/` in place from the read-only source trees, so the
whole pack can always be regenerated from scratch with `build_all.py`.

To add a future language (e.g. Ukrainian): add its `mod_root`, `codepage`,
`display_name` etc. to `LANGUAGES` in `langpack_common.py` (a disabled
`ukrainian`/cp1251 stub already exists there), then run
`build_all.py --lang ukrainian` once a source translation tree exists. No
generator script needs to change.

## Totals (Polish, generated 2026-09-22)

| Part | Folder | Files |
|---|---|---:|
| 1a | `txt/` | 17 (9 txtfiles + 8 notes; `credits.txt` has no slot, excluded) |
| 1b | `inventoryitems/` | 88 (2 encoding anomalies fixed) |
| 2 | `maps/` | 100 `.ent` files (4 of 1345 changed pairs excluded as asset paths) |
| 3 | `textures/` | 110 TGAs (3 alpha-masked) |
| 4 | `overlay/` | 225 (202 TGA + 23 MDL) |
| 5 | `strings/dll-strings.tsv` | 216 data rows (16 of 232 raw pairs excluded) |
| 6 | `manifest.txt`, `MANIFEST.tsv`, `README.md` | pack-level metadata, 543-row file manifest |

Full narrative (exclusions, data-quality notes, per-row detail) is in the
generated `pack/README.md` — regenerate it any time with `build_manifest.py`
rather than editing it by hand, since it re-derives every number from the
files on disk instead of trusting prior reports.
