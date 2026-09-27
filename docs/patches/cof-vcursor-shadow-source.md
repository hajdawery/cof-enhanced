# Cursor shadow source pixels

`cof-vcursor-shadow-source.patch` is an additive engine-only fix after the
gamepad controls patch. It does not change the supplied cursor PNG or renderer.

## Cause

The square cursor loader passed its decoded RGBA buffer directly to
`GL_LoadTextureInternal` and then read that same buffer to build a black shadow.
The GL renderer's `GL_UploadTexture` uses that buffer directly when no resample
is needed. Its `GL_BuildMipMap` explicitly works in place, packing smaller mip
levels into the beginning of the buffer. Reading the buffer as the original
128 by 128 image afterward turns those packed mip pixels into spurious shadow
across the upper rows. This explains the gray/black protrusion above the square
reported after the missing cursor art was deployed.

The source PNG was inspected and has no such protrusion. Its bytes stay
unchanged: SHA-256 `F32A42BF828DF4D4424EA10CEDC5E0007B15ADE268718554AD16C7FB7A6911FD`.

## Fix and controls

Upload the visible cursor from a temporary RGBA copy and free the copy after
the synchronous upload. Build the shadow from the untouched decoded source.
This costs 64 KiB temporarily for the supplied 128 by 128 cursor, only when
loading its texture or after renderer restart. Texture caching, scale, mipmaps,
blur and opacity remain as before. `cof_vcursor_shadow 0` already disables the
shadow; no new cvar is needed to preserve that option.

## Verification

`tests/cof-vcursor-shadow/run.py` extracts the actual patched C loader and
compiles a small MSVC harness with a deliberately destructive texture-upload
stub. It verifies that the visible art upload still receives the exact PNG
pixels and all shadow pixels match an independent dilation/blur reference.
The harness also checks cached texture reuse, reloading after texture loss,
and balanced temporary allocations. The old loader fails the shadow-pixel
comparison; the patched loader passes. Apply/reverse/apply checks pass.

No game was launched for this check. The visual result at different HUD scales
and on the user's renderer remains a manual runtime check after integration.
