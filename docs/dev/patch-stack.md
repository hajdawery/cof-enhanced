# The patch stack (authoritative apply order)

This page is the single source of truth for **which patches exist and in which
order they go on**. Every other page that says "apply after X" is a local
reminder; where one disagrees with this list, this list wins. For what each
patch does, see the [patch index](../patches/README.md).

The order below is the order the stack verifiers in `stage1/` apply
(`stage1/m7-integration-20260923/stackverify-m7.py` reads it from this page;
before it `stage1/lang3-20260922/stackverify-lang3.ps1` and the per-round
ones), and it matches the
order the old README gave, group by group. It covers all 77 patches in
`patches/` and all 77 `scripts/apply-*.ps1` scripts.

> **Verification status (m7, 2026-09-23).** The complete list below, steps
> 1-48 in this order, was applied in one run to a fresh `pristine-clean` copy
> with no patch edited, and that tree built the m7 release
> (`stage1/m7-integration-20260923`). A second fresh tree was verified step by
> step by `stackverify-m7.py`, which reads its order from **this page**: after
> each step the patch was reversed with `git apply --reverse`, re-applied, and
> (where the script has `-Reverse`) reversed and re-applied through its script;
> every re-apply reproduced the tree byte for byte, and the finished tree is
> byte-identical to the build tree (627 files). The reverse direction restores
> content exactly but not always whitespace: 31 reverses leave a lone CR on a
> blank line of a mixed-line-ending file (eight patches carry CRLF lines), and
> `cof-save-root-compat.patch` has one pre-image line indented with spaces
> where the file has tabs (`cl_scrn.c`, `VID_MINISHOT`), so its reverse writes
> spaces. Neither changes what a forward apply produces.

> **Options round (2026-09-23).** Step 48 `cof-mainui-options-layout` was
> added (cheats moved to 49). `stage1/options-20260923/stackverify-options.py`
> (the m7 verifier reading this page) applied steps 1-49 to a fresh tree,
> round-tripped every step, and the result is byte-identical (629 files) to
> the tree `stage1/releases/options-20260923` was built from; the only
> problem it reports is the known `cof-save-root-compat` reverse whitespace.
> The panels and gamepad rounds' patches, written at the same time, are not
> on this page yet.

> **Verification status (m8, 2026-09-23).** Steps 49-51 (`cof-panel-pause`,
> `cof-panel-transparency`, `cof-gamepad-input`) were added, cheats moved to
> 52. The complete list, steps 1-52 in this order, was applied in one run to a
> fresh `pristine-clean` copy with no context fix needed; three patches were
> then regenerated in place for the m8 changes (`cof-mainui-options-layout`:
> Tab / Shift+Tab and the death page's prompts; `cof-panel-pause`: the
> `CL_CoF_PanelsOnScreen` accessor; `cof-gamepad-input`: the panel check reads
> it, plus the hunk offsets of its new position) and the whole list applied in
> one run again to build m8 (`stage1/m8-integration-20260923`). Its verifier
> (`stackverify-m8.py`, reading this page) round-tripped every step: every
> re-apply byte-identical, the finished tree byte-identical to the build tree
> (635 files). The only problem it reports is the known
> `cof-save-root-compat` reverse whitespace; 33 CR-only reverse notes (the 31
> above plus `3rdparty/freevgui/image.h` for `cof-panel-transparency`, whose
> forward apply writes that file LF).

> **On-screen keyboard round (osk, 2026-09-23).** Steps 49-52
> (`cof-mainui-osk`, `cof-osk-engine`, `cof-client-enter-hook`,
> `cof-window-name`) were inserted after the options layout; the panels, the
> gamepad and the cheats moved to 53-56 with no patch changed. The 56 steps
> applied in one run (`stage1/osk-20260923/stack-build.log`), and
> `stage1/osk-20260923/stackverify-osk.py` (the m8 verifier, run against a
> copy of these scripts and patches with the m8 gamepad patch the build used)
> round-tripped every step: every re-apply byte-identical, the finished tree
> byte-identical to the build tree (640 files, raw). Only the known
> `cof-save-root-compat` reverse whitespace; 35 CR-only reverse notes. The
> gamepad2 round's newer `cof-gamepad-input.patch` (`A8FB3C3F…`) also passes
> `git apply --check` on top of steps 1-54.

