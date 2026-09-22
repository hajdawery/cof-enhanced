# Language packs (`cof_language`)

`patches/cof-language-packs.patch` (engine + FreeVGUI, applied by
`scripts/apply-cof-language-packs.ps1`) lets the game run in another language
from a data-only pack, without touching a single game file. It is generic: the
only language-specific inputs are the pack's folder name and the code page its
manifest declares. The Polish pack in [`languages/polish`](../../languages/README.md)
is the first one; Ukrainian (cp1251) needs no engine change.

The investigation this is built on is
`stage1/polish-file-access-20260922/RESULTS.md`. Where this document disagrees
with it, the measurement here is newer (section 4).

## 1. Using it

| cvar / command | default | meaning |
| --- | --- | --- |
| `cof_language` | `""` (archived) | pack folder under `cryoffear/languages/`; empty is English and turns every part of this off |
| `cof_language_strings` | `1` (archived) | draw-time replacement of the strings compiled into the DLLs |
| `cof_language_files` | `1` (archived) | redirect of the DLLs' own `txtfiles/`, `notes/`, `inventoryitems/` reads |
| `cof_language_trace` | `0` | developer: log every file the game DLLs open, redirected or not |
| `cof_language_list` | | packs found, with display name, code page, authors |
| `cof_language_status` | | active pack, hooks, redirect and substitution counters |
| `cof_language_apply` | | re-read the active pack from disk and remount it |

Install a pack by copying `languages/<code>/` to `<game>/cryoffear/languages/<code>/`
(check it against its `MANIFEST.tsv`), then `cof_language <code>`. The value is
archived, so the next start comes up in that language.

What switches when:

* **at start-up**, the pack named on the command line (`+cof_language x`,
  `+set cof_language x`) or in `config.cfg` is applied in `Host_Main` *before*
  the server and client libraries load (`CoF_Lang_EarlyApply`), so the fonts,
  panels and art the client builds at init already come from the pack;
* **immediately**, on a change in a running game: the string table, the code
  page and every text file the game opens from then on;
* **on the next map load**: repainted world textures and entity strings;
* **after a restart**: the client's VGUI art (it loads its panels once per
  session) and anything else the game DLLs cached at init.

## 2. The pack

```
cryoffear/languages/<code>/
    manifest.txt                 key=value: display_name, codepage (1250/1251/1252),
                                 subtitle_language (client slot, section 7), authors, ...
    overlay/cryoffear/**         same-path art and models (TGA, MDL)
    maps/<map>.ent               entity-lump overrides
    textures/<texname>.tga       repainted world textures (signs, posters)
    txt/txtfiles/languages/<code>/*.txt
    txt/notes/languages/<code>/*.txt
    inventoryitems/**.txt
    strings/dll-strings.tsv      english <TAB> localised <TAB> ... , UTF-8
    strings/menu-strings.tsv     the menu's own strings (section 8), UTF-8, hand-maintained
```

The layout is the one `scripts/polish/build_all.py` generates (all but
`strings/menu-strings.tsv`, which is written by hand); see
[`scripts/polish/README.md`](../../scripts/polish/README.md) for the generator and
the manifest fields. `<code>` must be a plain folder name (no `/ \ . :`).

## 3. Mechanisms

### 3.1 Activation (`engine/common/cof_language.c`, `host.c`, `filesystem_engine.c`)

`cof_language` is registered in `FS_Init`, so it exists before any config
runs. `CoF_Lang_EarlyApply` reads the value the command line or `config.cfg`
is about to set (command line wins, the last `config.cfg` line wins) and
applies it before `SV_Init`/`CL_Init`. `CoF_Lang_Frame`, at the top of every
`Host_Frame`, applies any later change. Applying parses the manifest, loads
the string table, pushes the code page into `cof_text_codepage` (1252 when
off; if the client has not registered that cvar yet it is set on the first
frame), and runs the stock `FS_Rescan_f`, at whose end `CoF_Lang_Remount` puts
the pack back on the search path.

