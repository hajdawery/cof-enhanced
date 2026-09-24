# Third-party notices

Cry of Fear: Enhanced ships binaries built from the open-source components
below, plus our own patches. Every copyright line here is quoted as found in
the component's source tree at the commit listed in
[`LICENSING.md`](LICENSING.md#3-pinned-upstream-sources). The full licence
texts are verbatim copies in [`licenses/`](licenses/); nothing in them was
edited. This file and `licenses/` must be shipped with every release.

Binaries and what is in them:

| Shipped file | Built from |
| --- | --- |
| `xash.dll` | Xash3D FWGS engine + our patches; statically links Opus, opusfile, libogg, libvorbis, bzip2, MultiEmulator, library-suffix, miniz, mpg123 (compact), getopt, whereami; compiles Valve Half-Life SDK headers |
| `ref_gl.dll` | Xash3D FWGS OpenGL renderer + our patches; compiles Valve Half-Life SDK headers |
| `filesystem_stdio.dll` | Xash3D FWGS filesystem, unmodified |
| `cryoffear/cl_dlls/menu.dll` | mainui_cpp + our patches; MiniUTL; stb_truetype; Valve Half-Life SDK headers (`sdk_includes/`) |
| `vgui.dll` | FreeVGUI + our patches (BSD-3-Clause); stb_truetype |
| `SDL2.dll` | SDL 2.30.9, unmodified |
| `CoFLaunchApp.exe` | our launcher (`launcher/`), GPL-3.0-or-later |
| `cryoffear/gfx/fonts/Inter-*.ttf` | Inter 3.019, unmodified |
| `cryoffear/fonts/cof_*.fnt` | bitmap atlases generated from Inter |

---

## Xash3D FWGS (engine, ref_gl, filesystem_stdio)

- Source: <https://github.com/FWGS/xash3d-fwgs>, commit
  `4857b389e6ba32ddaa68582aedcbc950c138f46a`.
- Licence: **GPL-3.0-or-later**. The tree has no top-level LICENSE file; the
  licence is stated in each source file. The project's header template
  (`Documentation/gpl_copyright_header.h`, verbatim in
  `licenses/xash3d-fwgs-copyright-header.txt`) reads
  "Copyright (C) 2015-2025 Xash3D FWGS contributors" followed by
  "either version 3 of the License, or (at your option) any later version".
  No linking exception or additional permission appears anywhere in the
  tree. Quake-derived files (e.g. in `ref/`, `engine/common/zone.c`) are
  "either version 2 of the License, or (at your option) any later version",
  which is used here under version 3.
- Full text: `licenses/GPL-3.0.txt` (also in `LICENSE`).
- Copyright lines found in the engine, renderer and filesystem headers,
  by frequency: "Copyright (C) 2007 Uncle Mike" (and other years, 189
  files), a1batross, "Xash3D FWGS contributors", Alibek Omarov, mittorn,
  "Copyright (C) 2003-2006 Mathieu Olivier", "Copyright (C) 2000-2007
  DarkPlaces contributors", "Copyright (C) 1996-1997 Id Software, Inc." /
  "Copyright (C) 1997-2001 Id Software, Inc.", Flying With Gauss, fgsfds,
  SNMetamorph, Velaron, Er2off, Xav101, Provod, FWGS Team, Andrey
  Akhmichin, jeefo, Mr0maks, Kevin Shanahan, "QuakeSpasm contributors",
  "FTEQW developers", "ReHLDS developers".

### mpg123 (compact copy inside the engine)

- Files: `engine/client/soundlib/libmpg/` (`dct64.c`, `dct36.c`, `huffman.h`
  and others; the wrapper `mpg123.c` is "Copyright (C) 2017 Uncle Mike",
  GPL-3.0-or-later).
- Notice, verbatim: "copyright ?-2006 by the mpg123 project - free software
  under the terms of the LGPL 2.1" (`licenses/mpg123-NOTICE.txt`).
- Licence: **LGPL-2.1**, full text `licenses/LGPL-2.1.txt`.

### miniz (`public/miniz.c`, `public/miniz.h`)

- "Copyright 2013-2014 RAD Game Tools and Valve Software"
- "Copyright 2010-2014 Rich Geldreich and Tenacious Software LLC"
- Licence: **MIT**, verbatim in `licenses/miniz-LICENSE.txt`.

### getopt (`public/getopt.c`, Windows builds)

- "SPDX-License-Identifier: BSD-3-Clause",
  "Copyright (c) 1987, 1993, 1994 The Regents of the University of California.  All rights reserved."
- Licence: **BSD-3-Clause**, verbatim in `licenses/getopt-netbsd-LICENSE.txt`.

### whereami (`engine/common/whereami.c`)

- "dual licensed under the WTFPL v2 and MIT licenses", "by Gregory Pakosz
  (@gpakosz)", <https://github.com/gpakosz/whereami>
  (`licenses/whereami-NOTICE.txt`).

### vgui_api.h (`engine/vgui_api.h`)

- "Copyright (C) 2015 Mittorn", released into the **public domain**
  (Unlicense text, verbatim in `licenses/vgui_api-public-domain.txt`).

## Valve Half-Life SDK headers (compiled into xash.dll, ref_gl.dll, menu.dll)

- Files: `common/*.h` (21 files), `pm_shared/pm_defs.h`, `pm_shared/pm_info.h`,
  `engine/alias.h`, `cdll_int.h`, `custom.h`, `customentity.h`, `edict.h`,
  `eiface.h`, `progdefs.h`, `shake.h`, `sprite.h`, `studio.h`, and
  `3rdparty/mainui/sdk_includes/` (11 files).
- Notice in each, verbatim (`licenses/valve-hlsdk-header-notice.txt`):

  > Copyright (c) 1996-2002, Valve LLC. All rights reserved.
  >
  > This product contains software technology licensed from Id
  > Software, Inc. ("Id Technology").  Id Technology (c) 1996 Id Software, Inc.
  > All Rights Reserved.
  >
  > Use, distribution, and modification of this source code and/or resulting
  > object code is restricted to non-commercial enhancements to products from
  > Valve LLC.  All other use, distribution, or modification is prohibited
  > without written permission from Valve LLC.

- For reference, Valve's current Half-Life 1 SDK licence
  (<https://github.com/ValveSoftware/halflife>, file `LICENSE`, fetched
  2026-09-22; it is not part of the FWGS tree) is copied verbatim in
  `licenses/valve-half-life-1-sdk-LICENSE.txt`. It begins "Half Life 1 SDK
  Copyright(c) Valve Corp." and allows distribution "but only for free".
- See `LICENSING.md` section 5 for why this does not sit cleanly with the
  GPL and how the project handles it.

## mainui_cpp (menu.dll)

- Source: <https://github.com/FWGS/mainui_cpp>, commit
  `61263995592e93a278d764807243d043d3b97c54`.
- Licence: **GPL-3.0-or-later** (files headed "either version 3") and
  **GPL-2.0-or-later** (Quake-derived menu files, "either version 2 of the
  License, or (at your option) any later version"); no LICENSE file in the
  repository. Used here under GPL version 3.
- Copyright lines found: "Copyright (C) 1997-2001 Id Software, Inc.",
  "Copyright (C) 2010 Uncle Mike" (and other years), "Copyright (C) 2017
  a1batross" (and other years), mittorn, "$_Vladislav" / "Vladislav
  Sukhov", Alibek Omarov, numas13, CrazyRussian, "Xash3D FWGS contributors".

### MiniUTL (inside mainui)

- Source: <https://github.com/FWGS/miniutl>, commit
  `371731e8b5ee63173e0b8c0cdc0ea2e0851a81da`.
- "Copyright (C) 2018, Valve Software", "Copyright (c) 2019, Flying With Gauss"
- Licence: **BSD-3-Clause**, verbatim in `licenses/miniutl-LICENSE.txt`.

### stb_truetype (menu.dll, vgui.dll)

- `3rdparty/mainui/font/stb_truetype.h`, "v1.26 - public domain", "authored
  from 2009-2021 by Sean Barrett / RAD Game Tools". Our FreeVGUI patch
  vendors the identical file into `3rdparty/freevgui/platform/xash3d-fwgs/`.
- Dual licence, verbatim in `licenses/stb_truetype-LICENSE.txt`:
  "ALTERNATIVE A - MIT License / Copyright (c) 2017 Sean Barrett" or
  "ALTERNATIVE B - Public Domain (www.unlicense.org)". We use it under
  Alternative A (MIT) and keep the notice.

## FreeVGUI (vgui.dll)

- Source: <https://github.com/FWGS/freevgui>, commit
  `73bfb4659f3d9eb28b79e5b26baea8c6b888d5eb`.
- Every source file: "SPDX-License-Identifier: BSD-3-Clause",
  "Copyright (C) 2024-2026 Alibek Omarov".
- `LICENSE`, verbatim in `licenses/freevgui-LICENSE.txt`:
  "Copyright (c) 2016-2020 Nagist", "Copyright (c) 2018 Valve Software",
  "Copyright (c) 2019-2026 Alibek Omarov". Licence: **BSD-3-Clause**.
- Origin, as its README states: a re-implementation of the Half-Life 1
  VGUI library "written from that specification alone", compiled from
  debug information in the shipped binaries and from Nagist's
  `vgui_dll` research; the README says it "shares no code with the
  original library" and that nothing is derived from HLSDK headers or the
  Source SDK. Nagist's copyright is carried because that research was used.
- Our changes to FreeVGUI (patch hunks and the new
  `platform/xash3d-fwgs/cofscale.cpp`, `coffont.cpp`, `coffont.h`) are
  offered under the same BSD-3-Clause licence.

## Opus, opusfile, libogg, libvorbis (xash.dll)

- Opus <https://github.com/xiph/opus> `503d81b138d76621aae4b12786e90de48aa8db3a`:
  "Copyright 2001-2023 Xiph.Org, Skype Limited, Octasic, Jean-Marc Valin,
  Timothy B. Terriberry, CSIRO, Gregory Maxwell, Mark Borgerding, Erik de
  Castro Lopo, Mozilla, Amazon". BSD-3-Clause with the Opus patent notes,
  `licenses/opus-COPYING.txt`.
- opusfile <https://github.com/xiph/opusfile> `6dfd29e7adb87f2e193575fc3fa88cbf1a0b27df`:
  "Copyright (c) 1994-2013 Xiph.Org Foundation and contributors".
  BSD-3-Clause, `licenses/opusfile-COPYING.txt`.
- libogg <https://github.com/xiph/ogg> `06a5e0262cdc28aa4ae6797627a783b5010440f0`:
  "Copyright (c) 2002, Xiph.org Foundation". BSD-3-Clause,
  `licenses/libogg-COPYING.txt`.
- libvorbis <https://github.com/xiph/vorbis> `1b75110b5a2754ba1931d82dd83cb822b266a21d`:
  "Copyright (c) 2002-2020 Xiph.org Foundation". BSD-3-Clause,
  `licenses/vorbis-COPYING.txt`.

## bzip2 (xash.dll)

- <https://gitlab.com/bzip2/bzip2> `66c46b8c9436613fd81bc5d03f63a61933a4dcc3`.
- "This program, "bzip2", the associated library "libbzip2", and all
  documentation, are copyright (C) 1996-2010 Julian R Seward.  All rights
  reserved." BSD-style licence, verbatim in `licenses/bzip2-COPYING.txt`.

## MultiEmulator (xash.dll)

- <https://github.com/FWGS/MultiEmulator> `e369abc23c49310b0f5e58f12fef6f46563b0d21`.
- "Copyright (c) 2017-2018 Alexander Belkin". **MIT**,
  `licenses/MultiEmulator-LICENSE.txt`.
- `src/SHA.h` also carries, and requires to be included with the
  distribution (`licenses/MultiEmulator-SHA-NOTICE.txt`): "The code in this
  project is Copyright (C) 2003 by George Anescu. You have the right to use
  and distribute the code in any way you see fit as long as this paragraph
  is included with the distribution. No warranties or claims are made as
  to the validity of the information and code contained herein, so use it
  at your own risk."

## library-suffix (xash.dll)

- <https://github.com/FWGS/library-suffix> `14fc7cd5b1e637d8fe722daa977e72eac9244e45`.
- Released into the **public domain** (Unlicense text,
  `licenses/library_suffix-public-domain.txt`).

## SDL 2 (SDL2.dll, shipped unmodified)

- SDL 2.30.9 (`SDL2-devel-2.30.9-VC.zip`), <https://www.libsdl.org/>.
- "Copyright (C) 1997-2024 Sam Lantinga <slouken@libsdl.org>". **zlib**
  licence, verbatim in `licenses/SDL2-COPYING.txt`.

## Inter typeface (fonts and derived atlases)

- `Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-SemiBold.ttf`, version
  "Version 3.019;git-0a5106e0b", <https://github.com/rsms/inter>.
- "Copyright 2020 The Inter Project Authors (https://github.com/rsms/inter)"
  (from `OFL.txt` and the fonts' name table). No Reserved Font Name is
  declared. The fonts' name table also states: "Inter UI and Inter is a
  trademark of rsms."
- Licence: **SIL Open Font License 1.1**, verbatim in
  `licenses/inter-OFL.txt` and next to the fonts and atlases as `OFL.txt`.
- `cof_console0..2.fnt` and `cof_hudtext0..1.fnt` are bitmap atlases we
  generate from Inter with `scripts/make-cof-console-font.py`; they are a
  Modified Version of the Font Software and are distributed under the same
  OFL 1.1.

## Gamepad button icons and controller pictures (menu data)

- "Xbox Series Button Icons and Controls" and "PS5 Button Icons and
  Controls" by **Zacksly**, <https://zacksly.itch.io>.
- Statement, as the licence asks: "Button Icons and Controls were created by
  Zacksly (Licensed under CC BY 3.0 - https://zacksly.itch.io)".
- Licence: **Creative Commons Attribution 3.0 Unported (CC BY 3.0)**,
  <https://creativecommons.org/licenses/by/3.0/>. The creator's licence notes
  for both packs, followed by the full CC BY 3.0 legal code (verbatim from
  creativecommons.org), are in `licenses/zacksly-CC-BY-3.0.txt`; the notes are
  also next to the files as `gamedata/cryoffear/gfx/shell/gamepad/LICENSE-Zacksly.txt`.
- What ships (`gamedata/cryoffear/gfx/shell/gamepad/`, 36 files, 237,483
  bytes): 32 button icons ("Buttons Full Solid", white, 128 px) copied
  **unmodified**, only renamed (e.g. `Left Bumper.png` -> `xbox/lb.png`), and
  two controller pictures ("Controller Images/Outline/Outline White 4k.png")
  that are **modified**: cropped to the drawing and resized to 1024 px wide
  (`scripts/make-gamepad-assets.py`). `icons.txt` (our key-to-icon table) is
  our own.

## Project emblem (not third-party; listed because it is not GPL)

- `assets/branding/coffix.png` and the icons generated from it
  (`coffix.ico`, embedded in `CoFLaunchApp.exe` and used as the game
  window icon): Copyright (c) 2026 haej, original artwork, distributed with
  the project; not covered by the GPL, all rights reserved except
  redistribution unmodified as part of Cry of Fear: Enhanced.

## Language packs

Not third-party software: see each pack's `LICENSE-NOTE.md` and `README.md`
under `languages/`.
