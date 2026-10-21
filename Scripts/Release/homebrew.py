"""Generate and synchronize the companion app's Homebrew Cask."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import subprocess

from github_release import gh


TAP = "dufu1991/homebrew-tap"
CASK_PATH = "Casks/norna-studio.rb"
DMG_NAME = "Norna-Studio-macOS-arm64.dmg"
VERSION_PATTERN = r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"


def cask_version(content):
    versions = re.findall(r'^  version "([^"]+)"$', content, re.MULTILINE)
    if len(versions) != 1 or not re.fullmatch(VERSION_PATTERN, versions[0]):
        raise ValueError("Expected one stable X.Y.Z Cask version")
    return tuple(map(int, versions[0].split(".")))


def render(directory, tag):
    manifest = json.loads((directory / "release.json").read_text(encoding="utf-8"))
    version = manifest["version"]
    if not re.fullmatch(VERSION_PATTERN, version) or manifest["tag"] != f"studio-v{version}" or tag != manifest["tag"]:
        raise ValueError("The package version does not match the requested Studio tag")
    if manifest["architectures"] != ["arm64"] or manifest["minimumMacOS"] != "14.0":
        raise ValueError("The Cask requires the arm64-only macOS 14 package")
    if manifest["signing"] not in ["ad-hoc", "developer-id-notarized"]:
        raise ValueError("Unknown package signing status")
    package = directory / DMG_NAME
    digest = hashlib.sha256(package.read_bytes()).hexdigest()
    checksums = (directory / "SHA256SUMS.txt").read_text(encoding="utf-8").splitlines()
    expected = [line.split()[0] for line in checksums if line.split()[1:] == [DMG_NAME]]
    if expected != [digest]:
        raise ValueError("The DMG checksum does not match the published checksum file")
    caveats = ""
    if manifest["signing"] == "ad-hoc":
        caveats = '''
  caveats <<~EOS
    This build is ad-hoc signed and is not notarized by Apple.
    macOS Gatekeeper may block it. See the release notes before opening the app.
  EOS
'''
    return f'''cask "norna-studio" do
  version "{version}"
  sha256 "{digest}"

  url "https://github.com/dufu1991/norna/releases/download/studio-v#{{version}}/{DMG_NAME}"
  name "Norna Studio"
  desc "Companion demo, debugging, and export tool for the NornaKit diagram library"
  homepage "https://github.com/dufu1991/norna"

  livecheck do
    url :url
    regex(/^studio-v(\\d+(?:\\.\\d+)+)$/i)
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "Norna Studio.app"
{caveats}end
'''


def sync(content):
    version = cask_version(content)
    endpoint = f"repos/{TAP}/contents/{CASK_PATH}"
    entries = json.loads(gh("api", f"repos/{TAP}/contents/Casks?ref=main"))
    existing = next((entry for entry in entries if entry["path"] == CASK_PATH), None)
    payload = {
        "message": f"chore: 更新 Norna Studio 至 {'.'.join(map(str, version))}",
        "branch": "main",
        "content": base64.b64encode(content.encode("utf-8")).decode("ascii"),
    }
    if existing:
        current = json.loads(gh("api", f"{endpoint}?ref=main"))
        previous = base64.b64decode(current["content"]).decode("utf-8")
        if cask_version(previous) > version:
            print("The tap already has a newer Studio version; skipping")
            return
        if previous == content:
            print("The tap already contains this Cask; skipping")
            return
        if cask_version(previous) == version:
            raise ValueError("A Cask for this version already exists with different content; bump the Studio version")
        payload["sha"] = current["sha"]
    subprocess.run(["gh", "api", "--method", "PUT", endpoint, "--input", "-"],
                   input=json.dumps(payload), text=True, stdout=subprocess.DEVNULL, check=True)
    print(f"Updated https://github.com/{TAP}/blob/main/{CASK_PATH}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["render", "sync"])
    parser.add_argument("--directory", type=Path, default=Path("build/release"))
    parser.add_argument("--tag")
    parser.add_argument("--cask", type=Path, default=Path("build/release/norna-studio.rb"))
    args = parser.parse_args()
    if args.command == "render":
        if not args.tag:
            parser.error("render requires --tag")
        args.cask.parent.mkdir(parents=True, exist_ok=True)
        args.cask.write_text(render(args.directory, args.tag), encoding="utf-8")
        print(f"Generated {args.cask}")
    else:
        sync(args.cask.read_text(encoding="utf-8"))