The handful of lifecycle lines (hooks, activation, mount) are written with
`Sys_Print`: `Con_Printf` drops everything while `host.allow_console` is still
false, which is exactly when the libraries load and the pack is applied.

### 3.2 Engine-loaded assets: why not `<gamedir>_<language>`

FWGS already has a localisation mount - `ui_language` + `fs_mount_l10n` +
`fs_rescan` put `<rootdir>/<gamedir>_<language>/` on the search path
(`filesystem/searchpath.c:401`). It was the preferred option and it cannot be
pointed at a pack: it only ever mounts a **sibling of the game directory**
named after the language, while a pack lives **inside** it under
`languages/<code>/overlay/cryoffear/`. Using it would need a junction or a copy
created in the install at activation (and `ui_language` also drives MainUI's
own translation lookup and is persisted in `vfs.cfg`).

Instead the engine adds the overlay directory itself, with the same call the
l10n tier uses (`g_fsapi.AddGameDirectory`, flags
`FS_GAMEDIR_PATH | FS_NOWRITE_PATH | FS_CUSTOM_PATH`), after every rescan. It
lands at the head of the search path - above the game directory, `_hd`,
`_addon`, `_<language>` and `custom/` - is never the write path, and is still a
game-directory path, so `gamedironly` lookups see it. Nothing is written to
disk; the next rescan with the pack off simply does not add it.

`maps/<map>.ent` and `textures/<name>.tga` are not at their game-relative path
inside the pack, so they are probed by path:

* `Mod_LoadEntities` (client model load) and `SV_ReadEntityScript` (server map
  check) load `languages/<code>/maps/<map>.ent` when it exists. It wins over a
  game-directory `.ent` of the same name (a warning says so), and the engine's
  "entity patch must be newer than the .bsp" rule is **not** applied to it: the
  pack is installed data, and a copy that did not keep timestamps would
  otherwise silently switch a whole map back to English.
* `Mod_SearchForTextureReplacement` probes `languages/<code>/textures/<name>.tga`
  first, before `materials/` and **without** `host_allow_materials` (a language
  override is not an HD-materials opt-in; the stock `materials/` probe still
  requires the cvar). Every repainted miptex of one name is byte-identical
  across the maps using it, so one file per name is enough.

### 3.3 Text the game DLLs read themselves

Two paths, both covered by the same mapping:

```
txtfiles/[languages/<slot>/]<rest>  ->  languages/<code>/txt/txtfiles/languages/<code>/<rest>
                                    ->  languages/<code>/txt/txtfiles/<rest>
notes/...                           ->  the same under txt/notes/
inventoryitems/<rest>               ->  languages/<code>/inventoryitems/<rest>
```

The client's own `languages/<slot>/` segment (the stock Dutch ... Swedish slots)
is dropped: the pack wins whatever subtitle language the game is set to. The
pack file is used only if it exists; otherwise the open goes through untouched.

* **The C runtime path.** Both DLLs are linked against the static MSVC runtime
  and import exactly one file-open primitive, `KERNEL32!CreateFileW`; every
  `std::ifstream` in them ends there, with a path built from the bare game
  directory. `CoF_Lang_HookModule` patches that import entry right after
  `LoadLibrary` (client: `CL_LoadProgs`; server: `SV_LoadProgs`), before any
  export is called (`[cof-lang] <dll>: CreateFileW import hooked` in the log). Measured user: `hl.dll` opens `txtfiles/subtitles.txt`
  this way.
* **The engine path.** Some of the DLLs' text goes through `pfnLoadFileForMe` /
  `COM_LoadFile`, i.e. `COM_LoadFileForMe` (`engine/common/common.c`), which now
  asks `CoF_Lang_GameFile` first. Measured users: `txtfiles/hints.txt` and
  `inventoryitems/*.txt` (section 4).

### 3.4 The import hook: safety rules

