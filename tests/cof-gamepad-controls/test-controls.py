"""Compile actual patched functions in a bounded host harness, without a game build.

Usage: python test-controls.py --source-root <fully patched FWGS tree>
Requires MSVC Build Tools; outputs only under the ignored build-gamepad4-controls.
"""
from pathlib import Path
import argparse
import re
import subprocess

p = argparse.ArgumentParser()
p.add_argument('--source-root', type=Path, required=True)
p.add_argument('--vcvars', type=Path, default=Path(r'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat'))
args = p.parse_args()
root = Path(__file__).resolve().parents[2]
src = (args.source_root / 'engine/client/input/cof_gamepad.c').read_text()
out = root / 'build-gamepad4-controls/harness'
out.mkdir(parents=True, exist_ok=True)

def function(name, source=src):
    match = re.search(r'^(?:static )?[^\n]+\b' + name + r'\([^\n]*\)\n\{', source, re.M)
    assert match, name
    start = match.start()
    opening = source.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]

layouts = re.findall(r'static const cof_pad_bind_t cof_pad_layout(?:_gen\d)?\[\] =\n\{.*?\n\};', src, re.S)
assert len(layouts) == 5
keys = sorted(set(re.findall(r'\bK_\w+', '\n'.join(layouts))) - {'K_JOY1'})
header = r'''
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
typedef unsigned int uint;
typedef int qboolean;
#define true 1
#define false 0
#define ARRAYSIZE(a) (sizeof(a)/sizeof((a)[0]))
#define Q_stricmp _stricmp
#define Q_snprintf snprintf
#define COM_StringEmptyOrNULL(s) (!(s) || !(s)[0])
typedef struct { int key; const char *binding; } cof_pad_bind_t;
typedef struct { float value; const char *string; int flags; } convar_t;
static convar_t cof_pad_no_doubletap = {1, "1", 3};
static convar_t cof_pad_defaults_gen;
static convar_t guard = {0, "0.000", 7};
static convar_t cl_forwardspeed = {400}, cl_sidespeed = {400};
typedef struct {float forwardmove, sidemove;} usercmd_t;
static float CL_CoF_JoyPulseHysteresis(void) {return 0.25f;}
static void CL_CoF_PadMoveKeyThresholds(float *f,float *s) {(void)f;(void)s;}
static void CL_CoF_PadTracePulses(uint a,uint b,float f,float s) {(void)a;(void)b;(void)f;(void)s;}
#define F (1U << 0)
#define B (1U << 1)
#define L (1U << 2)
#define R (1U << 3)
#define T (1U << 4)
#define S (1U << 5)
static int missing, nested, calls;
static float expected;
static struct {char defaults_note[256];} cof_pad;
static char bindings[128][128];
static const char *Key_GetBinding(int k) { return bindings[k]; }
static void Key_SetBinding(int k, const char *s) { strcpy(bindings[k],s); }
static convar_t *Cvar_FindVar(const char *s) { return !missing && !strcmp(s,"cl_nodoubletapdodge") ? &guard : NULL; }
static void Cvar_DirectSet(convar_t *v,const char *s) { v->value=(float)atof(s); }
static void Cvar_DirectSetValue(convar_t *v,float f) {v->value=f;}
static void Con_Printf(const char *fmt,...) {(void)fmt;}
void CL_CoF_PadMoveCommand(const char *command);
static void Cmd_ExecuteString(const char *s) {
    (void)s; calls++;
    assert(guard.value == expected);
    if (nested) { nested=0; CL_CoF_PadMoveCommand("+back"); assert(guard.value == expected); }
}
'''
body = '\n'.join(function(n) for n in ['CL_CoF_PadAnyBound', 'CL_CoF_PadApplyLayout', 'CL_CoF_PadMoveCommand', 'CL_CoF_PadLayoutBind', 'CL_CoF_PadMigrate', 'CL_CoF_PadDefaultsCheck'])
input_src = (args.source_root / 'engine/client/input/input.c').read_text()
body += '\n' + function('IN_JoyAppendMove', input_src)
main = r'''
static void reset(int generation) {
    memset(bindings,0,sizeof(bindings));
    cof_pad_defaults_gen.value=(float)generation;
}
static void seed(const cof_pad_bind_t *a,int count) {
    for(int i=0;i<count;i++) Key_SetBinding(a[i].key,a[i].binding);
}
static void layout_test(const cof_pad_bind_t *old,int count,int gen) {
    reset(gen); seed(old,count); CL_CoF_PadDefaultsCheck();
    for(int i=0;i<ARRAYSIZE(cof_pad_layout);i++)
        assert(!strcmp(Key_GetBinding(cof_pad_layout[i].key),cof_pad_layout[i].binding));
    assert(cof_pad_defaults_gen.value==5);
    reset(gen); seed(old,count);
    Key_SetBinding(K_R1_BUTTON,"custom_command"); Key_SetBinding(K_RSTICK,"");
    CL_CoF_PadDefaultsCheck();
    assert(!strcmp(Key_GetBinding(K_R1_BUTTON),"custom_command"));
    assert(!strcmp(Key_GetBinding(K_RSTICK),""));
    reset(gen); CL_CoF_PadDefaultsCheck();
    for(int k=K_JOY1;k<=K_AUX30;k++) assert(!bindings[k][0]);
}
int main(void) {
    layout_test(cof_pad_layout_gen1,ARRAYSIZE(cof_pad_layout_gen1),1);
    layout_test(cof_pad_layout_gen2,ARRAYSIZE(cof_pad_layout_gen2),2);
    layout_test(cof_pad_layout_gen3,ARRAYSIZE(cof_pad_layout_gen3),3);
    layout_test(cof_pad_layout_gen4,ARRAYSIZE(cof_pad_layout_gen4),4);
    reset(0); CL_CoF_PadDefaultsCheck();
    assert(!strcmp(Key_GetBinding(K_R1_BUTTON),"+dodge"));
    assert(!strcmp(Key_GetBinding(K_RSTICK),"cof_quickturn"));
    reset(0); Key_SetBinding(K_R1_BUTTON,"custom"); CL_CoF_PadDefaultsCheck();
    assert(!strcmp(Key_GetBinding(K_R1_BUTTON),"custom"));
    assert(!Key_GetBinding(K_RSTICK)[0]);
    reset(5); CL_CoF_PadDefaultsCheck(); assert(!Key_GetBinding(K_R1_BUTTON)[0]);
    CL_CoF_PadApplyLayout(true); assert(!strcmp(Key_GetBinding(K_R1_BUTTON),"+dodge"));
    expected=1; nested=1; CL_CoF_PadMoveCommand("+forward");
    assert(calls==2 && guard.value==0 && guard.flags==7 && !strcmp(guard.string,"0.000"));
    guard.value=0.5f; CL_CoF_PadMoveCommand("-forward"); assert(guard.value==0.5f);
    guard.value=1; CL_CoF_PadMoveCommand("+moveleft"); assert(guard.value==1);
    guard.value=0; expected=0; cof_pad_no_doubletap.value=0;
    CL_CoF_PadMoveCommand("+forward"); assert(guard.value==0);
    cof_pad_no_doubletap.value=1; missing=1;
    CL_CoF_PadMoveCommand("+forward"); assert(guard.value==0);
    missing=0; Cmd_ExecuteString("+forward"); assert(guard.value==0);
    expected=1;
    for(int i=0;i<50;i++) {
        usercmd_t cmd={0};
        IN_JoyAppendMove(&cmd,1,1); assert(cmd.forwardmove==400 && cmd.sidemove==400);
        IN_JoyAppendMove(&cmd,0,0);
        IN_JoyAppendMove(&cmd,-1,-1); assert(cmd.forwardmove==-400 && cmd.sidemove==-400);
        IN_JoyAppendMove(&cmd,0,0);
        assert(guard.value==0);
    }
    puts("PASS: generation 0-5/default reset; four migrations/custom/cleared bindings; scoped/nested/missing/disabled guard; keyboard path; 200 actual stick transitions");
    return 0;
}
'''
generation = re.search(r'^#define COF_PAD_DEFAULTS_GENERATION \d+$', src, re.M).group()
harness = header + '\nenum { K_JOY1=1, ' + ', '.join(keys) + ', K_AUX30 };\n' + generation + '\n' + '\n'.join(layouts) + '\n' + body + '\n' + main
(out/'controls.c').write_text(harness)
(out/'run.cmd').write_text(f'@echo off\ncall "{args.vcvars}" >nul\nif errorlevel 1 exit /b 1\ncl /nologo /W3 /D_CRT_SECURE_NO_WARNINGS /TC controls.c /Fe:controls.exe\nif errorlevel 1 exit /b 1\ncontrols.exe\n')
subprocess.run(['cmd.exe', '/d', '/c', 'run.cmd'], cwd=out, check=True)
