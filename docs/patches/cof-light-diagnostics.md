# Cry of Fear dynamic-light diagnostics (issue #4)

Status: investigated, **not a confirmed fix**. The added `cof_light_status`
command is a read-only snapshot. It does not modify rendering, cvars, entity
state, or either light pool. There is no behavior-changing cvar to opt out of;
the diagnostic runs only when explicitly requested.

Apply `scripts/apply-cof-light-diagnostics.ps1 -SourceRoot <tree>` after the
existing stack. It changes only `engine/client/cl_tent.c`, registers the
command with temporary-entity initialization and removes it on teardown.
`-Reverse` removes the diagnostic. Fresh apply, reverse, and reapply were
checked against the public test3 integration source on 2026-10-03. Compilation
and live command execution are separate checks; source roundtrip alone does
not establish either. The full integrated x86 engine build subsequently passed;
live command execution passed in the later runtime follow-up below.

## What the report establishes

Issue #4 contains a screenshot and an acknowledgement, without a map, save,
renderer configuration, hardware, or reproduction steps. The screenshot
appears to show a world/dropped lantern in a dark scene; it does not establish
the corresponding entity's renderfx or prove the light was allocated.

Earlier local FOV experiments on `c_forest3` documented a held lantern lighting
nearby ground, including with the viewmodel hidden. This is useful historical
evidence, not a reproduction of this report on the current release.

## Static evidence: the engine light allocator is a different path

Read-only inspection used retail `client.dll` SHA-256
`D2A04641B301804F6F449AA68265042B13ADC360925B80033D417EC9F38C9C00`.
Addresses below are preferred-base addresses and are meaningful only for that
binary; no proprietary binary is included in the repository.

* The client entity-effects helper at `0x10060000` reads
  `cl_entity_t.curstate.renderfx` and calls private allocator `0x1005C0F0`.
* That allocator manages **32 private records of 0x7C bytes** at `0x104CC550`.
  These are not FWGS's `dlight_t` records or `CL_AllocDlight` pool.
* The renderfx 165 branch at `0x100602D9` uses the interpolated entity origin,
  a vertical offset, radius `220 + RandomLong(-15,15)`, variable RGB, and a
  short refreshed lifetime. The renderfx 68 branch at `0x100603AC` instead
  reads attachment 3. Their exact equipment association must be checked from
  the actual packet/model; these are not names hard-coded by this diagnostic.
* Additional light-source branches include 71, 72, 73, 184, and 245. A zero
  count in the **engine** pool therefore cannot establish absent CoF lights.
* `gl_dynlight` and `gl_dynlight_ent` register with default `1`. The private
  world pass is called at `0x1005EFB6` from `0x1005EEB0`, gated by
  `gl_dynlight`. `0x1005B300` selects `GL_EQUAL`, walks the private light pool,
  and traverses the world BSP through `0x1005C200`.
* BSP traversal rejects nonmatching node visibility stamps (`0x1005C220`)
  and nonmatching client surface stamps (`0x1005C370`). Surfaces use the
  expected 0x5C stride. No structure mismatch was established by this audit.
* The custom renderer setup at `0x1005F3A0` also requires its GL manager,
  Paranoia wrapper, world lightdata, and extension capabilities. Existing
  public showcase logs show `Paranoia opengl hacks version: 1` on the local
  machine; the reporter's environment is unknown.

The custom base/light passes execute together, reached from the first studio
dispatch or the normal-triangle callback. Their existence alone does not prove
a FWGS ordering error. Changing engine dlight lifetimes, injecting a second
lantern light, changing all depth ranges, or hiding the world lantern would
be speculative and was not done.

## What the command records

Run `cof_light_status` while the problem is visible, ideally from a map-load
cfg or a normal user console session with `-log` enabled. It prints:

* custom-renderer and engine-light cvars, distinguishing unregistered values;
* active engine light origins, radius, color, key, and remaining lifetime;
* current packet entities with the client's light-source renderfx values,
  including invisible/model-less sources, model names, effects, packet and
  interpolated origins, and attachment 3; source output is capped at 64.

The command intentionally does not read private DLL memory, claim callback
admission from a packet alone, or change the caller's settings. A matching
entity may still be rejected before `HUD_AddEntity`. The packet check helps
separate that case from the absence of a server source.

## Next decisive runtime checks

1. Capture a named save/map at the failing lantern. Compare held and dropped
   lanterns beside known nearby geometry. Capture `cof_light_status` for both.
   Also run **`r_info`** (the renderer registers this name, not `gl_info`). Its
   `Color ... Alpha ... Depth ... Stencil ...` line reports the selected
   context attributes queried through `GL_GetAttribute`, rather than the
   requested eight alpha bits. Preserve startup output and any pointlight
   warning as well.
2. Confirm the relevant source reaches `0x10060000`, then whether its key,
   origin, radius, color, and lifetime appear in the private array. Zero engine
   lights are not a failure criterion.
