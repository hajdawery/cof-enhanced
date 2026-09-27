# On-screen keyboard and the Enter hook

Gamepad players can type. The keyboard is the project's own, drawn by the
menu in the theme; there is no Steam API and no system keyboard. It types
into the menu's text fields (Join/Host co-op: server address, name, server
name, password, ...) and, through the engine, into the game's own text fields
(the computer login). The game's Enter checks, which ask Windows directly,
are answered for a gamepad by a small import hook.

Patches ([patch stack](../dev/patch-stack.md) steps 49-51):

| Step | Patch | Target | What |
| ---: | --- | --- | --- |
| 49 | `cof-mainui-osk` | M | the keyboard window (`menus/CoFOsk.cpp`), the hooks in `controls/Field.cpp`, the prompts line |
| 50 | `cof-osk-engine` | E + V | the game's text fields: FreeVGUI reports `TextEntry` focus/clicks, the engine opens the keyboard and puts the text in (`engine/client/cof_osk.c`, `3rdparty/freevgui/platform/xash3d-fwgs/cofosk.cpp`) |
| 51 | `cof-client-enter-hook` | E | `USER32!GetAsyncKeyState` in client.dll answered for a gamepad (`engine/client/cof_enter_hook.c`) |
| 58 | `cof-osk-field-navigation` | E + V | Done advances between game fields (its original final-submit behavior is replaced by step 60) |
| 60 | `cof-osk-compact-context` | E + V + M | compact keyboard, active-field context, Done never submits the game form |

`xash.dll` and `vgui.dll` go together (step 50 adds two `vguiapi_t` entries).

## The keyboard

```
 KEYBOARD                 <field name>                        X
 [ text typed so far_                                          ]
  1   2   3   4   5   6   7   8   9   0
  q   w   e   r   t   y   u   i   o   p
  a   s   d   f   g   h   j   k   l   -
  z   x   c   v   b   n   m   ,   .   @
 [ Shift ] [ ?123  ] [ Space ] [ Delete ] [ Done  ]
 (A) Type (B) Delete (Y) Clear (X) Shift (LB) Symbols (RB) Space (View) Close (Menu) Done
```

* The symbols page (`?123`, LB) has `! @ # $ % ^ & * ( )`, `- _ = + [ ] { } ; :`,
  `' " , . / ? \ | < >`; the digits stay on top. `ABC` goes back.
* Shift: one tap = the next letter upper case, a second tap = caps lock, a
  third = off. X toggles the one-shot shift. Punctuation is not shifted.
* Pad: D-pad / left stick move (wrap around; the wide bottom keys keep the
  column you came from), **A** types the key, **B** deletes the last
  character, **B held** (0.6 s) clears, **Y** clears, **X** shift, **LB**
  symbols page, **RB** space, **START** = Done, **View/Back** = Close.
* Mouse: click a key; the X in the title band = Close. A real keyboard types
  into it too; Enter = Done, Escape = Close, Backspace deletes.
* **Done and Close both keep the text** (Y clears it). In the game, Done
  advances from the user name to the password and reopens the keyboard;
  Done on the last field closes without submitting. For a menu field Done is the
  same as Close. There is no "discard" - B is the
  in-grid delete, not Back.
* The prompts line under it shows the glyphs of the current button style
  (`cof_pad_style`, Xbox or PlayStation) while a pad is the last device, like
  the menu's own line, which steps aside while the keyboard is up.
* Password fields (`bHideInput`, or a game entry that hides its text) show
  asterisks in the preview. A numbers-only field accepts digits only, a
  field's length limit and letter case are respected.
* Strings through `L()`: KEYBOARD, Shift, Caps, Space, Delete, Done, Type,
  Clear, Symbols, Close, ABC (all seven `menu-strings.tsv`; `?123` and the key
  caps are characters and never translated).

### Menu fields

`controls/Field.cpp`: **A** on a text field opens the keyboard. It also opens
by itself when a **pad direction key moves the focus onto a field** while a
pad is the last input device (`UI_CoFPadMode`). It does *not* open when a page
opens with its first field focused (switching Extras tabs with LB/RB would
otherwise trap you in it) or when the mouse passes over a field. Over a menu
page the page is dimmed; Done / Close write the field (and its cvar, if any)
and send `QM_CHANGED` like typing does.

### The game's fields