> **Menu fixes round (menufix, 2026-09-24).** Steps 35
> `cof-mainui-source-theme` (Theme.h only: the deep-red palette) and 48
> `cof-mainui-options-layout` (focus by position, Controls / Game / Gamepad
> rows, pad styles; now also `BaseMenu.cpp`'s one-time pad-style migration)
> were regenerated in place; no step moved. The 56 steps applied in one run
> to a fresh tree (`stage1/menufix-20260924/stack-final.log`), and
> `stage1/menufix-20260924/stackverify-menufix.py` (the gamepad2 verifier,
> reading a private copy of this page, the scripts and the patches through
> `COF_ROOT`) round-tripped every step; steps 35 and 48: git and script
> `-Reverse` round trips OK; the finished tree is identical to the build
> tree (640 files, DIFFERENT: none). Besides the known `cof-save-root-compat`
> reverse whitespace it reports "re-apply did not reproduce" for the
> unchanged steps 2, 4 and 26 (CR bytes after a whitespace-tolerant reverse);
> the same happens with those unchanged patches in a scratch folder inside
> the repository, and the forward apply is byte-identical. The quicksave
> round's `cof-mainui-quicksave.patch` and the gamepad3 round's
> `cof-gamepad-input.patch` of 2026-09-24 12:30 pass `git apply --check` on
> the regenerated stack.

> **Verification status (m9, 2026-09-24).** Steps 53 `cof-quicksave` and 54
> `cof-mainui-quicksave` were inserted after the window name; the panels, the
> gamepad and the cheats moved to 55-58. The complete list, steps 1-58, applied
> in one run to a fresh `pristine-clean` with no patch edited
> (`stage1/m9-integration-20260924/stack-run1-unchanged.log`). Then two patches
> were regenerated in place: `cof-mainui-options-layout` (step 48: the game's
> "Tertiary Attack" shown as "Aim" on the Keybinds and Gamepad tabs; the
> generator first reproduced the menufix patch byte for byte) and
> `cof-gamepad-input` (step 57: hunk offsets only - its `LoadGame.cpp` and
> `CoFOptions.cpp` hunks were made before steps 48 and 54 grew those files and
> applied with offsets 9/55 and 291; content byte-identical). The final list
> applied in one run again (`stack-build.log`, the m9 build tree), and
> `stackverify-m9.py` (the menufix verifier, reading this page) round-tripped
> all 58 steps: every re-apply byte-identical, the finished tree
> byte-identical to the build tree (641 files, DIFFERENT: none). Only the
> known `cof-save-root-compat` reverse whitespace and 35 CR-only reverse
> notes; the menufix round's extra notes for steps 2, 4 and 26 did not recur
> (this run verified inside the repository).

## The base tree

| Piece | What it must be |
| --- | --- |
| Engine | Xash3D FWGS commit `4857b389e6ba32ddaa68582aedcbc950c138f46a` (the `fwgs-4857b38.zip` archive, unpacked as `xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a/` **inside this repository**: every apply script refuses a `-SourceRoot` outside the project folder) |
| `3rdparty/mainui` | `61263995592e93a278d764807243d043d3b97c54` exactly; every `apply-cof-mainui-*.ps1` checks the baseline |
| `3rdparty/freevgui` | `73bfb4659f3d9eb28b79e5b26baea8c6b888d5eb` (13 commits ahead of the FWGS pin; see [LICENSING.md section 3](../../LICENSING.md#3-pinned-upstream-sources)) |
| other submodules | the "used for our build" commits in LICENSING.md section 3 |

`pristine-clean/` (ignored, local) is this base tree **with step 0 already
applied**: the only `COF_` markers in it are the server playermove adapter's in
`engine/server/sv_pmove.c` (checked 2026-09-22). The verifiers copy it, take
FreeVGUI from the live checkout's `HEAD` with `git archive`, and clone MainUI
at the pinned baseline.

## Conventions every apply script follows

* `-SourceRoot <tree>` is mandatory and must resolve **inside this repository**;
  the patch is applied with `git apply --ignore-whitespace --directory=<rel>`
  (never `--unsafe-paths`, no global git settings).
* The script first checks that the target files exist and that its
  **prerequisite markers** are present (strings the earlier patches add), and
  refuses a tree that already carries its own markers (no double apply).
* It runs `git apply --check`, applies, then checks **its own markers** in the
  patched files: a zero exit code from `git apply` alone is never taken as
  proof that the source changed.
* It finishes with `git apply --reverse --check`, so an applied tree is always
  provably reversible.
* Most scripts take `-Reverse`, which verifies the patch is present, reverses
  it and re-checks. Scripts **without** `-Reverse`: `apply-pmove-adapter`,
  `apply-cof-client-pmove-profile`, `apply-cof-entvars-profile`,
  `apply-cof-edict-stride-profile`, `apply-cof-menu-load-trace`,
  `apply-cof-save-root-compat`, `apply-cof-ui-input-gate`,
  `apply-cof-vid-restart-background`, `apply-cof-ui-menu-map-redirect`,
  `apply-cof-ui-sound-volume`, `apply-cof-console-variable-font-fallback`,
  `apply-cof-console-style`, `apply-cof-levelshot-guard`,
  `apply-cof-text-autoscale`, `apply-cof-mp3-stop-on-map`,
  `apply-cof-gl-stage-trace`. The verifiers round-trip those with
  `git apply --reverse` directly.
* A patch regenerated "in place" keeps its position; later patches use its
  lines as hunk context, so it must be regenerated against the tree as it
  stands at its own step, not against the finished stack.

Run each as
`powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\<name>.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a`.

## The order

Target: **E** engine (`engine/`, `wscript`), **R** renderer (`ref/gl`),
**V** FreeVGUI (`3rdparty/freevgui`), **M** MainUI (`3rdparty/mainui`).
The four trees share no files, so the groups for different trees may be
interleaved; inside a tree, the order is strict.

### Compatibility base (engine)

| # | Script | Patch | Target | Doc |
| ---: | --- | --- | --- | --- |
| 0 | `apply-pmove-adapter` | `cof-pmove-legacy` | E | [pmove adapter](../patches/pmove-adapter.md) (already in `pristine-clean`) |
| 1 | `apply-cof-client-pmove-profile` | `cof-client-pmove-legacy` | E | [pmove adapter](../patches/pmove-adapter.md), [client checkpoint](../history/client-pmove-adapter-test.md) |
| 2 | `apply-cof-entvars-profile` | `cof-entvars-legacy` | E | [entvars layout](../history/entvars-layout-analysis.md); adds the `--enable-cof-entvars-legacy` configure option |
| 3 | `apply-cof-edict-stride-profile` | `cof-edict-stride-legacy` | E | [edict stride](../patches/edict-stride-proposal.md) |

### Saves (engine)

| # | Script | Patch | Target | Doc |
| ---: | --- | --- | --- | --- |
| 4 | `apply-cof-menu-load-trace` | `cof-menu-load-trace` | E | [menu-load trace](../patches/menu-load-trace.md) |
| 5 | `apply-cof-save-root-compat` | `cof-save-root-compat` | E | [root SAVE compatibility](../patches/cof-save-root-compat.md) |
| 6 | `apply-cof-pause-save-plumbing` | `cof-pause-save-plumbing` | E | [pause-save plumbing](../patches/cof-pause-save-plumbing.md) |
| 7 | `apply-cof-menu-save-backend` | `cof-menu-save-backend` | E | [menu-save backend](../patches/cof-menu-save-backend.md) |
| 8 | `apply-cof-tape-save-command` | `cof-tape-save-command` | E | [tape-save command](../patches/cof-tape-save-command.md) |

### Unified UI, milestones 1-4 (engine and FreeVGUI)

| # | Script | Patch | Target | Doc |
| ---: | --- | --- | --- | --- |
| 9 | `apply-cof-ui-input-gate` | `cof-ui-input-gate` | E | [input gate](../patches/cof-ui-input-gate.md) |
| 10 | `apply-cof-vid-restart-background` | `cof-vid-restart-background` | E | [video mode restart](../patches/cof-vid-restart-background.md) |
| 11 | `apply-cof-ui-menu-map-redirect` | `cof-ui-menu-map-redirect` | E | [menu-map redirect](../patches/cof-ui-menu-map-redirect.md) |
| 12 | `apply-cof-ui-sound-volume` | `cof-ui-sound-volume` | E | [menu sound volume](../patches/cof-ui-sound-volume.md) |
| 13 | `apply-cof-console-variable-font-fallback` | `cof-console-variable-font-fallback` | E | [console font fallback](../patches/cof-console-variable-font-fallback.md) |
| 14 | `apply-cof-console-style` | `cof-console-style` | E | [styled console](../patches/cof-console-style.md) |
| 15 | `apply-cof-ui-death-flow` | `cof-ui-death-flow` | E | [death flow](../patches/cof-ui-death-flow.md) |
| 16 | `apply-cof-levelshot-guard` | `cof-levelshot-guard` | E | [levelshot guard](../patches/cof-levelshot-guard.md) |
| 17 | `apply-cof-text-autoscale` | `cof-text-autoscale` | E | [text autoscale](../patches/cof-text-autoscale.md) |
| 18 | `apply-cof-mp3-stop-on-map` | `cof-mp3-stop-on-map` | E | [MP3 stop](../patches/cof-mp3-stop-on-map.md) |
| 19 | `apply-cof-sky-reset-per-map` | `cof-sky-reset-per-map` | E | [sky reset](../patches/cof-sky-reset-per-map.md) |
| 20 | `apply-cof-cofenhanced-version` | `cof-cofenhanced-version` | E | [build stamp](../patches/cof-cofenhanced-version.md) |
| 21 | `apply-cof-ui-scale` | `cof-ui-scale` | E | [UI scaling](../design/ui-scaling.md) |
| 22 | `apply-cof-vgui-anchor` | `cof-vgui-anchor` | V | [UI scaling](../design/ui-scaling.md) |
| 23 | `apply-cof-vgui-inter-fonts` | `cof-vgui-inter-fonts` | E + V | [VGUI Inter fonts](../design/vgui-inter-fonts.md) (the script also copies `stb_truetype.h` from MainUI into FreeVGUI) |
| 24 | `apply-cof-ui-death-live` | `cof-ui-death-live` | E | [death flow](../patches/cof-ui-death-flow.md) section 8 |
| 25 | `apply-cof-hud-text-backing` | `cof-hud-text-backing` | E + V | [HUD text](../patches/cof-hud-text-legibility.md) |

The one trap in this group: the styled console (14) must go on **before** the
death flow (15), whose hunks use the console's `console.c` lines as context.
The old README listed the death flow first in its prose; reading its code
blocks top to bottom failed at step 15.

### Renderer (`ref/gl`)

| # | Script | Patch | Target | Doc |
| ---: | --- | --- | --- | --- |
| 26 | `apply-cof-gl-stage-trace` | `cof-gl-stage-trace` | R | [GL stage trace](../patches/cof-gl-stage-trace.md) |
| 27 | `apply-cof-solid-entity-trace` | `cof-solid-entity-trace` | R | [solid-entity trace](../patches/cof-solid-entity-trace.md) |
| 28 | `apply-cof-transparent-triangle-trace` | `cof-transparent-triangle-trace` | R | [transparent-triangle trace](../patches/cof-transparent-triangle-trace.md) |
| 29 | `apply-cof-skyline-trace` | `cof-skyline-trace` | R | [skyline trace](../patches/cof-skyline-trace.md) |
| 30 | `apply-cof-gl-debug-stack` | `cof-gl-debug-stack` | R | [GL debug stack](../patches/cof-gl-debug-stack.md) |
| 31 | `apply-cof-custom-renderfx-opaque` | `cof-custom-renderfx-opaque` | R | [renderfx opaque](../patches/cof-custom-renderfx-opaque.md) |

The GL debug stack page says "before the entity/transparent and skyline
diagnostics"; the verified order puts it after them (30), and that is the
order that is known to apply.

### Menu (MainUI)

| # | Script | Patch | Target | Doc |
| ---: | --- | --- | --- | --- |
| 32 | `apply-cof-mainui-menu-save` | `cof-mainui-menu-save` | M | [MainUI menu save](../patches/cof-mainui-menu-save.md) |
| 33 | `apply-cof-mainui-background-scrim` | `cof-mainui-background-scrim` | M | [milestone 1](../patches/cof-ui-m1-plumbing.md) |
| 34 | `apply-cof-mainui-cof-menu` | `cof-mainui-cof-menu` | M | [milestone 2](../patches/cof-ui-m2-cof-menu.md) |
| 35 | `apply-cof-mainui-source-theme` | `cof-mainui-source-theme` | M | [UI theme](../design/ui-theme.md) |

### Milestone 5: field of view, crouch fix

| # | Script | Patch | Target | Doc |
| ---: | --- | --- | --- | --- |
| 36 | `apply-cof-fov` | `cof-fov` | E | [field of view](../patches/cof-fov.md) (no ordering constraint inside the engine stack) |
| 37 | `apply-cof-pmove-callback-view` | `cof-pmove-callback-view` | E | [pmove callback view](../patches/cof-pmove-callback-view.md) (needs only steps 0-1) |
| 38 | `apply-cof-viewmodel-fov` | `cof-viewmodel-fov` | R | [field of view](../patches/cof-fov.md) |

### Milestone 5b: aim down sights, chapter rule, sprite frames

| # | Script | Patch | Target | Doc |
| ---: | --- | --- | --- | --- |
| 39 | `apply-cof-ads-toggle` | `cof-ads-toggle` | E | [ADS and binds](../patches/cof-ads-toggle.md) |
| 40 | `apply-cof-chapter-rule` | `cof-chapter-rule` | E | [ADS and binds](../patches/cof-ads-toggle.md) section 4 |
| 41 | `apply-cof-sprite-quiet-frames` | `cof-sprite-quiet-frames` | R | [sprite frames](../patches/cof-sprite-quiet-frames.md) (last `ref/gl` patch) |

### Milestone 6: language packs

| # | Script | Patch | Target | Doc |
| ---: | --- | --- | --- | --- |
| 42 | `apply-cof-language-packs` | `cof-language-packs` | E + V | [language packs](../design/language-packs.md) (generated on top of 39-40) |
| 43 | `apply-cof-mainui-language-selector` | `cof-mainui-language-selector` | M | [language packs](../design/language-packs.md) section 7 |
| 44 | `apply-cof-mainui-menu-strings` | `cof-mainui-menu-strings` | M | [language packs](../design/language-packs.md) section 8 |

### Co-op bridge, the notifications option, the options relayout, the on-screen keyboard and window name, quick saves, the panels, the gamepad, field navigation and controls, then the cheats last

| # | Script | Patch | Target | Doc |
| ---: | --- | --- | --- | --- |
| 45 | `apply-cof-coop-bridge` | `cof-coop-bridge` | E + V | [co-op bridge](../design/coop-bridge.md) |
| 46 | `apply-cof-mainui-coop` | `cof-mainui-coop` | M | [co-op bridge](../design/coop-bridge.md) (shares no file with 43-44) |
| 47 | `apply-cof-notify-option` | `cof-notify-option` | E + M | [UI theme](../design/ui-theme.md), Game page (`cof_notify`); needs 14-17 and 43 |
| 48 | `apply-cof-mainui-options-layout` | `cof-mainui-options-layout` | M | [UI theme](../design/ui-theme.md), "Options relayout"; needs 35, 43, 44, 46, 47 |
| 49 | `apply-cof-mainui-osk` | `cof-mainui-osk` | M | [on-screen keyboard](../design/osk.md) (the key grid, menu text fields, `menu_cof_osk`); needs 48 |
| 50 | `apply-cof-osk-engine` | `cof-osk-engine` | E + V | [on-screen keyboard](../design/osk.md) (the game's text fields: `cof_osk`, vguiapi_t `CofOskEntry`/`CofOskCall`); needs 9, 40, 42; before 55-57 |
| 51 | `apply-cof-client-enter-hook` | `cof-client-enter-hook` | E | [on-screen keyboard](../design/osk.md), "The Enter hook" (client.dll `GetAsyncKeyState`, `cof_enter_pulse`, START = Enter); needs 42, 50 |
| 52 | `apply-cof-window-name` | `cof-window-name` | E | [building](building.md), "The game's name in Windows" (window title and class); upstream lines only |
| 53 | `apply-cof-quicksave` | `cof-quicksave` | E | [quick save](../patches/cof-quicksave.md) (`cof_quick_saves`, `cof_quicksave` / `cof_quickload`, the message strip lines); needs 5, 7, 15, 36 |
| 54 | `apply-cof-mainui-quicksave` | `cof-mainui-quicksave` | M | [quick save](../patches/cof-quicksave.md) (Load list row, first pause item, Game tab checkbox, Keybinds rows, defaults generation 5); needs 32, 35, 48 |
| 55 | `apply-cof-panel-pause` | `cof-panel-pause` | E + V | [panel pause](../patches/cof-panel-pause.md) (`cof_panel_pause`; the client's panels identified by class); needs 22, 24, 42 |
| 56 | `apply-cof-panel-transparency` | `cof-panel-transparency` | E + V | [world behind the panels](../patches/cof-panel-transparency.md) (`cof_panel_transparent`); needs 22, 23, 25, 55 |
| 57 | `apply-cof-gamepad-input` | `cof-gamepad-input` | E + V + M | [gamepad input](../patches/cof-gamepad-input.md) (layout generation 4, quick turn, trigger hysteresis, stick movement, pad styles; `menus/LoadGame.cpp` / `CoFOptions.cpp`: A on a save row, the last input device); needs 9, 14, 21, 39, 48, 54 (its `LoadGame.cpp` lines are context) and 55 (the panel check reads the panel identity of 55), 56 |
| 58 | `apply-cof-osk-field-navigation` | `cof-osk-field-navigation` | E + V | [OSK field navigation](../design/osk.md); Done advances within the same form, last field submits; needs 50-51 |
| 59 | `apply-cof-gamepad-controls` | `cof-gamepad-controls` | E + M | [gamepad round 4 controls](../patches/cof-gamepad-controls.md); generation 5: RB dodge, R3 quick turn, pad-only double-tap suppression; needs 57 |
| 60 | `apply-cof-osk-compact-context` | `cof-osk-compact-context` | E + V + M | [compact OSK and field context](../design/osk.md); smaller keyboard, field number, Done never submits; needs 58 |
| 61 | `apply-cof-osk-dismiss-guard` | `cof-osk-dismiss-guard` | E | [OSK dismissal guard](../design/osk.md); hold closing Enter/Start until release; needs 51, 60 |
| 62 | `apply-cof-vcursor-shadow-source` | `cof-vcursor-shadow-source` | E | [cursor shadow](../patches/cof-vcursor-shadow-source.md); preserve alpha through texture upload; needs 57 |
| 63 | `apply-cof-hud-text-style` | `cof-hud-text-style` | E + V | [Bold grey message text](../patches/cof-hud-text-style.md); soft shadow, independent optional background off by default; needs font/message patches |
| 64 | `apply-cof-mainui-compact-scale` | `cof-mainui-compact-scale` | M | [compact menus](../patches/cof-mainui-compact-scale.md); 12% smaller, keyboard size preserved; needs 60 |
| 65 | `apply-cof-mainui-hud-style` | `cof-mainui-hud-style` | M | [HUD selector](../patches/cof-mainui-hud-style.md); Classic/Remake, disabled if renderer missing |
| 66 | `apply-cof-hud-remake` | `cof-hud-remake` | E | [optional Remake HUD](../patches/cof-hud-remake.md); Classic default; needs 63 |
| 67 | `apply-cof-hud-ammo-state` | `cof-hud-ammo-state` | E | [all stock equipment and direct ammunition state](../patches/cof-hud-ammo-state.md); needs 66 |
| 68 | `apply-cof-hud-stamina-layout` | `cof-hud-stamina-layout` | E | [larger stamina bar and relocated dodge flash](../patches/cof-hud-stamina-layout.md); needs 66 |
| 69 | `apply-cof-selection-list` | `cof-selection-list` | M | [dropdowns and complete controller traversal](../patches/cof-selection-list.md); needs 64-65 |
| 70 | `apply-cof-pad-move-diagnostics` | `cof-pad-move-diagnostics` | E | [optional movement trace](../patches/cof-pad-move-diagnostics.md); observes input without changing speed |
| 71 | `apply-cof-panel-escape` | `cof-panel-escape` | E + V | [close active pane before Pause](../patches/cof-panel-escape.md); needs 57 |
| 72 | `apply-cof-pad-digital-speed` | `cof-pad-digital-speed` | E | [Digital movement correction](../patches/cof-pad-digital-speed.md); needs 70 |
| 73 | `apply-cof-hud-ammo-compact` | `cof-hud-ammo-compact` | E | [compact boxed ammunition](../patches/cof-hud-ammo-compact.md); needs 67 |
| 74 | `apply-cof-pad-upgrade-settings` | `cof-pad-upgrade-settings` | E | [upgrade settings](../patches/cof-pad-upgrade-settings.md); preserve existing gyro preferences; needs 59 |
| 75 | `apply-cof-hud-boss-style` | `cof-hud-boss-style` | E | [Remake boss health](../patches/cof-hud-boss-style.md); match player health colors and bar style; needs 66 |
| 76 | `apply-cof-cheats` | `cof-cheats` | E | [cheats internals](../design/cheats.md); **always last**, needs steps 2 and 4 |

## After applying

1. `scripts\write-cof-version.ps1` writes the generated, uncommitted
   `engine/cof_version.h` for the build stamp (step 20); without it the stamp
   reads `dev`.
2. Build as described in [building](building.md). Which binaries change with
   which patches: E -> `xash.dll`, R -> `ref_gl.dll`, V -> `vgui.dll`,
   M -> `cryoffear/cl_dlls/menu.dll`. `xash.dll` and `vgui.dll` must always be
   deployed together (steps 21, 23, 25, 42, 45, 50, 55, 56 and 57 all edit the shared
   `engine/vgui_api.h` interface). Step 58 also requires its matching engine and
   FreeVGUI pair for the new field-navigation operation.

## Verifying a stack

Copy the latest `stage1/*/stackverify-*.ps1` and extend it rather than writing
a new one. What they do, and what a new round must keep doing:

1. Copy `pristine-clean`, add FreeVGUI (`git archive HEAD` of the live
   checkout) and MainUI (clone, detach at `61263995…`).
2. Apply every step above in order through its script.
3. For each patch the round regenerated or added: hash its files, reverse it
   with `git apply --reverse`, prove the files are back to the pre-apply hash,
   re-apply, prove they match the post-apply hash, then run the script's own
   `-Reverse` and apply again.
4. Compare `engine/`, `ref/`, `3rdparty/freevgui/` and `3rdparty/mainui/` with
   the private tree the staged binaries were built from, CR-stripped, ignoring
   `build-*`, `.git` and the generated `engine/cof_version.h`. The result must
   be "DIFFERENT: none".

Nothing is built by a verifier, and nothing outside its work folder is written.