3. If a private light exists, trace `0x1005B300` and `0x1005C200`: allocation
   versus pass admission versus zero traversed surfaces versus GL rejection
   are separate failure boundaries. Check `GL_EQUAL` against the base pass's
   depth range and matrices before changing either.
4. Compare `gl_dynlight 1/0`, then `r_dynamic 1/0`, restoring settings afterward.
   Include phone/flashlight and muzzle flash controls; do not use a model-name
   workaround.

Local evidence/fixture: `stage1/issue4-lighting-20261003/`. Its standalone
builder uses real mutable folders and linked read-only assets. The muted,
windowed baseline launcher was blocked before process creation by Windows
Application Control, both normally and with sandbox escalation. No game test
ran, and neither the user's play copy nor the canonical game was modified.

## Follow-up ABI and light-pass audit

The bounded static follow-up found no confirmed engine mismatch. It eliminated
several candidates and identified a hardware/context-dependent failure gate
worth testing before a renderer change:

* `tests/cof-light-diagnostics/check-layout.ps1` compiles assertions against
  the actual pinned headers in an x86 MSVC environment. All assertions passed:
  node size 0x34, surface size 0x5C, and the node, surface, polygon, texinfo,
  and model offsets consumed by the client. This checks ABI offsets only.
* All **235** canonical map headers are BSP version 30. FWGS's packed QBSP2
  child-pointer representation does not apply to those maps; ordinary
  `children_[2]`, 16-bit surface index/count, and client traversal agree.
* Base traversal `0x1005FCA0` and light traversal `0x1005C200` use the same
  node visibility stamp (`0x104CDD6C`) and surface stamp (`0x104CDD44`).
  Base traversal marks visible leaf surfaces with that client stamp. Both
  passes run inside `0x1005EEB0`, with no intervening engine world pass. This
  does not support an unconditional FWGS/client frame-counter mismatch.
* Base and light draws share the polygon draw helper (`0x10061D50`), including
  the client's VBO index stored in the high half of polygon `flags`. Both
  consume the same generated vertex data. Their existence does not establish
  a dynamic-light-only polygon layout defect.
* **Pointlight capability gate:** `0x1005C900` uses its single-pass path only
  when `gl_twopassdyn` is zero, a 3D attenuation texture exists, and at least
  four texture units are available. Otherwise it needs framebuffer alpha for
  the multipass path. At `0x1005CA9D`, absent alpha bits cause it to warn
  `WARNING: no alpha buffer, pointlights will not be drawn!` and return
  failure. Allocation may therefore succeed while no world light is drawn.
* The client's alpha-bit field (`0x101BE800`) is populated by a
  `glGetIntegerv(GL_ALPHA_BITS, ...)` query at `0x10055914`. FWGS normally
  requests eight alpha bits in `GL_SetupAttributes`; safe-mode fallback at
  `SAFE_NOALPHA` or later stops requesting them. A request is not proof of
  the selected framebuffer format. `r_info` records the selected attributes.

The alpha gate is an **identified failure condition, not an attribution of
issue #4**. No reporter GL capabilities/log are available. If the actual alpha
count is nonzero, or the single-pass path is active, this particular gate does
not explain the report. If the gate does fire, fixing world depth or light
lifetimes would still be the wrong intervention. No further launch attempts
or behavior changes were made during this follow-up.

## Runtime follow-up, 2026-10-03

After the launch restriction was removed, two isolated candidate runs exited
normally. The combined candidate loaded `cofsave1` on `c_forest3`. The selected
NVIDIA framebuffer reports color 24, alpha 8, depth 24, stencil 8; the retail
client independently reports alpha 8 and four texture units, with its 3D
attenuation texture allocated. The missing-alpha gate does not explain this
local scene.

Read-only snapshots of the owned fixture process, guarded by the retail
client SHA-256, found a refreshed held-light record keyed 1, radius 225 then
218, RGB `(0.4, 0.4, 0.4)`. The visible packet source keyed 153 was instead
`models/weapons/lantern/w_lantern.mdl`, renderfx 245, at `(-613,392,8)`;
its private light had radius 3 and origin Z 14. Engine dlights remained empty.
This confirms private allocation and separates the held light from the world
pickup; it does not establish that either matches the reporter's lantern.

Baseline, engine-light-disabled, client-light-disabled, and forced two-pass
captures were saved under `stage1/issue4-lighting-20261003/fixture/root/cryoffear`.
The camera changed between frames, so these captures are not a controlled
pixel comparison or proof that the world illumination is correct. Evidence
includes module hashes, launch arguments, both logs, and private-pool JSON.
These initial observations alone did not justify a behavior patch. The later
placed/dropped comparison identified the color-sentinel mutation and verified
the fix described in [lantern light color](cof-lantern-light-color.md). The
additive fix extends this command with raw packet and linked RGB/amount fields.
