"""Verify documented built-in inline sources and native light/dark previews."""
import json
import re
import struct
from pathlib import Path

site = Path(__file__).resolve().parents[1] / 'dist'
assets = site / 'assets'
examples = json.loads((assets / 'inline-examples.json').read_text())
assert len(examples) == 2
assert {item['id'] for item in examples} == {'sf-symbols-color', 'rich-text'}
html = (site / 'docs.html').read_text()
for item in examples:
    assert f'data-inline-example="{item["id"]}"' in html
    assert set(item['sources']) == {'zh', 'en'}
    assert not re.search(r'[\u4e00-\u9fff]', item['sources']['en'])
    for language in ['zh', 'en']:
        stem = f'inline-{item["id"]}-{language}'
        assert (assets / f'{stem}.mmd').read_text() == item['sources'][language]
        images = [(assets / f'{stem}-{theme}.png').read_bytes() for theme in ['light', 'dark']]
        assert images[0] != images[1]
        assert struct.unpack('>II', images[0][16:24]) == struct.unpack('>II', images[1][16:24])
        for image in images:
            assert image[:8] == b'\x89PNG\r\n\x1a\n' and len(image) > 500
print('Verified 2 built-in bilingual inline sources and 8 native previews.')
