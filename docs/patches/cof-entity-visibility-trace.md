# Cutscene actor visibility investigation (#1)

Status: **diagnostics only; the reported defect is not fixed or reproduced yet**.
The source patch never changes visibility, model selection, or the return value
from the game DLL. Its trace is disabled by default.

## Evidence collected on 2026-10-03

The downloaded issue screenshot contains the Polish equivalent of subtitle 197,
"There's something in the ceiling." The original subtitle file and BSP entity
lump identify the room as `c_apartment1`. The actor matching that room is the
`env_model` target `scene1_1`, model `models/cutscene/tauruss.mdl`, with map origin
`-954 774 141`. Actor identification is a strong map-based inference, not a
runtime entity pick from the reporter's save.

The map provides explicit visibility controls:

* `scene1_1_inv`: `env_customize`, target `scene1_1`, `m_iVisible 2`.
* `scene1_1_vis`: the corresponding `m_iVisible 1` control.
* `trigger_once` brush `*124` targets the shared `multispawnhe` managers, one
  of which fires the hide control at zero delay. Its bounds
  `(-836,-209,283)` to `(-783,-121,386)` contain `info_player_start` at
  `(-819,-160,321)`. This is a touch-triggered entry sequence, not a DLL
  spawn callback. Check trigger touch and every same-name manager.
* The two `multiscene1_1` managers show the actor at time zero and hide it
  at 15 seconds. The actor animation is fired at seven seconds. The initiating
  path is button brush `*132` -> `multitscene` -> `multiscene1_1`.

The screenshot prompt is the ceiling hint **before** the handgun pickup
scene; it does not establish that scene cleanup failed. Investigate the
initial hide as well as post-scene cleanup.

Read-only inspection of the original `hl.dll` establishes that the customize
key parser stores `m_iVisible` at private-data offset `0xF4`; the use helper sets
`entvars.effects` bit `0x80` for value 2 and clears it for value 1. Relevant
preferred-image addresses are `0x1010C00E` (parse/store), `0x10109214`
(visibility value evaluation), `0x10109226` (hide), and `0x10109235` (show).
This is the engine's existing `EF_NODRAW` bit, at the expected entvars offset
`0x118`, before the legacy layout insertion. The generic engine client already
checks `EF_NODRAW` in `CL_LinkPacketEntities` and only visits current packet
entities. These observations do not identify the failing runtime boundary.

The canonical map and the installed map have identical SHA-256:
`8777047485E8ADEAF6E8C473CEDCD48470207A32831B5DF5E3E111C3D0C99BBC`.
The canonical and installed server DLL also match:
`0036B91C01E92ED205513F52563053A55A66A32D257EFB5F476B8F1F3DDE0E63`.

## Patch and use

Apply `scripts/apply-cof-entity-visibility-trace.ps1 -SourceRoot <tree>` to the
current engine stack. Build `xash`. The script verifies markers, checks the
patch before applying, and checks the inverse afterward. `-Reverse` removes
it. There are no game-DLL or map modifications.

`cof_entity_visibility_trace scene1_1` logs exact matching targetnames at most
once per second of host time. A targetname may belong to several entities, so
the log includes each entity index, classname, model, effects, flags, model
index, sequence, animation frame, and the actual `AddToFullPack` acceptance
result. Accepted callbacks also log packet effects/model/sequence/frame.
Rejected callback output is deliberately never read because it may be
uninitialized. The original callback still runs exactly once per entity.
Set `cof_entity_visibility_trace ""` to disable logging.

`ent_info <index>` now includes effects, the decoded `EF_NODRAW` bit, model
index, sequence and frame. Use `ent_list scene1_1` first: the actor shares its
name with a manager, and a name-based `ent_info` alone may select the manager.

In an **isolated fixture only**, the supplied
`tests/cof-entity-visibility/c_apartment1_load.cfg` captures startup, forces the
map-authored hide/show/hide controls, and starts the map-authored scene to
observe its automatic cleanup. Launch with `+volume 0`, developer logging,
windowed mode, and a bounded owned process as required by the testing guide.
Do not plant the configuration into the player's runtime.

Interpretation:

* Server effects lack `0x80` after the hide control: inspect target dispatch,
  private entity state, and the map's spawn/cutscene script timing.
