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

## Runtime check, 2026-10-03

The combined candidate ran normally in an isolated, muted 1920x1200 fixture
at HUD scale 1.5. On `c_apartment1`, triggering the real `objectivee` entity
produced `Objectives SIZE 32` and the "Help the person on the fourth floor."
caption. A ProFont phone-caption probe and `+objectives` were exercised with
backing off/on after the opening camera completed.

The final screenshot shows both captions without overlap. However, this
particular objective uses the **top hint label**, not the second bottom label
seen in the report: VGUI traces place the objective at device y=23 and phone
caption at y=937. Thus this is a real-render regression check for message
visibility and preserved hints, **not acceptance of the exact reported
bottom/bottom collision**. The compiled geometry regression covers that
branch; reproducing its original gameplay trigger remains outstanding.

Local evidence: `stage1/issues-hud-runtime-20261003/hud-revised/`, especially
`hud2-06-phone-objective-backing.png`, `hud-revised.log` and `RESULTS.json`.
No player runtime files were changed.
