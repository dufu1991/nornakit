"""Decide when to release and publish complete Studio packages with GitHub CLI."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess

from version import ROOT, read_version, write_outputs


def gh(*arguments):
    return subprocess.check_output(["gh", *arguments], text=True).strip()


def is_release_candidate(event, ref, before, sha, manual):
    if ref != "refs/heads/main":
        return False
    if event == "workflow_dispatch":
        return manual == "true"
    if event != "push":
        return False
    command = ["git", "diff", "--name-only", before, sha]
    if before == "0" * 40:
        command = ["git", "ls-tree", "-r", "--name-only", sha]
    changed = subprocess.check_output(command, cwd=ROOT, text=True).splitlines()
    return "Configuration/Studio-Version.xcconfig" in changed


def release_needed(metadata, releases, sha):
    existing = next((item for item in releases if item["tag_name"] == metadata["tag"]), None)
    if existing:
        if not existing["draft"]:
            return False
        if existing["target_commitish"] != sha:
            raise ValueError("An existing draft targets another commit; bump the Studio version")
        return True
    versions = [tuple(map(int, match.groups())) for item in releases
                if not item["draft"] and not item["prerelease"]
                and (match := re.fullmatch(r"studio-v(\d+)\.(\d+)\.(\d+)", item["tag_name"]))]
    if versions and tuple(map(int, metadata["version"].split("."))) <= max(versions):
        raise ValueError("The Studio version must be newer than all published Studio releases")
    return True


def prepare(repository, sha, output):
    metadata = read_version()
    pages = json.loads(gh("api", "--paginate", "--slurp", f"repos/{repository}/releases?per_page=100"))
    releases = [item for page in pages for item in page]
    needed = release_needed(metadata, releases, sha)
    if needed:
        refs = json.loads(gh("api", f"repos/{repository}/git/matching-refs/tags/{metadata['tag']}"))
        if any(item["ref"] == f"refs/tags/{metadata['tag']}" for item in refs):
            target = gh("api", f"repos/{repository}/commits/{metadata['tag']}", "--jq", ".sha")
            if target != sha:
                raise ValueError("The Studio tag already points at another commit")
    write_outputs({**metadata, "publish": str(needed).lower()}, output)
    print(f"{metadata['tag']}: {'ready to publish' if needed else 'already published; skipping'}")


def publish(repository, sha, directory):
    metadata = read_version()
    manifest = json.loads((directory / "release.json").read_text(encoding="utf-8"))
    if any(manifest[key] != value for key, value in metadata.items()) or manifest["commit"] != sha:
        raise ValueError("Package metadata does not match this release")
    assets = [directory / name for name in ["Norna-Studio-macOS-universal.dmg",
              "Norna-Studio-macOS-universal.zip", "SHA256SUMS.txt", "release.json"]]
    if not all(path.is_file() for path in assets):
        raise ValueError("The release package is incomplete")
    pages = json.loads(gh("api", "--paginate", "--slurp", f"repos/{repository}/releases?per_page=100"))
    releases = [item for page in pages for item in page]
    if not release_needed(metadata, releases, sha):
        raise ValueError("A published release cannot be overwritten")
    tag = metadata["tag"]
    if not any(item["tag_name"] == tag for item in releases):
        gh("release", "create", tag, "--repo", repository, "--target", sha,
           "--title", f"Norna Studio {metadata['version']}", "--draft",
           "--notes-file", str(directory / "RELEASE_NOTES.md"))
    gh("release", "upload", tag, *map(str, assets), "--repo", repository, "--clobber")
    gh("release", "edit", tag, "--repo", repository, "--draft=false", "--latest",
       "--notes-file", str(directory / "RELEASE_NOTES.md"))
    print(f"Published https://github.com/{repository}/releases/tag/{tag}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["candidate", "prepare", "publish"])
    parser.add_argument("--directory", type=Path, default=ROOT / "build/release")
    args = parser.parse_args()
    if args.command == "candidate":
        needed = is_release_candidate(os.environ["GITHUB_EVENT_NAME"], os.environ["GITHUB_REF"],
            os.environ["BEFORE_SHA"], os.environ["GITHUB_SHA"], os.environ["MANUAL_RELEASE"])
        write_outputs({"release": str(needed).lower()}, os.environ["GITHUB_OUTPUT"])
    elif args.command == "prepare":
        prepare(os.environ["GITHUB_REPOSITORY"], os.environ["GITHUB_SHA"], os.environ["GITHUB_OUTPUT"])
    else:
        publish(os.environ["GITHUB_REPOSITORY"], os.environ["GITHUB_SHA"], args.directory)
