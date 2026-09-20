# Stage1 campaign and save/load console smoke checkpoint

The test used the matched isolated runtime
`stage1/launch-proof/client-runtime-corrected` and engine SHA256
`65ACDEA266B66E7FFA44B15281B97C9938C63069E81411D84F9A5C6C00E79FAE`. The
deployed PDB still reports `edict_s` size `0x32C` with `pvPrivateData=0x7C`
and `v=0x80`.

A bounded `+map c_intro` run with `-cof-pmove-legacy` loaded
`maps/c_intro.bsp`, reached level load at about 1.03 seconds, connected the
client at about 0.87 seconds, and produced no second-chance exception. The
log is `stage1/launch-proof/client-runtime-corrected/client-startup-clientpmove-adapter-812-c_intro.log`.

For save testing, an isolated temporary `cryoffear/maps/c_intro_load.cfg`
waited until the local player was active and issued `save luna_stage1`; it was
removed after the run. The engine logged `Saving game to
save/luna_stage1.sav` and wrote the save preview. The save artifact was
158804 bytes with SHA256
`0804FEE0063A9D260204FF1B1ACE6F85022CBEA63B2ECEC0BB1549E5ACB7428D`.

A second bounded run with `+load luna_stage1` logged `Loading game from
save/luna_stage1.sav`, spawned `c_intro`, loaded the BSP, reached level load at
about 1.25 seconds, and connected the client at about 0.80 seconds. No
second-chance exception was captured. Logs and save artifacts remain in the
isolated test directory and are excluded from the repository.

The generated save preview is 267x200 and nonblank, with a rendered viewport
and black letterbox bands. It is available outside the repository at
`stage1/launch-proof/luna_stage1-snapshot.png`. This verifies basic rendered
output only; it does not establish vanilla visual parity, human control, or
Steam launch behavior.

## Validation limits

Both map transitions and the save/load check above were console-driven smoke
tests. The save was created by this Xash runtime, so they do not prove that
the original GoldSrc/Cry of Fear save format loads, or that the main-menu
`New Game` and `Load Game` controls complete their GUI transitions.

The current user report is kept as an open regression: selecting `Load Game`
from the main menu, choosing the first existing save from the real Steam
installation, and activating it can leave the menu view visible while
footstep audio plays. This report is not yet a reproduced root-cause finding.
The prior console logs and save hash remain valid evidence for their narrower
smoke-test scope.
