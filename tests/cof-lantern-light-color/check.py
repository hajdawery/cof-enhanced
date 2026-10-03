"""Compile the applied production predicate and whitening block, then test retail selection.

Run in an x86 MSVC developer shell: python check.py SOURCE_ROOT OUTPUT_DIR
The negative control disables only the production predicate and must fail.
"""
from pathlib import Path
import re
import subprocess
import sys

source, output = map(Path, sys.argv[1:])
output.mkdir(parents=True, exist_ok=True)
frame = (source / 'engine/client/cl_frame.c').read_text()
helper = re.search(r'static qboolean CL_CoFPreserveLanternColor\(.*?\n\}', frame, re.S).group()
block = re.search(r'\t\tif\( ent->model->type != mod_brush && !CL_CoFPreserveLanternColor\( ent \)\).*?\n\t\t\}', frame, re.S).group()
prefix = r'''
#include <stdio.h>
#include <string.h>
typedef int qboolean;
#define Q_stricmp _stricmp
enum { mod_brush, mod_sprite, mod_studio };
typedef struct { unsigned char r,g,b; } color24;
typedef struct { int renderfx, renderamt; color24 rendercolor; } state_t;
typedef struct { int type; } model_t;
typedef struct { model_t *model; state_t curstate; } cl_entity_t;
static struct { float value; } cof_lantern_light_fix;
static struct { const char *gamefolder; } gameinfo;
#define GI (&gameinfo)
'''
suffix = r'''
/* Retail fx245: black RGB and amount 0/255 chooses 220 plus jitter.
   Any other combination uses renderamt plus the same jitter. Test jitter=0. */
static int radius(const cl_entity_t *e) {
 color24 c=e->curstate.rendercolor;
 return !c.r && !c.g && !c.b && (!e->curstate.renderamt || e->curstate.renderamt==255) ? 220 : e->curstate.renderamt;
}
static int failures;
static void check(const char *name,int enabled,const char *game,int model,int fx,int amt,int r,int g,int b,int er,int eg,int eb,int rad) {
 model_t m={model}; cl_entity_t e={&m,{fx,amt,{r,g,b}}};
 cof_lantern_light_fix.value=(float)enabled;gameinfo.gamefolder=game;normalize(&e);
 color24 c=e.curstate.rendercolor;
 if(c.r!=er || c.g!=eg || c.b!=eb || e.curstate.renderamt!=amt || radius(&e)!=rad) {printf("FAIL %s rgb=%d/%d/%d radius=%d\n",name,c.r,c.g,c.b,radius(&e));failures++;}
}
int main(void) {
 check("default zero",1,"cryoffear",mod_studio,245,0,0,0,0,0,0,0,220);
 check("default255",1,"cryoffear",mod_studio,245,255,0,0,0,0,0,0,220);
 check("optout",0,"cryoffear",mod_studio,245,0,0,0,0,255,255,255,0);
 check("other game",1,"valve",mod_studio,245,0,0,0,0,255,255,255,0);
 check("case insensitive",1,"CryOfFear",mod_studio,245,0,0,0,0,0,0,0,220);
 check("other effect",1,"cryoffear",mod_studio,165,0,0,0,0,255,255,255,0);
 check("ordinary sprite",1,"cryoffear",mod_sprite,0,0,0,0,0,255,255,255,0);
 check("brush unchanged",0,"cryoffear",mod_brush,245,0,0,0,0,0,0,0,220);
 check("near black",1,"cryoffear",mod_studio,245,0,0,1,0,0,1,0,0);
 check("explicit color",1,"cryoffear",mod_studio,245,123,20,30,40,20,30,40,123);
 check("explicit amount",1,"cryoffear",mod_studio,245,123,0,0,0,0,0,0,123);
 return failures ? 1 : 0;
}
'''
for negative in (False, True):
    name = 'negative' if negative else 'regression'
    selected = helper if not negative else 'static qboolean CL_CoFPreserveLanternColor(const cl_entity_t *ent) { return 0; }'
    c = output / (name + '.c')
    c.write_text(prefix + selected + '\nstatic void normalize(cl_entity_t *ent) {\n' + block + '\n}\n' + suffix)
    exe = output / (name + '.exe')
    subprocess.run(['cl', '/nologo', '/W4', str(c), '/Fo' + str(output / (name+'.obj')), '/Fe' + str(exe)], check=True)
    result = subprocess.run([str(exe)], capture_output=True, text=True)
    print(result.stdout, end='')
    assert result.returncode == (1 if negative else 0), (name, result.returncode)
print('PASS production extraction and expected-failing old-whitening control')
