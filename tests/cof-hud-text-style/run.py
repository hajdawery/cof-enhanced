"""Compile actual HUD/VGUI style helpers against host stubs; no game launch."""
import argparse
from pathlib import Path
import re
import subprocess
p=argparse.ArgumentParser()
p.add_argument('--source-root',type=Path,required=True)
p.add_argument('--vcvars',type=Path,default=Path(r'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat'))
a=p.parse_args();root=Path(__file__).resolve().parents[2];out=root/'build-hud-text-style/harness';out.mkdir(parents=True,exist_ok=True)
def fn(text,name):
 m=re.search(r'^(?:static )?[^\n]+\b'+name+r'\([^\n]*\)\n\{',text,re.M);assert m,name
 end=text.index('{',m.start())+1;depth=1
 while depth:depth+=(text[end]=='{')-(text[end]=='}');end+=1
 return text[m.start():end]
main=(a.source_root/'engine/client/cl_main.c').read_text()
game=(a.source_root/'engine/client/dll_int/cl_game.c').read_text()
surface=(a.source_root/'3rdparty/freevgui/platform/xash3d-fwgs/surface.cpp').read_text()
font=(a.source_root/'3rdparty/freevgui/platform/xash3d-fwgs/coffont.cpp').read_text()
header=(a.source_root/'engine/cof_text_style.h').read_text()
# Background remains the old independent drawing path even with style enabled.
assert 'CVAR_DEFINE_AUTO( cof_hud_text_backing, "0",' in main
assert 'out->semibold == 2 ) out->backing = 0' not in main
flush=fn(game,'CL_CoF_HudTextFlush')
assert 'backing[3] = (byte)bound( 0, (int)cof_hud_text_backing.value, 255 );' in flush
assert 'if( backing[3] != 0 )' in flush
stub=r'''
#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <algorithm>
#include <vector>
typedef int qboolean;typedef unsigned char byte;typedef byte rgba_t[4];
#define Q_max(a,b) std::max((a),(b))
#define Q_rint(a) ((int)std::round(a))
#define bound(a,b,c) std::min(std::max((a),(b)),(c))
#define Q_stricmp _stricmp
#define Q_stristr strstr
#define COM_StringEmptyOrNULL(s) (!(s)||!(s)[0])
#define ARRAYSIZE(a) (sizeof(a)/sizeof((a)[0]))
#define Con_Reportf(...) ((void)0)
#define Con_Printf(...) ((void)0)
#define S_WARN ""
#define COF_FONT_REFERENCE_HEIGHT 768.0f
#define COF_FONT_MESSAGE_ROLES {"credits"}
struct Cvar{float value;};
Cvar cof_hud_text_style={1},cof_ui_inter_fonts={1},cof_text_codepage={1252},cof_hud_text_trace={0},cof_vgui_text_overflow={1},cof_hud_text_backing={0},cof_hud_msg_y_pct={78};
struct{int initialized;}ref={1};struct{int height;}refState={1080};
struct GameInfo{const char*gamefolder;};GameInfo info={"cryoffear"};GameInfo *GI=&info;
float CL_CoF_UIScale(){return 1.5f;}float CL_CoF_UIScaleUser(){return 1.5f;}
struct cof_vgui_font_t{int devicePx,logicalPx,codepage,semibold,ytarget,trace,backing,overflow;};
struct{byte*ttf[3];int ttf_size[3];bool ttf_tried[3];}cof_font;
typedef long fs_offset_t;
bool missingBold;byte fakefont[16];int fileCalls;
byte*FS_LoadFile(const char*path,fs_offset_t*n,bool){fileCalls++;*n=16;return missingBold&&strstr(path,"Inter-Bold")?nullptr:fakefont;}
struct Draw{float x,y;int r,g,b,a;};std::vector<Draw>draws;
struct cl_font_t{int charHeight;};
int CL_DrawCharacter(float x,float y,int,const rgba_t color,cl_font_t*,int){draws.push_back({x,y,color[0],color[1],color[2],color[3]});return 7;}
struct vpoint_t{float point[2],coord[2];};
struct Scissor{bool accept=true;bool clip(vpoint_t a,vpoint_t b,vpoint_t&c,vpoint_t&d){c=a;d=b;return accept;}}g_scissor;
struct Engine{const byte*(*CofFontFile)(int,int*);int color[4];void SetupDrawingImage(const int*c){memcpy(color,c,sizeof(color));}void DrawQuad(vpoint_t*a,vpoint_t*){draws.push_back({a->point[0],a->point[1],color[0],color[1],color[2],color[3]});}}engine,*g_engine=&engine;
struct FontPlat_Inter{static FontPlat_Inter*Create(const byte*,int,int,int,int){static FontPlat_Inter instance;return &instance;}};
struct CofFont{CofFont(FontPlat_Inter*){}};
struct CofEntry{int devicePx,logicalPx,codepage,semibold,backing;char role[64];CofFont*font;};
#define COF_FONT_CACHE 16
static CofEntry g_cache[COF_FONT_CACHE];static int g_cacheCount;
static void vgui_strcpy(char*d,int n,const char*s){strncpy_s(d,n,s,_TRUNCATE);}
'''
body='\n'.join(fn(main,n) for n in ['CL_CoF_FontRoleIsMessage','CL_CoF_FontRoleFraction','CL_CoF_FontDesc','CL_CoF_FontFile'])+'\n'+fn(game,'CL_CoF_DrawStyledHudChar')+'\n'+fn(surface,'CofDrawStyledQuad')+'\n'+fn(font,'CofFindOrCreate')
checks=r'''
static int requestedFace=-1;
static const byte*CaptureFace(int face,int*size){requestedFace=face;return CL_CoF_FontFile(face,size);}
int main(){
 cof_vgui_font_t d={};assert(CL_CoF_FontDesc("credits",&d)&&d.semibold==2&&d.backing==0);
 int tall=d.logicalPx;assert(tall>0&&d.devicePx>tall);
 cof_hud_text_backing.value=120;assert(CL_CoF_FontDesc("credits",&d)&&d.semibold==2&&d.backing==120);
 assert(CL_CoF_FontDesc("pager",&d)&&d.semibold==0&&d.backing==120);
 assert(CL_CoF_FontDesc("chaptertitle",&d)&&d.semibold==1);
 assert(CL_CoF_FontDesc("inventory",&d)&&d.semibold==0&&d.backing==0);
 cof_hud_text_style.value=0;assert(CL_CoF_FontDesc("credits",&d)&&d.semibold==1&&d.backing==120);
 cof_hud_text_backing.value=0;assert(CL_CoF_FontDesc("credits",&d)&&d.semibold==1&&d.backing==0);
 cof_hud_text_style.value=1;info.gamefolder="other";assert(!CL_CoF_FontDesc("credits",&d));info.gamefolder="cryoffear";
 int size=0;missingBold=true;assert(CL_CoF_FontFile(2,&size)==fakefont&&size==16&&fileCalls==2);
 assert(CL_CoF_FontFile(2,&size)==fakefont&&fileCalls==2); // fallback cached too
 memset(&cof_font,0,sizeof(cof_font));missingBold=false;assert(CL_CoF_FontFile(2,&size)==fakefont&&fileCalls==3);
 g_engine->CofFontFile=CaptureFace;assert(CL_CoF_FontDesc("credits",&d)&&d.semibold==2);
 assert(CofFindOrCreate("credits",d)&&requestedFace==2); // actual VGUI cache forwards integer face, not bool
 cof_hud_text_style.value=0;assert(CL_CoF_FontDesc("credits",&d)&&d.semibold==1);
 assert(CofFindOrCreate("credits",d)&&requestedFace==1);cof_hud_text_style.value=1;
 int ink[4];CoF_TextStyleColor(255,255,255,255,1,ink);assert(ink[0]==191&&ink[1]==193&&ink[2]==194&&ink[3]==255);
 CoF_TextStyleColor(100,127,40,255,1,ink);assert(ink[3]==127);
 CoF_TextStyleColor(0,0,0,255,1,ink);assert(ink[3]==0);
 CoF_TextStyleColor(10,200,30,128,0,ink);assert(ink[3]==128);
 float x1,y1,x2,y2;int w;CoF_TextShadowTap(20,0,&x1,&y1,&w);assert(w==56);
 CoF_TextShadowTap(40,0,&x2,&y2,&w);assert(x2>x1&&y2>y1&&x2<3);
 cl_font_t font={20};rgba_t half={127,127,127,255};
 draws.clear();CL_CoF_DrawStyledHudChar(10,20,'A',half,&font,0,0);assert(draws.size()==5);
 for(auto d:draws)assert(d.r==24&&d.g==25&&d.b==27&&d.a<=28);
 assert(CL_CoF_DrawStyledHudChar(10,20,'A',half,&font,0,1)==7);assert(draws.back().a==127&&draws.back().r==191);
 vpoint_t a={{10,20},{0,0}},b={{20,40},{1,1}};int color[]={0,255,0,127};
 draws.clear();CofDrawStyledQuad(a,b,color,true,0,20);assert(draws.size()==5);
 for(auto d:draws)assert(d.r==24&&d.a>=227);
 CofDrawStyledQuad(a,b,color,true,1,20);assert(draws.back().a==127&&draws.back().r==191);
 draws.clear();color[3]=255;CofDrawStyledQuad(a,b,color,true,0,20);CofDrawStyledQuad(a,b,color,true,1,20);assert(draws.empty());
 color[3]=0;CofDrawStyledQuad(a,b,color,false,1,20);assert(draws.back().r==0&&draws.back().g==255&&draws.back().a==0);
 draws.clear();g_scissor.accept=false;CofDrawStyledQuad(a,b,color,true,0,20);CofDrawStyledQuad(a,b,color,true,1,20);assert(draws.empty());
 puts("PASS: independent background off/on under both styles, integer Bold face forwarding, cached fallback, both alpha models, scaled shadow, foreground and clipping");
}
'''
(out/'style.cpp').write_text(stub+header+'\n'+body+'\n'+checks)
(out/'run.cmd').write_text(f'@echo off\ncall "{a.vcvars}" >nul\nif errorlevel 1 exit /b 1\ncl /nologo /EHsc /W3 style.cpp /Fe:style.exe\nif errorlevel 1 exit /b 1\nstyle.exe\n')
subprocess.run(['cmd.exe','/d','/c','run.cmd'],cwd=out,check=True)
