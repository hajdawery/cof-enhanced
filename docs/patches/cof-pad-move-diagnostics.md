# Movement diagnostics

`cof_pad_move_debug 1` enables four console samples per second while the engine processes game movement. `cof_pad_move_debug 0` stops logging. The setting is off by default and is not archived. It observes movement without changing speed, bindings or commands.

For a comparison, select Digital-style, close menus, enable logging, hold the stick straight forward for several seconds, then release and hold keyboard W for several seconds in the same open area. Stop logging afterwards. The console log includes the live mode, raw axes, shaped input, speed cvars, command movement before and after engine append, button bits, stick pulse flags, panel gate, predicted velocity and position. `preEngine` is the command already returned by the retail client's `CL_CreateMove`; it is not a pre-client value. Engine append does not change button bits, so the one `buttons` value describes both sides. IN_FORWARD is bit 0x0008; pulse flags use forward1/back2/left4/right8/forward-stop16/side-stop32.

The user comparison identified retail mixed-axis forward halving: keyboard300/0 produced225units/sec, while controller306.8/-23.2 produced116units/sec. [Digital speed correction](cof-pad-digital-speed.md) compensates this behavior. With that patch, a mixed controller command can intentionally show roughly twice its forward value in `postEngine`; retail movement then halves it. Compare final velocity as well as command components. Predicted velocity may also reflect collisions, crouching, game rules or acceleration. The diagnostic itself changes no movement.

Validation: additive patch apply/reverse checks and a scoped source audit ensure the diagnostic is gated before reads/formatting and the movement algorithm remains unchanged. No game was launched for this change.
