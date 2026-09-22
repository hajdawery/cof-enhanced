# Cry of Fear console variable-font fallback

Cry of Fear's `gfx.wad` provides `CONCHARS` as an oldstyle variable-width FNT
atlas. When the modern `fontN` files are unavailable, the unpatched console
loader falls through to the Quake fixed-grid `gfx/conchars` loader. That
interprets the CoF atlas as a 16-by-16 grid of equal square cells (256 glyph
slots) and produces incorrect glyph regions in console notifications and
screenshot version text.

`patches/cof-console-variable-font-fallback.patch` adds one fallback before
the existing fixed-grid final fallback: it tries `gfx/conchars.fnt` through
`Con_LoadVariableWidthFont`. It leaves the `con_oldfont` branch unchanged and
retains the fixed-grid fallback for games that do not provide an FNT resource.
The standard engine default stays `con_oldfont 0`.

Apply it to the pinned source tree with:

```powershell
.\scripts\apply-cof-console-variable-font-fallback.ps1 `
  -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

The script validates the source location, refuses an already-patched tree,
checks that the patch applies before changing files, and reverse-checks the
applied result. It never enables direct paths or touches game assets.

Runtime evidence from the isolated CoF fixture showed that `con_notifytime 0`
removed the top orange bands, `scr_drawversion 0` removed the bottom band, and
`con_oldfont 1` rendered both overlays legibly. The orange color is the engine
default `con_color` value (`240 180 24`). A patched default-branch run with
`con_oldfont 0`, `con_notifytime 3`, and `scr_drawversion 1` also rendered both
overlays legibly (engine SHA-256
`680DCD7FCBB5F31DCCA568DFB92ADE465B75A0814D23BB5AB487E09FF2318F1B`; frame
SHA-256 `CA541FA797CD60B61666F73AEC5D420F2AB2D7AABCD28B6139A4FE4E79129D94`;
log SHA-256
`9E83FCCC892C815806976A148298D0C7CB85955C296C29CB290A9E7A4D334200`).
This supports the automatic variable-width fallback when modern console fonts
are not present. It does not resolve unrelated client callback OpenGL errors
or prove the menu slot-click sequence; the command-only `cofload` harness
omits the original client panel-hide and unfreeze steps.
