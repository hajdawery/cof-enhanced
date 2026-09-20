# Stage 2 menu-to-game transition investigation

This is a bounded, isolated K-runtime investigation of the reported case where a
Cry of Fear menu remains visible while footstep audio plays after choosing a
menu save. The restored Steam installation was not accessed. The test used the
reviewed prototype engine `xash.dll` SHA256
`65ACDEA266B66E7FFA44B15281B97C9938C63069E81411D84F9A5C6C00E79FAE`, launcher
`CoFLaunchApp.exe` SHA256
`7B3FD518F10A780EDA6932934AF619C1241FDB852B362943F4737DF20DC086A9`, and the
preserved original CoF `client.dll` and `hl.dll` (SHA256
`D2A04641B301804F6F449AA68265042B13ADC360925B80033D417EC9F38C9C00` and
`0036B91C01E92ED205513F52563053A55A66A32D257EFB5F476B8F1F3DDE0E63`).

## Exact menu command paths

The deployed `cryoffear/resource/GameMenu.res` (SHA256
`A86BF30120DAE7F90D94AA0382E495610DBBBC18543BC63072A40488656558D9`) emits:

| Visible action | Command emitted by the resource |
| --- | --- |
| New Game | `engine beginspgame` |
| Load Game (discard progress) | `engine map c_loadgame` |
| 3D menu/Custom Campaign | `engine to3dmenu` |
| 2D menu | `engine returnmenu` |

The supplied 3840x2160 capture is a rendered `c_game_menu1` scene with a
small centered menu. It does not establish that a later click dispatched its
command.

## Isolated command-path observations

The Windows Computer Use bridge was unavailable (`Trusted RPC service is not
configured: sky`), so these are command-equivalent reproductions of the exact
resource commands rather than mouse-click evidence.

* `+beginspgame` reached `Spawn Server: c_difficulty_settings`, loaded that
  map, completed level load, and reached client initialization.
* `+map c_loadgame` reached `Spawn Server: c_loadgame`, loaded
  `maps/c_loadgame.bsp`, completed level load, received signon, and logged
  `client connected`. The bounded log is
  `stage1/launch-prototype-20260920/transition-load-stock1.log`.
* `+cofload 1` was queued too early and logged `Unknown command "cofload"`.
  This is an ordering artifact, not proof that the original DLL lacks the
  command. A `c_loadgame_load.cfg` attempt to issue it during server map
  startup also did not load a save; no successful stock-save result is claimed.
* The supported delayed probe was then run once as
  `+map c_loadgame +wait 600 +cmd cofload 1`, with `COF_PRELOAD_MARKER` and
  `COF_POSTLOAD_MARKER` around the forwarded command. The log
  `stage1/launch-prototype-20260920/transition-load-stock1-wait600-cmd.log`
  shows `Serverdata packet received`, sign-on completion, and `client
  connected` before both markers. It has no `Unknown command cofload`, but it
  also has no save-load message, saved-map spawn, load error, or map/view
  transition. This establishes the command was queued after sign-on, not that
  the stock save was restored.
* A separate direct `+load cofsave1` startup probe produced renderer/UI
  initialization only. It emitted no saved-map spawn or load result, so it is
  also inconclusive for stock-save compatibility. Its log is
  `stage1/launch-prototype-20260920/transition-direct-load-stock1.log`.
* The off-by-default trace build then captured the complete delayed route in
  `stage1/launch-prototype-20260920/transition-load-stock1-wait600-cmd-trace.log`:
  the packet reached the server, the original DLL returned from
  `ClientCommand`, and it issued `load cofsave1`. Xash entered
  `SV_LoadGame(save/cofsave1.sav)` and rejected it as `file missing`.
