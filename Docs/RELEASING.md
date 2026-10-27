# Releasing NornaKit and Norna Studio

[English README](../README.md) · [中文 README](../README.zh-CN.md)

NornaKit is the primary library product. GitHub Releases lead with the Kit version and its library changes. Norna Studio normally follows as an optional companion build, with a short version line rather than a separate feature announcement.

## Independent versions

| Product | Source of truth | Git tag | Current version |
| --- | --- | --- | --- |
| NornaKit Swift Package | `Configuration/Kit-Version.json` | `vX.Y.Z` | `v0.2.0` |
| Norna Studio app | `Configuration/Studio-Version.xcconfig` | `studio-vX.Y.Z` for standalone app releases | `0.1.1`, build `9` |

Swift Package Manager reads the Kit version from its Git tag. `Package.swift` has no separate version field. A companion attachment does not change the meaning of the Kit tag: its hidden release-note manifest records the independent app `version`, app `build`, library `kitVersion`, library source `commit`, and hosting `releaseTag`.

Do not copy the Kit version into Studio's marketing version. Increment Studio's build number for each refreshed companion. A standalone Studio release also needs a new app marketing version because published `studio-vX.Y.Z` releases are immutable.

## Version selection before committing

For each completed change, determine whether the released library or app behavior changes before preparing the commit. Library parser, layout, rendering, export, integration, or public model changes require a Kit version update and matching changelog section in the same delivery. Use a patch version for compatible fixes, performance work, and internal refactors; use a minor version for backward-compatible features. Breaking public API changes require a major version after 1.0, or a minor version while the library is below 1.0.

Each new companion package also needs a fresh Studio build number. Keep Studio's marketing version independent; app-only releases update its own marketing version and build without changing Kit's version. Documentation, tests, agent instructions, website, or CI changes alone do not require a product release unless they change a distributed product or its packaging. Plan one version for a completed delivery, not one version per intermediate edit.

Check published versions and companion builds before choosing new values. Do not reuse published tags, move an existing tag, or overwrite a published package. A `fix:` or `feat:` commit message does not trigger publication by itself: the workflow checks the version configuration files. Respect explicit instructions to commit locally or not push; updating version files does not authorize publication on its own.

## Normal Kit release

1. Change `Configuration/Kit-Version.json` to the next stable library version.
2. Add a nonempty section for that exact version in [CHANGELOG.md](../CHANGELOG.md). Describe the library changes and integration impact here.
3. Increment `CURRENT_PROJECT_VERSION` in the Studio version file so the companion can be upgraded independently. Keep its marketing version unless the app itself needs a new version.
4. Commit and push to `main`. A matching `vX.Y.Z` tag push also runs validation. Normal source-only commits do not publish a release.

[CI and NornaKit Release](../.github/workflows/ci.yml) runs release automation tests, the Swift suite, an Apple Silicon Release build, and website checks before publication. PRs receive checks only. Manual dispatch with `release` enabled retries the configured Kit version on `main`.

The Kit job resolves an existing tag to its immutable source commit, or uses the checked main commit when the tag is new. It checks out and tests that exact library source again, then builds the companion from that source with the separately configured Studio version and build. Companion metadata uses `NORNA_PACKAGE_SOURCE_COMMIT` for that source; GitHub's immutable `GITHUB_SHA` continues to identify the workflow commit. This also supports the already-created `v0.1.0` tag without moving it to a later CI commit.

Release notes start with **NornaKit X.Y.Z** and the exact library changelog section. Studio normally receives only a short companion version line. When app-specific notes are needed, add a matching `## X.Y.Z` section to `Docs/STUDIO_CHANGELOG.md`; only the current app version's section is appended.

Only the companion DMG uploads to a draft before it becomes public. The Kit release becomes GitHub's **Latest** release only after validation and upload succeed. Published releases and tags are never overwritten. A retry may replace incomplete assets only on a draft targeting the same source commit. Publication jobs are serialized, so a delayed older candidate cannot replace a newer library version.

## Companion downloads

A normal Kit release has one uploaded attachment: `Norna-Studio-macOS-arm64.dmg`, containing the optional app and Applications shortcut. GitHub also generates its two source archives automatically.

