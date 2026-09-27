# Close the game pane before pause

`cof_panel_escape 1` (default, archived) gives Escape to the open game pane
before the engine pause menu. `0` restores the existing engine-first Escape
route. Controller Start receives the same behavior when bound to `cancelselect`;
the keyboard path does not require a connected controller or gamepad cvars.

The engine checks a fresh recognized VGUI panel report during active gameplay.
It first invokes the panel's native Back/Close/Cancel button. Inventory alone
uses the client's `+inventory` key handler; remaining recognized panes get the
client's own Escape handler. None opens pause on that same press. The normal
engine Escape path remains available when no pane is reported. OSK handling
still has its existing priority.

The whole physical press is captured, including repeat and release, even if
the pane closes, focus changes, or the cvar is changed while the key is held.
Already-captured repeats/releases are consumed before the OSK/Enter hooks can
acquire them; key-down state is updated explicitly in that early path. Fresh
presses retain OSK/Enter priority. Key-state clearing resets the capture. This prevents one press closing a pane
and then opening pause through a repeat or leftover release.

## Notes without an X

Retail `CNoteDocument` and `CUserDocument` can hide their close button while its
native action signal remains present. The existing VGUI back search inspected
only visible buttons and selected the underlying Documents list before these
foreground document panels.

Note and user-document rules now precede the Documents rule. A second search
may include hidden descendants only for the exact `CNoteDocument` close
handler command 3 or `CUserDocument` close handler command 1, at the validated
command offset 8. The recognized parent and its ancestor chain must be visible.
Other hidden buttons and other commands cannot use this exception.

Calling the native button action preserves both client-side closure and its
server notification. No standalone `closedocument` command is queued, and no
input is injected into the operating system. Unknown panes retain the existing
engine behavior unless recognized by the established panel report.

## Verification

`tests/cof-panel-escape/run.py --source-root <tree> --out <evidence>` compiles
the actual engine helper and VGUI search/back functions with recording stubs.
It verifies pane closure before pause dispatch, repeat/release capture across
focus changes, opt-out, inventory and native Escape routing, controller Start
binding checks, layered note-before-list behavior, hidden close buttons,
wrong-command rejection, other hidden-button rejection, and ancestor visibility.

The apply script validates prerequisites, both markers and the inverse patch.
A private apply/reverse fixture compares source contents after roundtrip.
These tests do not launch the game; keyboard/controller play testing remains
necessary for the game's individual pane implementations.
