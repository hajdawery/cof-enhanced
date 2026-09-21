# Cry of Fear unified UI input gate (`cof_ui_input_gate`)

Milestone 1 of the unified UI stack. When the engine menu (`mainui`), the
console or the chat line owns input, the Cry of Fear client must neither paint
its VGUI/HUD layer nor receive keyboard and mouse input, and `Escape` must
always reach the engine so the engine menu can be opened even while a CoF VGUI
panel is up. When the game itself has focus nothing changes.

The behaviour is behind the engine cvar `cof_ui_input_gate`, default `1`. It is
deliberately **not** `FCVAR_ARCHIVE`, so an old `config.cfg` cannot silently pin
it off; set it on the command line (`+set cof_ui_input_gate 0`) or in a cfg when
you want the stock behaviour back for a comparison.

The same patch carries a second, independent milestone-1 cvar,
`cof_ui_deferred_cmd_guard` (default `1`, also not archived), which fixes the
"opening the engine menu throws the session away" blocker. It has its own cvar
because it is a different scope - a stale command-buffer entry, not input
ownership - and because the two then A/B independently. See
"The deferred `map c_game_menu1`" below.

This patch also packages the two `cof_skip_client_hud_redraw` /
`cof_skip_vgui_paint` diagnostics that had been living untracked in the engine
checkout. They are kept as independent unconditional overrides (both default
`0`) because they are the only way to attribute a drawn element to a specific
client callback; the gate is `AND`-ed with them, it does not replace them.

## What the patch does

`CL_CoF_UIGateActive()` (`engine/client/cl_main.c`) is the single predicate:

```c
qboolean CL_CoF_UIGateActive( void )
{
    if( !cof_ui_input_gate.value ) return false;
    return cls.key_dest != key_game;
}
```

It logs every transition at developer level as
`[cof-ui] input gate engaged/released (key_dest=N)`
(`0` console, `1` game, `2` menu, `3` chat line).

Unlike `CL_IsInGame()` it has **no** background-map or multiplayer exception.
That is the point of the patch: see "Why this is needed" below.

| Site | Change |
| --- | --- |
| `engine/client/dll_int/cl_game.c` `CL_DrawHUD` | `clgame.dllFuncs.pfnRedraw` is skipped in the `CL_ACTIVE` and `CL_PAUSED` cases while the gate is active. Everything the engine itself draws (screen fade, crosshair, centerprint, pause icon) is untouched. |
| `engine/client/vgui/vgui_draw.c` `VGui_Paint` | returns early while the gate is active. |
| `engine/client/vgui/vgui_draw.c` `VGui_KeyEvent`, `VGui_MouseEvent`, `VGui_MWheelEvent`, `VGui_MouseMove`, `VGui_ReportTextInput` | gated. Gating the function rather than the call site also covers the touch input path in `in_touch.c`. |
| `engine/client/input/in_keys.c` `Key_Event` | a narrow branch, ahead of the client first-refusal block, that routes `Escape` straight to `CL_Escape_f`. |
| `engine/client/dll_int/cl_gameui.c` `UI_UpdateMenu` | the deferred-client-command flush is dropped instead of executed while `cof_ui_deferred_cmd_guard` is on. |

### Key delivery bookkeeping

`vgui_draw.c` keeps `vgui_key_delivered[256]` and only ever hands VGUI a release
for a press it actually received (`VGui_CoF_DeliverKey`). This is not cosmetic:

* gating presses alone leaks the matching release into a CoF panel. Measured on
  2026-09-21: with only presses gated, the escape **release** reached the CoF 3D
  menu and the panel re-issued `map c_game_menu1`.
* gating releases alone leaves a key pressed during gameplay stuck down inside
  the support library once focus moves to the menu.

`Key_Event`'s escape branch calls `VGui_CoF_ForgetKey( key )` so the release of
the escape press it swallowed is not delivered either.

### Escape arbitration

```c
if( cof_ui_input_gate.value && key == K_ESCAPE && down && cls.key_dest == key_game )
```

Only `K_ESCAPE`, only key down, only while the game has focus, only with the gate
on. `r_showtextures` is honoured first exactly as the generic handler does,
autorepeat is suppressed (`keys[key].repeats > 1`), `gamedown` is cleared, a
developer-level `[cof-ui] escape routed to the engine` line is printed, and
`CL_Escape_f()` runs.

