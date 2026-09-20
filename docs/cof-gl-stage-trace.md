# CoF renderer GL stage trace

The optional `patches/cof-gl-stage-trace.patch` adds the renderer cvar
`cof_gl_trace`, defaulting to `0`. It labels the existing OpenGL error checks
around `R_DrawEntitiesOnList`; it does not change draw order, clear errors, or
disable a renderer stage. Apply it to the pinned FWGS source with:

```powershell
.\scripts\apply-cof-gl-stage-trace.ps1 `
  -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

The script validates the source root, performs a clean forward check, applies
the patch, and reverse-checks it. It does not use `--unsafe-paths`.

Build with the already configured diagnostic output directory:

```powershell
python waf build -j8
```

The verified cumulative engine output (including the opt-in save-root
compatibility work) is:

```text
build-cof-savecompat\engine\xash.dll
SHA-256: 7BA9DD02B20CF5FE5A9006A124BC1E9215DE86D52C646EF04EE7F0471CCAF182
PDB SHA-256: CC5A24A42863F60F820AA644A87DAE60061E1457C5B44A0564D88AAD18538BB8
```

The rebuilt renderer module from the same output is:

```text
build-cof-savecompat\ref\gl\ref_gl.dll
SHA-256: 8F24567D129BA1199D8AFD4805DA8030E52C548382BD53A99927C0633ADBFDB6
PDB SHA-256: 20575ED86AE5D3CC82003252CC76D54D9B2086E1C6F00F0153B0BFF2B9EBC176
```

`cof_gl_trace` is registered during renderer initialization. For a diagnostic
run, enable `developer`, `gl_check_errors 1`, and
`cof_gl_trace 1` in the isolated test copy. The labels identify the first
boundary that still reports an error among:

`before_solid_entities`, `after_solid_entities`,
`after_alpha_texture_chains`, `after_solid_sprites`, `after_solid_efx`,
`after_client_normal_triangles`, `after_trans_entities`,
`after_client_transparent_triangles`, `after_transparent_efx`, and
`after_viewmodel`.

The beam renderer adds three more boundaries: `beams_before_server`,
`beams_after_server`, and `beams_after_temp`. These bracket the server beam
entity loop and active temporary beam loop used by `CL_DrawEFX`.

The trace also checks safe TriAPI boundaries used by the original client DLL:
`triapi_render_mode`, `triapi_end`, `triapi_sprite_texture`, `triapi_fog`,
`triapi_get_matrix`, `triapi_cull_face`, and `triapi_brightness`. It never
calls `glGetError` between `TriBegin` and `TriEnd`, where OpenGL forbids it.
An error labeled `triapi_end` belongs to the completed client TriAPI batch;
if only `after_client_normal_triangles` remains, the client used direct OpenGL
or another uninstrumented API in that callback.

`cof_skip_client_normal_triangles` is a separate default-off diagnostic. It
skips only the original client DLL's normal-triangle callback; it is not a
compatibility fix and must not be enabled for ordinary play. It distinguishes
the callback's own pixels from later HUD drawing before any state workaround is
considered.

The trace consumes one `glGetError` result at each existing boundary. A label
narrows the renderer/client stage that left the error pending; it does not
identify the individual OpenGL call. The default remains unchanged when the
cvar is `0`. This checkpoint is intended to distinguish world/entity draws
from client triangle, effects, transparent, and view-model stages after the
controlled `r_drawentities 0` reproduction.
