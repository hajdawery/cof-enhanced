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
fixture's `config.cfg` carried `cof_nightmare_unlocked "1"` from milestone 2.
**Superseded by the unlockables round below:** that cvar no longer exists and
the gate reads `scriptsettings.dat` line 83.)

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

**Superseded by the *Unlockables round* below**, which decoded the file and made
both the status column and the Nightmare gate real. The rest of this item
describes the page as it was first built.

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

The death page did **not** stop Cry of Fear's death music in this round; that is
the *Death-music round* at the end of this document.

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

## Unlockables round, 2026-09-22

The unlock state is no longer unknown. `cryoffear/scriptsettings.dat` is
decoded, the Unlockables page shows a real **Unlocked** / **Locked** per flag,
and the difficulty page's Nightmare gate reads the same file instead of the
milestone-2 stand-in cvar, which is removed.

### The file, byte for byte (measured)

`GAME/cryoffear/scriptsettings.dat`, 2 222 bytes, SHA-256
`194E7144C398A7176D7BCA8543FFD4547949AC998E6F38FA38982DC7D6295F1E`:

* **101 lines of exactly 20 bytes**, separated by CRLF, with a trailing CRLF
  after the last one. `101 * 20 + 101 * 2 = 2222`, and every one of the 101
  splits is 20 bytes long — verified, not assumed.
* Line bytes are printable ASCII plus the single extended byte **`0xA3`**. That
  settles the guide's `£`: it is one byte, `0xA3`, in the file *and* in
  `client.dll`, not a UTF-8 `£` (`0xC2 0xA3`) and not a wide character. It
  occurs in 15 of the 101 lines and in 11 of the 34 token pairs. In the menu
  source it is written as the octal escape `\243`, because a hex escape would
  swallow a following hex digit (`"\xA3e"` is one character, not two).

### The comparison table in client.dll (measured)

Immediately after the `"/alt.dat\0"` literal at VA `1014118C`, padded to a
4-byte boundary, `client.dll` carries **34 pairs of 20-byte tokens**, each
stored as `<20 bytes>'\n'` padded to 24. The table runs from VA `10141198` to
VA `101417F8` (1 632 bytes) and is followed by the unrelated `"Ending seen: %d"`
strings. The two members of a pair differ in **exactly one character** — checked
for all 34.

The `'\n'` in the binary is why the file is CRLF: the client writes a token
through a text-mode stream, which expands it.

### The pair-to-line mapping (derived, not guessed)

Every one of the 34 pairs matches **exactly one** line of the canonical
`scriptsettings.dat`, and the 34 matched lines are all distinct. That is what
pins each pair to its line; the mapping is read out of the shipped file, not
inferred from ordering. Table order and file order do not agree.

All 27 entries of the Steam guide's table
(`stage1/ui-data-research-20260921/unlockables-token-table.md`) then match
`client.dll`'s own bytes **byte for byte**, both members, `0xA3` bytes included
— 27 of 27, no mismatches. That cross-check is what pins the *names* to the
lines. The other 7 pairs have no published name and are listed as
`Unidentified flag (line N)`; nothing about them is invented.

The first-listed member of each pair is the **locked** token. Measured for the
27 named entries (it equals the guide's "locked" column in all 27); assumed for
the other 7, and consistent with a fresh install holding the first member on
all 34 lines.

| Line | Pair | Unlockable | Line | Pair | Unlockable |
| ---: | ---: | --- | ---: | ---: | --- |
| 3 | 4 | Secret room, empty hint book, MP5 | 58 | 13 | Team Psykskallar hoodie |
| 7 | 1 | *unidentified* | 59 | 14 | Awesome suit |
| 15 | 0 | *unidentified* | 60 | 15 | Sick Simon suit |
| 22 | 3 | *unidentified* | 61 | 16 | AoM Twitcher suit |
| 39 | 5 | FAMAS with infinite ammo | 62 | 17 | Custom hoodies |
| 45 | 2 | *unidentified* | 70 | 18 | David Leatherhoff's axe |
| 47 | 32 | *unidentified* | 71 | 19 | Digital camera |
| 48 | 33 | *unidentified* | 72 | 20 | Simon's book |
| 51 | 6 | David Leatherhoff suit | 73 | 21 | Developer commentary |
| 52 | 7 | ModDB hoodie | 74 | 22 | Hidden package |
| 53 | 8 | Hello Kitty suit | 75 | 23 | Gasmask (night vision) |
| 54 | 9 | Afraid of Monsters suit | 76 | 24 | First hint page |
| 55 | 10 | Camouflage hoodie | 77 | 25 | Second hint page |
| 56 | 11 | Half Life Creations hoodie | 78 | 26 | Third hint page |
| 57 | 12 | Black Metal suit | 79 | 27 | Fourth hint page |
| | | | 80 | 28 | Fifth hint page |
| | | | 81 | 29 | *unidentified* |
| | | | 82 | 30 | Doctor mode |
| | | | 83 | 31 | Nightmare difficulty |

The tokens themselves live in `s_cofUnlockables[]` in `menus/CryOfFear.cpp`,
34 rows of `{ line, pair, name, how, locked, unlocked }`, ordered by line
number. They are the client's own bytes; a regenerating script is not needed,
but the check that produced them is reproducible from
`GAME/cryoffear/cl_dlls/client.dll` plus the canonical `scriptsettings.dat`.

**Verified against the compiler's view, too:** the 34 pairs of C string
literals in the source were decoded the way the compiler decodes them (octal
escapes included) and compared to the tokens extracted from `client.dll`. All
34 × 2 match, all are 20 bytes, and no line is missing or duplicated.

### Naming notes

* Names come from the guide, because the guide is what ties a name to a line.
  `client.dll`'s own 27 `"Unlocked: ..."` announcement strings (research
  §1.4) are a *separate* list whose order-to-line mapping was never measured,
  so they are not used as the key. Where the two disagree it is only wording:
  the guide's *Awesome suit* (line 59) is `client.dll`'s `Unlocked: Fuck Anime
  suit` — the twelve costume announcements sit in the same order as guide lines
  51–62, which is what identifies it.
* Line 3 is one flag for three things (secret room, empty hint book, MP5), per
  the guide.

### "How to unlock" — only what is measured

The conditions are still not text anywhere. `s_cofUnlockHow` (now the `how`
column of `s_cofUnlockables`) is **blank** for 28 of the 34 rows, and the six
filled rows are:

