# HUD: Classic / Remake selector

The Game options tab has a **HUD** selector with **Classic** and **Remake**.
It shares the right-hand row with HUD scale, while Language keeps the left
column. No extra row is added. The two controls each have a 213-unit-wide
frame (153 units between their arrows) in the current 960-unit tab layout.

The renderer owns archived `cof_hud_style`: `0` is Classic and its default;
`1` is Remake. This menu patch does not implement the Remake renderer or
register a substitute cvar. With a supporting engine, selection writes the
value immediately; the existing Close/config-save path persists archived
settings. Reopening the page reads the saved selection. An engine reset to
its default reads back as Classic.

A page reload guards the spinner's change event, so opening/reopening/reset
never writes a value merely to synchronize the widget. Unknown cvar values
are displayed as Classic without rewriting the stored value. A missing
renderer cvar shows disabled Classic. Only valid 0/1 user choices are
written. Other games and the legacy options layout are untouched.

## Patch and verification

`cof-mainui-hud-style` is additive after the current CoF options/menu patches,
before final cheats. It changes only `3rdparty/mainui/menus/AdvancedControls.cpp`.
Apply using `scripts/apply-cof-mainui-hud-style.ps1`. A future authorized
MainUI build produces `menu.dll`; engine rendering support is a separate patch.
The three menu translation keys are `HUD`, `Classic`, and `Remake`.

Probe without OS input injection:

```text
menu_cof_options_select game hudstyle
menu_cof_options_select game hudstyle 0
menu_cof_options_select game hudstyle 1
```

The probe uses the selector's normal change callback, rejects other values,
and reports the selection/cvar. Close uses the existing page mechanism.

The isolated compiled test extracts the actual model, reload, and change
methods and simulates the spinner's real behavior of emitting QM_CHANGED on
programmatic changes:

```powershell
python tests/cof-mainui-hud-style/run.py --source-root <patched-tree> --out <scratch>
```

Passed Classic default, both mappings, immediate writes, reopen, resetting
the renderer cvar to Classic, missing support, invalid values, reload-event
guards, and non-CoF/legacy guards. Patch apply/reverse/reapply and inverse
checks passed. Row geometry keeps the previous vertical placement and both
selectors inside the existing right column.

No full menu/engine build, game launch or deployment was performed for this
worker implementation. These tests cover the selector contract, not the
Remake renderer or visual readability with every translated font.
