# 0.4.0-test3

This public test release adds an optional Remake HUD and improves controller navigation, movement, and in-game text.

## Changes

- Choose **Classic** or **Remake** in the HUD setting. Classic remains the default.
- Remake health and boss bars share the same colors: white normally, light red after damage, and bright red at low health. Stamina uses a larger bottom-center bar with its recovery flash in the correct position.
- Compact boxed ammunition displays distinguish bullets from spare magazines. Shotguns use shell icons; supported firing modes, dual-wielded weapons, syringes, and other equipment have appropriate displays.
- In-game text uses grey Inter Bold with a soft shadow. The subtitle background option remains available and defaults off.
- Menus are smaller. Selection controls use dropdowns, and controller navigation reaches every options row.
- Digital controller movement now compensates for the game's mixed-axis slowdown. Keyboard movement is unchanged.
- Escape closes the current note or other game pane before opening Pause.
- The smaller on-screen keyboard identifies the active field. Done advances to the next field or closes the keyboard; it never submits the game's form.
- Corrected the controller cursor's shadow artifact and updated controller glyph delivery.

## Install or upgrade

Download `cof-enhanced-0.4.0-test3.zip`, extract it into your Cry of Fear folder, and run `Install.cmd`. For an existing Enhanced installation, use that same folder; do not uninstall first. The installer preserves saves and configuration files and retains the original installation backup. Custom controller bindings and saved gyro preferences are preserved during migration.

The separate source ZIP is for developers. `SHA256SUMS.txt` contains archive checksums.

This remains a test release. The entire campaign has not been re-tested on this build. The M16's changing firing mode is not labeled unless a reliable mode signal is available; ammunition counts remain independent of that label.