| Line | Text | Source |
| ---: | --- | --- |
| 3 | `One flag for all three; MP5 via Steam group` | the guide's note |
| 73 | `Enable it on the New Game page once unlocked` | the project's own `dev_commentary` checkbox |
| 74 | `Tied to the secret ending` | the guide names line 74 "Hidden Package (secret ending)" |
| 76–80 | `In-game hint page "<title>"` | `hl.dll`'s five measured page titles, whose order matches the guide's five hint-page lines exactly: `How To Unlock Book Pages`, `Ranking System Explained`, `How To Unlock Hoodies`, `How To Unlock Secret Items`, `How To Unlock Secret Weapons` |

Nothing reads `Finish the game`: no research supports that for any row, so the
rest are blank rather than filled with a plausible-sounding guess.

### What changed in the menu

| Place | Change |
| --- | --- |
| `menus/CryOfFear.h` | `UI_CoFUnlockablesReload()` and `UI_CoFNightmareStatus()` added; the Unlockables comment now describes a real source |
| `menus/CryOfFear.cpp` | `cofUnlockable_t s_cofUnlockables[34]` replaces `s_cofUnlockName[27]` / `s_cofUnlockHow[27]`; `UI_CoFDatLine()`, `UI_CoFUnlockablesReload()`, a real `UI_CoFUnlockableStatus()`; `CMenuCoFUnlockables::Show()` and `CMenuCoFDifficulty::Show()` re-read the file; the model gained `GetCellColors`; `cof_nightmare_unlocked` removed from the gate, from `Refresh()` and from `UI_CoFDifficulty_Precache` |

The read uses `EngFuncs::COM_LoadFile( "scriptsettings.dat", &len )` — the same
engine VFS call the library already uses for `scripts/chapterbackgrounds.txt`
and `maps/*.custom` — and `EngFuncs::COM_FreeFile`. Lines are found by
splitting on `\n` and dropping a trailing `\r`, not by striding a fixed 22
bytes, so an LF-only file still reads correctly. A line that is missing, not 20
bytes, or equal to neither token leaves that flag **unknown**; a missing file
leaves all 34 unknown rather than reporting everything locked, because an empty
or replaced file is not the same fact as a locked flag.

The file is re-read on every `Show()` of the Unlockables page and of the
difficulty page (2 KiB, so the cost is nothing), with a lazy first read as a
backstop. Nothing persists across a visit, so unlocking something in game and
returning to the menu shows the new state.

### Nightmare, and the removed cvar

`cof_nightmare_unlocked` is **gone**: not registered, not read, no replacement
override. `CMenuCoFDifficulty::StartGame` refuses `skillset 4` unless
`UI_CoFNightmareStatus() == 1`, so *unknown* is treated as locked, and
`Refresh()` grays the row and captions it. The caption distinguishes the two
non-unlocked cases:

* locked → `Nightmare has to be unlocked in game (scriptsettings.dat line 83).`
* unknown → `Nightmare state is unknown: cryoffear/scriptsettings.dat is missing or line 83 is unreadable.`

A `cof_nightmare_unlocked "1"` line left in an existing `config.cfg` is now
inert; the engine drops unknown archived names the next time it writes the
file.

### Status colours

`CMenuCoFUnlockablesModel::GetCellColors` forces the Status column only (theme
mode only): `THEME_ACCENT` for **Unlocked**, `THEME_TEXT_DIM` for **Locked**,
`THEME_DISABLED` for `?`. Every other column keeps the table's single row
colour, so the accent still means exactly one thing on the page. The
`Unlockable` / `How to unlock` split moved from 0.34 / 0.50 to 0.42 / 0.42 for
the 34-row list; `Status` stays 0.16.

### What the canonical file actually says on this machine

**All 34 flags are locked.** Every one of the 34 lines holds the first-listed
(locked) member of its pair, which is what a fresh install looks like — the
canonical copy at `K:\LLM\COF_Fix\Cry of Fear` has never been played. So the
"real state" capture below is a page of 34 `Locked` rows, and that *is* the
correct answer for this file; it is also the strongest possible check of the
token bytes, because a single wrong byte anywhere would have shown `?` on that
row.

### Evidence

Fixture `stage1/ui-m1-menu-fixture-20260921`, driven by the new `run-m3u.ps1`
(which only writes `maps/c_game_menu1_load.cfg`: `menu_cofunlockables`,
screenshot, `menu_cofdifficulty`, screenshot, `quit`). Windowed 1920x1080 with
`+volume 0`. **No input was injected.**

| File | Shows |
| --- | --- |
| `m3u-real-unlockables.png` `EED78A1F…` | the page against the canonical file: 34 rows, every visible one `Locked` in the dim colour, none `?` |
| `m3u-real-difficulty.png` `92F51E6D…` | the same file on the New Game page: the fourth row reads `Locked`, grayed, with the line-83 caption |
| `m3u-unlocked-unlockables.png` `6A6BBF9C…` | the fixture-only scratch file with lines 3, 39 and 83 set to their unlocked tokens: those rows read `Unlocked` in the accent, the rest `Locked` |
| `m3u-unlocked-difficulty.png` `4DA9DE98…` | the same file: `Nightmare` is named, not grayed, selectable, and the locked caption is gone |
| `m3u-real.log`, `m3u-unlocked.log` | the two runs |
| `canonical-manifest-m3u-before.txt`, `-after.txt` | the canonical tree unchanged |

**The scratch file was fixture-only and is restored.** Only
`stage1/ui-m1-menu-fixture-20260921/root/cryoffear/scriptsettings.dat` was
edited (lines 3, 39 and 83 rewritten in place, file length unchanged at 2 222
bytes, SHA-256 `26F56CF1…` while flipped); it is back to
`194E7144C398A7176D7BCA8543FFD4547949AC998E6F38FA38982DC7D6295F1E`, identical to
the canonical file. The canonical copy was never opened for writing:
`evidence/canonical-manifest-m3u-before.txt` and `-after.txt` are byte-identical
(6 197 files, 4 702 274 797 bytes, newest mtime
`2026-09-18T20:33:58.9860178Z`, SHA-256
`35EA26352345FA048F20ACE4D28D040A2BC616D1E919A6196F25644E5F639111`).

The fixture's `config.cfg` also lost its milestone-2 `cof_nightmare_unlocked "1"`
line, so the "real state" run starts from nothing but the file.

### Unlockables-round artefacts

**Superseded by the death-music round below**, which extends the same patch in
place; the current artefact hashes are in *Death-music-round artefacts*.

