#!/usr/bin/env python3
"""Build a prioritized candidate catalog from wowdev's semicolon-delimited wow-listfile.

Requires Python 3.9+. No game assets are read or exported.
The listfile is community metadata, NOT proof a model exists in the local Forever client.

Usage:
  python fireside_build_asset_index.py --listfile community-listfile.csv --out fireside-candidates.csv
  python fireside_build_asset_index.py --listfile community-listfile.csv --out candidates.csv --installed-ids forever-installed-ids.txt

The optional --installed-ids is a newline-separated text file of FileDataIDs independently
verified against the target WoW: Forever CASC root manifest. It MUST NOT be generated from
Retail's CASC manifest. Without this argument, installed = NOT_CHECKED.
"""
import argparse, csv, re, pathlib

KEYWORDS = {
  'House & buildings': ('house','housing','farm','cottage','hut','dwelling','residential','inn','tavern','barn','stable','outpost','barrack','townhall','blacksmith','workshop','shop','market','tower','keep','garrison','building'),
  'Furniture & interiors': ('furniture','chair','table','bench','bed','stool','shelf','desk','cabinet','bookcase','bookshelf','books','keg','barrel','fireplace','hearth','rug','carpet','door','window'),
  'Floors & architecture': ('floor','flooring','tile','stone','cobble','road','path','plank','stairs','step','bridge','railing','gate','fence','wall','pillar','roof','arch','platform','dock'),
  'Outdoor scenery': ('tree','bush','flower','grass','plant','rock','cliff','boulder','well','fountain','garden','bench','cart','wagon'),
  'Lighting & effects': ('light','lantern','torch','brazier','fire','campfire','candle','lamp','smoke','fog','mist','water','waterfall','spark'),
  'Decor & interactions': ('sign','banner','flag','poster','painting','trophy','chest','book','statue','shield','weaponrack','mailbox','portal','bell','gong','crate'),
  'Games & tavern': ('dice','game','arcade','target','stage','music','instrument','fishing','barrel','mug','tankard','cards'),
}

STYLE = ('human','orc','nightelf','night_elf','bloodelf','dwarf','tauren','troll','goblin','forsaken','undead','gnome','elven','gilneas','pandaria','northrend','kalimdor','azeroth')

def is_root_wmo(path):
    stem = path.rsplit('/',1)[-1].removesuffix('.wmo')
    # WMO groups e.g. House_000.wmo and LOD variants must NOT be imported as standalone roots.
    return not (re.search(r'_\d{3,4}(?:_lod\d+)?$',stem) or re.search(r'_lod\d+$',stem))

def classify(path):
    low=path.lower()
    names=[n for n,words in KEYWORDS.items() if any(x in low for x in words)]
    return '|'.join(names) if names else ''

def score(path,fmt,tags):
    p=path.lower(); score=0
    if 'house' in p or 'inn' in p or 'tavern' in p:score+=80
    if any(v in p for v in ('furniture','chair','table','floor','wall','stairs','campfire')):score+=50
    if any(v in p for v in ('building','hut','cottage','stable','barn','roof')):score+=30
    if fmt=='M2':score+=20 # proven model type from existing scene editors, not model-specific proof
    if 'azeroth' in p or 'kalimdor' in p or 'generic' in p:score+=10
    if 'lod' in p or 'test' in p or 'unused' in p:score-=20
    return score

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--listfile',required=True)
    ap.add_argument('--out',required=True);ap.add_argument('--installed-ids')
    ap.add_argument('--min-score',type=int,default=10)
    args=ap.parse_args()
    installed=None
    if args.installed_ids:
        installed={int(x.strip()) for x in pathlib.Path(args.installed_ids).read_text().splitlines() if x.strip().isdigit()}
    rows=[]
    with open(args.listfile,encoding='utf-8-sig',errors='replace',newline='') as f:
        for line in f:
            try: fid_s,path=line.rstrip('\r\n').split(';',1)
            except ValueError:continue
            if not fid_s.isdigit():continue
            fid=int(fid_s); p=path.strip().replace('\\','/').lower()
            if not p.endswith(('.m2','.wmo')):continue
            if p.endswith('.wmo') and not is_root_wmo(p):continue
            tags=classify(p)
            if not tags:continue
            fmt=p.rsplit('.',1)[-1].upper(); n=score(p,fmt,tags)
            if n<args.min_score:continue
            rows.append((n,fmt,p,fid,tags, ('YES' if fid in installed else 'NO') if installed is not None else 'NOT_CHECKED'))
    rows.sort(key=lambda r:(-r[0],r[1],r[2]))
    with open(args.out,'w',encoding='utf-8',newline='') as f:
        w=csv.writer(f);w.writerow(['priority_score','format','candidate_path','FileDataID','category_tags','installed_in_target_client','in_game_modelscene_render'])
        for row in rows:w.writerow([*row,'NOT_TESTED'])
    print(f'{len(rows)} candidates written to {args.out}. Not a verified in-game model list.')
    if installed is None:print('WARNING: No local Forever manifest supplied: client availability UNKNOWN for all entries.')

if __name__=='__main__':main()