* Server has `0x80`, but callback accepts a packet without it: inspect the
  retail `AddToFullPack` compatibility boundary.
* Callback rejects the hidden actor or sends `0x80`, but it remains visible:
  inspect decoded client state and custom rendering. Capture client-side
  state next; do not add a model-name suppression workaround.

## Validation and limits

Forward application, reverse application, reapplication and inverse checks
passed on an isolated copy of the three changed engine files. The MSVC harness
`tests/cof-entity-visibility/run.py` compiled the actual callback/trace block
and passed 24 combinations: original acceptance values 0/1/7, trace off/on,
and exact/mismatched/unnamed/free entities. It verifies one callback call,
unchanged arguments, unmodified entity/packet state, preserved return values,
and no rejected packet dereference (a null state is supplied on rejection).
Seven additional checks compile the real trace gate and verify null/empty
settings disable it, recursive portal passes do not log, and the one-second
throttle handles ordinary and backward clock transitions. Initial central
compilation exposed an unavailable string macro; the regenerated patch uses
an explicit nonnull/nonempty test. The subsequent integrated x86 engine,
FreeVGUI, renderer and menu build passed on 2026-10-03.

Runtime validation remains pending. The prepared release fixture launch was
blocked before startup by Windows Application Control; it produced no game
log or screenshot. This is an environment execution failure, not a game crash.
No automatic launch retry was performed.

The evidence and read-only analysis scripts remain under
`stage1/cutscene-20261003`. Original assets, the player's runtime, and saves
were not modified. Required acceptance remains: reproduce the reporter's
state; confirm ordinary scene completion, skipping, and save/load; verify the
actor appears during the scene and disappears during normal gameplay.



## Bounded initial-trigger audit (follow-up)

No causal mismatch was found in the inspected chain. The following are
eliminated as *static explanations under the normal startup state*, not as
proof that the reporter's live/save state passes every gate:

* **A missing or empty brush hull:** parsing the actual original
  `c_apartment1.bsp` model `*124` gives clip-hull heads 9188, 9194 and 9200.
  Traversing each at the player spawn `(-819,-160,321)` returns
  `CONTENTS_SOLID (-2)`. The model origin is zero. The selected standing or
  crouched hull therefore passes `SV_TouchLinks`' precise-brush check when
  player bounds match the registered hull (zero hull offset). The trigger
  bounding box also contains the spawn. Evidence is
  `stage1/cutscene-20261003/inspect-hulls.py` and `hull-evidence.json`.
* **Loss of `pmove.numtouch` suppressing this trigger:** `SV_RunCmd` calls
  `SV_LinkEdict(clent,true)` before and independently of the `numtouch` loop.
  The loop handles other impact contacts. Trigger-area traversal does not
  require a nonzero movement touch count. `SV_LinkEdict` calls the retail
  `SetAbsBox`, inserts `SOLID_TRIGGER` entities in the trigger list, and calls
  `SV_TouchLinks` when touch traversal is enabled and not recursively active.
* **Only the first same-name manager being found:** the real engine
  `SV_FindEntityByString` resumes after the previous edict and enumerates all
  matches. A new compiled x86 harness (`tests/cof-entity-visibility/run-chain.py`)
  extracts that function and its real descriptor table, includes the real
  patched `edict.h`/`progdefs.h`, and verifies four discontiguous matching
  managers, an actor and manager sharing a name, freed/disconnected skips,
  and the world-edict termination sentinel. It passed.
* **Shifted target/visibility fields:** that same x86 harness verifies
  `effects=0x118`, `target=0x1CC`, `targetname=0x1D0`,
  `pContainingEntity=0x20C`, edict entvars start `0x80`, and stride `0x32C`.
  These agree with the retail instructions inspected. Engine descriptors
  use `offsetof`, not stock hard-coded field offsets.
* **Wrong touch callback slot:** retail `GetEntityAPI` copies 50 function
  pointers from preferred address `0x102119F8`; slot 4 is `0x10016980`, the
  expected Touch dispatch. That dispatch reads private data at edict `+0x7C`
  and calls the entity Touch virtual at `+0xE4`, with the other entity as its
  argument. Its suppression gates include the game's global disable and
  either entity's `FL_KILLME`. Retail `trigger_once` spawn routes to the
  trigger initializer that sets `solid=1` (`SOLID_TRIGGER`) at entvars `+0x10C`.
