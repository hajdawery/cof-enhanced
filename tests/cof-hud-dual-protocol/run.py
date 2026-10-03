#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Cry of Fear: Enhanced contributors
"""Run real HUD code and the existing ammo suite with measured retail packets."""
import argparse
import ast
from pathlib import Path
import subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--source-root', type=Path, required=True)
p.add_argument('--out', type=Path, required=True)
a = p.parse_args()
a.out.mkdir(parents=True, exist_ok=True)
root = Path(__file__).resolve().parents[2]
tree = ast.parse((root / 'tests/cof-hud-ammo/run.py').read_text())
parts = {n.targets[0].id: ast.literal_eval(n.value) for n in tree.body
         if isinstance(n, ast.Assign) and isinstance(n.targets[0], ast.Name)
         and n.targets[0].id in ('stub', 'test')}
code = (a.source_root / 'engine/client/cof_hud_remake.c').read_text()
code = '\n'.join(line for line in code.splitlines() if not line.startswith('#include'))
checks = r'''
 // Actual hl.dll active path: WRITE_STRING, three WRITE_BYTE, MESSAGE_END.
 cof_hud_style.value=1;cof_hud_dual_protocol.value=1;
 CL_CoF_HudRemakeReset();current(15,-1);
 byte active[]={'m','o','d','e','l',0,0,3,2};
 CL_CoF_HudRemakeMessage("DualWield",sizeof(active),active);
 int actualClips[2]={7,-1};CL_CoF_HudRemakeMessage("DualAmmo",8,(byte*)actualClips);
 begin();assert(hud.collecting && hud.dual_id[0]==3 && hud.dual_id[1]==2);
 assert(sprite("sprites/cof_glock_mag.spr"));CL_CoF_HudRemakeAmmo();
 assert(has("7") && has("GLOCK  SEMI"));
 // Both hands, two guns and utility variants use the same three-byte suffix.
 active[7]=2;active[8]=3;CL_CoF_HudRemakeMessage("DualWield",sizeof(active),active);
 assert(hud.dual_id[0]==2&&hud.dual_id[1]==3);
 active[7]=7;active[8]=3;CL_CoF_HudRemakeMessage("DualWield",sizeof(active),active);
 begin();assert(hud.collecting&&hud.dual_id[0]==7);
 // Truncated, unterminated, trailing-byte and unsupported IDs never overread.
 for(int n=0;n<(int)sizeof(active);n++){
  hud.dual_id[0]=0;hud.dual_id[1]=0;
  CL_CoF_HudRemakeMessage("DualWield",n,active);assert(!hud.dual_id[0]&&!hud.dual_id[1]);
 }
 byte missingNull[]={1,2,3,4};CL_CoF_HudRemakeMessage("DualWield",4,missingNull);
 assert(!hud.dual_id[0]);
 byte odd[]={0,0,3,2,99};CL_CoF_HudRemakeMessage("DualWield",5,odd);assert(!hud.dual_id[0]);
 active[7]=99;CL_CoF_HudRemakeMessage("DualWield",sizeof(active),active);
 begin();assert(!hud.collecting);
 // Opt-out reproduces the old rejection, not a different inferred protocol.
 CL_CoF_HudRemakeReset();cof_hud_dual_protocol.value=0;active[7]=3;active[8]=2;
 CL_CoF_HudRemakeMessage("DualWield",sizeof(active),active);current(15,-1);
 begin();assert(!hud.collecting&&!hud.dual_id[0]);
 cof_hud_dual_protocol.value=1;CL_CoF_HudRemakeMessage("DualWield",sizeof(active),active);
 // Clear path is model string + three bytes + signed short; IDs invalidate it.
 byte clear[]={0,0,255,255,255,255};CL_CoF_HudRemakeMessage("DualWield",sizeof(clear),clear);
 begin();assert(!hud.collecting&&!hud.dual_id[0]&&!hud.dual_id[1]);
 CL_CoF_HudRemakeMessage("DualWield",sizeof(active),active);
 CL_CoF_HudRemakeMessage("ResetHUD",0,NULL);assert(!hud.dual_id[0]);
 puts("PASS retail active/clear DualWield, phone/gun, two guns, bounds, opt-out/reset");
'''
test = parts['test'].replace(' puts("PASS stock27', checks + '\n puts("PASS stock27')
file = a.out / 'dual-protocol.c'
file.write_text(parts['stub'] + '\n' + code + '\n' + test)
subprocess.run(['cl', '/nologo', '/W3', '/std:c11', str(file.resolve()), '/Fe:dual-protocol.exe'], cwd=a.out, check=True)
subprocess.run([str((a.out / 'dual-protocol.exe').resolve())], cwd=a.out, check=True)
