# Controller option traversal and selection lists

`ui_cof_dropdowns 1` (archived default) changes selection fields throughout the
themed Cry of Fear UI to anchored dropdown lists. `0` restores existing spinner,
dropdown, resolution-table and column-navigation behavior. The theme/options
layout gate still applies; other games keep their controls.

Up/Down and Tab visit every visible enabled control in top-to-bottom,
left-to-right order, including the other column and the HUD/scale split row.
Decorations, hidden items, disabled fields and mouse-only items are skipped.
Left/Right on closed selectors return to normal spatial navigation; sliders
retain their normal Left/Right adjustment. Binding/profile management tables
remain lists, with their existing edge escape.

A/Enter or a click opens a selection list. Up/Down moves its highlighted option
without changing a setting. A/Enter or a row click commits; B/Escape or an outside
click cancels. The original control regains focus. A separate top window consumes
input while open, so cancellation cannot close Options and bumpers cannot switch
its underlying tab. Lists show at most eight rows, scroll to keep selection
visible, and open above the control when space below is insufficient. Resolution
uses the same list while preserving the existing Apply/revert behavior.

SpinControl retains its model, float step, formatting and SetCurrentValue/event
path. Existing DropDown string/int/float controls retain SetCvar/onChanged.
Only confirmation calls a setter. No individual language, HUD, controller or
renderer option mapping is replaced. Runtime disabling, a hidden/closing owner,
or a disabled field closes the popup without a commit.

Verification: six actual modified/new MainUI translation units compile against
the current pinned source headers. `tests/cof-selection-list/run.py` compiles
the actual popup and navigation implementations with recording UI stubs. It
checks release pairing, delayed commits, cancel/outside click, focus return,
scrolling, screen bounds at 480/720/1080/2160 height, the Game tab's concrete
two-column and three-selector row sequence, and exhaustive traversal/inverse
coverage for varied holders of 1 through 160 items. These verify the traversal
invariant for arbitrary option-page geometry; they are not an interactive
per-page controller test. Visual language fitting and real controller operation
still need a runtime pass.
