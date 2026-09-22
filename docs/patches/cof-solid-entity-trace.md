# CoF solid-entity GL trace

This is an off-by-default diagnostic prerequisite for the skyline trace. It
checks `glGetError` before and after each solid entity draw and reports the
entity index, model name/type, studio callback selection, and error string.
It does not change the draw path while `cof_solid_entity_trace` remains `0`.

Apply from the project root to a disposable FWGS checkout inside this project:

```powershell
& .\scripts\apply-cof-gl-stage-trace.ps1 -SourceRoot .\xash3d-fwgs-<revision>
& .\scripts\apply-cof-solid-entity-trace.ps1 -SourceRoot .\xash3d-fwgs-<revision>
```

The helper confines the source path to this project, checks the expected
markers after application, and performs an opposite-direction `git apply
--check`. Use `-Reverse` only to remove the diagnostic from the same checkout.
The helper does not use `--unsafe-paths` or change global Git settings.

This patch is source-level diagnostic instrumentation only. No runtime result
is implied by the patch or helper.
