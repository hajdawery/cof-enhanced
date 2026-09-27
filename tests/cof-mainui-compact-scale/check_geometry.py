#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Cry of Fear: Enhanced contributors
"""Source-level geometry audit; no compilation, game launch, or file writes.
Pass --source-root for the patched source tree. It must also contain the
unchanged CoFOptions.h (frame dimensions) and Framework.cpp (centering law).
"""
import argparse, math, re
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--source-root',type=Path,required=True)
a=p.parse_args();m=a.source_root/'3rdparty/mainui'
theme=(m/'Theme.cpp').read_text();header=(m/'Theme.h').read_text();base=(m/'BaseMenu.cpp').read_text()
osk=(m/'menus/CoFOsk.cpp').read_text();options=(m/'menus/CoFOptions.h').read_text();framework=(m/'controls/Framework.cpp').read_text()
def numeric(text,name):
    return float(re.search(r'^#define\s+'+name+r'\s+(\d+(?:\.\d+)?)',text,re.M)[1])
factor=float(re.search(r'CvarRegister\( "ui_cof_menu_scale", "([\d.]+)"',theme)[1])
assert .85 <= factor <= .90
assert base.index('UI_ThemeApplyMenuScale();') < base.index('uiStatic.width = ScreenWidth / uiStatic.scaleX;')
assert base.index('uiStatic.scaleX = uiStatic.scaleY = ScreenHeight / 768.0f;') < base.index('UI_ThemeApplyMenuScale();')
assert 'uiStatic.scaleX *= s_cofMenuScaleApplied;' in theme and 'uiStatic.scaleY *= s_cofMenuScaleApplied;' in theme
assert 'ScreenHeight / ( 2.0f * uiStatic.scaleY ) - 384.0f' in theme
assert '( uiStatic.width - panelSize.w ) / 2, ( 768 - panelSize.h ) / 2' in framework
assert 'uiStatic.scaleX /= applied;' in osk and 'uiStatic.scaleY /= applied;' in osk
assert '~CCoFOskNativeScale() { --Depth(); uiStatic.scaleX = m_x; uiStatic.scaleY = m_y; }' in osk
for signature in ('bool CMenuCoFOsk::KeyDown( int key )','void CMenuCoFOsk::VidInit( void )','void CMenuCoFOsk::Draw( void )'):
    assert signature+'\n{\n\tCCoFOskNativeScale nativeScale;' in osk
w=numeric(options,'COF_TAB_FRAME_W');h=numeric(options,'COF_TAB_FRAME_H')
osk_w=10*numeric(osk,'OSK_KEY_W')+9*numeric(osk,'OSK_KEY_GAP')+2*numeric(osk,'OSK_PAD')
osk_h=numeric(header,'THEME_TITLE_BAND_H')+3*numeric(osk,'OSK_PAD')+numeric(osk,'OSK_PREVIEW_H')+5*numeric(osk,'OSK_KEY_H')+4*numeric(osk,'OSK_KEY_GAP')
assert (osk_w,osk_h)==(508,292)
resolutions=((640,480),(1280,720),(1280,1024),(1920,1080),(2560,1440),(3840,2160),(5120,2160),(1080,1920))
for width,height in resolutions:
    native=min(width/1024,height/768)
    for setting in (factor,.75,1.):
        scale=native*setting
        canvas_width=int(width/scale)
        offset=int(height/(2*scale)-384)
        x=int((canvas_width-w)/2)*scale;y=(offset+int((768-h)/2))*scale
        assert x>=0 and y>=0 and x+w*scale<=width and y+h*scale<=height
        assert abs(x+w*scale/2-width/2)<=1.5*scale and abs(y+h*scale/2-height/2)<=scale
        assert math.isclose(w*scale/(w*native),setting) and math.isclose(h*scale/(h*native),setting)
        # Scoped OSK rendering and hit-test dimensions equal gamepad5 at any menu setting.
        keyboard_scale=scale/setting
        assert math.isclose(osk_w*keyboard_scale,osk_w*native)
        assert math.isclose(osk_h*keyboard_scale,osk_h*native)
        # Restoring captured values, rather than multiplying, prevents drift.
        saved=scale
        for _ in range(100):
            temporary=saved/setting
            assert math.isclose(temporary,native)
            restored=saved
            assert restored==scale
print(f'PASS: source guards, centered options at {len(resolutions)} resolutions x 3 scales, {100*len(resolutions)*3} OSK restore cycles')
print(f'Default options height: {h/768:.1%} -> {h*factor/768:.1%} of screen on 4:3/wide displays; OSK {int(osk_w)}x{int(osk_h)} unchanged')
