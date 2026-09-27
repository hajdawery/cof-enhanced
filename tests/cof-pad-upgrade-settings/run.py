#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Compile actual controller migration functions and layout tables."""
from pathlib import Path
import argparse,re,subprocess
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source-root',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
s=(a.source_root/'engine/client/input/cof_gamepad.c').read_text()
def function(name):
 m=re.search(r'^static [^\n]+\b'+name+r'\([^\n]*\)\n\{',s,re.M);assert m,name
 start=m.start();i=s.index('{',m.start());depth=1;j=i+1
 while depth:
  depth+=(s[j]=='{')-(s[j]=='}');j+=1
 return s[start:j]
tables='\n'.join(re.findall(r'static const cof_pad_bind_t cof_pad_layout(?:_gen[1-4])?\[\] =\n\{.*?\n\};',s,re.S));assert tables.count('static const')==5
keys=sorted(set(re.findall(r'\bK_\w+',tables))-{'K_JOY1','K_AUX30'})
stub=r"""
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>
typedef int qboolean;
typedef struct {float value;} convar_t;
typedef struct {int key;const char *binding;} cof_pad_bind_t;
#define ARRAYSIZE(x) (sizeof(x)/sizeof((x)[0]))
#define COM_StringEmptyOrNULL(x) (!(x)||!*(x))
#define Q_stricmp _stricmp
#define Q_snprintf snprintf
#define Con_Printf(...) ((void)0)
#define COF_PAD_DEFAULTS_GENERATION 5
static convar_t cof_pad_defaults_gen,gyro;
static struct {char defaults_note[512];} cof_pad;
static char bindings[128][128];static int writes;
static const char *Key_GetBinding(int k){return bindings[k];}
static void Key_SetBinding(int k,const char*v){strcpy(bindings[k],v);writes++;}
static convar_t*Cvar_FindVar(const char*n){assert(!strcmp(n,"joy_gyro_enable"));return &gyro;}
static void Cvar_DirectSet(convar_t*c,const char*s){c->value=(float)atof(s);}
static void Cvar_DirectSetValue(convar_t*c,float v){c->value=v;}
"""
code=stub+'\nenum { K_JOY1=1,'+','.join(keys)+',K_AUX30=100 };\n'+tables+'\n'+'\n'.join(function(n) for n in ['CL_CoF_PadAnyBound','CL_CoF_PadApplyLayout','CL_CoF_PadLayoutBind','CL_CoF_PadMigrate','CL_CoF_PadDefaultsCheck'])
code+=r"""
int main(void){
 const cof_pad_bind_t*older[]={cof_pad_layout_gen1,cof_pad_layout_gen2,cof_pad_layout_gen3,cof_pad_layout_gen4};
 int counts[]={ARRAYSIZE(cof_pad_layout_gen1),ARRAYSIZE(cof_pad_layout_gen2),ARRAYSIZE(cof_pad_layout_gen3),ARRAYSIZE(cof_pad_layout_gen4)};
 for(int gen=0;gen<=6;gen++)for(int saved=0;saved<=1;saved++){
  memset(bindings,0,sizeof(bindings));gyro.value=(float)saved;cof_pad_defaults_gen.value=(float)gen;
  if(gen>=1&&gen<=4)for(int i=0;i<counts[gen-1];i++)Key_SetBinding(older[gen-1][i].key,older[gen-1][i].binding);
  Key_SetBinding(K_A_BUTTON,"custom_jump");Key_SetBinding(K_B_BUTTON,"");Key_SetBinding(110,"custom_keyboard");writes=0;
  CL_CoF_PadDefaultsCheck();assert(gyro.value==saved);assert(!strcmp(bindings[K_A_BUTTON],"custom_jump"));assert(!bindings[K_B_BUTTON][0]);assert(!strcmp(bindings[110],"custom_keyboard"));
  if(gen==0||gen>=5)assert(writes==0);
  if(gen>=1&&gen<=4)for(int i=0;i<counts[gen-1];i++){int k=older[gen-1][i].key;if(k==K_A_BUTTON||k==K_B_BUTTON)continue;const char*want=CL_CoF_PadLayoutBind(cof_pad_layout,ARRAYSIZE(cof_pad_layout),k);assert(!strcmp(bindings[k],want?want:""));}
  writes=0;CL_CoF_PadDefaultsCheck();assert(writes==0&&gyro.value==saved);
 }
 memset(bindings,0,sizeof(bindings));cof_pad_defaults_gen.value=0;gyro.value=0;Key_SetBinding(K_START_BUTTON,"cancelselect");CL_CoF_PadDefaultsCheck();assert(gyro.value==0);for(int i=0;i<ARRAYSIZE(cof_pad_layout);i++)assert(!strcmp(bindings[cof_pad_layout[i].key],cof_pad_layout[i].binding));
 puts("PASS: generation 0..6, gyro 0/1, custom/cleared/keyboard binds, legacy default migration, fresh defaults, idempotence");return 0;
}
"""
f=a.out/'migration.c';f.write_text(code);subprocess.run(['cl','/nologo','/W3','/std:c11',str(f.resolve()),'/Fe:migration.exe'],cwd=a.out,check=True);subprocess.run([str((a.out/'migration.exe').resolve())],cwd=a.out,check=True)
