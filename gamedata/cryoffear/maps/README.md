# `maps/c_game_menu1.ent`

This entity-lump override is **generated, not stored here.** It is a verbatim
copy of the entity lump of the shipped `c_game_menu1.bsp` with one entity
removed, so it is game data; the repository intentionally contains no game
files (see the top-level README), and `.gitignore` in this folder keeps the
generated file out of commits.

Generate it against a read-only game copy:

```powershell
python .\scripts\make-cof-ent-override.py `
  "K:\LLM\COF_Fix\Cry of Fear\cryoffear\maps\c_game_menu1.bsp" `
  "<runtime>\cryoffear\maps\c_game_menu1.ent" `
  cof_gamemenu
```

The script reads lump 0 of the BSP, drops every entity whose `classname`
matches an argument, writes the rest unchanged, and stamps the output with the
current time — the engine ignores an entity patch older than its BSP
(`engine/common/mod_bmodel.c:2318-2329`).

For `c_game_menu1` the result is 127 entities in, 126 out; the only entity
removed is

```
{
"origin" "-3526 -515 -63"
"angles" "0 0 0"
"classname" "cof_gamemenu"
}
```

`cof_gamemenu` is the server entity that drives Cry of Fear's own client-side
VGUI main-menu panel (`CCofGameMenu` in `cryoffear/cl_dlls/hl.dll`, which sends
the `GameMenu` user message that `client.dll` hooks). Removing it leaves the
map, its camera track, models, rain/snow and ambient audio untouched.

The override must live in a **real** `maps` directory in the runtime, beside
the BSPs. If a fixture links the canonical `maps` folder as a junction, the
engine's node-graph writes would land in the canonical tree.
