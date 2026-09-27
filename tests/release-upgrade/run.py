#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Exercise actual player ZIP installers in disposable minimal retail fixtures.
No engine is launched. Retail validation and local BSP/gameinfo generation remain enabled.
"""
import argparse,hashlib,json,os,re,shutil,subprocess,zipfile
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--previous-zip',type=Path,required=True);p.add_argument('--new-zip',type=Path,required=True)
p.add_argument('--canonical-game',type=Path,required=True);p.add_argument('--out',type=Path,required=True)
a=p.parse_args();a.out=a.out.resolve();a.canonical_game=a.canonical_game.resolve()
assert not a.out.exists(),'Use a new output directory; fixtures are retained for inspection'
assert a.canonical_game not in a.out.parents and a.out!=a.canonical_game,'Output must be outside the canonical game'
a.out.mkdir(parents=True)
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def unpack(z,name):
 target=a.out/name
 with zipfile.ZipFile(z) as f:
  for entry in f.infolist():
   path=Path(entry.filename)
   assert not path.is_absolute() and '..' not in path.parts and ':' not in entry.filename
  f.extractall(target)
 roots=list(target.rglob('MANIFEST.sha256'));assert len(roots)==1
 return roots[0].parent
def manifest(root):
 result={}
 for line in (root/'MANIFEST.sha256').read_text(encoding='utf-8-sig').splitlines():
  if not line or line.startswith('#'):continue
  m=re.fullmatch(r'([0-9a-fA-F]{64}) [ *](.+)',line);assert m,line
  rel=m[2].replace('\\','/');assert '..' not in Path(rel).parts and ':' not in rel and not rel.startswith('/')
  assert rel.lower() not in {s.lower() for s in result},rel
  assert not any(part.upper()=='SAVE' for part in Path(rel).parts),rel
  assert Path(rel).suffix.lower() not in {'.cfg','.sav'},rel
  result[rel]=m[1].upper();assert digest(root/'files'/rel)==result[rel],rel
 return result
old=unpack(a.previous_zip,'previous');new=unpack(a.new_zip,'new');oldfiles=manifest(old);newfiles=manifest(new)
# ZIP extraction over an earlier release leaves old-only payload files behind.
# They must be ignored because the current manifest is authoritative.
for rel in set(oldfiles)-set(newfiles):
 dst=new/'files'/rel;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(old/'files'/rel,dst)
stray=new/'files/cryoffear/config.cfg';stray.write_bytes(b'BAD stale unlisted config payload')
protected=['SAVE/player-slot.sav','cryoffear/SAVE/player-slot.sav','config.cfg','cryoffear/config.cfg','cryoffear/autoexec.cfg','cryoffear/userconfig.cfg','video.cfg','opengl.cfg','cryoffear/scriptsettings.dat']
seed=b'// player custom settings\r\nbind "A_BUTTON" "custom_jump"\r\nbind "B_BUTTON" ""\r\njoy_gyro_enable "1"\r\ncof_pad_move_mode "2"\r\ncof_hud_style "1"\r\nvolume "0.37"\r\n'
required=['CoFLaunchApp.exe','cryoffear/cl_dlls/hl.dll','cryoffear/cl_dlls/client.dll','cryoffear/liblist.gam','cryoffear/maps/c_game_menu1.bsp']
def fixture(name):
 game=a.out/name;game.mkdir();originals={}
 for rel in sorted(set(required)|set(oldfiles)|set(newfiles)|{'cryoffear/gameinfo.txt','cryoffear/maps/c_game_menu1.ent'}):
  source=a.canonical_game/rel
  if not source.is_file():
   assert rel not in required,rel
   continue
  dst=game/rel;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,dst);originals[rel]=digest(dst)
 for rel in protected:
  dst=game/rel;dst.parent.mkdir(parents=True,exist_ok=True);dst.write_bytes(seed+rel.encode());originals[rel]=digest(dst)
 return game,originals
def invoke(root,game,action):
 shell=Path(os.environ['SystemRoot'])/'System32/WindowsPowerShell/v1.0/powershell.exe'
 env=os.environ.copy();env['PSModulePath']=str(shell.parent/'Modules')+os.pathsep+str(Path(os.environ['ProgramFiles'])/'WindowsPowerShell/Modules')
 result=subprocess.run([str(shell),'-NoProfile','-ExecutionPolicy','Bypass','-File',str(root/(action+'.ps1')),'-GameDir',str(game)],capture_output=True,text=True,env=env)
 log=a.out/(game.name+'-'+action+'-'+str(len(list(a.out.glob('*.log'))))+'.log');log.write_text(result.stdout+'\n'+result.stderr)
 assert result.returncode==0,f'{action} failed: {log}\n{result.stdout}\n{result.stderr}'
def preserved(game,originals):
 for rel in protected:assert digest(game/rel)==originals[rel],rel
 for rel in required[1:]:assert digest(game/rel)==originals[rel],rel
 for rel,h in originals.items():
  if rel in newfiles or rel in oldfiles or rel in {'cryoffear/gameinfo.txt','cryoffear/maps/c_game_menu1.ent'}:
   assert digest(game/'cof-enhanced-backup'/rel)==h,'Original backup changed: '+rel

def installed(root,game,files):
 for rel,h in files.items():assert digest(game/rel)==h,'Installed mismatch: '+rel
 state=(game/'cof-enhanced-backup/installed-files.tsv').read_text(encoding='utf-8-sig')
 for rel,h in files.items():assert rel.replace('/','\\').lower() in state.lower() and h.lower() in state.lower(),rel
 info=(root/'release.txt').read_text(encoding='utf-8-sig');ver=re.search(r'^version=(.+)$',info,re.M).group(1).strip()
 assert 'version='+ver in (game/'cof-enhanced-version.txt').read_text()
 assert (game/'cryoffear/gameinfo.txt').is_file() and (game/'cryoffear/maps/c_game_menu1.ent').is_file()

def restored(game,originals):
 for rel,h in originals.items():assert digest(game/rel)==h,'Restore mismatch: '+rel
 for rel in set(oldfiles)|set(newfiles)|{'cryoffear/gameinfo.txt','cryoffear/maps/c_game_menu1.ent'}:
  if rel not in originals:assert not (game/rel).exists(),'Stale installed file: '+rel
for mode in ['fresh','upgrade']:
 game,originals=fixture(mode)
 if mode=='upgrade':
  invoke(old,game,'install');installed(old,game,oldfiles);preserved(game,originals)
  before={str(f.relative_to(game/'cof-enhanced-backup')):digest(f) for f in (game/'cof-enhanced-backup').rglob('*') if f.is_file() and f.name not in {'installed-files.tsv','backed-up-files.tsv','created-folders.txt'}}
 invoke(new,game,'install');installed(new,game,newfiles);preserved(game,originals)
 if mode=='upgrade':
  for rel,h in before.items():assert digest(game/'cof-enhanced-backup'/rel)==h,'Backup replaced: '+rel
  for rel in set(oldfiles)-set(newfiles):
   if rel not in originals:assert not (game/rel).exists(),'Obsolete payload remains: '+rel
 invoke(new,game,'install');installed(new,game,newfiles);preserved(game,originals)
 invoke(new,game,'uninstall');restored(game,originals)
 print('PASS:',mode,'install, manifest hashes/state, save/config/binds, original backups, repeat install, uninstall restore')
report={'previous_zip':str(a.previous_zip.resolve()),'previous_sha256':digest(a.previous_zip),'new_zip':str(a.new_zip.resolve()),'new_sha256':digest(a.new_zip),'old_files':len(oldfiles),'new_files':len(newfiles),'added_files':sorted(set(newfiles)-set(oldfiles)),'removed_files':sorted(set(oldfiles)-set(newfiles)),'result':'PASS','scope':'Real installer/uninstaller; no game runtime or save load executed'}
(a.out/'result.json').write_text(json.dumps(report,indent=2));print('PASS:',len(oldfiles),'old files ->',len(newfiles),'new files; report:',a.out/'result.json')