* **In memory only.** The IAT entry is found by name through the module's
  import name table (by resolved address if a module had none), made writable
  with `VirtualProtect`, swapped with one `InterlockedExchangePointer`, and
  protected again. Nothing on disk changes.
* **Restored before unload.** `COM_FreeLibrary` calls `CoF_Lang_UnhookModule`
  for every module just before `FreeLibrary`; a hooked one gets its original
  entry back (logged as `CreateFileW import restored`). A module loaded by the
  custom in-memory loader is never hooked.
* **Read-only opens only.** Any write access bit (`GENERIC_WRITE`,
  `GENERIC_ALL`, `FILE_WRITE_DATA`, `FILE_APPEND_DATA`) or any disposition other
  than `OPEN_EXISTING` passes straight through - saves, `config.cfg`,
  `scriptsettings.dat`, `maps/*.cfg`, the renderer's `paranoia_log.txt`.
* **Anchored.** The class folder has to follow a `<gamedir>/` segment (or open
  a bare relative path), so a `notes` folder somewhere in the install path can
  never match.
* **Thread-safe and re-entrant.** Everything the shim reads is taken under the
  shared side of an SRW lock that pack switching takes exclusively; the
  rewritten path lives on the caller's stack; the real open goes through the
  **engine's** own `CreateFileW` import, which is never patched, so the shim
  can never call itself. The last-error value is preserved across the shim's
  own work. Only the main thread logs; other threads are counted
  (`cof_language_status`).
* **Visible.** One `developer 1` line per redirect (`[cof-lang] open A -> B`
  for the CRT path, `[cof-lang] load A -> B` for the engine path),
  `cof_language_trace 1` for everything.

### 3.5 Strings compiled into the DLLs

`strings/dll-strings.tsv` is UTF-8. At load each row's English side is matched
as bytes, and the localised side is converted to the manifest's code page (the
same 1250/1251/1252 tables the Inter font layer decodes with) and unescaped
(`\n \t \r \\`; any other backslash is literal). Rows whose translation equals
the English are dropped; the first of duplicate rows wins.

Lookup is an exact hash match first, then the entries with printf conversions
(`%s %i %d %u %f %c %x`, with width/precision): the literal pieces must appear
in order with the first at the start and the last at the end, the text between
them is captured and dropped into the translation's own conversions left to
right (surplus conversions are removed, never drawn). Longer literal text is
tried first, so `You got the %s` beats `You got %s`. An entry with fewer than
three literal characters, or two adjacent conversions, is exact-match only.

Where it applies, all gated on `cof_language` and `cof_language_strings`:

* **FreeVGUI `TextImage::setText`** (`3rdparty/freevgui/image.cpp`) - every
  client label and text panel, before it is measured or wrapped. The hook is
  installed from the CoF font support (`coffont.cpp`) and reaches the engine
  through a new `vguiapi_t` entry, `CofLangString`, appended after `CofPrint`.
* **`CL_DrawString` / `CL_DrawStringLen`** (`engine/client/cl_font.c`) - only
  for calls carrying `FONT_DRAW_COF_LANG`, which the client-facing engfuncs
  (`pfnDrawConsoleString(Len)`, `pfnDrawString(Reverse)`) set. The engine's own
  console, notify lines and overlays never match.
* **The centre print** (`CL_CenterPrint`), which is drawn one character at a
  time and cannot be substituted later.

The engine's own fonts are cp1252/cp1251 sheets, so those two paths get a
variant with Latin Extended-A letters folded to their base letter (and UTF-8
where the call decodes UTF-8) instead of bytes their atlas would draw as the
wrong glyph.

### 3.6 Code page

The manifest's `codepage` (1250, 1251 or 1252; anything else falls back to 1252
with a warning) is written to `cof_text_codepage`, which the engine-rasterised
Inter VGUI fonts decode every byte with (`docs/design/vgui-inter-fonts.md`).
Turning the pack off writes 1252.

## 4. Coverage, measured

