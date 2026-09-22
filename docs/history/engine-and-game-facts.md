# Engine and game facts

The technical facts this project established about Cry of Fear 1.6 on Xash3D
FWGS 4857b38, one paragraph each, with the page that holds the evidence. All of
them were measured (disassembly, logs, draw-list walks, screenshots) unless
marked otherwise. Engine-agnostic lessons are collected separately in the
[Xash/GoldSrc developer notes](../dev/xash-goldsrc-developer-notes.md).

## ABI between the retail DLLs and the engine

* **`playermove_t` is four bytes longer in the retail DLLs**, starting at
  `numtouch` (`0x45490` in `hl.dll` vs `0x4548C` in FWGS). Everything before it,
  `cmd` included, matches. The first crash was `PM_Init` reading its
  `PM_Info_ValueForKey` callback at `+0x4F558`, which in FWGS is `pfnParticle`.
  The original adapter put the gap before `physinfo`, one field too late, which
  silently dropped every playermove touch impact.
  [pmove adapter](../patches/pmove-adapter.md), [callback view](../patches/cof-pmove-callback-view.md)
* **The crouch/crawl "stuck" bug** was the adapter itself: the DLL mutated the
  shifted copy while the engine's trace callbacks read the native object, so
  every trace in `PM_Move` used the previous frame's `usehull`. Hulls and duck
  fields were never wrong. [callback view](../patches/cof-pmove-callback-view.md)
* **`entvars_t` is shifted by four bytes after `light_level`** (`sequence`
  `0x12C` vs `0x128`, `pContainingEntity` read at `0x20C`), and **`edict_t` is
  `0x32C` bytes** in the retail DLL against `0x328` in FWGS. The inserted
  fields' identities were never recovered.
  [entvars layout](entvars-layout-analysis.md), [edict stride](../patches/edict-stride-proposal.md)

## Rendering

* **The missing main-menu skyline** is translucent brush entity `*23`. FWGS
  sorts any mod-defined `renderfx` into the translucent list; GoldSrc decides by
  `rendermode` alone. The `renderfx 137` sky sphere therefore drew after the
  skyline and covered it at depth ~0.896. `renderfx 137` is on 99 entities in 74
  maps. Depth writes, matrices and the client's attrib stack were all ruled out
  on the way. [renderfx opaque](../patches/cof-custom-renderfx-opaque.md),
  [skyline trace](../patches/cof-skyline-trace.md)
* **Negative `glDrawArrays` counts** are deliberate sky-polygon markers the
  client writes into the surface records, and the invalid cull-mode calls are
  redundant legacy calls. Neither was the skyline cause. The Wine/Proton
  `opengl32.dll` byte patch only skips a missing `wglGetLayerPaletteEntries`
  check and is irrelevant here. [skyline trace](../patches/cof-skyline-trace.md)
* **The client owns its sky behind its own `gl_customsky` cvar** and sets it to
  `0` on any failed sky face, never back. `c_unlockables` has no `skyname`; the
  engine's `desert` default is not shipped; 56 maps have no sky name.
  [sky reset](../patches/cof-sky-reset-per-map.md)
* **The client builds no 3D projection of its own** (no `glViewport`; only a
  texture-matrix `glFrustum` and one fixed 2D `glOrtho`). `hud_scale` still
  breaks the game, through the client's 2D overlay pass.
  [field of view](../patches/cof-fov.md), [UI scaling](../design/ui-scaling.md)
* **Cry of Fear has no `default_fov`**: the client hard-codes 90 at the hip, 60
  for "zoom 2", 30 for the cinematic zoom; `cl_fovmultiplier` scales all of them.
  [field of view](../patches/cof-fov.md)
* **The `glow01.spr` "no such frame 255" flood** is the tape recorder's red
  blink light: a one-frame `CSprite` whose frame `hl.dll` never wraps, saturating
  the 8-bit network field. [sprite frames](../patches/cof-sprite-quiet-frames.md)
* **A video mode change** re-calls the client's `pfnVidInit`, which in this
  client is a per-level entry point; its one-shot sky and atmosphere setup is
  not replayed. [video mode](../patches/cof-vid-restart-background.md)

## Menus, commands and messages

* **"Back to the main menu" is `map c_game_menu1`** everywhere in the game:
  the client's `to3dmenu`, its Unlockables, difficulty and server-settings
  panels, and `hl.dll` after deaths, endings and `closegame`. `HUD_Init` also
  queues one before the engine is up, which FWGS replays on the first menu
  draw. The Unlockables gallery's MAIN MENU button issues no command at all; it
  is recognisable only by the `ui/3d_click.wav` it plays at 0.5.
  [menu-map redirect](../patches/cof-ui-menu-map-redirect.md), [input gate](../patches/cof-ui-input-gate.md)
