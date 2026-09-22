# Custom UI regression checklist

> **Status (2026-09-22 docs pass):** this checklist predates the unified UI. The
> main menu, New Game and Load Game gates now go through the engine menu
> (MainUI), not `GameMenu.res`. The user has since play-verified in the runtime:
> menu New Game and Load Game (stock and Xash saves), tape-recorder save and
> load, inventory use and equipping, HUD and inventory at 150 % HUD scale. The
> phone keypad and light, quick slots and the 2560x1440 / 3840x2160 cursor
> alignment rows have no recorded result and remain **unverified**.

This checklist covers the original Cry of Fear game UI and its transitions
around the pinned FWGS engine. It is a test plan, not a claim that the listed
behaviors currently work. Every gate below is **pending** unless an evidence
source is explicitly marked otherwise.

For coordinate-space ownership, renderer callbacks, and display scaling
boundaries behind these gates, see the [custom UI scaling research note](../history/cof-custom-ui-scaling-research.md).

## Evidence boundaries

The following references are verified from the ignored test runtime and
configuration files:

- `cryoffear/resource/GameMenu.res` routes New Game to `engine beginspgame`,
  Load Game to `engine map c_loadgame`, 3D menu/Custom Campaign to
  `engine to3dmenu`, 2D menu to `engine returnmenu`, and Unlockables to
  `engine unlockablescmd`.
- The default bindings map `TAB` to `+inventory`, `1`/`2`/`3` to
  `quicksel 1`/`quicksel 2`/`quicksel 3`, `F` to `flashlight`, `Z` to
  `weapontoggle`, `E` to `+use`, and the first three mouse buttons to
  attack/melee/alternate attack.
- `txtfiles/hints.txt` describes inventory use/drop/equip/combine, quick
  slots, mobile-phone light and keypad input, and tape-recorder saves.
- `menu_settings.txt` describes the weapon-selection overlay in a 640×480
  logical coordinate space.

The existing bounded logs verify engine/client startup, renderer/menu/VGUI
initialization, and `c_game_menu1` map loading. They do not verify a GUI click,
inventory action, phone action, quick-slot action, or stock-save load.

The FWGS `mainui` implementation is an engine-facing layer with its own
scaling and controls. The CoF `GameMenu.res` command layer, `c_game_menu1`
and `c_loadgame` scenes, original client HUD, inventory, phone, and weapon
overlays are game-facing behavior. Classify each capture and log by layer;
success in one layer does not establish success in the other.

## Pending functional gates

| Gate | Expected evidence | Status |
| --- | --- | --- |
| Main-menu focus and click | Cursor highlight follows the intended row; activation changes the visible state and emits the expected command. | Pending |
| New Game | `beginspgame` leads from the menu to `c_intro` and reaches a controllable first frame. | Pending |
| Load Game, Xash save | `c_loadgame` shows the generated Xash save, selection leaves the menu, and the selected map/state appears. | Pending |
| Load Game, stock save | A stock GoldSrc/Cry of Fear save is listed, selected, and restored through the GUI. | Pending; no compatibility evidence yet |
| 3D/2D menu return | `to3dmenu` and `returnmenu` produce the intended scene/menu changes, with no menu-visible plus footsteps-only false pass. | Pending |
| Resume and quit | ESC/resume returns to the prior game state; quit reaches the expected confirmation/exit behavior. | Pending |
| Inventory open/close | `+inventory` opens the original inventory overlay, closes cleanly, and preserves the active game state. | Pending |
| Inventory interaction | Cursor hover, use, drop, equip, and a valid combine action target the intended slot/item. | Pending |
| Quick slots | `quicksel 1`, `quicksel 2`, and `quicksel 3` select the intended items and update the HUD. | Pending |
| Phone keypad | The phone/weapon-toggle route opens the keypad, accepts mouse and keyboard digits, sends a known test number, and produces its expected event. | Pending |
| Phone light | Phone light toggles, remains correct when holstered, and does not break flashlight/weapon input. | Pending |
| Tape-recorder save | An in-game tape-recorder save creates the expected slot and preview without relying on a console command. | Pending |
| Resolution/cursor repeat | At 1920×1080, 2560×1440, and 3840×2160, hitboxes, labels, logo, and cursor coordinates remain aligned. | Pending |

## Test separation

Run the Xash-generated save and stock GoldSrc/Cry of Fear save as separate
cases. Keep the existing console `+map` and `+load` results labeled as smoke
tests; they do not satisfy the New Game, Load Game, tape-recorder, or stock
save gates.

For each case record the engine and client hashes, active game/map, input path
(mouse, keyboard, or console), expected resource command, resulting map or
screen, screenshot, and exception status. A menu screenshot, renderer
initialization, nonblank frame, or footsteps by itself is insufficient to mark
a transition or gameplay interaction passed.

Do not compare the CoF custom UI directly to FWGS `mainui` geometry until the
capture is identified as belonging to that layer. For display comparisons,
retain the reference metrics in `display-reference-audit.md` and record the
actual viewport, `vid_scale`, `hud_scale`, DPI context, and runtime mode beside
each new capture.
