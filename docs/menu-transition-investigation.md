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
* The current branded launcher artifact was then checked in the isolated
  runtime with caller `-game`, `-cof-pmove-legacy`, and
  `+set cof_save_root_compat` omitted. The deployed launcher hash was
  `C6DFC178774CC88398C017A2E377613DED966C9637BC59C8AEA800538186A17A` and
  the root-compatible engine hash was
  `7BA9DD02B20CF5FE5A9006A124BC1E9215DE86D52C646EF04EE7F0471CCAF182`.
  The launcher log's `Program args` line showed that it injected
  `-game cryoffear -cof-pmove-legacy +set cof_save_root_compat 1`; the map
  load cfg read back `cof_save_root_compat 1`, and the original root save was
  accepted, followed by `Spawn Server: c_forest3` and loading its `.HL1`
  sidecar. The retained log is
  `stage1/menu-transition-evidence-20260920/direct-cforest3-launcher-c6-savecompat-20260920.log`
  (SHA256
  `3D330EE5022492E73AA5354507E7297AB50ABB9CC8C60E82E8ADD992DDAEB0E6`),
  with frame
  `stage1/menu-transition-evidence-20260920/launcher-c6-savecompat-c_forest3_shot0000.png`
  (SHA256
  `C903F7206055146C63FE3232F8A4C7A1C6258CE52DF2CE0AB077A9949385A5CA`).
  This validates launcher argument injection and root-save compatibility in
  the isolated runtime; it is not Steam or GUI-click evidence.
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

* A frozen renderer diagnostic then enabled
  `cof_skip_client_normal_triangles 1`, which bypasses only the original
  `HUD_DrawNormalTriangles` callback. The deployed hashes were measured before
  launch: engine `7BA9DD02B20CF5FE5A9006A124BC1E9215DE86D52C646EF04EE7F0471CCAF182`
  and renderer
  `8F24567D129BA1199D8AFD4805DA8030E52C548382BD53A99927C0633ADBFDB6`.
  Readbacks confirmed `cof_gl_trace 1`,
  `cof_skip_client_normal_triangles 1`, `gl_check_errors 1`,
  `r_drawentities 0`, and `r_drawbeams 0`. The load reached `c_forest3`;
  the trace produced 7 initial `GL_INVALID_VALUE` errors and no stage labels,
  compared with thousands of repeated `after_client_normal_triangles`
  errors when the callback ran. The retained frame
  `stage1/menu-transition-evidence-20260920/bypass-c_forest3_shot0000.png`
  (SHA256
  `9A516A6EEA38DEB3EFE32069B77BBC8F7E51FFFAED4DAF811B1AC87EF47F9618`)
  still shows the white radial field and orange HUD glyph corruption. Thus
  bypassing the callback removes the repeated GL error source but does not
  repair the visible output; this remains a diagnostic result, not a gameplay
  fix. The associated log is
  `stage1/menu-transition-evidence-20260920/gltrace-skip-normal-triangles-frozen-20260920.log`
  (SHA256
  `2FC1F94CECDB539B8A19725E69746424F60934D63CF09A7319A4F2A5C82DE1D5`).
  An earlier preliminary run used the different 4D18 TriAPI renderer and is
  excluded from evidence.

* A separate frozen engine diagnostic enabled
  `cof_skip_client_hud_redraw 1` while retaining
  `cof_skip_client_normal_triangles 1`, `r_drawentities 0`, and
  `r_drawbeams 0`. The deployed hashes were measured before launch: engine
  `EB4E168AC8B1C8F1A0095357E2B6388FB6ED65FFBAF7FBA7D1593B9ABDFE5BA1` and
  renderer
  `8F24567D129BA1199D8AFD4805DA8030E52C548382BD53A99927C0633ADBFDB6`.
  Readbacks confirmed all diagnostic cvars were enabled and the load reached
  `c_forest3`; the trace had only the 7 initial `GL_INVALID_VALUE` errors.
  The retained frame
  `stage1/menu-transition-evidence-20260920/bypass-hud-c_forest3_shot0000.png`
  (SHA256
  `965D8468B68B0F99DADCCCE13FDFBBDE4A8DA96E20D3EC8581B4683F629F8F1A`)
  no longer has the prior white radial field and shows the save selector and
  scene, while the orange glyph corruption remains. This assigns the white
  radial output to the `HUD_Redraw` path in this diagnostic configuration;
  orange glyphs still have another source. The log is
  `stage1/menu-transition-evidence-20260920/gltrace-skip-hud-redraw-frozen-20260920.log`
  (SHA256
  `FFB3189EFBD9677060839E0E18D82258240E05953CCD2F0C02C4D07A3D044533`).
  The test was cleaned and the normal runtime plus baseline manifest were
  restored.

