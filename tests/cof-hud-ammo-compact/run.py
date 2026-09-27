#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Compile real compact ammo drawing; record box, icon and glyph bounds."""
from pathlib import Path
import argparse, ast, subprocess
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source-root',required=True,type=Path);p.add_argument('--out',required=True,type=Path)
a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
tree=ast.parse((Path(__file__).parents[1]/'cof-hud-ammo/run.py').read_text())
stub=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='stub' for t in n.targets))
needle='static void Pic('
record=r'''
typedef struct {float x,y,w,h;int type,tall;char text[96];} Draw;
static Draw records[256];static int recordsCount;
static void record(float x,float y,float w,float h,int type,int tall,const char*text){
 assert(recordsCount<256);Draw*d=&records[recordsCount++];*d=(Draw){x,y,w,h,type,tall,{0}};
 if(text)snprintf(d->text,sizeof(d->text),"%s",text);
}
'''
stub=stub.replace(needle,record+needle)
stub=stub.replace('assert(w>=0&&h>=0);draws++;','assert(w>=0&&h>=0);draws++;record(x,y,w,h,1,0,NULL);')
stub=stub.replace('assert(w>=0&&h>=0);fills++;','assert(w>=0&&h>=0);fills++;record(x,y,w,h,alpha==64?2:3,0,NULL);')
needle='assert(stringCount<256);snprintf(strings[stringCount++],96,"%s",s);'
stub=stub.replace(needle,needle+'int width;CL_DrawStringLen(f,s,&width,NULL,0);record(x,y,width,f->charHeight,4,f->charHeight,s);')
code='\n'.join(l for l in (a.source_root/'engine/client/cof_hud_remake.c').read_text().splitlines() if not l.startswith('#include'))
test=r'''
static void current(int id,int clip){byte p[3]={1,(byte)id,(byte)clip};CL_CoF_HudRemakeMessage("CurWeapon",3,p);}
static void draw(void){recordsCount=stringCount=0;CL_CoF_HudRemakeBegin();CL_CoF_HudRemakeAmmo();}
static int boxes(void){int n=0;for(int i=0;i<recordsCount;i++)if(records[i].type==2)n++;return n;}
static void bounded(void){
 Draw*box=NULL;float previousTop=1e9f;
 for(int i=0;i<recordsCount;i++){
  Draw*d=&records[i];assert(d->x>=-0.1f&&d->y>=-0.1f&&d->x+d->w<=refState.width+0.1f&&d->y+d->h<=refState.height+0.1f);
  if(d->type==2){assert(d->y+d->h<previousTop);previousTop=d->y;box=d;}
  else if(box){assert(d->x>=box->x-0.1f&&d->y>=box->y-0.1f&&d->x+d->w<=box->x+box->w+0.1f&&d->y+d->h<=box->y+box->h+0.1f);}
 }
}
int main(void){
 cls.state=ca_active;cl.local.health=100;cls.creditsFont.valid=1;cls.creditsFont.scale=1;cls.creditsFont.charHeight=24;for(int i=0;i<256;i++)cls.creditsFont.charWidths[i]=12;
 CL_CoF_HudRemakeInit();cof_hud_ammo_compact.value=1;current(19,18);draw();assert(recordsCount==0); // Classic untouched
 cof_hud_style.value=1;hud_weapons[19].reserve=12;draw();assert(boxes()==1);bounded();
 int caption=0,numbers=0;for(int i=0;i<recordsCount;i++)if(records[i].type==4){if(!strcmp(records[i].text,"BURST")){assert(records[i].tall==11);caption++;}else{assert(records[i].tall==18);numbers++;}}
 assert(caption==1&&numbers==2);
 cof_hud_ammo_compact.value=0;draw();assert(boxes()==0);for(int i=0;i<recordsCount;i++)if(records[i].type==4)assert(records[i].tall==24);
 cof_hud_ammo_compact.value=1;
 for(int res=0;res<4;res++)for(int factor=0;factor<3;factor++){
  int widths[]={640,1280,1920,3840},heights[]={480,720,1080,2160};float multipliers[]={0.75f,1.0f,9.0f};refState.width=widths[res];refState.height=heights[res];multiplier=multipliers[factor];
  for(int id=1;id<HUD_WEAPONS;id++)if(id!=15){current(id,127);hud_weapons[id].reserve=32767;draw();assert(boxes()==1);bounded();}
  hud.weapon=15;hud.dual_id[0]=19;hud.dual_id[1]=23;hud.dual_clip[0]=99999;hud.dual_clip[1]=0;draw();assert(boxes()==2);bounded();
  hud.dual_id[0]=1;hud.dual_id[1]=6;draw();assert(boxes()==2);bounded();
 }
 // Missing optional item art retains text inside its box; no stale old metrics.
 refState.width=1920;refState.height=1080;multiplier=1;for(int i=4;i<ARRAYSIZE(hud_icons);i++)hud_icons[i].aspect=0;
 current(8,0);hud_weapons[8].reserve=32767;draw();assert(boxes()==1);bounded();
 int fallback=0;for(int i=0;i<recordsCount;i++)if(strstr(records[i].text,"SYRINGE"))fallback=1;assert(fallback);
 gate=1;draw();assert(recordsCount==0);
 puts("Compact actual drawing:18px numbers/11px caption, all stock IDs, INF/large counts, dual boxes, screen containment, fallback, Classic/optout PASS");return 0;
}
'''
f=a.out/'compact.c';f.write_text(stub+'\n'+code+'\n'+test)
subprocess.run(['cl','/nologo','/W3','/std:c11',str(f.resolve()),'/Fe:compact.exe'],cwd=a.out,check=True)
subprocess.run([str((a.out/'compact.exe').resolve())],cwd=a.out,check=True)
