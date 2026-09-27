# Digital-style walking correction

`cof_pad_move_fix 1` (archived, default) corrects continuous Digital-style walking. `cof_pad_move_fix 0` restores the previous mode 1 shape and command behavior. Analogue mode 0 and snapped mode 2 remain unchanged. Keyboard-only movement is untouched, including when a pad is unplugged or centered.

The retail client PM_CheckParameters at 10010DC0 halves forward movement whenever both command axes are nonzero (10010E39, float constant1013EE28 =0.5). This includes slight sideways stick drift. The recorded command306.8,-23.2 becomes153.4,-23.2; its normal walking speed is116.36 units/s. Keyboard300,0 bypasses that branch and yields225 units/s. This reproduces the user's observed difference.

Mode 1 now keeps radial direction, the existing deadzone/slow-walk response and diagonal preference. After composing engine input with the client's keyboard command, the correction doubles forward only to cancel the proven retail factor on mixed-axis commands. The retail speed cap remains in charge. Active sprint (IN_RUN plus the CoF player flag0x40000) skips compensation because retail zeros side instead of halving forward. The flag comes from the most recent predicted movement state; runtime sprint transitions still need play validation.

Sub-unit command components are zeroed before compensation because network commands truncate them to whole units. This keeps prediction and server on the same mixed-axis branch. It introduces only the existing wire command resolution, not a broad directional snap. There is no new speed multiplier.

Run `tests/cof-pad-digital-speed/run.py --source-root <patched-source>` with the bundled Python. It compiles the actual shape and correction functions against stubs, compares legacy mode/opt-out behavior, reproduces the screenshot's116.36 result and corrected225 target, and covers signs, near-cardinal directions, partial deflection, wire-zero boundaries, keyboard-only and mixed input, disconnect, sprint flags, null movement state and non-finite guards. No game launch is performed by the test.
