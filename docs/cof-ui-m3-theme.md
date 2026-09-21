# Unified UI, milestone 3a: the Source-style theme and dialogs

Scope: give the engine menu one minimalist Source-era look — translucent dark
panels with a title band and a close X, a centred main-menu list with a text
wordmark, muted grey type on a single amber accent, and primitive-drawn
controls so nothing depends on `gfx/shell` artwork Cry of Fear does not ship.
Milestone 1 (`docs/cof-ui-m1-plumbing.md`) put the engine menu over the live
scene, milestone 2 (`docs/cof-ui-m2-cof-menu.md`) made it *be* Cry of Fear's
menu; this milestone is the styling pass, planned in
`stage1/ui-theme-spec-20260921/RESULTS.md`.

Everything was verified in the disposable fixture
`stage1/ui-m1-menu-fixture-20260921` (README there for the recipe), windowed
with `+volume 0`, at 1920x1080, 1280x720 and 2560x1440. The canonical game copy
at `K:\LLM\COF_Fix\Cry of Fear` was never written to: 6 197 files,
4 702 274 797 bytes, newest mtime `2026-09-18T20:33:58.9860178Z`, identical
before and after (`evidence/canonical-manifest-m3-before.txt` and `-after.txt`
are byte-identical, SHA-256
`35EA26352345FA048F20ACE4D28D040A2BC616D1E919A6196F25644E5F639111`).

Labels as before: **measured** = seen in a screenshot, a log line or a shipped
binary; **inferred** = a reading of measured facts.

## What changed

One MainUI patch, `patches/cof-mainui-source-theme.patch`, applied with
`scripts/apply-cof-mainui-source-theme.ps1` on top of the pinned MainUI
revision `61263995592e93a278d764807243d043d3b97c54` **and** the three earlier
MainUI patches (`cof-mainui-menu-save.patch`,
`cof-mainui-background-scrim.patch`, `cof-mainui-cof-menu.patch`), plus three
font files and their licence under `gamedata/cryoffear/gfx/fonts/`.

36 files, 2 428 insertions, 157 deletions. **Superseded:** the feedback round
below extends the same patch in place; it is now 40 files, 3 457 insertions,
140 deletions, and the artefact hashes in *Feedback-round artefacts* are the
current ones.

| File | Change |
| --- | --- |
| `Theme.h` / `Theme.cpp` (new) | the palette, the type scale, the panel metrics, the `ui_theme` cvar, the hairline/triangle/cross/tick primitives and the letter-spaced text helper |
| `BaseMenu.cpp` / `.h` | call `UI_ThemeInit()` from `UI_Init` before `colors.lst`; make `uiStatic.outlineWidth` a hairline in theme mode; seven new `HFont` handles |
| `font/FontManager.cpp` | Inter through stb_truetype, the three static weights, the GDI fallback chain, the theme handles, no blur fonts |
| `font/WinAPIFont.cpp` | compiled even when stb is the primary backend, so the fallback chain has somewhere to go |
| `controls/Framework.*` | panel mode: scrim, panel, hairline border, title band, close X, right-aligned button row, layout helpers, theme status line, no banner and no banner slide |
| `controls/PicButton.*` | a plain-text theme draw path with three styles (main-menu item, panel row, button box); no glow, no decay, no drop shadow |
| `controls/CheckBox.cpp` | a 22x22 primitive box with a drawn tick |
| `controls/Slider.cpp` | primitive track, filled portion and knob, and cursor mapping to match |
| `controls/SpinControl.*` | one framed box with drawn triangles for the arrows |
| `controls/Table.cpp` | theme selection/hover fills, drawn scroll triangles, one forced row colour |
| `controls/DropDown.cpp` | theme colours, a square arrow gutter with a drawn triangle |
| `controls/Switch.cpp` | theme segmented control |
| `controls/Field.cpp`, `controls/Action.cpp` | theme fonts, no drop shadow, no console-font status text |
| `controls/MessageBox.*`, `controls/YesNoMessageBox.*` | the same panel chrome and a centred 520x200 confirmation layout |
| `menus/Main.cpp` | the centred Cry of Fear main menu with the `CRY OF FEAR` / `ENHANCED` text wordmark; the pause menu keeps the lower-left list |
| `menus/CryOfFear.cpp` | difficulty, custom campaign, language and extras as panels |
| `menus/Configuration.cpp`, `Video.cpp`, `VideoOptions.cpp`, `VideoModes.cpp`, `Audio.cpp`, `Controls.cpp`, `AdvancedControls.cpp`, `LoadGame.cpp`, `SaveLoad.cpp`, `CreateGame.cpp`, `ServerBrowser.cpp` | per-dialog panel sizes and grid layouts |

### The switch: `ui_theme`

Archived, default `1`. `0` restores the upstream WON look byte-for-byte on the
code paths that matter (amber pic buttons with the two-pass Gaussian glow, the
fat 4-unit outline, the banner, the console-font status text). The cvar is
sampled once in `UI_Init`, because turning it on also decides the font family
and rewrites the library's colour globals, so changing it needs a restart.

## The theme

### Palette

Packed `0xAARRGGBB`, as in `Theme.h`. `UI_ThemeInit` copies them over MainUI's
globals *before* `UI_ApplyCustomColors()`, so a `gfx/shell/colors.lst` is still
the last word on the seven keys it can reach — but it cannot set alpha
(`UI_ParseColor` → `PackRGB`), which is why the translucent panels can only
live in code.

