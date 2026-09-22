# Cheats in Cry of Fear: Enhanced

Cry of Fear 1.6 shipped with its cheats removed. Cry of Fear: Enhanced brings
them back in the engine, so your game files stay exactly as Steam installed
them. This page lists every cheat, how to switch it on and what to watch out
for. The technical details (offsets, how the game is checked, test results)
are in [docs/design/cheats.md](docs/design/cheats.md).

## Turning cheats on

1. Enable the console: **Options > Game > Enable console**. Open it with the
   `~` key.
2. Load a game first. Cheats need a running level; they do nothing on the main
   menu.
3. Type `sv_cheats 1` and press Enter.
4. Type the cheat, for example `noclip`.

`sv_cheats 0` switches every toggle (see below) off again.

Type `cof_cheats` at any time to see which cheats are on and whether your game
was recognised.

**The Cry of Fear cheats (everything starting with `cof_`, plus `fly`, `give`
and the sticky `noclip` / `notarget`) only work with the original Cry of Fear
1.6 game files.** The engine checks the game's `hl.dll` before touching
anything. If it is a different version or a mod, those commands print one line
saying so and do nothing, and `noclip`, `notarget` and `give` behave as they do
in any other Xash3D game.

Words used below:

- **toggle** - stays on until you switch it off (`0`), `sv_cheats 0`, or you
  quit the game. Toggles keep working after a level change and after loading
  any save, even one made before you turned the cheat on.
- **one-shot** - does its thing once. The change is part of your game and is
  saved with it.

## Movement

### `noclip`

Fly through walls, floors and ceilings: you move wherever you look. Type it
again (or `noclip 0`) to walk normally. **Toggle.** If you switch it off
inside a wall or high in the air you may be stuck there; switch it back on and
move somewhere open first.

In the original 1.6 game noclip switched itself off on the very next frame;
here it stays on. While you are on a ladder, in a cutscene or dead, the game
keeps control and noclip comes back as soon as it lets go.

### `fly`

Like noclip, but you still bump into walls - you just float and ignore
gravity. `fly` again (or `fly 0`) to land. **Toggle.** `fly` and `noclip`
switch each other off.

## Staying alive

### `cof_nodamage 1` / `cof_nodamage 0`

You take no damage - monsters, bullets, explosions, falls. **Toggle.**
Single player only.

Things to know:

- It works by telling the game you are "going through a door" all the time.
  While it is on, the effect that plays when the Stranger is near you does not
  happen.
- `kill` still kills you.
- In coop it refuses to switch on, because the game would make you invisible
  to the other players.

### `notarget`

Monsters do not notice you. `notarget` again (or `notarget 0`) to switch it
off. **Toggle.** The original game dropped notarget at doors, ladders,
cutscenes and level changes; here it stays on.

### `cof_nodrown 1` / `cof_nodrown 0`

You never run out of air under water. **Toggle.**

### `god`

Does **nothing** in Cry of Fear: the game never checks it. Use
`cof_nodamage 1` instead.

### `kill`

Kills you, even with `cof_nodamage` on.

## Weapons and items

### `cof_infammo 1` / `cof_infammo 0`

Infinite ammo: your magazine never empties, so you never reload. Also covers
syringes and flares. **Toggle.**

Saves made while it is on keep infinite ammo when you load them later, even
after restarting the game. Type `cof_infammo 0` to take it out of that save.

### `give <item>`

Puts an item straight into your inventory, with the normal pickup message.
**One-shot.** Only `weapon_...`, `ammo_...` and `item_...` names are accepted;
a name the game does not know prints `no such entity`.

**Weapons and tools** (`give weapon_<name>`):

| | | | |
|---|---|---|---|
| `branch` | `browning` | `camera` | `famas` |
| `flare` | `flashlight` | `g43` | `glock` |
| `lantern` | `m16` | `m76` | `mobile` |
| `mp5` | `nightstick` | `p345` | `radio` |
| `revolver` | `rifle` | `shotgun` | `sledgehammer` |
| `sledgeshovel` | `switchblade` | `syringe` | `tmp` |
| `vp70` | | | |

**Ammo** (`give ammo_<name>`): `glock`, `g43`, `m16`, `revolver`, `rifle`,
`shells`, `tmp`.

Examples:

```
give weapon_glock
give ammo_glock
give weapon_shotgun
give ammo_shells
give weapon_syringe
```

If you already carry the item, your inventory is full, or the game does not
let you have it (the donator-only TMP and the mappers-only MP5 still check who
you are), it is left on the floor at your feet and the console says so. The
first time you give yourself something the level never had, the console may
print a "late precache" warning; that is harmless.

### `ent_create <name>`

The engine's own entity spawner. It can create anything, not only items, and
drops it in front of you instead of into your inventory. It needs a second
switch: `sv_enttools_enable 1`. Spawning monsters or level entities this way
can crash the game; `give` is the safe way to get items.

## Night vision

### `cof_nightvision 1` / `cof_nightvision 0`

Puts the night-vision goggles on or takes them off, even if you have not
unlocked them. **One-shot.** The goggles animation plays first; if you type
the command again while it is still playing, you are told to try again.
`cof_nightvision` on its own switches between on and off.

## Stamina

### `cof_infstamina 1` / `cof_infstamina 0`

Sprinting, dodging and jumping never tire you. **Toggle.** Like infinite ammo,
it stays in a save made while it is on; `cof_infstamina 0` removes it.

## Story and saving

### `cof_ending <1-5>`

Chooses which of the five endings you get. **One-shot, saved with your game.**
It must be set **before** you use the ending door in Simon's house; it sets
which ending that door plays. Anything else the story asks of you on the way
there still has to be done.

### `cof_tapes <number>`

Sets how many saves are left on your current cassette in Nightmare mode, for
example `cof_tapes 99`. **One-shot, saved with your game.** You still need a
cassette tape in your inventory to use the tape recorder.

### `cof_unlockdoors`

Unlocks every locked door on the current level, no key needed. **One-shot,
for this level only** - run it again after a level change.

Be careful: some doors do something when they are unlocked with their key
(switch on a light, start a scene, count towards a puzzle). Doors opened with
this cheat skip that, which can leave a level in a state the story did not
expect. Padlocks, keypads and "use item" puzzles are not affected.

### `save <name>` / `load <name>`

Save and load under any name you like, anywhere, for example `save before_boss`
and later `load before_boss`. These are ordinary engine commands and need no
cheats.

### `skillset <number>`

The game's own difficulty command - the same one the New Game page sends. It
changes the `difficulty` setting. From the menu it starts a new campaign, so
do not use it in the middle of a game unless that is what you want.

## Old developer impulses

The game still contains some of its developers' debug commands, typed as
`impulse <number>`. They work without `sv_cheats` and are refused on the menu
maps. We found these by reading the game's code; they are the original
developers' tools, not something we tested or support:

| command | what it does |
| --- | --- |
| `impulse 105` | makes you silent / audible to monsters |
| `impulse 106` | prints information about the entity you are looking at |
| `impulse 107` | prints the name of the texture you are looking at |
| `impulse 103` | reports on the monster you are looking at |
| `impulse 100` | prints the class name of what you are looking at |

`impulse 101` (the classic "give everything") does nothing in Cry of Fear.

## Quick reference

| command | kind | needs `sv_cheats 1` | original 1.6 game only |
| --- | --- | --- | --- |
| `noclip` | toggle | yes | sticky version yes, otherwise stock |
| `fly` | toggle | yes | yes |
| `notarget` | toggle | yes | sticky version yes, otherwise stock |
| `god` | does nothing in CoF | yes | - |
| `kill` | one-shot | no | no |
| `give <item>` | one-shot | yes | yes |
| `ent_create <name>` | one-shot | `sv_enttools_enable 1` | no |
| `cof_infammo 0/1` | toggle | yes | yes |
| `cof_infstamina 0/1` | toggle | yes | yes |
| `cof_nodamage 0/1` | toggle, single player | yes | yes |
| `cof_nodrown 0/1` | toggle | yes | yes |
| `cof_nightvision 0/1` | one-shot | yes | yes |
| `cof_ending 1-5` | one-shot, saved | yes | yes |
| `cof_tapes <n>` | one-shot, saved | yes | yes |
| `cof_unlockdoors` | one-shot, this level | yes | yes |
| `cof_cheats` | status | no | - |
| `save` / `load <name>` | - | no | no |
| `skillset <n>` | - | no | no |
