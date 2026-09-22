# Building Cry of Fear: Enhanced

> Released binaries are built from, and their source offer names, the pinned
> FWGS commit plus the submodule commits actually built: see
> [`LICENSING.md` section 3](../../LICENSING.md#3-pinned-upstream-sources).

This repository holds **patches, scripts and data**, not engine source. A build
is: unpack the pinned engine, apply [the patch stack](patch-stack.md), generate
two headers, configure, build. Windows only; the result is a 32-bit (x86) set.

## Toolchain

| Tool | Version used | Notes |
| --- | --- | --- |
| Visual Studio Build Tools | MSVC 14.4x (VS 2022, "msvc 17.14"), x86 tools, Windows SDK 10.0.26100 | the build machine also has VS 18.9, so waf must be told which one: `--msvc_version="msvc 17.14" --msvc_targets=x86` |
| Python | 3.x (3.14 on the build machine) | runs waf and the generators; `scripts/make-cof-console-font.py` needs Pillow |
| Windows PowerShell | 5.1 | every `scripts/*.ps1` |
| git | any recent | the apply scripts call `git apply` |
| SDL2 | `SDL2-devel-2.30.9-VC.zip`, SHA-256 `8C91D91E5BCB997D062EC2B553C53832EBF95654D4AA35E8C02A954D4CE752AE` | unpacked to `prereq/sdl2-2.30.9-vc/SDL2-2.30.9` (ignored) |

Run the build from an x86 MSVC environment (`vcvarsall.bat amd64_x86`).

## Source tree

1. Unpack FWGS `4857b389e6ba32ddaa68582aedcbc950c138f46a` (`fwgs-4857b38.zip`,
   ignored) as `xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a/` **inside
   this repository**. The apply scripts refuse a tree outside it.
2. Add the submodules at the commits in LICENSING.md section 3 (the archive
   carries no submodule metadata). MainUI must be exactly `61263995…` and
   FreeVGUI `73bfb465…`.
3. Apply the server playermove adapter (`scripts\apply-pmove-adapter.ps1`) -
   or start from a copy of the local `pristine-clean/`, which is this tree with
   that one patch applied.
4. Apply the rest of [the patch stack](patch-stack.md), in order.

Keep one tree per round (`pristine-<round>-<date>/…`, ignored). Never build a
release out of the shared live checkout; see [releases](releases-and-deploy.md).

## Generated headers

```powershell
# common/build.h and build.h for a CLIENT build (XASH_DEDICATED left undefined)
.\scripts\prepare-fwgs-build-header.ps1 -Target client -SourceRoot <tree>
# engine/cof_version.h: "cofenhanced <VERSION line 1> (<line 2>, <git short hash>[+])"
.\scripts\write-cof-version.ps1 -SourceRoot <tree>
```

The first one matters more than it looks: `#ifdef XASH_DEDICATED` treats
`#define XASH_DEDICATED 0` as enabled, so a stale dedicated header silently
produces a dedicated-style client (see
[the 2026-09-20 checkpoint](../history/client-build-checkpoint.md) and
[developer notes](xash-goldsrc-developer-notes.md)). `engine/cof_version.h` is
never committed; without it the stamp reads `cofenhanced dev (dev, dev)`.

## Configure and build

From the tree's root, with your **own** output directory:

```powershell
python waf configure -4 --out=build-<round>-<date> `
  --sdl2=..\prereq\sdl2-2.30.9-vc\SDL2-2.30.9 `
  -T release --notests --disable-mbedtls `
  --enable-cof-entvars-legacy --enable-stbtt `
  --msvc_version="msvc 17.14" --msvc_targets=x86
python waf build -j8 --targets=xash,vgui,ref_gl,menu
```

(`--sdl2` is relative to the tree; adjust it for a tree that is nested deeper,
such as `pristine-<round>/xash3d-fwgs-…`.)

* `--enable-cof-entvars-legacy` comes from `cof-entvars-legacy.patch` and
  exports `XASH_COF_ENTVARS_LEGACY=1`; the Cry of Fear DLLs need it.
* `--enable-stbtt` makes MainUI read the Inter TTFs through stb_truetype.
* Set `WAFLOCK=.lock-waf-<round>` when another build may use the same tree, so
  the two do not share waf's lock file.
* `--targets` can be narrowed (`xash,vgui` for engine-only rounds, `menu`,
  `ref_gl`), but remember `xash.dll` and `vgui.dll` go together.

Outputs, relative to the out directory:

| File | Path |
| --- | --- |
| `xash.dll` (+ `xash.pdb`) | `engine\xash.dll` |
| `ref_gl.dll` | `ref\gl\ref_gl.dll` |
| `vgui.dll` | `3rdparty\freevgui\vgui.dll` |
| `menu.dll` | `3rdparty\mainui\menu.dll` (deployed as `cryoffear\cl_dlls\menu.dll`) |

`filesystem_stdio.dll` is shipped unmodified and `SDL2.dll` comes from the SDL2
package; neither changes with our patches.

## The launcher

`launcher/cof_launch.cpp` builds `CoFLaunchApp.exe`, the file Steam starts:

```powershell
.\scripts\build-cof-launcher.ps1        # -> build-launcher\CoFLaunchApp.exe
```

It finds MSVC through `vswhere` or `VSINSTALLDIR` (or `-VcVarsPath`), embeds
`assets/branding/coffix.ico` and sets `/LARGEADDRESSAWARE`. It loads the
colocated `xash.dll` and always passes
`-game cryoffear -cof-pmove-legacy +set cof_save_root_compat 1`; see
[the launcher contract](steam-launch-prototype.md#launcher-contract).

## Data files

Nothing to build except the font atlases, which are committed and reproducible
byte for byte:

```powershell
python .\scripts\make-cof-console-font.py      # cof_console0..2.fnt (defaults reproduce the shipped files)
```

The HUD text atlases (`cof_hudtext0/1.fnt`) come from the same script; see
[fonts](../design/fonts.md). `gamedata/cryoffear/maps/c_game_menu1.ent` is
derived from the game's own BSP and is generated on the player's machine
(`scripts/make-cof-ent-override.py`), never committed.

## Tests that build something

`tests/cof-menu-save/run-harness.bat [-SourceRoot <tree>]` extracts the menu-save
transaction code from a patched tree and runs it against a fake filesystem.
It never launches the game. See [testing](testing.md) for everything else.