Fixture `stage1/lang-engine-20260922/fixture` (m5a set with this engine and
`vgui.dll`, the pack copied and verified against `MANIFEST.tsv`), 1920x1080
windowed, commands only on the command line and in `maps/c_college1_load.cfg`.
Evidence in `stage1/lang-engine-20260922/evidence` (`P1`, `P2`, `E1` logs and
screenshots, `contact-sheet.png`).

| asset | path the game uses | result |
| --- | --- | --- |
| hooks | both DLLs | `hl.dll` and `client.dll` `CreateFileW import hooked` at load, `restored` at shutdown, in every run |
| mount | engine FS | `overlay/cryoffear/` on top of the search path |
| subtitles (`subtitle_main`, line 52) | `hl.dll`, CRT | `Będę potrzebował czegoś ostrego, żeby wyjąć ten klucz.` - ł, ą, ę, ś, ż drawn |
| hint bar (`cof_hint sprint`) | engine FS (`COM_LoadFileForMe txtfiles/hints.txt`) | `Przytrzymaj SHIFT, aby biec. ... wytrzymałość.` |
| item pickup (c_college1 screwdriver) | engine FS (`inventoryitems/screwdriver.txt`) + table `You got the %s` | `Podniosłeś śrubokręt` |
| pickup line (`cof_hud_msg_probe "Picked up a syringe"`) | VGUI table, exact match | `Podniosłeś Morfinę` |
| sign `c2_osign1` on c_college1 | texture probe | `RECEPCJA` (English run: `RECEPTION`) |
| entity strings | `maps/c_college1.ent` | loaded from the pack (log) |
| `cof_language ""` in the same session | | subtitle and pickup back to English at once, `cof_text_codepage` 1252; the sign keeps its texture until the next map load |

This corrects `polish-file-access-20260922/RESULTS.md` sections 1a/1b, which
expected `hints.txt` and `inventoryitems` to be opened with the client's C
runtime: `cof_language_trace` shows neither DLL opening anything but
`config.cfg` and `paranoia_log.txt` through `CreateFileW` in those scenes, and
both files arriving through `COM_LoadFileForMe`. Covered by the same code but
not exercised in a run: notes, phone messages, conclusions, `credits.txt`.

## 5. Wine / Proton

The hook is a plain PE import-table write through documented Win32 calls
(`VirtualProtect`, `InterlockedExchangePointer`, `GetFileAttributesW`); Wine
builds the same import tables for native DLLs and implements all of them, and
the engine-path redirect has nothing Windows-specific. It has **not** been run
under Wine or Proton. If the hook ever fails there, the log says
`no KERNEL32!CreateFileW import` or `cannot unprotect the import table`, the
game stays playable, and only the CRT-read text (subtitles, phone messages,
notes if they use that path) stays English; `cof_language_files 0` turns the
whole redirect off.

## 6. Open items

* **Deploy `xash.dll` and `vgui.dll` together.** The appended `vguiapi_t`
  entry means a new `vgui.dll` must not run on an older engine. Another round
  also rebuilds `vgui.dll` (FreeVGUI `surface.cpp`); the two changes are in
  different files and merge by applying both patches before one build.
* ~~The language selector on the menu's Game page is not written (MainUI).~~
  Done in the m6 round, section 7.
* Engine HUD text drawn per character (`pfnDrawCharacter`: `game_text` /
  `HudText` messages from translated `.ent` strings) uses the cp1252 HUD text
  atlases, so Polish letters there would show as the wrong glyph. Not seen in
  these runs; a cp1250 atlas (`scripts/make-cof-console-font.py` has no cp1250
  charset yet) or a per-character decode is needed if it shows up.
* One run with an intermediate build (`37866B64...`) ended abruptly right after
  the first in-game frame (exit -1, no dump, log just stops), the same signature
  as the pre-existing abrupt terminations recorded in PROJECT-MEMORY. It did not
  repeat in the nine launches after it, including three with the final binary.
  *(2026-09-22 docs pass: those earlier "abrupt terminations" were later traced
  to other test scripts killing every game process by name, see
  [engine and game facts](../history/engine-and-game-facts.md); whether this one
  had the same cause is **unverified**.)*