* **Death is not a command**: it is the `VGUIMenu` user message with byte 35,
  which the client turns into its `CGameOver` panel. Single player only.
  [death flow](../patches/cof-ui-death-flow.md)
* **Music bypasses the engine**: the client runs its own irrKlang `CMP3Player`,
  and its `stopmp3` console command is the whole control surface. The game
  deliberately carries a track across `changelevel`.
  [MP3 stop](../patches/cof-mp3-stop-on-map.md)
* **Unlockables** are 20-byte tokens, one per line of `scriptsettings.dat`
  (Nightmare = line 83); 27 lines are real unlockables, the seven other
  "unidentified" pairs are not. [UI theme](../design/ui-theme.md) (Unlockables round)
* **The original Extras links used the Steam overlay**, and `steam_api.dll` is
  not loaded under FWGS, so they were silent no-ops.
  [milestone 2](../patches/cof-ui-m2-cof-menu.md)

## In-game UI and text

* **Nothing in the in-game UI scaled**: the client lays out its VGUI viewport
  once, on the first `HUD_VidInit`, at the screen size of that moment (which is
  also why the inventory drifted after a resolution change), and its font
  bucket table caps at 1600 with strips identical from 1024 up.
  [UI scaling](../design/ui-scaling.md)
* **The inventory headings are artwork**, painted into
  `gfx/vgui/640_inventory.tga`. [VGUI Inter fonts](../design/vgui-inter-fonts.md)
* **Pickup lines and cutscene dialogue are not engine text**: they are one
  `Label` (+0x3A8) of the client's `CHUDControl` message strip, font role
  `credits`. Engine HUD text (`CHudMessage`) sits at 70 % and never moved.
  [HUD text](../patches/cof-hud-text-legibility.md)
* **The chapter-card line** is a raw client `pfnFillRGBA` rule that grows from
  15 to 463 px, not VGUI. [ADS and binds](../patches/cof-ads-toggle.md)
* **FreeVGUI passed signed `char`s** into glyph-width lookups at thirteen sites,
  harmless only while the game's own font re-masked them.
  [VGUI Inter fonts](../design/vgui-inter-fonts.md)

## Files and languages

* **Stock saves live in the root `SAVE\`**, beside the game directory, where
  the engine looks in `cryoffear\save\`. [root SAVE](../patches/cof-save-root-compat.md)
* **Both game DLLs open their text files through one `KERNEL32!CreateFileW`
  import** with a path built from the bare game directory, invisible to the
  engine filesystem; `hints.txt` and `inventoryitems` come through the engine's
  `COM_LoadFileForMe` instead. The game's seven-language table is code
  (`cof_subtitlelanguage` 1-7) and never covers `inventoryitems` or
  `credits.txt`. [language packs](../design/language-packs.md)
* **The Polish fan mod** is Windows-1250 text written over the English files,
  101 maps differing only in entity strings, 110 repainted sign textures and
  about 235 hex-patched DLL strings (some of which corrupted identifiers).
  [language packs](../design/language-packs.md),
  [`languages/polish/README.md`](../../languages/polish/README.md)

## Gameplay

* **The game's own "hold to aim" is broken**: `ItemPostFrame` checks aim before
  fire, so a held aim key blocks every shot, and the hunting rifle ignores the
  setting. The game only works as a toggle. [ADS and binds](../patches/cof-ads-toggle.md)
* **Co-op is plain GoldSrc multiplayer** switched by `deathmatch 1` (not
  `coop`), with the lobby autostart time in `mp_footsteps` and the old buttons
  sending `optionshack 0/1`. FWGS's `Cmd_ExecScript` glued a cfg's last line
  onto the next command. [co-op bridge](../design/coop-bridge.md)
* **Retail 1.6 disabled the cheats in code**: `PostThink` turns noclip off every
  frame and clears `FL_NOTARGET` in 13 places, `TakeDamage` never tests godmode,
  there is no `give`; the dormant `m_bInfiniteAmmo` / `m_bInfiniteStamina`
  switches and the ending flags are still in the player object.
  [cheats](../design/cheats.md)

## Things that turned out not to be bugs

* The "engine crashes 1-2 s after weapon actions" and two "silent exit"
  co-op runs on 2026-09-22 were other test scripts killing every game process
  by name. The only real crash that day was the expected control run without
  the playermove adapter (`stage1/crash-weapon-20260922/RESULTS.md`).
* The "Reload does not work" report of 2026-09-22 was withdrawn by the user.
* "Pickup notifications draw nothing because `titles.txt` is the stock file"
  was a worry, not a bug: they draw (user-verified).
