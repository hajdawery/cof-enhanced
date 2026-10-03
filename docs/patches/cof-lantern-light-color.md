# Lantern world-light color sentinel

`cof-lantern-light-color.patch` fixes a concrete engine/client data mismatch
behind dark placed and dropped lanterns. FWGS replaces black `rendercolor`
with white on all non-brush entities before the client `HUD_AddEntity` callback.
Cry of Fear uses black as a default-light sentinel for its renderfx 245,
so this changes the private light's radius selection.

The retail client chooses radius `220 + RandomLong(-5,5)` when all three color
bytes are zero and renderamt is 0 or 255. Otherwise it uses
`renderamt + RandomLong(-5,5)`. An ordinary lantern has amount zero: whitening
its sentinel therefore collapses a roughly 220-unit light to at most 5 units.
This is independent of engine dlights, GL alpha or depth equality.

| Setting | Default | Meaning |
| --- | --- | --- |
| `cof_lantern_light_fix` | 1 | Preserve rendercolor for Cry of Fear renderfx 245. Set 0 to restore the previous whitening behavior. |

The cvar is archived. The guard uses the case-insensitive `cryoffear` game
folder and exact effect 245; it does not change any model, amount, other effect
or other game. Brush entities keep their existing handling. Nonzero colors,
including near-black colors, remain exact. Existing white-default handling
continues for ordinary sprites and studio models.

Apply after `cof-light-diagnostics` using
`scripts/apply-cof-lantern-light-color.ps1 -SourceRoot <checkout>`; `-Reverse`
removes it. The additive patch also extends `cof_light_status` to show raw
packet color/amount beside linked entity color/amount and the new cvar.

## Evidence and checks

Retail client SHA-256:
`D2A04641B301804F6F449AA68265042B13ADC360925B80033D417EC9F38C9C00`.
At preferred base addresses `0x1006046B..0x1006052C`, effect 245 checks
exact-zero RGB and amount 0/255. Default-radius addition is at `0x100604EA`;
explicit-radius addition is at `0x100605B4`. FWGS's previous whitening is in
`CL_AddPacketEntities`, before `CL_AddVisibleEntity` calls the retail callback.

Before the fix, an isolated `c_forest3` save produced a placed lantern
entity 153 and a newly dropped lantern entity 308, both fx245. Read-only,
hash-guarded snapshots of the owned process found private radii 1 and 4,
white RGB and zero engine dlights. The held light, produced separately,
had radius 218..225 and RGB `(0.4,0.4,0.4)`. The BSP's placed lantern has
explicit black rendercolor. Alpha 8, four texture units and an allocated 3D
attenuation texture excluded the earlier missing-alpha hypothesis locally.

`tests/cof-lantern-light-color/check.py` extracts the applied production
predicate and whitening block into a minimal C harness. Its 11 cases cover
zero/255 default amounts, opt-out, other game/effect, brush, ordinary sprite,
near-black, explicit color and explicit amount. The x86 MSVC run passed.
A negative control reinstates old whitening and must fail the default-radius
cases; it did. Apply/reverse/apply checks and the combined x86 build passed.

A controlled same-process run then dropped the lantern and held camera/input
settings constant. With the cvar disabled, both raw packet colors were black
and amount zero, but linked colors were white. With it enabled, both linked
colors stayed black, and the private placed/dropped light radii were 222/225
with RGB `(0.4,0.4,0.4)`. The matching screenshots changed from dark ground
to illuminated ground, foliage and tree around the dropped lantern. The run
exited normally; fixture configs were restored. This verifies the causal
chain and visible fix for the reproduced placed/dropped-lantern defect.

Evidence: `stage1/issue4-lighting-20261003`, including launch scripts, logs,
module hashes, screenshots and private-pool snapshots. No game assets or
retail binaries are changed by this patch.
