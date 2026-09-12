"""Check source-string coverage and preserve every printf placeholder."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
catalog = json.loads((ROOT / 'translations/en.json').read_text())
quoted = re.compile(r'"(?:[^"\\]|\\.)*"')
chinese = re.compile(r'[\u3400-\u9fff]')
formats = re.compile(r'%[-+0-9.]*[dsf]|%%')
count = 0
for path in (ROOT / 'scripts').rglob('*.gd'):
    for match in quoted.finditer(path.read_text()):
        source = json.loads(match.group())
        if not chinese.search(source):
            continue
        assert source in catalog, f'Untranslated source in {path}: {source}'
        count += 1
for source, english in catalog.items():
    assert not chinese.search(english), f'Chinese remains in English entry: {source}'
    assert formats.findall(source) == formats.findall(english), f'Changed placeholders: {source}'
print(f'TRANSLATIONS: {count} source occurrences covered; {len(catalog)} English entries have matching placeholders.')