| Artefact | Bytes | SHA-256 |
| --- | ---: | --- |
| `patches/cof-mainui-source-theme.patch` | 184 165 | `C955D7C0BA45B5E45C9074730C37FFEF9E89CD63E0DB45C127FBE5709A1BBCF7` |
| `menu.dll` (`build-cof-ui-m3-20260921`) | 1 475 072 | `A1D61188612AC8245D23FF663DF4290409B13903A4354615FFBD5FA09769362D` |
| `menu.pdb` | 21 532 672 | `1F8D98D6365B469462AE97176FBA12ACDC70621233CF5F361660B687D3028471` |
| engine `xash.dll` used for both runs | 3 526 656 | `DC200932C8189C0E787CFB1750EBDC1CDC1A2CACEB7635B4078F3884D08F0786` |

Build line unchanged (`--enable-stbtt`, `WAFLOCK=.lock-waf-cof-ui-m3`). No new
cvar; one removed. `stage1/deploy-ui-m3-20260921.ps1` carries the new
`menu.dll` hash. The patch is still **41 files**, now 4 122 insertions and 160
deletions (was 3 457 / 140 at the death-flow round).

**Patch safety, re-verified.** The patch is regenerated **in place** — only the
`menus/CryOfFear.cpp` and `menus/CryOfFear.h` sections changed, every other
section is byte-identical to the previous revision — and the apply script is
untouched (its existing marker checks still cover the file). On
`cof-fix/pristine-ui-m1-scratch` over the pinned MainUI baseline plus the three
earlier MainUI patches: reverse, forward, duplicate-apply refusal. All **167**
mainui `.c`/`.cpp`/`.h` files then compared identical to the working tree
(line-ending-insensitive; the `core.autocrlf=true` caveat above still applies,
which is why the patch is generated LF-normalised).

### Still open after this round

1. **Seven flags have no name.** Lines 7, 15, 22, 45, 47, 48 and 81. Naming them
   needs a dynamic diff (toggle one thing in game, diff the file), not more
   static reading.
2. **The other 67 lines are still undecoded.** They are not boolean flags —
   `client.dll` has no paired constant for them — and most likely hold the
   profile data whose format strings sit right after the table
   (`Ending seen: %d`, `Grade: S/A/B/C/D`, `Difficulty chosen: …`).
3. **"How to unlock" is blank on 28 rows** and will stay blank until a
   condition is actually measured.
4. **Interaction is still manual**: scrolling the 34-row list, clicking
   *Open original gallery*, and starting a game on a genuinely unlocked
   Nightmare.

## Death-music round, 2026-09-22

The `GAME OVER` page now stops the death music. Cry of Fear's own
`CGameOver::setVisible` (`client.dll` VA `10040E60`) starts `game_over.mp3` on
its own MP3 player when the panel is shown; our page replaces the panel, the
panel is only gated off the screen, and its track carried on playing under it.

### What the page does

`CMenuCoFDeath` (`menus/CryOfFear.cpp`) issues the client's own console command
`stopmp3` — no arguments, unconditional stop, the same command
`CMenuLoadGame::LoadGame` and `CMenuCoFDifficulty::StartGame` already use, and a
different player from `EngFuncs::StopBackgroundTrack` — through the small helper
`StopDeathMusic()`, which is a no-op outside Cry of Fear and prints a
`Con_DPrintf` line naming the call site. It runs twice:

1. in `Show()`, and
2. once more on the **first `Think()` frame** after that, guarded by the
   one-shot `m_bStopMusicAgain` (also cleared when `Think` finds the session
   gone).

**Why `Show()` is the decisive one (measured + read from the engine source).**
`CL_CoF_DeathUserMessage()` is called from `CL_ParseUserMessage` *before* the
client DLL is handed the `VGUIMenu` message and only sets a latch; the page is
opened by `CL_CoF_DeathPump()`, which `Host_ClientFrame` calls right after
`CL_ReadPackets` (`engine/client/cl_main.c`). The client has therefore already
handled both `PlayMP3` and `VGUIMenu` — measured in that order,
`docs/cof-ui-death-flow.md` §1.1 — and started `game_over.mp3` by the time
`Show()` runs, so a single stop there is after every start.

**Why the second one exists.** A repeated `VGUIMenu` index 35 is still delivered
to the client even when the engine's latch ignores it (the latch only stops a
second page from being stacked), and the client re-shows `CGameOver` in that
case, which plays the track again. `Show()` does not run a second time for an
already-open page, so the first `Think()` frame covers a start that lands just
after the page opened. It is a one-shot, not a per-frame retry: `stopmp3` is
unconditional and nothing else on this page has music of its own to lose.

**One property of the command buffer, not of the page.** `pfnClientCmd`
(`engine/client/dll_int/cl_gameui.c:703`) appends to the command buffer, and
that buffer has a single `wait` counter shared by everything in it
(`Cbuf_ExecuteCommandsFromBuffer`, `engine/common/cmd.c:174`). In play the buffer
is empty when the player dies and the command runs on the same frame; a cfg or
an alias that is mid-`wait` delays it. This is the same fact that produced
`CL_CoF_DeathPump`, and it is why the verification below uses two runs.

### Evidence

Fixture `stage1/ui-m1-menu-fixture-20260921` with the new `menu.dll` over
`root/cryoffear/cl_dlls/menu.dll` and the shipped engine `BD90FDB9…` already in
`root/xash.dll`. Driver `run-deathmusic.ps1` (new; a thin wrapper around
`run-death.ps1`, which is itself the `run-m2.ps1` wrapper that adds the
`cof_ui_*` cvars). Windowed 1920x1080, `+volume 0`, `+load cofsave1`, the player
killed from `maps/c_forest3_load.cfg`. **No keyboard or mouse input was
injected, `SetForegroundWindow`/`AppActivate` were never called, and nothing was
retried.** Neither script ends in `quit`: a trailing `quit` sits *in front of*
the commands the page appends and would shut the host down before `stopmp3` was
reached, so both runs end by `run-m2.ps1`'s timeout instead, which loses nothing
— the engine `fflush`es the log on every line (`engine/common/sys_con.c:80`).

| Run | Shows |
| --- | --- |
| `dm1-stopmp3` (`-PageWait 450`) | the script ran out before the death message, so the page opened into an **empty** command buffer — the play case. `evidence/dm1-stopmp3.log:1114-1119`: `death screen: … -> menu_cofdeath`, `opening menu_cofdeath`, `Cry of Fear: death page (show), stopping the client MP3 player (stopmp3)`, `input gate engaged (key_dest=2)`, `Cry of Fear: death page (first think frame), …`. Its screenshot (`dm1-stopmp3-prepage.png`) is the scene *before* the page, which is what the short wait caught |
| `dm2-page` (`-PageWait 950`) | the page up and captured: `evidence/dm2-page.log:1109-1119` has the same five lines, then the script's own `COFDM-page-up` and `Write dm2-page-death.png`. `evidence/dm2-page-death.png` is `GAME OVER` with `Load Game` and `Exit` over the scene the player died in, no Cry of Fear panel and no HUD |

