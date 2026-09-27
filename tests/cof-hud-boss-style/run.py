#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 haej (Cry of Fear: Enhanced contributors)
"""Compile the actual HUD module and exercise the retail BossBar contract."""
import argparse, subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--source-root',required=True,type=Path)
p.add_argument('--out',required=True,type=Path)
p.add_argument('--game-root',type=Path,help='Optional installed cryoffear directory: verify all 40 decoded stock fingerprints')
a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
code=(a.source_root/'engine/client/cof_hud_remake.c').read_text()
code='\n'.join(line for line in code.splitlines() if not line.startswith('#include'))

stub=r'''
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#define true 1
#define false 0
#define Q_max(a,b) ((a)>(b)?(a):(b))
#define Q_min(a,b) ((a)<(b)?(a):(b))
#define bound(a,x,b) Q_max((a),Q_min((x),(b)))
#define ARRAYSIZE(x) (sizeof(x)/sizeof((x)[0]))
#define Q_stricmp _stricmp
#define Q_snprintf snprintf
#define CVAR_DEFINE_AUTO(n,s,f,h) convar_t n={0}
#define FCVAR_ARCHIVE 1
#define PF_RGBA_32 1
#define TF_IMAGE 1
#define ca_active 2
#define kRenderNormal 0
#define kRenderTransTexture 1
#define kRenderTransAdd 2
typedef unsigned char byte;
typedef int qboolean;
typedef struct {float value;} convar_t;
typedef struct {int left,right,top,bottom;} wrect_t;
typedef struct {int texture,valid,charHeight;float scale;byte charWidths[256];} cl_font_t;
typedef struct {int width,height,type,size;byte *buffer;} rgbdata_t;
static struct {int background,intermission;struct {int health;}local;} cl;
static struct {int state;cl_font_t creditsFont;} cls;
static struct {int framecount;double realtime;}host;
static struct {int width,height;}refState={1920,1080};
static struct {const char *gamefolder;} game={"cryoffear"},*GI=&game;
static int gate,missing,loaded,draws,fills,lastMode;static byte lastColor[4];
static float multiplier=1;static char strings[256][96];static int stringCount;
static const char *loadedNames[64];
static void Cvar_RegisterVariable(convar_t *v){}
static int CL_CoF_UIGateActive(void){return gate;}
static float CL_CoF_UIScaleUser(void){return multiplier;}
static int Find(const char *name){for(int i=0;i<loaded;i++)if(!strcmp(name,loadedNames[i]))return i+1;return 0;}
static void SetMode(int mode){lastMode=mode;}
static void Color(byte r,byte g,byte b,byte alpha){lastColor[0]=r;lastColor[1]=g;lastColor[2]=b;lastColor[3]=alpha;}
static void Pic(float x,float y,float w,float h,float s,float t,float s2,float t2,int tex){assert(w>=0&&h>=0);draws++;}
static struct {float x,y,w,h;int r,g,b,a;} rects[512];
static void Fill(int mode,float x,float y,float w,float h,int r,int g,int b,int alpha){assert(w>=0&&h>=0);assert(fills<512);rects[fills].x=x;rects[fills].y=y;rects[fills].w=w;rects[fills].h=h;rects[fills].r=r;rects[fills].g=g;rects[fills].b=b;rects[fills].a=alpha;fills++;}
static struct {struct {int (*GL_FindTexture)(const char*);void (*GL_SetRenderMode)(int);void (*Color4ub)(byte,byte,byte,byte);void (*R_DrawStretchPic)(float,float,float,float,float,float,float,float,int);void(*FillRGBA)(int,float,float,float,float,int,int,int,int);}dllFuncs;}ref={{Find,SetMode,Color,Pic,Fill}};
static rgbdata_t *FS_LoadImage(const char *name,void *unused,int size){
 if(missing)return NULL;rgbdata_t *pic=malloc(sizeof(*pic));*pic=(rgbdata_t){16,16,PF_RGBA_32,1024,calloc(1,1024)};
 for(int y=2;y<14;y++)for(int x=4;x<12;x++)memset(pic->buffer+(y*16+x)*4,255,4);
 if(strstr(name,"items.png")) { memset(pic->buffer,0,1024); for(int y=0;y<16;y++)for(int x=0;x<16;x++)if(x%4==1&&y%4==1)memset(pic->buffer+(y*16+x)*4,255,4); } pic->buffer[3]=1;return pic;
}
static int GL_LoadTextureInternal(const char *name,rgbdata_t*p,int flags){loadedNames[loaded]=name;return ++loaded;}
static void FS_FreeImage(rgbdata_t *p){free(p->buffer);free(p);}
static void CL_DrawStringLen(cl_font_t *font,const char*s,int*w,int*h,int flags){*w=(int)strlen(s)*font->charWidths['0'];}
static void CL_DrawString(float x,float y,const char*s,const byte*c,cl_font_t*f,int flags){assert(stringCount<256);snprintf(strings[stringCount++],96,"%s",s);}
'''
test=r'''
static byte white[4]={255,255,255,211};
static byte packet[256];static int packet_size;
static void boss(int skin,int mode,int hp,int cap){
 packet[0]=mode;int n=1;
 n+=snprintf((char*)packet+n,sizeof(packet)-n,"gfx/vgui/boss/%s_health_empty.tga",hud_boss_skins[skin])+1;
 n+=snprintf((char*)packet+n,sizeof(packet)-n,"gfx/vgui/boss/%s_health_full.tga",hud_boss_skins[skin])+1;
 packet[n++]=hp;packet[n++]=hp>>8;packet[n++]=cap;packet[n++]=cap>>8;packet_size=n;
 CL_CoF_HudRemakeMessage("BossBar",n,packet);
}
static int quad(int skin,int full,float width){return CL_CoF_HudRemakeVguiQuad(HUD_BOSS_FIRST+skin*2+full,true,440,45,width,45,white);}
static void paint(int skin){
 fills=0;CL_CoF_HudRemakeVguiBegin();
 // Real CBossBar child order: full base, empty full-width, clipped full.
 assert(quad(skin,1,200));assert(quad(skin,0,200));assert(quad(skin,1,200.0f*hud_boss.health/hud_boss.maximum));
 CL_CoF_HudRemakeBars();assert(fills==3);
 assert(rects[0].x==440&&rects[0].w==200&&rects[0].y==65.5f&&rects[0].h==4);
 assert(fabsf(rects[2].w-198.0f*hud_boss.health/hud_boss.maximum)<0.001f);
 assert(rects[2].a==211);
}
int main(void){
 byte doctor[16]={0x03,0x35,0x48,0x5f,0xaf,0xad,0xa0,0xbf,0x2a,0x72,0xb1,0xf5,0xa7,0xbb,0xcc,0x82};
 byte unknown[16]={0};assert(CL_CoF_HudRemakeTexture(doctor)==HUD_BOSS_FIRST+6);assert(CL_CoF_HudRemakeTexture(unknown)==0);
 cls.state=ca_active;cl.local.health=100;CL_CoF_HudRemakeInit();
 boss(3,1,1000,1000);assert(!quad(3,0,200)); // Classic passthrough
 cof_hud_style.value=1;missing=1;assert(!quad(3,0,200));missing=0;host.realtime=10;
 for(int skin=0;skin<10;skin++){
  boss(skin,1,1000,1000);paint(skin);assert(rects[2].r==245&&rects[2].g==245);
  host.realtime+=1;boss(skin,1,750,1000);paint(skin);assert(rects[2].g==160);
  host.realtime+=0.41;paint(skin);assert(rects[2].g==245);
  boss(skin,1,250,1000);paint(skin);assert(rects[2].g==48);
  boss(skin,1,-1,1000);paint(skin);assert(rects[2].w==0);
  boss(skin,1,2000,1000);paint(skin);assert(rects[2].w==198);
  assert(!quad((skin+1)%10,0,200));
 }
 boss(3,1,500,1000);host.realtime+=1;boss(3,1,450,1000);assert(hud_boss.damage_until>host.realtime);
 boss(3,1,400,500);assert(hud_boss.damage_until==0); // new cap is not damage
 boss(4,1,300,500);assert(hud_boss.damage_until==0); // new boss too
 for(int mode=0;mode<=2;mode+=2){boss(3,mode,500,1000);assert(hud_boss.skin==-1&&!quad(3,0,200));}
 boss(3,1,500,0);assert(hud_boss.skin==-1);boss(3,1,500,-1);assert(hud_boss.skin==-1);
 boss(3,1,500,1000);packet[1]='X';CL_CoF_HudRemakeMessage("BossBar",packet_size,packet);assert(hud_boss.skin==-1);
 boss(3,1,500,1000);int n=packet_size;for(int size=0;size<n;size++){CL_CoF_HudRemakeMessage("BossBar",size,packet);assert(hud_boss.skin==-1);}
 boss(3,1,500,1000);CL_CoF_HudRemakeMessage("BossBar",n,NULL);assert(hud_boss.skin==-1);
 boss(3,1,500,1000);fills=0;CL_CoF_HudRemakeVguiBegin();quad(3,1,100);CL_CoF_HudRemakeBars();assert(fills==0); // clipped fill cannot establish bounds
 paint(3);host.framecount++;fills=0;CL_CoF_HudRemakeBars();assert(fills==0);
 gate=1;assert(!quad(3,0,200));gate=0;cl.local.health=0;assert(!quad(3,0,200));cl.local.health=100;
 for(int h=480;h<=2160;h*=2){refState.height=h;multiplier=1.5f;CL_CoF_HudRemakeVguiBegin();assert(quad(3,0,500));fills=0;CL_CoF_HudRemakeBars();assert(fills==3&&rects[0].w==500&&rects[0].h<=16);}
 CL_CoF_HudRemakeReset();assert(hud_boss.skin==-1&&!quad(3,0,200));
 puts("PASS BossBar real child draw sequence; ten skins; health ratio/colors/timing; malformed/custom packets; Classic; visibility; clipped bounds; reset; scale");return 0;
}
'''
if a.game_root:
 from PIL import Image
 import hashlib
 checks=[]
 names=['carcass','craig','david','doctor','hanger','holeboss','mace','pumpa','sawer','simon']
 for i,name in enumerate(names):
  for j,part in enumerate(['empty','full']):
   raw=bytearray(Image.open(a.game_root/'gfx/vgui/boss'/f'{name}_health_{part}.tga').convert('RGBA').tobytes())
   for inverted in [False,True]:
    if inverted:
     for k in range(3,len(raw),4): raw[k]=255-raw[k]
    digest=','.join(str(x) for x in hashlib.md5(raw).digest())
    checks.append('{byte h[16]={'+digest+'};assert(CL_CoF_HudRemakeTexture(h)==HUD_BOSS_FIRST+'+str(i*2+j)+');}')
 test=test.replace('int main(void){','int main(void){'+''.join(checks))
 print('Checking 40 stock decoded texture fingerprints against installed art')
file=a.out/'hud-boss.c';file.write_text(stub+'\n'+code+'\n'+test)
subprocess.run(['cl','/nologo','/W3','/std:c11',str(file.resolve()),'/Fe:hud-boss.exe'],cwd=a.out,check=True)
subprocess.run([str((a.out/'hud-boss.exe').resolve())],cwd=a.out,check=True)
