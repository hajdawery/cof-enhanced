# The `cofenhanced` build stamp

> **Current values (2026-09-22 docs pass):** the examples below were written at
> milestone 3 (`0.3`, `m3`). `VERSION` now reads `0.4` / `m6`, so a fresh build
> stamps `cofenhanced 0.4 (m6, <commit>)`. The no-header fallback path is still
> **unverified** (not compiled), as stated below.

The engine draws Xash3D's own version line in the bottom-right corner
(`Con_DrawVersion`, `engine/client/console.c`) and, with the styled console on,
repeats the build string in the console's title band. Neither says anything
about *this* project's build. This adds a line for it, in the top-right corner
(see Drawing):

```
cofenhanced 0.3 (m3, f105554+)
```

and in the styled console's band the same string is appended after the engine's
own build:

```
Xash3D FWGS 49/0.21 (win32-i386 build -1)  cofenhanced 0.3 (m3, f105554+)
```

## Where the three values come from

| Macro | Source |
| --- | --- |
| `COFE_VERSION` | line 1 of `cof-fix/VERSION` (`0.3`) |
| `COFE_MILESTONE` | line 2 of `cof-fix/VERSION` (`m3`) |
| `COFE_COMMIT` | `git rev-parse --short HEAD` in `cof-fix`, with a trailing `+` when the tracked tree is dirty |

`scripts/write-cof-version.ps1` writes them into `engine/cof_version.h` in the
FWGS checkout. That file is **generated, not committed** — the checkout is
ignored by this repository anyway — and the engine includes it defensively:

```c
#if defined( __has_include )
#if __has_include( "cof_version.h" )
#include "cof_version.h"
#endif
#endif
#ifndef COFE_VERSION
#define COFE_VERSION   "dev"
#endif
...
#define COFE_BUILD_STRING "cofenhanced " COFE_VERSION " (" COFE_MILESTONE ", " COFE_COMMIT ")"
```

so a plain apply of `patches/cof-cofenhanced-version.patch` with no generated
header is meant to compile and show `cofenhanced dev (dev, dev)`. Run the script
before a build to stamp the real values; run it with `-Remove` to delete the
header again.

**Not built, only reviewed:** the shipped binary was built *with* the generated
header, and the no-header path was not compiled, because rebuilding the engine
would change the `xash.dll` hash every piece of evidence in this round refers
to. The guard is `#if defined( __has_include )` around `#if __has_include(...)`
with an unconditional `#ifndef` fallback for each of the three macros, so it
degrades on a compiler without `__has_include` as well as on a tree without the
header. Worth one build on the next engine round.

`engine/` is an include directory of the engine target
(`bld(name = 'engine_includes', export_includes = '. common common/imagelib')`,
`engine/wscript:164`), so `#include "cof_version.h"` resolves without any
wscript change.

## Drawing

Both sites reuse what is already there, so the stamp inherits the milestone-4
text autoscale for free:

* `Con_DrawVersion` measures the new string with `Con_DrawStringLen` and draws
  it in the **top-right corner** (since m7, 2026-09-23; before that it sat
  under the engine line in the bottom-right corner, where it covered the HUD),
  with the same colour and alpha as the engine line and the same inset from
  the two edges that line keeps in its corner: right-aligned at
  `width - len * 1.05f`, top at `height * 0.05f` of its own measured row. The
  engine line stays alone at its stock bottom-right place. While the fps
  counter is on screen (`cl_showfps` in a running game, not on the background
  map: `SCR_DrawFPS` draws it at y 4, right-aligned) the stamp moves down to
  `4 + <fps row height> + <its inset>`, so the two never overlap (the
  position counter of `cl_showpos` is centred and does not reach the corner).
  The stamp is drawn exactly when the engine line is - the menu, screenshot
  frames and a few seconds after a window event, all under the stock
  `scr_drawversion` - and there is deliberately no switch for the stamp
  alone (it is there for bug reports). Measured in m7: menu, and in game with
  `cl_showfps 1` (`stage1/m7-integration-20260923/evidence/notify-a-main.png`,
  `notify-d-fps.png`).
* `Con_StyleDrawConsole` formats the band string with `"%s  %s"` instead of
  `"%s"`. The band already clips and already re-measures, so nothing else
  changed.

## Patch

`patches/cof-cofenhanced-version.patch`, one file
(`engine/client/console.c`), applied with
`scripts/apply-cof-cofenhanced-version.ps1`. It refuses to apply unless the
styled console (`cof_console_style`) and the text autoscale
(`cof_text_autoscale`) are already present, because both hunks sit inside code
those two added; it refuses a duplicate apply, checks its markers afterwards,
reverse-checks, and `-Reverse` verifies that the two console patches it sits on
are still intact.

**Verified** on `cof-fix/pristine-ui-m1-scratch`: forward apply, duplicate-apply
refusal, `console.c` then hashed identical to the working tree, `-Reverse`
restored the pre-apply hash exactly.

## Verification

`stage1/ui-m1-menu-fixture-20260921/evidence/mn-1920-a-main.png` and
`mn-1280-a-main.png` show the two lines in the bottom-right corner at 1080p and
720p; every other screenshot from that round carries them too. The console band
is **marked for the user's manual test** — the styled console has to be open,
and this fixture's runs never open it.
