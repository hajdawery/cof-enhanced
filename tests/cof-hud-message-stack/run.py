#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Cry of Fear: Enhanced contributors
"""Compile the actual VGUI relocation methods; exercise independent captions."""
import argparse
from pathlib import Path
import re
import subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--source-root', type=Path, required=True)
p.add_argument('--out', type=Path, required=True)
a = p.parse_args()
a.out.mkdir(parents=True, exist_ok=True)
base = a.source_root / '3rdparty/freevgui/platform/xash3d-fwgs'
surface = (base / 'surface.cpp').read_text()
app = (base / 'app.cpp').read_text()
assert app.index('g_surface->beginMessageFrame();') < app.index('panel->paintTraverse();')
assert 'savedClip[1] + yDelta' in surface and 'savedClip[3] + yDelta' in surface

def function(name):
    m = re.search(r'^(?:bool|int|void) XashSurface::' + name + r'\([^\n]*\)[^\n]*\n\{', surface, re.M)
    assert m, name
    end = surface.index('{', m.start()) + 1
    depth = 1
    while depth:
        depth += (surface[end] == '{') - (surface[end] == '}')
        end += 1
    return surface[m.start():end]

stub = r'''
#include <cassert>
#include <cmath>
#include <cstdio>
#include <algorithm>
#define Q_max(a,b) std::max((a),(b))
#define Q_min(a,b) std::min((a),(b))
static int screen=1080;static float scale=1;
void CofUI_ScreenSize(int*,int*h){*h=screen;}
int CofUI_ToDeviceY(int y){return (int)std::round(y*scale);}
int CofUI_ToLayoutY(int y){return (int)std::round(y/scale);}
class XashSurface { public:
 enum{MAX_MESSAGE_LINES=3,MSG_BAND_LOW_PCT=35,MSG_BAND_HIGH_PCT=90};
 struct BackingLine{int y,tall,minx,maxx,first,count;}backingLines[96];
 struct Glyph{int y;int color[4];}backingGlyphs[32];
 int backingLineCount=0,backingGlyphCount=0,textYTarget=-1,messageStackTop=-1;
 bool messageStackUsed=false;
 bool runIsShortEnough()const;bool runIsMessage()const;
 void beginMessageFrame();int applyTextYTarget();
};
'''
checks = r'''
void run(XashSurface&s,int lines,int y,int height=24,bool visible=true){
 s.backingLineCount=s.backingGlyphCount=lines;
 for(int i=0;i<lines;i++){
  s.backingLines[i]={y+i*(height+2),height,0,100,i,1};
  s.backingGlyphs[i].y=s.backingLines[i].y;
  s.backingGlyphs[i].color[3]=visible?0:255;
 }
}
int main(){
 XashSurface s;
 for(int h:{768,1080,1200,1440,2160})for(float factor:{0.75f,1.f,1.5f,3.f}){
  screen=h;scale=factor;int origin=CofUI_ToLayoutY(h*60/100);
  s.textYTarget=h*78/100;s.beginMessageFrame();
  // A fully faded caption must not reserve an empty row for the next label.
  run(s,1,origin,24,false);assert(!s.applyTextYTarget()&&!s.messageStackUsed);
  run(s,1,origin);int d=s.applyTextYTarget();
  assert(s.backingLines[0].y==CofUI_ToLayoutY(s.textYTarget));
  assert(s.backingGlyphs[0].y==origin+d);
  int first=s.backingLines[0].y, reserved=s.messageStackTop;
  // Independent two-line phone caption must fit entirely above objective.
  run(s,2,origin+7);d=s.applyTextYTarget();
  assert(s.backingLines[1].y+24+4<reserved);
  assert(s.backingLines[1].y-s.backingLines[0].y==26);
  assert(s.backingGlyphs[1].y==origin+7+26+d);
  reserved=s.messageStackTop;
  // A taller three-line caption reserves its true height.
  run(s,3,origin,32);s.applyTextYTarget();
  assert(s.backingLines[2].y+32+5<reserved);
  // Top hints, credits, opt-out do not move or consume space.
  reserved=s.messageStackTop;run(s,1,CofUI_ToLayoutY(h/10));
  assert(s.applyTextYTarget()==0&&s.messageStackTop==reserved);
  run(s,4,origin);assert(s.applyTextYTarget()==0&&s.messageStackTop==reserved);
  run(s,1,origin);s.textYTarget=-1;assert(!s.applyTextYTarget());
  s.textYTarget=h*78/100;s.beginMessageFrame();run(s,1,origin);
  s.applyTextYTarget();assert(s.backingLines[0].y==first);
  // Even an already correctly placed first caption must reserve its row.
  s.beginMessageFrame();run(s,1,first);assert(!s.applyTextYTarget());
  reserved=s.messageStackTop;run(s,1,origin);s.applyTextYTarget();
  assert(s.backingLines[0].y+28<reserved);
  // Negative occupied coordinates are valid when the target is very high or
  // many labels exhaust the screen; they must not act as an unused sentinel.
  for(int pct:{1,78}){
   s.textYTarget=h*pct/100;s.beginMessageFrame();
   for(int n=0;n<100;n++){
    int oldTop=s.messageStackTop;bool occupied=s.messageStackUsed;
    run(s,1,origin,32);s.applyTextYTarget();
    assert(s.messageStackUsed);
    if(occupied)assert(s.backingLines[0].y+32+5<oldTop);
   }
   assert(s.messageStackTop<0);
  }
 }
 puts("PASS caption separation/wrapping/faded text/frame reset/hints/credits/opt-out, 5 resolutions x 4 scales");
}
'''
body = '\n'.join(function(n) for n in ('runIsShortEnough', 'runIsMessage', 'beginMessageFrame', 'applyTextYTarget'))
file = a.out / 'message-stack.cpp'
file.write_text(stub + '\n' + body + '\n' + checks)
subprocess.run(['cl', '/nologo', '/W3', '/EHsc', str(file.resolve()), '/Fe:message-stack.exe'], cwd=a.out, check=True)
subprocess.run([str((a.out / 'message-stack.exe').resolve())], cwd=a.out, check=True)