**The command really reaches the client.** Neither log contains
`Unknown command: stopmp3` (0 occurrences in both). That absence is meaningful
because each run also executes a deliberate control, `stopmp3_not_a_command`,
from the same cfg in the same session state, and the log answers it with
`Unknown command: stopmp3_not_a_command` (`dm1-stopmp3.log:1112`,
`dm2-page.log:1118`). `stopmp3` is a string in the shipped
`cryoffear/cl_dlls/client.dll` and in neither `hl.dll` nor the engine, so the
command is the client's own.

**Audibility is still a one-click manual test**, as it was for the Load Game and
New Game stops: `+volume 0` is on for every automated run.

### Regression check

The unlockables and difficulty pages were captured once more from the same
build, with `run-m3u.ps1 -Name m3dm-real`:

| File | Shows |
| --- | --- |
| `m3dm-real-unlockables.png` `515911C8…` | the 34-row page against the canonical `scriptsettings.dat`, every visible row `Locked`, none `?` — the same as `m3u-real-unlockables.png` |
| `m3dm-real-difficulty.png` `AD2A2C6D…` | `NEW GAME` with the fourth row grayed, named `Locked`, and the line-83 caption |
| `m3dm-real.log` | the run |

One cosmetic difference from `m3u-real-difficulty.png`: the theme's status line
at the bottom-left carries the Nightmare row's status string rather than
`Start a new game on Easy`, and that long string runs under the button row. The
status line follows the **pointer**, which rests wherever the desktop cursor
happens to be (no input is injected), so the two captures simply have the
pointer in different places; the clipping is the pre-existing full-width status
line, not a change from this round. Nothing else on either page moved.

Canonical game copy untouched across all three runs:
`evidence/canonical-manifest-m3dm-before.txt` and `-after.txt` are
byte-identical — 6 197 files, 4 702 274 797 bytes, newest mtime
`2026-09-18T20:33:58.9860178Z`.

### Death-music-round artefacts

| Artefact | Bytes | SHA-256 |
| --- | ---: | --- |
| `patches/cof-mainui-source-theme.patch` | 185 160 | `3200FC2F9CE74FAAEFFA8F34BCF0DCDEF1FF47C70DC5F76D98F28F8CD366A19B` |
| `menu.dll` (`build-cof-ui-m3-20260921`) | 1 475 584 | `6C25115CF99DAFD66CEBA6B734B40390E66D78D43875087B272ADD077604B426` |
| `menu.pdb` | 21 557 248 | `07702C47413E9F0838D4B9B9D5BE0CEDC6B541E9922F5EAB0CC119DC8142F8CF` |
| engine `xash.dll` used for both death runs | 3 511 296 | `BD90FDB994053BD6AE42E5E5C15B7A8DCAB5934389E657D5D0D3813A5C3328DE` |

Build line unchanged (`--enable-stbtt`, `WAFLOCK=.lock-waf-cof-ui-m3`, only
`--targets=menu`). No new cvar. `stage1/deploy-ui-m3-20260921.ps1` carries the
new `menu.dll` hash. The patch is still **41 files**, now 4 172 insertions and
152 deletions (was 4 122 / 160 at the unlockables round).

**Patch safety, re-verified.** The patch is regenerated **in place**: only the
`menus/CryOfFear.cpp` section changed in content. (`menus/CryOfFear.h` changed by
one character too — its single `@@` header had kept a git-style function-context
suffix that the rest of the file sections do not carry; the hunk itself is
identical.) The generator is the one the earlier revisions used: both trees read
**LF-normalised**, `difflib.unified_diff` with three lines of context,
`diff --git` headers, `new file mode 100644` plus `--- /dev/null` for `Theme.cpp`
and `Theme.h`, and no `index` lines. On
`cof-fix/pristine-ui-m1-scratch` over the pinned MainUI baseline plus the three
earlier MainUI patches: forward apply, duplicate-apply refusal, reverse (with
the scrim, menu-save and CoF-menu markers still in place afterwards), forward
again. After both forward applies all **167** mainui `.c`/`.cpp`/`.h` files
compared identical to the working tree (line-ending-insensitive; the
`core.autocrlf=true` caveat above still applies).

## Evidence index

All under `stage1/ui-m1-menu-fixture-20260921/evidence/`.

### Death-music round

| File | Shows |
| --- | --- |
| `dm1-stopmp3.log` | the page opening into an empty command buffer, both `stopmp3` issues, and the `stopmp3_not_a_command` control |
| `dm1-stopmp3-prepage.png` | the scene a few seconds before the page (the short `-PageWait`) |
| `dm2-page.log`, `dm2-page-death.png` | the same log lines and the `GAME OVER` page itself at 1920x1080 |
| `m3dm-real-unlockables.png`, `m3dm-real-difficulty.png`, `m3dm-real.log` | the unlockables and difficulty pages re-captured from the same build |
| `canonical-manifest-m3dm-before.txt`, `-after.txt` | the canonical tree unchanged |

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


## Options audit, main-list restructure, menu sounds and Skip prologue, 2026-09-22

Seven changes in one MainUI round, all Cry of Fear only, all in the same
`patches/cof-mainui-source-theme.patch` regenerated in place. `menu.dll` for
this round is in *Artefacts* at the bottom of this section.

### 1. The main list is two levels now

The main menu is exactly

    New Game, Load Game, Custom Campaign, Extras, Options, Quit

and **Extras** is no longer a page: it swaps the list in place, in the same
centred style, with the wordmark left exactly where it is, for

    Join Server, Host Server, Unlockables, Links, Back

**Links** is the old Extras page, the collection of URLs with
`Cry of Fear: Enhanced` first. **Language** left the main list entirely; the
Game options page owns it, where it already was.

How, in `menus/Main.cpp`: the list was never an array to begin with - every item
is a named `CMenuPicButton` member added once in `InitCoF` - and `VidInitCoF`
already switched between two completely different sets (main and pause) with
`SetVisibility` plus a local ordering array. The second level is one more member
(`iCoFLevel`), two more items (`cofLinks`, `cofBack`), one ordering array with
both levels in it, and `CoFSetLevel`, which repeats the four calls
`DisconnectCb` already made after it changed what the list contains:

```cpp
	VidInit( CL_IsActive( ));
	CalcPosition();
	CalcSizes();
	VidInitItems();
```

