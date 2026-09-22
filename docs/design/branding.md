# Project branding

The project emblem `coffix.png` is original artwork by haej (Copyright (c) 2026
haej; not covered by the GPL, all rights reserved except redistribution
unmodified as part of Cry of Fear: Enhanced, see
[LICENSING.md](../../LICENSING.md)). It is preserved byte-for-byte at
[`assets/branding/coffix.png`](../../assets/branding/coffix.png). It is a 1254 ×
1254 RGBA image with SHA-256
`1B00E63471ED15FDA50FD13A194598EC90BAFC592D36B7477941AD94D4837169`.

[`assets/branding/coffix.ico`](../../assets/branding/coffix.ico) is a generated
Windows icon containing 16, 24, 32, 48, 64, 128, and 256 pixel images. The
source artwork is square, so the generated images preserve its aspect ratio
without cropping or redesign. The icon is embedded as resource ID 101 in
`CoFLaunchApp.exe` by `launcher/cof_launch.rc`.

The launcher icon is project branding only. The runtime window icon is selected
by Xash3D from the active gameinfo `icon` field. The runtime packaging template
uses the project-owned namespace `cofmodern/branding/coffix`: copy
[`assets/branding/runtime/cryoffear/cofmodern/branding/coffix.ico`](../../assets/branding/runtime/cryoffear/cofmodern/branding/coffix.ico)
to `cryoffear/cofmodern/branding/coffix.ico` and merge
[`gameinfo-icon.fragment.txt`](../../assets/branding/runtime/cryoffear/gameinfo-icon.fragment.txt)
into the overlay's `cryoffear/gameinfo.txt`. The fragment sets
`icon "cofmodern/branding/coffix"`; Xash3D appends `.ico` and resolves the
nested path inside the game directory. This is a packaging template only and
does not modify the original game assets. The existing `coficon` asset remains
untouched.

The local branding launcher build was verified with resource ID 101 and has
SHA-256 `0C5ADD93EB4D3ADB3360FFB635E90C83791F38311272E2D9FFB75245601E00E`.
The current build script also enables `/LARGEADDRESSAWARE`; its separately
verified local output has SHA-256
`6FD58B8B83E7C6EC5B9016F5726F4F711E7896CCAEDE24926F742762E0380191`, PE
characteristics `0x122`, and resource ID 101. These local builds are separate
from the Steam-tested launcher hash recorded in the launch reports; no
branding or LAA launcher build has been deployed to the Steam install.