* **FindEntity sentinel disagreement:** retail lookup wrapper `0x10118480`
  passes the previous entity's containing edict at entvars `+0x20C` to the
  engine lookup callback, treats index zero as termination, and skips results
  with no private data. This agrees with engine lookup and its world sentinel.

Runtime-only possibilities remain: whether the player actually starts or
returns through this trigger in the failing save; the trigger's current
solid/enabled state; player `SOLID_NOT`, `playersonly`, group filters or touch
recursion gates; game touch suppression; dispatch/timing of the same-name
managers; and client state after the hide. The audit does not establish that
any of these conditions is wrong. The next useful evidence is the already
prepared visibility trace from an allowed runtime, not an unconditional
actor-hiding patch. No further launcher attempt or execution-policy workaround
was made during this follow-up.

## Allowed runtime follow-up and transition evidence

After the user changed Windows application-control settings, the existing isolated
fixture executed the combined candidate engine and VGUI successfully. All rounds
were muted, windowed, bounded, and exited normally through `quit`; only fixture
files were changed. SAVE contents were backed up/restored and hashes checked.

* `stage1/cutscene-20261003/runtime-baseline-allowed.log`: fresh `c_apartment1`
  initially has actor effects 0, but the game rejects its packet. By server time
  1.312 it has `EF_NODRAW` (0x80) and remains rejected. Explicit map show/hide
  controls work. Invoking the actual `multiscene1_1` manager shows the actor, then
  its scheduled 15-second hide sets 0x80 and rejects it again.
* `settled-visual/`: loading a save made while the actor was hidden preserves
  0x80 and packet rejection. Three settled screenshots at a fixed office camera
  show absent, present after the map's show control, absent after its hide control.
  The present actor matches the report's model/location. This isolates correct
  server-to-client hide behavior. Brush surfaces in this saved fixture appeared
  white, so these captures are not a general scene-rendering validation. Earlier
  `visual/` used an ineffective player selector, and `restore-visual/` did not
  wait after asynchronous screenshot requests; neither is counted as a visual pass.
* `normal-transition/`: started `c_start`, used its existing `1teleport` entity
  with a fixture-only destination adjustment to put the player inside the actual
  outgoing brush. Touch processing fired `CHANGE LEVEL: c_apartment1 stla`.
  The destination had no saved HL1 state and spawned fresh. Imported player origin
  was `-723 4 -343`, exactly the source position: both maps define `stla` at
  `-767 6 -343`. Actor effects were initially 0 with packet rejection, then 0x80
  by server time 1.609, remaining hidden through the bounded observation. The
  source command buffer survived the transition and issued the planned quit;
  the destination map-load script was not automatically executed on this smooth
  transition. Exit code was zero.

The normal route has a deliberate second teleport: `c_start` outgoing brush
`*158` bounds `[-763,-43,-414]..[-682,51,-304]` exactly match destination
`c_apartment1` `trigger_multiple *203`, which fires `teleportst`. Its destination
is `[-812,-160,282]` (standing player Z +37), inside initial hide brush `*124`.
This geometry and the actual transition result do not support a normal-entry
landmark-offset or missed-hide-trigger fault. An unused-looking older `land2b`
changelevel exists in c_start without a matching landmark and produces a warning
while enumerating transitions; the tested active `stla` transition succeeds.

The reporter holds a shotgun in the early Glock office. This is a clue for a
later revisit, alternate arrival, modified inventory, or another game state;
it does not identify one conclusively. Other incoming routes include c_apartment2
(`land1`, `land2`, `land3`, `land4`, `ap2la`) and c_apartment5 (`land5`). Those
landmarks do not themselves place the player in the initial hide volume. A hidden
actor loaded from an ordinary save is verified above, but an actual adjacent-map
revisit/restoration and the reporter's precise save/version are not yet verified.
No unconditional model suppression or speculative gameplay patch is justified.
Issue #1 remains open; the additive trace is a diagnostic, not a claimed fix.
