# Compact boxed Remake ammunition

`cof_hud_ammo_compact 1` is archived and enabled by default. It affects Remake
HUD only; Classic stays unchanged. Set it to `0` to restore the previous
unboxed 24-pixel Remake ammunition layout.

Numbers and adjacent bullet/magazine/item icons use an 18-pixel 1080p reference,
25 percent smaller than before. Firing mode and dual-hand identity captions use
an independent 11-pixel font inside a small header. A thin muted gray outline
encloses each row, with a subtle black backing (alpha 64) and a divider between
loaded rounds and reserve ammunition. The existing message decoding, quantities,
infinite-ammunition display, icon choices and fallback labels remain unchanged.

The box width follows measured text widths, including large reserves and `INF`.
Each dual-hand row has its own box; the second box is stacked above the first
using its actual height, so captions cannot overlap. Resolution and user HUD
scaling still apply. Extreme scale settings shrink to available screen width
and cap total row height so both boxes remain visible. Missing optional item art
retains its text fallback inside the box.

`tests/cof-hud-ammo-compact/run.py` compiles the actual HUD module and records
every box, icon and text rectangle. It checks explicit 18/11-pixel font heights,
all stock IDs, large counts, infinite ammo, dual firearm and utility rows,
640x480/1280x720/1920x1080/3840x2160, three HUD multipliers including an extreme
setting, fallback text, Classic, and the opt-out. Every drawn element must fit
its containing box and screen, and dual boxes cannot overlap. These are compiled
geometry checks; final appearance still needs user play testing.