Because `VidInitCoF` recomputes every visible item's rectangle from the item's
own measured text width on every `VidInit`, and because both the mouse hit test
(`CMenuItemsHolder::MouseMove`) and the keyboard cursor
(`CMenuItemsHolder::AdjustCursor`) skip invisible items by themselves,
**keyboard navigation and mouse hit boxes follow the swapped list at every
resolution with no extra code**. `AddItem` order is the navigation order, so the
two levels are added in the order each is drawn and never interleaved. After a
swap the cursor is put on the first item of the list that is now on screen
(`SetCursorToItem`), because `AdjustCursor` wraps.

Escape on the second level is **Back**, not Quit: `CMenuMain::KeyDown` handles
it before the existing branch, and only when the main menu is showing - going in
game resets the level, so the pause list keeps its own flat behaviour.

Two console commands, `menu_cof_extras_list` and `menu_cof_main_list`, run the
same `CoFSetLevel` path, because this project may not inject the click that
would otherwise be the only way in. Same pattern as the engine's
`cof_ui_menu_panel_probe`.

### 2. Options audit: what actually does anything in this game

Cry of Fear renders through its own Paranoia OpenGL path, so several stock
Video-page controls were suspected of doing nothing. They were **measured**, not
guessed, in `stage1/ui-m1-engine-fixture-20260921` with `run-vidprobe.ps1`:
`cofsave1` on `c_forest3`, the same camera, three screenshots forty frames
apart, the cvar at two extremes, and the nine A-B frame pairs compared pixel by
pixel (percentage of pixels differing by more than 8 in any channel).

Two methodology notes, both learned the hard way and both load-bearing:

* the value must **not** go on the command line as `+set`. `config.cfg` and
  `opengl.cfg` are exec'd by `Host_Init` *after* the command line's `+set` pass,
  so an archived or `FCVAR_GLCONFIG` cvar written in either config silently won
  and both runs of a pair came out identical. The first pass measured `gamma`,
  `brightness`, `gl_gamma`, `gl_brightness`, `gl_contrast` and `gl_anisotropy`
  as having *exactly zero* effect for this reason alone. The value now goes in a
  generated cfg the command line execs, which lands in the command buffer and
  therefore runs after both configs, and every run's log prints the cvar one
  more time immediately before the screenshot;
* **the noise floor is about 13 %, not zero.** Two runs with an identical
  command line produce byte-identical screenshots (`cl_showfps 0` against
  `cl_showfps 0`: aligned differences `0.00, 0.00, 0.00`). But three null
  controls that cannot change a pixel - `cl_cmdrate` 20/60, `cl_updaterate`
  20/60 and `name` probeA/probeB - all land at **9.9 % to 13.8 %**, because the
  scene has a flickering light whose phase decorrelates as soon as anything at
  all differs between the two launches. Anything at or below ~13 % is therefore
  *no measurable effect*, not a small one.

