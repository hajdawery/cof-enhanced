# Cry of Fear: Enhanced - Swedish (Svenska)

A **minimal language pack**: it makes the menu of Cry of Fear: Enhanced
Swedish and selects the game's own Swedish subtitles and documents.
It adds no game text of its own.

* `manifest.txt` - `display_name=Svenska`, `codepage=1252`,
  `subtitle_language=7`: picking *Svenska* in Options > Game >
  Language sets the engine's `cof_language swedish` and the client's own
  subtitle slot `cof_subtitlelanguage 7`, so the game reads the Swedish
  files it ships (`txtfiles/languages/swedish/`, `notes/languages/swedish/`,
  `gfx/vgui/introductions/swedish/`).
* `strings/menu-strings.tsv` - every string of this project's menu
  (main menu, all Options pages, Extras, Unlockables, Credits, Save/Load,
  pause and death pages, co-op pages, dialogs, tooltips, the Controls list),
  `english <TAB> translation <TAB> where`, UTF-8.

**The menu translation is machine-drafted** (written 2026-09-22 by an AI
worker of this project, not by a translator) **and waits for review** by a
native speaker. Proper nouns, map names and the titles of the game's
in-game hint pages are kept in English. Check a changed file with
`scripts/polish/extract-menu-strings.ps1 -MainUI <tree>\3rdparty\mainui
-Pack languages\swedish` (missing strings, `%s` mismatches, characters
the menu fonts do not carry); `menu_cof_strings reload` in the console
re-reads it in a running game.

No `overlay/`, `maps/`, `textures/`, `txt/`, `inventoryitems/` or
`strings/dll-strings.tsv`: the engine mounts nothing for this pack, its DLL
string table stays empty (one warning line in the log says so) and the code
page stays 1252. See [`../README.md`](../README.md) and
[`docs/cof-language-packs.md`](../../docs/cof-language-packs.md).

`LICENSE-NOTE.md` - the licence of this folder: the project's own GPL-3.0-or-later (it holds no game text).

`MANIFEST.tsv` lists every file but itself and this README
(path, bytes, SHA-256).