```
 pad A on the computer's user name (the gamepad cursor's click)
   Key_Event: last key = pad (CL_CoF_OskNoteKey)
   FreeVGUI TextEntry::mousePressed / focus change -> CofOsk_Hook -> vguiapi_t::CofOskEntry
   engine: pad last, game focused -> keyboard due in 2 painted frames
           (the game clears its "Enter a username..." placeholder on the click)
   CL_CoF_OskFrame (VGui_Paint): cof_osk_field / cof_osk_hidden <- the entry's text now;
           "menu_cof_osk game" at the head of the command buffer
 menu: the keyboard is the only window of the menu, no scrim, cof_osk_over_game 1
   engine: VGui_Paint and VGUI_IsInGame keep the game's panels painted under it
 Done / Close: menu sets cof_osk_result (hex) + cof_osk_submit (1 Close, 2 Done), closes
   CL_CoF_OskFrame: vguiapi_t::CofOskCall op 0 -> TextEntry::setText on the focused entry;
           Done: CofOskCall op 3 schedules the next sibling field, then the keyboard reopens;
                 the last field closes; the user presses the game's OK button themselves
```

A keyboard-and-mouse player never gets it: a real key or mouse button is the
last input. (A real mouse click reaches FreeVGUI before its own key event, so
right after pad use a mouse click can ask for the keyboard; the request is
dropped when that key event has arrived by the time it is due.) The server is paused while the menu is open (single player), as
with the pause menu; the game resumes when it closes.

Engine cvars: `cof_osk` (saved, 1; 0 = never open over the game),
`cof_osk_trace` (developer); internal: `cof_osk_over_game`, `cof_osk_field`,
`cof_osk_hidden`, `cof_osk_result`, `cof_osk_submit`. Commands:
`cof_osk_status`, `cof_osk_set <hex>|-` (text into the focused game field by
hand), test hook `cof_osk_probe <n> [keyboard]` (clicks the n-th visible game
text entry as the mouse would, with the pad as the last input; `keyboard`
leaves the last input alone). Menu: `menu_cof_osk game|status`.

## The Enter hook

client.dll (retail 1.6) reads Enter from Windows at two places, both
`call [1013A26C]` = `USER32!GetAsyncKeyState(VK_RETURN)` with a bit-15 test
(`bt ax, 0Fh`):

| Site | What | Notes |
| --- | --- | --- |
| `1003F54C` (returns to `1003F550`) | `CComputer::solve`, the computer login | then a 1.0 s `GetClientTime` debounce at `+0xBC`, then `computercheck <user> <password>` |
| `1003D21E` | `CHUDControl` chapter / commentary card, "Press Enter to skip" | only called while a card is up |

No other call site uses the import (the only other reference is an unused
`jmp [1013A26C]` thunk at `100B427A`, no callers). Static tools:
`stage1/osk-20260923/tools/cl_enter_sites.py`, `cl_dis.py`.

`cof_enter_hook.c` puts its own function into that import slot of client.dll
right after it is loaded (next to the language packs' `CreateFileW` hook, same
technique). For `VK_RETURN` it answers "down" (`0x8001`):

* for **one frame of polls** after `cof_enter_pulse` (the keyboard's Done;
  any cfg can run it); an unanswered pulse expires after 2 s;
* after **START on a gamepad while the game is polling for Enter** (a poll in
  the last 0.25 s: the computer is open, or a card is up). That START press
  arms the pulse and is used up (not the pause menu over the computer); with
  nothing polling, START does what it always did. `cof_enter_pad 0` turns
  this off;
* while `+cof_enter` is held (bindable, for anyone who wants a button of their
  own; not bound by default).

While the engine menu or the console owns the keyboard, a **real** Enter is
hidden from the game: Enter typed into the console, the pause menu or the
keyboard no longer logs the computer in behind them. Every other key and
caller get Windows' answer. `cof_enter_status` prints hook state, polls,
answers; `cof_enter_trace 1` logs every answered poll with its call site
(`client.dll+0x3F550` = the computer).

## Measured (stage1/osk-20260923/RESULTS.md)

* Menu: A on Join co-op's address opened it, `127.0.0.1` typed with the
  D-pad and Done wrote the field; D-pad down to "Your name" opened it by
  itself; Y, shift, symbols page, B, B held (clear), View (Close), Escape;
  Polish at 3840x2160.
* Game (c_start2, the computer): the keyboard over the live computer; user
  name by Close, password by Done: the game answered "Invalid username or
  password!" (a `computercheck` went out); START on the open computer =
  Enter at `client.dll+0x3F550`; START with nothing polling passed through
  to its binding (`cancelselect`); a keyboard player's click opened nothing.

## Gamepad round 4: Done advances through the computer fields

`cof-osk-field-navigation` is additive after the gamepad patch and before the
final cheats patch. Apply with `scripts/apply-cof-osk-field-navigation.ps1`.
It changes the engine and FreeVGUI; the existing menu keyboard needs no new
controls or translations. Its Start/Menu button and Done key use the same
path. Build and deploy `xash.dll` and `vgui.dll` together when that work is
requested; this source change has not been deployed.