* A pack switched on in a running game leaves the client's VGUI art and
  anything else the game cached at init in English until a restart; switching
  at the menu and restarting is the supported flow.
* Item names inside pickup lines come from the pack's `inventoryitems` file
  (`nice_name`), so they are as good as that data; lines the table has no
  entry for stay English.
* (lang2) The menu table is keyed by the English alone, so one English string
  cannot be translated two ways (`Save`: button and column header). A page
  that must differ needs its own English wording in the source.
* (lang2) The co-op pages' strings were drafted against
  `patches/cof-mainui-coop.patch` while that round was still open; after it
  lands, run `extract-menu-strings.ps1 -Pack languages\polish` once more.
* (lang2) The console-only old Language page (`menu_coflanguage`) still sets
  only the client's slot; nothing in the menu links to it.

## 7. The Language option on the Game page (m6, one option since lang2)

`patches/cof-mainui-language-selector.patch` (MainUI, applied by
`scripts/apply-cof-mainui-language-selector.ps1` after
`cof-mainui-source-theme.patch`) makes the Game options page
(`menus/AdvancedControls.cpp`) carry exactly **one** language option,
*Language*, in the left-hand slot of the first spinner row (next to *HUD
scale*; *Aim down sights* is under it), plus a note under the rows. The panel
is 760x580 for Cry of Fear.

**The client's own subtitle language.** Cry of Fear has a second, older
language setting: the archived cvar `cof_subtitlelanguage`, 1 = English,
2..7 = Dutch, French, German, Norwegian, Spanish, Swedish. It is created by
the game DLL's `subtitleset N` command (hl.dll, no range clamp) and read by
both DLLs **at every file open**, never cached: hl.dll picks
`txtfiles/[languages/<name>/]subtitles.txt`, `phone_messages.txt` and
`hints.txt` with it, client.dll `notes/[languages/<name>/]...`, the
conclusion texts and the intro cards `gfx/vgui/introductions/<name>/`; the
client's co-op intro card reads its own copy, `cl_coop_language`. Slot 0/1
and anything above 7 are the English root. It is not in `settings.scr`. The
m2 menu exposed it as a *Subtitle language* spinner on the Game page (and as
the old Language page, `menu_coflanguage`, console only).

Since lang2 that row is gone (the control is no longer added) and *Language*
sets both:

| row | `cof_language` | `cof_subtitlelanguage` (and `cl_coop_language`) |
| --- | --- | --- |
| English | `""` | 1 (the client default) |
| every installed pack, sorted by `display_name` | the pack folder | the manifest's `subtitle_language=` (1..7; missing or invalid = 1) |
| (only for an old configuration) `<name> (subtitles)` | `""` | the slot 2..7 it already has |

