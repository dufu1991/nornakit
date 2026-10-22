"""Read the independently versioned Norna Studio build configuration."""
import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
CONFIG = ROOT / "Configuration/Studio-Version.xcconfig"


def read_version(path=CONFIG):
    contents = path.read_text(encoding="utf-8")
    values = {}
    for key in ["MARKETING_VERSION", "CURRENT_PROJECT_VERSION"]:
        matches = re.findall(rf"^{key}\s*=\s*([^\s/]+)\s*$", contents, re.MULTILINE)
        if len(matches) != 1:
            raise ValueError(f"Expected exactly one {key} in {path}")
        values[key] = matches[0]
    version = values["MARKETING_VERSION"]
    build = values["CURRENT_PROJECT_VERSION"]
    if not re.fullmatch(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)", version):
        raise ValueError("MARKETING_VERSION must be a stable X.Y.Z version without leading zeros")
    if not re.fullmatch(r"[1-9]\d{0,3}", build):
        raise ValueError("CURRENT_PROJECT_VERSION must be an integer from 1 to 9999")
    return {"version": version, "build": build, "tag": f"studio-v{version}"}


def write_outputs(values, destination):
    with Path(destination).open("a", encoding="utf-8") as output:
        output.writelines(f"{key}={value}\n" for key, value in values.items())


def package_metadata(environment, path=CONFIG):
    metadata = read_version(path) | {
        "commit": environment.get("NORNA_PACKAGE_SOURCE_COMMIT", environment.get("GITHUB_SHA", "working-tree")),
        "architectures": ["arm64"],
        "minimumMacOS": "14.0",
        "signing": "developer-id-notarized" if environment["NORNA_PACKAGE_SIGNING"] == "true" else "ad-hoc",
    }
    if environment.get("NORNA_KIT_VERSION"):
        version = environment["NORNA_KIT_VERSION"]
        if not re.fullmatch(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)", version):
            raise ValueError("NORNA_KIT_VERSION must be a stable X.Y.Z version")
        metadata |= {"kitVersion": version, "releaseTag": "v" + version}
    return metadata


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--field", choices=["version", "build", "tag"])
    parser.add_argument("--github-output", type=Path)
    args = parser.parse_args()
    metadata = read_version()
    if args.github_output:
        write_outputs(metadata, args.github_output)
    print(metadata[args.field] if args.field else json.dumps(metadata, indent=2))