The [latest DMG](https://github.com/dufu1991/nornakit/releases/latest/download/Norna-Studio-macOS-arm64.dmg) follows the primary Kit release. Swift Package consumers use the `vX.Y.Z` library tag and do not install Studio.

The ZIP, `release.json`, and `SHA256SUMS.txt` remain available in the packaging job's Actions artifacts for debugging and verification. They are not uploaded to Releases. A hidden `norna-studio-manifest` JSON comment in the release notes carries the independent app metadata and DMG SHA-256 digest for automation without adding visible attachments. Homebrew checks that digest against both GitHub's asset digest and the downloaded DMG. Legacy releases with manifest and checksum attachments remain supported.

## Standalone Studio updates

If only Studio needs a release, change its marketing version and build without changing the Kit version file. CI publishes the independent `studio-vX.Y.Z` app release after checks pass. Manual dispatch has a separate `studio_release` input for retrying this path.

When both version files change together, the Kit release takes priority and only one release page is created. A standalone Studio release is appropriate for app-specific functionality, packaging, or distribution changes that warrant separate notes.

## Signing and build environment

The workflow uses the GitHub-hosted `xcode-27` runner and Xcode 27.1. The app and both embedded frameworks, NornaKit and the internal NornaExamples support module, must contain only `arm64`; the minimum macOS version is 14. The native icon format also requires this Xcode generation. `.github/actionlint.yaml` registers the preview runner label for lint versions that do not yet recognize it.

With `MACOS_SIGNING_ENABLED` unset or `false`, the package uses ad-hoc signatures without Hardened Runtime library validation. The app retains its sandbox entitlements. Release notes identify that the companion is not Developer ID signed or notarized.

For Developer ID signing and notarization, set `MACOS_SIGNING_ENABLED=true` and configure these Actions secrets:

| Secret | Value |
| --- | --- |
| `MACOS_CERTIFICATE_P12` | Base64-encoded `.p12` containing one valid Developer ID Application identity |
| `MACOS_CERTIFICATE_PASSWORD` | Certificate export password |
| `APPLE_TEAM_ID` | Apple Developer team identifier |
| `APPLE_ID` | Notarization account |
| `APPLE_APP_PASSWORD` | App-specific notarization password |

The signed branch enables Hardened Runtime, signs embedded code before the app, applies sandbox entitlements, notarizes and staples the app and DMG, and deletes its temporary keychain. Missing credentials or notarization failures stop publication. It never silently falls back to ad-hoc signing.

Only publication jobs receive `contents: write` and signing secrets. Pull requests cannot publish or obtain those secrets. The repository-scoped `GITHUB_TOKEN` handles Kit and Studio publication.

## Homebrew distribution

```sh
brew install --cask dufu1991/tap/norna-studio
brew update
brew upgrade --cask dufu1991/tap/norna-studio
```

The Cask installs only the companion app. It reads Studio's version and build from the verified release manifest, not from the Kit tag. Kit-hosted companions use a Cask version such as `0.1.1,7` and a literal versioned download URL such as `releases/download/v0.1.0/...`. This lets an app build follow a new Kit release without copying the library version into the app version.

[Publish Studio to Homebrew](../.github/workflows/homebrew.yml) accepts both Kit and standalone Studio releases. It reads the release-note manifest, downloads only the published DMG, validates the release tag and checksum, then generates the Cask with [homebrew.py](../Scripts/Release/homebrew.py). Older builds cannot replace newer builds, identical retries skip writes, and different content for the same app version/build is rejected.

For immediate cross-repository synchronization, optionally configure `HOMEBREW_TAP_TOKEN` with Contents read/write permission for `dufu1991/homebrew-tap`. Without it, the tap's own **Sync Norna Studio** workflow checks the latest stable release hourly and can be dispatched manually, using its repository's own `GITHUB_TOKEN`.

The tap workflow accepts a Kit release with companion assets as well as legacy `studio-vX.Y.Z` releases. Keep its `Casks/norna-studio.rb`, README, and workflow consistent. Preserve existing local changes when updating a sibling tap checkout.

## Recovery and local verification

A draft can be retried only for the same library source commit. If a tag already exists, the workflow tests and packages that tag; it never moves the tag to the new workflow commit. Bump the Kit version for new library changes and the Studio build for a new companion. Published assets are immutable.

```sh
python3 -m unittest discover -s Tests/ReleaseTests -p 'test_*.py'
swift test --build-system native
bash Scripts/Release/package.sh
```

The packaging script writes local artifacts only. Kit publication is handled separately by `library_release.py`; packaging alone does not launch the app, push tags, update Homebrew, or contact GitHub. With signing enabled, packaging contacts Apple's notarization service.