| Token | Value | Use |
| --- | --- | --- |
| `THEME_SCRIM` | 0 0 0 150 | behind every modal panel |
| `THEME_PANEL` | 32 32 32 230 | dialog body |
| `THEME_PANEL_BORDER` | 150 150 150 200 | the 1 px panel border |
| `THEME_TITLE_BAND` | 20 20 20 240 | title strip |
| `THEME_TITLE_TEXT` | 220 220 220 | uppercase panel title |
| `THEME_TEXT` | 190 190 190 | body, rows, items at rest |
| `THEME_TEXT_DIM` | 140 140 140 | labels above controls, hints, the status line |
| `THEME_TEXT_HI` | 240 240 240 | hovered |
| `THEME_ACCENT` | 240 180 24 | the single accent: selected row, tick, knob, focused frame |
| `THEME_SELECT_FILL` | 240 180 24 @ 51 | behind the selected row |
| `THEME_HOVER_FILL` | 255 255 255 @ 20 | behind a hovered row or button |
| `THEME_DISABLED` | 100 100 100 | grayed |
| `THEME_INPUT_BG` / `_BORDER` | 12 12 12 @ 200 / 90 90 90 | control boxes |
| `THEME_TRACK` | 60 60 60 | slider track |
| `THEME_SEPARATOR` | 255 255 255 @ 64 | hairlines under the title band and above the button row |

The accent is MainUI's own `uiPromptTextColor`, kept rather than invented, so
`colors.lst PROMPT_TEXT_COLOR` stays meaningful.

### The border

`uiStatic.outlineWidth` was 4 virtual units, scaled — about 5.6 px at 1080p and
11 px at 2160p, which is what made every control read as a heavy WON frame. In
theme mode `UI_VidInit` sets it to `max(1, round(scaleY))` instead, so **every**
`UI_DrawRectangle` call site in the library becomes a hairline from one line of
code, and the spin control's arrow geometry (derived from `UI_OUTLINE_WIDTH`)
tightens with it.

### Type: Inter through stb_truetype

The build now configures `--enable-stbtt`, so `MAINUI_USE_STB` is defined and
`CStbFont` is the primary backend. `CFontManager::FindFontDataFile` maps the
family `Inter` onto one of three shipped static faces by the requested weight,
because stb_truetype cannot synthesise a weight:

| Requested weight | File |
| --- | --- |
| < 500 | `gfx/fonts/Inter-Regular.ttf` |
| 500–599 | `gfx/fonts/Inter-Medium.ttf` |
| ≥ 600 | `gfx/fonts/Inter-SemiBold.ttf` |

Handles, all built in `CFontManager::VidInit` and stored in `uiStatic`
(sizes are virtual units, multiplied by `scaleY` at build time):

| Handle | Tall | Weight | Face | Used by |
| --- | --- | --- | --- | --- |
| `hThemeTitle` | 17 | 600 | SemiBold | panel title band |
| `hThemeLabel` | 16 | 400 | Regular | labels above controls, hints, the status line |
| `hThemeBody` | 19 | 400 | Regular | list rows, control values, panel rows, message text |
| `hThemeButton` | 19 | 600 | SemiBold | button row |
| `hThemeItem` | 24 | 500 | Medium | main and pause menu items |
| `hThemeLogo` | 46 | 600 | SemiBold | `CRY OF FEAR` |
| `hThemeLogoSub` | 20 | 500 | Medium | `ENHANCED` |

**Measured** (`evidence/m3.log`): `Rendering Inter(36, 500)`,
`Rendering Inter(64, 600)` and so on — every handle comes from the shipped
files.

**Fallback.** `CFontBuilder::Create` no longer drops straight to the bitmap
font when the primary backend fails. It walks `Inter → Tahoma → Verdana →
Microsoft Sans Serif → Arial` on the **GDI** backend, which is now compiled
even when stb is primary (`font/WinAPIFont.cpp` lost its
`!defined(MAINUI_USE_STB)` guard). Only if that whole chain fails does the
bitmap font appear. **Measured**: with no `gfx/fonts/tahoma.ttf` shipped, the
menu's own console-font handle logs
`Unable to read font file gfx/fonts/tahoma.ttf!` followed by
`Font "Tahoma" is unavailable, using "Inter"` and renders normally.

On Windows `SCALE_FONTS` is not defined, so `charH` never changes glyph size —
a new text size genuinely needs a new `HFont`, which is why there are seven.

**Metric note.** Inter at a given `tall` renders very close to Tahoma at the
same `tall` here: `CStbFont::Create` scales for a pixel height of `tall + 4`
while `CWinAPIFont::Create` asks GDI for a cell of `tall + 6`, and Inter's
larger x-height roughly cancels the four-versus-six difference. The spec's
sizes were kept unchanged and nothing overflows at 1280x720 (see the 720p
captures, including the widest panel, Join Server at 960 units with a
seven-button row).

### Metrics

