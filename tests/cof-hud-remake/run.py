#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 haej (Cry of Fear: Enhanced contributors)
"""Compile real Remake HUD C module against recording API stubs; no game launch."""
import argparse
from pathlib import Path
import subprocess
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--source-root',required=True,type=Path)
p.add_argument('--out',required=True,type=Path)
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
typedef struct {int texture,valid,charHeight;float scale;int charWidths[256];} cl_font_t;
typedef struct {int width,height,type,size;byte *buffer;} rgbdata_t;
static struct {int background,intermission;struct {int health;}local;} cl;
static struct {int state;cl_font_t creditsFont;} cls;
static struct {int framecount;double realtime;}host;
static struct {int width,height;}refState={1920,1080};
static struct {const char *gamefolder;} game={"cryoffear"},*GI=&game;
static int gate,missing,loaded,draws,fills,lastMode;static byte lastColor[4];
static float multiplier=1;static char strings[32][32];static int stringCount;
static const char *loadedNames[8];
static void Cvar_RegisterVariable(convar_t *v){}
static int CL_CoF_UIGateActive(void){return gate;}
static float CL_CoF_UIScaleUser(void){return multiplier;}
static int Find(const char *name){for(int i=0;i<loaded;i++)if(!strcmp(name,loadedNames[i]))return i+1;return 0;}
static void SetMode(int mode){lastMode=mode;}
static void Color(byte r,byte g,byte b,byte alpha){lastColor[0]=r;lastColor[1]=g;lastColor[2]=b;lastColor[3]=alpha;}
static void Pic(float x,float y,float w,float h,float s,float t,float s2,float t2,int tex){assert(w>=0&&h>=0);draws++;}
static void Fill(int mode,float x,float y,float w,float h,int r,int g,int b,int alpha){assert(w>=0&&h>=0);fills++;}
static struct {struct {int (*GL_FindTexture)(const char*);void (*GL_SetRenderMode)(int);void (*Color4ub)(byte,byte,byte,byte);void (*R_DrawStretchPic)(float,float,float,float,float,float,float,float,int);void(*FillRGBA)(int,float,float,float,float,int,int,int,int);}dllFuncs;}ref={{Find,SetMode,Color,Pic,Fill}};
static rgbdata_t *FS_LoadImage(const char *name,void *unused,int size){
 if(missing)return NULL;rgbdata_t *pic=malloc(sizeof(*pic));*pic=(rgbdata_t){16,16,PF_RGBA_32,1024,calloc(1,1024)};
 for(int y=2;y<14;y++)for(int x=4;x<12;x++)memset(pic->buffer+(y*16+x)*4,255,4);
 pic->buffer[3]=1;return pic;
}
static int GL_LoadTextureInternal(const char *name,rgbdata_t*p,int flags){loadedNames[loaded]=name;return ++loaded;}
static void FS_FreeImage(rgbdata_t *p){free(p->buffer);free(p);}
static void CL_DrawStringLen(cl_font_t *font,const char*s,int*w,int*h,int flags){*w=(int)strlen(s)*font->charWidths['0'];}
static void CL_DrawString(float x,float y,const char*s,const byte*c,cl_font_t*f,int flags){strcpy(strings[stringCount++],s);}
'''
test=r'''
static byte white[4]={255,255,255,255};
static int sprite(const char *name,int digit,float x,float y){wrect_t rc={digit*24,digit*24+20,0,24};return CL_CoF_HudRemakeSprite(name,digit<0?NULL:&rc,kRenderTransAdd,1,x,y,20,24,0,0,1,1,white);}
static void magazine(int tens,int units){assert(sprite("sprites/cof_glock_mag.spr",-1,1700,900));assert(sprite("sprites/cof_mag_cross.spr",-1,1800,990));if(tens>=0)assert(sprite("sprites/cof_ammohud.spr",tens,1850,990));assert(sprite("sprites/cof_ammohud.spr",units,tens<0?1850:1874,990));}
int main(void){
 cls.state=ca_active;cl.local.health=100;cls.creditsFont.valid=1;cls.creditsFont.scale=1;cls.creditsFont.charHeight=24;for(int i=0;i<256;i++)cls.creditsFont.charWidths[i]=12;
 CL_CoF_HudRemakeInit();CL_CoF_HudRemakeBegin();assert(!hud.collecting&&loaded==0);assert(!sprite("sprites/cof_glock_mag.spr",-1,1700,900));
 cof_hud_style.value=1;missing=1;CL_CoF_HudRemakeBegin();assert(!hud.collecting);assert(!CL_CoF_HudRemakeQuad(HUD_HEALTH,255));
 missing=0;host.realtime=6;CL_CoF_HudRemakeBegin();assert(hud.collecting&&loaded==4);assert(hud_icons[0].u1==0.25f&&hud_icons[0].v1==0.125f); // ignores faint alpha noise
 byte current[3]={1,6,7};CL_CoF_HudRemakeMessage("CurWeapon",3,current);
 magazine(1,2);assert(HudMagazineCount()==12);CL_CoF_HudRemakeAmmo();assert(stringCount==2&&!strcmp(strings[0],"7")&&!strcmp(strings[1],"12"));assert(hud.count==0);
 // Counter has no cached digits: following frame receives no magazine count.
 CL_CoF_HudRemakeBegin();int before=draws;assert(sprite("sprites/cof_glock_mag.spr",-1,1700,900));CL_CoF_HudRemakeAmmo();assert(draws==before+1&&stringCount==2);
 // Unknown/incomplete/ambiguous rows replay exactly the stored draw count.
 CL_CoF_HudRemakeBegin();magazine(1,2);assert(sprite("sprites/cof_ammohud.spr",3,1850,950));before=draws;CL_CoF_HudRemakeAmmo();assert(draws==before+5&&stringCount==2);
 CL_CoF_HudRemakeBegin();magazine(-1,0);assert(HudMagazineCount()==0);CL_CoF_HudRemakeAmmo();assert(!strcmp(strings[3],"0"));
 // Shotgun reserve is individual shells, captured directly from Classic digits.
 current[1]=4;current[2]=3;CL_CoF_HudRemakeMessage("CurWeapon",3,current);CL_CoF_HudRemakeBegin();assert(sprite("sprites/cof_shotgun_box.spr",-1,1700,900));assert(sprite("sprites/cof_shotgun_box_icon.spr",-1,1800,990));assert(sprite("sprites/cof_ammohud.spr",9,1850,990));assert(HudMagazineCount()==9);CL_CoF_HudRemakeAmmo();assert(!strcmp(strings[4],"3")&&!strcmp(strings[5],"9"));
 CL_CoF_HudRemakeBegin();int dual[2]={5,6};CL_CoF_HudRemakeMessage("DualAmmo",8,(byte*)dual);assert(!sprite("sprites/cof_glock_mag.spr",-1,1700,900));
 // Interleaved unrelated sprites flush before their draw, preserving order and mode.
 hud.dual=0;CL_CoF_HudRemakeBegin();before=draws;assert(sprite("sprites/cof_shotgun_box.spr",-1,1700,900));assert(!CL_CoF_HudRemakeSprite(NULL,NULL,17,2,20,20,20,20,0,0,1,1,white));assert(draws==before+1&&lastMode==17&&hud.overflow);
 CL_CoF_HudRemakeBegin();before=draws;for(int i=0;i<HUD_MAX_DRAWS;i++)assert(sprite("sprites/cof_shotgun_box.spr",-1,1700,900));assert(!CL_CoF_HudRemakeSprite("sprites/cof_shotgun_box.spr",NULL,19,2,1700,900,20,20,0,0,1,1,white));assert(draws==before+HUD_MAX_DRAWS&&lastMode==19);
 // Fixed VP70 burst label requires its exact sprite and current weapon ID.
 current[1]=19;CL_CoF_HudRemakeMessage("CurWeapon",3,current);CL_CoF_HudRemakeBegin();assert(sprite("sprites/cof_vp70_mag.spr",-1,1700,900));assert(sprite("sprites/cof_mag_cross.spr",-1,1800,990));assert(sprite("sprites/cof_ammohud.spr",2,1850,990));CL_CoF_HudRemakeAmmo();assert(!strcmp(strings[stringCount-1],"BURST"));
 current[1]=23;CL_CoF_HudRemakeMessage("CurWeapon",3,current);CL_CoF_HudRemakeBegin();assert(sprite("sprites/cof_famas_mag.spr",-1,1700,900));assert(sprite("sprites/cof_mag_cross.spr",-1,1800,990));assert(sprite("sprites/cof_ammohud.spr",2,1850,990));CL_CoF_HudRemakeAmmo();assert(!strcmp(strings[stringCount-1],"AUTO"));
 // Health/stamina substitute only when corresponding Classic quads are visible.
 CL_CoF_HudRemakeReset();host.framecount=20;byte stamina[3]={60,0,0};CL_CoF_HudRemakeMessage("Stamina",3,stamina);assert(hud.stamina==60);assert(CL_CoF_HudRemakeQuad(HUD_HEALTH,255));assert(CL_CoF_HudRemakeQuad(HUD_STAMINA,255));before=fills;CL_CoF_HudRemakeBars();assert(fills==before+4);host.framecount++;before=fills;CL_CoF_HudRemakeBars();assert(fills==before);
 // No stale ammo/stamina survives map reset; malformed packets ignored.
 CL_CoF_HudRemakeMessage("ResetHUD",0,NULL);assert(hud.clip==-1&&hud.stamina==-1);CL_CoF_HudRemakeMessage("CurWeapon",2,current);assert(hud.clip==-1);
 gate=1;assert(!CL_CoF_HudRemakeQuad(HUD_HEALTH,255));gate=0;cof_hud_style.value=0;assert(!CL_CoF_HudRemakeQuad(HUD_HEALTH,255));
 puts("HUD Classic/missing-art/multidigit/same-frame/replay/zero/dual/visibility/reset/bounds PASS");return 0;
}
'''
file=a.out/'hud-remake.c';file.write_text(stub+'\n'+code+'\n'+test)
subprocess.run(['cl','/nologo','/W3','/std:c11',str(file.resolve()),'/Fe:hud-remake.exe'],cwd=a.out,check=True)
subprocess.run([str((a.out/'hud-remake.exe').resolve())],cwd=a.out,check=True)
