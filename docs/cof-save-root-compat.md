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

The definitive frozen deployment run used the measured `engine\xash.dll`
SHA256
`7BA9DD02B20CF5FE5A9006A124BC1E9215DE86D52C646EF04EE7F0471CCAF182`, with
`-game cryoffear -cof-pmove-legacy +set cof_save_root_compat 1`. The runtime
timestamps were 2026-09-20 18:18:01.971+02 for the preserved stock load,
18:19:50.330+02 for the root-save write, and 18:20:32.880+02 for reload. The
stock `SAVE\cofsave1.sav` (SHA256
`9B95AEF173B008B6F7712084591FD8A4D1517E70C9DBBA07A44AFEEE4D43ED9C`) loaded
after signon, recorded `SV_LoadGame entry: save/cofsave1.sav`, reached
`c_forest3`, and extracted `c_forest2.HL1` into the root `SAVE` directory.
The write then created `SAVE\luna_rootcompat_frozen_20260920.sav` (102390
bytes) and its thumbnail (284854 bytes); a separate reload reached
`c_forest3` and `c_forest3.HL1` again. The write log SHA256 is
`D9909278C7EE20B64E71559519E3D518E1CB5C0484511478532DACB7EA9AC2B1` and the
reload log SHA256 is
`BF04344B4A8A98FD6D7695E0C5360B7B6D00FD01DBE9A67EFB826548A48561DD` in the
ignored evidence file
`stage1/menu-transition-evidence-20260920/savecompat-frozen7BA9-deployment.txt`.
Original save/config manifests were restored unchanged after the run.

A traversal regression probe issued `delete ../../escape_probe` from the
isolated `cryoffear` game directory; the sentinel outside `SAVE` remained
present. `saveshot` rejects `../../escape`, `sub/../../escape`, drive-qualified,
and backslash-separated names while accepting `rootcompat_probe2`. Rename
translation also requires both endpoints to pass the same confined-path validation.

This validates opt-in root-save load, embedded sidecar extraction, root-save
write, thumbnail creation, and reload through a command-equivalent route. It
does not prove the GUI Load Game path, full gameplay, camera handoff, or
renderer parity, and the cvar is not enabled by default.
