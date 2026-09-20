# Xash/GoldSrc developer notes

These notes collect reusable lessons from the bounded Cry of Fear/Xash
investigation. They describe the pinned FWGS source at commit
`4857b389e6ba32ddaa68582aedcbc950c138f46a` and the isolated diagnostics in
this repository. CoF-specific observations are labeled; they are useful
examples, not general compatibility guarantees.

## Start by separating the layers

An Xash game is a collaboration between the engine and two game DLL roles:

- The engine owns the process, window, renderer, filesystem, networking,
  command buffer, map lifecycle, and save container. It calls game DLL entry
  points and exposes callbacks through versioned C structures.
- The server game DLL owns game rules, entities, server-side commands, and
  save/restore field descriptions.
- The client game DLL owns HUD, input callbacks, client effects, and game UI
  behavior. A resource file or custom map can select an engine command while
  the resulting screen is still drawn by the game client or map.

This split matters when a menu looks correct but a click fails. A FWGS
`mainui` result does not prove that the original client HUD, custom menu map,
or server callback accepted the same input. Record the layer for every
screenshot and log.

The pinned engine's input path illustrates the boundary:
`engine/client/input/input.c:339-368` reads an absolute platform mouse
position and sends it to both VGUI and `UI_MouseMove`; button events at
`input.c:375-403` go through VGUI, the client DLL, or engine key dispatch
depending on the active destination. The CoF resource menu separately emits
engine commands. In this project, `cryoffear/resource/GameMenu.res` maps New
Game to `engine beginspgame`, Load Game to `engine map c_loadgame`, and 3D/2D
menu changes to `engine to3dmenu`/`engine returnmenu`.

## Map-based menus are real game states

The isolated CoF resources use maps for menu scenes. Static inspection recorded
`c_game_menu1` entities for the game-menu controller, trigger cameras, and
ambient menu audio. The `c_loadgame` map contains the load-game controller and
an `info_player_start`. This explains why a menu camera or footsteps can remain
visible while a command is being processed: audio, camera, client UI, and
server map state are separate pieces of state.

For a custom game, make menu transitions observable at each boundary:

1. log the resource command and the target map or UI state;
2. log client connection/sign-on and the server callback that receives any
   follow-up command;
3. capture the resulting frame and input destination; and
4. treat audio alone as an incomplete result.

The current CoF investigation proves startup and entry to `c_game_menu1`, and
the command-equivalent `+map c_loadgame` reaches the load-selector map. It does
not prove a mouse-driven Load Game transition, stock-save restoration, camera
handoff, or first-person view.

## Commands cross a connection boundary

The engine comment at `engine/common/cmd.c:970-977` states that commands such
as `godmode` and `noclip` entered at the client console are forwarded to the
server. `Cmd_ForwardToServer` at `cmd.c:980-1010` refuses forwarding until the
client is connected, then writes a `clc_stringcmd` message. On the server,
`engine/server/sv_client.c:3086-3160` tokenizes the received command and calls
the server DLL's `pfnClientCommand` for custom commands. The game DLL can send
an engine command back through `engine/server/sv_game.c:2321-2335`, where the
engine validates it before adding it to the command buffer.

This gives a useful diagnostic pattern for a game command: trace client
forwarding, packet receipt, the server DLL callback, the DLL's server command,
and the engine's command execution. A console-equivalent command can prove
that a route exists, but it cannot prove that a menu control found the right
hitbox or that the same command was sent at the right connection state.

The repository's optional CoF menu-load trace follows this pattern. It is an
off-by-default diagnostic patch, not a gameplay feature. Keep such traces
opt-in and scoped to a known command so they cannot silently alter normal
dispatch.

## Save files have a container contract and a restore contract

The pinned server loader first checks the save identifier and version, reads
the payload and token-table sizes, rebuilds the symbol table, and invokes game
DLL restore callbacks. The relevant baseline code is
`engine/server/sv_save.c:1770-1813`. `SV_LoadGame` then checks file existence,
initializes the game, extracts the saved directory, validates the saved map,
and continues the restore path (`sv_save.c:2111-2180` in the pinned source).

Therefore, “the file was listed” and “the header was accepted” are weaker than
“the original game state restored.” Entity field tables, pointer offsets,
entity stride, map availability, and game DLL assumptions all participate in
the final result. Test these separately:

- an Xash-generated save made by the same profile;
- a stock GoldSrc/Cry of Fear save; and
- a GUI Load Game route, distinct from `+load` or a console command.

The current project has only a bounded self-generated Xash save/load smoke
result. Stock-save compatibility and GUI transition success remain unverified.

A later isolated trace first showed a post-sign-on `cofload1` reaching the
original `hl.dll` `ClientCommand` callback, the DLL emitting `load cofsave1`,
and the engine entering `SV_LoadGame` before rejecting `save/cofsave1.sav` as
missing. The pinned loader calls `FS_FileExists( pPath, true )` at
`engine/server/sv_save.c:2141-2145`; the `true` flag selects a game-directory
lookup. The preserved fixture was at the runtime-root `SAVE` directory, so it
was invisible to that lookup. This was a fixture-placement issue, not evidence
of filename-casing behavior or an engine save bug.

