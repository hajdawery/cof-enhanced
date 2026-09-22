# `R_GetSpriteFrame: no such frame 255 (sprites/glow01.spr)` (milestone 5b)

User report, 2026-09-22: the console floods with
`R_GetSpriteFrame: no such frame 255 (sprites/glow01.spr)`.

Renderer patch `patches/cof-sprite-quiet-frames.patch` (ref/gl only, the last
patch of the ref/gl stack, after `cof-viewmodel-fov`), applied with
`scripts/apply-cof-sprite-quiet-frames.ps1`. Evidence:
`stage1/m5b-integration-20260922` (`case-glow*.ps1`, `evidence/glow*`,
`evidence/rel-glow*`).

## Who prints it

`engine/client/cl_sprite.c` `R_GetSpriteFrame`, which clamps an out-of-range
frame and logs it with a plain `Con_Printf` on **every** call. Its caller is
the renderer's `R_DrawSpriteModel`: a one-frame sprite never takes the lerp
path (`R_SpriteAllowLerping` wants more than one frame), so every draw of the
sprite hands `curstate.frame` straight to the engine.

## Where frame 255 comes from

**Measured** with `cof_sprite_trace 1` on the `quick` save (`c_park`):

```
[cof-sprite] sprites/glow01.spr requested frame 155 numframes 1 ent 312 (server entity)
  rendermode 5 renderamt 255 rendercolor 192,0,0 scale 0.098 framerate 7.94
  path R_DrawSpriteModel -> engine R_GetSpriteFrame (direct)
```

(`framerate 7.94` is the 8-bit signed delta field's ceiling, 127/16, for a
real 10.) `c_park` has no `glow01` entity of its own (the map's entity lump
was scanned), and the only code in `hl.dll` that creates `glow01.spr` is
**`CTapeRecorder::BlinkThink`** (export `?BlinkThink@CTapeRecorder@@AAEXXZ`,
`1007C440`): every blink it calls `CSprite::SpriteCreate( "sprites/glow01.spr" )`
and sets scale 0.1, `kRenderTransAdd`, colour 192 0 0, renderamt 255,
framerate 10 and `AnimateUntilDead` with `dmgtime = time + m_maxFrame / 10`
(`CSprite::AnimateAndDie` inlined) - exactly the traced state. It is the tape
recorder's red blink light, not the lamps.

The value itself: `CSprite::AnimateThink` (`10092610`) advances
`frames = framerate * ( time - m_lastTime )`, and `CSprite::Animate`
(`10092590`) wraps the result with `fmod( frame, m_maxFrame )` only when
`m_maxFrame > 0`. For a one-frame sprite `m_maxFrame` is 0, so nothing wraps.
**Measured**: with the stock clamp the log shows one line per blink, frame 155,
165, 175 ... 255, one second apart (`glow2-q0.log`, 11 lines in 16 s), then
255 for good - consistent with a fresh sprite each blink whose first advance
is counted from `m_lastTime` 0, i.e. 10 x the level time (**inferred**), and
with the 8-bit network `frame` field saturating at 255 after 25.5 s. The frame
drawn is the sprite's only frame either way; stock GoldSrc clamps silently.

## The change

```
cof_sprite_quiet_frames   default 1, FCVAR_GLCONFIG (opengl.cfg)   0 = stock
cof_sprite_trace          default 0, flags 0                        developer diagnostic
```

* `cof_sprite_quiet_frames 1`: `R_CoFSpriteFrame` clamps an out-of-range frame
  (0 or numframes-1, the same values the engine would pick) before the engine
  sees it, on both the direct and the lerp path, so the draw is unchanged and
  the engine's per-call warning never fires. One line per sprite model is
  still printed, at developer level (`Con_DPrintf`).
* `cof_sprite_trace 1`: once per sprite model, the name, requested frame,
  numframes, entity index (server or client entity), render mode, amount,
  colour, scale, framerate and the calling path.

## Verification

| Run | settings | "no such frame" lines |
| --- | --- | --- |
| `glow2-q0` | `cof_sprite_quiet_frames 0` (stock) | 11 in 16 s (155 ... 255) |
| `glow2-q1` | default | 1 (the developer line) |
| `glow2-t1`, `rel-glow` | default + `cof_sprite_trace 1` | 1, plus the `[cof-sprite]` line above |

The street-lamp halos and the tape recorder render in both
(`glow2-q0-c.png` / `glow2-q1-c.png`); the clamped frame is the same frame the
engine chose before. Note for tests: `cof_sprite_quiet_frames` is
`FCVAR_GLCONFIG`, so a run that sets it writes `opengl.cfg`; the m5b driver
restores a baseline `opengl.cfg` before every run.

## Artefacts

| Artefact | Bytes | SHA-256 |
| --- | ---: | --- |
| `patches/cof-sprite-quiet-frames.patch` | 6 578 | `AC6F465066EDAF9AA0AB2BB0AACE302332AE02AB4A7DFDD8EECD49E61BCAF96D` |
| `ref_gl.dll` (`stage1/releases/m5b-20260922`) | 1 111 552 | `179C03D3AE5D5D347F8F366D48CC78CB88B742FE19327A076E90732E89DEDB44` |

The released renderer is built from the live checkout's `ref/gl` (out dir
`build-cof-m5b-ref-20260922`), which also carries the older default-off
diagnostics the deployed `73E6F5E3...` had; the patch goes on there with
`git apply -C1` (the same reduced context `cof-viewmodel-fov` needed) and
`gl_sprite.c` is then byte-identical to the stack-verified tree.
