# Retail active dual-wield packets (issue #5)

Apply after the existing HUD ammo/compact/boss/stamina stack. This additive
patch changes only the observed message decoder in `cof_hud_remake.c`.

The previous decoder inferred the packet size from retail client handler
`10090780`: it reads a model string, three bytes and a short. The retail **server
does not send that short on active packets**. Read-only inspection of canonical
`hl.dll` found active writers at `10033239`, `100F2E75` and `100F79E5`: each
writes the model string and three bytes, then ends the message. Clear-model
branches at `100F2E36` and `100F79AF` also write the final short. The two identity
bytes are the same fields the client stores at `10545864` and `10545868`.

Requiring five bytes after the string discarded all these active packets,
leaving both identities zero and intentionally falling back to Classic ammo.
The decoder now accepts exactly the measured three- or five-byte suffix. It
still requires a bounded NUL-terminated model string, rejects other lengths,
validates stock IDs, and never reads the optional short. Client data is unchanged.

`cof_hud_dual_protocol 1` is the default. Setting it to `0` restores the previous
strict decoder; `cof_hud_style 0` retains Classic presentation.

`tests/cof-hud-dual-protocol/run.py` compiles the real module, reuses the complete
existing ammo suite and adds active pistol/phone, swapped hands, two-gun,
clear-state, malformed/truncated, unsupported-ID, reset and opt-out fixtures.
This corrects the earlier synthetic fixture's unconditional trailing short.
The additive patch passed apply/reverse checks. No retail DLL is patched.

## Runtime check, 2026-10-03

The combined candidate was run in an isolated, muted 1920x1200 fixture at HUD
scale 1.5. Giving the phone and Glock and running retail `inventorydualwield 1 2`
produced actual `DualWield SIZE 36` and `DualAmmo SIZE 8` messages. The Remake
capture shows separate `GLOCK SEMI` (15 loaded, one spare magazine) and `PHONE`
rows; switching to Classic restores the original magazine display.

Local evidence is under `stage1/issues-hud-runtime-20261003/hud-revised/`:
`verified-remake-dual.png`, `verified-classic-dual.png`, `hud-revised.log` and
`RESULTS.json`. The descriptive image copies preserve original screenshot
bytes. Original filenames 02/03 had inverted style labels because capture is
deferred and the cfg changed style immediately afterward. The fixture process
exited normally; the player's runtime was not changed.

Remaining visual validation: two guns, gun + light, reloads, save/load and 4K.
