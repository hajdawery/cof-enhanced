# Testing: fixtures, rules and hooks

How this project tests a change without touching the player's install and
without driving the desktop. The rules marked **hard rule** exist because
breaking them once cost real damage (keystrokes typed into the user's editor,
game sessions killed under the user); they are not style advice.

## Where things run

| Place | What it is | May a test change it? |
| --- | --- | --- |
| Steam installation | the player's real game | **no** (read-only baseline; the one 2026-09-20 Steam test was separately approved and fully restored, see [the Steam test](../history/steam-play-test.md)) |
| `K:\LLM\COF_Fix\Cry of Fear` | canonical untouched game copy | **no**, never, not even a font file |
| `stage1\launch-prototype-20260920` | the user's playable runtime | only through the deploy script ([releases](releases-and-deploy.md)); the user may be playing |
| `stage1\<round>-<date>\` | a worker's evidence folder and fixture | yes |

## Hard rules for any launch

* **`+volume 0`** on every automated launch (a console command; `+set volume 0`
  is not the same thing).
* **No input injection.** No `keybd_event`, `SendInput`, `AppActivate`,
  `SetForegroundWindow`. Commands go on the command line, into
  `maps/<map>_load.cfg`, or through `+exec`. The single exception: one Escape
  keypress, and only after `GetForegroundWindow` has confirmed the game window
  is in front; otherwise the check goes on the user's manual list.
* **Never kill by name.** No `Stop-Process -Name cof/xash/CoFLaunchApp`, no
  `taskkill /IM`. A launch script may stop only the PID it started
  (`Start-Process -PassThru`), and never a process whose path is under
  `stage1\launch-prototype-20260920`. Two "crash" investigations on 2026-09-22
  turned out to be other workers' scripts killing every game process by name.
* **Windowed, short, bounded.** No retry loops after a crash or a hang; record
  it and stop.
* A diagnostic renderer swapped into a runtime is swapped back afterwards,
  and a run that sets an `FCVAR_GLCONFIG` cvar (they persist in `opengl.cfg`)
  restores the baseline `opengl.cfg`.

## Fixtures

Reuse one fixture per round; never copy the whole game per run. Details and the
rollback discipline are in
[the fixture workflow](steam-launch-prototype.md#reusable-fixture-workflow).
What was learned the hard way:

* The Cry of Fear client reads files through its own C runtime, not the
  engine's VFS, so `-rodir` does not work with it. Fixtures use **junctions for
  read-only asset folders** and **hardlinks for maps, WADs and media**.
* **Never junction a folder the engine writes into.** A fixture that
  junctioned `gfx/` and `resource/` into the canonical copy leaked a generated
  file there on 2026-09-22; `gfx/` and `resource/` must be real folders.
* Tear a junction fixture down with the `Remove-FixtureRoot` pattern (remove
  the junctions first), never with `Remove-Item -Recurse`.
* `wait N` on the command line is one frame, not N. Delayed test commands go in
  `maps/<map>_load.cfg`, which the engine runs when that map loads.
* Saves: back up the fixture's `SAVE/` before a save-writing test and restore
  it; never hardlink saves or configs.

## Test hooks built into the patches

Because no input may be injected, most features ship a console hook that
reaches the same code path a click would:

| Hook | From | Does |
| --- | --- | --- |
| `menu_cof_sound_probe [slot]` | theme | plays one menu sound through the controls' own call |
| `cof_ui_menu_panel_probe [sample] [volume]` | menu-map redirect | feeds the gallery MAIN MENU detector the sound a real click plays |
| `menu_cof_language_select [row \| code \| english]` | language selector | picks a Language row |
| `menu_cof_strings reload` | menu strings | re-reads the active pack's `menu-strings.tsv` |
| `menu_cof_host_start` | co-op pages | presses Start on the Host page |
| `cof_font_probe "<scheme> text"` | VGUI Inter fonts | draws a string with an engine font (code-page check) |
| `cof_hud_text_probe`, `cof_hud_msg_probe` | HUD text | draws a HUD text line / a message-strip line |
| `cof_key_probe <key> <1\|0>`, `cof_ads_status` | ADS option | drives the engine key path; prints ADS state |
| `cof_world_probe` | death live | prints `sv.time`, `sv.framecount` and the simulation gates |
| `cof_language_trace 1`, `cof_sprite_trace 1`, `cof_hud_text_trace 1` | packs, sprites, HUD text | developer logging |

Each page in [docs/patches](../patches/README.md) lists its own hooks and the
exact runs that used them.

## Evidence

Record for every run: the engine/renderer/menu/vgui SHA-256, the command line,
the cfg files used, the log, and the screenshots with their hashes. State the
smallest claim the evidence supports and label it measured, inferred or
unverified (the convention at the end of
[the developer notes](xash-goldsrc-developer-notes.md)). Anything a log cannot
prove (audibility, a real mouse click, a browser actually opening) is marked
for the user's manual test.

## Checklists

* [Custom UI regression checklist](custom-ui-regression-checklist.md) - the
  interaction gates (with its 2026-09-22 status note).
* [Display reference audit](display-reference-audit.md) - the resolution
  acceptance matrix (1080p / 1440p / 2160p).
* [Crash capture guidance](crash-capture-guidance.md) - what a first-chance
  capture does and does not prove.
* [Stack verification](patch-stack.md#verifying-a-stack) - the source-level
  check every patch round ends with.
* `tests/cof-menu-save/` - the menu-save transaction harness (no game launch).