**Round 2 (user decision): the game's six own languages are packs.**
`languages/dutch`, `french`, `german`, `norwegian`, `spanish`, `swedish` are
*minimal packs*: `manifest.txt` (display name in the language, `codepage=1252`,
`subtitle_language=` 2 ... 7) and `strings/menu-strings.tsv`, nothing else. So
*Deutsch* sets `cof_language german` and slot 4: the menu is German and the
game reads its own `txtfiles/languages/german/` files (the engine finds no
pack file for them and lets the open through - measured: `[cof-lang] open
cryoffear/txtfiles/languages/german/subtitles.txt (not in the pack, English)`,
the trace showing that very German file opened; the log's "English" means "not
redirected"). For such a pack the engine mounts nothing (no `overlay/`), its
DLL string table is empty (`Warning: cof_language:
languages/german/strings/dll-strings.tsv not found, DLL strings stay in
English`), and the code page stays 1252 - measured in the `de`, `fr` and `tbl`
runs. The special `(subtitles)` rows of round 1 are gone; the model keeps the
six names only to show an old configuration (`cof_language ""` with slot 2..7,
e.g. from the retired spinner) as its own row, like `not installed`, so opening
the page never rewrites it.

Why a pack says `subtitle_language=1`: the engine serves a pack's `txt/` file
over **whatever** slot the client asks for (section 3.3 drops the client's
`languages/<name>/` segment), so the slot only decides what the client falls
back to for a file the pack does not have, and what intro-card folder it
reads. With 1 the client opens the English root paths, gets the pack's file
where it exists, English otherwise, and the pack's `overlay/` repaints the
English intro cards - one consistent language, never a Polish subtitle next to
a German note. Measured in the lang2 `pl` run with `cof_language_trace 1`: the
game opened `cryoffear/txtfiles/subtitles.txt` once, redirected to
`languages/polish/txt/txtfiles/languages/polish/subtitles.txt`, nothing else
for that line; in round 2 the *Deutsch* and *Français* packs made it open
`txtfiles/languages/german/subtitles.txt` and `.../french/subtitles.txt`.

* **Rows.** Rebuilt every time the page opens (a pack copied in while the
  game runs shows up without a restart): English, then every folder under
  `<gamedir>/languages/` with a `manifest.txt` (the engine's own
  `cof_language_list` search: `GetFilesList("languages/*")` game-directory
  only, then `COM_LoadFile` of the manifest; folder names with `. : \ /`
  skipped), sorted by display name (ASCII case folded). A `cof_language`
  naming a pack that is not installed shows as `<code> (not installed)`, an
  old configuration's slot 2..7 without a pack as `<name> (subtitles)` (a key
  of the menu string table, section 8), so opening the page never rewrites a
  cvar. The current row is the pack for a non-empty `cof_language`, else that
  old-slot row, else English.
* **Selecting** writes `cof_language` if it differs, and the subtitle slot if
  it differs: in a running game through the game's own `cmd subtitleset N`
  (so the player's cached copy follows) and the cvar directly (so the config
  written next already has it; `set` creates it when the game never did),
  plus `cl_coop_language` when the client registered it (also when only that
  copy differs); then
  `host_writeconfig`. The engine applies `cof_language` on its next frame
  (section 1), the menu's own strings switch on the menu's next frame
  (section 8). The note under the rows: *Text switches at once, signs on the
  next map; restart the game for the remaining art.*
* **Test hook.** `menu_cof_language_select [row | code | english]` (cfg-only;
  this project's tests may not inject clicks or keys) opens the Game page,
  lists the rows with their `cof_language` and slot, and moves the spinner
  with the control's own `SetCurrentValue`, which raises the same
  `QM_CHANGED` event an arrow click does.

Measured in m6 (`stage1/lang-integration-20260922`, 1920x1080 windowed):

| run | what | result |
| --- | --- | --- |
| `sel` | main menu, Game page, `menu_cof_language_select polish` | rows `English` / `Polski`; the page shows *Polski*; engine: `cof_language: polish (Polski, code page 1250)`, pack mounted, `cof_text_codepage` 1250; `config.cfg` holds `cof_language "polish"` |
| `pl2` | next start with that config, quick save (c_park) | subtitle line 52 `Będę potrzebował czegoś ostrego, żeby wyjąć ten klucz.`, pickup `Podniosłeś Morfinę`; spinner back to English in game: `cof_language ""`, code page 1252, `Host_WriteConfig()` logged before the next map; `map c_forest1` with `gl_customsky 1` |
| `en` | next start with that config | the same two lines in English (`I'm going to need something big to cut free that key.`) |
| `final` | the staged m6 set, one session: menu -> Polish -> load -> subtitle + pickup in Polish -> map change -> English | all of the above in one run |

Measured in lang2 (`stage1/lang2-20260922/RESULTS.md`): see section 8.

## 8. The menu's own strings (lang2)

`patches/cof-mainui-menu-strings.patch` (MainUI, applied by
`scripts/apply-cof-mainui-menu-strings.ps1`, README order after the
selector) translates this project's menu - main menu, every Options page,
Extras, Unlockables, Credits, Save/Load, the pause and death pages, the co-op
pages, dialogs, tooltips, the Controls list - from the active pack's
`strings/menu-strings.tsv`.

**The file.** `english <TAB> translation [<TAB> anything]`, UTF-8 with or
without a BOM (a line that is not valid UTF-8 is read in the manifest's code
page instead); `#` lines and a first row whose first cell is `english` are
skipped; `\n`, `\t`, `\\` unescaped; an empty translation or one equal to the
English is ignored; the first of duplicate rows wins. The **key is the
English exactly as the menu draws it** - for a `#GameUI_...` token the English
the game's `resource/gameui_english.txt` (or this project's
`cryoffear_english.txt`) gives it, for a Controls row the `kb_act.lst` label,
for a Controls section caption the upper-cased label the theme draws. Keys
with printf conversions (`%s %d %i %u %f %c %x`) also match formatted text by
the same rules as the DLL table (section 3.5): literal pieces in order, first
at the start, last at the end, captures dropped into the translation's own
conversions left to right, surplus conversions removed, longer keys first; a
captured piece that is itself a key is translated too (`Subtitle language:
%s` + `English`). Text wrapped in `^N` colour codes (the Controls list builds
its rows as `^6<label>^7`) is looked up without them.