`cof_osk_next_field` is archived and defaults to 1. With it enabled, Done
writes the current text, finds the next visible enabled TextEntry under the
same parent in top-to-bottom, left-to-right order, and schedules its normal
entry click. Child order breaks position ties. Hidden/disabled entries and
other forms are excluded. It never wraps from the last field to the first.
The focus request is asynchronous: FreeVGUI commits it in `externalTick`,
so the engine waits its existing two painted frames, reads the newly focused
entry, then opens the keyboard. The last field closes without submitting (step 60 replaces the original
step-58 Enter pulse). Close writes text without advancing or submitting. Set
`cof_osk_next_field 0` to have Done close on every field; it still never submits.

A missing or hidden focused entry is rejected before writing or navigation;
remembered focus addresses are rediscovered in the visible live panel tree.
A disabled form or lost game focus does not submit. The existing bounded
TextEntry registry is retained; this does not add destructor tracking or
change FreeVGUI's ABI. Op 3 on the existing `CofOskCall` returns 1 for a
scheduled advance, 0 for the final field, and -1 for unavailable focus/form.
The existing `cof_osk_trace` and report messages distinguish next-field,
final-submit, and unavailable-form paths without printing entered text.

### Evidence and limits (2026-09-27)

Read-only disassembly of retail `client.dll` confirms the computer fields
are direct siblings: user name `[edi+0xD4]` and password `[edi+0xD8]` both
call `Panel::setParent` (vtable offset 0x40) with `[edi+0xE0]`, at
`0x1003ECEA` and `0x1003EDC1`. Their constructor positions are y=0xCC and
y=0xE7. Restricting traversal to the same parent therefore covers this form
without reaching unrelated panels. The internal entry-click path is the
same one used by the previously play-tested `cof_osk_probe`; it does not
inject keyboard or mouse input into Windows.

`tests/cof-osk-navigation/run.py` compiles two small contract harnesses from
the actual patched FreeVGUI implementation and engine frame function, with
external APIs stubbed. In an MSVC developer shell, run:

```powershell
python tests/cof-osk-navigation/run.py --source-root <patched-tree> --out <scratch-folder>
```

Verified: deferred focus commitment; username text retained; next field then
close without final submission; no wrap; screen order despite reversed child order;
hidden/disabled entries, disabled/hidden parents, unrelated and nested forms;
removed or lost focused entries; Close; cvar off; failed text write; lost game
focus; unavailable Enter hook; delayed reopening and no repeated submit.
The apply script was applied, reversed, and reapplied on a private source
fixture with inverse checks. These are source/contract checks, not a game
play-test. No full rebuild, game launch, OS input injection or deployment was
performed. Computer login, placeholder clearing, and physical-pad behavior
still need a user-authorized runtime verification after a future build.

## Compact keyboard and active field (2026-09-27 follow-up)

User feedback after gamepad round 4: the keyboard covered too much of the
computer form, the active field was unclear, and Done must not activate the
computer's login. The additive `cof-osk-compact-context` patch follows the
round-4 navigation/controls patches. Done still advances through fields,
but the final Done only keeps text and closes. No `cof_osk_next_field` value
causes automatic submission. The player uses the game's own OK control.
The separate dismissal guard patch also prevents a held Enter/START from
leaking through when the keyboard closes.

The panel is 508 by 292 virtual units, down from 678 by 394 (about 75% in
each dimension). It inherits the existing UI display scaling; there is no
new keyboard-size setting. Title and preview font heights stay readable.
Long translated key labels shrink to fit their keys, and a long input
preview shows its tail/caret without splitting UTF-8 characters. Password
masking still follows the game's TextEntry hidden flag. The two four-prompt
rows fit within the panel width, measuring and scaling each row for long
translations; they no longer span most of the screen.

The game keyboard's title says **Field 1 of 2**, then **Field 2 of 2**.
`Field %d of %d` is a translated menu key. FreeVGUI computes the index/count
from the visible enabled sibling entries in the same screen order used by
navigation, returning them in op 4 of the existing callback (count in the
high byte, one-based index in the low byte; 0 for unavailable focus).
The engine exposes `cof_osk_field_index` and `cof_osk_field_count` only as
internal metadata. It does not guess labels from player-entered text, and
no password text is added to the title or logs. Menu-owned fields retain
their existing captions.

The updated compiled contract harness covers field metadata and verifies
that final Done and the cvar-off path produce **zero Enter pulses**. A
second harness extracts the actual menu `VidInit`, `KeyRect`, and `DrawHints`
methods and records drawing calls with a stub font metric. It verifies
panel/key/prompt bounds at 640x480, 1280x720, 1920x1080, 2560x1440,
3840x2160 and 5120x2160, including long translated-label stress cases:

```powershell
python tests/cof-osk-navigation/run_layout.py --source-root <patched-tree> --out <scratch-folder>
```

Both harnesses passed; the additive apply script passed apply/reverse/reapply
and inverse checks. Stub font metrics do not replace visual verification
with real fonts and the game. No game launch or deployment was performed
for these worker checks; final appearance and real computer login remain
runtime verification items.
