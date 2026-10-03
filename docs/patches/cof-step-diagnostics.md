# Walking sound and cursor investigation (issue 3)

The report combines missing walking footsteps and a cursor disappearing around
OBS startup. Its follow-up confirms walking silence but says the recording was
not checked first. The downloaded clip's sampled frames are black or show OBS;
they do not establish a game-side cursor failure. These are separate symptoms,
and neither is marked fixed by this patch.

## Measured source and binary findings

The retail server movement DLL's step update at `0x100099E0` checks ground,
movement flags, speed and the step timer; its step playback at `0x10007550`
checks `fuser3` (offset `0x214`) and `runfuncs` (legacy offset `0x4F5B4`).
Sound callbacks use legacy offset `0x4F5B8`. The existing adapter copies those
fields and callback slots; the earlier crouch fix explicitly preserves the
unshifted timer field. This does not establish that the reported state is correct
at runtime.

The engine client callback checks native `runfuncs` before `S_StartSound`.
The server callback adds `SND_FILTER_CLIENT`; `SV_Multicast` suppresses that
request for the originating client when movement prediction is enabled. Thus
server-only sound requests plus missing client requests could produce silence;
the available report does not demonstrate that sequence. Do not remove the
filter without checking, since that could double every predicted footstep.

`mp_footsteps` is repurposed by CoF as the co-op lobby autostart timer. It is not
an appropriate blind workaround. The input code already has focus activation
and deactivation and gamepad ownership rules for cursor visibility; there is
no evidence yet that OBS bypasses any particular rule.

A further static check found the equivalent client step playback gate at
`0x100141B4`/`0x100141C9`: the same `fuser3` and legacy `runfuncs` fields.
Client setup and finish copy `fuser3`, the step timer and alternating-foot
state; server prediction filtering is driven by the same `cl_nopred` userinfo
setting used locally. No mismatch was established in those paths.
All 69 literal step/surface WAV references found in the local client DLL exist
in the canonical game: mono 22,050 Hz PCM, 8- or 16-bit. That rules out missing
files for this local sample set, not dynamic sample names or the reporter's
installation. Audit output is `stage1/issue3-footsteps-20261003/sample-audit.json`.

## Optional diagnostics

Apply `scripts/apply-cof-step-diagnostics.ps1 -SourceRoot <tree>` after the
playermove adapter and callback-view patches. Both cvars default to zero,
are not archived, and do not change sound parameters, filtering, prediction,
movement speed or cursor ownership.

- `cof_step_trace_cl 1` logs client movement sound requests, including requests
  rejected by the existing prediction gate.
- `cof_step_trace_sv 1` logs server requests before the existing entity gate.
- Value `2` additionally samples post-move state at most twice per second:
  ground, flags, step timer, fuser3, speed, water, buttons, texture and physinfo.
  Server sampling is shared between players; it is intended primarily for
  reproducing this single-player report.
- `cof_input_trace 2` and `m_grab_debug 1` are existing cursor/input diagnostics.

Turn the cvars back to zero when finished. Logs may grow while tracing is on.
Diagnostics report requested sounds, not audible output. They do not prove
sample decoding, mixer output or OBS capture success.

## Validation and next run

`tests/cof-step-diagnostics/run.py` compiles the actual two sound callbacks and
checks diagnostic levels 0/1/2, client prediction rejection, invalid server
entities and unchanged forwarding of every sound argument. This passed on
2026-10-03. The integrated x86 engine build also passed. After the user changed
Windows application policy, the candidate launched and exited normally.

The `c_forest3` / `cofsave1` movement run produced client/server footstep
requests in all four commanded phases: forward 8/8, backward 12/13, walking
8/8, and crouching 13/15. Client requests had `runfuncs=1`, and concrete and
grass samples appeared in the loaded sound list. The backend was SDL
DirectSound. Evidence is in
`stage1/issue3-footsteps-20261003/runtime-steps.log`, with extracted requests
in `step-requests.json` and the exact sequence in `run.ps1`.
This rules out missing client movement callbacks in that run; it does not
reproduce the reported silence. The required muted launch cannot establish
audibility, and no OBS focus transition was exercised. The issue remains open.

Use an isolated fixture and compare ordinary walking, running and crouching on
the same surface, keyboard and controller, with OBS closed/open. Record game
version, map, input device, window mode and the two trace streams. A server
request alone points toward prediction; no requests points toward movement
state; client requests reaching playback point toward sound loading/mixing.
For cursor loss, distinguish the OS pointer over a panel from the gameplay
crosshair and from the cursor captured by OBS. Capture focus/grab logs for
each transition before choosing a behavior change.

## User verification

On 2026-10-03 the user reported testing footsteps themselves and confirmed
they work. Stop treating footsteps as a reproduced defect. The user's game
version, map and input device were not specified. Cursor behavior is a separate
claim and still awaits clarification. No footstep behavior patch was needed.

The user subsequently confirmed everything works for them and asked to leave
the remaining report open while waiting for more data. Investigation is paused.
