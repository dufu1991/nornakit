"""Sync only documented native inline previews and remove stale generated examples."""
import json
from pathlib import Path
import shutil
import subprocess
import sys

website = Path(__file__).resolve().parents[1]
source = website.parent / 'build/InlineContent'
assets = website / 'dist/assets'
examples = json.loads((source / 'inline-examples.json').read_text())
filenames = {'inline-examples.json'}
for example in examples:
    for language in example['sources']:
        stem = f"inline-{example['id']}-{language}"
        filenames.add(f'{stem}.mmd')
        filenames.update(f'{stem}-{theme}.png' for theme in ['light', 'dark'])
for path in assets.glob('inline-*'):
    if path.suffix in ['.png', '.mmd'] and path.name not in filenames:
        path.unlink()
for filename in sorted(filenames):
    shutil.copyfile(source / filename, assets / filename)
subprocess.run([sys.executable, str(website / 'scripts/verify-inline-content.py')], check=True)
