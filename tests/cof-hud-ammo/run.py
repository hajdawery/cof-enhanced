#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 haej (Cry of Fear: Enhanced contributors)
"""Compile actual HUD module with message and renderer contract fixtures."""
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
static float multiplier=1;static char strings[256][96];static int stringCount;
static const char *loadedNames[64];
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
 if(strstr(name,"items.png")) { memset(pic->buffer,0,1024); for(int y=0;y<16;y++)for(int x=0;x<16;x++)if(x%4==1&&y%4==1)memset(pic->buffer+(y*16+x)*4,255,4); } pic->buffer[3]=1;return pic;
}
static int GL_LoadTextureInternal(const char *name,rgbdata_t*p,int flags){loadedNames[loaded]=name;return ++loaded;}
static void FS_FreeImage(rgbdata_t *p){free(p->buffer);free(p);}
static void CL_DrawStringLen(cl_font_t *font,const char*s,int*w,int*h,int flags){*w=(int)strlen(s)*font->charWidths['0'];}
static void CL_DrawString(float x,float y,const char*s,const byte*c,cl_font_t*f,int flags){assert(stringCount<256);snprintf(strings[stringCount++],96,"%s",s);}
'''
test=r'''
static byte white[4]={255,255,255,255};
static void current(int id,int clip){byte p[3]={1,(byte)id,(byte)clip};CL_CoF_HudRemakeMessage("CurWeapon",3,p);}
static void info(int id,int divisor,int amount){byte p[4]={(byte)id,(byte)divisor,(byte)amount,(byte)(amount>>8)};CL_CoF_HudRemakeMessage("WpnInfo",4,p);}
static void ammo(int id,int amount){byte p[3]={(byte)id,(byte)amount,(byte)(amount>>8)};CL_CoF_HudRemakeMessage("AmmoX",3,p);}
static void list(int id,int type){byte p[10]={'w',0,(byte)type,255,255,255,0,0,(byte)id,0};CL_CoF_HudRemakeMessage("WeaponList",10,p);}
static int sprite(const char *name){return CL_CoF_HudRemakeSprite(name,NULL,kRenderTransAdd,1,20,20,32,128,0,0,1,1,white);}
static int has(const char *s){for(int i=0;i<stringCount;i++)if(!strcmp(strings[i],s))return 1;return 0;}
static void begin(void){stringCount=0;CL_CoF_HudRemakeBegin();}
int main(void){
 cls.state=ca_active;cl.local.health=100;cls.creditsFont.valid=1;cls.creditsFont.scale=1;cls.creditsFont.charHeight=24;for(int i=0;i<256;i++)cls.creditsFont.charWidths[i]=12;
 CL_CoF_HudRemakeInit();current(3,7);begin();assert(!hud.collecting&&loaded==0&&!sprite("sprites/cof_glock_mag.spr"));
 cof_hud_style.value=1;missing=1;begin();assert(!hud.collecting);missing=0;host.realtime=6;
 // Retail WpnInfo handler: explicit divisor, signed short total, 8 magazine cases.
 int magazineIDs[]={3,7,9,14,19,20,26,27};
 for(int i=0;i<8;i++){int id=magazineIDs[i];list(id,1);ammo(1,999);info(id,15,180);assert(HudReserve(id)==12);info(id,0,77);assert(HudReserve(id)==12);}
 // Lingering DualAmmo clip values must NEVER imply dual wield for a single rifle.
 int clips[2]={5,6};CL_CoF_HudRemakeMessage("DualAmmo",8,(byte*)clips);
 current(3,7);begin();assert(hud.collecting);
 // Retail draw ordering: clipped magazine, digits, icon, cross; unrelated overlays
 // may occur anywhere. No geometry/rect-width dependence, no end-of-batch guess.
 assert(sprite("sprites/cof_glock_mag.spr"));assert(!sprite("sprites/subtle_noise.spr"));assert(sprite("sprites/cof_ammohud.spr"));assert(!sprite("sprites/cof_crosshair.spr"));assert(sprite("sprites/cof_glock_mag_icon.spr"));assert(sprite("sprites/cof_mag_cross.spr"));CL_CoF_HudRemakeAmmo();assert(has("7")&&has("12")&&has("SEMI"));
 begin();CL_CoF_HudRemakeAmmo();assert(has("7")&&has("12")); // independent of sprite availability/order
 // Reload/discard events update only explicit server packet counts.
 info(3,15,165);current(3,15);begin();CL_CoF_HudRemakeAmmo();assert(has("11")&&has("15"));
 // Rifle/revolver/shotgun reserve is the AmmoX pool selected by WeaponList.
 int looseIDs[]={4,11,21};for(int i=0;i<3;i++){int id=looseIDs[i];list(id,8+i);ammo(8+i,17);info(id,5,100);current(id,3);begin();assert(sprite("sprites/cof_revolver_cylinder.spr"));CL_CoF_HudRemakeAmmo();assert(has("3")&&has("17"));}
 // Syringe and flare counts are item quantities, not clips or magazine division.
 int itemIDs[]={8,13};for(int i=0;i<2;i++){info(itemIDs[i],9,4);current(itemIDs[i],-1);begin();assert(sprite("sprites/cof_syringe_icon.spr"));CL_CoF_HudRemakeAmmo();assert(has("4")&&!has("-"));}
 // DualWield identity packet has a string then five bytes. DualAmmo is clips only.
 current(15,-1);begin();assert(!hud.collecting&&!sprite("sprites/cof_glock_mag.spr"));
 byte dual[7]={'v',0,1,3,21,0,0};CL_CoF_HudRemakeMessage("DualWield",7,dual);current(15,-1);begin();CL_CoF_HudRemakeAmmo();assert(has("5")&&has("6")&&has("11")&&has("17")&&has("GLOCK  SEMI")&&has("REVOLVER  SINGLE"));
 // All stock identities have a styled presentation; utilities get no fake count.
 for(int id=1;id<HUD_WEAPONS;id++){current(id,5);begin();assert(sprite("sprites/cof_ammohud.spr"));int before=draws;CL_CoF_HudRemakeAmmo();assert(draws>before||stringCount>0);if(hud_catalog[id].kind==HUD_NONE&&id!=15)assert(!has("5"));}
 current(23,30);begin();assert(sprite("sprites/gm_inf.spr"));CL_CoF_HudRemakeAmmo();assert(has("INF")&&has("AUTO"));
 // Atlas cells are cropped independently and share one texture upload.
 assert(hud_icons[4].texture==hud_icons[5].texture);assert(hud_icons[4].u1==0.0625f&&hud_icons[4].v1==0.8125f);assert(loaded==5);
 // Exact retail HideWeapon bits and menu gates retain passthrough, no stray HUD.
 byte hide=1;CL_CoF_HudRemakeMessage("HideWeapon",1,&hide);begin();assert(!sprite("sprites/gm_inf.spr"));CL_CoF_HudRemakeAmmo();assert(stringCount==0);hide=0;CL_CoF_HudRemakeMessage("HideWeapon",1,&hide);
 gate=1;begin();assert(!hud.collecting);gate=0;
 // Reset does not forget WeaponList metadata (retail retains it across respawn).
 CL_CoF_HudRemakeReset();assert(hud.weapon==0&&hud_weapons[11].ammo_type==9&&HudReserve(11)==0);begin();CL_CoF_HudRemakeAmmo();assert(!stringCount);
 byte malformed[2]={1,3};CL_CoF_HudRemakeMessage("CurWeapon",2,malformed);assert(hud.weapon==0);current(99,4);begin();assert(!sprite("sprites/cof_ammohud.spr"));
 cof_hud_style.value=0;current(3,7);begin();assert(!sprite("sprites/cof_glock_mag.spr"));
 puts("PASS stock27/message accounting/retail draw order/lingering DualAmmo/dual identities/items/atlas/hide/reset/Classic");return 0;
}
'''
file=a.out/'hud-ammo.c';file.write_text(stub+'\n'+code+'\n'+test)
subprocess.run(['cl','/nologo','/W3','/std:c11',str(file.resolve()),'/Fe:hud-ammo.exe'],cwd=a.out,check=True)
subprocess.run([str((a.out/'hud-ammo.exe').resolve())],cwd=a.out,check=True)
