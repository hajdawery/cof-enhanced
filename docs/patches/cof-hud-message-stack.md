# Independent HUD message rows (issue #2)

Apply after the existing text backing/style patches and the complete pre-issue
HUD stack. This additive FreeVGUI patch leaves the engine/support ABI unchanged.

`XashSurface::applyTextYTarget` previously moved the first line of **every**
qualifying text run onto `cof_hud_msg_y_pct`. Independent labels flush separately
on panel pop, so simultaneous phone/objective labels landed on the same row.
The issue screenshot is consistent with this deterministic code defect.

At the beginning of each painted frame, the surface now clears its occupied
message interval. The first visible message keeps the configured target. Each
subsequent message is placed above the preceding occupied interval, allowing
for every wrapped line, font height, backing padding and a gap. Fully faded
labels do not occupy a row. Text and glyphs move together; the existing clip
translation receives the same delta, preserving panel clipping.

Top hints, long credits runs and other font roles retain their previous paths.
The existing `cof_hud_msg_y_pct 0` opt-out restores original client positioning
by disabling message relocation. No new VGUI callback or font descriptor field
is needed. Ordering follows label paint order; this does not assign semantic
priority to phone versus objective messages.

`tests/cof-hud-message-stack/run.py` compiles the actual relocation methods and
checks separate one/two/three-line labels, true occupied heights, glyph spacing,
invisible labels, frame reset, already-positioned first labels, top hints,
credits and the opt-out across five heights and four UI scales. Low targets
and 100 sequential captions verify negative occupied coordinates remain valid
reservations rather than being mistaken for unused state. Apply/reverse
checks passed. These are geometry regressions, not a live-game screenshot test.

Manual validation still needed: reproduce simultaneous phone/objective labels,
including wrapped localized text, at 1080p/1200p/4K with varied HUD scale and
backing on/off. Extreme target percentages or enough messages to exhaust the
available screen height can still place text offscreen.
