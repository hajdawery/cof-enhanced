# Compact MainUI scale

The options window previously occupied about 88.5% of the screen height on
4:3 and wider displays. The default now uses 77.9%, leaving more of the game
visible around it. Main menu, pause menu, tabs, dialogs, controls, text, and
their hit rectangles share a 12% reduction. The existing OSK retains its
separately tuned gamepad5 size.

## Configuration and patch order

Apply `scripts/apply-cof-mainui-compact-scale.ps1` after the compact OSK and
other current menu patches, before the final cheats patch. Only MainUI is
changed; a subsequent requested build needs `menu.dll`.

`ui_cof_menu_scale` is archived, defaults to `0.88`, and accepts `0.75` to
`1.0`. `1` restores the previous menu dimensions. Values outside that range
are clamped for layout, and NaN falls back to the default. It is sampled at
`UI_VidInit`: restart the game or reinitialize the video mode after changing
it. It is deliberately not applied dynamically between layout and drawing,
which would leave stale mouse hit rectangles.

The reduction applies only to Cry of Fear with the Source theme active.
Other game menus and `ui_theme 0` retain their existing scale. This setting
does not alter the engine console or the game's HUD, inventory, or phone.

## Implementation

`Theme.cpp` registers the cvar and implements `UI_ThemeApplyMenuScale`.
`BaseMenu.cpp` calls it once after resetting the aspect-ratio scale and
before computing the virtual width, fonts, and menu layout. Both scale axes
use the same multiplier. Recomputing `yOffset` keeps the 768-unit canvas
vertically centered; the existing width/PanelPos logic keeps dialogs
horizontally centered. Resolution changes start from the base scale again,
so the multiplier cannot accumulate.

`menus/CoFOsk.cpp` uses a scoped restoration of the pre-menu scale during
layout, drawing, and keyboard/mouse activation. All keyboard key metrics,
preview text, title chrome, close-button hit area, and prompt rows therefore
keep the gamepad5 physical sizes. The scope restores the exact captured
scale values on exit, including early returns, and only the outermost nested
scope removes the menu multiplier. Its title drawing calls the
shared theme helpers under that same scope. No OSK constants are reduced a
second time.

## Verification and limits

Run the source-level geometry audit without compiling or launching anything:

```powershell
python tests/cof-mainui-compact-scale/check_geometry.py --source-root <patched-tree>
```

Verified the source placement/guards, actual tab-frame and keyboard metrics,
centered bounded options rectangles at eight resolutions (640x480 through
4K, ultrawide, 5:4, and portrait), three scale settings, and unchanged OSK
geometry/restoration across repeated scopes. The compiled OSK layout harness passed using actual multipliers 0.75, 0.88,
and 1, the actual key handler and theme title renderer, nested scopes, and
early returns. Title-band height and close-button hit areas match the
restored keyboard geometry. The inactive/non-CoF path returns without
touching stock scale or offset values. Patch apply/reverse/reapply and inverse checks
passed on a private sparse source tree.

No menu/engine build, game launch, deployment, or screenshot comparison was
performed; only the isolated layout contract harness was compiled.
The source geometry checks do not establish visual quality with real fonts;
that remains a runtime verification item after an authorized build.
