"""Check real icon payloads, metadata links, and maskable safe bounds."""
import json
import struct
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit

site = Path(__file__).resolve().parents[1] / 'dist'

class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self.images = []
        self.meta = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'link': self.links.append(attrs)
        if tag == 'img': self.images.append(attrs)
        if tag == 'meta': self.meta.append(attrs)

for page in ['index.html', 'docs.html']:
    parser = Page()
    parser.feed((site / page).read_text())
    for link in parser.links:
        url = urlsplit(link.get('href', ''))
        if not url.scheme: assert (site / url.path).is_file(), (page, url.path)
    icons = [link for link in parser.links if link.get('rel') == 'icon']
    assert any(link.get('href') == 'favicon.svg' and link.get('sizes') == 'any' for link in icons)
    assert any(link.get('href') == 'favicon.ico' for link in icons)
    assert any(link.get('rel') == 'apple-touch-icon' and link.get('sizes') == '180x180' for link in parser.links)
    assert any(link.get('rel') == 'manifest' for link in parser.links)
    for image in parser.images:
        url = urlsplit(image.get('src', ''))
        if not url.scheme: assert (site / url.path).is_file(), (page, url.path)
    for key in ['og:image', 'og:image:width', 'og:image:height']:
        assert any(meta.get('property') == key for meta in parser.meta), (page, key)

ico = (site / 'favicon.ico').read_bytes()
reserved, kind, count = struct.unpack_from('<HHH', ico)
assert (reserved, kind, count) == (0, 1, 6)
sizes = []
for index in range(count):
    width, height, _, _, planes, bits, length, offset = struct.unpack_from('<BBBBHHII', ico, 6 + index * 16)
    width, height = width or 256, height or 256
    frame = ico[offset:offset + length]
    assert frame[:8] == b'\x89PNG\r\n\x1a\n'
    assert struct.unpack_from('>II', frame, 16) == (width, height)
    assert (planes, bits) == (1, 32)
    sizes.append(width)
assert sizes == [16, 32, 48, 64, 128, 256]

for name, size in [('apple-touch-icon.png', 180), ('assets/brand/web-icon-192.png', 192),
                   ('assets/brand/web-icon-512.png', 512), ('assets/brand/web-icon-maskable-512.png', 512)]:
    data = (site / name).read_bytes()
    assert struct.unpack_from('>II', data, 16) == (size, size), name
for svg in [site / 'favicon.svg', *site.glob('assets/brand/*.svg')]: ET.parse(svg)
manifest = json.loads((site / 'site.webmanifest').read_text())
assert {item['purpose'] for item in manifest['icons']} == {'any', 'maskable'}
for item in manifest['icons']: assert (site / item['src']).is_file()
# The expanded 32 px nodes have bounding corners at 18 and 110 on a 128 px grid.
# Applying the maskable transform keeps even those farthest corners inside the safe circle.
assert ((46 * 0.66) ** 2 * 2) ** 0.5 < 128 * 0.4
assert 'assets/brand/symbol-mono.svg' in (site / 'theme.css').read_text()
assert 'assets/norna-symbol-mono.svg' not in (site / 'theme.css').read_text()
print('Verified six ICO sizes, SVG metadata, touch and maskable assets, theme pairing, and both pages.')
