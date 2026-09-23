# Contributing

Thanks for wanting to help. Bug reports, translations, testing on other setups
and patches are all welcome.

## Reporting a bug

Open an issue at <https://github.com/hajdawery/cof-enhanced/issues> with:

* the version line from the top-right corner of the main menu
  (`cofenhanced <version> (<milestone>, <commit>)`);
* your resolution, window mode and HUD scale, and the language if it is not
  English;
* what you did, what you expected, what happened, and a screenshot if it is
  visual;
* for a crash or a hang, what you were doing in the seconds before it.

Please check that the same thing does not happen in the original game first
if you can; some oddities are Cry of Fear's own.

## Changing code

Read [docs/README.md](docs/README.md) first, then
[building](docs/dev/building.md), [the patch stack](docs/dev/patch-stack.md)
and [testing](docs/dev/testing.md). In short:

* This repository holds **patches** against pinned upstream sources, not
  source trees. A change to the engine, the renderer, FreeVGUI or MainUI is a
  new or regenerated `patches/*.patch` plus its `scripts/apply-*.ps1`, which
  must check its prerequisites and its own markers and reverse-check the result.
* A regenerated patch keeps its place in the stack and is regenerated against
  the tree as it stands at that step. Finish with a stack verification on a
  fresh tree.
* Every behaviour change gets a cvar that restores the stock path, and a page
  under `docs/patches/` (or `docs/design/`) that says what was measured, how,
  and what was not.
* Never commit game files, Steam files, binaries, PDBs, dumps, saves or
  screenshots. The only game-derived data allowed is translation packs, and
  only translator-authored content (see [LICENSING.md](LICENSING.md)).
* Follow the launch rules in [testing](docs/dev/testing.md): `+volume 0`, no
  input injection, never kill game processes by name.

## Translations

A language pack is data, not code: a folder under `languages/<code>/` with a
`manifest.txt`, a `MANIFEST.tsv`, a `README.md` naming its creators and
sources, and at least `strings/menu-strings.tsv` for the menu. The format and a
step-by-step template are in [languages/README.md](languages/README.md).
Review of the machine-drafted menu translations (German, Spanish, French,
Dutch, Norwegian, Swedish and Polish) by native speakers is especially welcome.

## Licensing of contributions (Developer Certificate of Origin)

By contributing you agree to the
[Developer Certificate of Origin 1.1](https://developercertificate.org/):
you certify that you wrote the contribution, or otherwise have the right to
submit it under the licence below. Sign off every commit to say so:

```
git commit -s -m "..."
# adds: Signed-off-by: Your Name <you@example.com>
```

Your contribution is licensed under the same terms as the part of the
repository it changes:

| What you change | Licence of your contribution |
| --- | --- |
| engine, renderer and MainUI patch hunks, new engine/MainUI files, scripts, launcher, tests, docs | **GPL-3.0-or-later** |
| hunks against `3rdparty/freevgui/` and new FreeVGUI files | **BSD-3-Clause** (FreeVGUI's own licence); new files carry `SPDX-License-Identifier: BSD-3-Clause` |
| translations in `languages/<code>/` | pack content, not GPL: distributed free of charge with Cry of Fear: Enhanced for use with a legally owned copy of Cry of Fear, credited in the pack's `README.md` (see `languages/polish/LICENSE-NOTE.md` for the terms) |
| fonts | only unmodified OFL fonts, or atlases generated from them, with `OFL.txt` beside them |

New source files should start with a copyright line
`Copyright (C) <year> <your name> (Cry of Fear: Enhanced contributors)` and
the licence notice of the file's kind. Do not submit anything taken from Cry
of Fear, from Valve, or from other mods, and nothing you are not allowed to
share. Cry of Fear: Enhanced is distributed free of charge only (see
LICENSING.md section 5); contributions are accepted on that basis.
