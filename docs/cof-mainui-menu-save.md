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
enabled at runtime. This source checkpoint does not claim a completed GUI
runtime test, visual parity, or phone/pause behavior.

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
