# Aim down sights, default binds and the chapter card rule (milestone 5b, Hold reworked in the fix-ads-tape round)

Three engine-side changes and their menu halves:

* **"Aim down sights: Hold / Toggle"** on the Game options page, engine cvar
  `cof_ads_toggle` (`patches/cof-ads-toggle.patch`);
* the default binds **MOUSE2 = aim, MOUSE3 = secondary attack**, applied once to
  configs that still hold the shipped pair, and a `gfx/shell/kb_def.lst` so the
  menu's "Use defaults" agrees (theme patch + gamedata overlay);
* the chapter title card's white **rule suppressed** in the engine's
  `pfnFillRGBA` path, `cof_hud_chapter_rule_hide`
  (`patches/cof-chapter-rule.patch`).

Labels as elsewhere: **measured** = seen in a log, a screenshot or a shipped
binary; **inferred** = a reading of measured facts. Evidence:
`stage1/m5b-integration-20260922` (the first version) and
`stage1/fix-ads-tape-20260922` (the Hold rework: `case-ads*.ps1`,
`case-final.ps1`, logs and screenshots under `evidence/`, `RESULTS.md`).

## 1. The game's ironsights are a toggle; its "hold" mode is not usable

**Measured, hl.dll** (read only, image base `0x10000000`): the server DLL
registers a cvar `ironsights_toggle` (name at `101AEC8C`, `cvar_t` at
`10214778`: default `"1"`, flags `FCVAR_SERVER`, **not archived**). A press of
`+attack3` (the client's `in_attack3` kbutton sets the usercmd bit `0x40`)
reaches the weapon's vtable slot 107 through `CBasePlayerWeapon::ItemPostFrame`
(`1011D560`). For the ironsight weapons that slot is

```
if( !ironsights_toggle && m_bIronSights )
    return;                          // "hold": a press only ever enters
m_bIronSights = !m_bIronSights;      // toggle: every press flips
m_bIronSights ? EnterIronsights() : LeaveIronsights();
```

(e.g. the glock at `10047C00`, guarded by the press edge
`m_afButtonPressed & 0x40`, `+0x22B0`), and with `ironsights_toggle 0` their
slot 86 leaves ironsights when the button is no longer held.

The m5b round shipped "Hold" as the game's own `ironsights_toggle 0`. With a
real mouse the user found it unusable, and the retail DLL says why:

* **No firing while the aim key is held.** `ItemPostFrame` tests the `0x40`
  button FIRST (`1011DAA8`) and reaches `PrimaryAttack` only in its `else`
  branch (`1011DB1C`), so as long as `+attack3` is held no shot is ever fired.
  Measured (`ads4.log`, section G2, glock, `ironsights_toggle 0`): aimed, three
  `+attack` presses, no shot (no `Particle` / `CurWeapon` user message).
* **The hunting rifle never leaves its scope.** Only ten weapons read the cvar
  (glock, vp70, p345, revolver, tmp, g43, mp5 in slots 86 and 107; m16, famas,
  shotgun in slot 107 only). The rifle's slot 107 (`100682A0`) ignores it,
  toggles its scope flag `m_bRaised` (`+0x106`) without a press-edge check and
  sets a 0.25 s delay, and its slot 86 has no release path: in "hold" it is a
  toggle that also re-toggles every 0.25 s the key stays down.

So the game is a **toggle** out of the box (`ironsights_toggle 1`, which it
re-registers every time hl.dll loads and never saves), and a usable Hold has to
be built on top of that toggle.

## 2. `cof_ads_toggle`: Toggle is the game's, Hold is the engine's

```
cof_ads_toggle      default 1, FCVAR_ARCHIVE   1 = Toggle (the game's own), 0 = Hold
cof_ads_hold_pulse  default 0.2, flags 0       Hold: the longest a toggle press lasts, seconds (0 = same frame)
```

`CL_CoF_ADSSync()` (`engine/client/cl_main.c`, every client frame from
`CL_UpdateClientData`) keeps the game at `ironsights_toggle 1` in **both**
modes, whenever hl.dll has (re)registered the cvar. A value typed into
`ironsights_toggle` by hand still sticks until the next registration.

**Toggle** is untouched: the aim key's bind runs `+attack3` / `-attack3` as
always.

**Hold** (`cof_ads_toggle 0`): `Key_AddKeyCommands` (`input/in_keys.c`) hands a
key bound to `+attack3` to `CL_CoF_ADSHoldKey()` instead of queuing the bind.
The key's press and its release each become **one toggle press** of the game's
own `+attack3`: `+attack3 K` now, `-attack3 K` as soon as the weapon has
switched, and after `cof_ads_hold_pulse` seconds at the latest (capped at
0.24 s, below the rifle's 0.25 s re-toggle). The button is therefore never
held, so firing while aimed works, and every weapon, the rifle included, aims
in on the press and out on the release.

* Why not a same-frame press and release: **measured** (`ads2.log`, B), a
  `+attack3 K; -attack3 K` in one command-buffer pass does not move the glock
  (the press edge it needs is not seen); a toggle tap of 2 frames or more does
  (A: 2, 5, 10, 20 frames all aim).
* **Reconciling.** The game may refuse a toggle while the weapon is busy (the
  glock's 0.3 s after entering or leaving, a shot, a reload, the rifle's bolt
  and 0.25 s scope delay). So the engine watches the result and repeats the
  press every 0.35 s (`COF_ADS_RETRY`) until the weapon is where the key says,
  for at most 5 s (`COF_ADS_WINDOW`). The state it watches is the zoom target
  the server keeps in the player's `vuser2[0]` and sends in the client data
  (90 at the hip, about 50 for the glock's ironsights, 85 then 30 for the
  rifle's scope; hl.dll writes it on every enter and leave) - **per weapon**:
  nothing in hl.dll resets it when a weapon is put away (measured, `ads2.log`:
  the glock left aimed, the rifle drawn, the target stayed 50), so a zoom only
  counts while the view model it began with is in the hands.
* **Safety.** A release retries only while the weapon still reports aimed; a
  press retries only with a weapon whose view model has been seen aimed before
  (learned per map). A weapon whose `+attack3` does something else gets exactly
  one press per key edge. Nothing is sent while a menu has focus, the game is
  paused or in an intermission; a release that happened while a menu had focus
  (which the engine never turns into `-attack3`) is picked up from the key
  state.
* Dev lines at `developer 1+`: `[cof-ads] hold: key down -> toggle pulse 1 ...`,
  `... released (the weapon switched)`, `... retry ...`, `... gave up ...`.

The menu (`3rdparty/mainui/menus/AdvancedControls.cpp`, theme patch) is
unchanged: an "Aim down sights" spinner, **Hold / Toggle**, on the Game page,
written live.

### Developer commands

* `cof_key_probe <key> <1|0>` - hands one press or release straight to
  `Key_Event`, the entry point the platform layer uses; only with `developer`
  set, restricted (a server cannot send it). This is how both modes are tested
  without injecting OS input. While the probe runs, a bind's expanded
  `+cmd`/`-cmd` text is inserted at the head of the command buffer
  (`Key_QueueBindText`), which is where a key pressed on that frame lands;
  otherwise it would queue behind the rest of the test script.
* `cof_ads_status` - one line: `cof_ads_toggle`, `ironsights_toggle`, the zoom
  target and whether it counts as aimed (with the view model it began with),
  the FOV the client draws with, and the Hold emulation's state.

### Verification (fix-ads-tape round)

Glock from the quick save (c_park) and the hunting rifle (`give weapon_rifle`),
keys only through `cof_key_probe`, a shot proven by the `Particle` /
`CurWeapon` user messages (`cl_trace_messages 1`):

| case (`ads4.log`, `fin2.log`) | result |
| --- | --- |
| glock, Hold: press | aimed (target 50) |
| glock, Hold: fire x3 while held | shots 2 and 3 fire (the first falls in the 0.3 s after entering) |
| glock, Hold: release right after a shot | first press refused (shot cooldown), the retry leaves: hip |
| glock, retail `ironsights_toggle 0` held, fire x3 | **no shot** (the retail bug, for comparison) |
| glock, Toggle: tap in, fire, tap out | in, shots fire, the tap out right after a shot is refused by the game (unchanged Toggle behaviour) |
| rifle drawn while the glock was aimed | counted as hip (target still 50, other view model) |
| rifle, Hold: press / fire / release | scoped (target 30), shot fires, release -> first press refused (bolt), retry leaves |
| rifle, Toggle: two taps | the first, within 0.25 s of the previous toggle, is refused by the game; the second scopes in |
| after save + load | the scoped rifle comes back scoped; Hold press: "already aimed"; the shot fires; the release press is refused (bolt after the shot) and the retry was still pending when the run quit |
| after a map change (c_forest3 -> load quick, c_park) | glock Hold: aimed, shot fires, release -> hip after two refused presses |

## 3. Default binds: MOUSE2 aims

**Measured**, canonical `cryoffear/config.cfg`: `MOUSE2 "+attack2"` (secondary
attack; on the lantern and the melee weapons the bash) and
`MOUSE3 "+attack3"` (ironsights). The game ships **no** `gfx/shell/kb_def.lst`,
only `kb_act.lst`.

* The theme's deferred defaults go to **generation 4**
  (`UI_ThemeApplyDeferredDefaults`, `Theme.cpp`): if `MOUSE2` is still
  `+attack2` **and** `MOUSE3` is still `+attack3`, they are swapped once;
  any other binding of either button is left alone and the step is never
  offered again (`ads1.log`: `Cry of Fear: default binds updated - MOUSE2 aims
  down sights (+attack3), MOUSE3 is the secondary attack (+attack2)`;
  `ads2h.config.cfg`: `bind "MOUSE2" "+attack3"`, `bind "MOUSE3" "+attack2"`,
  `ui_cof_scene_defaults "4"`).
* `gamedata/cryoffear/gfx/shell/kb_def.lst` (43 binds, SHA-256
  `2063D59F7871E8ED952B08BFF106C946B41090020966A8569FF709A35CBB2080`) is the
  game's own `config.cfg` bind list with the same swap - what Controls >
  "Use defaults" loads. Deployed by `stage1/deploy-ui-m3-20260921.ps1`
  (payload entry `cryoffear\gfx\shell\kb_def.lst`, new).

Manual test left for the user: pressing "Use defaults" on the Controls page
(a dialog button; not reachable from a cfg).

## 4. The chapter card rule (`cof_hud_chapter_rule_hide`)

The chapter card ("Chapter 6 - It's not over yet") is a VGUI Label and scales
with the milestone-4 transform; the white rule under it is a raw
`pfnFillRGBA` from the client and does not, so at the user's HUD scale it runs
through the title. User decision: suppress it.

**Measured** with `cof_hud_text_trace 1`, every client fill logged
(`chap-*-show*.log`, `c_bridge`): the card draws exactly one fill of its own, a
2 px white rule that grows in 16 px steps (15, 31, ... 447) to 463 px while
the title types out and fades with the card (alpha 223..228), at a fixed place
relative to the screen centre:

| render size | rule |
| --- | --- |
| 1920x1080 | `729,561` = 960-231, 540+21 |
| 2560x1440 | `1049,741` = 1280-231, 720+21 |
| 3840x2160 | `1689,1101` = 1920-231, 1080+21 |

So the match (`CL_CoF_ChapterRuleHidden`, `engine/client/dll_int/cl_game.c`,
asked by both `pfnFillRGBA` and `pfnFillRGBABlend`) is: Cry of Fear, pure white,
2 px tall, 1..463 px wide, at `(width/2 - 231, height/2 + 21)` of the screen
the client is told about (one pixel of slack) - every frame of the growth, not
only the finished `463x2 rgba 255,255,255,228`. Alpha is not matched.

```
cof_hud_chapter_rule_hide   default 1, flags 0   0 = draw the rule as the game does
```

Verified at 1080p, 1440p and 2160p (`chap-*-hide`, `rel-chap-2160`): the rule
is gone, the title is untouched; the `-show` runs with the cvar at 0 are the
control.

## Artefacts

| Artefact | Bytes | SHA-256 |
| --- | ---: | --- |
| `patches/cof-ads-toggle.patch` (fix-ads-tape: Hold emulation) | 24 874 | `652057FAF8F2E5A26A780095BDCF6A98BD6E1D708C7B5B770FF33AB4A5CCDE29` |
| `patches/cof-chapter-rule.patch` (fix-ads-tape: context lines only) | 6 587 | `9536F614578D85B2AE55152B63F1ACDBE98B362370B6877603C4A8599AF7C78C` |
| `xash.dll` (`stage1/releases/fix-ads-tape-20260922`) | | `B1E38985CB6786A325EAA4925E079DCF1B3B24EC12822108285D1F579648D76A` |
| `menu.dll` (unchanged since m6) | | `2BDAB51E84AFBFA3ACB65F8E6CF58BF8312185D734108321CB5661E8FE969A7C` |

History: m5b shipped `cof-ads-toggle.patch` `9B2B593C…` (Hold = the game's
`ironsights_toggle 0`), `cof-chapter-rule.patch` `7E7DBBEF…`, xash `BAF1533F…`.

Apply order: after the milestone-5 engine patches,
`scripts/apply-cof-ads-toggle.ps1` then `scripts/apply-cof-chapter-rule.ps1`.
