# The console as a Source-style window (`cof_console_style`)

Unified UI milestone 3, part (b). The engine console keeps every bit of its
GoldSrc behaviour — the tilde toggle, the key handling, the command history, the
tab completion, the completion ghost, the notify lines, the backscroll — and
gains a Source-style window: a centred translucent panel with a thin border, a
title band carrying `CONSOLE` and the build string, a close `X` at the right of
the band, and a separate input box with its own border and caret at the bottom.

Nothing is blurred behind it; that is milestone 3 part (c).

The panel colours follow the milestone-3a theme spec
(`stage1/ui-theme-spec-20260921/RESULTS.md` §2.1).

## Cvars

None are `FCVAR_ARCHIVE`, so a stale `config.cfg` cannot pin the look. All of
them are registered in `Con_Init` (`engine/client/console.c`).

| cvar | default | effect |
| --- | --- | --- |
| `cof_console_style` | `1` | `0` returns the console to the stock full-width `conback` drawing, byte for byte, including the font texture (see below) |
| `cof_console_width` | `0.70` | panel width as a fraction of the screen, clamped to 0.25..1.0 |
| `cof_console_height` | `0.60` | panel height as a fraction of the screen, clamped to 0.25..1.0 |
| `cof_console_title` | `CONSOLE` | title band text, used as written |
| `cof_console_panel_color` | `32 32 32 230` | panel body — spec `THEME_PANEL` |
| `cof_console_border_color` | `150 150 150 200` | outer hairline and the rule under the band — spec `THEME_PANEL_BORDER` |
| `cof_console_band_color` | `20 20 20 240` | title band — spec `THEME_TITLE_BAND` |
| `cof_console_title_color` | `220 220 220 255` | title, close `X`; the build string uses it at half alpha — spec `THEME_TITLE_TEXT` |
| `cof_console_text_color` | `190 190 190 255` | log lines and typed input — spec `THEME_TEXT` |
| `cof_console_input_bg_color` | `12 12 12 200` | input box fill — spec `THEME_INPUT_BG` |
| `cof_console_input_border_color` | `90 90 90 255` | input box hairline — spec `THEME_INPUT_BORDER` |
| `cof_console_accent_color` | `240 180 24 255` | the `]` prompt, the caret, and the close `X` while hovered — spec `THEME_ACCENT` |
| `cof_console_font_grayscale` | `1` | load the console font texture as `TF_LUMINANCE`; only honoured while `cof_console_style` is on (see "The amber font" below) |

Each colour cvar takes `"r g b"` or `"r g b a"`; a string with fewer than three
numbers falls back to the cvar's own default rather than to white.

## Geometry

`Con_StyleLayout()` derives everything from `refState.width`/`refState.height`
and the loaded bitmap font. There is no 4:3 term anywhere in it, unlike the
stock `Con_DrawSolidConsole`, which anchors its background to
`refState.width * 3 / 4` (`console.c`, the `R_DrawStretchPic` call).

```
panel w = refState.width  * cof_console_width      (>= padx*6 + charH*8)
panel h = refState.height * cof_console_height     (>= band + line + input + padding)
panel x = ( refState.width  - w ) / 2
panel y = ( refState.height - h ) / 2

border  = max( 1, refState.height / 720 )          1 px @720p/1080p, 2 @1440p, 3 @2160p
padx    = max( 8, refState.height / 72  )
pady    = max( 5, refState.height / 144 )
band_h  = font charHeight + pady*2
input_h = font charHeight + pady*2                 inset padx/pady from the panel
log     = everything between the band and the input box
close X = a (band_h - pady) square, padx in from the panel's right edge
```

Measured from the screenshots below: 69.8% x 59.7% of the screen at 1280x720,
1920x1080 and 2560x1440 alike.

The panel is **not** animated by `Con_DestHeight()`'s slide any more. The stock
`lines` value still arrives and still comes from `Con_RunConsole`, so
`scr_conspeed` still governs how long the console takes to appear, but it now
drives an alpha ramp (`min( lines / height * 2, 1 )`) instead of a Y offset. In
game `Con_DestHeight()` is half the screen, which is exactly the point where
that ramp reaches full opacity.

## What is drawn, in order

`Con_DrawStyledConsole( lines )`:

1. panel body, title band, hairline under the band, hairline border (all
   `ref.dllFuncs.FillRGBA( kRenderTransTexture, ... )`, axis-aligned — the
   engine has no rounded-rect or line primitive, and neither do the Source
   dialogs the spec targets);
