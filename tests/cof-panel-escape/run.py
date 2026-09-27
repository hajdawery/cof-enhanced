#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 haej (Cry of Fear: Enhanced contributors)
"""Compile real Escape dispatch and VGUI close selection against recording stubs."""
import argparse
from pathlib import Path
import subprocess

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--source-root',required=True,type=Path)
p.add_argument('--out',required=True,type=Path)
a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
engine=(a.source_root/'engine/client/input/in_keys.c').read_text()
vgui=(a.source_root/'3rdparty/freevgui/platform/xash3d-fwgs/cofpanels.cpp').read_text()
start=engine.index('static CVAR_DEFINE_AUTO( cof_panel_escape')
end=engine.index('// where the menu or the client edits',start)
engine_code=engine[start:end]
assert engine.index('Key_CoF_PanelEscape( key, down, kb )')<engine.index('if( cof_ui_input_gate.value && down')
assert engine.index('OSK_KeyEvent( key, down )')<engine.index('Key_CoF_PanelEscape( key, down, kb )')
capture_start=engine.index('    if( key>=0 && key<ARRAYSIZE(keys) && cof_panel_escape_down[key] )')
capture_end=engine.index('\n\tif( OSK_KeyEvent',capture_start)
capture_guard=engine[capture_start:capture_end]
assert capture_start<engine.index('OSK_KeyEvent( key, down )')
assert 'memset( cof_panel_escape_down, 0, sizeof( cof_panel_escape_down ));' in engine

engine_stub=r'''
#include <assert.h>
#include <string.h>
#include <stdio.h>
typedef int qboolean;
#define true 1
#define false 0
#define ARRAYSIZE(a) (sizeof(a)/sizeof((a)[0]))
#define Q_stricmp _stricmp
#define FCVAR_ARCHIVE 1
#define CVAR_DEFINE_AUTO(n,s,f,h) struct {float value;} n={1}
#define K_ESCAPE 27
#define K_START_BUTTON 180
#define key_game 0
#define ca_active 1
#define COF_PANEL_INVENTORY 1
#define COF_VGUI_PANEL_BACK 1
static struct {int gamedown,repeats,down;const char *binding;}keys[265];
static struct {int key_dest,state;}cls={0,1};
static struct {int background;}cl;
static struct {const char *gamefolder;} game={"cryoffear"},*GI=&game;
static int visible=1,report=1,classes=2,back=1,backs,forgets,events;
static int eventKey[8],eventDown[8];static const char *eventBind[8];
static int VGui_IsActive(void){return visible;}
static unsigned CL_CoF_PanelsOnScreen(qboolean *r){*r=report;return classes;}
static void VGui_CoF_ForgetKey(int key){forgets++;}
static int VGui_CoF_PanelAction(int action,char *info,int size){backs++;return back;}
static int Native(int down,int key,const char *binding){eventDown[events]=down;eventKey[events]=key;eventBind[events++]=binding;return 0;}
static struct {struct {int(*pfnKey_Event)(int,int,const char*);}dllFuncs;}clgame={{Native}};
'''
engine_code+='\nstatic int early_hooks; static void TestEarly(int key,int down) {\n'+capture_guard+'\nearly_hooks++;}\n'
engine_test=r'''
int main(void){
 assert(Key_CoF_PanelEscape(K_ESCAPE,1,"cancelselect"));assert(backs==1&&events==0);
 // A callback can close the pane and change focus. Repeat/release stay captured.
 classes=0;cls.key_dest=1;cof_panel_escape.value=0;
 assert(Key_CoF_PanelEscape(K_ESCAPE,1,"cancelselect"));assert(backs==1);
 assert(Key_CoF_PanelEscape(K_ESCAPE,0,"cancelselect"));assert(!cof_panel_escape_down[K_ESCAPE]);
 cls.key_dest=key_game;cof_panel_escape.value=1;assert(!Key_CoF_PanelEscape(K_ESCAPE,1,"cancelselect"));
 // Stock opt-out, ordinary gameplay, menu, background and missing report bypass.
 classes=2;cof_panel_escape.value=0;assert(!Key_CoF_PanelEscape(K_ESCAPE,1,""));cof_panel_escape.value=1;
 report=0;assert(!Key_CoF_PanelEscape(K_ESCAPE,1,""));report=1;cl.background=1;assert(!Key_CoF_PanelEscape(K_ESCAPE,1,""));cl.background=0;
 assert(!Key_CoF_PanelEscape(65,1,"+attack"));
 // Inventory uses its native binding, then releases internally; no pause action.
 back=0;classes=COF_PANEL_INVENTORY;assert(Key_CoF_PanelEscape(K_ESCAPE,1,""));assert(events==2&&eventDown[0]==1&&eventDown[1]==0&&!strcmp(eventBind[0],"+inventory"));
 assert(Key_CoF_PanelEscape(K_ESCAPE,0,""));events=0;
 // A panel above inventory receives native Escape instead of closing underneath.
 classes=3;assert(Key_CoF_PanelEscape(K_ESCAPE,1,""));assert(events==2&&eventKey[0]==K_ESCAPE&&!strcmp(eventBind[0],"cancelselect"));assert(Key_CoF_PanelEscape(K_ESCAPE,0,""));events=0;
 // START only when bound to Escape, without consulting controller availability.
 assert(!Key_CoF_PanelEscape(K_START_BUTTON,1,"+attack"));assert(Key_CoF_PanelEscape(K_START_BUTTON,1,"cancelselect"));assert(events==2);
 TestEarly(K_START_BUTTON,1);assert(early_hooks==0&&cof_panel_escape_down[K_START_BUTTON]);
 TestEarly(K_START_BUTTON,0);assert(early_hooks==0&&!cof_panel_escape_down[K_START_BUTTON]&&!keys[K_START_BUTTON].down);
 TestEarly(K_START_BUTTON,1);assert(early_hooks==1); // fresh press still reaches OSK/Enter first
 puts("PASS engine pane-first/focus-change/repeats/release/optout/inventory/native/START");
}
'''

