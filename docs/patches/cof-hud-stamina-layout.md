# Remake stamina layout and dodge overlay

Apply after `cof-hud-remake`. Classic is unchanged. Remake stamina is centered
at the bottom, 280 by 4 pixels at the 1080p reference instead of 150 by 2.
The existing HUD multiplier and resolution scale still apply.

The old red dodge rectangle is a separate solid VGUI Panel, not a texture.
Retail client disassembly verifies its creation at `10036FC5`: member FE8
is parented to the stamina image panel DC, positioned at 0,0, with dimensions
read from the stamina empty image. The stamina message updates recovery-delay
time FE4 at `1003A3C9`. During recovery, `1003CBC6` sets the child background to
red (255,0,0) with VGUI transparency 128; `1003CC16` subsequently increases
transparency by 15 per update. FreeVGUI `Panel::paintTraverse` paints the parent
before its children; `Panel::paintBackground` emits the child's solid rectangle.

The engine matches that precise draw pair: a fingerprint-recognized stamina
texture immediately followed by a solid red quad with identical final bounds,
within the same VGUI pass and frame. Any intervening quad, different bounds,
color, missing stamina state, missing art, or menu/Classic gating leaves the
solid draw alone. This is not a general red-rectangle suppression rule.
The matched red flash is drawn across the new stamina bar with the client's
actual converted alpha, preserving its delay and fade. A nonzero flash remains
visible even if stamina has already recovered to 100 percent.

State is cleared at each VGUI paint; bounds are measured after both UI scaling
stages, so resized or HUD-scaled panels must establish a fresh pair. Custom
clients that change the texture/child sequence conservatively retain their
original solid overlay.

`tests/cof-hud-stamina-layout/run.py` compiles the actual module with renderer
recording stubs. It checks Classic passthrough, unrelated color/position/texture,
interleaved quads, stale frames and new passes, reset, real flash alpha, and
1080p/4K geometry with a user HUD multiplier. No game launch is performed.
