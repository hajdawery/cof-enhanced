# CoF pause-save file-list plumbing

This opt-in patch narrows the existing `cof_save_root_compat` behavior to the
GameUI save enumeration and comment reader used by the pause/load UI.

When the cvar is enabled, the loaded game folder is exactly `cryoffear`, and
the requested file pattern is case-insensitively exactly `save/*.sav`,
`CL_GetFilesList` searches `SAVE/*.sav` with `caseinsensitive=true` and
`gamedironly=false`. Every other file-list request keeps its original pattern
and flags.

`SV_GetSaveComment` calls the existing `SV_SaveFSOpen` read adapter. This keeps
the root-save translation and the normal non-CoF path in one place; no
preview/screenshot path is changed.

Apply after `cof-save-root-compat.patch` with:

```powershell
pwsh -NoProfile -File scripts/apply-cof-pause-save-plumbing.ps1 `
  -SourceRoot <source-tree>
```

The script requires the source tree to be inside this project, checks the
existing root-save adapter, performs a forward `git apply --check`, applies the
patch, and verifies its markers. `-Reverse` performs the corresponding reverse
check and removes the changes. No build or runtime test is part of this patch.

The original stock client contains `SAVE/saveinfo1.cof` through
`saveinfo5.cof`, `cofload 1` through `cofload 5`, and the original server DLL
contains `load cofsave1` through `load cofsave5`. This patch only makes the
engine-side list/comment lookup see the stock root `SAVE` directory; it does
not add or enable a pause save UI.
