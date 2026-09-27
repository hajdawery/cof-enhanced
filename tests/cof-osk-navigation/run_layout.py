#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Cry of Fear: Enhanced contributors
"""Compile compact OSK layout methods against recording draw/font stubs.
No menu build, renderer, or game launch. Run in an MSVC developer shell.
"""
import argparse
import pathlib
import re
import subprocess
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--source-root',type=pathlib.Path,required=True)
p.add_argument('--out',type=pathlib.Path,required=True)
a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
s=(a.source_root/'3rdparty/mainui/menus/CoFOsk.cpp').read_text()
def method(signature):
    start=s.index(signature)
    return s[start:s.index('\n}',start)+2]
native_scope=''
if 'class CCoFOskNativeScale' in s:
    at=s.index('class CCoFOskNativeScale')
    native_scope='#define HAS_NATIVE_SCOPE\nfloat appliedScale=1.0f; float UI_ThemeMenuScaleApplied(){return appliedScale;}\n'+s[at:s.index('\n};',at)+3]+'\n'
if not native_scope: native_scope='float appliedScale=1.0f; struct CCoFOskNativeScale{};\n'
theme=(a.source_root/'3rdparty/mainui/Theme.cpp').read_text()
at=theme.index('void UI_ThemeDrawDialogPanel(')
title_method=theme[at:theme.index('\n}',at)+2]
key_names=sorted(set(re.findall(r'\bK_[A-Z0-9_]+',method('bool CMenuCoFOsk::KeyDown('))))
key_enum='enum {'+','.join(key_names)+'};\n'
macros='\n'.join(line for line in s.splitlines() if line.startswith('#define OSK_'))
source=r"""
#include <cassert>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>
#include <algorithm>
#include <cmath>
#define Q_min std::min
#define Q_max std::max
#define THEME_TITLE_BAND_H 34
#define THEME_BODY_TALL 18
#define THEME_PAD_X 22
#define THEME_TITLE_TALL 17
#define THEME_PANEL_BORDER 0
#define THEME_TITLE_BAND 0
#define THEME_SEPARATOR 0
#define THEME_TITLE_TEXT 0
#define THEME_PANEL 0
#define THEME_TEXT_HI 0
#define QM_DRAWTRANS 0
#define QM_LEFT 0
#define ETF_FORCECOL 0
#define ETF_NO_WRAP 0
#define ETF_NOSIZELIMIT 0
struct Point{int x,y;Point(int a=0,int b=0):x(a),y(b){}};
struct Size{int w,h;Size(int a=0,int b=0):w(a),h(b){}};
int ScreenWidth,ScreenHeight;
struct {float scaleY,scaleX;int hThemeBody,hThemeTitle,cursorX,cursorY,realTime;} uiStatic;
std::string translation;
const char *L(const char*){return translation.c_str();}
bool UI_CoFPadMode(){return true;}
const char *UI_CoFPadGlyph(const char *a,const char*){return a;}
struct Font {int GetTextWideScaled(int,const char *s,int h){return (int)std::strlen(s)*h/2;}} font,*g_FontMgr=&font;
struct Rect{int x,y,w,h;};std::vector<Rect> draws;
void UI_FillRect(int x,int y,int w,int h,int){draws.push_back({x,y,w,h});}
void UI_DrawPic(int x,int y,int w,int h,int,const char*,int){draws.push_back({x,y,w,h});}
void UI_DrawString(int,int x,int y,int w,int h,const char*,int,int,int,int){draws.push_back({x,y,w,h});}
void UI_FillRect(Point p,Size z,int c){UI_FillRect(p.x,p.y,z.w,z.h,c);}
void UI_DrawHairline(Point,Size,int){}
void UI_ThemeSeparator(int,int,int,int){}
void UI_DrawString(int f,Point p,Size z,const char *s,int c,int h,int a,int flags){UI_DrawString(f,p.x,p.y,z.w,z.h,s,c,h,a,flags);}
struct Base {static void VidInit(){} static bool KeyDown(int){return false;}};
class CMenuCoFOsk {
public:
 typedef Base BaseClass;
 int m_px,m_py,m_pw,m_ph,m_gx,m_gy,m_kw,m_kh,m_kg;
 Point m_scPos;Size m_scSize;
 bool m_bOpen=true,m_bBCleared=false,m_bSymbols=false;int m_iBDownTime=0,m_iShift=0,m_iRow=0,m_iCol=0,m_iColMemo=0,closed=0;
 void Move(int,int){}void PressSelected(){}void Backspace(){}void Clear(){}void Type(int){}void Close(bool){closed++;}
 void VidInit();bool KeyRect(int,int,int&,int&,int&,int&) const;void DrawHints();bool KeyDown(int);bool HitTest(int,int,int&,int&)const;
};
"""+native_scope+key_enum+macros+"\n"+title_method+"\n"+method("bool CMenuCoFOsk::KeyDown(")+"\n"+method("bool CMenuCoFOsk::HitTest(")+"\n"+'\n'+method('void CMenuCoFOsk::VidInit( void )')+'\n'+method('bool CMenuCoFOsk::KeyRect(')+'\n'+method('void CMenuCoFOsk::DrawHints( void )')+r"""
int main(){
 int resolutions[][2]={{640,480},{1280,720},{1920,1080},{2560,1440},{3840,2160},{5120,2160}};
 for(auto &r:resolutions){
#ifdef HAS_NATIVE_SCOPE
 for(float factor:{0.75f,0.88f,1.0f}){
#else
 for(float factor:{1.0f}){
#endif
  ScreenWidth=r[0];ScreenHeight=r[1];const float native=(float)r[1]/768;appliedScale=factor;
  const float scaled=native*factor;uiStatic.scaleY=scaled;uiStatic.scaleX=scaled;
  CMenuCoFOsk osk;osk.VidInit();
  assert(uiStatic.scaleY==scaled&&uiStatic.scaleX==scaled);
  assert(std::abs(osk.m_pw-(int)(508*native))<=1);
  {CCoFOskNativeScale outer;const float active=uiStatic.scaleY;{CCoFOskNativeScale inner;assert(uiStatic.scaleY==active);}assert(uiStatic.scaleY==active);}
  assert(uiStatic.scaleY==scaled);
  draws.clear();{CCoFOskNativeScale draw;UI_ThemeDrawDialogPanel(Point(osk.m_px,osk.m_py),Size(osk.m_pw,osk.m_ph),"Field 1 of 2");}
  const int band=draws[1].h;assert(std::abs(band-(int)(34*native))<=1);
  uiStatic.cursorX=osk.m_px+osk.m_pw-1;uiStatic.cursorY=osk.m_py+band-1;
  osk.KeyDown(K_MOUSE1);assert(osk.closed==1&&uiStatic.scaleY==scaled);
  uiStatic.cursorY=osk.m_py+band;osk.KeyDown(K_MOUSE1);assert(osk.closed==1);
  osk.m_bOpen=false;osk.KeyDown(K_MOUSE1);assert(uiStatic.scaleY==scaled);osk.m_bOpen=true;
  assert(osk.m_px>=0&&osk.m_py>=0&&osk.m_px+osk.m_pw<=ScreenWidth&&osk.m_py+osk.m_ph<=ScreenHeight);
  assert(OSK_COLS*OSK_KEY_W+(OSK_COLS-1)*OSK_KEY_GAP+OSK_PAD*2==508);
  for(int row=0;row<5;row++)for(int col=0;col<(row==4?5:10);col++){
   int x,y,w,h;osk.KeyRect(row,col,x,y,w,h);
   assert(x>=osk.m_px&&y>=osk.m_py&&x+w<=osk.m_px+osk.m_pw&&y+h<=osk.m_py+osk.m_ph);
  }
  for(int length:{3,9,16,32}){
   translation=std::string(length,'W');draws.clear();{CCoFOskNativeScale draw;osk.DrawHints();}
   assert(draws.size()==18); // two row backgrounds plus eight glyph/label pairs
   for(auto &d:draws){assert(d.x>=osk.m_px&&d.x+d.w<=osk.m_px+osk.m_pw);assert(d.y>=osk.m_py+osk.m_ph&&d.y+d.h<=ScreenHeight);}
  }
 }
 }
 puts("Compact OSK layout: native-scale0.75/0.88/1, nested scopes, title/hit areas; panel/keys/two hint rows within bounds at 480p..2160p and ultrawide, long labels PASS");
}
"""
cpp=(a.out/'layout.cpp').resolve();exe=(a.out/'layout.exe').resolve();obj=(a.out/'layout.obj').resolve()
cpp.write_text(source)
subprocess.run(['cl','/nologo','/EHsc','/W4',str(cpp),'/Fe:'+str(exe),'/Fo:'+str(obj)],check=True)
subprocess.run([str(exe)],check=True)
