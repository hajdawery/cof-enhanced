# Remake ammunition from retail messages

This additive correction follows `cof-hud-remake`. `cof_hud_style 0` still
retains Classic. The previous sprite-digit buffer was too restrictive for real
gameplay: it required one contiguous, geometrically coherent group and treated
nonnegative `DualAmmo` values as an active dual-wield flag. Retail selects dual
wield only when the active weapon ID is 15; `DualAmmo` contains clip counts.
The user's runtime test found every weapon retaining Classic ammunition, which
the earlier idealized draw fixtures had failed to expose.

The replacement observes the same server messages used by the retail client,
with bounds and packet-length checks. It does not write client state or modify
the original DLL. Named ammunition sprites are suppressed independently of draw
order; the styled display is drawn immediately after the client HUD callback.
Noise, crosshair and other sprites pass through without changing blend state.
Loading/changelevel passes no longer open ammunition collection.

## Exact counting rules

`WeaponList` supplies the signed primary ammunition type in its eight-byte
suffix. `AmmoX` supplies a type byte and signed 16-bit quantity (retail takes its
absolute value). `WpnInfo` supplies weapon ID, an explicit divisor byte and a
signed 16-bit amount. These reproduce retail handler `1001B610` and reserve
getter `1001A070`; no magazine capacity is guessed.

| Stock IDs | Displayed reserve | Icon |
| --- | --- | --- |
| 3 Glock, 7 P345, 9 M16, 14 TMP, 19 VP70, 20 Browning, 26 G43, 27 MP5 | `WpnInfo.amount / WpnInfo.divisor`, exactly as retail | Magazine |
| 4 shotgun | `AmmoX` selected by `WeaponList`, individual shells | Shell |
| 11 scoped rifle, 21 revolver | Selected `AmmoX`, individual rounds | Bullet |
| 8 syringe, 13 flare | Direct `WpnInfo.amount`, item quantity | Item |
| 23 FAMAS | `INF`, matching retail `gm_inf` sprite at `100194AF` | Magazine |

Current loaded rounds come from signed `CurWeapon` clip fields, including the
client's negative-value convention. All weapon clips are tracked, while only
active packets change the selected weapon. Zero counts remain valid. Reset
clears amounts and selection but retains `WeaponList` metadata, as retail does
across respawn. Unknown custom IDs retain the original presentation.

ID 15 uses `DualWield`'s model string followed by one byte, two weapon-ID bytes
and a short; `DualAmmo` contains two signed 32-bit clips. Two separate labeled
rows show each hand's actual weapon, clip and reserve. Switching back to a
single weapon ignores the still-populated dual clips. Until both dual identity
fields arrive, the original display remains visible instead of a blank readout.

Stock utility/melee IDs 1 flashlight, 2 phone, 5 camera, 6 knife, 10 lantern,
12 nightstick, 16 branch, 17 action, 18 hammer, 22 radio, 24 axe and 25 book
show their identity icon without inventing an ammunition count. Syringe and
flare have their own icon and quantity. The existing health/stamina renderer is
unchanged by this patch.

## Modes and assets

Verified fixed labels: Glock, P345, Browning and G43 `SEMI`; scoped rifle and
revolver `SINGLE`; TMP, FAMAS and MP5 `AUTO`; VP70 `BURST`. M16 has a mutable
server mode that has not been established in the client message protocol, so
this renderer does not guess its current setting. Shotgun has no mode label.

`gfx/shell/hud_remake/items.png` is a transparent four-by-four uniform-cell atlas:

| Row | Cells from left to right |
| --- | --- |
| 1 | Flashlight, phone, camera, lantern |
| 2 | Knife, nightstick, branch, hammer |
| 3 | Flare, radio, axe, book |
| 4 | Syringe, action/hand, reserved pickaxe, reserved shovel |

Visible alpha bounds are measured separately inside each cell before upload;
all icons share one texture. Missing individual art uses a text identity,
without restoring the old ammunition display. The four existing core HUD PNGs
remain required; missing core assets retain Classic safely. Retail HideWeapon
bits `0x0d`, menu gating and non-active state prevent a stray replacement.

## Verification and limits

`tests/cof-hud-ammo/run.py` compiles the real module against recording stubs.
Fixtures model the retail packet formats, eight magazine switch cases,
individual-round cases, reload/discard updates, lingering dual clips during
single-weapon use, actual dual identities, all 27 stock IDs, item quantities,
infinite ammunition, per-cell atlas bounds, hide flags, resets and Classic.
The draw sequence deliberately interleaves unrelated overlays and omits digit
geometry, so the old buffer assumptions cannot silently return. The patch also
receives apply/reverse source comparison and independent worker review.

These checks do not replace user play testing. No automatic game launch or
input injection was used. Custom weapon IDs, models that repurpose stock IDs,
and unknown mod message formats are outside the measured stock catalog.
