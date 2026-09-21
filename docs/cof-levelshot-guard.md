# Levelshot NULL-world guard (`CL_LevelShot_f`)

A crash, not a feature. Packaged separately from the styled console so it can be
taken on its own.

## The crash

Typing `newgame` at the console while the menu background map is running ends
the server. `SV_NewGame_f` runs from the same command buffer as the queued
`levelshot` the next level load posts, so by the time `CL_LevelShot_f` executes
there is no world: `cl.worldmodel` is `NULL`. The function reaches

```c
ft1 = FS_FileTime( cl.worldmodel->name, false );
```

and `name` is the first member of `model_t`, so `cl.worldmodel->name` evaluates
to the null pointer rather than faulting on the spot. The null path travels
through `FS_FileTime` -> `FS_FindFile` -> `FS_FindFile_DIR` and is dereferenced
in `FS_FixFileCase` (`filesystem/dir.c:294`).

Measured stack, from
`stage1/ui-m1-menu-fixture-20260921/evidence/m2-startmap.log`:

```
Crash: address 5496E072, code C0000005
Exception: dir.c:294:0
 0: FS_FixFileCase (dir.c:294:0)
 1: FS_FindFile_DIR (dir.c:395:39)
 2: FS_FindFile (searchpath.c:827:18)
 3: FS_FileTime (io.c:932:29)
 4: CL_LevelShot_f (cl_cmds.c:322:0)
 5: Cmd_ExecuteStringWithPrivilegeCheck
 ...
 8: Host_ClientBegin (cl_main.c:3925:0)
```

## The fix

`patches/cof-levelshot-guard.patch` adds two early returns to
`CL_LevelShot_f` (`engine/client/cl_cmds.c`):

* the map branch bails when `cl.worldmodel` is NULL, when its `name` is empty,
  or when `clgame.mapname` is empty, sets `cls.scrshot_action =
  scrshot_inactive` and reports
  `CL_LevelShot_f: no world loaded, skipping the levelshot` at developer level;
* the demo branch bails the same way on an empty `cls.demoname`, which is the
  only other string that reaches `FS_FileTime` from here.

No cvar: there is no reason to want the old behaviour. Nothing else in the
screenshot path changes; a levelshot with a world present behaves exactly as
before.

## Verification

Fixture `stage1/ui-m1-engine-fixture-20260921`, driver
`run-vidmode-cfg-case.ps1`, case cfg `root/cryoffear/lscase1.cfg` plus the load
hook `root/cryoffear/maps/c_difficulty_settings_load.cfg`. Windowed, 1280x720,
`+volume 0`, no injected input of any kind. Engine
`build-cof-ui-m1-engine-20260921/engine/xash.dll` SHA-256
`1B80EF3769479C1ACEB3EC415837BF17581B7CC6730E7DE7BC2D3FE83AE5B0AD`.

The case boots to the background map, screenshots it, then runs `newgame`.

Run `ls1-newgame-bgmap`, log SHA-256
`790367945F1323AB79AD62E614ABA145EBC84AC2E4A148316127C7E8756E3E91`:

```
677: Spawn Server: c_game_menu1
899: Host_EndGame: The End
903: CL_LevelShot_f: no world loaded, skipping the levelshot
906: Host_EndGame: The End
909: Spawn Server: c_difficulty_settings
```

No crash, no `Exception:` line, engine exited by itself with code 0 after 7.0 s,
and the `gameinfo.txt` `startmap` (`c_difficulty_settings` in this game folder,
not `c_intro`) loaded. Screenshots
`evidence/ls1-newgame-bgmap-a.png` SHA-256
`285F56CFE4A7A962FCA7DCC0D1B5E5FB6743AACEDD967EC8BF23B769D0AB5BA3` (background
map before the command) and `evidence/ls1-newgame-bgmap-b.png` SHA-256
`D2805DB5F4A38034319F45B7C5AE35AFBB82EE7F22803A9FEDCE45E0F17B05D7` (the new map
up afterwards).

The canonical tree was manifested before and after and is unchanged
(`evidence/canonical-console-before.txt`, `evidence/canonical-console-after.txt`).

## Limits

* Only the two paths inside `CL_LevelShot_f` are guarded. Other queued
  screenshot kinds (`saveshot`, `envshot`) were not audited for the same
  lifetime problem.
* The underlying `FS_FixFileCase` NULL dereference is still there; this patch
  stops one caller reaching it, it does not harden the filesystem.

## Applying

Order-independent; it shares no hunk context with any other patch in the stack.

```powershell
pwsh -File .\scripts\apply-cof-levelshot-guard.ps1 -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

The script validates the source location, refuses an already-patched tree,
refuses a tree whose `CL_LevelShot_f` does not have the unguarded
`cl.worldmodel->name` read, verifies markers afterwards, and reverse-checks the
result. Verified on 2026-09-21 against a scratch copy of
`cof-fix\pristine-ui-m1-scratch`.