| Control | Cvar | Aligned difference | Verdict |
| --- | --- | ---: | --- |
| (null control) | `cl_cmdrate` 20/60 | 9.9-12.9 % | the floor |
| (null control) | `cl_updaterate` 20/60 | 10.0-12.5 % | the floor |
| (null control) | `name` A/B | 9.9-11.4 % | the floor |
| Detail textures | `r_detailtextures` 0/1 | 10.5-13.5 % | **at the floor - removed** |
| Overbrights | `gl_overbright` 0/1 | 10.4-13.2 % | **at the floor - removed** |
| Use VBO | `gl_vbo` 0/1 | 9.2-9.6 % | at the floor, but it is a *performance* option and has no visual effect by design - **kept** |
| Water ripples | `r_ripple` 0/1 | 10.4-14.2 % | at the floor, but there is no water in the test scene - **kept, inconclusive** |
| Texture filtering | `gl_texture_nearest` 0/1 | **19.8-20.6 %** | works - kept |
| Auto scale HUD | `hud_scale` 0/1024 | **50.2-52.1 %** | works - kept |
| (not on the page) | `gl_anisotropy` 1/16 | 13.0-13.6 % | at the floor |
| (not on the page) | `gl_detailtex` 0/1 (the client's own) | 9.4-11.8 % | at the floor |
| Crosshair (Game page) | `crosshair` 0/1 | 11.4-13.8 % | at the floor, but this save may show no crosshair at all - **kept, inconclusive** |

Detail textures is additionally settled by the data: Cry of Fear ships **no**
`maps/<map>_detail.txt`, and its own detail-texture cvar is the client's
`gl_detailtex`, which measured at the floor too. The checkbox is gone for this
game and `r_detailtextures` is defaulted to `0` through
`UI_ThemeApplyDeferredDefaults`, the same one-shot marker
(`ui_cof_scene_defaults`) that already defaults `ui_renderworld` to `1` - so an
explicit user value in `opengl.cfg` still wins, because the marker is already
`1` by then.

Overbrights is settled by the same reading: Cry of Fear loads its own
"additional lightmaps" and lights the world inside the Paranoia path, so the
engine's overbright never reaches what you see.

#### Gamma, brightness and contrast are rebound

The client logs `gamma / brightness / contrast` into `paranoia_log.txt` from a
single format string at VA `1014C5D0`, fed from three cvars it registers itself:

| cvar | registered at | default | clamp |
| --- | --- | --- | --- |
| `gl_gamma` | `100607AB` | `1` | - |
| `gl_brightness` | `100607C5` | `0` | forced down to `0.3` at VA `1005A1C3` |
| `gl_contrast` | `100607DC` | `1` | forced down to `2.0` at VA `1005A195` |

The decisive measurement is **when** a change takes effect. Applied *before* the
level loads, the engine's own `gamma` 1.8 -> 3.0 changes 83.7 % of the frame; but
applied from the map-load hook, with the level already up - which is what
dragging a slider does - it changes only **10.5 %**, i.e. the floor. The
client's three, applied exactly the same way from the map-load hook, change
**92.2 %** (`gl_gamma` 0.4/2.0), **89.5 %** (`gl_brightness` 0/0.3) and
**60.5 %** (`gl_contrast` 0.2/2.0).

So for Cry of Fear the Gamma and Brightness sliders drive `gl_gamma` and
`gl_brightness`, a **Contrast** slider is added for `gl_contrast` (the engine
has no contrast at all and the client treats the three as one group), the slider
ranges are the clamps above, and the engine's gamma test image is not touched -
it previews an engine-side transform the Paranoia path does not perform. Every
other game keeps `gamma`/`brightness` exactly as before.

**Not touched, as instructed:** resolution, window mode, vsync and the renderer
spinner.

Game, Controls and Audio pages: nothing else was removed. Controls binds keys
through `bind`/`unbind` and has no cvars at all; Audio already hides the HEV
suit slider and the mobile vibration controls for this game; the Game page's
remaining controls are input plumbing (`m_pitch`, `in_mlook`, `lookspring`,
`lookstrafe`, `look_filter`/`m_filter`, `sv_aim`, `m_rawinput`, `sensitivity`)
plus this project's own `con_enable`, `cof_pause_menu_saves` and
`cof_subtitlelanguage`.

### 3. Localisation: no more raw `GameUI_*` keys

`L()` (`MenuStrings.cpp:75`) is a pure fallback - a key with no entry is
returned verbatim, which is why `GameUI_VSync` and `GameUI_RawInput` were
rendering as their own names. `Localize_InitLanguage` (`MenuStrings.cpp:456`)
loads `resource/<name>_<lang>.txt` in the order `gameui`, `valve`, `mainui`,
`<gamedir>`, and `Dictionary_Insert` lets the last writer win, so a file at
`cryoffear/resource/cryoffear_english.txt` overrides everything.

A full sweep of the mainui tree found 82 distinct `GameUI_*` keys used against
the 232 in the game's shipped `resource/gameui_english.txt`. Exactly four have
no entry, and the new file supplies all four:

| Key | Used by | Now reads |
| --- | --- | --- |
| `GameUI_VSync` | Video page | Vertical sync |
| `GameUI_RawInput` | Game page | Raw mouse input |
| `GameUI_RawInputLabel` | Game page status line | Take the mouse straight from the device, bypassing the operating system's pointer acceleration |
| `GameUI_PlayGame_Alt` | `menus/NewGame.cpp`, not reachable on a CoF page | Start |

The file is `gamedata/cryoffear/resource/cryoffear_english.txt`, Valve VDF, UTF-8
without a BOM. The parser (`MenuStrings.cpp:385`) reads the header through
`COM_ParseFile`, which skips `//` comments, so the explanatory header at the top
is safe.

### 4. Menu sounds

The engine menu was silent in this game. `uiSounds` (`BaseMenu.cpp:48`) names
seven Half-Life files under `media/`, `UI_LoadSounds` rewrites a missing one to
`sound/common/`, and **none of the fourteen resulting paths exists**: a sweep of
the canonical read-only copy finds no `launch_*`, no `buttons/blip*`, no `valve`
directory and no PAK anywhere in the tree. `FS_LoadSound` failed for every one
and `S_LoadSound` substituted a second of silence.

`uiSoundsCoF` supplies the game's own, gated on `UI_IsCryOfFear()` so every
other game keeps the stock names untouched:

| Slot | File | What plays it |
| --- | --- | --- |
| `SND_IN` | `ui/3d_click.wav` | (mainui never uses this slot) |
| `SND_OUT` | `ui/buttonclickrelease.wav` | a window closing |
| `SND_LAUNCH` | `ui/3d_click.wav` | every pic button, action and close button |
| `SND_ROLLOVER` | `ui/3d_rollover.wav` | (mainui never uses this slot) |
| `SND_GLOW` | `ui/buttonclick.wav` | checkbox and switch toggles |
| `SND_BUZZ` | `common/wpn_denyselect.wav` | slider/spinner/table at the end of range, rejected bind |
| `SND_KEY` | `ui/buttonclick.wav` | slider step, entering key-grab mode |
| `SND_REMOVEKEY` | `common/wpn_denyselect.wav` | key unbound |
| `SND_MOVE` | `ui/3d_rollover.wav` | keyboard cursor moved, mouse entered a new item |
| `SND_NULL` | (silent) | deliberate silence on a table mouse-drag |

All six files exist (`cryoffear/sound/ui/` and `cryoffear/sound/common/`).
`UI_LoadSounds` also had to stop discarding a name whose `FileExists` probe
fails: `FS_LoadSound` tries `sound/<name>` before `<name>`
(`engine/client/soundlib/snd_main.c`), and these names are relative to `sound/`.

**This cannot trigger the gallery MAIN MENU hook.** `CL_CoF_MenuPanelSound` has
exactly one caller in the whole engine - `pfnPlaySoundByName` in
`engine/client/dll_int/cl_game.c`, the *client DLL's* callback. The menu goes
through `EngFuncs::PlayLocalSound` -> `pfnPlaySound` (`cl_gameui.c:721`) ->
`S_StartLocalSound` at `VOL_NORM`, a different function entirely; the hook only
answers to volume `0.5` and additionally requires `cls.state == ca_active` and
`cl_background 0`, neither of which holds for the menu over the background map.
Three independent reasons, all read in the engine sources.

Audibility is manual. What the log proves is the resolution, one line per slot:
`Cry of Fear menu sound 0: "ui/3d_click.wav"` through
`Cry of Fear menu sound 9: ""`, with no sound-loading error anywhere in the run.

### 5. Skip prologue

An archived cvar `cof_skip_prologue` (default `0`) and a checkbox on the New
Game page, shown only for the main campaign - a custom campaign starts at its
own first map and has no prologue to skip.

The target map is **`c_nightmare`**, and that was measured, not assumed:

* `c_intro` has exactly one `trigger_changelevel`: brush `*141`, `"map"
  "c_nightmare"`, landmark `landakukej` (`info_landmark` at `212 -408 -2523`);
  the player is teleported into it by `cof_teleport` `kunitei2` about 185 s in;
* all ten of `c_intro`'s `trigger_camera` entities carry `spawnflags 116`, which
  includes `SF_CAMERA_PLAYER_TAKECONTROL`: the player never has control on that
  map;
* a classname census of `c_intro` returns **zero** `game_player_equip`,
  `weapon_*`, `item_*`, `cof_giveitems`, `cof_clearitems`, `env_global`,
  `cof_chapter`, `cof_begingame` and `trigger_auto`. It grants nothing and sets
  nothing; its only effect outside itself is the level change;
* `c_nightmare`'s worldspawn has `"newunit" "1"`, so the engine wipes the save
  transition directory on entry - it is a clean unit boundary by design - and
  its **first** `info_player_start` (`211 -412 -2545`) is exactly the landmark
  arrival point, inside the `trigger_once` that starts its own opening sequence;
* `c_nightmare` carries the main campaign's **only** `cof_begingame` (`"begin"`,
  fired at t=0 of its `nightmulti`; there are ten in all 235 maps and this is
  the one in the campaign) and grants `weapon_camera` through `cof_giveitems`
  `kakkaej`. Starting one map later, at `c_start`, would skip both - which is
  why `c_start` is the wrong answer even though it is the first map with a
  chapter card.

