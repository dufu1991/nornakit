"""Publish NornaKit release notes with an independently versioned Studio companion."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

from github_release import gh, is_release_candidate
from release_metadata import DMG_NAME, append_manifest, read_manifest
from version import ROOT, read_version, write_outputs

VERSION = r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"
ASSETS = ["Norna-Studio-macOS-arm64.dmg", "Norna-Studio-macOS-arm64.zip", "SHA256SUMS.txt", "release.json"]


def read_library_version(path=ROOT / "Configuration/Kit-Version.json"):
    values = json.loads(path.read_text(encoding="utf-8"))
    if set(values) != {"version"} or not re.fullmatch(VERSION, values["version"]):
        raise ValueError("Kit-Version.json must contain one stable X.Y.Z library version")
    return {"version": values["version"], "tag": "v" + values["version"]}


def candidate(event, ref, before, sha, manual):
    if ref.startswith("refs/tags/"):
        return event == "push" and ref == "refs/tags/" + read_library_version()["tag"]
    return is_release_candidate(event, ref, before, sha, manual, "Configuration/Kit-Version.json")


def releases(repository):
    pages = json.loads(gh("api", "--paginate", "--slurp", f"repos/{repository}/releases?per_page=100"))
    return [item for page in pages for item in page]


def release_needed(metadata, existing, target):
    current = next((item for item in existing if item["tag_name"] == metadata["tag"]), None)
    if current:
        if not current["draft"]:
            return False
        if current["target_commitish"] != target:
            raise ValueError("The library draft targets another commit")
        return True
    versions = [tuple(map(int, match.groups())) for item in existing
                if not item["draft"] and not item["prerelease"]
                and (match := re.fullmatch("v" + VERSION, item["tag_name"]))]
    if versions and tuple(map(int, metadata["version"].split("."))) <= max(versions):
        raise ValueError("The Kit version must be newer than published library versions")
    return True


def source_target(repository, metadata, sha):
    refs = json.loads(gh("api", f"repos/{repository}/git/matching-refs/tags/{metadata['tag']}"))
    if any(item["ref"] == f"refs/tags/{metadata['tag']}" for item in refs):
        return gh("api", f"repos/{repository}/commits/{metadata['tag']}", "--jq", ".sha")
    return sha


def changelog_notes(changelog, version):
    match = re.search(rf"^## {re.escape(version)}(?:[ \t]+[^\n]*)?\n(.*?)(?=^## |\Z)", changelog, re.MULTILINE | re.DOTALL)
    if not match or not match[1].strip():
        raise ValueError("The library version requires its own nonempty CHANGELOG.md section")
    return match[1].strip()


def validate_companion(directory, metadata, target, studio):
    if not all((directory / name).is_file() for name in ASSETS):
        raise ValueError("The companion package is incomplete")
    manifest = json.loads((directory / "release.json").read_text(encoding="utf-8"))
    expected = {**studio, "commit": target, "kitVersion": metadata["version"], "releaseTag": metadata["tag"]}
    mismatched = [key for key, value in expected.items() if manifest[key] != value]
    if mismatched:
        raise ValueError("The companion package metadata differs in: " + ", ".join(mismatched))
    if manifest["architectures"] != ["arm64"] or manifest["minimumMacOS"] != "14.0":
        raise ValueError("The companion requires the arm64 macOS 14 package")
    if manifest["signing"] not in ["ad-hoc", "developer-id-notarized"]:
        raise ValueError("Unknown companion signing status")
    sums = [line.split() for line in (directory / "SHA256SUMS.txt").read_text().splitlines()]
    for name in [ASSETS[0], ASSETS[1], "release.json"]:
        expected_sum = [[hashlib.sha256((directory / name).read_bytes()).hexdigest(), name]]
        if [fields for fields in sums if len(fields) == 2 and fields[1] == name] != expected_sum:
            raise ValueError("The companion checksum does not match: " + name)
    return manifest


def validate_studio_build(repository, studio, existing):
    builds = []
    for release in existing:
        if release["draft"] or release["prerelease"]:
            continue
        assets = {asset["name"]: asset for asset in release["assets"]}
        manifest = read_manifest(release["body"])
        if manifest is None:
            if "release.json" not in assets:
                continue
            manifest = json.loads(gh("api", f"repos/{repository}/releases/assets/{assets['release.json']['id']}",
                                     "-H", "Accept: application/octet-stream"))
        builds.append((tuple(map(int, manifest["version"].split("."))), int(manifest["build"])))
    current = (tuple(map(int, studio["version"].split("."))), int(studio["build"]))
    if builds and current <= max(builds):
        raise ValueError("Increment the independent Studio build before publishing a refreshed companion")


def prepare(repository, sha, output):
    metadata, studio = read_library_version(), read_version()
    existing = releases(repository)
    target = source_target(repository, metadata, sha)
    needed = release_needed(metadata, existing, target)
    if needed:
        notes = subprocess.check_output(["git", "show", f"{target}:CHANGELOG.md"], cwd=ROOT, text=True)
        changelog_notes(notes, metadata["version"])
        validate_studio_build(repository, studio, existing)
    write_outputs({**metadata, "target": target, "publish": str(needed).lower()}, output)
    print(f"{metadata['tag']}: {'ready to publish' if needed else 'already published; skipping'}")


def publish(repository, target, directory):
    metadata, studio = read_library_version(), read_version()
    # An existing tag is immutable, including when retrying an interrupted draft.
    if source_target(repository, metadata, target) != target:
        raise ValueError("The library tag points at another commit")
    existing = releases(repository)
    if not release_needed(metadata, existing, target):
        raise ValueError("A published library release cannot be overwritten")
    manifest = validate_companion(directory, metadata, target, studio)
    source = subprocess.check_output(["git", "show", f"{target}:CHANGELOG.md"], cwd=ROOT, text=True)
    notes = f"# NornaKit {metadata['version']}\n\n" + changelog_notes(source, metadata["version"])
    notes += f"\n\n## Companion build\n\nNorna Studio {studio['version']} (build {studio['build']}) includes NornaKit {metadata['version']}. The app version is independent of the Swift Package version.\n"
    studio_notes = ROOT / "Docs/STUDIO_CHANGELOG.md"
    if studio_notes.is_file() and re.search(rf"^## {re.escape(studio['version'])}(?:\s|$)", studio_notes.read_text(), re.MULTILINE):
        notes += "\n" + changelog_notes(studio_notes.read_text(), studio["version"]) + "\n"
    if manifest["signing"] == "ad-hoc":
        notes += "\nThe companion app is ad-hoc signed and is not notarized by Apple.\n"
    notes += "\nThe DMG contains the optional Studio app. Swift Package integration does not require it.\n"
    notes = append_manifest(notes, manifest, directory)
    notes_file = directory / "KIT_RELEASE_NOTES.md"
    notes_file.write_text(notes, encoding="utf-8")
    tag = metadata["tag"]
    if not any(item["tag_name"] == tag for item in existing):
        gh("release", "create", tag, "--repo", repository, "--target", target,
           "--title", f"NornaKit {metadata['version']}", "--draft", "--notes-file", str(notes_file))
    gh("release", "upload", tag, str(directory / DMG_NAME), "--repo", repository, "--clobber")
    gh("release", "edit", tag, "--repo", repository, "--draft=false", "--latest", "--notes-file", str(notes_file))
    print(f"Published https://github.com/{repository}/releases/tag/{tag}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["candidate", "prepare", "publish"])
    parser.add_argument("--target")
    parser.add_argument("--directory", type=Path, default=ROOT / "build/release")
    args = parser.parse_args()
    if args.command == "candidate":
        needed = candidate(os.environ["GITHUB_EVENT_NAME"], os.environ["GITHUB_REF"], os.environ["BEFORE_SHA"],
                           os.environ["GITHUB_SHA"], os.environ["MANUAL_RELEASE"])
        write_outputs({"release": str(needed).lower()}, os.environ["GITHUB_OUTPUT"])
    elif args.command == "prepare":
        prepare(os.environ["GITHUB_REPOSITORY"], os.environ["GITHUB_SHA"], os.environ["GITHUB_OUTPUT"])
    else:
        if not args.target:
            parser.error("publish requires the verified source --target")
        publish(os.environ["GITHUB_REPOSITORY"], args.target, args.directory)