After an exact-hash copy was placed at `cryoffear/SAVE/cofsave1.sav`, the same
trace recorded `load accepted: map=c_forest3`, `Loading game from
save/cofsave1.sav`, and a subsequent `Spawn Server: c_forest3`. This proves the
dispatch, game-directory search, save acceptance, and map restoration stages
for that isolated stock-save fixture. It still does not prove the GUI click
route, camera/input handoff, a playable first-person frame, or visual parity;
the temporary copy and generated sidecars were removed after the run.

## ABI adapters should be persistent, narrow, and opt-in

The first proven CoF mismatch is a four-byte PMove table shift after `physinfo`.
The experimental adapter keeps the native engine object for engine callbacks,
copies into a persistent shifted view for the original DLL's PM_Init/PM_Move,
and copies state back. That is safer than globally changing the callback table,
but it still proves only the observed boundary.

The later descriptor evidence found a four-byte shifted range in `entvars_s`
(`sequence` after `light_level`, then `health` and `iuser1`) and a separate
four-byte `edict_s` stride discrepancy. The corrected dedicated profile passed
the earlier null-edict allocator fault, then reached a later original-DLL
first-chance access during ServerActivate. These are diagnostic milestones,
not a completed compatibility layer.

For a new game or port, record the exact structure size, field offsets, calling
convention, pointer ownership, and callback stage for every proposed adapter.
Keep the default layout unchanged, gate the adapter behind an explicit profile
option, and verify the deployed executable and matching PDB before interpreting
a runtime result.

## Build headers and artifacts are part of the experiment

The client build checkpoint exposed a common generated-header trap:
`#ifdef XASH_DEDICATED` treats `#define XASH_DEDICATED 0` as enabled. A stale
dedicated `build.h` or `common/build.h` can therefore select dedicated-only
code in a nominal client build. Use a fresh output directory, confirm the
generated defines, and keep client and dedicated artifacts separate.

Record the pinned source revision, Waf options, dependency revisions, compiler
architecture, output directory, executable/DLL hash, and matching PDB hash.
A completed compile is not a valid client checkpoint if the headers selected
the wrong target. The repository's build notes intentionally call these local
diagnostic checkpoints rather than reproducible builds.

## Filesystem and launcher assumptions

The reviewed Windows launcher resolves its own directory, sets
`XASH3D_BASEDIR` and the current directory, and loads the colocated engine.
The tested root layout keeps engine dependencies beside `xash.dll` and the
game DLLs under the selected game directory. Windows case-insensitive names
such as `FileSystem_Stdio.dll`/`filesystem_stdio.dll` refer to one destination;
deployment scripts must not treat them as two independent files.

The current launcher is x86. Its local branded build with
`/LARGEADDRESSAWARE` reports PE characteristics `0x122`, but it has no embedded
DPI manifest. That flag is a process address-space property, not evidence that
the game UI scales correctly. FWGS separately defaults `vid_scale` to `1.0`
(`engine/client/vid_common.c:23-32`) and sets an SDL per-monitor DPI hint
(`engine/platform/sdl2/sys_sdl2.c:111-115`), while Windows does not receive
`SDL_WINDOW_ALLOW_HIGHDPI` in `engine/platform/sdl2/vid_sdl2.c:661-670`.

The FWGS `mainui` has its own logical scaling: `3rdparty/mainui/BaseMenu.cpp:
1040-1060` derives a 1024×768-style scale from the screen. The original CoF
menu, HUD, inventory, and phone may use different client/resource paths, so
measure and classify the active layer before changing scale policy.

## Console commands and cheats are not gameplay proof

Console commands are useful probes for map entry, sign-on timing, and engine
dispatch. They are not substitutes for mouse hit testing, inventory state,
phone keypad input, tape-recorder saves, or the original menu's client/server
sequence. Keep diagnostic commands off by default, avoid forwarding arbitrary
input, and log rejection reasons rather than treating a queued command as a
passed feature.

## Component and licensing provenance

The repository deliberately excludes the original proprietary CoF DLLs, game
assets, Steam files, dumps, and built binaries. The build notes record
dependency revisions; they also record that the fetched MultiEmulator checkout
includes an MIT license. This notebook does not assert a complete license audit
for every dependency or game component. Before distributing a derived game or
runtime, preserve each upstream license notice and separately resolve the
rights for original game code and assets.

## Findings convention and open questions

Record future findings with: pinned source revision; exact relative path;
evidence type (`static`, `runtime`, `artifact`, or `unverified`); command or
input route; executable/DLL/PDB hashes; isolated test scope; and the smallest
claim supported by the evidence. Do not include machine-specific paths,
proprietary files, or raw dumps in the repository.

Open questions for the next checkpoints:

- Which component draws each CoF custom menu screen: original client, map
  entities, engine `mainui`, or a combination?
- Does a post-sign-on `cofload N` reach the original DLL and restore a stock
  save, and does the camera/input destination change afterward?
- Which ABI member and stride assumptions remain after the current PMove,
  entvars, and edict experiments?
- Are inventory, phone, and quick-slot interactions correct at each tested
  resolution and cursor scale?
- What DPI/manifest policy should a distributable launcher adopt after the
  actual Windows display matrix is measured?