**Where it applies.** Not in `L()`: every page resolves its `L()` strings
once, the first time it opens, so a lookup there could not follow a language
change in a running game. The lookup (`UI_LangText`, `MenuStrings.cpp`, next
to `L()`) runs where text is **drawn and measured** - `UI_DrawString`,
`CFontManager::GetTextWide` / `GetTextHeightExt` for whole strings, and the
theme's letter-spaced text (`UI_ThemeDrawTracked` / `UI_ThemeTrackedWidth` in
`Theme.cpp`: the main-menu wordmark and the death page's *GAME OVER*, which
walked single bytes and now decode UTF-8 like `UI_DrawString`) - so layout
widths are those of the translation. `CMenuField` (typed text: player
names, addresses, passwords) is held out (`UI_LangHold`), its label is not.
`UI_LangFrame`, at the top of `UI_UpdateMenu`, loads the table the first time
and whenever `cof_language` changes, then lays the open pages out again
(`uiStatic.menu.VidInit`), so the page the player is on switches language the
frame after the spinner moves; pages not open lay themselves out when they
open. `menu_cof_strings [reload | <text>]` prints the table's state, reloads
it from disk (for pack authors) or shows what a given text becomes. The log
line at load: `menu strings: languages/polish/strings/menu-strings.tsv: 397
strings, 10 of them with conversions` (identity rows are not counted).

**Fonts.** The menu does not use the engine's cp1250/cp1251 bitmap atlases
(those are for in-game text); it rasterises the shipped Inter TTFs
(`gfx/fonts/Inter-*.ttf`, stb_truetype) for every menu font - titles, labels,
body, buttons, items, logo - with the glyph set `UploadTextureForFont` builds:
ASCII, Latin-1 from U+00A1 (letters and, since round 2, the punctuation: ¡ ¿
« » ° for Spanish and French; the stock range began at U+00C0), Latin
Extended-A (all Polish letters), Cyrillic
U+0400-045F and the cp1251 set (Ґґ, „ ” “ ‘ ’ – — … « » № and the like), and
decodes the strings as UTF-8. So the table must be UTF-8 (hence the
code-page fallback only for stray lines) and may use only those characters;
`extract-menu-strings.ps1 -Pack` checks that.

