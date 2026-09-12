"""Verify that shipped notices exist and package copies retain their exact bytes."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--package', type=Path)
args = parser.parse_args()
required = ['LICENSE', 'THIRD_PARTY_NOTICES.md', 'assets/fonts/OFL.txt',
            'assets/fonts/COPYRIGHT.txt', 'licenses/CC0-1.0.txt',
            'licenses/Godot-LICENSE.txt', 'licenses/Godot-COPYRIGHT.txt',
            'licenses/Noto-OFL.txt', 'licenses/Noto-COPYRIGHT.txt',
            'licenses/Quaternius-Animation-Library.txt',
            'licenses/Quaternius-Animation-Library-2.txt',
            'licenses/Quaternius-Fantasy-Outfits.txt']
for name in required:
    assert (ROOT / name).is_file() and (ROOT / name).stat().st_size > 30, name
assert 'Adobe' in (ROOT / 'assets/fonts/COPYRIGHT.txt').read_text()
assert 'SIL OPEN FONT LICENSE' in (ROOT / 'assets/fonts/OFL.txt').read_text()
assert 'does not replace' in (ROOT / 'THIRD_PARTY_NOTICES.md').read_text()
packs = ['character-pack-adventures', 'character-pack-skeletons',
         'dungeon-remastered', 'medieval-hexagon-pack', 'particles',
         'monsters', 'animals', 'terrain', 'detailed', 'medieval-village',
         'ultimate-monsters']
for pack in packs:
    notices = [p for p in (ROOT / 'assets/vendor' / pack).rglob('*')
               if p.is_file() and 'license' in p.name.lower()]
    assert notices, f'Missing original license for {pack}'
catalog = json.loads((ROOT / 'assets/vendor/catalog.json').read_text())
for key in catalog:
    assert key.split('/')[0] in packs, f'Unreviewed catalog pack: {key}'
if args.package:
    target = args.package / 'LICENSES'
    pairs = [(ROOT / n, target / n) for n in ['LICENSE', 'THIRD_PARTY_NOTICES.md']]
    pairs += [(p, target / p.name) for p in (ROOT / 'licenses').iterdir() if p.is_file()]
    for p in (ROOT / 'assets/vendor').rglob('*'):
        if p.is_file() and (p.suffix in ['.txt', '.md'] or p.name == 'sources.json'):
            pairs.append((p, target / 'PUBLIC-ASSETS' / p.relative_to(ROOT / 'assets/vendor')))
    for source, copy in pairs:
        assert copy.is_file() and source.read_bytes() == copy.read_bytes(), f'Changed/missing notice: {copy}'
    print(f'LICENSE PACKAGE: {len(pairs)} original notices and source records preserved byte-for-byte.')
print(f'LICENSE CHECK: {len(packs)} asset packs, character/animation notices, font copyright and engine notices verified.')
