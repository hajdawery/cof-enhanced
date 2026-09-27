"""Extract and compile the real Enter guard with host input stubs; no game/OS input."""
import argparse
from pathlib import Path
import re
import subprocess

p=argparse.ArgumentParser()
p.add_argument('--source-root',type=Path,required=True)
p.add_argument('--vcvars',type=Path,default=Path(r'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat'))
a=p.parse_args()
root=Path(__file__).resolve().parents[2]
out=root/'build-osk-dismiss-guard/harness'
out.mkdir(parents=True,exist_ok=True)
src=(a.source_root/'engine/client/cof_enter_hook.c').read_text()

def function(name):
    m=re.search(r'^(?:static )?[^\n]+\b'+name+r'\([^\n]*\)\n\{',src,re.M)
    assert m,name
    b=src.index('{',m.start()); end=b+1; depth=1
    while depth:
        depth+=(src[end]=='{')-(src[end]=='}');end+=1
    return src[m.start():end]

state=src[src.index('static struct'):src.index('} cof_enter = { 0 };')+len('} cof_enter = { 0 };')]
stub=r'''
#include <assert.h>
#include <stdio.h>
#include <string.h>
typedef int qboolean;
typedef short SHORT;
typedef void *HMODULE;
typedef unsigned long ULONG_PTR;
#define WINAPI
#define XASH_WIN32 1
#define true 1
#define false 0
#define VK_RETURN 13
#define COF_ENTER_POLL_RECENT 0.25
#define COF_ENTER_PULSE_LIFE 2.0
#define Con_Reportf(...) ((void)0)
#define _ReturnAddress() 0
enum {K_ENTER=10,K_KP_ENTER,K_START_BUTTON,key_game=20,key_menu,ca_active=30};
struct {float value;} cof_osk_dismiss_guard={1},cof_enter_pad={1},cof_enter_trace={0},host_developer={0};
struct {double realtime;int framecount;} host={10,1};
struct {int key_dest,state;} cls={key_game,ca_active};
static int keys[64],osk,gate;
static SHORT real_return;
static SHORT GetAsyncKeyState(int k){return k==VK_RETURN?real_return:123;}
static int Key_IsDown(int k){return keys[k];}
static int CL_CoF_UIGateActive(void){return gate;}
static int CL_CoF_OskOverGame(void){return osk;}
'''
body='\n'.join(function(n) for n in ['CL_CoF_EnterOskDismiss','CL_CoF_EnterArm','CoF_Enter_GetAsyncKeyState','CL_CoF_EnterKeyEvent'])
checks=r'''
static void reset(void){
 memset(&cof_enter,0,sizeof(cof_enter));memset(keys,0,sizeof(keys));
 cof_enter.hooked=1;cof_enter.last_poll=10;cls.key_dest=key_game;cls.state=ca_active;
 cof_osk_dismiss_guard.value=cof_enter_pad.value=1;osk=gate=0;real_return=0;
}
static int event(int key,int down){
 int used=CL_CoF_EnterKeyEvent(key,down);
 if(!used)keys[key]=down;
 return used;
}
static void close_with(int key){
 reset();osk=gate=1;cls.key_dest=key_menu;
 if(key!=K_START_BUTTON)real_return=(SHORT)0x8000;
 assert(!event(key,1)); // first press reaches MainUI Done
 osk=gate=0;cls.key_dest=key_game;
 assert(event(key,1)); // repeat in the SAME event batch cannot reach client
 assert(!cof_enter.pulse);
 CL_CoF_EnterOskDismiss(); // result consumed next paint
 for(int i=0;i<20;i++){
   assert(event(key,1)); assert(!cof_enter.pulse);
   assert(CoF_Enter_GetAsyncKeyState(VK_RETURN)==0);
 }
 assert(!event(key,0)); // engine gets release to clear its bookkeeping
 real_return=1; // Windows low transition bit must not submit either
 if(key!=K_START_BUTTON)assert(CoF_Enter_GetAsyncKeyState(VK_RETURN)==0);
 real_return=0;CoF_Enter_GetAsyncKeyState(VK_RETURN);
 assert(!keys[key]);
 if(key==K_START_BUTTON){assert(event(key,1));assert(cof_enter.pulse);assert(CoF_Enter_GetAsyncKeyState(VK_RETURN)&0x8000);}
 else {assert(!event(key,1));real_return=(SHORT)0x8000;assert(CoF_Enter_GetAsyncKeyState(VK_RETURN)&0x8000);}
}
int main(void){
 close_with(K_ENTER);close_with(K_KP_ENTER);close_with(K_START_BUTTON);
 // Release and a fresh press may share an event batch with no intervening poll.
 reset();osk=1;cls.key_dest=key_menu;real_return=(SHORT)0x8000;
 assert(!event(K_ENTER,1));osk=0;cls.key_dest=key_game;CL_CoF_EnterOskDismiss();
 assert(!event(K_ENTER,0));assert(!event(K_ENTER,1));
 assert(CoF_Enter_GetAsyncKeyState(VK_RETURN)&0x8000);
 reset();cof_enter.pulse=cof_enter.held=1;CL_CoF_EnterOskDismiss();
 assert(!cof_enter.pulse&&!cof_enter.held);assert(CoF_Enter_GetAsyncKeyState(VK_RETURN)==0);
 // Done clicked with a mouse while Enter is physically down but no SDL event.
 reset();real_return=(SHORT)0x8000;CL_CoF_EnterOskDismiss();assert(CoF_Enter_GetAsyncKeyState(VK_RETURN)==0);
 real_return=0;assert(CoF_Enter_GetAsyncKeyState(VK_RETURN)==0);
 real_return=(SHORT)0x8000;assert(CoF_Enter_GetAsyncKeyState(VK_RETURN)&0x8000);
 // Other keys / the game's explicit button are not routed through this guard.
 assert(CoF_Enter_GetAsyncKeyState(42)==123);assert(!event(42,1));
 // Cvar off retains previous behavior; ordinary keyboard/menu behavior is unchanged.
 reset();cof_osk_dismiss_guard.value=0;cof_enter.pulse=1;CL_CoF_EnterOskDismiss();assert(cof_enter.pulse);
 reset();real_return=(SHORT)0x8000;assert(CoF_Enter_GetAsyncKeyState(VK_RETURN)&0x8000);
 gate=1;assert(CoF_Enter_GetAsyncKeyState(VK_RETURN)==0);gate=0;
 assert(CoF_Enter_GetAsyncKeyState(VK_RETURN)&0x8000);
 puts("PASS: Enter/keypad/START Done, same-batch and held repeats, releases/fresh confirms, stale synthetic state, raw Enter, cvar fallback");
 return 0;
}
'''
(out/'guard.c').write_text(stub+state+'\n'+body+'\n'+checks)
(out/'run.cmd').write_text(f'@echo off\ncall "{a.vcvars}" >nul\nif errorlevel 1 exit /b 1\ncl /nologo /W3 /TC guard.c /Fe:guard.exe\nif errorlevel 1 exit /b 1\nguard.exe\n')
subprocess.run(['cmd.exe','/d','/c','run.cmd'],cwd=out,check=True)
