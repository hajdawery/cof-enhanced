# Gamepad round 4: dodge and quick turn

`cof-gamepad-controls.patch` is additive after `cof-gamepad-input` and before
the cheats patch. It changes engine input and the MainUI Gamepad action list.
No upstream patch is regenerated.

The default controller layout advances from generation 4 to 5: RB uses
`+dodge`, the game's action bound to ALT; R3 uses `cof_quickturn`. B still
toggles crouch. `+alt` is not the action in the shipped `kb_act.lst` or our
ALT default binding. The Gamepad page reads current bindings and includes a
fallback Dodge label. The shared `kb_def.lst` carries the same defaults.

Migration handles generations 1 through 4, changing a button only when its
current binding equals that generation's default. Custom bindings and empty
bindings stay as they are, including profiles with every pad binding cleared.
Generation 0 with no bindings still gets the initial layout. The existing
`cof_pad_defaults force` command explicitly resets all buttons. This pad
generation is independent of the MainUI keyboard defaults generation.

`cof_pad_no_doubletap` is saved and defaults to **1**. The engine temporarily
sets only the numeric `cl_nodoubletapdodge` value while calling the client's
synchronous movement-command handler for a stick pulse, then restores the
exact previous value. It does not alter the cvar string, flags or config.
The keyboard command path and RB's explicit dodge do not pass through this
guard. Setting `cof_pad_no_doubletap 0` restores the earlier stick pulse path.
Stick shaping and hysteresis remain intact. The helper also covers movement
from the engine's legacy combined joystick/touch path; it does not override
custom aliases that defer their work through the command buffer.

## Evidence and limits

Measured source facts: shipped action data binds ALT to `+dodge`; the existing
client research identifies synchronous double-tap detection in the directional
handlers (for example `+forward` at `10078F9A`). Engine `Cmd_ExecuteString`
calls a registered handler synchronously, and `Cvar_RegisterVariable` retains
the client's cvar object, so the scoped numeric override reaches that handler.

`tests/cof-gamepad-controls/test-controls.py` compiles the actual patched
layout, migration, defaults and movement-guard functions with a small host
harness. It checks old-generation migrations, custom and cleared bindings,
default reset, absent/disabled guard, exact restoration, nested calls, and the
ordinary keyboard path. Apply/reverse scripts and source-stack verification
check integration separately. These are source-level checks, not an app build.

No game was launched, no game binaries built or deployed. Manual validation still
needed after a targeted build: repeated full stick flicks in all directions
must not dodge, RB must dodge in the desired direction, R3 must turn 180
degrees, keyboard double taps must retain the player's setting, and saved
custom bindings must survive migration/restart. The mixed keyboard/stick
direction-handler timestamp interaction remains unmeasured in the retail
client; source tests establish scoped suppression, not hardware behavior.
