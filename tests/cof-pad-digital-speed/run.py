"""Compile actual shape/correction functions and model the proven retail packet branch."""
import argparse,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--source-root',type=Path,required=True);p.add_argument('--out',type=Path);a=p.parse_args()
r=Path(__file__).resolve().parents[2];out=(a.out or r/'pristine-pad-digital-speed-20260927/harness').resolve();out.mkdir(parents=True,exist_ok=True)
s=(a.source_root/'engine/client/input/cof_gamepad.c').read_text()
def fn(text,name):
 start=text.index('qboolean '+name) if name=='CL_CoF_PadMoveShape' else text.index('void '+name)
 end=text.index('{',start)+1;depth=1
 while depth:depth+=(text[end]=='{')-(text[end]=='}');end+=1
 return text[start:end]
shape=fn(s,'CL_CoF_PadMoveShape');fix=fn(s,'CL_CoF_PadMoveCorrectCommand')
before=(Path(__file__).parent/'legacy-shape.inc').read_text()
legacy=fn(before,'CL_CoF_PadMoveShape').replace('CL_CoF_PadMoveShape','LegacyShape')
stub=r'''
#include <cmath>
#include <cfloat>
#include <climits>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <limits>
#include <initializer_list>
#define Q_max(a,b) ((a)>(b)?(a):(b))
#define Q_min(a,b) ((a)<(b)?(a):(b))
#define bound(a,b,c) Q_min(Q_max(a,b),c)
#define M_PI_F 3.14159265358979323846f
#define IN_RUN 0x1000
#define Q_stricmp _stricmp
using qboolean=bool;
struct Cvar{float value;};
Cvar cof_pad_move_mode{1},cof_pad_move_fix{1},cof_pad_move_deadzone{.15f},cof_pad_move_walk{.6f},cof_pad_move_curve{1},cof_pad_move_diagonal{1.2f};
struct{bool move_saturated=false,move_digital_active=false;}cof_pad;
enum{JOY_AXIS_SIDE,JOY_AXIS_FWD};short raw[2];bool connected=true;
short Joy_CoF_AxisRaw(int axis){return raw[axis];}bool Joy_IsActive(){return connected;}
struct Game{const char*gamefolder;};Game game{"cryoffear"};Game*GI=&game;
struct PM{int flags=0;}pm;struct{PM*pmove=&pm;}clgame;
struct usercmd_t{float forwardmove=0,sidemove=0;unsigned buttons=0;};
'''
body=r'''
float speed(usercmd_t c,bool wire=false){if(wire){c.forwardmove=(float)(int)c.forwardmove;c.sidemove=(float)(int)c.sidemove;}if((c.buttons&IN_RUN)&&clgame.pmove&&(clgame.pmove->flags&0x40000))c.sidemove=0;else if(c.forwardmove&&c.sidemove)c.forwardmove*=.5f;return Q_min(300.f,std::hypot(c.forwardmove,c.sidemove))*.75f;}
usercmd_t sample(int f,int side){raw[JOY_AXIS_FWD]=(short)f;raw[JOY_AXIS_SIDE]=(short)side;float fw=0,sd=0;CL_CoF_PadMoveShape(&fw,&sd,1,1);usercmd_t c{fw*300,sd*200,0};CL_CoF_PadMoveCorrectCommand(&c,fw,sd);return c;}
void close(float a,float b,float eps=.001f){assert(std::fabs(a-b)<=eps);}
int main(){
 close(speed({306.8f,-23.2f,8}),116.3583f,.001f);close(speed({300,0,8}),225);
 auto screenshot=sample(-32768,-3716);close(speed(screenshot),225);close(speed(screenshot,true),225);
 auto cardinal=sample(-32768,0);close(cardinal.forwardmove,300);close(cardinal.sidemove,0);
 for(int sign:{-1,1}){auto near=sample(sign*32767,sign*64);close(speed(near),225,.3f);close(speed(near,true),225,1);}
 close(speed(sample(0,32767)),150);close(speed(sample(-23170,23170)),225);
 auto slow=sample(-8000,900);assert(speed(slow)>0&&speed(slow)<225);
 for(float mode:{0.f,2.f}){cof_pad_move_mode.value=mode;for(int f:{-32767,-8000,0,8000,32767})for(int x:{-32767,-2000,0,2000,32767}){raw[1]=(short)f;raw[0]=(short)x;float fa=0,sa=0,fb=0,sb=0;assert(CL_CoF_PadMoveShape(&fa,&sa,1,1)==LegacyShape(&fb,&sb,1,1));close(fa,fb);close(sa,sb);usercmd_t c{fa*300,sa*200,0},old=c;CL_CoF_PadMoveCorrectCommand(&c,fa,sa);close(c.forwardmove,old.forwardmove);close(c.sidemove,old.sidemove);}}
 cof_pad_move_mode.value=1;cof_pad_move_fix.value=0;raw[1]=-32768;raw[0]=-3716;float fa=0,sa=0,fb=0,sb=0;CL_CoF_PadMoveShape(&fa,&sa,1,1);LegacyShape(&fb,&sb,1,1);close(fa,fb);close(sa,sb);usercmd_t old{fa*300,sa*200,0};CL_CoF_PadMoveCorrectCommand(&old,fa,sa);close(speed(old),116.35f,.1f);
 cof_pad_move_fix.value=1;sample(-32768,-3716);
 for(float x:{-.99f,.99f}){usercmd_t c{300,x,0};CL_CoF_PadMoveCorrectCommand(&c,1,x);close(c.forwardmove,300);close(c.sidemove,0);close(speed(c),speed(c,true));}
 for(float x:{-1.f,1.f}){usercmd_t c{300,x,0};CL_CoF_PadMoveCorrectCommand(&c,1,x);close(c.forwardmove,600);close(speed(c),speed(c,true));}
 // Uncapped slow walking exposes packet branch errors hidden by maxspeed.
 for(float x:{-.99f,.99f,-1.f,1.f}){usercmd_t c{60,x,0};CL_CoF_PadMoveCorrectCommand(&c,.2f,x);close(speed(c),speed(c,true));close(speed(c),std::fabs(x)<1?45.f:45.00625f,.001f);}
 pm.flags=0x40000;usercmd_t slowSprint{60,25,IN_RUN};CL_CoF_PadMoveCorrectCommand(&slowSprint,.2f,.1f);close(slowSprint.forwardmove,60);close(speed(slowSprint),45);pm.flags=0;
 for(float x:{-.99f,.99f}){usercmd_t c{60,x,0};CL_CoF_PadMoveCorrectCommand(&c,.2f,x);close(c.forwardmove,60);close(c.sidemove,0);close(speed(c),45);close(speed(c,true),45);}
 for(float x:{-1.f,1.f}){usercmd_t c{60,x,0};CL_CoF_PadMoveCorrectCommand(&c,.2f,x);close(c.forwardmove,120);close(c.sidemove,x);close(speed(c),45.00625f);close(speed(c,true),45.00625f);}
 pm.flags=0x40000;usercmd_t partialSprint{60,25,IN_RUN};CL_CoF_PadMoveCorrectCommand(&partialSprint,.2f,.1f);close(partialSprint.forwardmove,60);close(speed(partialSprint),45);pm.flags=0;
 usercmd_t key{300,200,8};CL_CoF_PadMoveCorrectCommand(&key,0,0);close(key.forwardmove,300);
 connected=false;CL_CoF_PadMoveCorrectCommand(&key,1,1);close(key.forwardmove,300);connected=true;
 sample(0,0);CL_CoF_PadMoveCorrectCommand(&key,1,1);close(key.forwardmove,300);sample(0,32767);
 // Mixed keyboard-forward and active pad-side: inspect composed final axes.
 CL_CoF_PadMoveCorrectCommand(&key,0,1);close(key.forwardmove,600);
 pm.flags=0x40000;usercmd_t sprint{300,25,IN_RUN};CL_CoF_PadMoveCorrectCommand(&sprint,1,.1f);close(sprint.forwardmove,300);
 pm.flags=0;sprint={300,25,IN_RUN};CL_CoF_PadMoveCorrectCommand(&sprint,1,.1f);close(sprint.forwardmove,600);
 clgame.pmove=nullptr;sprint={300,25,IN_RUN};CL_CoF_PadMoveCorrectCommand(&sprint,1,.1f);close(sprint.forwardmove,600);clgame.pmove=&pm;
 usercmd_t bad{std::numeric_limits<float>::infinity(),20,0};CL_CoF_PadMoveCorrectCommand(&bad,1,1);assert(std::isinf(bad.forwardmove));bad.forwardmove=std::numeric_limits<float>::quiet_NaN();CL_CoF_PadMoveCorrectCommand(&bad,1,1);assert(std::isnan(bad.forwardmove));
 game.gamefolder="other";raw[1]=-32768;raw[0]=-3716;fa=sa=fb=sb=0;CL_CoF_PadMoveShape(&fa,&sa,1,1);LegacyShape(&fb,&sb,1,1);close(fa,fb);close(sa,sb);game.gamefolder="cryoffear";
 GI=nullptr;usercmd_t other{300,20,0};CL_CoF_PadMoveCorrectCommand(&other,1,1);close(other.forwardmove,300);
 puts("PASS: retail screenshot reproduction; corrected225; cardinal/nearaxis/signs/partial; mode0/2 and optout parity; wirezero boundaries; keyboardonly/mixed/centering/unplug; sprint flags/null; finite guards");
}
'''
source=out/'test.cpp';source.write_text(stub+'\n'+shape+'\n'+legacy+'\n'+fix+'\n'+body)
vc=r'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat'
command=f'call "{vc}" >nul && cl /nologo /EHsc /std:c++17 "{source}" /Fe:"{out / "test.exe"}" /Fo:"{out / "test.obj"}" && "{out / "test.exe"}"'
bat=out/'run.cmd';bat.write_text('@echo off\n'+command+'\n',newline='\r\n')
subprocess.run(['cmd','/d','/c',str(bat)],check=True)