2. the title, left, at `padx`;
3. the build string right-aligned before the close button, at half alpha. This
   is the version text that the stock console draws across the top of the
   *screen*; the brief asked for it in the band, and that is where it is. The
   separate `Con_DrawVersion()` watermark (menu and screenshots) is untouched;
4. the close `X`, drawn as the font's own `X` glyph, `THEME_ACCENT` while the
   cursor is inside its box and `THEME_TITLE_TEXT` otherwise;
5. the log, bottom-up from the bottom of the log area, stopping at its top;
   backscroll arrows keep the stock red `^` row;
6. the input box, its hairline, the `]` prompt, the field and the caret;
7. `SCR_DrawFPS( 4 )`.

`Con_DrawSolidConsole()` forks to this at its very top and returns; everything
after that fork is the original code, untouched. `Con_DrawStyledConsole` returns
`false` — falling through to the stock drawing — when there is no font, when
`host.allow_console` is clear, or when the screen is too small to hold a window.

`Con_DrawNotify`, `Con_DrawDebug`, `Con_DrawDebugLines`, `Con_DrawVersion`,
`Field_DrawInputLine`, `Con_Print`, the history and the key handling are not
edited at all.

## Clipping

`CL_DrawString` does not clip. A styled log line therefore goes through
`Con_DrawStringClipped`, a copy of the `CL_DrawString` loop that stops before it
would draw past the log area's right edge (conservatively, one `W` width early),
with the same `^N` colour-code and UTF-8 handling. The same function draws the
title, the build string and the input.

Long lines are **clipped, not wrapped**: `con.linewidth` still comes from the
screen width (`Con_CheckResize`), because it also governs the notify lines, and
wrapping happens in `Con_Print` when the line is added, long before the panel
exists. At 1280x720 the deliberately long test line wraps by itself and both
halves fit the panel; at 1920x1080 it does not wrap and the tail is clipped at
the panel edge. That is visible in the screenshots and is the intended
behaviour.

`con.input.widthInChars` *is* re-derived from the input box each frame, so the
typed line scrolls horizontally inside the box instead of inside the screen.
When `cof_console_style` goes back to 0, `Con_DrawConsole` forces
`con.linewidth = 0` so `Con_CheckResize` recomputes the stock value.

`Con_GetInputRect` reports the styled input box while the style is on, so the
on-screen keyboard and the IME candidate window follow the panel.

## The amber font (`cof_console_font_grayscale`)

**Measured.** Cry of Fear's `gfx.wad` `CONCHARS` atlas is not a white font: its
glyph pixels are orange (peak about 253,169,27). Every console draw call
modulates that texture, so no colour passed to `CL_DrawString` can produce a
neutral grey — passing 190,190,190 produced 188,126,20 on screen, passing
220,220,220 produced 216,141,22. The engine's `con_color` default `240 180 24`
lands on the atlas's own hue, which is why the stock console looks
"correctly" orange.

With `cof_console_font_grayscale 1` (the default) the console font textures are
loaded with `TF_LUMINANCE`, which makes the glyphs white, and the spec colours
then land where they should: measured 188,188,188 for the log, 216,216,216 for
the title, 119,119,119 for the build string.

Two consequences, both deliberate:

* **`^N` colour codes become true colours.** `^1` is red rather than
  orange-red, `^5` is cyan rather than green. That is the correct behaviour;
  the stock console has been tinting them all along.
* **The notify area's hue shifts.** The notify lines are drawn by the same
  untouched `Con_DrawNotify` in the same place with the same timing, but their
  default colour stops being `con_color` x atlas (a deep orange, 253,168,0
  measured) and becomes `con_color` itself (amber, 253,253,0 measured on the
  brightest glyph). Set `cof_console_font_grayscale 0` to get the old pixels
  back, or `cof_console_style 0` to get the stock console entirely.

The flag is only honoured while `cof_console_style` is non-zero, so
`cof_console_style 0` alone is still the complete stock console. Changing
either cvar at runtime reloads the console fonts from `Con_DrawConsole`
(`Con_InvalidateFonts()` + `Con_LoadConchars()`), the same pair a video mode
change uses; that was exercised in `con6-notify-1280x720`.

The font stays a bitmap `.fnt`, as both audits recommend
(`stage1/ui-architecture-audit-20260921/RESULTS.md` §1.3,
`stage1/ui-theme-spec-20260921/RESULTS.md` §D). One consequence: glyph size does
not scale with resolution, so at 2560x1440 the panel is twice the size of the
720p one but the text is the same number of pixels tall. `con_fontscale` is the
existing lever for that and is untouched.

