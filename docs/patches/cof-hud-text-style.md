# Muted Bold in-game text

`cof-hud-text-style` adds the approved Inter Bold treatment to the existing
in-game message pipelines: muted grey **#BFC1C2** and a small soft charcoal
shadow. MainUI typography, document text, inventory roles and chapter titles
are unchanged. `cof_hud_text_style 1` enables it; **0** restores the earlier
SemiBold face and original message colours live. The existing **Subtitle
background** menu option stays independent and works with either text style.
Its `cof_hud_text_backing` default is now **0** (off); enabling the checkbox
sets 120 as before. Existing saved preferences are respected.
The existing font substitution cvars remain available.

## Coverage established from the existing client audit

The visible pickup messages and dialogue use FreeVGUI `CHUDControl`, whose
font role is `credits`. The engine's existing `CL_CoF_FontRoleIsMessage`
classification selects this role. The stock `$effect 3` `CSubtitle` route is
not used by the shipped titles data. Synthetic `HudText` subtitles also use
the separate engine `pfnDrawCharacter` path, which this patch covers too.
See [the measured pipeline investigation](cof-hud-text-legibility.md).

The `credits` scheme is shared with credit-roll text and the top hint bar;
this remains role-based styling, not a new panel classifier. Engine
`pfnDrawCharacter` also carries equipment notices and pickup counters. Those
text paths receive the new style, including previously coloured messages.
Health/stamina/boss-bar graphics and unrelated VGUI/menu font roles keep their
semantic colours. UTF-8 engine draws retain their existing direct colour path
to avoid decoding the same multi-byte character once per shadow tap; the
shipped CoF subtitle pipeline is single-byte.

## Rendering and assets

FreeVGUI's existing face selector uses value 2 for Inter Bold, without changing
the shared structure size. The engine caches a third face from
`gfx/fonts/Inter-Bold.ttf`, falling back to SemiBold when it is missing. Engine
HUD text uses `fonts/cof_hudtext_bold0.fnt` and `cof_hudtext_bold1.fnt`, generated
at 14 and 19 pixels from that same face. Missing Bold atlases fall back to the
earlier SemiBold atlases. Font metrics reload on live style changes.

The shadow is RGB 24/25/27: one 22% central tap and four 7% peripheral taps.
Its offset is 5.5% of glyph height and radius 3.5%, floored at one drawing unit;
VGUI's existing UI transform scales these with its glyphs. Every collected
line draws all shadows before any foreground glyphs, avoiding dark edges
from a neighbour's later shadow. The same clipped helper handles the rare
direct overflow path. Optional backing strips remain available underneath the
styled text. Their placement, configured opacity and the pager's behavior
remain unchanged; changing text style never overwrites that preference.

VGUI preserves the client's inverse alpha exactly. The engine API has no
alpha argument and fades text by multiplying RGB, so its highest colour
channel becomes opacity before the foreground is changed to grey. Both shadow
and foreground therefore vanish together; no dark ghost remains after fade.

`tests/cof-hud-text-style/run.py` compiles extracted renderer/descriptor code
against host stubs and checks role selection, fallback, colour/alpha, shadow
geometry, clipping, and draw passes. Source apply/reverse checks cover the
patch stack. No claim of visual or hardware validation is made by these tests.
Manual validation should include dialogue/pickup fades over bright/dark scenes,
1080p and 2160p with several HUD scales, and the live style opt-out.
