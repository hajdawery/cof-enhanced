# CoF GL debug stack helper

This Windows-only diagnostic extends the GL debug callback with bounded native
stack samples for two observed error messages: a negative-count message and an
invalid face-culling-mode message. It records up to 12 frames and two samples
per message class. Sampling remains gated by `cof_gl_trace`; the helper is
inactive when that cvar is `0`. The module path is forced to terminate before
it is used for the log name.

Apply it after the GL-stage trace patch and before the entity/transparent and
skyline diagnostics:

```powershell
& .\scripts\apply-cof-gl-stage-trace.ps1 -SourceRoot .\xash3d-fwgs-<revision>
& .\scripts\apply-cof-gl-debug-stack.ps1 -SourceRoot .\xash3d-fwgs-<revision>
```

The helper confines the source path to this project, requires the GL-stage
markers, verifies the helper and bounded-sampling markers, and performs an
opposite-direction `git apply --check`. Use `-Reverse` only on the same
checkout. It does not use `--unsafe-paths` or global Git settings.

The frozen diagnostic build provenance supplied for this stack was the older
source snapshot with digest
`C93ACE1D950274A6B327714753E7CB6C819CD1B1C15004F91575BB192CD0A412`.
This patch adds defensive path termination on top of that snapshot; it does
not claim byte-for-byte identity with the older source or its binary. Terra
rebuilt the current source with that termination separately. The builds and
PDBs remain outside Git; this repository contains only the source patch and
application helper. The stack trace is diagnostic evidence, not a renderer
behavior change, and this patch intentionally does not include the later
world-polygon probe or any binary artifacts.
