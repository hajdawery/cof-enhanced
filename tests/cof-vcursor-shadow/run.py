#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 haej (Cry of Fear: Enhanced contributors)
"""Run in an MSVC developer shell; extracts the real cursor loader, stubs an
upload which overwrites its input, and compares captured art/shadow pixels.
No game launch, renderer build or image modification. Needs Pillow.
"""
import argparse
import pathlib
import subprocess
from PIL import Image

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--source-root', required=True, type=pathlib.Path)
p.add_argument('--out', required=True, type=pathlib.Path)
a = p.parse_args()
a.out.mkdir(parents=True, exist_ok=True)
repo = pathlib.Path(__file__).resolve().parents[2]
source = (a.source_root / 'engine/client/input/cof_gamepad.c').read_text()
start = source.index('static int CL_CoF_VCursorArt(')
end = source.index('\n/*', start)
function = source[start:end]
im = Image.open(repo / 'gamedata/cryoffear/gfx/shell/gamepad/cursor.png').convert('RGBA')
w, h = im.size
(a.out / 'cursor.rgba').write_bytes(im.tobytes())
stub = r'''
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
typedef unsigned char byte;
typedef struct { int width,height,type,size,flags; byte *buffer; } rgbdata_t;
#define PF_RGBA_32 1
#define IMAGE_HAS_COLOR 1
#define IMAGE_HAS_ALPHA 2
#define TF_CLAMP 1
#define COF_VCURSOR_ART "cursor.rgba"
#define S_WARN ""
#define true 1
#define Q_max(a,b) ((a)>(b)?(a):(b))
#define Con_Printf(...) ((void)0)
#define CL_CoF_PadTrace(...) ((void)0)
static struct { int art_tex,shadow_tex,art_missing; } cof_pad;
static int uploads,allocations;
static void *Z_Malloc(size_t n) { allocations++; return malloc(n); }
static void *Z_Calloc(size_t n) { allocations++; return calloc(1,n); }
static void Z_Free(void *p) { allocations--; free(p); }
static int Find(const char *n) { return strstr(n,"shadow")?cof_pad.shadow_tex:cof_pad.art_tex; }
static struct { struct { int (*GL_FindTexture)(const char*); } dllFuncs; } ref = {{Find}};
static rgbdata_t *FS_LoadImage(const char *n, void *unused, int size) {
 rgbdata_t *p=malloc(sizeof(*p)); *p=(rgbdata_t){WIDTH,HEIGHT,PF_RGBA_32,WIDTH*HEIGHT*4,3,malloc(WIDTH*HEIGHT*4)};
 FILE *f=fopen(n,"rb"); assert(f); assert(fread(p->buffer,1,p->size,f)==(size_t)p->size); fclose(f); return p;
}
static void FS_FreeImage(rgbdata_t *p) { free(p->buffer);free(p); }
static int GL_LoadTextureInternal(const char *name,rgbdata_t *p,int flags) {
 FILE *f=fopen(strstr(name,"shadow")?"shadow.rgba":"art.rgba","wb"); assert(f);
 assert(fwrite(p->buffer,1,p->size,f)==(size_t)p->size); fclose(f);
 // Renderer GL_BuildMipMap writes into this buffer; an arbitrary destructive
 // write tests ownership more strictly than a particular GL mipmap setting.
 memset(p->buffer,255,p->size); return ++uploads;
}
'''
main = r'''
int main(void) {
 int shadow=0; assert(CL_CoF_VCursorArt(&shadow)==1 && shadow==2);
 assert(uploads==2 && allocations==0);
 assert(CL_CoF_VCursorArt(&shadow)==1 && shadow==2 && uploads==2);
 // Renderer restart invalidates both cached texture IDs.
 cof_pad.art_tex=cof_pad.shadow_tex=0;
 assert(CL_CoF_VCursorArt(&shadow)==3 && shadow==4);
 assert(uploads==4 && allocations==0);
 puts("cursor uploads/cache/restart/allocation balance PASS"); return 0;
}
'''
code = a.out / 'cursor-shadow.c'
code.write_text(f'#define WIDTH {w}\n#define HEIGHT {h}\n' + stub + function + main)
subprocess.run(['cl', '/nologo', '/W3', '/std:c11', str(code.resolve()), '/Fe:cursor-shadow.exe'], cwd=a.out, check=True)
subprocess.run([str((a.out / 'cursor-shadow.exe').resolve())], cwd=a.out, check=True)
assert (a.out / 'art.rgba').read_bytes() == im.tobytes(), 'art changed before upload'
# Independent scalar reference: circular alpha dilation, then two 3x3 averages.
alpha = list(im.getchannel('A').tobytes())
r = max(2, w // 40)
dilated = [max(alpha[sy*w+sx] for dy in range(-r,r+1) for dx in range(-r,r+1)
               if dx*dx+dy*dy <= r*r and 0 <= (sx:=x+dx) < w and 0 <= (sy:=y+dy) < h)
           for y in range(h) for x in range(w)]
for _ in range(2):
    blurred = []
    for y in range(h):
        for x in range(w):
            neighbors = [dilated[sy*w+sx] for sy in range(max(0,y-1),min(h,y+2))
                         for sx in range(max(0,x-1),min(w,x+2))]
            blurred.append(sum(neighbors)//len(neighbors))
    dilated = blurred
expected = bytes(c for alpha in dilated for c in (0,0,0,alpha))
assert (a.out / 'shadow.rgba').read_bytes() == expected, 'shadow derived from mutated upload pixels'
print('Original art and all shadow pixels match reference despite destructive upload: PASS')
