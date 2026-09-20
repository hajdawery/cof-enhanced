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
  `stage1/menu-transition-evidence-20260920/`:
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
* The first `GL_INVALID_VALUE` appears immediately after c_forest3 lightmap
  setup, at `gl_rmain.c:830`, the error check after solid entity rendering.
  A first targeted `+r_drawentities 0` run was rejected as cheat-protected.
  A bounded follow-up set `+sv_cheats 1`, then read back
  `"r_drawentities" is "0" ("1")` before loading the saved map. World/entity
  geometry was suppressed while the first-person weapon and HUD remained;
  the severe white bloom and garbled orange text persisted. This rules out
  the world/entity pass as the sole cause of the corruption, but does not
  identify the first invalid GL operation. Its retained frame is
  `stage1/menu-transition-evidence-20260920/svcheats-r_drawentities0-c_forest3.png`
  (SHA256
  `C061139215FD9AFA5F03ED5A595F43BA8E3E787F3F21CE505DF9FD549C0CCD00`),
  with log `transition-render-svcheats-entities0.log` in the same directory
  (SHA256
  `306F2BB28C982109C1D464499803EC0AF46BD8CC7FDD2240CC4662A55F4DCDB9`).
  A follow-up with the registered `r_drawbeams 0` cvar also read back
  `"r_drawbeams" is "0" ("1")` after the saved-map load, but retained the
  same first error location and severe frame corruption. Its log is
  `stage1/menu-transition-evidence-20260920/transition-render-svcheats-rdrawbeams0.log`
  (SHA256
  `858E5F86B9F69735ED741569EC7BB75A3E2406A18B22D5FF273A27A068A970CE`),
  and its frame is
  `stage1/menu-transition-evidence-20260920/svcheats-r_drawentities0-r_drawbeams0-c_forest3.png`
  (SHA256
  `B5F69E421C6E11129AE19D863F01FF136F46DDDD9A1570FAD764AC6FF9781073`).
* The matched GL-stage diagnostic modules were also tested, with engine
  `73B83DA28AE169A320742C090FE8CE480332B139D32CE5472D4D2424BBAF45C8` and
  renderer
  `2D0CDB362F4908CE31C4B333019874D1D58BE9EEF19CF577CB89B96CD927F23E`.
  `cof_gl_trace` remained an unknown command at startup and after sign-on,
  so no stage labels were emitted. Read-only source inspection found the
  diagnostic cvar defined in `ref/gl/gl_opengl.c` but absent from
  `GL_InitCommands()` registration; this build therefore cannot identify the
  pending-error stage. The run was cleaned and the normal renderer restored.
* The `c_loadgame` BSP (SHA256
  `9255A38BCF6A6DC00AD6E9C04B84698923D6B60DD49152CCC3CCA1D1B29066BC`)
  contains a `cof_loadgame` entity and an `info_player_start`. The
  `c_game_menu1` BSP contains `cof_gamemenu`, menu trigger-camera entities,
  and ambient menu audio. These map/entity facts explain why audio and menu
  camera state can persist visually while a map command is being processed,
  but they do not by themselves identify a bug.

* A corrected matched GL-stage diagnostic was run after registering
  `cof_gl_trace` in the renderer. The engine SHA256 was
  `977008A7E49C05B17EFA2750CC633674E8CF8D150E012A0022B8E3FA34A06AD1`
  and the renderer SHA256 was
  `253B24DC91F2CAEE4E88E45A28447C17455E7EA6D6413F19167F377CAC92DD99`.
  The run read back `cof_gl_trace 1`, `gl_check_errors 1`,
  `r_drawentities 0`, and `r_drawbeams 0`; the delayed stock-save route
  reached `c_forest3` and connected the second client. It emitted 5,791
  stage-labeled `GL_INVALID_VALUE` errors, all at
  `after_client_normal_triangles`; there were 7 earlier unlabeled errors,
  for 5,798 total. This localizes the first labeled pending error to the
  client normal-triangle stage, without identifying the individual GL call.
  The retained frame is
  `stage1/menu-transition-evidence-20260920/gltrace-corrected-rdrawbeams0-c_forest3.png`
  (SHA256
  `0C69674A8DCF9EFDD42E77E59564F106BFD289CF447ED3CCF810DBA5D595852`),
  with log
  `stage1/menu-transition-evidence-20260920/transition-render-gltrace-corrected-rdrawbeams0.log`
  (SHA256
  `C241072692C1416642A5BF4CDF3AFC5879408CB9F64B8BDB05047B256EE10415`).
  The corrected modules and temporary fixture were removed after capture;
  the normal engine/renderer and save/config manifest were restored.

