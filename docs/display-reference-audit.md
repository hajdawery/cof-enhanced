# Display and menu reference audit

This is a bounded read-only audit of the supplied 4K menu capture and the
pinned FWGS source. It defines the next display/reference gate; it does not
claim visual parity or identify the current menu-transition root cause.

## Supplied capture

The reference image is the user-supplied external file `coffix-devbuild.png`
(it is not copied into this repository). Its measured metadata is:

| Property | Value |
| --- | --- |
| Dimensions | 3840 × 2160 |
| Pixel format | 24-bit RGB |
| Embedded DPI metadata | 143.9926 × 143.9926 DPI |
| SHA-256 | `7CBE46E8CCC4E2734AA1B5FAD704F1EE602DB9FE0216A720CCD4AF671F1EB1DD` |

The capture shows a centered Cry of Fear logo and an 11-row menu. A simple
bright-pixel measurement gives an approximate logo envelope of `(1682,894)` to
`(2136,980)` and menu envelope of `(1818,1750)` to `(2020,2108)` in source
pixels. These envelopes are repeatable comparison anchors, not semantic
segmentation of the artwork or a visual-fidelity score.

## Scaling boundary

The pinned FWGS `3rdparty/mainui/BaseMenu.cpp` source sets
`uiStatic.scaleX = uiStatic.scaleY = ScreenHeight / 768.0f` for displays at or
wider than 4:3, then derives the logical menu width from `ScreenWidth`.
At 3840 × 2160 that path would use a scale of 2.8125 and a logical width of
about 1365.33. `UI_ScaleCoords` multiplies control coordinates and sizes by
that scale, while `UI_MouseMove` receives absolute screen coordinates.

That is only a possible engine-side boundary. The visible CoF menu is driven
by the game resource `cryoffear/resource/GameMenu.res`, whose commands include
`engine beginspgame`, `engine map c_loadgame`, `engine to3dmenu`, and
`engine returnmenu`. The source tree does not establish that the supplied
capture's bespoke menu is drawn by the FWGS `mainui` implementation. The
separate client `hud_scale` path and the SDL display transform must therefore
be recorded before attributing a size or cursor defect to scaling.

The pinned SDL2 source defaults `vid_scale` to `1.0`, disables
`SDL_WINDOW_ALLOW_HIGHDPI` on Windows, and sets the SDL Windows DPI hint to
`permonitor`. The supplied image's DPI metadata is not evidence of the
operating system DPI setting. The historical Steam-tested x86 launcher and
the first branding build have no embedded DPI manifest and do not set the
large-address-aware flag. The current launcher build script now enables
`/LARGEADDRESSAWARE`; its verified local output reports PE characteristics
`0x122` and resource ID 101. This flag audit does not establish a Windows DPI
policy.

## Stage 2 acceptance matrix

Run each row from a clean, matched runtime after the menu-transition fix. Keep
the same aspect ratio, window mode, display DPI context, language, assets, and
renderer. Record `width`, `height`, `vid_scale`, `hud_scale`, actual viewport
size, and whether the menu is the original client/resource path or FWGS
`mainui`.

| Display target | FWGS `mainui` reference scale* | Capture and interaction gate |
| --- | ---: | --- |
| 1920 × 1080 | 1.40625 | Main menu screenshot; hover and click every visible row; record logo/menu envelopes and cursor hit alignment. |
| 2560 × 1440 | 1.87500 | Repeat the same screenshot and row interactions; compare normalized positions and row spacing. |
| 3840 × 2160 | 2.81250 | Repeat against the supplied capture; record physical text size, logo/menu envelopes, and cursor alignment. |

\* These are expected values only for the FWGS `mainui` scaling path. The CoF
resource/client menu must be measured separately.

For each resolution, the functional sequence is: main menu → `New Game` →
first playable frame; main menu → `Load Game` → slot selector → selected save;
then return to menu and quit. Test a stock GoldSrc/Cry of Fear save and an
Xash-generated save as separate cases. Keep the existing console `+map` and
`+load` smoke checks labeled separately. Capture lossless PNGs at stable menu,
slot-selector, and first-frame points with the exact runtime hash and cvar
snapshot beside each capture.

Acceptance requires the selected menu state to change, the expected command
to execute, and the resulting screen or map state to appear. Footstep audio
alone is not a transition result. A nonblank frame or matching menu envelope
does not establish visual parity.

The interaction gates and the original game UI references are listed in the
[custom UI regression checklist](custom-ui-regression-checklist.md). Every
runtime interaction in that checklist is pending until reproduced on the
matched fixed runtime.
