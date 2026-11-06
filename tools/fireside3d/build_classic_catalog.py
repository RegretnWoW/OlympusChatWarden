#!/usr/bin/env python3
"""Resolve explicit Elwynn WMO candidates and Classic/Forever M2 references.

The listfile proves an ID/path mapping, not installation or native rendering.
"""
import argparse
import csv
import json
from pathlib import Path


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--listfile', type=Path, required=True)
    ap.add_argument('--source', type=Path, default=Path('tools/fireside3d/elwynn-assets.csv'))
    ap.add_argument('--out', type=Path, default=Path('Fireside3DAssets/Index.lua'))
    args = ap.parse_args()
    with args.source.open(newline='') as f:
        selected = list(csv.DictReader(f))
    expected = {int(r['fileID']): r['path'] for r in selected}
    assert len(expected) == len(selected) <= 512, 'Duplicate/excessive asset references'
    found = {}
    with args.listfile.open(encoding='utf-8-sig') as f:
        for line in f:
            number, sep, path = line.strip().partition(';')
            if sep and number.isdigit() and int(number) in expected:
                found[int(number)] = path.replace('\\', '/').lower()
    assert found == expected, 'An explicit model ID/path mapping is absent or has changed'
    rows = []
    for r in selected:
        fmt = r['path'].rsplit('.', 1)[1].upper()
        assert r['era'] in {'CLASSIC', 'FOREVER_REFERENCE'}
        assert fmt == 'M2' or (fmt == 'WMO' and r['zone'] == 'Elwynn Forest'
                               and r['status'] == 'ELWYNN_WMO_RENDER_UNVERIFIED'
                               and int(r['fileID']) in {106851,106965,106848,107232})
        row = dict(r, fileID=int(r['fileID']), height=float(r['height']), format=fmt)
        rows.append(row)
    def lua(row):
        return '{' + ','.join('[' + json.dumps(k) + ']=' + json.dumps(v) for k, v in row.items()) + '}'
    args.out.write_text('-- Elwynn world-building candidates and existing Classic/Forever props.\n'
                        '-- ID/path resolution is not an installed-client or render certification.\n'
                        'Fireside3DAssetIndex={\n ' + ',\n '.join(map(lua, rows)) + '\n}\n')
    print(f'{len(rows)} references resolved; Elwynn WMO candidates remain render-unverified.')


if __name__ == '__main__':
    main()
