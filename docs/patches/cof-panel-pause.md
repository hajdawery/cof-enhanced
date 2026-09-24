# Stop the world while a safe panel is open (`cof_panel_pause`)

Engine + FreeVGUI patch `patches/cof-panel-pause.patch`, applied with
`scripts/apply-cof-panel-pause.ps1`. It goes on after
`cof-notify-option` (step 47 of [the patch stack](../dev/patch-stack.md))
and before `cof-cheats`, which still applies on top unchanged;
[`cof-panel-transparency`](cof-panel-transparency.md) builds on it.
Research: `stage1/controller-research-20260923/RESULTS.md` (Q2); evidence:
`stage1/panels-20260923`.

`xash.dll` and `vgui.dll` must be deployed together (a new `vguiapi_t` entry).

## What it does

Cry of Fear never stops the world for its in-play panels: while the inventory
or a note is open, monsters keep moving and attacking. With
`cof_panel_pause 1`, **in single player only**, the server stops simulating
while one of these panels is on screen:

| panel | client class | paused |
| --- | --- | --- |
| inventory | `CRECBInventory` | yes |
| documents list | `CDocuments` | yes |
| note | `CNoteDocument` | yes |
| user document | `CUserDocument` | yes |
| billboard | `CVGUIBillboard` | yes |
| YES/NO question | `CYesno` | yes |
| tape recorder SAVED GAMES page, its confirm box | `CSaveLoad`, `CSave` | yes |
| phone | `CPhone` | **never** |
| landline | `CTelephone` | **never** |
| computer | `CComputer` | **never** |
| padlock | `CPadlock` | **never** |
| boiler puzzle | `CPuzzleBar` | **never** |
| keypad, animal statue, text window | `CKeypad`, `CAnimalStatue`, `CParanoiaTextPanel` | never (tier 2 of the research, left alone) |
| any other modal client panel (menu-map pages, old game over, gallery, command menu) | | never |

If a "never" panel is on screen together with a tier-1 one, the world runs.
The excluded panels wait for something scripted in the world (a call that
answers, a door the keypad opens), are the live 3D scene themselves (the
padlock), or debounce on the client clock, which only moves inside a 0.1 s
window while the server clock stands still (the phone's 0.2 s digit
debounce, the computer's 1.0 s Enter debounce) - see the research, section 2.4.

## How

**Which panel is open** is read, not guessed: the VGUI support library walks
the client's panel tree once per painted frame (root, the client viewport,
its panels; depth 3, visible panels only) and names each panel by its class.
client.dll is built with MSVC run-time type information, so the complete
object locator in front of every vtable leads to the decorated class name
(`.?AVCRECBInventory@@`). Every pointer is checked with `VirtualQuery` before
it is followed and results are cached per vtable, so nothing depends on an
address inside client.dll, and an object without type information is simply
not recognised (`3rdparty/freevgui/platform/xash3d-fwgs/cofpanels.cpp`,
`cofmem.cpp`). The library reports one `COF_PANEL_*` bit per visible class to
the engine through the new `vguiapi_t::CofPanelReport` (`engine/vgui_api.h`).

**The engine's one "panel open" answer.** `CL_CoF_PanelsOnScreen( &reporting )`
(declared in `engine/common/common.h`) returns the bits of the latest fresh
report without the HUD container, 0 when the report is stale, and says whether
a fresh report exists. The gamepad input ([`cof-gamepad-input`](cof-gamepad-input.md))
takes it as the source of truth for "a clickable panel is open" (since m8);
its old arrow-cursor test is only the fallback when the class list names
nothing.

**The pause** is the one the engine menu already uses in single player
(`engine/client/cof_panel_pause.c`):

* `SV_IsSimulating()` returns false (`engine/server/sv_main.c`, next to the
  `playersonly` test): no entity thinks, no physics, `sv.time` stands still;
* `SV_ExecuteClientMessage()` zeroes the player's movement
  (`engine/server/sv_client.c`, the same test the death page uses);
* string commands keep running (`inventoryequip`, `closedocument`, the tape
  recorder's `unfreezesave`, `save`), and the server keeps sending messages.

It is **not** the `pause` command: `cl.paused` is never set, so the client
clock, the sound mixer, the MP3 stream, the client's own irrKlang music and the
HUD keep running.

The predicate (`CL_CoF_PanelPaused`) is true only with `cof_panel_pause 1`,
`cls.state == ca_active`, `key_dest == key_game`, `cl.maxclients <= 1`, not the
background map, a local server with `svs.maxclients <= 1`, a tier-1 panel
visible and no excluded one. The report goes stale after two host frames
without a painted VGUI frame (engine menu, console, loading), so nothing stays
paused on an old report. It is counted in frames, not seconds: one slow frame
(a screenshot being written) must not let the world run for a frame.

## Cvars and commands

| name | default | flags | meaning |
| --- | --- | --- | --- |
| `cof_panel_pause` | `0` | saved | 1 = stop the single-player world while a tier-1 panel is open |
| `cof_panel_trace` | `0` | | developer: 1 logs every change of the visible panels and of the pause, with `sv.time` and the world frame count; 2 also names each panel class the first time it is on screen; 3 (with the transparency patch) dumps the open panels' trees |
| `cof_panel_status [tag]` | | command | one line: panels on screen, pause, `sv.time`, world frames, `simulating`, `ingame` |

The menu checkbox ("Pause on Inventory", Game page) belongs to the options
relayout; it links `cof_panel_pause` (0/1).

## Measured (`stage1/panels-20260923/RESULTS.md`)

Every tier-1 panel that could be opened without a mouse click (inventory,
note, billboard, YES/NO, tape page) held `sv.time` and the world frame count
constant across ~100 frames; where a close path was reachable from a cfg (the
inventory by its own key, the note through hl.dll's own "hide every menu")
the world ran again from the frame the panel disappeared. Every excluded
panel that could be opened (landline, computer, padlock, boiler puzzle, and
the tier-2 keypad) left the world running. The tape recorder
page kept the pause while a `save` was written (the save works in the paused
state, exactly as pause-menu saves do). A `changelevel` with a panel up
starts the next map simulating.

What a real click does and a log cannot prove (music audible, the tape slot
click, the documents list, the user document, the phone) is on the manual
checklist in the RESULTS file.

## Known behaviour

* Items used from the inventory take effect when it closes (weapon deploy,
  syringe healing over time, a key used on a door): the commands arrive at
  once, the thinks run after the pause.
* A YES/NO answer and whatever a note's `closedocument` triggers happen at
  close, the retail order.
* Looping world sounds keep playing (the mixer is not gated).
* Co-op and listen servers with clients are never paused.