* The corrected root-save compatibility artifact was then tested independently
  with no `cryoffear/SAVE` fixture. The build output had changed during the
  session; the actual engine loaded for these save tests was SHA256
  `7BA9DD02B20CF5FE5A9006A124BC1E9215DE86D52C646EF04EE7F0471CCAF182`.
  With `cof_save_root_compat 1`, the preserved root `SAVE/cofsave1.sav`
  loaded to `c_forest3` and extracted its `.HL1/.HL2/.HL3` sidecars into the
  root `SAVE` directory. A disposable `luna_rootcompat_probe_20260920` save
  wrote both `SAVE/luna_rootcompat_probe_20260920.sav` (SHA256
  `C0D85DB996205F63652772E387F56C03F05E238580EBA16213899FB2F02A82EF`)
  and its thumbnail `.bmp` (SHA256
  `F22AA144D904A9664F5C57B440EAD47984D78A487043792E61975466E9773121`).
  A separate run loaded that disposable save and again reached `c_forest3`
  and `c_forest3.HL1`. The write and reload logs are retained in
  `stage1/menu-transition-evidence-20260920/` with SHA256 values
  `BBCB8772FBDE520BCFFAB2D696D7A76C64CFB8E6A46639284E65F35CF889F316`
  and `48327DF721E293F37A3FCE61CFE63AFB35221795BABCEF55C83482FE566D6C0B`.
  The disposable files and sidecars were removed, the normal engine was
  restored to SHA256 `65ACDEA266B66E7FFA44B15281B97C9938C63069E81411D84F9A5C6C00E79FAE`,
  and the baseline save/config manifest remained unchanged. This validates
  root save read, write, thumbnail, and reload behavior under the opt-in cvar;
  it remains command-equivalent evidence rather than a GUI Load Game proof.

* The save result was repeated from a frozen bundle to close deployment
  provenance. Both runs measured engine SHA256
  `7BA9DD02B20CF5FE5A9006A124BC1E9215DE86D52C646EF04EE7F0471CCAF182`
  immediately before launch. The unique
  `luna_rootcompat_frozen_20260920` write created a root `SAVE` save (SHA256
  `35BFF51E6243EBE05A262747A2BC995813CD2657DCA1161AD1BE173D6FA4E498`)
  and thumbnail (SHA256
  `61BFA4FC2C75CFD10497F3AFF5B3AA095F9639EC56C4F5AE2CBADFC25D62A6C9`).
  A second run with the same measured engine hash loaded that save and reached
  `c_forest3` and `c_forest3.HL1`. The write and reload logs are retained as
  `savecompat-write-luna_rootcompat_frozen_20260920.log` (SHA256
  `D9909278C7EE20B64E71559519E3D518E1CB5C0484511478532DACB7EA9AC2B1`)
  and `savecompat-reload-luna_rootcompat_frozen_20260920.log` (SHA256
  `BF04344B4A8A98FD6D7695E0C5360B7B6D00FD01DBE9A67EFB826548A48561DD`).
  The probe files and sidecars were removed and the normal runtime plus the
  baseline save/config manifest were restored afterward.

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
