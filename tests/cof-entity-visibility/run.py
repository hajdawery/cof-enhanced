# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Cry of Fear: Enhanced contributors
"""Compile the actual packet callback/trace block; diagnostics must preserve dispatch."""
import argparse
from pathlib import Path
import subprocess
p=argparse.ArgumentParser()
p.add_argument('--source-root',type=Path,required=True)
p.add_argument('--out',type=Path,required=True)
a=p.parse_args();a.out=a.out.resolve();a.out.mkdir(parents=True,exist_ok=True)
s=(a.source_root/'engine/server/sv_frame.c').read_text()
start=s.index('\t\t// add entity to the net packet; call the DLL exactly once')
end=s.index('\n\t\tif( accepted )',start)
block=s[start:end]
gate_start=s.index('\tstatic double cof_visibility_next_log;')
gate_end=s.index('\n\t// during an error shutdown',gate_start)
gate=s[gate_start:gate_end]
code=r'''
#include <cassert>
#include <cstring>
#include <cstdarg>
#include <cstdio>
#include <string>
typedef bool qboolean;
struct Vars { const char *targetname="scene1_1", *classname="env_model", *model="actor.mdl"; int effects=128,flags=0,modelindex=9,sequence=1; float frame=3; };
struct edict_t { bool free=false; Vars v; } actor,client;
struct entity_state_t { int effects=128,modelindex=9,sequence=1; float frame=3; } packet;
struct Server { float time=7.5f; int hostflags=123; } sv;
int called=0,result=0,logs=0;
entity_state_t *expectedState=nullptr;
std::string output;
int FullPack(entity_state_t *state,int index,edict_t *ent,edict_t *cl,int hostflags,bool player,unsigned char *pset){
 ++called;assert(state==expectedState&&index==42&&ent==&actor&&cl==&client&&hostflags==123&&!player&&pset==nullptr);return result;
}
struct DLL { int (*pfnAddToFullPack)(entity_state_t*,int,edict_t*,edict_t*,int,bool,unsigned char*)=FullPack; };
struct Game { DLL dllFuncs; } svgame;
const char *SV_GetString(const char *s){return s?s:"";}
int Q_strcmp(const char*a,const char*b){return strcmp(a,b);}
int NUM_FOR_EDICT(edict_t *e){assert(e==&client);return 1;}
void Con_Printf(const char *fmt,...){++logs;char out[2048];va_list args;va_start(args,fmt);vsnprintf(out,sizeof(out),fmt,args);va_end(args);output+=out;}
struct Host { double realtime=0; } host;
const char *targetSetting=nullptr;
const char *Cvar_VariableString(const char *name){assert(!strcmp(name,"cof_entity_visibility_trace"));return targetSetting;}
bool Gate(bool from_client,const char *target,double now){
 targetSetting=target;host.realtime=now;
'''+gate+r'''
 return cof_visibility_log;
}
int Run(qboolean cof_visibility_log,const char *cof_visibility_target){
 entity_state_t *state=expectedState;edict_t *ent=&actor,*pClient=&client;int e=42;bool player=false;unsigned char *pset=nullptr;
'''+block+r'''
 return accepted;
}
int main(){
 assert(!Gate(true,nullptr,100));assert(!Gate(true,"",100));
 assert(!Gate(false,"scene1_1",100));assert(Gate(true,"scene1_1",100));
 assert(!Gate(true,"scene1_1",100.5));assert(Gate(true,"scene1_1",101));
 assert(Gate(true,"scene1_1",0));
 // Rejected callbacks are allowed to leave state entirely unavailable.
 // Null in this harness proves the trace does not inspect rejected output.
 for(int accept : {0,1,7}) for(bool trace : {false,true}) for(int match=0;match<4;match++){
  actor=edict_t{};called=logs=0;output.clear();result=accept;expectedState=accept?&packet:nullptr;
  const char *target="scene1_1";
  if(match==1)target="different";
  if(match==2)actor.v.targetname=nullptr;
  if(match==3)actor.free=true;
  const Vars before=actor.v;const entity_state_t packetBefore=packet;
  assert(Run(trace,target)==accept&&called==1);
  assert(!memcmp(&actor.v,&before,sizeof before)&&!memcmp(&packet,&packetBefore,sizeof packet));
  const int expectedLogs=trace&&match==0?(accept?2:1):0;
  assert(logs==expectedLogs);
  if(expectedLogs){
   assert(output.find("effects=0x80")!=std::string::npos);
   assert(output.find("client=1 ent=42 class=env_model target=scene1_1 model=actor.mdl")!=std::string::npos);
   assert((output.find("[cof-entity-packet]")!=std::string::npos)==(accept!=0));
  }
 }
 puts("PASS: 7 extracted trace-gate checks and 24 extracted callback cases: original return value, exactly one dispatch, all arguments unchanged, trace off/on, target mismatch, unnamed/free entities, and rejected packet output never read");
}
'''
source=a.out/'visibility.cpp';source.write_text(code)
vc=Path('C:/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools/VC/Auxiliary/Build/vcvars64.bat')
bat=a.out/'run.cmd'
bat.write_text(f'@echo off\ncall "{vc}" >nul\ncl /nologo /EHsc /std:c++17 "{source}" /Fe:"{a.out / "visibility.exe"}" /Fo:"{a.out / "visibility.obj"}"\nif errorlevel 1 exit /b 1\n"{a.out / "visibility.exe"}"\n',newline='\r\n')
subprocess.run(['cmd','/d','/c',str(bat)],check=True)
