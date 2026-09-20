# Skyline trace renderer

`cof_skyline_trace` defaults to `0`. When set to `1`, the renderer emits at most 48 `[cof-skyline]` lines and only for `models/Props/Blandat/byggnader.mdl`. Lines record studio entry, the live and network angles, model and sequence bounds, the transform matrix, transformed bounds, the studio frustum-cull result, and the client studio callback's before/after state. The trace does not change drawing.

Apply the existing [GL-stage](cof-gl-stage-trace.md), [solid-entity](cof-solid-entity-trace.md),
and [transparent-triangle](cof-transparent-triangle-trace.md) trace
prerequisites first, then apply this patch to the same pinned source checkout.
The skyline patch adds its own cvar and studio instrumentation; it does not
silently carry those prerequisite implementations.

```powershell
.\scripts\apply-cof-skyline-trace.ps1 `
  -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

The helper confines the checkout to this project, requires the earlier
`cof_gl_trace`, `cof_solid_entity_trace`, and
`cof_skip_client_transparent_triangles` markers, checks the three expected
source files, verifies the skyline markers after application, and
reverse-checks the patch. Use
`-Reverse` only on a tree where this skyline patch is already applied. No
`--unsafe-paths` or global Git settings are used.

The separate artifact bundle is `artifacts/skyline-tracebundle-20260920/`; do not replace a runtime renderer automatically. For a manual menu capture, place its `ref_gl.dll` and matching PDB in an isolated test copy, launch `c_game_menu1`, set `cof_skyline_trace 1`, and retain the console log. An `entry` followed by `cull=1` means the engine studio bounding-box test rejected the model at this dispatch point; it does not prove that the built-in renderer drew it, because a custom client callback can invoke the same engine check. The refreshed patch also records callback-before/after state around that custom callback, but those lines still identify observed state and do not establish that the callback produced visible pixels. No entry is inconclusive: a cubemap pass or follow-parent rejection can return before this dispatch. The trace does not report PVS because no PVS result is available at this dispatch point.

## External compatibility leads

The WineHQ report ["Getting game with native opengl32.dll to work..."](https://forum.winehq.org/viewtopic.php?t=32263) is a concrete binary workaround for the original Cry of Fear/Paranoia renderer path. The report says that `hw.dll` loads CoF's modified OpenGL wrapper while `ddraw.dll` needs Wine's builtin `opengl32`; the author's workaround renamed the modified wrapper to `opengl33` and changed the references in `hw.dll` and `cl_dlls/client.dll`. The final follow-up narrowed the crash workaround to one byte in that wrapper: at file offset `0x00006776`, change `0x75` (`jne`) to `0xEB` (`jmp`). The earlier list of sixteen offsets was not required by that follow-up. This is a patch to a proprietary runtime wrapper and loader route, not a source-level FWGS renderer fix, so it is retained as provenance only and no binary or byte patch belongs in this repository.

The linked [MacGaming report](https://www.reddit.com/r/macgaming/comments/mg2r9w/cry_of_fear_on_mac/) contains two separate observations: the original CrossOver setup lacked flashlight light, and a later commenter used the non-Steam CoF 1.0 files with the [TheKingFireS Xash3D-COF fork](https://github.com/TheKingFireS/Xash3D-COF) under Whisky. The latter is an anecdotal launch result (20--40 FPS on an M1 Mac, with the Steam build reportedly crashing); it provides no renderer hash, GL trace, or flashlight fix. It therefore does not identify the skyline geometry issue here, and the flashlight symptom must not be used as a proxy for the current `byggnader.mdl` cull/transform investigation.

The fork's public tree is explicitly labeled a standalone, non-FWGS custom build, with engine code under `engine/client`, `engine/common`, and `engine/server`; its visible history ends with a December 2023 merge and an October 2023 commit applying two FWGS client patches. The indexed history and README expose no Paranoia/Wine-specific source change or renderer call that can be compared safely with this checkout. Its repository `LICENSE` is GPLv3. That license is compatible with the GPL engine lineage in principle, but any future code comparison still needs file-level copyright and provenance review; the fork's binaries, patches, and game files are not project inputs.

### Proton and Windows corroboration

The exact [Proton issue comment](https://github.com/ValveSoftware/Proton/issues/2379#issuecomment-769236151) by `dblsaiko` (2021-01-28) repeats the Wine workaround as a four-step binary procedure: apply the linked `cof-opengl32.patch` with `patch --binary` to the game's `opengl32.dll`, rename the result to another name with the same character count (the comment uses `opengl33.dll`), and replace every `opengl32` reference in `hw.dll` and `cryoffear/cl_dlls/client.dll`. The author reports that this removed the three-hands bug and restored flashlight light. The linked [Steam discussion](https://steamcommunity.com/app/223710/discussions/0/3164316851917596841/) independently reports the same `gl_renderer 1` setting and a Windows Steam test with the patched files, with slight graphical glitches still observed. These are binary deployment reports, not FWGS source changes or proof that the same workaround applies to the current Xash renderer; the original patch archive and modified DLLs remain intentionally untracked.

The raw patch’s relevant mechanism is narrower than a general OpenGL compatibility fix. Terra’s binary audit identifies the `0x6776` conditional as the modified wrapper’s initialization check for the system `wglGetLayerPaletteEntries` export; the `75` branch takes the failure path when that export is unavailable, while `EB` skips it. The Wine discussion describes this more generally as a missing WGL export. Our current FWGS proxy successfully initializes the required WGL calls, so this workaround does not explain the skyline trace or justify changing the Xash renderer.
