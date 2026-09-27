# Optional Remake HUD

`cof_hud_style 0` is the default and retains Classic. `1` selects the compact
Remake presentation through the Game options selector. This engine patch never
edits the retail client DLL or changes gameplay, inventory, ammunition, or weapon
messages. Apply after HUD text style; the selector is a separate MainUI patch.

Health appears at the bottom left with an anatomical heart and a horizontal bar.
It is white normally, light red for 0.4 seconds after damage, and bright red at
25% of the health cap or below. Depleted stamina appears as a thin centered line.
Both follow the visibility and alpha of the original HUD elements. Dimensions
use a 1080p reference and the existing user HUD scale multiplier.

The right counter uses rounds in the current magazine and the exact number of
spare magazines drawn by Classic. It never divides reserve ammunition to guess
a magazine count. Shotgun counters use shells for both loaded and spare counts,
with the shell icon. Supported single-weapon sprite families are Glock, P345,
M16, TMP, rifle, Browning, FAMAS, VP70, G43, MP5, and shotgun. A missing or
ambiguous count, dual wield, or unsupported sprite retains the original ammo
presentation. The retail VP70 shows verified fixed `BURST` and FAMAS shows `AUTO`; other
modes are omitted and this introduces no firing-mode toggle.

## Measured data and rendering boundaries

Retail `client.dll` disassembly established `CurWeapon` as three bytes (active,
signed weapon ID, signed clip), `Stamina` as one percentage byte followed by a
coordinate recovery delay, and `DualAmmo` as two signed 32-bit values. The
client's negative clip convention is retained. Health comes from engine client
state, with the `HealthCap` byte applied when provided.

Ammo reserve digits are decoded from same-frame `cof_ammohud.spr` rectangles
(20 by 24 at horizontal increments of 24). One to three coherent digits are
accepted with an identified magazine/cross or shotgun/box-icon combination.
Shotgun ID 4 is confirmed at HUD draw `10018623`; its reserve helper
`1001B672` stores raw individual shells, unlike magazine-count cases. VP70 ID
19 and its sprite mapping are confirmed at `10018B7D`; server `Shoot` continues
until three shots at `10085267`, while secondary is melee. FAMAS ID 23
primary `1003BBD0` is invoked by the held-attack shared loop at `1011DBE0`,
updates its cooldown without an attack-release latch; its secondary is melee.

Recognized sprites are buffered with their exact final geometry, UVs, color,
texture and blend mode. Incomplete patterns replay Classic. Interleaved unknown
sprite calls and overflow replay the pending batch before the current draw and
disable replacement for that frame. Collection closes immediately after client
redraw, before pause/fade overlays. Reserve digits are never cached across
frames or maps. Direct non-sprite renderer calls inside an ammo cluster are not
intercepted; no such retail cluster was established by this review.

Health/stamina VGUI textures are recognized by the MD5 of decoded RGBA pixels,
including both BitmapTGA alpha conventions. No game artwork is redistributed.
Suppression and replacement share the same active-game/menu gating. Only a
recognized element drawn that frame triggers a replacement. This assumes those
exact HUD images are not reused by unrelated custom panels; unknown/custom
images remain Classic. Texture IDs are rechecked against the renderer cache
after reloads. `CL_ClearState`, `ResetHUD` and `InitHUD` clear message state.

Icons are original generated PNGs at `gfx/shell/hud_remake/heart.png`,
`bullet.png`, `magazine.png`, and `shell.png`. Sources may have any resolution.
The loader computes a visible UV crop from alpha at least 128 before upload,
ignoring faint exterior noise and preserving aspect ratio. Missing artwork
retains Classic and retries later. Source pixels are never reused after upload.

## Verification

`tests/cof-hud-remake/run.py --source-root <patched-tree> --out <evidence-dir>`
compiles the actual C module against recording renderer/message stubs using an
x86 MSVC developer shell. It checks Classic and missing-art passthrough, cropped
alpha bounds, multi-digit and zero magazine counts, no stale next-frame count,
ambiguous-pattern replay, shotgun shells, dual fallback, interleaved and overflow
blend restoration, VP70/FAMAS labels, frame visibility, reset, and malformed packets.
The apply script checks prerequisites, markers, and the inverse patch. A sparse
apply/reverse fixture returned identical source (Git normalized line endings).

These are source and compiled contract checks, not visual play verification.
User testing should cover reloads, magazine inventory above nine, shotgun shells,
dual wield, low health/damage, stamina depletion, pause and inventory, map changes,
resolution/HUD-scale changes and switching back to Classic.
