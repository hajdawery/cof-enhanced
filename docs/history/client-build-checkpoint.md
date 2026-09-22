# Client build checkpoint

> **Historical checkpoint (2026-09-20).** Superseded by [building](../dev/building.md).
> Its closing statement that "no valid client build or runtime result has replaced
> it yet" is out of date: every milestone since has been built as a client with
> `XASH_DEDICATED` undefined and played. Current toolchain notes (MSVC 17.14 x86,
> `--enable-cof-entvars-legacy --enable-stbtt`) are in the building page.

> Released binaries are built from, and their source offer names, the pinned FWGS commit plus the submodule commits actually built: see [`LICENSING.md` section 3](../../LICENSING.md#3-pinned-upstream-sources).

The client build uses FWGS commit `4857b389e6ba32ddaa68582aedcbc950c138f46a`
with the experimental patch applied to a clean source tree. It requires the
x86 MSVC tools from Visual Studio 2022 BuildTools, Windows SDK 10.0.26100,
and the official SDL2 VC development package:

`SDL2-devel-2.30.9-VC.zip`

SHA-256:

`8C91D91E5BCB997D062EC2B553C53832EBF95654D4AA35E8C02A954D4CE752AE`

The extracted source also needs the recursive dependencies listed in its
`.gitmodules`. This document records one local diagnostic checkpoint; it is
not a reproducible-build claim. The source archive does not carry the parent
repository's submodule checkout metadata, so the dependency revisions used
locally are recorded below for auditability.

The client configure unconditionally uses `3rdparty/MultiEmulator`, and the
Win32 x86 client links `3rdparty/freevgui`. The local checkout used
`MultiEmulator` from `https://github.com/FWGS/MultiEmulator.git` at the pinned
revision `e369abc23c49310b0f5e58f12fef6f46563b0d21`; its included license is
MIT. The local `freevgui` revision did not match the pinned source gitlink.
The standard Windows client configuration also links bzip2, opus, opusfile,
vorbis, and vorbisfile when system copies are unavailable; those local
checkouts are listed below.

Dependency provenance for this checkpoint:

| Submodule | Source gitlink | Local revision | Status |
| --- | --- | --- | --- |
| `3rdparty/MultiEmulator` | `e369abc23c49310b0f5e58f12fef6f46563b0d21` | `e369abc23c49310b0f5e58f12fef6f46563b0d21` | matched; client required |
| `3rdparty/freevgui` | `f592f2f5aa3fc07745722133f580755442627064` | `73bfb4659f3d9eb28b79e5b26baea8c6b888d5eb` | present but different; Win32 x86 client required |
| `3rdparty/bzip2/bzip2` | `66c46b8c9436613fd81bc5d03f63a61933a4dcc3` | `66c46b8c9436613fd81bc5d03f63a61933a4dcc3` | matched; used when no system bzip2 |
| `3rdparty/opus/opus` | `82ac57d9f1aaf575800cf17373348e45b7ce6c0d` | `503d81b138d76621aae4b12786e90de48aa8db3a` | present but different; used when no system opus |
| `3rdparty/opusfile/opusfile` | `3ecc22aa0a4430f61c2403d57370a089536d197a` | `6dfd29e7adb87f2e193575fc3fa88cbf1a0b27df` | present but different; used when no system opusfile |
| `3rdparty/libogg/libogg` | `7cf42ea17aef7bc1b7b21af70724840a96c2e7d` | `06a5e0262cdc28aa4ae6797627a783b5010440f0` | present but different; used when no system ogg |
| `3rdparty/vorbis/vorbis-src` | `bb4047de4c05712bf1fd49b9584c360b8e4e0adf` | `1b75110b5a2754ba1931d82dd83cb822b266a21d` | present but different; used when no system vorbis |
| `3rdparty/extras/xash-extras` | `9f5b017985981e5eadd1813c0cde1e4f217e12e1` | `f9e8e35e4b3fe267c45ccf03541998efb1cef031` | present but different; client conditional |
| `3rdparty/gl-wes-v2` | `9c8ef67f97aa1640ea2e3eed08d87d3d1c670f2f` | `9c8ef67f97aa1640ea2e3eed08d87d3d1c670f2f` | matched; optional GLWES renderer |
| `3rdparty/nanogl` | `cf7ccf7173a7b616d29096380c2df2b0f1a0db3c` | `cf7ccf7173a7b616d29096380c2df2b0f1a0db3c` | matched; optional NanoGL renderer |
| `3rdparty/library_suffix` | `14fc7cd5b1e637d8fe722daa977e72eac9244e45` | `14fc7cd5b1e637d8fe722daa977e72eac9244e45` | matched; build metadata helper |
| `3rdparty/gl4es/gl4es` | `81547d986798e876de8b434193920b606a72363f` | absent | optional GL4ES renderer; not used |
| `3rdparty/maintui` | `e5f143ee3370bf9c897015b60bcefbdf2937187e` | absent | optional text UI; not used |
| `3rdparty/libbacktrace/libbacktrace` | `b9e40069c0b47a722286b94eb5231f7f05c08713` | `0b9b49cf4a2c9229fc052d6716e1528b2f23e91` | present but different; not a client link listed by this build |
| `3rdparty/mainui` | `61263995592e93a278d764807243d043d3b97c54` | `61263995592e93a278d764807243d043d3b97c54` | matched; client conditional |
| `3rdparty/mbedtls/mbedtls` | `701bb7cfdef4c8860e7fdafcec1e7ec8a05a37a9` | `701bb7cfdef4c8860e7fdafcec1e7ec8a05a37a9` | matched; disabled by configure |

The optional renderer and text UI rows are included to make the missing
submodules explicit; they were not needed for this default GL client build.

From the pinned source directory directly below the repository root, configure
with the repository-relative SDL path:

```powershell
python waf configure -4 --out=build-cof-client `
  --sdl2="..\prereq\sdl2-2.30.9-vc\SDL2-2.30.9" `
  -T release --notests --disable-mbedtls
```

The extracted archive may contain stale generated headers from a dedicated
build, or no generated `common/build.h`. Before a client build, both
`build.h` and `common/build.h` must describe the client configuration. For a
client build, `XASH_DEDICATED` must be undefined, because this source uses
`#ifdef XASH_DEDICATED` in dedicated-only guards; defining it as `0` still
selects the dedicated path. The client values are `XASH_SDL=2`,
`XASH_REF_GL_ENABLED=1`, and SDL video, sound, input, timer, and messagebox
backends. A stale dedicated header defines `XASH_DEDICATED=1` and causes the
same dedicated-only selection, including the duplicate-definition failure in
`engine/client/dll_int/cl_game.c`.

The dedicated engine receives `XASH_DEDICATED=1` from its Waf target defines;
the shared generated header helper intentionally leaves this macro undefined.
Do not use a header containing `#define XASH_DEDICATED 0` for a client build.

Build with:

```powershell
python waf build -j8
```

The earlier local output was `build-cof-client/engine/xash.dll`, 3,470,336
bytes, SHA-256
`F398F7833BFC4D42C0BDACAB76659A6757BFBAD3754BDFCA0FC70BC4651E6FC0`.
That build defined `XASH_DEDICATED=0`, so it followed dedicated-only
`#ifdef` paths and is not valid client proof. It is a local ignored build
artifact and is not part of the repository; the hash identifies the failed
checkpoint only.

The runtime checkpoint therefore provides no client, `ref_gl`, menu, VGUI, or
launcher proof. No valid client build or runtime result has replaced it yet;
the next build must use headers with `XASH_DEDICATED` omitted and a fresh
client output directory.