Difficulty survives the map change by itself. `difficulty` is an engine cvar
registered by the game DLL with `FCVAR_ARCHIVE|FCVAR_SERVER` (`hl.dll` `cvar_t`
at `10214750`, default `"2"`); `skillset` writes it synchronously with
`pfnCVarSetFloat` (VA `10019E09` / `10019E47`) and writes nothing else that
outlives the map; `RefreshSkillData` (VA `100AF810`) re-reads it from the cvar on
every level load through `CWorld::Precache` -> `InstallGameRules`.

But `skillset` also arms a five-second player think (VA `100DFC10`) that issues
`map <campaign>` or, with no campaign set, **`map c_intro`**. So the skip is not
spelled as our own `map` command on top of `skillset` - that think would load
`c_intro` five seconds later. It is spelled as the game's own `campaign`
override, which is exactly what the shipped difficulty panel uses
(`"campaign %s"` at `client.dll` `10147744`):

```
cmd campaign c_nightmare
cmd skillset <N>
```

so the authentic white fade, `inventory/game_start.wav` and the difficulty write
all still happen and only the destination differs. With no server to forward to
(right after Quit to menu), the existing fallback sets `difficulty` and issues
`map <target>` directly, as before.

**Measured** (`stage1/ui-m1-menu-fixture-20260921/evidence/sp-skip2.log`): from
the background map, `cmd campaign c_nightmare` then `cmd skillset 2` gives
`GAME SKILL LEVEL:2`, then `Spawn Server: c_nightmare`, then `GAME SKILL LEVEL:2`
again on the new map.

### 6. Credits

A **Credits** entry joins the Extras sub-list, which is now

    Join Server, Host Server, Unlockables, Links, Credits, Back

`CMenuCoFCredits` (`menus/CryOfFear.cpp`) is a centred theme panel titled
CREDITS with three sections. Each section is a small uppercase label, one or
more body lines (the last of each of the first two dim), and a link button that
hands its URL to the system browser through `EngFuncs::ShellExecute`, the same
route the Links page uses:

| Section | Body | Link |
| --- | --- | --- |
| TEAM PSYKSKALLAR | Andreas "ruMpel" Ronnberg and James "Minuit" Marchant / *Creators of Cry of Fear* | YouTube -> `https://www.youtube.com/@TeamPsykskallar` |
| CRY OF FEAR: ENHANCED | haej / *Community-driven* | Project site -> `https://cofenhanced.haej.pl` |
| CRY OF FEAR SPOLSZCZENIE (POLISH LOCALISATION) | Avioo, Mixdedemon, hexag0n, Izonka with their roles | Steam Workshop -> `https://steamcommunity.com/sharedfiles/filedetails/?id=3164091802` |

(The table above spells the two accented letters plainly; the shipped strings
carry the real characters.)

Layout: one column, 640x470 in the 1024x768 virtual space, the section pitch
derived from the content rect rather than hard-coded, so it follows the panel at
every resolution. Two details were fixed by looking at the first screenshots
rather than by guessing:

* the three link buttons share **one measured width**, taken from the longest
  label through `g_FontMgr->GetTextWideScaled( uiStatic.hThemeBody, ... )`.
  `THEME_BTN_MIN_W` is 110 virtual units and both "Project site" and "Steam
  Workshop" are wider, so at the fixed width they clipped to `Project ...` and
  `Steam ...`;