Virtual units of the 768-tall space. Panel: title band 34, padding 24 / 20 / 20,
button row 32 with a 20 gap and 12 between buttons (minimum width 110, widened
to the button's own text plus 28), 2-column gutter 28, 3-column gutter 22, row
height 30 with a 34 pitch, control height 30, checkbox 22, slider track 6 in a
26-unit hit box. Close X: 26x26, inset 6 from the panel's right edge.

## The screens

All paths are under `stage1/ui-m1-menu-fixture-20260921/evidence/`.

### Main menu — `m3-main.png` `08C9D6DF…` (1080p), `m3-720-main.png` `07A9BFE2…` (720p), `m3-1440-main.png` `4DE28497…` (1440p)

A centred column over the live `c_game_menu1` scene, as in Cry of Fear's own
menu: every line centred on the screen's horizontal middle, and the wordmark
plus the ten items treated as one group whose centre sits at 52 % of the
height. `CRY OF FEAR` in the largest handle in `THEME_TEXT_HI` with 4 units of
extra letter spacing, `ENHANCED` directly under it in a much smaller handle in
`THEME_TEXT_DIM` with half the tracking. No banner, no background bitmap, no
minimize/close window buttons. Each item's hit box is exactly as wide as its
own text plus 12 units and is recomputed in `VidInitCoF`, so the mouse
rectangle and the keyboard cursor follow the drawn position at every
resolution. Hover is text-only: `THEME_TEXT` → `THEME_TEXT_HI`, nothing moves.
The page's one hint line is drawn bottom-left in the theme label font
(`Start a new game.` in the 1080p capture).

`UI_DrawString` advances strictly by `DrawCharacter`'s return, so the wordmark's
tracking is drawn by `UI_ThemeDrawTracked`, which walks the string itself.

### Pause menu — `m3p-pause.png` `F33C6864…`

The same five items (`Resume game`, `Save\Load Game`, `Options`,
`Quit to menu`, `Quit`) in the Source-reference lower-left list, flush to a
64-unit margin and anchored 96 units above the bottom, over the paused forest
scene through the `ui_scrim_alpha 150` scrim. No wordmark — it belongs to the
main menu only.

### New game / difficulty — `m3-difficulty.png` `3969A4D7…`, `m3-720-difficulty.png` `C9B44705…`, `m3-1440-difficulty.png` `C858658E…`

560x400 panel titled `NEW GAME`. The campaign caption (`Cry of Fear`, or
`Custom campaign: … (first map …)`) as a dim line, then the four difficulties
as full-width selectable rows instead of four WON pic buttons — the current one
carries `THEME_SELECT_FILL` and accent text. Clicking a row still starts the
game exactly as before; a `Start` button was added that starts the row that has
focus. The locked Nightmare row greys out and its explanation moves from a
hover-only status string to a dim caption under the list. The
`Enable developer commentary` checkbox sits above the button row and now draws
a real box, so the `[ON ]`/`[OFF]` text marker milestone 2 needed is gone.
Buttons: `Cancel` `Start`. (The capture shows Nightmare selectable because the
fixture's `config.cfg` carries `cof_nightmare_unlocked "1"` from milestone 2.)

### Custom campaign — `m3-campaign.png` `88D05C92…`

860x520, `CUSTOM CAMPAIGN`, two columns split 0.70/0.30. All twelve campaigns
in the list, `From maps/*.custom` as the dim caption under it, and the selected
campaign's description, author and first map as running text in the right
column. Buttons: `Cancel` `Play`.

### Language — `m3-language.png` `AA1A0231…`

420x420, `LANGUAGE`, seven full-width rows. The current choice is marked on the
row itself (accent text on `THEME_SELECT_FILL`), which replaces milestone 2's
`Subtitle language: …` caption. The capture shows German selected, matching the
fixture's archived `cof_subtitlelanguage "4"`. Button: `Close`.

### Extras — `m3-extras.png` `2AEAC63E…`

520x400, `EXTRAS`, six rows with the URL as a dim second line under each row
instead of a hover-only status string. Button: `Close`.

### Load game — `m3-loadgame.png` `DAAE93B1…`, `m3-720-loadgame.png` `0F675449…`, `m3-1440-loadgame.png` `56144103…`

860x560, `LOAD GAME` (`SAVE GAME` in save mode), two columns split 0.62/0.38:
the five Cry of Fear slots on the left, the save thumbnail in a 16:9 box on the
right. Buttons: `Delete` (hidden for Cry of Fear) `Cancel` `Load`.

### Save / load hub — `m3p-saveload.png` `7F6E9F88…`

480x300, `SAVE / LOAD`, two rows plus the pause-save checkbox and the hint
caption. The checkbox draws a real box, so its `[ON ]`/`[OFF]` marker is gone
too. Button: `Close`.

### Options and its subpages

| Screen | Capture | Panel |
| --- | --- | --- |
| Options | `m3-options.png` `0CB1AB81…` | 420x300, three rows: Controls, Audio, Video. Touch, Gamepad and Update are not added for this build |
| Video | `m3-video.png` `A117BDDB…` | 420x260, two rows |
| Video options | `m3-vidoptions.png` `8C982D43…` | 860x560, sliders then the checkbox block; the gamma preview hides itself because `gfx/shell/gamma` is not shipped |
| Video modes | `m3-vidmodes.png` `7F69259A…` | 860x520, renderer and window-mode spinners plus V-sync on the left, the resolution table on the right |
| Audio | `m3-audio.png` `B2AF7A0C…` | 640x460, three sliders left, three checkboxes right; the two vibration items are hidden on desktop |
| Controls | `m3-controls.png` `B484795E…`, `m3-720-controls.png` `B5FB7EAC…`, `m3-1440-controls.png` `F34B284A…` | 900x600, the key list full width; buttons `Use Defaults` `Adv. Controls` `Cancel` `OK` |
| Advanced controls | `m3-advcontrols.png` `6517B15B…` | 640x480, two checkbox columns, sensitivity slider, `Close` |

**Superseded by the feedback round below:** Options is now four rows with *Game*
first, the Video hub and its two children are one *Video* page, Advanced
Controls is the *Game* page and is no longer reachable from Controls, and Audio
has no HEV suit volume. The `m3-*` captures above are the first deployed build;
the current ones are the `m3fb-*` set.

### Join and host — `m3-join.png` `911D8332…`, `m3-720-join.png` `B1C63095…`, `m3-host.png` `8E691209…`

Join Server is 960x620 with the tab strip as a themed segmented control under
the title band, the server table filling the content, the four filter
drop-downs in a row above the button row, and all seven buttons in one
right-aligned row (`Favorite` `View game info` `Create Server` `Refresh`
`Add server` `Close` `Join`). Host Server is 900x560 with the form on the left
and the map list on the right; buttons `Adv. Options` `Cancel` `Start`.

### Quit confirmation — `m3p-quit.png` `4AFD729F…`

520x200 centred panel titled `QUIT`, message centred in the content rect,
`Cancel` `Quit` bottom-right, over the pause menu and its scrim. Reached by
`menu_quit` while a game is loaded — out of game that command quits
immediately, which is why the capture is from the in-game run.

## The one functional change

The Cry of Fear client's own Load Game and difficulty panels stopped the
client's MP3 player before loading; the engine-menu path never did, so a
background map's music carried on into a save whose map starts no track (root
cause in `stage1/menu-music-20260921/RESULTS.md`). The menu now issues the
client's own console command `stopmp3` — no arguments, unconditional stop —
before the `load cofsaveN` in `CMenuLoadGame::LoadGame` (gated on
`UI_IsCoFRootSaveGame()`) and before the `cmd campaign` / `cmd skillset` pair in
`CMenuCoFDifficulty::StartGame` (gated on `UI_IsCryOfFear()`). This is a
different player from `EngFuncs::StopBackgroundTrack`, which is the engine's
own and is still called where it already was.

**Measured, `evidence/m3-stopmp3.log`:** the command executes between
`COFM3-stopmp3-probe` and `COFM3-stopmp3-done` with no `Unknown command` line,
so it reaches the client. **Audibility is a one-click manual test.**

## Artefacts

| Artefact | Bytes | SHA-256 |
| --- | ---: | --- |
| `patches/cof-mainui-source-theme.patch` (superseded) | 124 729 | `C1077E9C78FC5A8A8021ADA1D2CD547E9AA67B13C562F18AB37BA9A2170D1A51` |
| `menu.dll` (`build-cof-ui-m3-20260921`, superseded) | 1 402 368 | `9F33C0817DE2F5790471E27D7933A586BA1A41F1B46891FE555D7CF5D35F033E` |
| `menu.pdb` (superseded) | 18 280 448 | `7616AE6E52968A9B7DC4EFC39F7DCF918E87040B5FD27632D83F0FC9C1F854C6` |
| `gamedata/cryoffear/gfx/fonts/Inter-Regular.ttf` | 310 252 | `3127F0B873387EE37E2040135A06E9E9C05030F509EB63689529BECF28B50384` |
| `gamedata/cryoffear/gfx/fonts/Inter-Medium.ttf` | 315 132 | `A645F55492D1C8CDACE43C72BE8CBEC08E680B5A86D8B4C2D1C50D6E41E9CC96` |
| `gamedata/cryoffear/gfx/fonts/Inter-SemiBold.ttf` | 316 220 | `B0B540E69BF6717016E33874670E09ACF4BFFC2CA3F4C1CF174A4FF696308C65` |
| `gamedata/cryoffear/gfx/fonts/OFL.txt` | 4 470 | `3C8D13D97EA5EB62868833A377034C6BE6A9833E768D32ABEC2A767A8101E4BC` |
| engine `xash.dll` used for every run | 3 526 656 | `DC200932C8189C0E787CFB1750EBDC1CDC1A2CACEB7635B4078F3884D08F0786` |

Inter is licensed under the SIL Open Font License 1.1; `OFL.txt` is the licence
file from the upstream Inter package (`Copyright 2020 The Inter Project
Authors`). The three static faces were taken from the system font directory of
the build machine; they are game data, not repository content, and are not
committed.

Build (note `--enable-stbtt`, which is the only change from the milestone-2
configure line):

```
python waf configure -4 --out=build-cof-ui-m3-20260921 \
  --sdl2=..\prereq\sdl2-2.30.9-vc\SDL2-2.30.9 \
  -T release --notests --disable-mbedtls --enable-cof-entvars-legacy --enable-stbtt
python waf build -j8 --targets=menu
```

from the pinned FWGS checkout with the x86 MSVC environment
(`vcvarsall.bat amd64_x86`) and `WAFLOCK=.lock-waf-cof-ui-m3` so a concurrent
build in the same tree is not disturbed.

New cvar: `ui_theme` (archived, default `1`).

## Patch safety

`scripts/apply-cof-mainui-source-theme.ps1` follows the same pattern as the
earlier MainUI patches: `SourceRoot` must be inside the workspace, mainui must
be at the pinned commit, all three earlier MainUI patches must already be
present (checked by marker strings), the theme markers must be absent for a
forward apply and present for `-Reverse`, and both directions are verified
afterwards — including that a reverse did not damage the CoF-menu or menu-save
patches.

**Verified:** the script reverse-applied cleanly on the patched tree, leaving
`menus/CryOfFear.cpp`, the scrim and the save integration in place and removing
`Theme.cpp`/`Theme.h`, then re-applied forward; all 210 mainui files then hashed
identical to the pre-reverse snapshot and the rebuild produced the same
`menu.dll` `9F33C081…`. One caveat: this repository's git has
`core.autocrlf=true`, so `git apply` rewrites LF-only files with CRLF. That
changes no content — `git apply --ignore-whitespace` tolerates it — but it does
mean a round trip is not byte-identical without normalising those files back.

## Open, and what needs a manual test or an engine change

1. **No native interaction anywhere.** Every capture is a console command from a
   `maps/<map>_load.cfg`. Nothing was clicked, so hover, press, keyboard
   navigation, slider dragging, table scrolling, the close X and the drop-downs
   are **all manual tests**. The drawn states are visible in the captures
   (focused rows, grayed checkboxes) because the cursor and the keyboard cursor
   start on the first item.
2. **The `stopmp3` fix is measured as a command, not as silence.** Audibility is
   a one-click manual test.
3. **`CMenuSwitch` overlaps its segments when one is hidden.** The Join Server
   tab strip hides the deprecated NAT tab; upstream gives it zero width but the
   last visible segment is then stretched by `Draw`, so the labels are not
   evenly spaced. Upstream behaviour, not introduced here, and only cosmetic.
4. **Two upstream strings have no localisation entry** and render as
   `GameUI_VSync` and `GameUI_RawInput`. Pre-existing.
5. **The Load Game panel has no save comment under the thumbnail.** The spec
   asks for one; the comment lives in a private field of
   `CMenuSavesListModel` and exposing it was out of proportion to the gain.
6. **`CMenuGameOptions` is styled but not surfaced.** It is multiplayer-only and
   is reachable from Player Setup and the connection warning, not from Options.
7. **Colour codes in list models are forced to one row colour** in theme mode.
   That is deliberate — Cry of Fear's own `gfx/shell/kb_act.lst` is full of
   `^N` codes and the Controls list read as WON amber and cyan — but it means a
   model that uses colour to carry meaning loses it.
8. **One engine-side note for the console worker:** the theme pushes
   `SetConsoleDefaultColor( 190, 190, 190 )` from `UI_ThemeInit`, so the engine
   console text is grey rather than amber before milestone 3b starts.

## Feedback round, 2026-09-21 late evening

The user played the deployed build and reported nine items. All nine are fixed
in the **same** patch (`patches/cof-mainui-source-theme.patch`, regenerated in
place; the apply script and its marker checks are unchanged), rebuilt into
`build-cof-ui-m3-20260921` with the same configure line, and re-verified in the
same fixture at 1920x1080 and 1280x720. The canonical game copy was not written
to: `evidence/canonical-manifest-m3fb-before.txt` and `-after.txt` are
byte-identical (6 197 files, 4 702 274 797 bytes, newest mtime
`2026-09-18T20:33:58.9860178Z`, SHA-256
`35EA26352345FA048F20ACE4D28D040A2BC616D1E919A6196F25644E5F639111`).

The patch grew from 36 files / 2 428 insertions to 40 files / 3 457 insertions.
New files in it: `model/BaseModel.h` and `model/KbActListModel.h` (section
headers), `menus/CryOfFear.h` (the new page and the shared language helpers).

### 1. Hover never cleared on the main menu

**Cause (measured, source):** every themed control drew its hot state from
`this == m_pParent->ItemAtCursor()`. `ItemAtCursor()` returns the *holder's
cursor index*, and `CMenuItemsHolder::MouseMove` leaves `m_iCursor` on the last
item the pointer touched — it only clears `QMF_HASMOUSEFOCUS`. So the last
hovered item stayed lit forever.

**Fix:** the highlight follows the item's own focus flags instead, which is what
the stock pic-button path already did (`CMenuPicButton::Draw` builds `state`
from `QMF_HASMOUSEFOCUS|QMF_HASKEYBOARDFOCUS`). `Theme.h` has the rule as
`UI_THEME_HOT( item )`; `PicButton.cpp` uses the `state` it is already given,
and `CheckBox.cpp`, `Slider.cpp`, `SpinControl.cpp` and the panel close button
in `Framework.cpp` use the macro. Mouse-move focus transfer is unchanged
upstream behaviour: `MouseMove` calls `SetCursor` and clears both focus bits on
the previous item, so moving the pointer takes the highlight away from a
keyboard-focused item, and when the pointer is over nothing only a
keyboard-focused item stays lit.

**Evidence, and what is still manual.** `evidence/m3fb-main.png` and
`evidence/m3fb-pages-main.png` are two runs of the same page with the pointer
resting in different places; exactly one item is lit in each, and it is a
different one (`Custom Campaign` and `Extras`). `evidence/m3fb-pause.png` shows
the pause list with the pointer over none of it and nothing lit — which the old
build could not produce. **Moving the mouse off an item, and arrow-key
navigation, are still a manual test**: no input may be injected.

### 2. Text clipping in the confirm message box

**Cause (measured, source):** two separate things.
`CMenuYesNoMessageBox::_VidInit` sized the panel at a fixed 520x200, and
`UI_DrawString`'s vertically centred path starts halfway down the rect *and*
stops a line short of its bottom, so a rect with room for four lines fits two.
The `hud_scale` warning is two sentences plus a `\n\n`, so it ellipsised into
the button row.

**Fix:** `UI_ThemeWrappedLines()` counts the lines `UI_DrawString` will wrap a
string into (colour codes skipped, explicit newlines counted);
`UI_ThemeMessagePanelSize()` picks the narrowest of 520 / 660 / 800 virtual
units that keeps the dialog compact and returns the height for the wrapped text
plus the title band, the padding and the button row, clamped to 704. The
message item is aligned `QM_TOP` rather than `QM_CENTER` (`QM_CENTER` is 0, so
horizontal centring is kept) which makes the whole rect usable, and one line of
headroom is added once the message wraps at all. `CMenuYesNoMessageBox::Show()`
redoes the layout, because the message is set immediately before the box is
shown. `CMenuMessageBox` (the *Press a key* box) got the same treatment in a new
`_VidInit`; `menus/Controls.cpp` no longer stamps a WON rect over it.

**Audit of the other dialogs at 1280x720:** the sizing is in the two message-box
classes, so every caller inherits it — the quit and disconnect confirmations
(`menus/Main.cpp`), the update check (`Configuration.cpp`), the keyboard-defaults
warning (`Controls.cpp`), the test-mode and restart boxes (`VideoModes.cpp`),
the connection warning and the *Press a key* box. `evidence/m3fb-720-*.png`
shows no clipping on any panel at 720p.

### 3. A top-level Game options page

`menus/AdvancedControls.cpp` is now that page: title `GAME`, 760x520, and
Options lists it **first** (`Game, Controls, Audio, Video` — `Configuration.cpp`,
panel grown to 420x340). It holds the eight advanced control checkboxes in two
columns, the mouse-sensitivity slider and the *Input devices* row exactly as
before, plus, for Cry of Fear only, the **Pause menu saves** checkbox moved out
of Save/Load and a **Subtitle language** spin control. The *Adv. Controls*
button is gone from Controls in theme mode. Without the theme the page is still
the stock Advanced Controls dialog reached from Controls, unchanged.

The language control shares one implementation with the Language page:
`UI_CoFSubtitleLanguageCount/Name/Get/Set` in `menus/CryOfFear.cpp`, which keeps
the measured behaviour (`cmd subtitleset N` when a server is up, otherwise the
archived `cof_subtitlelanguage` directly). `menus/SaveLoad.cpp` keeps the
checkbox object, hidden, only to read the cvar and decide whether *Save Game* is
offered, and re-reads it in `Show()`; its hint line now points at
Options > Game.

### 4. Pause-menu background was black behind the scrim

**Cause (measured):** the scrim in `CMenuBackgroundBitmap::DrawInGameBackground`
only replaces the opaque fill while `ui_renderworld` is on, and FWGS registers
that cvar with a default of `"0"` (`engine/client/cl_main.c:92`). The deployed
build therefore drew the scrim over a scene the engine was not rendering.

**Fix:** `UI_ThemeApplyDeferredDefaults()` turns it on once for Cry of Fear and
records that in the archived `ui_cof_scene_defaults`. Two details matter:

* the marker cvar is **registered** in `UI_ThemeInit` (UI_Init, inside
  `CL_Init`) but **read** later, because `Host_Init` execs `config.cfg` after
  `CL_Init` and a name the menu has not registered yet never reaches it. The
  first attempt registered it lazily and the user's choice was overwritten on
  every launch;
* the flip itself runs from `UI_UpdateMenu`'s one-time block, the same place
  that loads the backgrounds and the strings, which is the first point safely
  past the `config.cfg` exec.

**Measured.** With `ui_renderworld` and `ui_cof_scene_defaults` removed from the
fixture's `config.cfg`, `evidence/m3fb-pause.log:735` prints
`Cry of Fear: ui_renderworld defaulted to 1 …`, `config.cfg` comes back with
`ui_renderworld "1"` and `ui_cof_scene_defaults "1"`, and
`evidence/m3fb-pause.png` / `m3fb-720-pause.png` show the paused forest through
the scrim. With `ui_renderworld "0"` written back by hand and the marker left at
`1`, `evidence/m3fb-pause-userchoice.log` has no such line, the cvar stays `0`
afterwards, and `evidence/m3fb-pause-userchoice.png` shows the old,
scene-less appearance — the user's choice is respected.

### 5. HEV suit volume removed from Audio

`suitVolume` drives `suitvolume`, which is Half-Life's suit speech; Cry of Fear
has no suit. `menus/Audio.cpp` hides it for Cry of Fear and lays out only the
visible sliders. Everything else on the page is untouched.
`evidence/m3fb-pages-audio.png`.

### 6. One Video page

`menus/VideoModes.cpp` now also owns the former Video-options controls: the
gamma and brightness sliders and the six image checkboxes, with their cvar
links, the `hud_scale` warning box and the per-renderer graying copied over
verbatim. The panel is `VIDEO`, 940x620: renderer, window mode, V-sync and the
resolution table on the left, gamma, brightness and the checkboxes on the right,
one `Cancel` `Apply` row. Apply writes the image settings and then runs the
unchanged `SetConfig()`, so the fullscreen test-mode countdown and the
renderer-change restart prompt behave exactly as FWGS does. `menus/Video.cpp`
keeps the old hub for the non-theme path only and forwards
`UI_Video_Menu()` straight to this page in theme mode; `menus/VideoOptions.cpp`
is untouched and still serves the WON look. `evidence/m3fb-pages-video.png`,
`m3fb-720-pages-video.png`.

### 7. Extras: Cry of Fear: Enhanced

Added as the **first** entry, `https://cofenhanced.haej.pl`, opened through the
same `EngFuncs::ShellExecute` path as the other six. Panel grown to 560x440 for
the seventh row. `evidence/m3fb-pages-extras.png`.

### 8. An engine-menu Unlockables page

`CMenuCoFUnlockables` (`menus/CryOfFear.cpp`, command `menu_cofunlockables`),
940x600, a table of the 27 items measured in `client.dll`
(`stage1/ui-data-research-20260921/RESULTS.md` §1.4) with columns
**Unlockable | How to unlock | Status**, a dim caption explaining the `?`, and
the buttons `Open original gallery` `Close`. The main menu's Unlockables item
routes here instead of running `unlockablescmd`; that command is now what the
gallery button runs, so the old route is still one click away (the engine worker
owns its return path).

**Status is honestly unknown.** `UI_CoFUnlockableStatus( index )` is the
documented hook — it returns `-1` unknown, `0` locked, `1` unlocked, and today
it answers `-1` for everything except Nightmare, which it reads from the
project's own stand-in cvar `cof_nightmare_unlocked`. There is no real flag
source: `cryoffear/scriptsettings.dat` is 101 fixed-width obfuscated tokens
compared against 34 paired constants compiled into `client.dll` and the
token-to-item mapping is unresolved (research §1.3, explicitly open).

**"How to unlock" is unknown too, and that is measured.** A sweep of the shipped
data (`txtfiles`, `notes`, `resource`, `scripts`, the gallery map's entity lump,
every `*.txt`/`*.res`/`*.lst`/`*.cfg`) and of both game DLLs' string tables
found only the `Unlocked: …` announcements, the gallery art names, and five book
*page titles* in `hl.dll` (`How To Unlock Book Pages`, `Ranking System
Explained`, `How To Unlock Hoodies`, `How To Unlock Secret Items`, `How To
Unlock Secret Weapons`); the pages themselves are rasterised textures inside
`models/bookmenu.mdl` (`page`, `page1`..`page5`), so no string form exists.
`s_cofUnlockHow[]` is therefore the one place to fill in when a condition is
measured; every entry it does not know reads `?`.
`evidence/m3fb-pages-unlockables.png`, `m3fb-720-pages-unlockables.png`.

### 9. Section rules in the Controls list

`gfx/shell/kb_act.lst` marks a section the GoldSrc way — a `"blank"` row of `=`,
the caption, another row of `=` — and the table drew all three as text.
`CMenuKbActListModel::CollapseSections()` (theme mode only) drops every
rule-of-equals row and turns what is left of each separator into a section
caption, uppercased and stripped of colour codes. `CMenuBaseModel` gained
`IsLineSectionHeader( line )`; `CMenuTable::Draw` renders such a row as a small
uppercase `THEME_TEXT_DIM` caption in the label font with a hairline under it,
with no selection or hover fill, and `MoveCursor`, `SetCurrentIndex` and the
mouse row-pick step over them, so keyboard navigation never lands on one.
`menus/Controls.cpp` seeds the cursor with `SetCurrentIndex( 0 )`, which lands
on `Move forward`. `evidence/m3fb-pages-controls.png` (1080p),
`m3fb-720-pages-controls.png`.

### Feedback-round artefacts

**Superseded by the death-flow round below.**

| Artefact | Bytes | SHA-256 |
| --- | ---: | --- |
| `patches/cof-mainui-source-theme.patch` (superseded) | 169 722 | `8CB3BA283169C86CCBE0463DB852F140C4CB5E71AA5D0016056C665AA5A79405` |
| `menu.dll` (`build-cof-ui-m3-20260921`, superseded) | 1 417 728 | `84307B5BDD71E67AF2C02D68B828BC6D25C5D97027D8F81BC250B4ABF024DD0D` |
| `menu.pdb` (superseded) | 19 992 576 | `C93E7F42F9618964CA4850BF6C0BB5B99548774D42D6D9F5B8E6B001EBA2C4B9` |
| engine `xash.dll` used for every run | 3 526 656 | `DC200932C8189C0E787CFB1750EBDC1CDC1A2CACEB7635B4078F3884D08F0786` |

New cvar: `ui_cof_scene_defaults` (archived, default `0`, set to `1` the first
time the `ui_renderworld` default is applied). `ui_theme` is unchanged.

**Patch safety, re-verified.** `scripts/apply-cof-mainui-source-theme.ps1`
reverse-applied the regenerated patch on the patched tree — leaving the
CoF-menu, scrim and menu-save patches intact — and re-applied it forward; all
185 mainui source files then compared identical to the pre-reverse snapshot
(line-ending-insensitive, the `core.autocrlf=true` caveat below) and the rebuild
produced the same `menu.dll` `84307B5B…`.

### Still manual after this round

1. **Every interaction.** Hover leaving an item, arrow-key navigation over the
   new section captions, clicking *Open original gallery*, the Extras browser
   tab, dragging the merged Video page's sliders, the `hud_scale` warning box
   (it is only reachable by clicking the checkbox in game; the wrap fix was
   verified with the identical text through `menu_showmessagebox`).
2. **Applying a resolution change from the merged Video page** — the test-mode
   countdown and the restart prompt are unchanged code, not re-measured here.
3. `GameUI_VSync` and `GameUI_RawInput` still have no localisation entry
   (pre-existing, item 4 of the list above).

## Death-flow round, 2026-09-22

The same patch grew two more things, both documented in
[the death flow and "Enable console"](cof-ui-death-flow.md):

1. **`CMenuCoFDeath`** (`menus/CryOfFear.cpp`, command `menu_cofdeath`, declared
   in `menus/CryOfFear.h`) - the engine-menu replacement for Cry of Fear's
   `GAME OVER` panel, opened by the engine's new `cof_ui_death_menu` hook. It is
   the one page in the theme with no panel and no scrim: `Theme.cpp` gained
   `UI_ThemeSetSceneUnveiled()` / `UI_ThemeSceneUnveiled()` and
   `UI_ThemeDeathBacking()`, `Theme.h` the `THEME_DEATH_*` tokens, and
   `controls/BackgroundBitmap.cpp` a two-line early return in
   `DrawInGameBackground` so the scene the player died in is drawn untouched.
2. **"Enable console"** on the Game page (`menus/AdvancedControls.cpp`), bound to
   the archived engine cvar `con_enable` that the death-flow engine patch adds.

The patch is regenerated in place and is now **41 files**
(`controls/BackgroundBitmap.cpp` joins the list; it was already touched by
`cof-mainui-background-scrim.patch`, and this patch adds one hunk on top). The
apply script is unchanged except for four more marker checks.

| Artefact | Bytes | SHA-256 |
| --- | ---: | --- |
| `patches/cof-mainui-source-theme.patch` | 170 228 | `AD1A3BC1D8CFBC3A8BBE732147668AB4A3F97AD37D44E517D8B0855750277BF2` |
| `menu.dll` (`build-cof-ui-m3-20260921`) | 1 470 976 | `1704D258E8125C89CA8514F48D5A5363C244ABDB15BBC22F1BC2E5831F58E627` |
| `menu.pdb` | 21 458 944 | see the build directory |
| engine `xash.dll` used for the death-flow runs | 3 510 784 | `C2A17F232A7E6B5F1BBBC8D02815558BDF4BC82E7EAABC831514C93E394B2204` |

Build line unchanged (`--enable-stbtt`, `WAFLOCK=.lock-waf-cof-ui-m3`).

**Patch safety, re-verified.** On `cof-fix/pristine-ui-m1-scratch` over the
pinned MainUI baseline plus the three earlier MainUI patches: forward apply,
duplicate-apply refusal, reverse, forward again - and all 187 mainui files then
compared identical to the working tree (line-ending-insensitive; the
`core.autocrlf=true` caveat above still applies, and is now why the patch is
generated LF-normalised).

Evidence for both additions is in `stage1/ui-m1-menu-fixture-20260921/evidence/`
as the `d*` and `b*` runs listed in `docs/cof-ui-death-flow.md`.

## Evidence index

All under `stage1/ui-m1-menu-fixture-20260921/evidence/`.

### Feedback round

| File | Shows |
| --- | --- |
| `m3fb-main.png`, `m3fb-720-main.png` | the main menu over the live scene, one item lit under the pointer |
| `m3fb-pause.png`, `m3fb-720-pause.png` | the pause menu with the paused scene through the scrim, and the `ui_renderworld` default applied |
| `m3fb-pause-quit.png`, `m3fb-720-pause-quit.png` | the quit confirmation, wrapped and clear of the button row |
| `m3fb-pause-userchoice.png`, `-userchoice.log` | `ui_renderworld "0"` kept: no default line, scene not drawn |
| `m3fb-pages-options.png`, `m3fb-720-pages-options.png` | Options with Game first |
| `m3fb-pages-game.png`, `m3fb-720-pages-game.png` | the new Game page |
| `m3fb-pages-audio.png`, `m3fb-720-pages-audio.png` | Audio without the HEV suit volume |
| `m3fb-pages-video.png`, `m3fb-720-pages-video.png` | the merged Video page |
| `m3fb-pages-extras.png`, `m3fb-720-pages-extras.png` | Extras with `Cry of Fear: Enhanced` first |
| `m3fb-pages-unlockables.png`, `m3fb-720-pages-unlockables.png` | the Unlockables page |
| `m3fb-pages-controls.png`, `m3fb-720-pages-controls.png` | Controls with section captions and no `Adv. Controls` button |
| `m3fb-pages-confirm.png`, `m3fb-720-pages-confirm.png` | the long warning wrapped in full |
| `m3fb-pages.log`, `m3fb-720-pages.log`, `m3fb-main.log`, `m3fb-720-main.log`, `m3fb-pause.log`, `m3fb-720-pause.log` | the runs |
| `canonical-manifest-m3fb-before.txt`, `-after.txt` | the canonical tree unchanged |

### Milestone 3a

| File | Shows |
| --- | --- |
| `m3-main.png`, `m3-720-main.png`, `m3-1440-main.png` | the centred main menu and wordmark at three resolutions |
| `m3p-pause.png` | the pause menu over a loaded save |
| `m3-difficulty.png`, `m3-720-difficulty.png`, `m3-1440-difficulty.png` | the difficulty panel |
| `m3-campaign.png` | all twelve custom campaigns with the detail column |
| `m3-language.png`, `m3-extras.png` | the language and extras panels |
| `m3-loadgame.png`, `m3-720-loadgame.png`, `m3-1440-loadgame.png` | the save list and thumbnail |
| `m3p-saveload.png` | the save/load hub with the pause-save checkbox |
| `m3-options.png`, `m3-video.png`, `m3-vidoptions.png`, `m3-vidmodes.png`, `m3-audio.png`, `m3-controls.png`, `m3-advcontrols.png` | Options and its subpages |
| `m3-720-controls.png`, `m3-1440-controls.png`, `m3-720-join.png` | the same pages at 720p and 1440p |
| `m3-join.png`, `m3-host.png` | the server browser and create-server panels |
| `m3p-quit.png` | the quit confirmation |
| `m3.log`, `m3p.log`, `m3-720.log`, `m3-1440.log`, `m3-main.log`, `m3-720-main.log` | the runs, including the Inter font lines |
| `m3-stopmp3.log` | `stopmp3` executing with no `Unknown command` |
| `canonical-manifest-m3-before.txt`, `-after.txt` | the canonical tree unchanged |
