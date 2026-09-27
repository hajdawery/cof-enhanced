#!/usr/bin/env python3
"""Build the Nintendo Switch and Steam Deck button art under
gamedata/cryoffear/gfx/shell/gamepad/switch/ and steamdeck/ from the prompt art
haej supplied (K:/LLM/COF_Fix/Prompts/"Nintendo Switch" and "Steam Deck"; some
of those icons are derived from Zacksly's CC BY 3.0 "Button Icons and
Controls", see gfx/shell/gamepad/LICENSE-NOTE.md), for the menu's Gamepad tab
and button prompts (the style ids "switch" and "steamdeck" of icons.txt).

    python scripts/make-gamepad-style-art.py --src "K:/LLM/COF_Fix/Prompts" [--out gamedata/cryoffear/gfx/shell/gamepad]

What it writes, and nothing else:
  * the button icons the two styles use, resized from 512x512 to 128x128 like
    the Xbox and PlayStation ones (premultiplied alpha, Lanczos), renamed to
    lower-case file names;
  * one controller picture per style, the silhouette cropped to its drawing
    plus a 40 px margin and resized to 1024 px wide (Lanczos, premultiplied),
    the recipe of scripts/make-gamepad-assets.py.
Buttons a style has no picture of use the Xbox icon (icons.txt says which);
icons.txt and LICENSE-NOTE.md are hand-written and not touched. Needs Pillow.
The output is deterministic for the same source files.
"""
import argparse
import os

from PIL import Image

STYLES = {
    'switch': ('Nintendo Switch', 'two joycons silouhette.png', [
        ('L.png', 'l.png'), ('R.png', 'r.png'), ('ZL.png', 'zl.png'), ('zr.png', 'zr.png'),
        ('Left Stick Click.png', 'ls.png'), ('Right Stick Click.png', 'rs.png'),
        ('dpad up.png', 'dpad_up.png'), ('dpad down.png', 'dpad_down.png'),
        ('dpad left.png', 'dpad_left.png'), ('dpadright.png', 'dpad_right.png'),
        ('+ button.png', 'plus.png'), ('- button.png', 'minus.png'),
    ]),
    'steamdeck': ('Steam Deck', 'steam deck silhouette.png', [
        ('L1.png', 'l1.png'), ('R1.png', 'r1.png'), ('L2.png', 'l2.png'), ('R2.png', 'r2.png'),
        ('L3.png', 'l3.png'), ('R3.png', 'r3.png'),
        ('L4.png', 'l4.png'), ('L5.png', 'l5.png'), ('R4.png', 'r4.png'), ('R5.png', 'r5.png'),
        ('STEAM button.png', 'steam.png'), ('three dots.png', 'quick_access.png'),
    ]),
}


def resize_premultiplied(im, size):
    """Lanczos on premultiplied RGBA, so no dark or light fringe appears where
    the icon meets its transparent surroundings."""
    im = im.convert('RGBA')
    pm = im.convert('RGBa').resize(size, Image.LANCZOS)
    return pm.convert('RGBA')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--src', required=True, help='folder holding "Nintendo Switch" and "Steam Deck"')
    here = os.path.dirname(os.path.abspath(__file__))
    ap.add_argument('--out', default=os.path.join(here, '..', 'gamedata', 'cryoffear', 'gfx', 'shell', 'gamepad'))
    a = ap.parse_args()

    for style, (folder, silhouette, icons) in STYLES.items():
        src = os.path.join(a.src, folder)
        dst = os.path.join(a.out, style)
        os.makedirs(dst, exist_ok=True)
        for name, out in icons:
            im = Image.open(os.path.join(src, name))
            resize_premultiplied(im, (128, 128)).save(os.path.join(dst, out), optimize=True)
        im = Image.open(os.path.join(src, silhouette)).convert('RGBA')
        l, t, r, b = im.getchannel('A').getbbox()
        m = 40
        im = im.crop((l - m, t - m, r + m, b + m))
        w = 1024
        h = round(im.size[1] * w / im.size[0])
        resize_premultiplied(im, (w, h)).save(os.path.join(dst, 'controller.png'), optimize=True)
        print(style, len(icons), 'icons, controller.png', (w, h), 'crop', (l - m, t - m, r + m, b + m))
    print('wrote', os.path.normpath(a.out))


if __name__ == '__main__':
    main()