* only the body line the button sits **beside** (the section's last) gives up
  width for it. With every line shortened, the first section's long line clipped
  to `Andreas "ruMpel" Ronnberg and James "Minuit" M...`.

**Non-ASCII, measured, not assumed.** The strings carry `o`-diaeresis and
`l`-stroke as UTF-8 in the source. The theme's primary font backend is
stb_truetype over the shipped Inter faces (`--enable-stbtt`), which rasterises
by code point, and both letters render correctly at both resolutions -
`Roennberg` and `Tlumaczenie` appear with their real glyphs in
`mz-1920-c-credits.png` and `mz-1280-c-credits.png`. At 1280x720 the whole panel
fits with no scrolling, which was the tight case.

### Artefacts

| Artefact | Bytes | SHA-256 |
| --- | ---: | --- |
| `patches/cof-mainui-source-theme.patch` | 216 361 | `9B04F63EA64F757404ADDD1F8EE5B304D3B0B7F79217F0E1E5BD14051562F24F` |
| `menu.dll` (`build-cof-ui-m3-20260921`) | 1 484 800 | `3B5569D5FD2DB95FA436952860FAE8FF9FE05BD47CC434A11821FC62B37F9EC2` |
| engine `xash.dll` used for these runs | 3 519 488 | `06F1D1159320761FBF1C09770DD61A152D04F01D24E5A14E3379BBF0B7AF7E1B` |

Build line unchanged (`--enable-stbtt`, `WAFLOCK=.lock-waf-cof-ui-m3`).

**Patch safety, re-verified.** The patch is regenerated **in place** and is
still 41 files - the same file set as the committed version, compared name by
name. On `cof-fix/pristine-ui-m1-scratch` over the pinned MainUI baseline plus
the three earlier MainUI patches: reverse the old patch to get back to that
baseline, forward-apply the new one, duplicate-apply refusal, all **187** mainui
files then compared identical to the working tree (line-ending-insensitive),
then reverse and forward again. The patch is generated LF-normalised, for the
`core.autocrlf=true` reason described earlier in this document.

### Evidence

`stage1/ui-m1-menu-fixture-20260921/evidence/`, engine `06F1D115...`:

| File | Shows |
| --- | --- |
| `mz-1920-a-main.png`, `mz-1280-a-main.png` | the restructured main list at 1080p and 720p, and the `cofenhanced` stamp in the corner |
| `mz-1920-b-extras.png`, `mz-1280-b-extras.png` | the Extras second level in place, wordmark unmoved, with Credits in the list |
| `mz-1920-c-credits.png`, `mz-1280-c-credits.png` | the Credits panel, three sections, all three link labels complete, the accented letters rendered |
| `mn-1920-c-back.png`, `mn-1280-c-back.png` | back on the main list after `menu_cof_main_list` (earlier round, before Credits) |
| `mz-1920-d-video.png`, `mz-1280-d-video.png` | the Video page: Gamma/Brightness/Contrast, `Vertical sync` localised, no Detail textures and no Overbrights |
| `mz-1920-e-newgame.png`, `mz-1280-e-newgame.png` | the New Game page with `Skip prologue` |
| `mz-1920-f-game.png`, `mz-1280-f-game.png` | the Game page with `Raw mouse input` localised and Subtitle language |
| `mn-1920-g-audio.png`, `mn-1280-g-audio.png` | the Audio page |
| `mm-1920.log` | the ten `Cry of Fear menu sound N:` lines and the cvar readback |
| `mm-defaults.log` | `r_detailtextures defaulted to 0` firing once, and `opengl.cfg` coming back with `r_detailtextures "0"` |
| `mm-userchoice.log` | the same build with the marker already `1` and the user value `1`: no `defaulted to` line, the value stays `1` |
| `sp-skip2.log` | `campaign c_nightmare` + `skillset 2` -> `Spawn Server: c_nightmare`, `GAME SKILL LEVEL:2` |

The video-option measurements are in
`stage1/ui-m1-engine-fixture-20260921/evidence/` as the `vq-*` runs, with
`run-vidprobe.ps1` as the driver.

## Menu sounds volume and the deferred-defaults generation, 2026-09-22

The user: *the CoF menu sounds are too loud.* The engine side of the fix - the
archived `ui_sound_volume` cvar, where it is applied and why - is
[its own document](cof-ui-sound-volume.md) and its own patch
(`patches/cof-ui-sound-volume.patch`). Three things changed in the menu, all in
`patches/cof-mainui-source-theme.patch`, regenerated in place.

### 1. A "Menu sounds" slider on the Audio page

`menus/Audio.cpp`: a third slider under *Sound effects volume* and *MP3 volume*,
`0 … 1` in steps of `0.05`, `LinkCvar( "ui_sound_volume" )`, status line
*Volume of the menu's own button and rollover sounds*. It writes on change and
again in `SaveAndPopMenu` (skipped when hidden), exactly like its neighbours.

**Theme mode only.** The WON layout is a grid of fixed coordinates and adding a
row to it would move controls that `ui_theme 0` promises to leave byte for byte
as upstream has them, so the item is added but `SetVisibility( UI_ThemeActive() )`
hides it there. In the panel layout it takes the next `THEME_CTRL_PITCH` slot in
the left column; the panel is unchanged at 640x460 and still fits four sliders,
which is the non-Cry-of-Fear case where the HEV suit slider is also visible.

`evidence/sv2-1920-audio.png` `0400A208…`.

### 2. `ui_cof_scene_defaults` is a generation number now

`UI_ThemeApplyDeferredDefaults()` (`Theme.cpp`) used the archived marker as a
boolean: zero meant *apply the defaults*, anything else meant *the user's
choices stand*. That made it a one-way door - every installation that had run an
older build already had `ui_cof_scene_defaults "1"`, so a newly added default
could never reach it.

The marker is now the **generation** of the last set of defaults that was
offered, and `COF_SCENE_DEFAULTS_GEN` (currently `2`) is what this build knows:

| Generation | Applied |
| ---: | --- |
| 1 | `ui_renderworld 1` (the paused scene through the scrim) and `r_detailtextures 0` |
| 2 | `ui_sound_volume 0.5` |

`UI_ThemeApplyDeferredDefaults` applies only the steps between the recorded
generation and `COF_SCENE_DEFAULTS_GEN`, then writes the new number. A user who
already has `1` therefore gets the quieter menu sounds once and keeps whatever
they decided about `ui_renderworld` and `r_detailtextures`; a fresh install gets
all three. Raising the number is the whole procedure for adding the next one.

**Measured** (`stage1/ui-m1-menu-fixture-20260921/evidence/`): with the fixture
`config.cfg` at `ui_cof_scene_defaults "1"`, `sv2-1920.log:756` prints
`Cry of Fear: ui_sound_volume defaulted to 0.5 (the game's own UI sounds are
loud)` and nothing about `ui_renderworld` or `r_detailtextures`, and the file
comes back with `ui_cof_scene_defaults "2"` and `ui_sound_volume "0.500000"`.
Run again with the marker at `2`, `sv2-control.log` has no `defaulted to` line
at all and a value the cfg set by hand survives.

### 3. Two more cfg-only hooks

Same reason and same pattern as `menu_cof_extras_list` / `menu_cof_main_list`:
the real way in is a click this project may not inject.

| Command | Runs |
| --- | --- |
| `menu_cof_quit_to_menu` | `CMenuMain::DisconnectCb`, i.e. Quit to menu plus its confirmation, for the disconnect-return validation in [the redirect document](cof-ui-menu-map-redirect.md#disconnect-re-arms-the-background-map-too-2026-09-22) |
| `menu_cof_sound_probe [slot]` | `EngFuncs::PlayLocalSound( uiStatic.sounds[slot] )`, default `SND_LAUNCH` - one menu sound through the very call every control uses, so a cfg can prove the volume the mixer is handed |

### Artefacts

| Artefact | Bytes | SHA-256 |
| --- | ---: | --- |
| `patches/cof-mainui-source-theme.patch` | 228 657 | `BCEE87E6800DE153011A0DC6558D0B04150244CF9F771F5E58AE4A951A2CE8B7` |
| `menu.dll` (`build-cof-ui-m3-20260921`) | 1 485 824 | `F7E46B3A2A472AFED3167E78D2D575EC58A631AF344FE6789A344346F0A569DF` |
| engine `xash.dll` used for these runs | 3 520 000 | `1C25CE6BF17EB3C7A70931CD6D00D9296917B41F756CDA6FFD4E603ECF197C13` |

Build line unchanged (`--enable-stbtt`, `WAFLOCK=.lock-waf-cof-ui-m3`).

**Patch safety, re-verified.** Regenerated in place, still **41 files**, the same
file set as before. On `cof-fix/pristine-ui-m1-scratch` over the pinned MainUI
baseline plus the three earlier MainUI patches: reverse the old patch to reach
that baseline, generate the new one against it, round-trip it in a scratch copy
(forward, byte-identical, reverse check), then run the apply script itself
through reverse → forward → duplicate-apply refusal on the scratch tree. All
mainui files there then compare identical to the working tree
(line-ending-insensitive). The patch is generated LF-normalised, for the
`core.autocrlf=true` reason described earlier in this document.

### Evidence

| File | Shows |
| --- | --- |
| `sv2-1920.log`, `sv2-1920-audio.png` | the deferred default firing once, the four `[cof-ui] menu sound … volume 0.50` lines, and the Audio page with the new slider at half travel |
| `sv2-control.log` | the marker already at `2`: no re-default, and `volume 0.50 / 1.00 / 0.25` tracking the cvar |
| `dm1-console-disconnect*`, `dm2-quit-to-menu*`, `dm3-control-off*`, `dm4-redirect-latch*` | the disconnect-return cases, which also exercise `menu_cof_quit_to_menu` |