Every other key keeps the upstream client-first behaviour verbatim, including
the CoF computer-input workaround for FWGS issue #1923 and the
issue #1943 / #528 compromise in the generic escape handler.

**Double-fire:** there is none, and there is strictly *less* client involvement
than before. With the gate on the CoF client never observes the escape key-down
(`pfnKey_Event` is not called) and never observes the release (delivery
bookkeeping drops it), so the client's own escape handling cannot run alongside
`CL_Escape_f`. With the gate off the stock path is unchanged: during ordinary
gameplay the client is offered the key first and, whatever it answers, VGUI also
gets the key, which is the upstream behaviour.

Escape with the console open is untouched: `key_dest` is `key_console`, the new
branch does not fire, and `Key_Console` closes the console as before. Escape with
the engine menu open is untouched: `key_dest` is `key_menu` and mainui receives
the key through `UI_KeyEvent`, so the menu still toggles shut.

## Why this is needed even though the CoF client already hides itself

Measured, 2026-09-21, fixture `stage1/ui-m1-engine-fixture-20260921`:

* The CoF HUD and the CoF 3D menu are drawn through **`VGui_Paint`**, not through
  `pfnRedraw`. `cof_skip_vgui_paint 1` removes them in game;
  `cof_skip_client_hud_redraw 1` does not
  (`evidence/case7-layer-probe-{a,b,c}.png`).
* FreeVGUI's `XashPaint`
  (`3rdparty/freevgui/platform/xash3d-fwgs/app.cpp:53-55`) already returns early
  unless `g_engine->IsInGame()`, which is `CL_IsInGame()`. In single player that
  is `cls.key_dest == key_game`, so in a plain SP map the CoF layer already
  disappears under the console and the chat line without this patch.
* **But `CL_IsInGame()` returns `true` unconditionally when `cl.background` is
  set or `cl.maxclients > 1`** (`engine/client/cl_main.c:123-131`). Those are
  exactly the `map_background c_game_menu1` unified-main-menu configuration and
  CoF coop. There the client layer is *not* suppressed by the support library.
* The `pfnRedraw` path has no such guard at all.

So the audit's statement that `VGui_Paint` is ungated is correct about the
engine, and the gate is what makes the invariant hold in the configurations the
unified UI actually uses, independently of the support library.

## Validation

Fixture: `stage1/ui-m1-engine-fixture-20260921` (minimal runtime, canonical
assets reached through NTFS junctions/hardlinks, `-rodir` deliberately not used).
Build `build-cof-ui-m1-engine-20260921`, `engine/xash.dll` SHA-256
`D63FFD97D7F44A7FA0BB572F34D62F8693B76C17F77097505D495FD79ABF965D`.
Every launch used `+volume 0` and ran windowed at 1280x720.

Measured:

* gate transitions fire at every `key_dest` change and only there
  (`case2`, `case4`, `case5`, `case24` logs);
* real `keybd_event` Escape injection with the CoF 3D menu panel up produced
  `[cof-ui] escape routed to the engine, client key handling bypassed` followed
  by `[cof-ui] input gate engaged (key_dest=2)` (`case12`, `case15`, `case18`);
  with the gate off the same injection produced no such line at all and the
  engine menu never opened (`case13`, `case19`) - the audit's swallowed-Escape
  behaviour, reproduced;
* console typing is unaffected: with the gate on, `~` then a typed
  `screenshot ...` then Enter executed and produced the image, and Escape then
  closed the console instead of opening the menu
  (`case24-console-typing-gateon.log`, `case24-typed-screenshot.png`);
* `VGui_Paint` is the layer that draws the CoF HUD (`case7`).

Not measured, established by code review:

* that the gate's early returns in `VGui_Paint` / `CL_DrawHUD` change the
  rendered image. With the stock CoF client and the stock mainui there is no
  configuration reachable from a console script in which the two differ: the
  support library already self-suppresses in SP, and mainui's in-game background
  is an opaque fill (`controls/BackgroundBitmap.cpp:66-69`), so the menu case is
  pixel-identical with the gate on and off (`case2-gate-on-menu-b.png` hashes
  the same as the pre-patch baseline `step0-baseline-overlap-b.png`). The gate's
  visible effect appears once the pause scrim becomes translucent and once the
  main menu runs over a background map.
