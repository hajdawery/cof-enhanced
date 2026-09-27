#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Cry of Fear: Enhanced contributors
"""Compile the actual HUD selector model/reload/change methods with event/cvar stubs."""
import argparse, pathlib, subprocess
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--source-root',type=pathlib.Path,required=True)
p.add_argument('--out',type=pathlib.Path,required=True)
a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
s=(a.source_root/'3rdparty/mainui/menus/AdvancedControls.cpp').read_text()
def method(signature):
 start=s.index(signature);return s[start:s.index('\n}',start)+2]
at=s.index('class CMenuCoFHudStyleModel');model=s[at:s.index('\n};',at)+3]
# Check integration points as well as running the actual data-plumbing methods.
assert 'if( UI_CoFOptionsLayout() ) ReloadHudStyle();' in s
assert 'hudStyle.onChanged = VoidCb( &CAdvancedControls::HudStyleChanged );' in s
assert 'if( UI_CoFOptionsLayout() ) AddItem( hudStyle );' in s
assert 'hudStyle.SetRect( right.pt.x, y, hudHalf, THEME_CTRL_H );' in s
source=r"""
#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <functional>
#include <string>
const char *L(const char *s){return s;}
struct CMenuBaseArrayModel{virtual void Update()=0;virtual int GetRows()const=0;virtual const char *GetText(int)=0;};
std::string cvar="0";int writes=0;bool layout=true;
bool UI_CoFOptionsLayout(){return layout;}
namespace EngFuncs{
const char *GetCvarString(const char*){return cvar.c_str();}
float GetCvarFloat(const char*){return (float)std::atof(cvar.c_str());}
void CvarSetValue(const char *name,float v){assert(std::strcmp(name,"cof_hud_style")==0);cvar=v==1?"1":"0";writes++;}
}
struct Spin {
 float value=-1;bool grayed=false;std::function<void()> changed;
 void SetGrayed(bool b){grayed=b;}float GetCurrentValue(){return value;}
 void SetCurrentValue(float v){bool notify=value!=v;value=v;if(notify)changed();}
};
class CAdvancedControls {
public:
 bool m_bCoF=true,m_bHudStyleLoading=false;Spin hudStyle;
 CAdvancedControls(){hudStyle.changed=[this](){HudStyleChanged();};}
 void ReloadHudStyle();void HudStyleChanged();
};
"""+model+'\n'+method('void CAdvancedControls::ReloadHudStyle(')+'\n'+method('void CAdvancedControls::HudStyleChanged(')+r"""
int main(){
 CMenuCoFHudStyleModel model;assert(model.GetRows()==2);assert(!std::strcmp(model.GetText(0),"Classic"));assert(!std::strcmp(model.GetText(1),"Remake"));
 CAdvancedControls page;page.ReloadHudStyle();assert(page.hudStyle.value==0&&!page.hudStyle.grayed&&writes==0);
 page.hudStyle.SetCurrentValue(1);assert(cvar=="1"&&writes==1);
 CAdvancedControls reopened;reopened.ReloadHudStyle();assert(reopened.hudStyle.value==1&&writes==1);
 reopened.hudStyle.SetCurrentValue(0);assert(cvar=="0"&&writes==2);
 cvar="1";reopened.ReloadHudStyle();assert(reopened.hudStyle.value==1&&writes==2);
 cvar="0";reopened.ReloadHudStyle();assert(reopened.hudStyle.value==0&&writes==2); // renderer default reset
 cvar="2";reopened.ReloadHudStyle();assert(reopened.hudStyle.value==0&&cvar=="2"&&writes==2); // never normalize on open
 reopened.hudStyle.SetCurrentValue(.5f);assert(cvar=="2"&&writes==2);
 cvar="";reopened.ReloadHudStyle();assert(reopened.hudStyle.grayed&&reopened.hudStyle.value==0&&writes==2);
 reopened.hudStyle.SetCurrentValue(1);assert(cvar.empty()&&writes==2);
 cvar="0";reopened.m_bCoF=false;reopened.hudStyle.SetCurrentValue(0);assert(writes==2);
 reopened.m_bCoF=true;layout=false;reopened.hudStyle.SetCurrentValue(1);assert(writes==2);
 puts("HUD selector: default/mappings/live change/reopen/reset/missing renderer/invalid values/event guard PASS");
}
"""
cpp=(a.out/'hud_style.cpp').resolve();exe=(a.out/'hud_style.exe').resolve();obj=(a.out/'hud_style.obj').resolve()
cpp.write_text(source,encoding='utf-8')
subprocess.run(['cl','/nologo','/EHsc','/W4',str(cpp),'/Fe:'+str(exe),'/Fo:'+str(obj)],check=True)
subprocess.run([str(exe)],check=True)
