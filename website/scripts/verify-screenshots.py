"""Check that every localized source has matching native light/dark screenshots."""
import hashlib
import json
import re
import struct
from pathlib import Path

site = Path(__file__).resolve().parents[1] / 'dist'
assets = site / 'assets'
examples = json.loads((site / 'examples.json').read_text(encoding='utf-8'))
assert len(examples) == 36 and len({item['id'] for item in examples}) == 36
assert len({item['builtinID'] for item in examples}) == 36
symbols = [item for item in examples if item['id'].startswith('example-')]
assert {item['builtinID'] for item in symbols} == {'sf-symbols', 'sf-symbols-wrapping', 'sequence-sf-symbols'}
stems = ['hero-en', 'hero-zh']
for item in examples:
    assert set(item['sources']) == {'zh', 'en'}, item['id']
    assert not re.search(r'[\u4e00-\u9fff]', item['sources']['en']), item['id']
    for language in ['zh', 'en']:
        stem = f"{item['id']}-{language}"
        assert (assets / f'{stem}.mmd').read_text(encoding='utf-8') == item['sources'][language], stem
        if item in symbols:
            assert ':sf:' in item['sources'][language], stem
        stems.append(stem)
    if item['sources']['zh'] != item['sources']['en']:
        for theme in ['light', 'dark']:
            assert (assets / f"{item['id']}-zh-{theme}.png").read_bytes() != (assets / f"{item['id']}-en-{theme}.png").read_bytes(), item['id']
for stem in stems:
    light = (assets / f'{stem}-light.png').read_bytes()
    dark = (assets / f'{stem}-dark.png').read_bytes()
    for data in [light, dark]:
        assert data[:8] == b'\x89PNG\r\n\x1a\n', stem
        assert len(data) > 500, stem
    assert struct.unpack('>II', light[16:24]) == struct.unpack('>II', dark[16:24]), stem
    assert hashlib.sha256(light).digest() != hashlib.sha256(dark).digest(), stem
print(f'Verified {len(examples)} bilingual sources and {len(stems)} native light/dark PNG pairs.')
