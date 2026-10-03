# Copyright (C) 2026 Cry of Fear: Enhanced contributors
# SPDX-License-Identifier: GPL-3.0-or-later
"""Compile the real sound callbacks: tracing must not change forwarding/gates."""
import argparse, subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--source-root',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
def callback(rel, name):
    text=(a.source_root/rel).read_text()
    cvar='cof_step_trace_cl' if name=='ClientSound' else 'cof_step_trace_sv'
    assert f'Cvar_RegisterVariable( &{cvar} );' in text
    assert f'static CVAR_DEFINE_AUTO( {cvar}, "0", 0,' in text
    start=text.index('static void GAME_EXPORT pfnPlaySound(');end=text.index('{',start)+1;depth=1
    while depth:
        depth+=(text[end]=='{')-(text[end]=='}');end+=1
    return text[start:end].replace('pfnPlaySound(',name+'(')
code=r'''
#include <cassert>
#include <cstdarg>
#include <cstdio>
#include <cstring>
#define GAME_EXPORT
struct Cvar { float value; } cof_step_trace_cl{},cof_step_trace_sv{};
struct PM { int runfuncs=0,player_index=2; } pm;
struct Game { PM *pmove=&pm; } clgame,svgame;
struct edict_t {} ent;
enum { SND_FILTER_CLIENT=2048 };
int logs=0,plays=0,registrations=0,lastEnt=0,lastChan=0,lastPitch=0,lastFlags=0;
float lastVol=0,lastAttn=0;bool valid=true;
const char *lastSample=nullptr;
void Con_Printf(const char*,...){++logs;}
int S_RegisterSound(const char *sample){++registrations;lastSample=sample;return 42;}
void S_StartSound(const void *pos,int e,int ch,int handle,float vol,float attn,int pitch,int flags){assert(pos==nullptr&&handle==42);++plays;lastEnt=e;lastChan=ch;lastVol=vol;lastAttn=attn;lastPitch=pitch;lastFlags=flags;}
edict_t *SV_EdictNum(int n){lastEnt=n;return &ent;}
bool SV_IsValidEdict(edict_t *e){assert(e==&ent);return valid;}
void SV_StartSound(edict_t *e,int ch,const char *sample,float vol,float attn,int flags,int pitch){assert(e==&ent);++plays;lastChan=ch;lastSample=sample;lastVol=vol;lastAttn=attn;lastFlags=flags;lastPitch=pitch;}
'''
code+=callback('engine/client/dll_int/cl_pmove.c','ClientSound')+'\n'+callback('engine/server/sv_pmove.c','ServerSound')
code+=r'''
int main(){
for(int trace=0;trace<=2;trace++){
 cof_step_trace_cl.value=cof_step_trace_sv.value=(float)trace;
 logs=plays=registrations=0;pm.runfuncs=0;
 ClientSound(4,"player/step.wav",.2f,.8f,7,95);
 assert(plays==0&&registrations==0&&logs==(trace?1:0));
 pm.runfuncs=1;ClientSound(4,"player/step.wav",.2f,.8f,7,95);
 assert(plays==1&&registrations==1&&lastEnt==3&&lastChan==4&&lastVol==.2f&&lastAttn==.8f&&lastFlags==7&&lastPitch==95);
 assert(!strcmp(lastSample,"player/step.wav"));
 valid=false;ServerSound(4,"player/step.wav",.2f,.8f,7,95);assert(plays==1);
 valid=true;ServerSound(4,"player/step.wav",.2f,.8f,7,95);
 assert(plays==2&&lastFlags==(7|SND_FILTER_CLIENT)&&lastPitch==95&&lastVol==.2f&&lastAttn==.8f);
 assert(logs==(trace?4:0));
}
puts("PASS: disabled/enabled diagnostics preserve prediction guard, invalid-edict guard, sample and all sound parameters");
}
'''
source=a.out/'callbacks.cpp';source.write_text(code)
vc=Path('C:/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools/VC/Auxiliary/Build/vcvars64.bat')
bat=a.out/'run.cmd';bat.write_text(f'@echo off\ncall "{vc}" >nul\ncl /nologo /EHsc /std:c++17 "{source}" /Fe:"{a.out / "callbacks.exe"}" /Fo:"{a.out / "callbacks.obj"}"\nif errorlevel 1 exit /b 1\n"{a.out / "callbacks.exe"}"\n',newline='\r\n')
subprocess.run(['cmd','/d','/c',str(bat.resolve())],check=True)
