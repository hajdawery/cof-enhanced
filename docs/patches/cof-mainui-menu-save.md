# CoF MainUI menu-save integration

This experimental MainUI change connects the optional backend to the existing
Save/Load menu for the Cry of Fear game folder. It is based on the nested
FreeVGUI/MainUI repository at revision
`61263995592e93a278d764807243d043d3b97c54` and changes only
`menus/LoadGame.cpp` and `menus/SaveLoad.cpp`. The unrelated nested `miniutl`
change in the working tree is excluded.

The feature is disabled by default through `cof_pause_menu_saves 0`. When the
user enables it, the menu enumerates the original five `cofsave1` through
`cofsave5` slots, reads their `SAVE/saveinfoN.cof` labels, and sends the
server-side `cof_menu_save <1..5>` command. Existing slots show a separate
overwrite confirmation. Delete remains unavailable for these shared slots;
the original tape-recorder save path remains the owner of the same five slots.
The backend must already be applied, and root-save compatibility must be
enabled at runtime. A later direct-GUI check covered a native tape save/load in
slot 3 and an enabled pause-menu save/load in slot 4. Those are focused
user-observed routes in the K-only test deployment; they do not validate every
slot, preview, renderer state, phone flow, or pause-menu surface. The current
source build still needs a focused GUI check of its toggle marker, `Slot` /
`Save` / `Date` columns, and `No preview` fallback.

The CoF toggle keeps the native checkbox interaction and cvar link, while
also drawing an explicit `ON` or `OFF` text marker so its state remains
visible when the deployment lacks the optional `gfx/shell/cb_*` checkbox
textures. CoF save rows use `Slot`, `Save`, and `Date` headings matching their
slot label, save label, and timestamp fields. A missing CoF screenshot shows
neutral `No preview` text; the existing fallback preview remains unchanged for
non-CoF save menus. Existing localization strings are otherwise unchanged.

Apply from the outer FWGS source checkout with:

```powershell
pwsh -NoProfile -File scripts/apply-cof-mainui-menu-save.ps1 `
  -SourceRoot <fwgs-source-tree>
```

The helper requires the source tree to be inside this project, verifies the
nested MainUI repository is exactly at the pinned baseline, applies only the
two listed files, checks inserted markers, and supports a checked reverse
application with `-Reverse`. A disposable nested-submodule fixture passed
forward application, reverse checking, and reverse application.