* menu keyboard navigation: the patch adds no code in the `key_menu` branch of
  `Key_Event`.

### `cof_ui_deferred_cmd_guard`, 2026-09-21

Same fixture, now carrying the **assembled milestone 1**: the scrim
`cryoffear/cl_dlls/menu.dll` `B0D3ACCD...`, `scripts/chapterbackgrounds.txt`,
`maps/c_game_menu1.ent` and the milestone `gameinfo.txt` from
`stage1/ui-m1-menu-fixture-20260921`. Build `build-cof-ui-m1-engine-20260921`,
`engine/xash.dll` SHA-256
`B22D83CEBA5EDC9944FF8A07BA9485B22088F4B3E0C660006474F652FEE5220E`.
All launches windowed 1280x720 with `+volume 0`, `-dev 2`, `+set developer 2`.

| Run | What it shows |
| --- | --- |
| `v2-ingame-menumain-guardon` | `+load cofsave1` -> `Spawn Server: c_forest3`, bound key -> `menu_main`: `input gate engaged (key_dest=2)`, `dropped stale deferred client command "map c_game_menu1"`, **no second `Spawn Server`**. `-b.png` is the engine pause menu over the paused forest through the translucent scrim; Escape closes it (`released (key_dest=1)`) and `-c.png` is the resumed scene with the CoF HUD back |
| `v4-ingame-escape-guardon` | same through real `keybd_event` Escape: `escape routed to the engine`, gate engaged, command dropped, map still `c_forest3`, `-c.png` resumed |
| `v5-ingame-menumain-guardoff` | control in the **same binary** with `+set cof_ui_deferred_cmd_guard 0`: `Spawn Server: c_game_menu1` right after the menu opens - the blocker, reproduced |
| `v11-mainmenu-bgmap` | plain boot: command dropped, `map_background c_game_menu1`, `cl_background` is `1`, engine main menu over the live snowing skyline with no CoF overlay |
| `v12-newgame-quit` | New Game chosen with real arrow/enter keys in the engine menu -> `Spawn Server: c_difficulty_settings` |

## The deferred `map c_game_menu1` (`cof_ui_deferred_cmd_guard`)

The blocker recorded here earlier - "on any CoF map, bringing the engine menu up
makes the client load `c_game_menu1`" - is **found and fixed**. It was not a
reaction to the menu taking focus at all, and not the client's `IN_DeactivateMouse`
or `HUD_Frame`. It is a boot-time command that the engine keeps and replays late.

### Measured chain

1. Cry of Fear's `HUD_Init` (`client.dll` `1001D4A0` -> `10079A60`, tail at
   `1007A45B`) ends with
   `push 101427F4h ("map c_game_menu1"); call ds:[101B2658h]` at VA `1007A4B8`
   (`101B2658` is `cl_enginefunc_t` index 20, `pfnClientCmd`; the return address
   is `1007A4CD`). It also writes `1` into its own state word `10542A68`. This is
   Cry of Fear booting itself into its 3D-menu map.
2. `CL_LoadProgs()` - which calls `HUD_Init` - runs at `engine/client/cl_main.c:4037`,
   **before** `cls.initialized = true` at `:4041`. So `pfnClientCmd`
   (`engine/client/dll_int/cl_game.c:1913-1926`) takes its `else` branch and
   appends the string to `host.deferred_cmd` (`engine/common/common.h:303`,
   128 bytes) instead of running it.
3. Nothing else ever touches `host.deferred_cmd`. Its only consumer is
   `UI_UpdateMenu` (`engine/client/dll_int/cl_gameui.c:43-49`), which flushes it
   with `Cbuf_AddText` + `Cbuf_Execute` **the first frame `UI_IsVisible()` is
   true**. In a running game that is the frame the player opens the engine menu,
   so `map c_game_menu1` executes and the save is gone.

The other four references to the string in `client.dll` (`10029DDC`, `10031680`,
`10040B74`, and the `to3dmenu` console command at `1006E38A`) are VGUI panel
handlers and were not involved; `IN_ActivateMouse` (`1007C160`) and
`IN_DeactivateMouse` (`1007C1D0`) only toggle the client's own mouse state and
issue no command at all.

