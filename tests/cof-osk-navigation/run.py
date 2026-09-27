#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Cry of Fear: Enhanced contributors
"""Compile only OSK contract harnesses; no engine build or game launch.
Run in an MSVC developer shell: python run.py --source-root <patched tree> --out <scratch>.
The harness includes actual patched functions, replacing external APIs with stubs.
"""
import argparse
import pathlib
import subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--source-root', type=pathlib.Path, required=True)
p.add_argument('--out', type=pathlib.Path, required=True)
a = p.parse_args()
a.out.mkdir(parents=True, exist_ok=True)
vgui = (a.source_root / '3rdparty/freevgui/platform/xash3d-fwgs/cofosk.cpp').read_text()
context_enabled = 'CofOsk_FieldContext' in vgui
vgui = '\n'.join(line for line in vgui.splitlines() if not line.startswith('#include'))
stub = r"""
#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
namespace vgui {
struct Panel {
 Panel *parent = nullptr; std::vector<Panel*> children; bool visible = true, enabled = true; int x=0,y=0;
 virtual ~Panel() {} bool isVisible(){return visible;} bool isEnabled(){return enabled;}
 int getChildCount(){return (int)children.size();} Panel *getChild(int i){return children[i];}
 Panel *getParent(){return parent;} void getPos(int &ox,int &oy){ox=x;oy=y;}
 void add(Panel *p){children.push_back(p);p->parent=this;}
};
struct App {Panel *focus=nullptr,*requested=nullptr; void tick(){focus=requested;} static App *getInstance(){static App a;return &a;} Panel *getFocus(){return focus;}};
struct InputSignal {virtual void mousePressed(int,Panel*)=0; virtual void mouseReleased(int,Panel*)=0;};
const int MOUSE_LEFT=0;
struct TextEntry;
static void (*hook)(TextEntry*,int,bool);
struct TextEntry : Panel, InputSignal {
 std::string value; int presses=0,releases=0; bool accept=true;
 void getText(int,char *b,int n){std::snprintf(b,n,"%s",value.c_str());}
 void setText(const char *b,int n){value.assign(b,n);} void repaint(){}
 void mousePressed(int,Panel*) {presses++; if(accept){App::getInstance()->requested=this;hook(this,2,false);}}
 void mouseReleased(int,Panel*) {releases++;}
};
void TextEntry_SetCofOskHook(void (*h)(TextEntry*,int,bool)){hook=h;}
}
struct Engine {int (*CofOskCall)(int,char*,int)=nullptr;void (*CofOskEntry)(int,int,const char*)=nullptr;};
Engine engine; Engine *g_engine=&engine; vgui::Panel *g_rootPanel=nullptr;
"""
checks = ("\n#define HAS_FIELD_CONTEXT\n" if context_enabled else "") + r"""
int main(){
 Panel root, form, unrelated; root.add(&form);root.add(&unrelated);g_rootPanel=&root;
 TextEntry user, pass, hidden, disabled, alien;
 // Reverse construction order tests geometry rather than registry/child order.
 pass.y=231;user.y=204;hidden.y=210;disabled.y=220;alien.y=215;
 form.add(&pass);form.add(&user);form.add(&hidden);form.add(&disabled);unrelated.add(&alien);
 hidden.visible=false;disabled.enabled=false;
 for(auto e:{&pass,&user,&hidden,&disabled,&alien}) CofOsk_Hook(e,3,false);
 auto focus=[&](TextEntry *e){App::getInstance()->focus=e;App::getInstance()->requested=e;CofOsk_Hook(e,1,false);};
 focus(&user);
#ifdef HAS_FIELD_CONTEXT
 assert(CofOsk_Call(4,nullptr,0)==((2<<8)|1));
#endif
 char text[]="simon";assert(CofOsk_Call(0,text,sizeof text)==1);
 assert(CofOsk_Call(3,nullptr,0)==1);assert(App::getInstance()->getFocus()==&user);App::getInstance()->tick();assert(CofOsk_Focused()==&pass);assert(user.value=="simon");
 assert(pass.presses==1 && pass.releases==1);assert(alien.presses==0);
#ifdef HAS_FIELD_CONTEXT
 assert(CofOsk_Call(4,nullptr,0)==((2<<8)|2));
#endif
 assert(CofOsk_Call(3,nullptr,0)==0); // final field does not wrap
 focus(&user);form.enabled=false;assert(CofOsk_Call(3,nullptr,0)==-1);form.enabled=true;
 form.visible=false;assert(CofOsk_Call(3,nullptr,0)==-1);form.visible=true;
 App::getInstance()->focus=&form;assert(CofOsk_Call(3,nullptr,0)==-1);
 // Removed field retains stale focus address; neither write nor advance touches it.
 focus(&user);form.children.erase(form.children.begin()+1);assert(CofOsk_Call(0,text,sizeof text)==0);
 assert(CofOsk_Call(3,nullptr,0)==-1);
#ifdef HAS_FIELD_CONTEXT
 assert(CofOsk_Call(4,nullptr,0)==0);
#endif
 // A nested text field in another container is deliberately outside this form.
 Panel nested;form.add(&nested);TextEntry nestedEntry;nested.add(&nestedEntry);CofOsk_Hook(&nestedEntry,3,false);
 focus(&pass);assert(CofOsk_Call(3,nullptr,0)==0);
 puts("FreeVGUI: next/final/ordering/hidden/disabled/unrelated/stale/deferred-focus PASS");
}
"""
engine = (a.source_root / 'engine/client/cof_osk.c').read_text()
start = engine.index('qboolean CL_CoF_OskFrame( void )')
end = engine.index('\n/*', start)
frame = engine[start:end]
stub_engine = r"""
#include <cassert>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <string>
typedef bool qboolean;
struct Cvar {float value; const char *string;};
Cvar cof_osk_field_index={0,""},cof_osk_field_count={0,""},cof_osk_submit={0,""},cof_osk_result={0,""},cof_osk_next_field={1,""},cof_osk_field={0,""},cof_osk_hidden={0,""},cof_osk_over_game={0,""};
struct {bool pad_last,entry,hidden;int pending,reports;} osk_state;
enum {key_game,key_menu};struct {int key_dest;} cls;
const int COF_OSK_OPEN_DELAY=2;
int nextResult=0,advances=0,writes=0,pulses=0,opens=0;bool putOk=true,gameFocus=true,command=true;
bool CL_CoF_OskGameHasFocus(){return gameFocus;}
bool CL_CoF_OskPut(const char*){writes++;return putOk;}
int VGui_CoF_OskCall(int op,char *b,int n){if(op==4)return (2<<8)|2; if(op==3){advances++;return nextResult;} if(op==2){std::snprintf(b,n,"password");return 1;}return 0;}
bool Cmd_Exists(const char*){return command;}
void Cbuf_InsertText(const char *s){if(std::strstr(s,"cof_enter_pulse"))pulses++;if(std::strstr(s,"menu_cof_osk"))opens++;}
void Con_Reportf(const char*,...){}
void Cvar_DirectSet(Cvar *c,const char *s){c->string=s;c->value=(float)std::atoi(s);}
void CL_CoF_EnterOskDismiss(){}
void Cvar_DirectSetValue(Cvar *c,int value){c->value=(float)value;}
bool CL_CoF_OskOverGame(){return false;}
void reset(){cof_osk_submit.value=2;cof_osk_next_field.value=1;cof_osk_result.string="73696d6f6e";osk_state={};cls.key_dest=key_game;nextResult=0;advances=writes=pulses=opens=0;putOk=gameFocus=command=true;}
"""
checks_engine = ("\n#define NO_FORM_SUBMIT\n" if context_enabled else "") + r"""
int main(){
 reset();nextResult=1;CL_CoF_OskFrame();assert(writes==1&&advances==1&&pulses==0&&opens==0);
 assert(cof_osk_submit.value==0);CL_CoF_OskFrame();assert(opens==1&&pulses==0);
#ifdef NO_FORM_SUBMIT
 assert(cof_osk_field_index.value==2&&cof_osk_field_count.value==2);
#endif
 CL_CoF_OskFrame();assert(opens==1);
 reset();CL_CoF_OskFrame();
#ifdef NO_FORM_SUBMIT
 assert(pulses==0&&advances==1);CL_CoF_OskFrame();assert(pulses==0);
#else
 assert(pulses==1&&advances==1);CL_CoF_OskFrame();assert(pulses==1);
#endif
 reset();cof_osk_submit.value=1;CL_CoF_OskFrame();assert(writes==1&&advances==0&&pulses==0&&opens==0);
 reset();cof_osk_next_field.value=0;nextResult=1;CL_CoF_OskFrame();
#ifdef NO_FORM_SUBMIT
 assert(advances==0&&pulses==0);
#else
 assert(advances==0&&pulses==1);
#endif
 reset();putOk=false;CL_CoF_OskFrame();assert(advances==0&&pulses==0);
 reset();nextResult=-1;CL_CoF_OskFrame();assert(pulses==0&&opens==0);
 reset();gameFocus=false;CL_CoF_OskFrame();assert(advances==0&&pulses==0);
 reset();command=false;CL_CoF_OskFrame();assert(pulses==0);
 puts("Engine: next/reopen/final/Close/cvar-off/failed-write/lost-focus/no-hook PASS");
}
"""
for name, source in [('vgui',stub+vgui+checks),('engine',stub_engine+frame+checks_engine)]:
 cpp=(a.out/(name+'.cpp')).resolve(); exe=(a.out/(name+'.exe')).resolve(); obj=(a.out/(name+'.obj')).resolve()
 cpp.write_text(source)
 subprocess.run(['cl','/nologo','/EHsc','/W4',str(cpp),'/Fe:'+str(exe),'/Fo:'+str(obj)],check=True)
 subprocess.run([str(exe)],check=True)
