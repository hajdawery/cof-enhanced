# Cry of Fear: Enhanced - Spanish (Español)

A **minimal language pack**: it makes the menu of Cry of Fear: Enhanced
Spanish and selects the game's own Spanish subtitles and documents.
It adds no game text of its own.

* `manifest.txt` - `display_name=Español`, `codepage=1252`,
  `subtitle_language=6`: picking *Español* in Options > Game >
  Language sets the engine's `cof_language spanish` and the client's own
  subtitle slot `cof_subtitlelanguage 6`, so the game reads the Spanish
  files it ships (`txtfiles/languages/spanish/`, `notes/languages/spanish/`,
  `gfx/vgui/introductions/spanish/`).
* `strings/menu-strings.tsv` - every string of this project's menu
  (main menu, all Options pages, Extras, Unlockables, Credits, Save/Load,
  pause and death pages, co-op pages, dialogs, tooltips, the Controls list),
  `english <TAB> translation <TAB> where`, UTF-8.

**The menu translation is machine-drafted** (written 2026-09-22 by an AI
worker of this project, not by a translator) **and waits for review** by a
native speaker. Proper nouns, map names and the titles of the game's
in-game hint pages are kept in English. Check a changed file with
`scripts/polish/extract-menu-strings.ps1 -MainUI <tree>\3rdparty\mainui
-Pack languages\spanish` (missing strings, `%s` mismatches, characters
the menu fonts do not carry); `menu_cof_strings reload` in the console
re-reads it in a running game.

* `strings/dll-strings.tsv` - only the five quick save messages the engine
  itself shows on the game's message strip ("Quick saved", "Quick loaded",
  ...), `english <TAB> translation <TAB> engine <TAB> - <TAB> note`, UTF-8,
  machine-drafted like the menu strings. No game DLL string is replaced.

No `overlay/`, `maps/`, `textures/`, `txt/` or `inventoryitems/`: the
engine mounts nothing for this pack and the code page stays 1252. See [`../README.md`](../README.md) and
[`docs/cof-language-packs.md`](../../docs/cof-language-packs.md).

`LICENSE-NOTE.md` - the licence of this folder: the project's own GPL-3.0-or-later (it holds no game text).

`MANIFEST.tsv` lists every file but itself and this README
(path, bytes, SHA-256).
