# Fonts: who draws which text, and from what

Cry of Fear: Enhanced uses one typeface, **Inter** (SIL Open Font License 1.1),
everywhere it can reach, and leaves alone the text it cannot. Text in this game
comes out of four different paths, so there are four answers.

| Text | Drawn by | Font source | Sized by | Page |
| --- | --- | --- | --- | --- |
| Main menu, pause menu, dialogs, options | MainUI (`menu.dll`) | `gfx/fonts/Inter-{Regular,Medium,SemiBold}.ttf` through stb_truetype, GDI Tahoma fallback chain | the menu's own scale | [UI theme](ui-theme.md) |
| Console, notify lines, corner overlays (fps, net graph, version, build stamp) | engine console | `fonts/cof_console{0,1,2}.fnt` atlases (Inter Regular, base 16 / 24 / 34 px, cp1252) | `cof_text_height_pct` (1.7 % of render height) | [text autoscale](../patches/cof-text-autoscale.md) |
| Engine HUD text: hints, `HudText` messages, prompts (`pfnDrawCharacter`) | engine | `fonts/cof_hudtext{0,1}.fnt` atlases (Inter SemiBold, base 14 / 19 px, cp1252) | `cof_hud_text_height_pct` x HUD scale | [HUD text](../patches/cof-hud-text-legibility.md) |
| Client VGUI text: notes and documents, chapter titles, credits, subtitles, pickup lines, scoreboard | FreeVGUI (`vgui.dll`) | Inter Regular / SemiBold TTF, rasterised at device pixels | per-role fraction of render height x HUD scale | [VGUI Inter fonts](vgui-inter-fonts.md) |

Not reachable by any font setting:

* The inventory's headings (`BAG`, `POCKETS`, `SLOT n`, `ITEM DESCRIPTION`,
  `CURRENT OBJECTIVE`, ...) are **painted into** `gfx/vgui/640_inventory.tga`.
  Changing them is an art job.
* Anything the client draws with its own OpenGL code.

## Files

| File | What | Licence |
| --- | --- | --- |
| `gamedata/cryoffear/gfx/fonts/Inter-Regular.ttf`, `-Medium.ttf`, `-SemiBold.ttf` | unmodified Inter 3.019 | SIL OFL 1.1 |
| `gamedata/cryoffear/gfx/fonts/OFL.txt` | the Inter licence | - |
| `gamedata/cryoffear/fonts/cof_console0..2.fnt`, `cof_hudtext0..1.fnt` | bitmap atlases generated from Inter by `scripts/make-cof-console-font.py`, reproducible byte for byte | SIL OFL 1.1 (a Modified Version of the font) |
| `gamedata/cryoffear/fonts/OFL.txt` | the same licence, beside the atlases | - |

Both `OFL.txt` copies must be installed with the files next to them (see
[LICENSING.md](../../LICENSING.md), section 4). Inter declares no Reserved Font
Name, so the atlases need no rename, but they are named `cof_*` and must not be
presented as "Inter" themselves.

Regenerate the atlases:

```powershell
python .\scripts\make-cof-console-font.py
python .\scripts\make-cof-console-font.py --ttf gamedata/cryoffear/gfx/fonts/Inter-SemiBold.ttf `
    --out gamedata/cryoffear/fonts --name cof_hudtext --sizes 14,19
```

The HUD text sizes are not a preference: the `.fnt` container addresses at most
65536 atlas pixels, and above a ~20 px base the packer drops glyphs out of the
216-character cp1252 set.

## Code pages

The game and the language packs are 8-bit text. Each path handles that
differently:

* **VGUI** decodes every byte with `cof_text_codepage` (1250 Central European,
  1251 Cyrillic, 1252 Western) immediately before the glyph lookup; a language
  pack sets it from its manifest. Inter covers Latin Extended-A and Cyrillic.
* **MainUI** draws UTF-8 from the TTFs at run time: ASCII, Latin-1 from
  U+00A1, Latin Extended-A, Cyrillic U+0400-045F with Ґґ, and cp1251
  punctuation. `scripts/polish/extract-menu-strings.ps1` checks a pack's menu
  strings against that set.
* **The two atlas sets are cp1252 only.** A 1250 or 1251 pack whose text reaches
  the console or the engine HUD path (`game_text` from a translated `.ent`) would
  show wrong glyphs there. Not observed in the Polish runs; a cp1250 atlas or a
  per-character decode is the fix if it shows up (open item in
  [language packs](language-packs.md) section 6).

## The game's own fonts, for reference

* `CONCHARS` in `gfx.wad`: an orange, variable-width `.fnt`. Stock FWGS misread
  it as a 16x16 grid; [the console font fallback](../patches/cof-console-variable-font-fallback.md)
  fixed that. It is the console's fallback when the Inter atlases are missing,
  and the styled console loads its font as luminance
  (`cof_console_font_grayscale`) so the orange does not tint every colour.
* `gfx/creditsfont.fnt`: the engine HUD text font before milestone 4b
  (`cof_hud_text_font 0` restores it).
* `gfx/vgui/fonts/<res>_<scheme>.tga` with `.chw` width tables: the client's
  VGUI strips, built as "Arial"; the resolution table caps at 1600 and the
  strips stop changing at the 1024 bucket, which is why they could not scale.
  `cof_ui_inter_fonts 0` restores them.
