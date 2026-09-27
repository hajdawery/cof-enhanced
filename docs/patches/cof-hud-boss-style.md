# Remake boss health bars

`cof_hud_style 1` restyles the ten stock boss bars to match Remake health: a thin horizontal bar, subtle gray outline, white fill, a 0.4-second light-red damage flash, and bright red at or below 25% health. It preserves the original bar's horizontal position, width, vertical center and opacity. Deferred drawing receives absolute device coordinates, independent of the active panel painter offset. The original name strip (rows 31–44 of each verified 200×45 empty texture) is drawn unchanged in the original VGUI painter; only the bar art is replaced. `cof_hud_style 0` restores the untouched Classic presentation; the existing menu selector controls both player and boss HUD styling.

Apply after the existing HUD patches with `scripts/apply-cof-hud-boss-style.ps1 -SourceRoot <source>`. Use `-Reverse` to remove it. The HUD module, its declaration in `client.h`, and the VGUI draw handoff change. No game artwork or client DLL is modified or redistributed.

## Verified retail contract

Client `BossBar` handler at `1003E610` reads a visibility BYTE, NUL-terminated empty and full texture paths, current-health signed SHORT, and maximum-health signed SHORT. Mode 1 shows the panel; modes 0 and 2 hide it (2 during paint). The observer never consumes or alters the message. Paint at `1003E7F0` derives the clipped width from current/max health. The constructor at `1003E360` creates full, empty, and clipped-full image children at the same position. The replacement measures only the full-width empty image, never the clipped fill.

Recognition requires both an exact stock path pair and the matching decoded RGBA texture MD5, including the client's inverted-alpha convention. Supported pairs: carcass, craig, david, doctor, hanger, holeboss, mace, pumpa, sawer, simon. All use `gfx/vgui/boss/<name>_health_{empty,full}.tga`. The actual c_apartmentsick `cof_bosshealthbar` entity specifies the Sawer pair; server DLL strings independently verify the Simon pair. Unknown/custom paths retain Classic rendering; unrecognized textures are never suppressed. A mod that changes only one half of a stock pair can retain that changed half while the recognized half is restyled. Atomic fallback for such partially replaced custom skins is outside this stock-art implementation.

Missing or malformed packets, invalid maximum health, reset, menu gating, and absent core HUD assets cannot suppress a bar without the replacement being available. A hidden/non-painted boss panel never creates a replacement bar. New boss/maximum health clears the damage flash; a health increase does not count as damage. Existing HUD gating also hides replacement drawing when the local player is dead or intermission is active. This deliberately retains the same eligibility rules as Remake player health.

## Validation

From an x86 MSVC developer environment:

```powershell
python tests/cof-hud-boss-style/run.py --source-root <patched-source> --out <temporary-output>
```

Add `--game-root <installed-cryoffear-directory>` to verify all 40 normal/inverted decoded stock texture fingerprints using Pillow.

The harness compiles the actual complete HUD source with recording renderer stubs and exercises the measured three-child retail draw order, ten stock skins, exact texture classification, current/max ratio, opacity, damage expiry, low/zero/over-max health, skin/cap changes, mode 0/1/2, every truncated packet length, unknown paths, missing icons, stale frames, menu/dead-player gates, reset, and several resolutions/scales. Patch application and reverse checks pass on an isolated copy. The actual VGUI draw function is also compiled into the harness and tested with nonzero painter offsets, combined UI/HUD scales, clipped UVs and preservation of the exact name strip. A live Sawer capture exposed the original local-coordinate bug, now corrected; parent will repeat the live check.

For a genuine encounter capture, `c_apartmentsick` contains `monster_bosschainsaw` targetname `theboss`, origin `-2065 879 -680`, and `cof_bosshealthbar` targetname `bossbar`, message `theboss`. The map's `multisawersc` starts its boss-bar trigger after 25 seconds. A developer capture can use the actual entity's `use` input where supported; this recipe is source-derived and not a verified playthrough.
