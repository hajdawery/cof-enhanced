# Game-directory overlay files

Everything under `gamedata/` is **not** engine or menu source. These are small
text files — plus, since UI milestone 3a, three font files — that belong in the
Cry of Fear *game directory* (`cryoffear/`) of a runtime, beside the shipped
assets. They change engine and MainUI behaviour through data only: no binary is
patched and no game file is modified.

Copy the tree over a runtime's game folder, keeping the paths:

```
gamedata/cryoffear/scripts/chapterbackgrounds.txt  ->  <runtime>/cryoffear/scripts/chapterbackgrounds.txt
gamedata/cryoffear/gameinfo.keys                   ->  merge into <runtime>/cryoffear/gameinfo.txt
gamedata/cryoffear/maps/c_game_menu1.ent           ->  generate locally, see maps/README.md
gamedata/cryoffear/gfx/fonts/Inter-*.ttf           ->  <runtime>/cryoffear/gfx/fonts/
gamedata/cryoffear/gfx/fonts/OFL.txt               ->  <runtime>/cryoffear/gfx/fonts/
```

Nothing here may be copied into `K:\LLM\COF_Fix\Cry of Fear`, which is the
read-only canonical game copy.

| File | What it does | Measured reference |
| --- | --- | --- |
| `cryoffear/scripts/chapterbackgrounds.txt` | Names `c_game_menu1` as the menu background map, so the engine menu starts `map_background c_game_menu1` on its first draw and paints over the live, animating scene. | `3rdparty/mainui/BaseMenu.cpp:970-994` (parse), `:547-583` (`UI_StartBackGroundMap`), `engine/server/sv_cmds.c:260-295` (`map_background`) |
| `cryoffear/gameinfo.keys` | The `gameinfo.txt` keys the UI milestones need: `render_picbutton_text` and `startmap`. Milestone 2 changed `startmap` from `c_difficulty_settings` to `c_intro` and dropped `noskills`, because the engine menu now has its own difficulty page. | `filesystem/gameinfo.c:352-444`, `engine/client/dll_int/cl_gameui.c:376-406` |
| `cryoffear/gfx/fonts/Inter-Regular.ttf`, `-Medium.ttf`, `-SemiBold.ttf` | The Source-style theme's type. MainUI's stb_truetype backend reads them through `CFontManager::FindFontDataFile`, which picks the face from the requested weight. Licensed under the SIL Open Font License 1.1; `OFL.txt` next to them is the upstream Inter licence file. Font binaries are game data and are not committed. | `3rdparty/mainui/font/FontManager.cpp` (`FindFontDataFile`, `LoadFontDataFile`), `font/StbFont.cpp:49-100` |
| `cryoffear/maps/c_game_menu1.ent` | Entity-lump override for the menu map with the `cof_gamemenu` entity removed, which stops Cry of Fear's own client VGUI menu panel from drawing over the engine menu. Derived from the shipped BSP, so it is generated locally and never committed. | `engine/common/mod_bmodel.c:2304-2345` |

See [docs/cof-ui-m1-plumbing.md](../docs/cof-ui-m1-plumbing.md),
[docs/cof-ui-m2-cof-menu.md](../docs/cof-ui-m2-cof-menu.md) and
[docs/cof-ui-m3-theme.md](../docs/cof-ui-m3-theme.md) for what each one was
verified to do and for the evidence.
