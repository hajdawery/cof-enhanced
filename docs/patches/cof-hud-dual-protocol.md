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

Remaining visual validation: equip pistol + phone/light and two guns; reload,
switch back to one weapon, save/load and switch Classic/Remake at 1200p and 4K.
The reported gameplay sequence was not reproduced in a live game in this change.
