# Gamepad round 4: missing cursor and controller pictures

2026-09-27, data and packaging repair; no engine patch or rebuild required.

## Measured cause

The playable runtime's `cryoffear/gfx/shell/gamepad` contained the old 36-file
Xbox/PlayStation payload. It had no `cursor.png`, `switch/`, `steamdeck/` or
`LICENSE-NOTE.md`, and an old `icons.txt`. The repository and frozen
`stage1/releases/m9-20260924` each contain the complete 64-file payload.
The runtime's engine and menu already match m9 byte for byte:

| File | SHA-256 |
| --- | --- |
| `xash.dll` | `5C417EB83049BA6E9C5AA869E7E3921C96ABA2A24D79CCE677DFB511CA08B244` |
| `cryoffear/cl_dlls/menu.dll` | `04E08DD3F3137791490BC91B49A074B51B58870D12263D95119B8EC98F93BD35` |
| staged/repository `cursor.png` | `F32A42BF828DF4D4424EA10CEDC5E0007B15ADE268718554AD16C7FB7A6911FD` |

The engine's `CL_CoF_VCursorArt` loads precisely that path and intentionally
falls back to the procedural ring when the image is absent. `icons.txt` has
the correct Switch and Deck `STYLE` rows. No lookup change is needed.

## Fix

The public release builder previously omitted the entire gamepad directory
from its gamedata allowlist. It now copies every tracked gamepad file and
validates the copied folder before making an archive. The reusable read-only
`scripts/test-gamepad-art.ps1` checks the cursor's PNG/RGBA dimensions, all four
STYLE rows, every referenced PNG, both attribution files, and optionally every
file against a SHA-256 manifest. This catches an incomplete art deployment.

The workspace deploy script `stage1/deploy-ui-m3-20260921.ps1` now resolves
paths relative to its location instead of the old `K:` drive. `-CheckOnly`
validates the source payload without writing anything; `-ArtOnly` selects only
the frozen art folder, with its pinned 64-file manifest, and puts the old art
in its own timestamped backup. The full deployment backup is preserved.

From the workspace's `stage1` directory:

```powershell
# Read-only, safe while the game is running:
./deploy-ui-m3-20260921.ps1 -ArtOnly -CheckOnly
# When ready to update the play runtime, after closing the game:
./deploy-ui-m3-20260921.ps1 -ArtOnly
```

The art-only operation reports the exact backup path. Restore its
`cryoffear/gfx/shell/gamepad` folder as a whole if needed; the normal full
`-Rollback` belongs to the full deploy backup, not this separate art backup.

## Verification and limits

Repository and m9 art pass validation against the frozen m9 manifest.
Negative checks reject the old runtime's missing cursor, a missing Deck
silhouette, a missing Switch STYLE row, and a changed manifest-pinned file.
Both art-only and full deployment preflight passed against the m9 payload
before the new round's binding data changed. Release-script syntax passes;
no release archive was assembled from this in-flight checkout.
Source review confirms the cursor loader and all style lookups. The supplied
Switch/Deck art was regenerated with `scripts/make-gamepad-style-art.py`:
all 26 files match the repository byte for byte. No artwork was redesigned.
No runtime files were changed, no game launched,
and no binary rebuilt. Visual confirmation after deployment remains manual:
open a panel with a pad for the square cursor, then select Nintendo and Steam
Deck in Options > Gamepad for their controller pictures.
