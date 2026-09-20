# Skyline trace renderer

`cof_skyline_trace` defaults to `0`. When set to `1`, the renderer emits at most 32 `[cof-skyline]` lines and only for `models/Props/Blandat/byggnader.mdl`. Lines record studio entry, entity state, transformed sequence bounds, and the studio frustum-cull result. The trace does not change drawing.

Apply the separate GL-stage trace first, then apply this patch to the same
pinned source checkout:

```powershell
.\scripts\apply-cof-skyline-trace.ps1 `
  -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

The helper confines the checkout to this project, requires the earlier
`cof_gl_trace` marker, checks the three expected source files, verifies the
skyline markers after application, and reverse-checks the patch. Use
`-Reverse` only on a tree where this skyline patch is already applied. No
`--unsafe-paths` or global Git settings are used.

The separate artifact bundle is `artifacts/skyline-tracebundle-20260920/`; do not replace a runtime renderer automatically. For a manual menu capture, place its `ref_gl.dll` and matching PDB in an isolated test copy, launch `c_game_menu1`, set `cof_skyline_trace 1`, and retain the console log. A missing `entry` line means the model did not reach this studio dispatch; an `entry` followed by `cull=1` identifies studio frustum culling. The trace does not report PVS because no PVS result is available at this dispatch point.