### How it was measured

A temporary instrumented engine printed, for every `Cbuf_AddText` /
`Cbuf_AddFilteredText` whose text contains `c_game_menu1`, the return address
plus the owning module and RVA (`GetModuleHandleExA`), and for every
`pfnClientCmd` / `pfnServerCmd` the client-relative return address, together with
a marker naming the engine->client callback then on the stack. It also traced
`IN_ActivateMouse` / `IN_DeactivateMouse` and the user-message dispatch.

The decisive line (`stage1/ui-m1-engine-fixture-20260921/evidence/diag3-module.log`):

```
[cof-ui] input gate engaged (key_dest=2)
[cof-diag] Cbuf_AddText <map c_game_menu1
> ra=535B30E7 module=xash.dll+0x1030E7 cb=engine key_dest=2
```

`xash.dll+0x1030E7` resolves through the build's own PDB to
`UI_UpdateMenu+0x37`, `engine/client/dll_int/cl_gameui.c:46`. No `ClientCmd`,
`ServerCmd`, stufftext or client callback fired at that moment - the engine
replayed its own stale buffer. The same run shows the only `pfnClientCmd` for
that string happening once, at startup, with `state=0`.

### The fix

`UI_UpdateMenu` drops the pending buffer instead of running it while
`cof_ui_deferred_cmd_guard` is on, and reports it once at developer level:

```
[cof-ui] dropped stale deferred client command "map c_game_menu1"
```

`host.deferred_cmd` can only be written before `cls.initialized`, so everything
in it is a boot-time command. If it is still pending when the engine menu is
first up, it has missed its moment; running it then is never what the client
meant. With the cvar at `0` the stock code path runs unchanged and the blocker
reproduces in the same binary, which is how the A/B below was taken.

This also fixes a second, quieter defect: on a plain boot the same deferred
`map c_game_menu1` ran **after** mainui's `map_background c_game_menu1`,
replacing the background map with a real one and handing focus back to the game.
With the guard on, `cl_background` stays `1` and the engine menu keeps the live
scene behind it.

## Risks

* `pfnRedraw` is a client callback, not only a draw call. If Cry of Fear
  advances HUD state inside `HUD_Redraw`, skipping it while the menu is open
  freezes that state. Server simulation is already stopped in that situation
  (`SV_IsSimulating` requires `CL_IsInGame()`), so this is consistent, but it is
  untested over long menu sessions.
* `key_dest` is the only input to the gate. Any engine path that leaves
  `key_dest` at something other than `key_game` while the player is really
  playing would silently disable the CoF HUD and its input. No such path is
  known in this checkout.
* The patch does not touch `V_RenderView`, `UI_MouseMove`, the console, or
  mainui, so console typing and menu navigation keep their upstream code paths.
* `cof_ui_deferred_cmd_guard` drops the **whole** `host.deferred_cmd` buffer, not
  just a level change. That buffer is only writable before `cls.initialized`, so
  in this checkout it can only ever hold client-DLL boot commands, and for Cry of
  Fear it only ever holds `map c_game_menu1`; but a different mod that relied on
  a deferred command being replayed at the first menu draw would lose it. The
  cvar restores the stock path.
* Cry of Fear no longer auto-enters its own 3D-menu map on boot. That is the
  intent of milestone 1 (the engine menu owns the main menu over
  `map_background`), but it means `scripts/chapterbackgrounds.txt` - or an
  explicit `map_background` - is now what puts a live scene behind the menu. With
  neither, mainui falls back to its Steam background bitmap.
* Not verified in this session: quitting from the engine menu by menu navigation,
  and the engine menu's Load Game page loading a Cry of Fear save. Neither code
  path is touched by this patch. See the fixture `README.md` for what was and was
  not driven.

## Applying

Apply after the other engine patches in the ordered list in `README.md`:

```powershell
pwsh -File .\scripts\apply-cof-ui-input-gate.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

The script refuses a tree that already has the gate, refuses a tree that already
carries the untracked `cof_skip_*` diagnostics (this patch supplies them),
verifies concrete markers in all six touched files afterwards, and reverse-checks
the patch.
