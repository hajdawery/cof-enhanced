# Quick save and quick load (`cof_quick_saves`, F5 / F9)

Two patches, applied as steps 53 and 54 of the [patch stack](../dev/patch-stack.md),
after `cof-window-name` and before `cof-panel-pause`:

| step | script | patch | target |
| ---: | --- | --- | --- |
| 53 | `apply-cof-quicksave` | `cof-quicksave` | E (`xash.dll`) |
| 54 | `apply-cof-mainui-quicksave` | `cof-mainui-quicksave` | M (`cl_dlls/menu.dll`) |

Plus the gamedata key list `gamedata/cryoffear/gfx/shell/kb_def.lst` (F5, F9,
F12 lines) and seven rows in each pack's `strings/menu-strings.tsv`.
Evidence: `stage1/quicksave-20260924/RESULTS.md`.

## 1. What the player gets

Off by default. **Options > Game > Quick saves** turns it on (the saved cvar
`cof_quick_saves`). Then:

| where | what |
| --- | --- |
| F5 (`cof_quicksave`) | in single-player play: save to the quick slot, "Quick saved" on the game's message strip |
| F9 (`cof_quickload`) | load the quick save; "Quick loaded" once the level is up |
| pause menu | **Quick save** is the first item (single player only): saves, then back to the game |
| Load window | the quick save is the first row: **Quick** / **Quick save (c_park)** / the date, like the five slots; A, Enter or a double click loads it (the Save tab never lists it, so there is no overwrite question) |
| Options > Keybinds | rows **Quick save** and **Quick load** under "Pause game" |

With the option off: F5 / F9 / the two commands only say **"Quick saves are
disabled in Options > Game"**, the pause menu has no Quick save and the Load
window no quick row (even when the file exists).

**The cvar is `cof_quick_saves`, not `cof_quicksave`**: FWGS refuses a cvar
and a command of the same name (`Cmd_AddCommand`: "already defined as a var";
`Cvar_RegisterVariable`: "already defined as command"), and the command names
are the ones the binds use.

## 2. The files