start=vgui.index('struct CofBackRule')
end=vgui.index('// after a gamepad left click',start)
vgui_code=vgui[start:end]
vgui_stub=r'''
#include <cassert>
#include <cstdio>
#include <cstring>
#include <vector>
template<class T> struct Dar {std::vector<T> v;int getCount(){return (int)v.size();}T operator[](int i){return v[i];}};
struct ActionSignal {const char *cls;int cmd;};
struct Panel {const char *cls;bool visible=true,button=false;std::vector<Panel*> children;Panel *parent=nullptr;int rect[2]={10,10};Panel(const char *c):cls(c){}void add(Panel &p){children.push_back(&p);p.parent=this;}int getChildCount(){return (int)children.size();}Panel *getChild(int i){return children[i];}bool isVisible(){return visible;}};
struct Button:Panel {Dar<ActionSignal*> signals;int clicks=0;Button(ActionSignal &s):Panel("button"){button=true;signals.v.push_back(&s);}void doClick(){clicks++;if(parent)parent->visible=false;}};
struct CofButtonAccess{static Dar<ActionSignal*> &signals(Button *p){return p->signals;}};
struct CofPanelAccess{static const int *screenOrigin(Panel *p){return p->rect;}static const int *size(Panel *p){return p->rect;}};
struct CofHandler{const char *cls;int at4,at8;};
static bool CofReadHandler(ActionSignal *s,CofHandler &h){h={s->cls,s->cmd,s->cmd};return true;}
static bool CofIsButton(Panel *p){return p->button;}
#define COF_CLASS_PLAIN_PANEL 2
static int CofPanels_Class(Panel *p){return 1;}
static const char *CofRttiName(Panel *p,char *name,int size){return p->cls;}
struct Surface{Panel *panel;Panel *getPanel(){return panel;}};
static Surface *g_surface;
'''
vgui_test=r'''
int main(){
 Panel root("root"),view("viewport"),docs(".?AVCDocuments@@"),note(".?AVCNoteDocument@@"),user(".?AVCUserDocument@@"),keypad(".?AVCKeypad@@");root.add(view);view.add(docs);view.add(note);view.add(user);view.add(keypad);
 ActionSignal ds{".?AVCDocumentsHandler_Command@@",25},ns{".?AVCNoteDocumentHandler_Command@@",3},us{".?AVCUserDocumentHandler_Command@@",1},ks{".?AVCKeypadHandler_Command@@",1};
 Button db(ds),nb(ns),ub(us),kb(ks);docs.add(db);note.add(nb);user.add(ub);keypad.add(kb);nb.visible=false;ub.visible=false;kb.visible=false;user.visible=false;keypad.visible=false;
 Surface surf{&root};g_surface=&surf;char info[256];
 assert(CofPanelBack(info,sizeof(info))==1&&nb.clicks==1&&db.clicks==0&&!note.visible); // hidden note X native callback, before underlying list
 assert(CofPanelBack(info,sizeof(info))==1&&db.clicks==1); // next press closes underlying documents
 user.visible=true;assert(CofPanelBack(info,sizeof(info))==1&&ub.clicks==1);
 keypad.visible=true;assert(CofPanelBack(info,sizeof(info))==0&&kb.clicks==0); // hidden bypass never generic
 kb.visible=true;assert(CofPanelBack(info,sizeof(info))==1&&kb.clicks==1);
 note.visible=true;ns.cmd=4;assert(CofPanelBack(info,sizeof(info))==0&&nb.clicks==1); // wrong command cannot close
 ns.cmd=3;root.visible=false;assert(CofPanelBack(info,sizeof(info))==0);root.visible=true;view.visible=false;assert(CofPanelBack(info,sizeof(info))==0);
 puts("PASS VGUI layered note/userdoc/hidden exact close/other hidden rejection/ancestry");
}
'''

for name,code,suffix in [('engine',engine_stub+engine_code+engine_test,'.c'),('vgui',vgui_stub+vgui_code+vgui_test,'.cpp')]:
    source=a.out/(name+suffix);source.write_text(code)
    flag='/std:c11' if suffix=='.c' else '/std:c++17'
    subprocess.run(['cl','/nologo','/W3',flag,str(source.resolve()),'/Fe:'+name+'.exe'],cwd=a.out,check=True)
    subprocess.run([str((a.out/(name+'.exe')).resolve())],cwd=a.out,check=True)
