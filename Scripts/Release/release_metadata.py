"""Keep machine-readable companion metadata in a hidden release-note comment."""
import hashlib
import json
import re


DMG_NAME = "Norna-Studio-macOS-arm64.dmg"
MARKER = "<!-- norna-studio-manifest:"


def read_manifest(notes):
    if MARKER not in notes:
        return None
    matches = re.findall(re.escape(MARKER) + r"\s*(\{[^\n]*\})\s*-->", notes)
    if len(matches) != 1 or notes.count(MARKER) != 1:
        raise ValueError("Expected exactly one valid companion manifest comment")
    manifest = json.loads(matches[0])
    if not re.fullmatch(r"[0-9a-f]{64}", manifest["sha256"]):
        raise ValueError("The companion manifest requires a SHA-256 digest")
    return manifest


def append_manifest(notes, manifest, directory):
    if MARKER in notes:
        raise ValueError("The release notes already contain companion metadata")
    values = manifest | {"sha256": hashlib.sha256((directory / DMG_NAME).read_bytes()).hexdigest()}
    return notes.rstrip() + "\n\n" + MARKER + " " + json.dumps(values, separators=(",", ":")) + " -->\n"