* The stock installation copies used for this investigation store
  `cofsave1.sav` at the runtime-root `SAVE` directory, while the CoF
  subdirectory contained only `saveinfo1.cof`/`saveinfo2.cof` and no
  `cryoffear/SAVE` directory. The engine uses `DEFAULT_SAVE_DIRECTORY`
  (`save/`) with a game-directory-only lookup, so the stock layout is not
  visible to the CoF load path. This is a deployment save-location
  compatibility requirement, not a filename-casing issue or generic loader
  failure. For one bounded diagnostic run, an exact-hash copy of
  `cofsave1.sav` was placed at `cryoffear/SAVE/cofsave1.sav`. The same trace then recorded
  `SV_LoadGame entry`, `load accepted: map=c_forest3`, `Loading game from
  save/cofsave1.sav`, and a subsequent `Spawn Server: c_forest3` in
  `trace-fixture-smoke.log`. The temporary copy and generated `.HL1/.HL2/.HL3`
  sidecars were removed afterward; the original engine and save hashes were
  restored.
* The command-equivalent post-load capture showed hands, weapon, HUD, and
  `c_forest3`, so this route left the menu view in that path. The frame had
  severe white/orange rendering corruption. This is evidence of the route
  reaching a first-person scene, not a GUI-transition, gameplay, or visual
  parity pass.
  Retained ignored evidence files are under
  `stage1/menu-transition-evidence-20260920/` (absolute directory
  `K:\\LLM\\COF_Fix\\stage1\\menu-transition-evidence-20260920`):
  `baseline-c_loadgame_shot0000.png` (SHA256
  `A09C108CA3914D926996BECEFB168FFD9CCA1EE10EC11CB3FDEC8563C5615F65`),
  `baseline-c_forest3_shot0000.png` (SHA256
  `7A764F6542D0878417A5AED32EE92C4E71B8877B001CCC1BE945EEEE4DE60B02`),
  and the trace-build comparison `trace-c_forest3_shot0000.png` (SHA256
  `DAACC833D6D05960AD10C7FDC3B564E2F8665F0D5F8D446096A17E21F23FD3A4`).
  The baseline and trace post-load frames show the same corruption, so it is
  present in the normal engine and is not caused by the trace patch. The
  baseline frame visibly lists slot 1 `Forest Field - Thu May 16 16:46:02
  2024` and slot 2 `Train - Thu May 16 16:48:23 2024`.
* The `c_loadgame` BSP (SHA256
  `9255A38BCF6A6DC00AD6E9C04B84698923D6B60DD49152CCC3CCA1D1B29066BC`)
  contains a `cof_loadgame` entity and an `info_player_start`. The
  `c_game_menu1` BSP contains `cof_gamemenu`, menu trigger-camera entities,
  and ambient menu audio. These map/entity facts explain why audio and menu
  camera state can persist visually while a map command is being processed,
  but they do not by themselves identify a bug.

The isolated `SAVE/cofsave1.sav`, `SAVE/cofsave2.sav`, `SAVE/quick.sav`, and
`cryoffear/SAVE/saveinfo1.cof`/`saveinfo2.cof` were hashed before testing and
were unchanged afterward. No game process remains.

## Current conclusion and next gate

The engine-side command path is proven for entering the load-selector map, and
New Game reaches its difficulty map. The delayed server-forwarded command,
original DLL callback, and save-loader route are now proven. With the save
placed in the engine's game-directory save path, the preserved stock save was
accepted and restored `c_forest3`; a deployment rule is still required to map
the stock root `SAVE` files into that path. The command-equivalent post-load
frame reached hands, weapon, HUD, and `c_forest3`, but its severe
white/orange corruption leaves rendering and gameplay unvalidated. The
reported GUI sequence remains open:
main menu → Load Game → selected stock slot → playable map/view. The current
runs do not prove that a stock GoldSrc save loads through the CoF selector, nor
do they prove camera mode, menu visibility, input focus, or a clean first-person
frame after selecting a slot. Footstep audio and map logs are insufficient as a
pass criterion. The next controlled test needs a working UI interaction bridge
or an equivalent post-signon dispatch of the exact `cofload N` command, followed
by a full-frame capture and map/camera/UI-state evidence.