**Keeping a pack complete.** `scripts/polish/extract-menu-strings.ps1
-MainUI <tree>\3rdparty\mainui [-Out menu-strings.en.tsv] [-Pack
languages\<code>]` lists every key with its source location (all `L()`
arguments and every other literal that reads as text in the pages Cry of Fear
reaches, `#GameUI_` tokens resolved, `kb_act.lst`, and the engine's `Pause
Save (%s)` title), and with `-Pack` reports missing keys, keys no source uses
any more, conversion mismatches and characters the fonts do not carry (exit 1
on the first three kinds of error but not on unused keys). A new page is one
line in its `$Files` list (the co-op pages, `menus/CoFCoop.cpp`, are listed
already).

**Seven tables** (round 2): Polish plus the six minimal packs, 474 rows each,
all checked with `-Pack` against both key lists (432 without, 472 with the
co-op pages), plus two width estimates for the fixed-width places
(`stage1/lang2-20260922/src/table-fit.py`, `control-fit.py`, calibrated on
screenshots): the Unlockables and Load lists needed shorter texts in several
languages (the in-game hint page titles now appear quoted on their own,
`Pause (%s)` / `Empl. %i` and similar). Translated rows: de 426, fr 431, es
438, nl 426, no 438, sv 437 (the rest proper nouns, formats and words the
language shares with English).

**Polish.** `languages/polish/strings/menu-strings.tsv`: 474 rows (432 keys
of the tree without the co-op round + 42 of `patches/cof-mainui-coop.patch`
as of 2026-09-22 22:00), 438 translated, 36 kept (proper nouns, `OK`,
`Ping`, language names). **Machine-drafted for review** (see the pack's
README). One English key cannot carry two meanings: `Save` is both the Save
button and the Load list's column header and reads `Zapis`.

Measured (`stage1/lang2-20260922`, fixture with the pack copied, 1920x1080
windowed, commands from `maps/<map>_load.cfg` only):

| run | what | result |
| --- | --- | --- |
| `sel` | English config with `cof_subtitlelanguage 4`; Game page; `menu_cof_language_select polish`; then every page by its menu command | English page shows one *Language* row reading `Deutsch (subtitles)`, no *Subtitle language* row; after the switch the same open page re-laid out in Polish (*GRA*, *Język: Polski*, *Celowanie przez przyrządy: Przełączanie*), `cof_subtitlelanguage` 4 -> 1, `cof_language "polish"` in `config.cfg`; Options, Video, Audio, Controls (action names and section captions), Load, Extras list, Unlockables, New Game, Credits all Polish with ą ć ę ł ń ó ś ź ż drawn; `menu strings: "Load Game" -> "Wczytaj grę"`, `"Subtitle language: English" -> "Język napisów: English"` |
| `pl` | next start with that config; quick save | main menu Polish from the first frame; subtitle file opened once from the pack (above); Polish subtitle and pickup; pause menu *Wróć do gry / Zapisz grę / Wczytaj grę / Opcje / Wyjdź do menu / Wyjdź*; Game page in game Polish; spinner to English in game: page English at once, `cof_language ""`, slot 1 |
| `en` | next start with that config; quick save | English menu, English subtitle from `txtfiles/subtitles.txt`; in game `Deutsch (subtitles)`: `cof_language ""`, `cof_subtitlelanguage` and `cl_coop_language` 4, the game then opens `txtfiles/languages/german/subtitles.txt` |
| `final` | the staged lang2 set | see `stage1/lang2-20260922/RESULTS.md` |
| `de` (round 2) | English config with the old slot 4; select *Deutsch* | the page first shows the old-slot row `Deutsch (subtitles)`, rows English, Deutsch, Español, Français, Nederlands, Norsk, Polski, Svenska; after the switch Game, Controls, Video, Unlockables, main menu, pause menu German (ä ö ü ß drawn); `cof_language: german (Deutsch, code page 1252)`, no mount, DLL table empty; the game's German subtitle file opened |
| `fr` (round 2) | next start with that config; select *Français* | slot 4 -> 3 and `cl_coop_language` 3; Game, Audio, Load, main menu French; the game's French subtitle file opened; death page *PARTIE TERMINÉE / Charger une partie / Quitter*; English in game: menu English, slot 1, the English subtitle file opened |
| `tbl` (round 2) | Spanish, French, Swedish, English at the menu | Load and Unlockables in Spanish and French without clipped cells after the shortening; Swedish and back to English |
