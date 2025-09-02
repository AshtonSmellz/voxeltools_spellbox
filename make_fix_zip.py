#!/usr/bin/env python3
"""
make_fix_zip.py — produce voxeltools_spellbox_fixed.zip with corrected references

Run this from the ROOT of your Godot project/repo. It scans all .gd/.tscn/.tres files,
rewrites stale script/resource references to their current locations, and writes a ZIP
containing the corrected copies while leaving your working tree untouched.

Usage:
  python make_fix_zip.py
  python make_fix_zip.py --out voxeltools_spellbox_fixed.zip
  python make_fix_zip.py --verbose

Notes:
- If multiple files share the SAME BASENAME (e.g., two different 'Utils.gd'), the tool
  will not guess — it reports ambiguity and leaves the reference unchanged.
- Certain known path moves are hard-coded (Blocks -> VoxelToolFiles) based on your repo.
- You can inspect the ZIP then copy files over or extract atop your repo.
"""

import argparse
import io
import re
import sys
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

EDIT_EXTS = {'.gd', '.tscn', '.tres'}

HARDCODED_RESOURCE_MOVES = {
    'res://blocks/mesher.tres': 'res://VoxelToolFiles/voxel_mesher_blocky.tres',
    'res://blocks/voxel_library.tres': 'res://VoxelToolFiles/voxel_blocky_library.tres',
    'res://blocky_game/save': None,  # deprecated; warn only
}

RE_PRELOAD = re.compile(r'(?P<func>\bpreload|load)\(\s*["\'](?P<path>res://[^"\']+)["\']\s*\)')
RE_REL_PRELOAD = re.compile(r'(?P<func>\bpreload|load)\(\s*["\']\./(?P<rel>[^"\']+)["\']\s*\)')
RE_EXT_RESOURCE = re.compile(r'path=["\'](?P<path>res://[^"\']+)["\']')

def collect_files(root: Path):
    return [p for p in root.rglob('*') if p.is_file() and p.suffix in EDIT_EXTS]

def build_basename_map(root: Path):
    from collections import defaultdict
    m = defaultdict(list)
    for p in root.rglob('*'):
        if p.is_file() and p.suffix in ('.gd', '.tres', '.res'):
            godot_path = 'res://' + str(p.relative_to(root)).replace('\\', '/')
            m[p.name].append(godot_path)

    preferred = {}
    def rank_of(s):
        return 0 if '/Scripts/' in s else 1 if '/VoxelToolFiles/' in s else 2

    for base, paths in m.items():
        if len(paths) == 1:
            preferred[base] = paths[0]
        else:
            ranked = sorted(paths, key=lambda s: (rank_of(s), len(s)))
            same_rank = [p for p in ranked if rank_of(p) == rank_of(ranked[0])]
            if len(same_rank) > 1:
                preferred[base] = None  # ambiguous
                m[base] = same_rank
            else:
                preferred[base] = ranked[0]
    return preferred, m

def rewrite_text(text: str, basename_to_path: dict, all_candidates: dict, verbose=False, rel_note=''):
    changes = []
    def pick_path(base):
        chosen = basename_to_path.get(base)
        if chosen is None:
            return None, all_candidates.get(base, [])
        return chosen, []

    for old, new in HARDCODED_RESOURCE_MOVES.items():
        if old in text:
            if new is None:
                changes.append((f'hardcoded:{old}', 'WARN: deprecated; no replacement set'))
            else:
                text = text.replace(old, new)
                changes.append((f'hardcoded:{old}', f'-> {new}'))

    def _pre(m):
        path = m.group('path')
        base = Path(path).name
        chosen, amb = pick_path(base)
        if chosen and chosen != path:
            changes.append((f'preload:{path}', f'-> {chosen}'))
            return f'{m.group("func")}("{chosen}")'
        elif amb:
            changes.append((f'preload:{path}', f'AMBIGUOUS among: {amb}'))
        return m.group(0)

    text = RE_PRELOAD.sub(_pre, text)

    def _pre_rel(m):
        rel = m.group('rel')
        base = Path(rel).name
        chosen, amb = pick_path(base)
        if chosen:
            changes.append((f'preload:./{rel}', f'-> {chosen}'))
            return f'{m.group("func")}("{chosen}")'
        elif amb:
            changes.append((f'preload:./{rel}', f'AMBIGUOUS among: {amb}'))
        return m.group(0)

    text = RE_REL_PRELOAD.sub(_pre_rel, text)

    def _ext(m):
        path = m.group('path')
        base = Path(path).name
        if not (base.endswith('.gd') or base.endswith('.tres') or base.endswith('.res')):
            return m.group(0)
        chosen, amb = pick_path(base)
        if chosen and chosen != path:
            changes.append((f'ext:{path}', f'-> {chosen}'))
            return f'path="{chosen}"'
        elif amb:
            changes.append((f'ext:{path}', f'AMBIGUOUS among: {amb}'))
        return m.group(0)

    text = RE_EXT_RESOURCE.sub(_ext, text)
    if verbose and changes:
        print(rel_note)
        for a,b in changes:
            print(f'   {a} {b}')
    return text, changes

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='voxeltools_spellbox_fixed.zip', help='Output zip filename')
    ap.add_argument('--verbose', action='store_true')
    args = ap.parse_args()

    root = Path('.').resolve()
    files = collect_files(root)
    basename_to_path, all_candidates = build_basename_map(root)

    total_changes = 0
    buf = io.BytesIO()
    with ZipFile(buf, 'w', compression=ZIP_DEFLATED) as z:
        for f in files:
            try:
                orig = f.read_text(encoding='utf-8', errors='ignore')
            except Exception as e:
                print(f'WARN: could not read {f}: {e}', file=sys.stderr)
                continue
            new, changes = rewrite_text(orig, basename_to_path, all_candidates, verbose=args.verbose, rel_note=f'-- {f.relative_to(root)}')
            arcname = str(f.relative_to(root)).replace('\\', '/')
            z.writestr(arcname, new)
            total_changes += len(changes)

    with open(args.out, 'wb') as fh:
        fh.write(buf.getvalue())

    print(f'Wrote {args.out} with {len(files)} files. Total replacements: {total_changes}.')
    amb = {k:v for k,v in all_candidates.items() if basename_to_path.get(k) is None}
    if amb:
        print(f'Note: {len(amb)} ambiguous basenames could not be auto-resolved.')
        print('Examples:', list(amb.keys())[:10])

if __name__ == '__main__':
    main()
