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
SHA-256: 977008A7E49C05B17EFA2750CC633674E8CF8D150E012A0022B8E3FA34A06AD1
PDB SHA-256: 502E22ED0893421427BF67CCDECAAADDD9E1E4D42AF7CD6735BA01489D5EAEC7
```

The rebuilt renderer module from the same output is:

```text
build-cof-savecompat\ref\gl\ref_gl.dll
SHA-256: 253B24DC91F2CAEE4E88E45A28447C17455E7EA6D6413F19167F377CAC92DD99
PDB SHA-256: C7909837DC04BE13D5709509746AF62AF2008A064DFA894B0B0BA7417D95A3AC
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

The trace consumes one `glGetError` result at each existing boundary. A label
narrows the renderer/client stage that left the error pending; it does not
identify the individual OpenGL call. The default remains unchanged when the
cvar is `0`. This checkpoint is intended to distinguish world/entity draws
from client triangle, effects, transparent, and view-model stages after the
controlled `r_drawentities 0` reproduction.