* A direct playable-map control bypassed the `c_loadgame` selector entirely:
  frozen engine `7BA9DD02B20CF5FE5A9006A124BC1E9215DE86D52C646EF04EE7F0471CCAF182`
  started `c_forest3`, then issued local `load cofsave1` with the normal F3B
  renderer and no diagnostic bypasses. The log
  `stage1/menu-transition-evidence-20260920/direct-cforest3-rootload-baseline-20260920.log`
  (SHA256
  `DC451C74BB905887F297E97D30F31067DE0DF9274A02934DB814D8CC12400A07`)
  recorded the save load and 5,890 `GL_INVALID_VALUE` errors. Its frame
  `direct-cforest3-rootload-baseline-c_forest3.png` (SHA256
  `948B2CEE44BD290B695CE7D13799D8DDE8C59ADD70AE45160064AC7CC642F865`)
  shows the dark forest scene, flashlight/hand, localized white flashlight
  glow, and orange glyphs. The same symptoms therefore occur outside the
  selector-map lifecycle.

* Setting only the original client `gl_screenblur` cvar from 1 to 0 on the
  same direct route did not materially change the frame: the dark scene,
  localized glow, and orange glyphs remained. `gl_posteffects` stayed at 1.
  The log is
  `stage1/menu-transition-evidence-20260920/direct-cforest3-screenblur0-20260920.log`
  (SHA256
  `345D9B5868F763576CC8BF504E81FB68C3B2F3BE05B4F0B40FBFF5D83EF73695`);
  its post-load frame `screenblur0-c_forest3_shot0001.png` has SHA256
  `24E62EA56F9483DC09C761FCCC73DC9BEB36DE991CE4F676340ACC32E321B35C`.
  Both tests were cleaned and the baseline runtime/save manifest restored.

* A direct control with `-dev 0` kept the same map/save route and normal
  callbacks. Readbacks showed `developer 0`, `r_speeds 0`, `cl_showpos 0`,
  and `r_showtree 0`; `cl_showents` is not registered in this client. The
  frame still contained the orange glyphs and localized flashlight glow, so
  developer level and the checked engine debug overlays do not explain them.
  The log is
  `stage1/menu-transition-evidence-20260920/direct-cforest3-dev0-baseline-20260920.log`
  (SHA256
  `94F33C80C24B5C19BF4BCBC18023D357E8AE5D1B29F79D344CCF41B12EB58DF8`),
  and the frame is `dev0-c_forest3_shot0001.png` (SHA256
  `E27BCCA6D2855FE7FD3858FDE32E5A4A48CB19B858D3DD6BD151270FA736C47`).

* A frozen GL texture-cache trace on the same direct route measured engine
  `EB4E168AC8B1C8F1A0095357E2B6388FB6ED65FFBAF7FBA7D1593B9ABDFE5BA1` and
  renderer
  `F4676812800DB086F1A9D43F4D869776DFB9E004096A7C066B3B8EA032642946`
  before launch. With `cof_gl_trace 1`, both callback bypasses 0, and
  `r_drawentities`/`r_drawbeams` 1, the log recorded 5,942
  `GL_INVALID_VALUE` errors but zero texture-unit cache mismatches and zero
  texture-binding cache mismatches. The first labeled error remained at
  `after_solid_entities`; the retained frame still shows the dark scene,
  flashlight glow, and orange glyphs. The log is
  `stage1/menu-transition-evidence-20260920/direct-cforest3-texture-cache-trace-20260920.log`
  (SHA256
  `2C2A1F07163D176390B702C7AFDE79CE20469AE4A5ED52D11C971B07C642C700`),
  and the frame is `cache-c_forest3_shot0001.png` (SHA256
  `FB187FAAF9FB85FD8E2A6F76721356F7B2BBE77D54B4C5231843C52925507271`).
  The cache mismatch hypothesis is not supported by this run.

