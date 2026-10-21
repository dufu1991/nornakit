"""Publish the generated context-specific brand assets into the static site."""
import json
import shutil
from pathlib import Path

root = Path(__file__).resolve().parents[2]
site = root / 'website/dist'
source = root / 'build/Branding/IconSystem'
target = site / 'assets/brand'
target.mkdir(parents=True, exist_ok=True)
names = ['symbol.svg', 'symbol-dark.svg', 'symbol-mono.svg', 'safari-pinned-tab.svg',
         'app-icon-light.png', 'app-icon-dark.png', 'social-cover.png',
         'web-icon-192.png', 'web-icon-512.png', 'web-icon-maskable-512.png']
for name in names:
    shutil.copyfile(source / name, target / name)
for name in ['favicon.ico', 'favicon.svg', 'apple-touch-icon.png']:
    shutil.copyfile(source / name, site / name)
for size in [16, 32, 48, 64, 128, 256]:
    shutil.copyfile(source / f'favicon-{size}.png', target / f'favicon-{size}.png')

# Keep previously published asset URLs valid while replacing their stale artwork.
for current, previous in [('symbol.svg', 'norna-symbol.svg'), ('symbol-mono.svg', 'norna-symbol-mono.svg'),
                          ('app-icon-light.png', 'app-icon.png')]:
    shutil.copyfile(source / current, site / 'assets' / previous)

manifest = {
    'id': './', 'name': 'NornaKit — Native diagrams', 'short_name': 'NornaKit',
    'start_url': './', 'scope': './', 'display': 'browser',
    'background_color': '#fafaf9', 'theme_color': '#5148d8',
    'icons': [
        {'src': f'assets/brand/web-icon-{size}.png', 'sizes': f'{size}x{size}', 'type': 'image/png', 'purpose': 'any'}
        for size in [192, 512]
    ] + [{'src': 'assets/brand/web-icon-maskable-512.png', 'sizes': '512x512', 'type': 'image/png', 'purpose': 'maskable'}]
}
(site / 'site.webmanifest').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n')
print('Synced context-specific site icons, compatibility URLs, and manifest.')
