# Gamepad button art: who made what

This folder holds the button pictures of the menu's Gamepad tab and button
prompts (`icons.txt` says which picture belongs to which button and style).

## `xbox/` and `ps5/`

Zacksly's "Xbox Series Button Icons and Controls" and "PS5 Button Icons and
Controls" (https://zacksly.itch.io), licensed under Creative Commons
Attribution 3.0 Unported (CC BY 3.0). The button icons are copied unchanged;
the two `controller.png` pictures were cropped, resized, and had the platform
logos removed by haej. The packs' own licence files are in
`LICENSE-Zacksly.txt`; the full licence text is in the repository's
`licenses/zacksly-CC-BY-3.0.txt`.

## `switch/` and `steamdeck/`

Made by haej for Cry of Fear: Enhanced (2026), some derived from Zacksly's CC
BY 3.0 icons above:

* `switch/ls.png` and `switch/rs.png` are Zacksly's "Left Stick Click" and
  "Right Stick Click" (Xbox pack, "Buttons Solid", white, 512 px), **resized
  to 128 px** - modified from the original.
* The shoulder, trigger and grip buttons (`switch/l.png`, `r.png`, `zl.png`,
  `zr.png`; `steamdeck/l1.png`-`l5.png`, `r1.png`-`r5.png`, `steam.png`,
  `quick_access.png`) are haej's drawings in the style of Zacksly's button
  shapes (derived work, modified: new labels and shapes).
* The d-pad and +/- buttons and the two controller pictures
  (`switch/controller.png`, the Joy-Con pair; `steamdeck/controller.png`, the
  Steam Deck) are haej's own drawings.

Every file here was resized from haej's 512 px (buttons) and 1254 / 1672 px
(pictures) originals by `scripts/make-gamepad-style-art.py` (buttons to
128 x 128, pictures cropped to the drawing plus a 40 px margin and resized to
1024 px wide).

Buttons these two styles have no picture of use the Xbox icons from `xbox/`
(the face buttons A/B/X/Y, and the Steam Deck's d-pad, View and Menu), under
the Zacksly licence above.

Nintendo Switch, Joy-Con, Steam and Steam Deck are trademarks of their
owners; the pictures only show which button to press and imply no
endorsement.
