# Licence note: Polish language pack

**This folder is not covered by the project's GNU GPL.** The repository's
`LICENSE` applies to the project's code; it does not apply to anything in
`languages/polish/`.

## What this pack is

The files in this folder are a translation of Team Psykskallar's Cry of
Fear text (subtitles, notes, hints, inventory descriptions and the game
DLLs' interface strings) and the translators' repainted versions of the
game's signage. The pack holds only what the translators authored:

- translated text files and string tables;
- **entity patches** (`maps/*.entpatch`): just the key/value pairs the
  translators changed in each map (the in-world text), which the engine
  applies to the map's own entity data when the map loads. No map and no
  complete entity list is shipped;
- repainted **world sign and poster textures** (`textures/`);
- repainted **textures of studio models** (`models/<model>/<texture>.bmp`:
  phone screens, newspapers, book pages, signs), which the engine swaps into
  the game's own model when it loads it. No model file is shipped;
- repainted **interface images** (`overlay/`: menus, notes, item cards).

Nothing in the pack is byte-identical to a game file, and images whose
pixels equal the game's are left out (the generators check both). The
selectors in the entity patches (entity class names, target names, model
numbers and origins) and the CRC-32 of each replaced value are the minimum
needed to find the right entity; they are identifiers, not content.

It is derived from Cry of Fear, whose text, textures and models belong to
Team Psykskallar, and from the fan translation **Cry of Fear:
Spolszczenie**
(<https://steamcommunity.com/sharedfiles/filedetails/?id=3164091802>).

## Who made it

The translation is the work of the Spolszczenie authors credited in
[`README.md`](README.md#creators): **Avioo** (translation, graphics,
testing), **Mixdedemon** (translation), **hexag0n** (technical work,
testing) and **Izonka** (testing). It was contributed to Cry of Fear:
Enhanced with their permission (received 2026-09-22), re-derived into this
pack's format by the project's scripts as `README.md` describes.

The exception is `strings/menu-strings.tsv`, which translates the project's
own menu (text written by the project) and was drafted by the project; see
`README.md`.

## Terms

- The pack is distributed free of charge, as part of Cry of Fear:
  Enhanced, **only for use with a legally owned copy of Cry of Fear**. It
  is useless without the game and does not replace it.
- It is game-derived data, not software, and it is not offered under the
  GPL or any other open licence. The translators' work remains theirs, and
  the underlying game content remains Team Psykskallar's.
- Do not sell it, and do not redistribute it separately from Cry of
  Fear: Enhanced without the translators' permission.
- If Team Psykskallar or the translators ask for any part of it to be
  removed, the project will remove it.

Keep this note and `README.md` (with its credits) with every copy of the
pack.
