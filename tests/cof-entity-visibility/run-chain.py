# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Cry of Fear: Enhanced contributors
"""Compile real target-name enumeration with the real x86 legacy edict layout."""
import argparse,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--source-root',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out=a.out.resolve();a.out.mkdir(parents=True,exist_ok=True);a.source_root=a.source_root.resolve()
s=(a.source_root/'engine/server/sv_game.c').read_text()
start=s.index('static const TYPEDESCRIPTION gEntvarsDescription[]');end=s.index('};',start)+2;table=s[start:end]
start=s.index('static edict_t *GAME_EXPORT SV_FindEntityByString(');end=s.index('{',start)+1;depth=1
while depth:depth+=(s[end]=='{')-(s[end]=='}');end+=1
lookup=s[start:end]
code=r'''
#include <cassert>
#include <cstdio>
#include <cstring>
#include <cstddef>
#include <cstdint>
#include <initializer_list>
typedef float vec3_t[3];typedef int qboolean;typedef unsigned char byte;
typedef struct edict_s edict_t;

#define XASH_COF_ENTVARS_LEGACY 1
#include "edict.h"
#define GAME_EXPORT
#define S_ERROR ""

#define ASSERT assert
#define COM_StringEmptyOrNULL(x) (!(x)||!(x)[0])
#define Q_strcmp strcmp
#define Con_Printf printf
enum {FIELD_STRING,FIELD_MODELNAME,FIELD_SOUNDNAME};
struct TYPEDESCRIPTION {int fieldType;const char *fieldName;size_t fieldOffset;};
#define DEFINE_ENTITY_FIELD(name,type) {type,#name,offsetof(entvars_t,name)}
edict_t edicts[12]{};char strings[256]="";
struct Globals {const char *pStringBase=strings;} globals;
struct Game {int numEntities=12;edict_t *edicts=::edicts;Globals *globals=::&globals;} svgame;
struct ServerStatic {int maxclients=1;} svs;
const char *SV_GetString(string_t n){return strings+n;}
int NUM_FOR_EDICT(edict_t *p){return int(p-edicts);}
edict_t *SV_EdictNum(int i){return &edicts[i];}
bool SV_IsValidEdict(edict_t *p){return p&&!p->free;}
void *SV_ClientFromEdict(edict_t*,bool){return nullptr;}
'''.replace('::&globals','&::globals')+table+'\n'+lookup+r'''
int main(){
 static_assert(sizeof(void*)==4,"must exercise x86 layout");
 static_assert(sizeof(edict_t)==0x32C,"retail edict stride");
 static_assert(offsetof(edict_t,v)==0x80,"retail entvars start");
 static_assert(offsetof(entvars_t,effects)==0x118,"retail effects");
 static_assert(offsetof(entvars_t,target)==0x1CC,"retail target");
 static_assert(offsetof(entvars_t,targetname)==0x1D0,"retail targetname");
 static_assert(offsetof(entvars_t,pContainingEntity)==0x20C,"retail containing edict");
 strcpy(strings+1,"multispawnhe");strcpy(strings+32,"scene1_1");strcpy(strings+64,"env_model");
 for(auto &e:edicts)e.free=1;
 // Discontiguous, same-name managers; do not stop at the first match.
 for(int n : {2,5,7,10}){edicts[n].free=0;edicts[n].v.targetname=1;}
 edicts[3].v.targetname=1; // freed matching entity must be skipped
 edicts[1].free=0;edicts[1].v.targetname=1; // disconnected client is skipped
 edict_t *previous=nullptr;
 for(int n : {2,5,7,10}){previous=SV_FindEntityByString(previous,"targetname","multispawnhe");assert(previous==&edicts[n]);}
 assert(SV_FindEntityByString(previous,"targetname","multispawnhe")==edicts);
 // Actor and manager share a name too; actual header offsets address the right string fields.
 edicts[5].v.targetname=32;edicts[7].v.targetname=32;edicts[5].v.classname=64;
 assert(SV_FindEntityByString(nullptr,"targetname","scene1_1")==&edicts[5]);
 assert(SV_FindEntityByString(&edicts[5],"targetname","scene1_1")==&edicts[7]);
 assert(SV_FindEntityByString(nullptr,"classname","env_model")==&edicts[5]);
 assert(SV_FindEntityByString(nullptr,"targetname",nullptr)==edicts);
 assert(SV_FindEntityByString(nullptr,"targetname","")==edicts);
 assert(SV_FindEntityByString(nullptr,"targetname","missing")==edicts);
 puts("PASS: real x86 entvars/edict offsets and real target-name lookup enumerate every matching manager, skip freed/disconnected entities, preserve world sentinel");
}
'''
source=a.out/'chain.cpp';source.write_text(code)
vc=Path('C:/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools/VC/Auxiliary/Build/vcvarsall.bat')
bat=a.out/'run-chain.cmd';bat.write_text(f'@echo off\ncall "{vc}" amd64_x86 >nul\ncl /nologo /EHsc /std:c++17 /I"{a.source_root / "engine"}" /I"{a.source_root / "common"}" "{source}" /Fe:"{a.out / "chain.exe"}" /Fo:"{a.out / "chain.obj"}"\nif errorlevel 1 exit /b 1\n"{a.out / "chain.exe"}"\n',newline='\r\n');subprocess.run(['cmd','/d','/c',str(bat)],check=True)
