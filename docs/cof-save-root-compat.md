# Cry of Fear root `SAVE` compatibility

The stock Cry of Fear installation keeps `SAVE\` beside the game directory,
while Xash normally resolves the engine save directory as `cryoffear\save\`.
The compatibility patch is opt-in through the engine cvar
`cof_save_root_compat 1`. It activates only when the loaded game folder is
`cryoffear`.

With the cvar enabled, the server save implementation translates its existing
`save/` paths to the runtime-root `SAVE/` directory for reads and to
`../SAVE/` for writes, deletes, and renames. Direct paths are enabled only for
those translated write operations, then immediately disabled. A root-compat
`saveshot` name must be a nonempty basename without slash, backslash, or drive
separators; the screenshot writer rechecks the final
`../SAVE/<name>.bmp` path before enabling direct paths. Save-file enumeration
and `saveshot` use the same location; the screenshot writer
temporarily enables the same direct-path mode for the saveshot operation. The normal default remains
the existing game-directory save path.

Apply the existing menu-load trace patch first, then apply
`scripts/apply-cof-save-root-compat.ps1`. The save patch is intentionally based
on that source state so its forward and reverse checks remain reproducible.
Then configure and build with the normal client profile, for example:

```powershell
python waf configure -4 --out=build-cof-savecompat --sdl2="..\prereq\sdl2-2.30.9-vc\SDL2-2.30.9" -T release --notests --disable-mbedtls --enable-cof-entvars-legacy
python waf build -j8
```

The isolated validation run used the resulting `engine\xash.dll` (SHA256
`73B83DA28AE169A320742C090FE8CE480332B139D32CE5472D4D2424BBAF45C8`) with
`-game cryoffear -cof-pmove-legacy +set cof_save_root_compat 1`, dispatched
`cofload 1` after signon, and loaded the preserved stock
`SAVE\cofsave1.sav` (SHA256
`9B95AEF173B008B6F7712084591FD8A4D1517E70C9DBBA07A44AFEEE4D43ED9C`). The
trace recorded `SV_LoadGame entry: save/cofsave1.sav`, `load accepted:
map=c_forest3`, a second `c_forest3` signon, and extraction of
`c_forest2.HL1` into the root `SAVE` directory. A save probe also created
`SAVE\rootcompat_probe2.sav` and `SAVE\rootcompat_probe2.bmp` in the
isolated root.

A traversal regression probe issued `delete ../../escape_probe` from the
isolated `cryoffear` game directory; the sentinel outside `SAVE` remained
present. `saveshot` rejects `../../escape`, `sub/../../escape`, drive-qualified,
and backslash-separated names while accepting `rootcompat_probe2`. Rename
translation also requires both endpoints to pass the same confined-path validation.

This validates the root-save load and embedded sidecar extraction path. It does
not claim full gameplay or renderer parity, and the cvar is not enabled by
default.