* A VGUI-only diagnostic on 2026-09-20 measured frozen engine
  `F08506BFB6530214F0555007E30A6D4D9ECD231A18BD5559D589CF82E0AB1440`
  and renderer
  `F4676812800DB086F1A9D43F4D869776DFB9E004096A7C066B3B8EA032642946`
  before launch. The direct `c_forest3` route reached the map with
  `cof_skip_vgui_paint 1`, while `cof_skip_client_hud_redraw 0`,
  `cof_skip_client_normal_triangles 0`, `r_drawentities 1`, and
  `r_drawbeams 1` were read back. The trace recorded 6,178
  `GL_INVALID_VALUE` errors. The retained frame
  `stage1/menu-transition-evidence-20260920/vgui-c_forest3_shot0001.png`
  (SHA256
  `D996E29E8901A56A84D3957FE8848C9D52E2CC86B0577D2D8F7195576F987B43`)
  still shows the localized flashlight glow and orange glyphs, similar to
  the normal direct control. Skipping the engine `VGui_Paint()` support
  callback therefore does not explain those visuals. The log is
  `stage1/menu-transition-evidence-20260920/direct-cforest3-vgui-paint-bypass-20260920.log`
  (SHA256
  `244B2E123FF3DABB29AE10BA1C7116FC35334591EF76EDAC2785233B443C9DCE`).
  This was diagnostic only; the runtime and baseline manifest were restored
  after capture.

* A normal-callback control set the engine `con_notifytime` cvar to 0 on the
  initial `c_forest3` frame. The readback confirmed `con_notifytime 0` (from
  the default 3); after the delayed capture, the upper orange notification
  glyphs disappeared while the lower orange glyphs remained. The retained
  frame is
  `stage1/menu-transition-evidence-20260920/notifytime0-c_forest3_shot0000.png`
  (SHA256
  `434DEC067F6BA3D4AB53E99FABA1CE12246330E1CCA394917A1CBBEC654044FC`),
  with log
  `stage1/menu-transition-evidence-20260920/direct-cforest3-con-notifytime0-20260920.log`
  (SHA256
  `DA54058D277FB93B3DA18391A2F2A1922A6E4A36D64C3253D57C58A2C54A4E79`).
  This is consistent with the upper band being `Con_DrawNotify` output.

* A follow-up normal-callback control set `scr_drawversion 0` as well as
  `con_notifytime 0`, with readbacks confirming both values. The delayed
  initial `c_forest3` frame no longer contained either orange glyph band;
  the ordinary status bars and flashlight/hand remained. Its frame is
  `stage1/menu-transition-evidence-20260920/scr-drawversion0-c_forest3_shot0000.png`
  (SHA256
  `45D3BBF74C837EF37A79132528127BAEC959BAAEB7A1EB9BAEB269308B017AE5`),
  with log
  `stage1/menu-transition-evidence-20260920/direct-cforest3-scr-drawversion0-20260920.log`
  (SHA256
  `A075AD3C49354E91F76C528BB4BC0534EB83291791E11B740BE1A344BD922A93`).
  Together these controls attribute the orange bands to engine console
  overlays, rather than the client VGUI, normal-triangle, or transparent-
  triangle callbacks. Both temporary runs were cleaned and the baseline
  runtime/save manifest was restored.

