# The engine HUD text, made readable (`cof_hud_text_font`, `cof_hud_text_backing`)

Unified UI milestone 4b, the text half. The scaling half is
[the in-game UI scaled from the display](cof-ui-m4-scaling.md) and the VGUI font
half is [the client's VGUI text rasterised from Inter](cof-vgui-inter-fonts.md);
this patch sits on top of both.

The user's report was three things in one sentence: the cutscene subtitles, the
pickup notifications ("You got the Lantern", "Picked up a glock magazine with
15 rounds") and the yellow `SIMON:` / `MAN:` dialogue lines are **placed too
high** and **too light to read**. One of those turned out not to be true, and
finding out which took a full static reconstruction of the client's own layout
plus a runtime probe. Both are below.

## 1. Where this text actually comes from

`pfnDrawCharacter( x, y, ch, r, g, b )` (engfunc slot 26, client engfuncs table
at `101B2670`) has **exactly four** call sites in `client.dll`:

| VA | inside | what it draws |
| --- | --- | --- |
| `1007E272` | `CHudMessage::MessageDrawScan` (`1007E0A0`) | the main per-character pass |
| `1007E3E9` | `CHudMessage::MessageScanNextChar` (`1007E2D0`) | the `effect == 1` second pass, same x/y |
| `100723E8` | `DrawHudString` (`100723B0`) | "Using Gas Mask", "Using Head Shield", `CHudMenu::Draw` |
| `10072455` | `DrawHudStringReverse` (`10072410`) | the pickup-history counter, bottom right |

`CHudMessage::Draw` (`1007DA00`) itself never calls it - its own first block is
the `GameTitle` sprite. Characters are emitted one level down.

**The pickup notifications are not on this path at all.** `"You got the %s"`
(`1014EEE8`) is built at `100702C0` in the client's `Inventory` message handler
and copied into `gViewPort[0x142C] + 0xD4`, which is the FreeVGUI `CHUDControl`
message strip; `"Picked up a %s magazine with %i rounds"` is not in `client.dll`
at all - it is in `hl.dll` at `101DBBB8`, sent as the `ProFont` user message
(`RegUserMsg("ProFont")` at `100E63A8`), and the client's hook `100712A0` copies
it into **the same** panel. Both are therefore VGUI, scaled by `cof_ui_scale`
and rendered with the Inter substitution, not with `cls.creditsFont`.

Subtitles are a fork in the road: `MessageAdd` (`1007DEA0`) routes a message to
`CSubtitle` (`gViewPort+0x140C`) only on the branch at `1007DFB8` that requires
`pfnTextMessageGet` to *find* the name in `titles.txt` **and** that entry to
carry `$effect 3`. The shipped `cryoffear/titles.txt` is the stock Half-Life
file and has **zero** `$effect 3` entries, so with the shipped data that route
is dead and a subtitle sent as `HudText` falls through to the synthetic path in
section 2, which *is* `pfnDrawCharacter`.

## 2. The y formula, and why the font size cannot move it

`CHudMessage::YPosition` is at `1007E790` and is bit-for-bit stock Half-Life:

```
y == -1  ->  ( ScreenHeight - height ) * 0.5          centred
y <  0   ->  ( 1.0 + y ) * ScreenHeight - height      bottom aligned
y >= 0   ->  ScreenHeight * y                         absolute fraction
```

`height` is `lineCount * iCharHeight` (`1007E135: imul ecx, [1018F43C]`), and
`1018F43C` - `gHUD.m_scrinfo.iCharHeight`, which is where the engine's HUD font
size arrives - is referenced in **only two instructions in the whole client**:
that multiply, and the `+= iCharHeight` line advance at `1007E28D`.

Cry of Fear does not use `titles.txt` for its own messages. `MessageAdd` bails
for a `!`-prefixed name it cannot resolve and otherwise fills a hardcoded
`client_textmessage_t` at `10543C68` from the 16 bytes at `10150440`:

| offset | dword | value | field |
| --- | --- | --- | --- |
| `10150440` | `BF800000` | **-1.0** | `x` - horizontally centred |
| `10150444` | `3F333333` | **0.699999988** | **`y`** |
| `10150448` | `3C23D70A` | 0.01 | `fadein` |
| `1015044C` | `3FC00000` | 1.5 | `fadeout` |

`y = 0.7` is positive, so `YPosition` takes the third branch and **`height` is
not used at all**. The first line of every such message lands at exactly
`0.70 * ScreenHeight` whatever `iCharHeight` is; only lines 2..N move, downward,
by `(iCharHeight - 19)` each.

**Measured at runtime**, `cof_hud_text_trace 1` with the new
`cof_hud_text_probe` (section 5), same message, HUD scale 150 %:

| render size | `iCharHeight` | logged line y | fraction |
| --- | ---: | ---: | ---: |
| 1920x1080 | 29 px | `y=756` | **70.00 %** |
| 2560x1440 | 38 px | `y=1008` | **70.00 %** |

70 % of the screen height **is** the lower third the user remembers, and it did
not move. So `cof_hud_text_height_pct` is exonerated: the placement complaint
belongs to the VGUI surfaces above, whose panels the client centres itself (the
measured panel tree in `cof-ui-m4-scaling.md` puts the `CHUDControl` message
strip at exactly half the screen height, which is where it has always been).

### The offset, and why its default is 0

    y += render_height * cof_hud_text_y / 100
       + ( charHeight - shippedHeight ) * cof_hud_text_y_shift

`cof_hud_text_y_shift` is the general form of the correction: how many glyph
heights per line the client's own formula takes off its anchor. It is `0.5` for
the centred branch, `1.0` for the bottom-aligned one and **`0` for the branch
Cry of Fear actually uses**, which is why `0` is the default - measured, not
assumed. `cof_hud_text_y` is then a plain user offset in percent of the render
height, for a player who wants the line lower anyway. Verified live:
`cof_hud_text_y 3` moved the logged line from `y=756` to `y=788` at 1080p
(+32 px = 3.0 %) and from `y=1008` to `y=1051` at 1440p (+43 px = 3.0 %).

## 3. Legibility: a heavier face

`cls.creditsFont` loads `gfx/creditsfont.fnt`, a thin aliased one-size bitmap.
The milestone 4 sizing then *magnifies* it - 1.5x at 1080p with the HUD scale
at 150 %, 2x at 1440p - and a magnified 19 px bitmap stem is exactly the "too
light" the user saw.

`cof_hud_text_font 1` (default) replaces it with an atlas generated from the
**Inter SemiBold** face the project already ships, by the same
`scripts/make-cof-console-font.py` the console atlases come from:

```powershell
python scripts/make-cof-console-font.py `
    --ttf gamedata/cryoffear/gfx/fonts/Inter-SemiBold.ttf `
    --out gamedata/cryoffear/fonts --name cof_hudtext --sizes 14,19
```

**Two sizes, and no more.** The `.fnt` container addresses a glyph with a
16-bit linear pixel offset, so the whole atlas has to fit in 65536 pixels; at a
24 px base the generator already drops 21 of the 216 cp1252 glyphs and at 36 px
it drops 137. The language packs need that upper range, so the base heights
stop at 19 px and larger displays magnify an antialiased master instead of an
aliased one. The console keeps Inter **Regular** - `cof_console*.fnt` is
untouched.

`SCR_LoadCreditsFont` loads the game's own font first, keeps its height as
`shipped`, and only then tries the atlas whose base is the largest at or below
the target, into a scratch `cl_font_t`: a missing or corrupt atlas leaves the
stock font exactly as it was. `SCR_ScaleCreditsFont` then brings whichever font
is in play to

    target = render_height * cof_hud_text_height_pct / 100
             * hud_fontscale * cof_ui_scale_user,   floored at `shipped`

which is the same law as milestone 4; the floor used to be expressed as "glyph
scale never below 1" and had to be restated in pixels, because with a generated
atlas the base height is 14 or 19 px rather than the shipped size.

## 4. Legibility: a backing strip

A translucent black strip behind each line, the same shape the menu's own GAME
OVER page uses (`UI_ThemeDeathBacking`). `cof_hud_text_backing` is its alpha,
default `120`, `0` = off.

**It cannot be drawn when the line starts.** A line's extent is only known once
its last glyph has been emitted, and by then a strip would paint over the text.
So `pfnDrawCharacter` does not draw: it **collects**, into a per-frame list
grouped by baseline y, and `CL_CoF_HudTextFlush` - the last thing `CL_DrawHUD`
does - draws one strip per group and then that group's glyphs over it. Padding
is `charHeight/2` horizontally and `charHeight/6` vertically, so it follows the
display the way the rest of milestone 4 does.

Two deliberate exclusions from the collector: **UTF-8 mode** (`hud_utf8 1`),
because `Con_UtfProcessChar` is a state machine over the byte stream and
resolving a glyph twice would decode the sequence twice - the Cry of Fear text
pipeline is 8-bit, which is what `cof_text_codepage` exists for - and **tab
stops**, whose advance depends on the pen position at draw time. Both fall
through to the direct draw.

**Draw order.** The flush is the last thing in `CL_DrawHUD`, so this text ends
up above the rest of the client's HUD instead of wherever in `pfnRedraw`'s own
sequence it happened to be emitted. That is the intended order for overlay text
and the only order in which a backing strip can work. It changes nothing for
the VGUI layer, which the engine paints in a separate pass, so **the boss bar,
the inventory and every other client panel are untouched**.

### The same strip for the notes and document reader

By the user's follow-up request, the VGUI notes/pager text gets the same
treatment, at the same alpha and padding. The engine decides *which* role gets
one - `CL_CoF_FontDesc` fills the new `backing` field of `cof_vgui_font_t`, and
only for the `pager` role - so there is exactly one place in the codebase that
answers "does this text get a strip", and no other client label, the boss bar
and the inventory included, can grow one by accident.

The support library needs the same deferral for the same reason, and one worse:
`TextImage`, the layout path behind every client label, calls `drawPrintText`
**once per character**, so nothing smaller than a whole panel could group a
line. `XashSurface::drawPrintText` collects instead of drawing when the current
font's role has a backing alpha, and `flushBackingText` runs from
`popMakeCurrent` - the last moment the drawing panel's translate and scissor are
still current, so the strip and the glyphs are clipped exactly alike - plus once
at the end of the paint pass, for the `cof_font_probe` string, which draws
outside any push/pop pair.

`CofFont_Backing` asks the engine on every call rather than reading the value
the font was cached with: the client builds its fonts once per level load, and
`cof_hud_text_backing` has to be live the way its engine-side twin is.

## 5. Cvars and the test hooks

| cvar | default | flags | meaning |
| --- | --- | --- | --- |
| `cof_hud_text_font` | `1` | `FCVAR_ARCHIVE` | draw the engine HUD text from `fonts/cof_hudtext*.fnt` (Inter SemiBold) instead of the game's `gfx/creditsfont.fnt` |
| `cof_hud_text_backing` | `120` | `FCVAR_ARCHIVE` | alpha 0-255 of the strip behind each line of engine HUD text, and behind the notes/pager text |
| `cof_hud_text_y` | `0` | `FCVAR_ARCHIVE` | extra vertical offset, in percent of the render height |
| `cof_hud_text_y_shift` | `0` | â€” | the per-line-height correction; measured 0 for this game, see section 2 |
| `cof_hud_text_trace` | `0` | â€” | developer: log every collected line with its y, its fraction of the screen, its extent and its colour |

Two commands, both cfg-only test hooks, because neither path had a repeatable
test before:

* **`cof_hud_text_probe "<text>"`** sends the client one `HudText` message
  through the engine's own `CL_HudMessage()` - the same call the
  `TE_TEXTMESSAGE` temp entity uses - so `CHudMessage` runs its real layout and
  what lands on screen is the real thing. `impulse 101` emits no such message
  (measured, `stage1/ui-m4-scaling-20260922`) and a real pickup needs walking to
  an item, which this project may not do.
* **`cof_font_probe "pager <text>"`**, from the font patch, is how the VGUI
  backing is checked without a note in the inventory.

## 6. Evidence

`stage1/ui-m4b-fixture-20260922`, 1920x1080 and 2560x1440, windowed, from the
user's own `config.cfg` (HUD scale 150 %, which is what they play with).

| run | what it shows |
| --- | --- |
| `h1-before-1080-b.png` | `cof_hud_text_font 0`, `cof_hud_text_backing 0`: the stock thin grey line over the forest floor, barely legible |
| `h2-after-1080-b.png` | the defaults: Inter SemiBold on a translucent strip, same position |
| `h5-before-1440-b.png` / `h3-after-1440-b.png` | the same pair at 2560x1440, where the stock font is magnified 2x and falls apart |
| `d3-live.log` / `d4-control.log` / `d5-page-b.png` / `f1-final.log` | the death-page half, see [the death flow](cof-ui-death-flow.md) section 8.3 |
| `h4-trace-1080.log` / `h4-trace-1440.log` | the y trace quoted in section 2, including the `cof_hud_text_y 3` step |
| `p4-pager-a-nobacking.png` / `p4-pager-b-backing.png` | the pager role at `cof_hud_text_backing` 0 and 120 |

## 7. Applying

After the whole milestone 4 stack:

```powershell
pwsh -File .\scripts\apply-cof-hud-text-backing.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
python waf build -j8 --targets=xash,vgui
```

The script refuses a tree that already carries the change, checks
`cof-ui-scale` and `cof-vgui-inter-fonts` by marker, verifies concrete markers
in every touched file afterwards, and takes `-Reverse`. The generated atlases
`gamedata/cryoffear/fonts/cof_hudtext{0,1}.fnt` ship with it and have to be
deployed into `cryoffear/fonts/`.

## 8. Known limits

* The **placement** complaint is not about the engine text path, which was
  never displaced (section 2). The text the user photographed belongs to the
  client's own `CHUDControl` message Label, and **section 9 fixes that** -
  milestone 4c, `cof_hud_msg_y_pct`.
* The subtitle route depends on `titles.txt`: with the shipped stock file a
  subtitle sent as `HudText` is drawn by this path and gets the new font and
  the strip; a language pack that ships a `titles.txt` with `$effect 3` entries
  would move it to `CSubtitle` and out of this patch's reach.
* The atlas covers the 216 printable cp1252 bytes. A code page whose upper
  range differs (1250, 1251) needs its own atlas; the engine HUD font has no
  `cof_text_codepage` equivalent yet, unlike the VGUI fonts.

---

## 9. The in-game message text (`cof_hud_msg_y_pct`), milestone 4c

Section 8's "the placement complaint cannot be fixed by this patch" was right
about the engine text path and wrong about what the user was looking at. The
text they photographed Ã¢â‚¬â€ the item pickups and the yellow `SIMON:` / `MAN:`
cutscene dialogue Ã¢â‚¬â€ is **one VGUI panel**, and it is neither `CHudMessage` nor
`CSubtitle`.

### 9.1 What it is

| piece | where |
| --- | --- |
| the panel | `CHUDControl` (`gViewPort+0x142C`, ctor `100362B0`) Ã¢â‚¬â€ its child **`Label` at `+0x3A8`**, constructed at `10037CA9` as `Label(" ", 0, 0, ScreenWidth, 64)` with `setContentAlignment( a_center )` |
| its font | `CHUDControl+0xF54`, taken in the constructor at `100366B9` from `CSchemeManager::getSchemeHandle( "credits" )` Ã¢â‚¬â€ so the engine's role for it is **`credits`** |
| the string | `CHUDControl+0xD4`, a 257-byte buffer |
| writer 1, client side | `100702C0` inside the `Inventory` handler `1006FF40`: `sprintf( "You got the %s" )`, colour byte `5` |
| writer 2, server side | hl.dll formats `"Picked up a %s magazine with %i rounds"` (`101DBBB8`) and sends the **`ProFont`** user message (`10119810`: `WriteByte(colour)` + `WriteString(text)`); the client's hook `100712A0` reads exactly one byte and one string and copies it into the same buffer |
| its position | rewritten **every frame while the string is non-empty** (`1003BA40`): `setPos( 0, ScreenHeight - 3*G )`, `setSize( ScreenWidth, 64 )`, where `G = round( ScreenHeight/480 * 25 )` is the cinematic-bar unit computed once at `10037B31` |
| its lifetime | a fade state machine on `+0xF18` / `+0xF1C` / `+0xF20`: about 0.5 s in, 4 s hold, 0.5 s out, then the buffer is cleared at `1003B8C7` |

**`CHUDControl` paints none of this itself.** Its `paintBorder` helper
`1003B0C0` only moves and re-texts child panels; its one `drawPrintText` prints
the literal `"Butts"` behind a debug flag at `10542BB4` that is always 0. The
forty-odd other things on `CHUDControl` Ã¢â‚¬â€ the health and stamina bars, the
vignette, the hint bar, the SMS icon, the letterbox strips, the timer Ã¢â‚¬â€ are all
**siblings with their own bounds**, which is why moving this text cannot move
them.

**`CSubtitle` is not involved.** It lives at `gViewPort+0x140C`, builds its font
from `"Default Text"` (or from a `@<scheme>` token at the head of the line,
`100A2940`), and is reachable only from the `$effect 3` branch of
`CHudMessage::MessageAdd` (`1007DFC0`) Ã¢â‚¬â€ which needs a `titles.txt` entry with
`$effect 3`, and the shipped `cryoffear/titles.txt` is the stock Half-Life file
with none. So with the shipped data the dialogue the player sees is the Label
above, which is exactly what the trace shows.

### 9.2 Why it was in the wrong place

The panel's own position is a stable `ScreenHeight - 3*G`, about 84.4 % of the
*layout* height, at every resolution. What is not stable is what the milestone 4
surface transform does to it: the panel is 64 px tall near the bottom of the
layout, so the anchor pass anchors it **high** (to the bottom edge), and
`device = ( layout + ( screen/scale - layout )) * scale` then lands the text
wherever the scale happens to put it. Measured with `cof_hud_text_trace`, at the
HUD scale the user plays with (`cof_ui_scale_user 1.5`):

| render size | scale | layout y of the text | device y | fraction |
| --- | ---: | ---: | ---: | ---: |
| 1920x1080 | 1.5 | 574 | 861 | **79.72 %** |
| 2560x1440 | 2.0 | 517 | 1034 | **71.81 %** |

Same game, same settings, eight points of screen apart Ã¢â‚¬â€ and at a large enough
scale it keeps going, which is what puts the line over a full-screen view like
the map/timetable screen.

### 9.3 The fix

`cof_hud_msg_y_pct` (archived, default `78`) is an **absolute target**, not an
offset: the engine hands the support library the device row the first line of a
message run belongs on, and `XashSurface::applyTextYTarget` shifts the whole
collected run there, keeping the spacing of any further lines. `0` turns it off
and leaves the client's own placement.

Applied to the collected *text*, not to the panel, for two reasons: the panel
also carries the health bar, the stamina bar and the hint bar, which must not
move; and the client rewrites that panel's `setPos` every frame while the
message is up, so a panel-level move would have to fight it every frame.

Measured, same probe, after:

| render size | device y | fraction |
| --- | ---: | ---: |
| 1920x1080 | 842 | **77.96 %** |
| 2560x1440 | 1124 | **78.06 %** |

### 9.4 The role is shared, so the run length is the real discriminator

`credits` is not this Label's private scheme. `getSchemeHandle( "credits" )` is
also called by the client's own main menu (`1002C6B3`), the unlockables menu
(`10033DEF`), the note/document viewer's buttons (`10046FB4`), the keypad panel
(`1004AA45`), the stats and end-of-chapter screens (`1001F3FB`, `10020EE1`,
`100265B9`), the welcome/intro panel (`1003DEAF`) and `CHUDControl`'s own
secondary Label at `+0x3B0`. A change scoped by role alone would move all of
them.

So the placement and the backing strip are additionally gated on the run being
**at most three lines** (`MAX_MESSAGE_LINES`). The message Label never wraps Ã¢â‚¬â€
`TextImage`'s wrap branch cannot fire, because `Label::setText` sizes the image
to the text's own width, and the only line breaks are literal `\n` in the
payload Ã¢â‚¬â€ so a real message is one line, while the intro text card and the
credits roll are six and more. Verified: with the feature on, the intro card
renders in **exactly the same rows 413..668** it did before, with no strip.

### 9.5 The face

The message role takes the **Inter SemiBold** face, for the same reason the
engine HUD text did. This cannot be scoped more tightly than the role, so every
`credits` consumer listed in 9.4 becomes SemiBold. It is a legibility change in
the right direction everywhere it lands; to revert it, drop
`CL_CoF_FontRoleIsMessage( role )` from the `*semibold` expression in
`CL_CoF_FontRoleFraction` and rebuild.

### 9.6 Cvars and hooks added in 4c

| name | default | flags | meaning |
| --- | --- | --- | --- |
| `cof_hud_msg_y_pct` | `78` | `FCVAR_ARCHIVE` | where the in-game message text sits, as a percentage of the render height; `0` = the client's own placement |
| `cof_hud_msg_probe` | Ã¢â‚¬â€ | command | send the client one `ProFont` message: `cof_hud_msg_probe "<text>" [colour]`. Colour index 0/3 yellow, 1 azure, 2/6 red, 4 green, 5 grey (what the pickups use). Never put `DEADNOTIFY` in the text Ã¢â‚¬â€ the client's handler swaps any message containing it for the coop respawn prompt |
| `cof_hud_text_trace` | `0` | Ã¢â‚¬â€ | extended in 4c: also logs every VGUI text line with its role, its layout y, its device y and its fraction of the screen |

`vguiapi_t` gains `CofPrint`, because `vgui_dprintf` goes to stderr, which the
game log never sees; it falls back to `Sys_PrintLog` when the console is locked,
which is the one configuration in which the client's VGUI layer paints at all.

### 9.7 Evidence

`stage1/ui-m4b-fixture-20260922`, from the user's own `config.cfg`
(HUD scale 150 %).

| run | what it shows |
| --- | --- |
| `p1-stock-1080.png`, `p2-stock-1440.png` | `cof_ui_inter_fonts 0`: the game's own bitmap font, no strip, the client's placement Ã¢â‚¬â€ thin and pale over the scene |
| `n1-before.png` / `n4-before1440.png` | `cof_hud_msg_y_pct 0`: the drift, 79.72 % against 71.81 % |
| `r1-after-1080.png` / `r2-after-1440.png` | the defaults: 77.96 % and 78.06 % |
| `t1-final-1080-yellow.png`, `t2-final-1440-yellow.png` | a yellow `SIMON:` dialogue line (colour index 0) on its strip Ã¢â‚¬â€ the user's own case |
| `mA-intro.log` | the live cutscene: `MAN:` and `SIMON:` lines traced with role `credits`, at the same slot as the pickups |
| `s1-intro-08..15.png` | the intro text card with the feature on: rows 413..668, unchanged, no strip |

Still manual: a screenshot of a live in-game subtitle with the feature on. The
cutscene is not deterministic under a frame-counted cfg Ã¢â‚¬â€ one run reached the
dialogue and two others did not Ã¢â‚¬â€ and the lines are proven to be the same panel,
the same role and the same slot as the probe, which is captured.

---

## 10. The moved run has to take its clip rectangle with it, milestone 5a

Section 9.3 moves the collected glyphs. It did not move the **scissor**, and
that is why the user, playing at 3840x2160 with the HUD scale at 150 %, saw the
subtitles, the pickup notifications and the hint bar render **nothing at all**.

### 10.1 Why the panel walks up the screen

`CHUDControl`'s message Label is positioned every frame as
`setPos( 0, ScreenHeight - 3*G )` with `G = round( ScreenHeight/480 * 25 )` -
but `G` is computed **once**, in the constructor (`10037B31`), from the screen
height at that moment, while the `setPos` uses the height in force when it
runs. Those are not the same number, so the bar climbs as the display grows.
Measured with `cof_hud_text_trace`, layout y of the first line of a run:

| render size | `3*G` | panel band (layout) | text row | fraction of the screen |
| --- | ---: | --- | ---: | ---: |
| 1920x1080 | 168 | 552..616 | 574 | 79.72 % |
| 2560x1440 | 225 | 495..559 | 517 | 71.81 % |
| 3840x2160 | 339 | **381..445** | 403 | **55.97 %** |

The 1080p and 1440p rows are section 9.2's; the 2160p row is new, and it is the
one that breaks. `cof_hud_msg_y_pct 78` wants layout row 562. From 574 that is a
move of **-13**, which still lands inside the 64 px band. From 403 it is a move
of **+159**, which lands 117 px below the bottom of the band - and the clip
rectangle in force during the flush is still that band's (`pushMakeCurrent` ->
`Panel::getClipRect`). `Scissor::clip()` rejected every glyph, `drawFilledRect`
was rejected the same way, and the line vanished together with its backing
strip.

Everything the client draws with the `credits` role is in that same shape, which
is why it looked to the player like *all* of the substituted VGUI text had
stopped rendering.

### 10.2 The fix

`XashSurface::applyTextYTarget()` now returns the distance it moved the run, and
`flushBackingText()` moves the scissor rectangle by exactly that distance for
the duration of the strip and glyph draws, then puts it back:

```cpp
int yDelta = applyTextYTarget();
if( yDelta != 0 ) { g_scissor.getRect( savedClip );
                    g_scissor.setRect( savedClip[0], savedClip[1] + yDelta,
                                       savedClip[2], savedClip[3] + yDelta ); }
...
if( clipMoved ) g_scissor.setRect( savedClip[0], savedClip[1],
                                   savedClip[2], savedClip[3] );
```

Moving the rectangle rather than dropping it keeps every guarantee the clip was
there for: the run is still clipped to its panel's width and to a band of its
panel's height, just at its new row. `Scissor::getRect()` is the one new entry
point (`3rdparty/freevgui/platform/xash3d-fwgs/clip.cpp`), which is why that
file joins this patch.

`cof_hud_text_trace` gained `moved=` and `clip=` for the same reason: without
them this was invisible in the log, because the run was being collected,
retargeted and traced perfectly - and then thrown away one call later.

### 10.3 Measured, after

| render size | `cof_hud_msg_y_pct` | moved | clip band after the move | device row |
| --- | ---: | ---: | --- | ---: |
| 1920x1080 | 0 | 0 | 552..616 | 861 (79.72 %) |
| 1920x1080 | 78 | -13 | 539..603 | **842 (77.96 %)** |
| 3840x2160 | 0 | 0 | 381..445 | 1209 (55.97 %) |
| 3840x2160 | 78 | +159 | 540..604 | **1686 (78.06 %)** |

`stage1\m5a-regression-20260922\evidence`: `ver-1080-b-pct78.png` and
`ver-2160-b-pct78.png` show the line and its strip; `bi4kA-game-g2-msg.png` and
`bi4kD-game-g2-msg.png` are the same probe before the fix, on the full m5 set
and on the m4c control - blank in both, which is what proved this was never a
milestone-5 regression at all but a latent one in 4c that the user's 4K display
was the first thing to expose.

### 10.4 The retarget is scoped by WHERE the run already is

The role is not a sufficient discriminator, and this is the other half of the
same bug. `CHUDControl` carries **two** full-width 64 px `credits` Labels: the
message strip, positioned every frame at `ScreenHeight - 3*G`, and a second one
pinned to the top of the screen, which is where the hints and the `Press E`
prompts appear. Retargeting by role alone dragged the hint bar down onto the
message row - before milestone 5a it was clipped away and nobody could see it
happening, and the clip fix in 10.2 would have made it visible in the wrong
place.

So `runIsMessage()` now also asks where the run already is, in device pixels,
**before** the move:

    MSG_BAND_LOW_PCT (35) <= deviceY * 100 / render_height <= MSG_BAND_HIGH_PCT (90)

Measured device rows of the message strip at the HUD scale the user plays with
(`cof_ui_scale_user 1.5`): 79.7 % at 1080p, 71.8 % at 1440p, 56.0 % at 2160p -
it climbs for the reason in 10.1, and the band is generous on both sides of
that. The top Label is at 0 %, which no band that contains the message strip
can reach.

Everything else is unchanged. A run the band turns down keeps the client's own
placement and **still gets its backing strip and its SemiBold face**: the strip
now asks the weaker `runIsShortEnough()` question (`backingLineCount <=
MAX_MESSAGE_LINES`), so the only thing that is still deliberately stripless is
what always was - the intro text card and the credits roll, which are six lines
and more.

### 10.5 Measured, the two bands

`cof_font_probe "credits <text>"` draws a `credits` run at layout (12,12) - the
same role, the same collector and the same y target as the message strip, at
the top of the screen. It is the deterministic stand-in for a hint: no console
command in this game raises a real one.

| build | run | `moved` | device row |
| --- | --- | ---: | --- |
| before (`41C0E78D`'s predecessor) | top-band probe | **+550** | 1686 = 78.06 % - dragged onto the message row |
| before | message probe | +159 | 1686 = 78.06 % |
| **after** | top-band probe | **0** | 36 = **1.67 %**, with its strip |
| **after** | message probe | +159 | 1686 = **78.06 %**, with its strip |
| **after**, 1920x1080 | top-band probe | 0 | 18 = 1.67 % |
| **after**, 1920x1080 | message probe | -13 | 842 = 77.96 % |

`stage1\m5a-regression-20260922\evidence`: `band-old-2160-*`, `band-fix-2160-*`
and `band-fix-1080-*`, logs and screenshots. `band-fix-2160-b-both.png` has both
runs on screen at once, each on its own strip, at 1.67 % and 78.06 %.

### 10.6 Known limit of the band

At `cof_ui_scale_user 2.0` on a 2160p display the client's own formula puts the
message strip at a **negative** layout row (`540 - 675`), i.e. off the top of
the layout entirely, so it falls outside the band and keeps that placement
instead of being retargeted. It was invisible in that configuration before this
round as well - the old code moved it and the clip threw it away - so this is
not a regression, but it is not a fix either. 100/125/150 % at every resolution
from 720p to 2160p, and 200 % up to 1440p, are all inside the band.
