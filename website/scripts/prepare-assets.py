"""Build bilingual gallery screenshots from the same sources as Norna Studio."""
import shutil
import os
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
site = root / 'website' / 'dist'
assets = site / 'assets'
assets.mkdir(parents=True, exist_ok=True)
subprocess.run(['swift', 'build', '--product', 'NornaKit'], cwd=root, check=True)
for name in ['render-examples', 'render-showcase', 'render-inline-content']:
    executable = root / 'build' / f'site-{name}'
    executable.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        'swiftc', '-module-cache-path', '/tmp/norna-site-swift-cache',
        '-parse-as-library', '-I', '.build/debug', '-L', '.build/debug', '-lNornaKit',
        str(root / 'website' / 'scripts' / f'{name}.swift'), '-o', str(executable)
    ], cwd=root, check=True)
    renderer_environment = os.environ | {'PACKAGE_RESOURCE_BUNDLE_PATH': str(root / '.build/debug')}
    destination = site if name == 'render-examples' else root / 'build/InlineContent' if name == 'render-inline-content' else assets
    subprocess.run([str(executable), str(destination)],
                   cwd=root, env=renderer_environment, check=True)
subprocess.run(['swift', 'Scripts/build_brand_assets.swift'], cwd=root, check=True)
subprocess.run([sys.executable, str(root / 'website/scripts/sync-brand.py')], check=True)
subprocess.run([sys.executable, str(root / 'website/scripts/sync-inline-content.py')], check=True)
for filename, name in [('Docs/SUPPORT.md', 'SUPPORT.zh.md'),
                       ('README.zh-CN.md', 'README.zh.md'), ('README.md', 'README.en.md')]:
    shutil.copyfile(root / filename, assets / name)
shutil.copyfile(root / 'THIRD_PARTY_NOTICES.md', assets / 'THIRD_PARTY_NOTICES.md')
subprocess.run([sys.executable, str(root / 'website/scripts/verify-screenshots.py')], check=True)
