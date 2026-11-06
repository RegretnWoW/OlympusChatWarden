#!/usr/bin/env python3
"""Build a public code/media overlay from explicit Git paths; never package a workspace recursively."""
from pathlib import Path
import argparse, hashlib, json, subprocess, zipfile
BASE='e4cc9f8da008fd065d933e6d142dde854108d53a'

def tracked():
    return subprocess.check_output(['git','ls-files','-z']).decode().split('\0')[:-1]

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--out',default='builds/fireside-3d');ap.add_argument('--private-reference',type=Path)
    args=ap.parse_args();root=Path.cwd();out=root/args.out;out.mkdir(parents=True,exist_ok=True)
    files=tracked();selected={}
    for name in files:
        p=Path(name)
        if name.startswith('OlympusChatWarden/') and 'Media' not in p.parts and p.suffix.lower() in {'.lua','.xml','.toc','.md','.txt'}:
            selected[name]=p
        elif name.startswith('Fireside3DAssets/') and p.suffix in {'.lua','.toc'}:selected[name]=p
    selected['OlympusChatWarden/Media/World3D/Grass.tga']=Path('OlympusChatWarden/Media/World3D/Grass.tga')
    for name in ['FiresideRecovery.toc','Recovery.lua','README.txt']:selected['FiresideRecovery/'+name]=Path(name)
    selected['FIRESIDE-3D-README.md']=Path('tools/fireside3d/README.md')
    # Reject exact private files and private-only long literals without emitting their contents.
    forbidden_hashes=set();literals=set()
    if args.private_reference:
        import re
        base_files=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE]).decode().splitlines()
        base_lua=b'\n'.join(subprocess.check_output(['git','show',BASE+':'+p]) for p in base_files if p.endswith('.lua'))
        for p in args.private_reference.rglob('*'):
            if not p.is_file():continue
            data=p.read_bytes();forbidden_hashes.add(hashlib.sha256(data).hexdigest())
            if p.suffix=='.lua':
                for literal in re.findall(rb'[\'\"]([A-Za-z0-9+/=_-]{48,})[\'\"]',data):
                    if len(set(literal))>=12 and literal not in base_lua:literals.add(literal)
    def check(data,name):
        assert hashlib.sha256(data).hexdigest()not in forbidden_hashes,'Private file rejected'
        assert not any(value in data for value in literals),'Private-only literal rejected'
        assert not name.startswith(('OlympusWardenSimLab/','attachments/','private-')),'Nonpublic path rejected'
    manifest={'base':BASE,'kind':'public code overlay; requires existing base media','files':{}}
    for name,p in selected.items():
        assert not p.is_symlink() and p.resolve().is_relative_to(root),'Nonlocal/symlink payload rejected'
        data=p.read_bytes();check(data,name);manifest['files'][name]=hashlib.sha256(data).hexdigest()
    candidate=out/'Fireside-3D-candidate1-overlay.zip'
    with zipfile.ZipFile(candidate,'w',zipfile.ZIP_DEFLATED)as z:
        for name,p in sorted(selected.items()):z.write(p,name)
        z.writestr('FIRESIDE-3D-MANIFEST.json',json.dumps(manifest,indent=2)+'\n')
    delta=subprocess.check_output(['git','diff','--name-only','--diff-filter=ACMRT',BASE,'--','OlympusChatWarden','Fireside3DAssets','tools/fireside3d']).decode().splitlines()
    with zipfile.ZipFile(out/'Fireside-3D-changed-files.zip','w',zipfile.ZIP_DEFLATED)as z:
        for name in delta:
            data=Path(name).read_bytes();check(data,name);z.write(name,name)
    patch=subprocess.check_output(['git','diff','--binary',BASE,'--','OlympusChatWarden','Fireside3DAssets','tools/fireside3d'])
    check(patch,'Fireside-3D.patch');(out/'Fireside-3D.patch').write_bytes(patch)
    (out/'Integration-README.md').write_bytes(Path('tools/fireside3d/README.md').read_bytes())
    for p in out.glob('*.zip'):
        with zipfile.ZipFile(p)as z:assert z.testzip()is None
    print('Public overlay:',len(selected),'files;',candidate.stat().st_size,'bytes. Changed-files ZIP and patch verified.')
    print('Private reference checked:',bool(args.private_reference),'; no private file/literal contents emitted.')
if __name__=='__main__':main()