## No slide, no fade (milestone 5a)

The stock console is a GoldSrc drop-down: `Con_RunConsole()` walks
`con.vislines` towards `Con_DestHeight()` at `scr_conspeed` lines per second,
and `Con_DrawSolidConsole( con.vislines )` draws the sheet that far down the
screen. The styled console is a **window** — its geometry comes from
`cof_console_width` / `cof_console_height` and the panel is always in the same
place — so `lines` never moved it. All the animation ever did here was drive
the alpha in `Con_DrawStyledConsole()`:

    frac  = lines / render_height
    alpha = min( frac * 2, 1 ) * 255

which made the window fade up over `scr_conspeed` on open and, more annoyingly,
**linger on the way out**: the user reported a closed console still painted over
the scene. `stage1\m5a-regression-20260922\evidence\con-old-styled-d-close-frame1.png`
is that, one frame after `toggleconsole`.

So `Con_RunConsole()` snaps while the style is on:

```c
if( Con_StyleEnabled( ))
	con.vislines = con.showlines;
else
	...the stock lines_per_frame walk...
```

`Con_DestHeight()` returns either the full render height or half of it, so
`frac` is 1.0 or 0.5 and the alpha expression is 255 either way: the window is
fully drawn on the frame the toggle is pressed. On close `Con_DestHeight()`
returns 0, `con.vislines` becomes 0, and `Con_DrawConsole()`'s own
`if( con.vislines )` test drops the draw entirely — gone on the next frame.
`scr_conspeed` is untouched and still drives the stock drop-down, which is the
only thing it was ever for.

Measured, in game on `c_forest3`, `scr_conspeed 600`, every command from the
planted `maps\c_forest3_load.cfg` and one `wait` between the toggle and the
screenshot:

| run | one frame after open | one frame after close |
| --- | --- | --- |
| `con-old-styled-*` (before) | `b-open-frame1.png`, faded | `d-close-frame1.png`, **window still there** |
| `con-fix-styled-*` (after) | `b-open-frame1.png`, **full window** | `d-close-frame1.png`, **gone** |
| `con-fix-stock-*` (`cof_console_style 0`) | `b-open-frame1.png`, nothing yet — the stock sheet is 10 px down | — |

The third row is the scoping control: the stock path still slides.

## The close button

The `X` is clickable. `IN_MouseMove()` (`engine/client/input/input.c`) now calls
`Con_MouseMove( x, y )` next to the existing `UI_MouseMove( x, y )`; console.c
only remembers the position. `Key_Console()` handles `K_MOUSE1` by testing that
position against the close box through `Con_StyleCloseHit()`, which itself
returns false unless the styled console is visible, and calls
`Con_ToggleConsole_f()` — the same function the tilde key calls. Any click
outside the box falls through to the code that was already there.

**Marked for manual test.** The verification harness is forbidden from injecting
mouse input, so the click and the hover highlight were never exercised in an
automated run. The code path is guarded to the one box and to
`cof_console_style != 0`, so the worst case if the pointer coordinates do not
line up on some setup is that the button is decorative.

## Verification

Fixture `stage1/ui-m1-engine-fixture-20260921`, driver
`run-vidmode-cfg-case.ps1` (the cfg-driven one), every launch windowed, short,
`+volume 0`, `-dev 2`, `+set developer 2`. **No keystroke and no mouse event was
injected in any of these runs**: the console is opened by the engine's own
`toggleconsole` command from a cfg, and the case cfgs end in `quit` so the
engine closes itself.

Engine under test: `build-cof-ui-m1-engine-20260921/engine/xash.dll` SHA-256
`1B80EF3769479C1ACEB3EC415837BF17581B7CC6730E7DE7BC2D3FE83AE5B0AD`
(the milestone-1 stack plus the vid-restart patches plus this one and the
levelshot guard).

Case cfgs in the fixture: `root/cryoffear/concase1.cfg` (background map),
`concase2.cfg` (in game), `concase0.cfg` (`cof_console_style 0` control),
`concase3.cfg` (notify area + live font reload). Each sets `gl_check_errors 0`
so the CoF client's known per-frame `GL_INVALID_VALUE` spam does not bury the
log, and sets it back before `quit`.

