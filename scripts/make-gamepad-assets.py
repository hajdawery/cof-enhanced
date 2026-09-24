#!/usr/bin/env python3
"""Build gamedata/cryoffear/gfx/shell/gamepad/ from Zacksly's "Xbox Series
Button Icons and Controls" and "PS5 Button Icons and Controls" (CC BY 3.0,
https://zacksly.itch.io), for the menu's Gamepad controls page
(patches/cof-mainui-options-layout.patch, docs/design/ui-theme.md).

    python scripts/make-gamepad-assets.py --src "K:/LLM/COF_Fix/Prompts" [--out gamedata/cryoffear/gfx/shell/gamepad]

What it writes, and nothing else:
  * the 16 button icons per pad, "Buttons Full Solid/White/128w", copied
    byte for byte (only renamed to lower-case file names);
  * one controller picture per pad, "Controller Images/Outline/Outline White
    4k.png", cropped to its drawing plus a 40 px margin and resized to
    1024 px wide (Lanczos) - the only modified files;
  * LICENSE-Zacksly.txt: both packs' LICENSE.txt, verbatim.
icons.txt (the key -> icon table) is hand-written and not touched.
Needs Pillow. The output is deterministic for the same source files.
"""
import argparse
import os
import shutil

from PIL import Image

PACKS = {
    'xbox': 'Xbox Series Button Icons and Controls',
    'ps5': 'PS5 Button Icons and Controls',
}

# engine key -> (xbox source, xbox file, ps5 source, ps5 file)
ICONS = [
    ('A_BUTTON', 'A', 'a', 'Cross', 'cross'),
    ('B_BUTTON', 'B', 'b', 'Circle', 'circle'),
    ('X_BUTTON', 'X', 'x', 'Square', 'square'),
    ('Y_BUTTON', 'Y', 'y', 'Triangle', 'triangle'),
    ('L1_BUTTON', 'Left Bumper', 'lb', 'L1', 'l1'),
    ('R1_BUTTON', 'Right Bumper', 'rb', 'R1', 'r1'),
    ('LTRIGGER', 'Left Trigger', 'lt', 'L2', 'l2'),
    ('RTRIGGER', 'Right Trigger', 'rt', 'R2', 'r2'),
    ('STICK1', 'Left Stick Click', 'ls', 'Left Stick Click', 'l3'),
    ('STICK2', 'Right Stick Click', 'rs', 'Right Stick Click', 'r3'),
    ('DPAD_UP', 'D-Pad Up', 'dpad_up', 'D-Pad Up', 'dpad_up'),
    ('DPAD_DOWN', 'D-Pad Down', 'dpad_down', 'D-Pad Down', 'dpad_down'),
    ('DPAD_LEFT', 'D-Pad Left', 'dpad_left', 'D-Pad Left', 'dpad_left'),
    ('DPAD_RIGHT', 'D-Pad Right', 'dpad_right', 'D-Pad Right', 'dpad_right'),
    ('START', 'Menu', 'menu', 'Options', 'options'),
    ('BACK', 'View', 'view', 'Create', 'create'),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--src', required=True, help='folder holding the two Zacksly packs')
    here = os.path.dirname(os.path.abspath(__file__))
    ap.add_argument('--out', default=os.path.join(here, '..', 'gamedata', 'cryoffear', 'gfx', 'shell', 'gamepad'))
    a = ap.parse_args()

    for pad, folder in PACKS.items():
        src = os.path.join(a.src, folder)
        dst = os.path.join(a.out, pad)
        os.makedirs(dst, exist_ok=True)
        for row in ICONS:
            name, out = (row[1], row[2]) if pad == 'xbox' else (row[3], row[4])
            shutil.copyfile(os.path.join(src, 'Buttons Full Solid', 'White', '128w', name + '.png'),
                            os.path.join(dst, out + '.png'))
        im = Image.open(os.path.join(src, 'Controller Images', 'Outline', 'Outline White 4k.png')).convert('RGBA')
        l, t, r, b = im.getchannel('A').getbbox()
        m = 40
        im = im.crop((l - m, t - m, r + m, b + m))
        w = 1024
        h = round(im.size[1] * w / im.size[0])
        im.resize((w, h), Image.LANCZOS).save(os.path.join(dst, 'controller.png'), optimize=True)
        print(pad, 'controller.png', (w, h))

    with open(os.path.join(a.out, 'LICENSE-Zacksly.txt'), 'wb') as f:
        for pad, folder in PACKS.items():
            f.write(('=' * 78 + '\n' + folder + '/LICENSE.txt\n' + '=' * 78 + '\n\n').encode())
            f.write(open(os.path.join(a.src, folder, 'LICENSE.txt'), 'rb').read())
            f.write(b'\n\n')
    print('wrote', os.path.normpath(a.out))


if __name__ == '__main__':
    main()
