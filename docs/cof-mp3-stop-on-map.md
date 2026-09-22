# Stop the client's MP3 player on a session change (`cof_mp3_stop_on_map`)

Cry of Fear's music does not go through the engine at all. `client.dll` creates
its own irrKlang device and a `CMP3Player` next to it, so `S_StopBackgroundTrack`
in `CL_Disconnect`, the level loader's audio teardown and every other engine
sound path leave it running: a track started on one map keeps playing over the
next one, over a loaded save, and over the menu.

The full measurement is in `stage1/menu-music-20260921/RESULTS.md`. The parts
this patch depends on:

| Thing | `client.dll` VA | Note |
| --- | --- | --- |
| `MP3_Create()` | `1007F9E0` | one `createIrrKlangDevice`, called from `CHud::Init` |
| `CMP3Player::Stop( float fade )` | `1007FC10` -> `10080780` | fade 0 = immediate `ISound::stop()` |
| `stopmp3` console command | registered at `1006D60A`, handler `1006E350` | **unconditional** `MP3_Stop( 0.0f )` |
| `mp3player` console command | handler `1006E310` | an empty stub, does nothing |
| `PlayMP3` | user message, hooked at `1006D5FA` | the only other control surface; there is no "stop" user message |

So `stopmp3` is the whole control surface, and it is an ordinary client console
command, which means the engine can issue it.

## What the engine does

`CL_CoF_StopMP3( reason )` in `engine/client/cl_main.c` runs
`Cmd_ExecuteString( "stopmp3" )` **directly** rather than through `Cbuf`,
because it has to take effect *before* the transition it precedes: a queued
command would run after the new level had already started its own track.

Guards, in order: the cvar; `host.status == HOST_CRASHED` or a dedicated build;
`clgame.hInstance` (no client DLL, no player); `Cmd_Exists( "stopmp3" )` (a
client that is not Cry of Fear); and a one-per-`host.framecount` latch, because
`COM_NewGame` / `COM_LoadLevel` / `COM_LoadGame` call `CL_Disconnect()`
themselves when no server is running and one transition would otherwise log
twice.

Four call sites, all of them "this is a new session":

| Site | Covers |
| --- | --- |
| `COM_LoadLevel()` (`engine/common/host_state.c`) | `map <name>`, `map_background`, `restart`, `reload`, `nextmap` |
| `COM_NewGame()` | `newgame`, `hazardcourse`, the menu's New Game |
| `COM_LoadGame()` | `load <save>`, `quickload`, and every other route through `SV_LoadGame` |
| `CL_Disconnect()` (`engine/client/cl_main.c`) | the `disconnect` command, quit to menu, the unified UI's menu-map redirect sequence |

The three `COM_*` funnels are used rather than the individual console command
handlers because every route - console, cfg, alias, stufftext, the menu library,
the redirect - converges on them.

## The deliberate exception: `changelevel`

`COM_ChangeLevel()` is **not** hooked. Cry of Fear carries a track across an
in-game level transition on purpose (the train ride, the sewer and subway
chains); stopping the music there would be a regression, not a fix. The apply
script asserts that `COM_ChangeLevel` contains no `CL_CoF_StopMP3` call after
the patch, so the exception cannot be lost to a later edit.

## Cvar and log

| Cvar | Default | Flags | Meaning |
| --- | --- | --- | --- |
| `cof_mp3_stop_on_map` | `1` | none (deliberately not `FCVAR_ARCHIVE`, like the rest of the `cof_*` family) | run `stopmp3` before a fresh map, newgame, save load or disconnect |

One developer-level line per stop:

```
[cof-mp3] stopmp3 before map
[cof-mp3] stopmp3 before newgame
[cof-mp3] stopmp3 before load
[cof-mp3] stopmp3 before disconnect
```

## Validation

Fixture `stage1/ui-m1-engine-fixture-20260921`, wrapper
`run-textscale-case.ps1`, case cfgs `mp3case1.cfg`, `mp3case2.cfg`,
`mp3case3.cfg` and the new `maps/c_intro_load.cfg` hook. No keyboard or mouse
injection, no `SetForegroundWindow`, no retry; windowed 1280x720, `+volume 0`.
Engine `96F0BA9CCEE3CA36FB1F125BA8C07416F24AFF94C500A4225066299F0EB92C17`.

| Run | Decisive lines |
| --- | --- |
| `m1-bg-to-map` | background map with the menu track, then `map c_forest3`: `[cof-mp3] stopmp3 before map` then `Spawn Server: c_forest3` - in that order, and again for the background map itself at boot |
| `m2-load-to-map` | `+load cofsave1` gives `[cof-mp3] stopmp3 before load` then `Spawn Server: c_forest3`; then `map c_intro` gives `[cof-mp3] stopmp3 before map` then `Spawn Server: c_intro` |
| `m3-changelevel` | the control: `changelevel c_forest3` from inside the game produces `Spawn Server: c_forest3 []` with **no** `[cof-mp3]` line between `COFMP3_CHANGELEVEL` and it |

Whether the sound actually stopped cannot be observed from a log - the MP3
module has no logging of any kind and writes nothing to `paranoia_log.txt` - so
the runs prove the command is issued at the right moment and the changelevel
exception holds. **Marked for the user's manual test:** that the menu track
really stops when a save is loaded, and that it really keeps playing across an
in-game `changelevel` (the train ride is the obvious case).

## Applying

After the unified UI menu-map redirect and the death flow, whose `cl_main.c` and
`common.h` lines this patch uses as hunk context:

```powershell
pwsh -File .\scripts\apply-cof-mp3-stop-on-map.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

The script refuses a tree that already carries it, checks both prerequisites by
marker, verifies concrete markers in all three touched files, asserts the
`COM_ChangeLevel` exception, and reverse-checks the patch. Verified 2026-09-22
on `cof-fix/pristine-ui-m1-scratch` and on a fresh copy of
`cof-fix/pristine-clean` with the whole engine stack applied in order.