| Run | Configuration | Result |
| --- | --- | --- |
| `con1-bgmap-1920` | 1920x1080, background map `c_game_menu1` | panel 1342x646 (69.9% x 59.8%), title band, build string, close `X`, log in spec grey, input box with `]` and caret |
| `con2-ingame-1920` | 1920x1080, `+load cofsave1` (map `c_forest3`) | same panel over the live scene, translucent, HUD suppressed by the milestone-1 input gate; `-a` caught the fade-in mid-ramp |
| `con3-style0-1920` | 1920x1080, `cof_console_style 0` | the stock console: full width, `conback` image, amber text, version top-right, prompt at the bottom left |
| `con4-bgmap-1280x720` | 1280x720 | panel 894x430 (69.8% x 59.7%) |
| `con5-bgmap-2560x1440` | 2560x1440 windowed | panel 1788x860 (69.8% x 59.7%) |
| `con6-notify-1280x720` | in game, console never opened, style 1 then 0 | notify lines in the same place with the same content; only the default hue changes, and the runtime font reload works |
| `ls1-newgame-bgmap` | 1280x720, `newgame` on the background map | the levelshot guard, see `cof-levelshot-guard.md` |

Screenshots, logs, command lines and hashes are in the fixture's `evidence/`
folder and indexed in `evidence/CONSOLE-EVIDENCE.md`. The headline frames:

| Path | SHA-256 |
| --- | --- |
| `stage1/ui-m1-engine-fixture-20260921/evidence/con1-bgmap-1920-c.png` | `111103AB06DBC5BA76BE82630E28EC68BDFE9F1092A026677F1422A8C90162DF` |
| `stage1/ui-m1-engine-fixture-20260921/evidence/con2-ingame-1920-c.png` | `A5DB9F52CAAC3DD1BFB6DAFF08A6DC60DC3BC99E5437F2527C60AE5110FEA1E8` |
| `stage1/ui-m1-engine-fixture-20260921/evidence/con3-style0-1920-c.png` | `C7E77AD8E86D634DD74F38F042CA958204FFCB40477098D3EEBEF8903F3DE757` |
| `stage1/ui-m1-engine-fixture-20260921/evidence/con4-bgmap-1280x720-c.png` | `2DF31D38FC82E9A8F681AD30B173668838AA897F3C36BF61AB9927E0728A56FD` |
| `stage1/ui-m1-engine-fixture-20260921/evidence/con5-bgmap-2560x1440-c.png` | `54300BD2714373E4ADFD70AA8C76A3D4AD03F63CC312945D4C7A9CB5D1FFCB22` |
| `stage1/ui-m1-engine-fixture-20260921/evidence/con6-notify-1280x720-a.png` | `0DD6F9749AC9F49E1B46488F1087582B7DDFA05308AB6A1D0469EE23F56F2AC7` |
| `stage1/ui-m1-engine-fixture-20260921/evidence/con6-notify-1280x720-b.png` | `80F1E8AF26063839B7777AF4F9D3967024AB9F66834784D4C6F706AEC913B008` |

The canonical tree `K:\LLM\COF_Fix\Cry of Fear` was manifested before and after
every run (`evidence/canonical-console-before.txt`,
`evidence/canonical-console-after.txt`): 6197 files, 4702274797 bytes, newest
write 2026-09-18T20:33:58Z, identical.

## Risks and limits

* Long lines are clipped at the panel edge rather than rewrapped (above).
* The bitmap glyph size is resolution-independent only in the sense that it does
  not change; the panel scales around it. Use `con_fontscale` for high DPI.
* `cof_console_font_grayscale` changes the notify hue (above).
* The close button click is not automatically tested (above).
* Not measured: the console during a level change or a cinematic (both are
  early-returned by the stock `Con_DrawConsole` before the fork), the console on
  the software renderer, and any non-Windows platform.
* `Con_MouseMove` is fed from `IN_MouseMove()`, which returns early while touch
  emulation wants a visible cursor and only fires when the pointer actually
  moves. On a touch-only device the close button would never highlight.

## Applying

Apply after `scripts\apply-cof-console-variable-font-fallback.ps1`; the script
refuses a tree without it, because the patch's font hunks use that fallback's
own lines as context and because it is what makes CoF's `gfx.wad` atlas load as
an FNT in the first place.

```powershell
pwsh -File .\scripts\apply-cof-console-style.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

The script validates the source location, refuses an already-patched tree,
checks the prerequisite, checks that the patch applies before changing files,
verifies concrete markers in all three touched files afterwards, and
reverse-checks the applied result. Verified on 2026-09-21 against a scratch copy
of `cof-fix\pristine-ui-m1-scratch` (which carries the font fallback): apply,
result identical to the build tree, clean reverse, correct refusals on a
second run and on a tree without the prerequisite.
