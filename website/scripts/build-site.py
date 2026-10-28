"""Prepare the committed static site for Cloudflare Pages without a Swift build."""
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
site = root / "website/dist"
for source, name in [
    ("README.md", "README.en.md"),
    ("README.zh-CN.md", "README.zh.md"),
    ("Docs/SUPPORT.md", "SUPPORT.zh.md"),
    ("THIRD_PARTY_NOTICES.md", "THIRD_PARTY_NOTICES.md"),
]:
    shutil.copyfile(root / source, site / "assets" / name)
for script in ["verify-brand.py", "verify-screenshots.py", "verify-inline-content.py", "verify-windows.py"]:
    subprocess.run([sys.executable, str(root / "website/scripts" / script)], check=True)
print("NornaKit static site is ready in website/dist for https://nornakit.com.")
