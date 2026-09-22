# CoF transparent-triangle trace prerequisite

This is an off-by-default diagnostic prerequisite for the skyline trace. It
adds `cof_skip_client_transparent_triangles`, defaulting to `0`, around the
client transparent-triangle callback. With the default value the existing
callback is still invoked; setting it to `1` is a diagnostic isolation switch,
not a renderer fix.

Apply after the GL-stage and solid-entity prerequisites:

```powershell
& .\scripts\apply-cof-gl-stage-trace.ps1 -SourceRoot .\xash3d-fwgs-<revision>
& .\scripts\apply-cof-solid-entity-trace.ps1 -SourceRoot .\xash3d-fwgs-<revision>
& .\scripts\apply-cof-transparent-triangle-trace.ps1 -SourceRoot .\xash3d-fwgs-<revision>
```

The helper confines the source path to this project, requires the earlier
markers, verifies the new header/registration/callback markers, and performs
an opposite-direction `git apply --check`. Use `-Reverse` only on the same
checkout. It does not use `--unsafe-paths` or global Git settings.

This patch is source-level diagnostic instrumentation only. No runtime result
is implied by the patch or helper.