* A follow-up font-loader diagnostic restored the normal overlay cvars and
  set `con_oldfont 1`; the post-change readback confirmed `con_oldfont 1`
  after two rendered frames. The initial `c_forest3` frame rendered the
  notification text and bottom-right Xash3D version as readable orange text,
  unlike the garbled fixed-grid glyphs in the baseline. The retained frame is
  `stage1/menu-transition-evidence-20260920/con-oldfont1-c_forest3_shot0000.png`
  (SHA256
  `561F601C7A7DC56ECE8D2E915206775D75C1A174D87FE80E809E43E46206BB06`),
  with log
  `stage1/menu-transition-evidence-20260920/direct-cforest3-con-oldfont1-20260920.log`
  (SHA256
  `B8E20F4301DDFED31C50BE55280FF22D79BC679272F03E5BADD2F7C70416CC5C`).
  This is a diagnostic indication that the CoF variable-width `conchars.fnt`
  path may need explicit loader selection; it is not yet a default change or
  full UI parity proof.

* Terra's frozen console variable-font fallback engine was then tested with
  the original default `con_oldfont 0`, `con_notifytime 3`, and
  `scr_drawversion 1`. The deployed engine hash was
  `680DCD7FCBB5F31DCCA568DFB92ADE465B75A0814D23BB5AB487E09FF2318F1B`;
  the normal renderer remained `F3B1D4B9F3C2237C50447D956EE43070B22BF578C9E15CD0ED67D30B30E6F172`.
  After two rendered frames, the cvar readbacks confirmed those defaults,
  and the initial `c_forest3` frame showed the notification text and
  bottom-right Xash3D version as legible orange text without changing the
  original game assets. The retained frame is
  `stage1/menu-transition-evidence-20260920/console-variable-font-fallback-c_forest3_shot0000.png`
  (SHA256
  `CA541FA797CD60B61666F73AEC5D420F2AB2D7AABCD28B6139A4FE4E79129D94`),
  with log
  `stage1/menu-transition-evidence-20260920/direct-cforest3-console-variable-font-fallback-20260920.log`
  (SHA256
  `9E83FCCC892C815806976A148298D0C7CB85955C296C29CB290A9E7A4D334200`).
  This supports an automatic engine font fallback fix; it does not establish
  selector, gameplay, or Steam compatibility.

* The approved interactive K-runtime helper then launched the normal visible
  menu with launcher
  `C6DFC178774CC88398C017A2E377613DED966C9637BC59C8AEA800538186A17A`,
  fallback engine
  `680DCD7FCBB5F31DCCA568DFB92ADE465B75A0814D23BB5AB487E09FF2318F1B`,
  and renderer
  `F3B1D4B9F3C2237C50447D956EE43070B22BF578C9E15CD0ED67D30B30E6F172`.
  The user clicked Load Game and the first displayed slot. The log records
  `c_game_menu1`, then `Loading game from save/cofsave1.sav`,
  `Spawn Server: c_forest3`, and loading `c_forest3.HL1`, followed by client
  sign-on. The user reported that gameplay appeared and controls worked; this
  is direct GUI interaction evidence, without a visual-parity claim. The
  retained log is
  `stage1/menu-transition-evidence-20260920/interactive-selector-20260920-192635/interactive-selector-20260920-192635.log`
  (SHA256
  `FC221E03A83C76ED9155769E55D3D263415C1C8A22FF02CCC9FBD119CE06903A`).
  The run logged 3,180 `GL_INVALID_VALUE` lines, 36 unknown-command warnings,
  540 warning lines, and the existing `is_donator` delta-field error. The
  isolated launcher and engine were restored after exit; the recovery backup
  and mutable game state remain preserved.

* In the follow-up user check, the in-game inventory opened and at least item
  equipping worked. The phone UI was not confirmed. Pause opened the Xash
  pause menu; that menu does not expose Cry of Fear's tape-recorder saves,
  which remain an in-world interaction. Optional menu saving is a requested
  product feature, not an implemented change; when implemented it is disabled
  by default and user-enabled. It must preserve the existing five-slot limit,
  use those same five slots as the tape-recorder saves, and require overwrite
  confirmation. Preserve the stock tape-only behavior by default.

