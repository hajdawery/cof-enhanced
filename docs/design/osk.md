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
* **Done and Close both keep the text** (Y clears it). Done also confirms: in
  the game it presses Enter for the game once (the computer logs in); for a
  menu field it is the same as Close. There is no "discard" - B is the
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
           Done: "cof_enter_pulse" (step 51) -> the computer's own Enter check sees one press
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
