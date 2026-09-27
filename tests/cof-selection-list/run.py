#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Compile actual modal-list and spatial-navigation functions without opening the game."""
from pathlib import Path
import argparse, subprocess
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source-root',type=Path,required=True);p.add_argument('--out',type=Path,required=True)
a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
controls=a.source_root/'3rdparty/mainui/controls'
popup='\n'.join(l for l in (controls/'SelectionPopup.cpp').read_text().splitlines() if not l.startswith('#include'))
popup=popup.replace('private:','public:') # inspect pending selection; behavior remains real implementation
nav=(controls/'ItemsHolder.cpp').read_text();nav=nav[nav.index('struct cofNavBox_t'):nav.index('bool CMenuItemsHolder::AdjustCursor')]
stub=r'''
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <vector>
#include <algorithm>
using std::min;using std::max;
#define Q_min min
#define Q_max max
#define bound(a,x,b) max(a,min(x,b))
#define FBitSet(a,b) ((a)&(b))
#define QMF_GRAYED 1
#define QMF_INACTIVE 2
#define QMF_MOUSEONLY 4
#define QMF_HIDDENBYPARENT 8
#define QMF_CLOSING 16
#define QMF_HASKEYBOARDFOCUS 32
#define THEME_BODY_TALL 18
#define THEME_LABEL_TALL 14
#define THEME_TEXT 1
#define THEME_TEXT_DIM 2
#define THEME_TEXT_HI 3
#define THEME_DISABLED 4
#define THEME_INPUT_BG 5
#define THEME_INPUT_BORDER 6
#define THEME_ACCENT 7
#define THEME_PANEL 8
#define THEME_HOVER_FILL 9
#define UI_THEME_HOT(x) true
#define QM_LEFT 0
#define ETF_FORCECOL 1
#define ETF_NO_WRAP 2
#define ETF_NOSIZELIMIT 4
#define COF_NAV_STOCK -2
enum {K_UPARROW=1,K_DOWNARROW,K_LEFTARROW,K_RIGHTARROW,K_ENTER,K_ESCAPE,K_MOUSE1,K_MWHEELUP,K_MWHEELDOWN,K_HOME,K_END,K_TAB,K_SHIFT,K_LB};
struct Point{int x,y;Point(int a=0,int b=0):x(a),y(b){}};
struct Size{int w,h;Size(int a=0,int b=0):w(a),h(b){}};
static int ScreenWidth=1920,ScreenHeight=1080;
static struct {float scaleY=1;int cursorX=0,cursorY=0,hThemeBody=1,hThemeLabel=2;}uiStatic;
static bool enabled=true,shift=false;
static bool UI_CoFOptionsLayout(){return true;}
namespace EngFuncs{static float GetCvarFloat(const char*){return enabled;}static bool KEY_IsDown(int){return shift;}}
namespace UI{namespace Key{
static bool IsUpArrow(int k){return k==K_UPARROW;}static bool IsDownArrow(int k){return k==K_DOWNARROW;}
static bool IsLeftArrow(int k){return k==K_LEFTARROW;}static bool IsRightArrow(int k){return k==K_RIGHTARROW;}
static bool IsEnter(int k){return k==K_ENTER;}static bool IsEscape(int k){return k==K_ESCAPE;}static bool IsLeftMouse(int k){return k==K_MOUSE1;}
static bool IsHome(int k){return k==K_HOME;}static bool IsEnd(int k){return k==K_END;}}
namespace Scissor{static void PushScissor(Point,Size){}static void PopScissor(){}}}
template<class...T>static void UI_FillRect(T...){}template<class...T>static void UI_DrawHairline(T...){}
template<class...T>static void UI_DrawString(T...){}template<class...T>static void UI_ThemeDrawTriangle(T...){}
static bool UI_CursorInRect(Point p,Size s){return uiStatic.cursorX>=p.x&&uiStatic.cursorX<p.x+s.w&&uiStatic.cursorY>=p.y&&uiStatic.cursorY<p.y+s.h;}
class CMenuItemsHolder;
class CMenuBaseItem{public:int iFlags=0;bool visible=true;const char*szName="test";Point position;Size dimensions=Size(200,30);CMenuItemsHolder*parent=nullptr;
virtual ~CMenuBaseItem(){}virtual bool IsVisible()const{return visible;}Point GetRenderPosition()const{return position;}Size GetRenderSize()const{return dimensions;}CMenuItemsHolder*Parent(){return parent;}};
class CMenuItemsHolder:public CMenuBaseItem{public:std::vector<CMenuBaseItem*>items;CMenuBaseItem*focus=nullptr;int ItemCount(){return(int)items.size();}CMenuBaseItem*GetItemByIndex(int i){return items[i];}void SetCursorToItem(CMenuBaseItem&i){focus=&i;}};
class CMenuBaseWindow:public CMenuItemsHolder{public:Point m_scPos;Size m_scSize;bool opened=false;CMenuBaseWindow(const char*){}void Link(CMenuItemsHolder*p){parent=p;}void Show(){opened=true;VidInit();}void Hide(){opened=false;}void DisableTransition(){}virtual void VidInit(){}virtual void Draw(){}virtual bool KeyDown(int){return false;}virtual bool KeyUp(int){return false;}virtual bool MouseMove(int,int){return true;}};
typedef void(*cofSelectionText_t)(CMenuBaseItem*,int,char*,int);typedef void(*cofSelectionCommit_t)(CMenuBaseItem*,int);
'''
test=r'''
static int commits=0,value=2;
static void Text(CMenuBaseItem*,int n,char*b,int size){snprintf(b,size,"Choice %d",n);}
static void Commit(CMenuBaseItem*,int n){commits++;value=n;}
int main(){
 CMenuItemsHolder form;CMenuBaseItem item;item.parent=&form;item.position=Point(1600,1000);form.focus=&item;
 CCoFSelectionPopup pop;pop.Open(&item,40,2,Text,Commit);assert(pop.opened&&pop.rows==8&&pop.m_scPos.y<item.position.y);
 pop.KeyUp(K_ENTER);assert(pop.opened&&commits==0); // opener release never commits
 for(int i=0;i<20;i++)pop.KeyDown(K_DOWNARROW);
 assert(value==2&&commits==0&&pop.selected==22&&pop.first<=22&&pop.first+pop.rows>22);
 pop.KeyDown(K_LB);assert(pop.opened&&value==2); // no tab escape
 pop.KeyDown(K_ESCAPE);pop.KeyUp(K_ESCAPE);assert(!pop.opened&&value==2&&commits==0&&form.focus==&item);
 pop.Open(&item,40,value,Text,Commit);pop.KeyDown(K_DOWNARROW);pop.KeyDown(K_ENTER);pop.KeyUp(K_ENTER);assert(value==3&&commits==1&&!pop.opened);
 pop.Open(&item,40,value,Text,Commit);pop.KeyDown(K_END);assert(pop.selected==39&&pop.first+pop.rows==40);pop.Draw();
 uiStatic.cursorX=pop.m_scPos.x+10;uiStatic.cursorY=pop.m_scPos.y+pop.rowHeight+3;int expected=pop.first+1;pop.KeyDown(K_MOUSE1);pop.KeyUp(K_MOUSE1);assert(value==expected&&commits==2);
 pop.Open(&item,40,value,Text,Commit);uiStatic.cursorX=0;uiStatic.cursorY=0;pop.KeyDown(K_MOUSE1);pop.KeyUp(K_MOUSE1);assert(commits==2&&!pop.opened);
 pop.Open(&item,40,value,Text,Commit);item.iFlags=QMF_GRAYED;pop.Draw();assert(!pop.opened&&commits==2);item.iFlags=0;
 for(int height:{480,720,1080,2160}){ScreenHeight=height;item.position.y=height-35;pop.Open(&item,99,98,Text,Commit);assert(pop.m_scPos.y>=0&&pop.m_scPos.y+pop.m_scSize.h<=height&&pop.first+pop.rows==99);pop.KeyDown(K_ESCAPE);pop.KeyUp(K_ESCAPE);}
 // Game tab's alternating switches, input row, Language/HUD/scale, footer.
 std::vector<CMenuBaseItem> controls(16);form.items.clear();
 int coords[16][2]={{0,0},{500,0},{0,34},{500,34},{0,68},{500,68},{0,102},{500,102},{0,136},{0,176},{0,244},{500,244},{729,244},{0,400},{0,280},{10,500}};
 for(int i=0;i<16;i++){controls[i].position=Point(coords[i][0],coords[i][1]);form.items.push_back(&controls[i]);}controls[14].iFlags=QMF_INACTIVE;controls[15].iFlags=QMF_GRAYED;
 int cursor=0;for(int expected=1;expected<=14;expected++){cursor=UI_CoFNavTarget(&form,cursor,K_DOWNARROW,true);assert(cursor==expected%14);}assert(UI_CoFNavTarget(&form,0,K_UPARROW,true)==13);
 // General invariant covers every page shape: each usable field exactly once,
 // reversed Up traversal is the inverse, hidden/disabled/decorative skipped.
 for(int count=1;count<=160;count++){
  std::vector<CMenuBaseItem> fields(count);form.items.clear();std::vector<int>expected;
  for(int i=0;i<count;i++){fields[i].position=Point((i*17%7)*110,(i*13%19)*34);fields[i].visible=i%11!=3;fields[i].iFlags=i%13==5?QMF_INACTIVE:0;form.items.push_back(&fields[i]);if(UI_CoFNavUsable(&fields[i]))expected.push_back(i);}
  if(expected.empty())continue;cursor=expected[0];std::vector<int>seen;
  do{assert(std::find(seen.begin(),seen.end(),cursor)==seen.end());seen.push_back(cursor);int next=UI_CoFNavTarget(&form,cursor,K_DOWNARROW,true);assert(UI_CoFNavTarget(&form,next,K_UPARROW,true)==cursor);cursor=next;}while(cursor!=expected[0]);assert(seen.size()==expected.size());
 }
 puts("Actual dropdown cancel/confirm/scroll/mouse/focus/geometry + Game sequence + exhaustive1..160 traversal PASS");
}
'''
file=a.out/'selection.cpp';file.write_text(stub+'\n'+popup+'\n'+nav+'\n'+test)
subprocess.run(['cl','/nologo','/EHsc','/std:c++14',str(file.resolve()),'/Fe:selection.exe'],cwd=a.out,check=True)
subprocess.run([str((a.out/'selection.exe').resolve())],cwd=a.out,check=True)