* A second visible 1080p interactive run covered the same user-facing route;
  the retained evidence is
  `stage1/menu-transition-evidence-20260920/interactive-selector-20260920-193023/interactive-selector-20260920-193023.log`
  (2,057,216 bytes). No screenshot was captured in that run. All backups were
  retained, original binaries were restored, and no process remained afterward.

## GUI handler boundary

The retained command-equivalent captures do not reproduce the complete slot
click handler. Static disassembly of the original client slot-1 path at
`VA 0x100316F7` shows that the handler first hides the panel through vtable
slot `+24` with argument `0`, calls the UI cursor/update helper at
`VA 0x100AAAD0`, sends the server command `unfreeze 1024`, checks
`game_menu`, calls `VA 0x1007FC10(0)`, frees `saveinfo`, and only then sends
the server-forwarded `cofload1` command. The exact symbolic names of the two
internal calls are unresolved here.

The console and delayed-command probes exercise the server-forwarded save
route, but do not reproduce those panel, cursor, and focus operations. The
save-selector appearance in the HUD-suppressed diagnostic frame is therefore
not evidence that the full GUI handler failed; it may be a property of the
diagnostic harness. The later interactive run confirms the user-visible
main-menu-to-stock-save route, but it did not instrument each internal panel,
cursor, focus, or transition field separately.

The isolated `SAVE/cofsave1.sav`, `SAVE/cofsave2.sav`, `SAVE/quick.sav`, and
`cryoffear/SAVE/saveinfo1.cof`/`saveinfo2.cof` were hashed before testing and
were unchanged afterward. No game process remains.

## Current conclusion and next gate

The engine-side command path is proven for entering the load-selector map, and
New Game reaches its difficulty map. The delayed server-forwarded command,
original DLL callback, and save-loader route are now proven. With the opt-in
root-save compatibility path enabled, the preserved stock root `SAVE` layout
was accepted directly and restored `c_forest3`; no extra fixture copy or
deployment mapping was required for that tested route. The opt-in remains
required for this layout. The branded launcher now injects that opt-in before
forwarded load/map commands, and the isolated launcher smoke test read the
cvar back as `1` before accepting the stock root save. The console overlay
glyph corruption is fixed by the tested variable-width fallback with the
default `con_oldfont 0`; a separate severe white/renderer corruption remains,
along with repeated `GL_INVALID_VALUE` diagnostics, so visual parity and broad
gameplay remain unvalidated. One actual GUI route is now user-confirmed:
main menu → Load Game → selected stock slot → playable map/view, with controls
working in that session. The current evidence does not prove every stock save,
camera mode, clean first-person rendering, or the full inventory/phone/pause
surface. Footstep audio and map logs are insufficient as a broad pass
criterion.

The next acceptance gates are:

1. Repeat the stock-save route after death/reload and verify the resulting
   camera, HUD, input focus, and frame quality.
2. Exercise inventory use, drop, combine, and equip paths; verify the phone
   keypad/light/holster flow separately.
3. Verify a map transition and a fresh New Game path beyond the existing
   difficulty-map evidence.
4. If optional menu saving is implemented, keep it disabled by default,
   reuse the same five slots as tape-recorder saves, require overwrite
   confirmation, and test user-enabled save, thumbnail, reload, and rollback
   paths while retaining tape-recorder saves as the default behavior.
5. Resolve or characterize the remaining renderer warnings and visual
   corruption before claiming parity.

## Renderer acceptance record

The user observed that the main-menu map is visibly missing some geometry in
the current renderer. This is a separate visual acceptance defect from the
successful stock-save load, working controls, and inventory-equipping checks;
no causal link to the recorded `GL_INVALID_VALUE` lines has been established.
The renderer is not fully tested. Water or water-shader differences are
explicitly deferred and are not a current priority. When renderer work
resumes, restore the missing main-menu geometry first, then revisit water
behavior after the save-menu interaction path remains stable.
