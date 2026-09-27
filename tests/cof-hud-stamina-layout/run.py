#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Compile actual stamina routing and layout; uses shared renderer fixture, no game."""
import argparse, ast, subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--source-root',required=True,type=Path)
p.add_argument('--out',required=True,type=Path)
a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
fixture=Path(__file__).parents[1]/'cof-hud-ammo/run.py'
tree=ast.parse(fixture.read_text())
stub=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='stub' for t in n.targets))
stub=stub.replace('static void Fill(', 'static float lastFillX,lastFillY,lastFillW,lastFillH; static int fillR,fillG,fillB,fillA;\nstatic void Fill(')
stub=stub.replace('assert(w>=0&&h>=0);fills++;','assert(w>=0&&h>=0);fills++;lastFillX=x;lastFillY=y;lastFillW=w;lastFillH=h;fillR=r;fillG=g;fillB=b;fillA=alpha;')
code=(a.source_root/'engine/client/cof_hud_remake.c').read_text()
code='\n'.join(l for l in code.splitlines() if not l.startswith('#include'))
test=r'''
static byte white[4]={255,255,255,255},red[4]={255,0,0,127},blue[4]={0,0,255,127};
static int quad(int kind,int texture,float x,float y,float w,float h,byte*c){return CL_CoF_HudRemakeVguiQuad(kind,texture,x,y,w,h,c);}
static void anchor(void){assert(quad(HUD_STAMINA,1,30,600,20,160,white));}
int main(void){
 cls.state=ca_active;cl.local.health=100;CL_CoF_HudRemakeInit();host.framecount=10;
 byte stamina[3]={50,0,0};CL_CoF_HudRemakeMessage("Stamina",3,stamina);
 CL_CoF_HudRemakeVguiBegin();assert(!quad(HUD_STAMINA,1,30,600,20,160,white));assert(!quad(0,0,30,600,20,160,red));assert(loaded==0);
 cof_hud_style.value=1;CL_CoF_HudRemakeVguiBegin();
 assert(!quad(0,0,30,600,20,160,red)); // red without known image is untouched
 anchor();assert(!quad(0,0,31,600,20,160,red)); // another rectangle
 anchor();assert(!quad(0,0,30,600,20,160,blue)); // another color
 anchor();assert(!quad(0,1,30,600,20,160,red)); // another texture
 anchor();assert(!quad(0,0,100,100,10,10,red));assert(!quad(0,0,30,600,20,160,red)); // intervening quad
 anchor();host.framecount++;assert(!quad(0,0,30,600,20,160,red)); // stale frame
 anchor();CL_CoF_HudRemakeVguiBegin();assert(!quad(0,0,30,600,20,160,red)); // same-frame new pass
 anchor();assert(quad(0,0,30,600,20,160,red));CL_CoF_HudRemakeBars();
 assert(lastFillW==280&&lastFillH==4&&lastFillX==820&&lastFillY==1048);
 assert(fillR==255&&fillG==0&&fillB==0&&fillA==127); // retain actual dodge fade
 CL_CoF_HudRemakeVguiBegin();anchor();red[3]=0;assert(quad(0,0,30,600,20,160,red));CL_CoF_HudRemakeBars();assert(lastFillW==140&&fillR==245&&fillA==255);
 // Changing resolution/scale never reuses old bounds. New final geometry matches.
 refState.width=3840;refState.height=2160;multiplier=1.25f;CL_CoF_HudRemakeVguiBegin();
 assert(quad(HUD_STAMINA,1,60,1200,40,320,white));assert(!quad(0,0,30,600,20,160,red));
 assert(quad(HUD_STAMINA,1,60,1200,40,320,white));red[3]=60;assert(quad(0,0,60,1200,40,320,red));CL_CoF_HudRemakeBars();assert(lastFillW==700&&lastFillH==10&&fillA==60);
 anchor();gate=1;assert(!quad(0,0,30,600,20,160,red));gate=0;
 CL_CoF_HudRemakeMessage("ResetHUD",0,NULL);assert(!quad(HUD_STAMINA,1,30,600,20,160,white));
 puts("Stamina selective pair, Classic, unrelated colors/bounds, frame/pass reset, actual flash alpha, 1080p/4K scale PASS");return 0;
}
'''
f=a.out/'stamina.c';f.write_text(stub+'\n'+code+'\n'+test)
subprocess.run(['cl','/nologo','/W3','/std:c11',str(f.resolve()),'/Fe:stamina.exe'],cwd=a.out,check=True)
subprocess.run([str((a.out/'stamina.exe').resolve())],cwd=a.out,check=True)