| file | where | written by |
| --- | --- | --- |
| `cofquick.sav` | runtime root `SAVE\` | `SV_CoFQuickSave` through the root-SAVE adapter ([root SAVE](cof-save-root-compat.md)) |
| `cofquick.bmp` | runtime root `SAVE\` | the engine's own `saveshot`, one frame later, like every save |
| `saveinfoquick.cof` | `cryoffear\SAVE\` | the label, `Quick save (<map>) - <Www Mmm dd hh:mm:ss yyyy>`, the format of the pause saves' `saveinfoN.cof` |

The game's own `SAVE\quick.sav` (its old quick save, still in the Steam
install) is a different file and is never touched. The tape recorders and the
pause-menu saves keep their five `cofsaveN` slots.

## 3. Engine (`cof-quicksave.patch`)

* **`engine/server/sv_save.c`**: the pause-menu save's transaction is now
  `SV_CoFSaveTransaction( name, label, title, what )` - the label written to a
  temp file first, the old `.sav` and label kept as `.coffix-backup` until
  the new pair is in place, rollback on any I/O error, the menu map refused -
  shared by `SV_CoFMenuSave` (unchanged behaviour and messages; only the
  failure lines name "menu save to slot N") and the new `SV_CoFQuickSave`.
  `SV_CoFQuickSaveExists` answers through the same adapter.
* **`engine/client/cof_quicksave.c`** (new): `cof_quick_saves` (saved, 0),
  `cof_quicksave`, `cof_quickload`, and when a quick save may happen:

| refused | how it is detected | answer |
| --- | --- | --- |
| option off | `cof_quick_saves 0` | "Quick saves are disabled in Options > Game" (strip in play, else console) |
| co-op, host or joiner | local server with more than one slot, or `cl.maxclients > 1` | "Quick saves work in single player only" (strip) |
| no game, the menu background map, still loading | `SV_Active`, `ca_active`, `cl.background`, loading plaque | console |
| menu or console open (this includes the death page) | `key_dest != key_game` | console |
| a client panel open (inventory, notes, tape page, computer...) | the client shows its arrow cursor, `host.mouse_visible` | console |
| dead, no player | `IsValidSave` | console ("Can't savegame with a dead player") |

  The quick load needs the option, single player and the file ("There is no
  quick save yet" otherwise).
* **`engine/client/cl_main.c`**: `CL_CoF_QuickSaveInit` in `CL_InitLocal`
  (before `config.cfg`, so the saved value lands on the real cvar);
  `CL_CoF_QuickSaveFrame` in `Host_ClientFrame`, next to the death page's
  pump: "Quick loaded" 20 frames after the loaded level is active with no
  loading plaque (outside the command buffer, which a running cfg can hold up;
  given up after 120 s).

### What the player is told, and where

Not a console line in the corner: every message the player should see goes to
**the game's own message strip** - the `ProFont` user message that hl.dll uses
for the pickup lines and for the tape recorder's own **"Saved"** (hl.dll
`100DF132`: `ProFont( player, "Saved", 4 )`), dispatched to the client with
`CL_DispatchUserMessage`, exactly what `cof_hud_msg_probe` does. So these lines
are drawn by the client's `CHUDControl` Label and get everything that path
already has ([HUD text](cof-hud-text-legibility.md) section 9):

* placement: `cof_hud_msg_y_pct` (78 % of the render height);
* face and size: Inter SemiBold, the `credits` role's height times the HUD
  scale (`cof_ui_scale_user`);
* the backing strip: `cof_hud_text_backing` (0 = off);
* the client's own fade (about 0.5 s in, 4 s, 0.5 s out);
* translation: the language pack's string table at the client's `setText`.

| text (English key) | colour index |
| --- | --- |
| `Quick saved` | 4, green (the game's "Saved") |
| `Quick loaded` | 4 |
| `Quick saves are disabled in Options > Game` | 5, grey (the pickup lines) |
| `There is no quick save yet` | 5 |
| `Quick saves work in single player only` | 5 |

**For translators**: these five strings are engine text, so they belong in the
pack's `strings/dll-strings.tsv` (`english <TAB> translation <TAB> ...`), not in
`menu-strings.tsv`. Verified with a fixture-only Polish row
(`Quick saved` -> `Szybko zapisano grę`, drawn with the `ę`). Since m9 all
seven packs ship the five rows (machine-drafted, `source_dll` `engine`, at the
end of the file): the Polish `dll-strings.tsv` is generated, so its rows live
in `scripts/polish/string_overrides_polish.tsv` as extra `engine` rows that
`build_dll_strings_tsv.py` appends; the six minimal packs have a small
hand-maintained `strings/dll-strings.tsv` with only these rows
([language packs](../design/language-packs.md) section 3.5). The log lines
themselves are `Con_Reportf` (developer only).

## 4. Menu (`cof-mainui-quicksave.patch`)

| file | change |
| --- | --- |
| `menus/LoadGame.cpp` | the quick row first in the Load tab (option on, `SAVE/cofquick.sav` present): `L( "Quick" )` in the Slot column, the label's title `Quick save (<map>)` in the Save column (translated at draw time through the key `Quick save (%s)`, like `Pause Save (%s)`), the timestamp in the Date column, the thumbnail `SAVE/cofquick.bmp`; activating it runs the page's own `LoadGame()` (`load "cofquick"`, `stopmp3`); never in the Save tab; the menu registers `cof_quick_saves` too; a developer line `Load list: quick save row ...` |
| `menus/Main.cpp` | pause list: **Quick save** first (`AddItem` order = pad/arrow order, and first in the drawing order), visible in play, single player, option on; it queues `cof_quicksave` and closes the menu, so the command runs next frame with the menu already closed; `Think()` lays the list out again when the option changes while the list is up |
| `menus/AdvancedControls.cpp` | the Game tab checkbox **Quick saves** (`cof_quick_saves`, written at once), the free right-hand slot of the fourth checkbox row (the panel keeps its size); `menu_cof_options_select game quicksaves 0|1` |
| `model/KbActListModel.h` | Keybinds rows **Quick save** (`cof_quicksave`) and **Quick load** (`cof_quickload`) after "Pause game", added in code like the crouch toggle (the game's `kb_act.lst` is not shipped modified) |
| `Theme.cpp` | deferred-defaults **generation 5** (see below) |

### Default keys: generation 5

`COF_SCENE_DEFAULTS_GEN` 4 -> 5, offered once per profile
(`ui_cof_scene_defaults`):

* **F9** -> `cof_quickload` when F9 is unbound;
* **F5** -> `cof_quicksave` when F5 is unbound, **or** when it still holds the
  game's shipped `snapshot` (the game's own `config.cfg` binds F5 to
  `snapshot`, so a fresh profile is never "F5 unbound"); the screenshot then
  moves to **F12**, but only when F12 is free - otherwise F5 is left alone;
* a key bound to anything else is left alone ("F5 is bound to "+reload", left
  as it is (quick save has no key)").

`gfx/shell/kb_def.lst` ("Use defaults") carries the same: `"F5" "cof_quicksave"`,
`"F9" "cof_quickload"`, `"F12" "snapshot"`. The pad has no default button.

## 5. Menu strings

Seven keys, in all seven `languages/<code>/strings/menu-strings.tsv`
(machine-drafted like the rest; `MANIFEST.tsv` rows updated): `Quick save`,
`Quick load`, `Quick saves`, the checkbox's and the pause item's status lines,
`Quick` (the Load row's Slot column) and `Quick save (%s)` (the label, an
engine string the extractor now lists next to `Pause Save (%s)`).
`scripts/polish/extract-menu-strings.ps1 -Pack` passes for all seven packs.

## 6. Verification (summary)

8 launches, junction fixture, see RESULTS.md: fresh profile (generation 5
binds, off refusals, pause list and Load window without the quick entries, the
Game tab checkbox, Quick save first in the pause list, the pause item saves,
the Load row with map and date, F9 restores health 37 -> 100 and z 161 -> 65,
the row loads by A, refusals with the console / the inventory / dead);
custom profile at 3840x2160 and HUD 150 % (F5 left alone, F9 bound, no row and
no item with the file present, the strip on and off); the user's own profile
at 1080p / 150 % (upgrade from generation 3, strip on/off, Polish translation
through `dll-strings.tsv`, German pause list, Load window, Keybinds);
co-op host (refused, no pause item). Stack: steps 1-58 applied from a fresh
`pristine-clean`, both patches round-tripped by `git apply` and by their own
`-Reverse`, the finished tree byte-identical to the build tree.

## 7. Known limits

* The quick save thumbnail is taken one frame after the save, when the
  "Quick saved" line has only just started to fade in.
* The pause menu opens with **Quick save** focused (it is the first item):
  with a pad, A at once saves.
* "A panel is open" is the client's arrow cursor. Opening the pause menu over
  the inventory and choosing Quick save saves after the menu closes, before
  the inventory's cursor comes back.
* The Gamepad tab's action list has no Quick save / Quick load entry (it lists
  `kb_act.lst`, the code-added crouch toggle and the pad lines of
  `kb_def.lst`); a pad button can still be bound with `bind`.
* The five on-screen messages are translated by every pack since m9
  (machine-drafted, section 3); a new pack needs the five rows in its
  `dll-strings.tsv`.
