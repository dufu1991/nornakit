#!/bin/bash
set -euo pipefail
umask 077

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$project_root"
version="$(python3 Scripts/Release/version.py --field version)"
build_number="$(python3 Scripts/Release/version.py --field build)"
signing="${MACOS_SIGNING_ENABLED:-false}"
if [[ "$signing" != true && "$signing" != false ]]; then
    echo 'MACOS_SIGNING_ENABLED must be true or false.' >&2
    exit 1
fi
if [[ "$signing" == true ]]; then
    : "${MACOS_CERTIFICATE_P12:?Set MACOS_CERTIFICATE_P12}"
    : "${MACOS_CERTIFICATE_PASSWORD:?Set MACOS_CERTIFICATE_PASSWORD}"
    : "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID}"
    : "${APPLE_ID:?Set APPLE_ID}"
    : "${APPLE_APP_PASSWORD:?Set APPLE_APP_PASSWORD}"
fi

output="$project_root/build/release"
mkdir -p "$output"
temporary="$(mktemp -d "${TMPDIR:-/tmp}/norna-release.XXXXXX")"
keychain="$temporary/signing.keychain-db"
cleanup() {
    if [[ -f "$keychain" ]]; then
        security delete-keychain "$keychain"
    fi
    rm -rf "$temporary"
}
trap cleanup EXIT

xcodebuild build \
    -project Norna.xcodeproj -scheme NornaStudio \
    -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath build \
    'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO

app="$project_root/build/Build/Products/Release/Norna Studio.app"
app_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
app_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")"
[[ "$app_version" == "$version" && "$app_build" == "$build_number" ]]
for architecture in arm64 x86_64; do
    lipo "$app/Contents/MacOS/Norna Studio" -verify_arch "$architecture"
    lipo "$app/Contents/Frameworks/NornaKit.framework/NornaKit" -verify_arch "$architecture"
done

identity='-'
sign_arguments=(--force --options runtime --timestamp=none)
if [[ "$signing" == true ]]; then
    export NORNA_CERTIFICATE_PATH="$temporary/certificate.p12"
    python3 - <<'PY'
import base64
import os
from pathlib import Path
Path(os.environ['NORNA_CERTIFICATE_PATH']).write_bytes(base64.b64decode(os.environ['MACOS_CERTIFICATE_P12'], validate=True))
PY
    keychain_password="$(openssl rand -hex 32)"
    security create-keychain -p "$keychain_password" "$keychain"
    security set-keychain-settings -lut 21600 "$keychain"
    security unlock-keychain -p "$keychain_password" "$keychain"
    security import "$NORNA_CERTIFICATE_PATH" -k "$keychain" \
        -P "$MACOS_CERTIFICATE_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security > /dev/null
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
        -k "$keychain_password" "$keychain" > /dev/null
    identity="$(security find-identity -v -p codesigning "$keychain" | python3 -c '
import re, sys
identities = re.findall(r"([A-F0-9]{40}) \"Developer ID Application:", sys.stdin.read())
if len(identities) != 1:
    raise SystemExit("Import exactly one valid Developer ID Application identity")
print(identities[0])
')"
    sign_arguments=(--force --options runtime --timestamp --keychain "$keychain")
fi

# Sign embedded code before signing the enclosing app.
codesign "${sign_arguments[@]}" --sign "$identity" "$app/Contents/Frameworks/NornaKit.framework"
codesign "${sign_arguments[@]}" --sign "$identity" \
    --entitlements Configuration/NornaStudio.entitlements "$app"
codesign --verify --deep --strict --verbose=2 "$app"

notarize() {
    xcrun notarytool submit "$1" --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_PASSWORD" --wait --timeout 20m --output-format json > "$temporary/notary-result.json"
    python3 - "$temporary/notary-result.json" <<'PY'
import json
import sys
from pathlib import Path
result = json.loads(Path(sys.argv[1]).read_text())
if result['status'] != 'Accepted':
    raise SystemExit(f"Notarization failed: {result['status']}; submission {result['id']}")
PY
}

if [[ "$signing" == true ]]; then
    ditto -c -k --sequesterRsrc --keepParent "$app" "$temporary/notarization.zip"
    notarize "$temporary/notarization.zip"
    xcrun stapler staple "$app"
    xcrun stapler validate "$app"
    spctl --assess --type execute --verbose=2 "$app"
fi

zip_path="$output/Norna-Studio-macOS-universal.zip"
dmg_path="$output/Norna-Studio-macOS-universal.dmg"
rm -f "$zip_path" "$dmg_path"
ditto -c -k --sequesterRsrc --keepParent "$app" "$zip_path"
mkdir "$temporary/dmg"
ditto "$app" "$temporary/dmg/Norna Studio.app"
ln -s /Applications "$temporary/dmg/Applications"
hdiutil create -volname 'Norna Studio' -srcfolder "$temporary/dmg" \
    -format UDZO -fs HFS+ "$dmg_path"
if [[ "$signing" == true ]]; then
    codesign --force --timestamp --keychain "$keychain" --sign "$identity" "$dmg_path"
    notarize "$dmg_path"
    xcrun stapler staple "$dmg_path"
    xcrun stapler validate "$dmg_path"
fi

export NORNA_PACKAGE_SIGNING="$signing"
python3 - <<'PY'
import json
import os
from pathlib import Path
import sys
sys.path.insert(0, 'Scripts/Release')
from version import read_version
metadata = read_version() | {
    'commit': os.environ.get('GITHUB_SHA', 'working-tree'),
    'architectures': ['arm64', 'x86_64'],
    'minimumMacOS': '14.0',
    'signing': 'developer-id-notarized' if os.environ['NORNA_PACKAGE_SIGNING'] == 'true' else 'ad-hoc',
}
directory = Path('build/release')
(directory / 'release.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
signing_note = ('Signed with Developer ID and notarized by Apple.' if metadata['signing'] == 'developer-id-notarized'
    else '**Ad-hoc signed build.** This package is not signed with Developer ID or notarized by Apple. '
         'macOS Gatekeeper may block it. Review the source and build locally if you require a trusted developer signature.')
notes = f"""## Norna Studio {metadata['version']}

Build {metadata['build']} · macOS 14 or later · Apple Silicon and Intel

Download the DMG, open it, and drag **Norna Studio** to **Applications**. A ZIP containing the same app is also available.

{signing_note}

`SHA256SUMS.txt` contains SHA-256 checksums for both packages and `release.json`.

This is a **Norna Studio application release**. Its version is independent of NornaKit Swift package releases.

Source commit: `{metadata['commit']}`.
"""
(directory / 'RELEASE_NOTES.md').write_text(notes, encoding='utf-8')
PY
(
    cd "$output"
    shasum -a 256 Norna-Studio-macOS-universal.dmg Norna-Studio-macOS-universal.zip release.json > SHA256SUMS.txt
)
echo "Packaged Norna Studio $version ($build_number) in $output"
