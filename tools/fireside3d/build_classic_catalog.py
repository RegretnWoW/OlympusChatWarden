#!/usr/bin/env python3
"""Resolve an explicit Classic/Forever M2 allowlist, never a retail-wide scan.

The listfile proves an ID/path mapping, not installation or native rendering.
"""
import argparse
import csv
import json
from pathlib import Path


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--listfile', type=Path, required=True)
    ap.add_argument('--source', type=Path, default=Path('tools/fireside3d/classic-assets.csv'))
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
        assert r['era'] in {'CLASSIC', 'FOREVER_REFERENCE'} and r['path'].endswith('.m2')
        row = dict(r, fileID=int(r['fileID']), height=float(r['height']), format='M2')
        rows.append(row)
    def lua(row):
        return '{' + ','.join('[' + json.dumps(k) + ']=' + json.dumps(v) for k, v in row.items()) + '}'
    args.out.write_text('-- Explicit Classic-era M2 / existing Forever references only.\n'
                        '-- ID/path resolution is not an installed-client or render certification.\n'
                        'Fireside3DAssetIndex={\n ' + ',\n '.join(map(lua, rows)) + '\n}\n')
    print(f'{len(rows)} explicit M2 references resolved; no WMO or retail housing candidates.')


if __name__ == '__main__':
    main()
