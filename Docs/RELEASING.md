# Releasing Norna Studio

[English README](../README.md) · [中文 README](../README.zh-CN.md)

The app, Swift package, and website share [dufu1991/norna](https://github.com/dufu1991/norna). NornaKit is the primary library product. Studio is a companion demo, rendering, debugging, and export tool with an independent release cycle.

## Automatic release policy

The [workflow](../.github/workflows/ci.yml) runs for pushes to `main`, PRs targeting `main`, and manual dispatches. Checks include Swift tests, release automation tests, an Apple Silicon Release build, and website resource validation. Only successful checks can reach publication.

A push to `main` publishes the app when that push changes `Configuration/Studio-Version.xcconfig`. The initial push containing this file also triggers publication. A manual run on `main` with `release` enabled retries the current app version; leaving the checkbox disabled only runs checks. Tag pushes do not start this workflow.

| Namespace | Purpose |
| --- | --- |
| `studio-v1.2.3` | Studio app release, created automatically by the workflow |
| `v0.4.0` | Independent NornaKit Swift Package version |

Library tags never trigger app publication. When creating a separate library Release, leave it unmarked as GitHub's latest release so the app's stable download URLs continue to resolve to Studio.

## Prepare a version

Edit [Studio-Version.xcconfig](../Configuration/Studio-Version.xcconfig):

```xcconfig
MARKETING_VERSION = 0.2.0
CURRENT_PROJECT_VERSION = 3
```

Use a stable three-part app version and increment the positive integer build number for each release. Both Debug and Release configurations read this file directly. No XcodeGen regeneration or `Package.swift` change is required for a version bump.

Commit the version file with the app changes and merge or push to `main`. Its version does not need to match a library tag. New app releases must be newer than all published Studio releases. An already published version is skipped; its assets are never overwritten.

The workflow uses the GitHub-hosted `xcode-27` preview runner with Xcode 27.1, building only `arm64` for Apple Silicon Macs running macOS 14 or later. The app icon uses the current Icon Composer document format and requires Xcode 27.1 to compile. The app executable and bundled framework are checked to contain only `arm64`. Tests also run on Apple Silicon. `.github/actionlint.yaml` registers this documented hosted runner label with lint versions that do not yet recognize it.

## Signing setup

With the repository Actions variable `MACOS_SIGNING_ENABLED` unset or `false`, no Apple credentials are required. The app and framework receive ad-hoc signatures. Release notes identify these packages as not Developer ID signed or notarized; Gatekeeper may block them.

For Developer ID signing and Apple notarization, set that variable to `true` and configure these repository **Actions secrets**:

| Secret | Value |
| --- | --- |
| `MACOS_CERTIFICATE_P12` | Base64 of a password-protected Developer ID Application certificate exported with its private key |
| `MACOS_CERTIFICATE_PASSWORD` | Password for the exported `.p12` |
| `APPLE_TEAM_ID` | Apple Developer team identifier matching the certificate |
| `APPLE_ID` | Account used for notarization |
| `APPLE_APP_PASSWORD` | App-specific password for that account |

Export exactly one valid Developer ID Application identity. Encode the file with `base64 -i certificate.p12 | tr -d '\n'` and store the result directly as the secret. Do not commit credentials. Publication uses the repository-scoped `GITHUB_TOKEN`; no personal access token is needed.

When signing is enabled, missing credentials or failed signing or notarization stop publication. The workflow does not switch to ad-hoc signing. It imports the certificate into a temporary keychain, signs embedded code before the app, applies hardened runtime and sandbox entitlements, notarizes and staples the app, and notarizes and staples the final DMG. It deletes the keychain when the script exits.

If an ad-hoc release was already published, enable signing and bump the app version to publish a new notarized release.

## Assets and download links

Every Studio release contains:

- `Norna-Studio-macOS-arm64.dmg`: app and Applications shortcut.
- `Norna-Studio-macOS-arm64.zip`: the same app with its bundle layout and signatures preserved.
- `SHA256SUMS.txt`: checksums for both packages and the manifest.
- `release.json`: version, build, commit, architectures, minimum macOS, and signing status.

Stable links are [latest DMG](https://github.com/dufu1991/norna/releases/latest/download/Norna-Studio-macOS-arm64.dmg) and [latest ZIP](https://github.com/dufu1991/norna/releases/latest/download/Norna-Studio-macOS-arm64.zip). The website uses the DMG URL. Before the first successful release these endpoints return 404.

Download all four files into one directory and run `shasum -a 256 -c SHA256SUMS.txt` to verify them.

## Homebrew distribution

The companion app can also be installed as a Cask from [dufu1991/homebrew-tap](https://github.com/dufu1991/homebrew-tap):

```sh
brew install --cask dufu1991/tap/norna-studio
brew update
brew upgrade --cask dufu1991/tap/norna-studio
```

NornaKit remains a Swift Package dependency. The Cask installs only the optional Norna Studio app and requires Apple Silicon and macOS 14 or later.

The tap's [Sync Norna Studio workflow](https://github.com/dufu1991/homebrew-tap/blob/main/.github/workflows/norna-studio.yml) runs hourly, when its workflow file changes, and on manual dispatch. It checks out the public Norna release tools, verifies the latest published Studio package, and updates the Cask using the tap's own `GITHUB_TOKEN`. No personal token is needed for this synchronization. Scheduled execution can be delayed by GitHub; use manual dispatch to synchronize immediately.

For immediate synchronization directly from the Norna release workflow, optionally configure the **Norna repository** Actions secret **`HOMEBREW_TAP_TOKEN`** with a fine-grained personal access token scoped to **`dufu1991/homebrew-tap`**, with **Contents: Read and write**. No workflow or administration permissions are required. GitHub's ordinary `GITHUB_TOKEN` is scoped to the repository running the workflow, so the app release token cannot write to the separate tap.

After the Studio release job succeeds, it calls [Publish Studio to Homebrew](../.github/workflows/homebrew.yml). The workflow downloads the published DMG, manifest, and checksums for that exact `studio-vX.Y.Z` tag, checks the package architecture and SHA-256, and generates the Cask with [homebrew.py](../Scripts/Release/homebrew.py). It creates or updates only `Casks/norna-studio.rb` on the tap's `main` branch. Existing Casks and the tap's `youran-toolbox` dispatch workflow are unaffected. The Cask points at the versioned Release URL, never the mutable latest-download URL.

The original `studio-v0.1.0` release has universal assets. The initial Cask in the local tap references that verified published DMG and restricts installation to Apple Silicon. Publish this Cask to the tap to make the installation command available. Do not substitute a locally rebuilt package or a nonexistent `arm64` URL for the published asset.

Subsequent automatic synchronization requires a newer app release with the `macOS-arm64` asset names. For example, use app version `0.1.1` and build `6` or higher. This replaces the initial Cask with the arm64-only download. Published releases are not rewritten to change their package architecture.

If the optional tap token is missing, the Norna workflow reports that immediate synchronization is skipped; the tap-owned workflow still performs publication. Once configured, token permission errors and upload failures fail the immediate Homebrew job. An identical retry does not create another commit, older versions cannot replace newer Casks, and different content for the same version is rejected. Updates use the existing blob SHA so a concurrent edit is rejected rather than overwritten.

To recover a failed tap update without a personal token, run **Sync Norna Studio** in the tap repository or rerun its failed job. With the optional tap token configured, run **Publish Studio to Homebrew** manually on Norna’s `main`, supplying the already published tag, or rerun the failed job. This downloads the existing release and does not rebuild or republish it. Homebrew publication is serialized separately from app publication. Ad-hoc builds retain an explicit Cask caveat about signing and notarization; Homebrew does not change the package's signing status.

Generate and inspect a Cask locally without changing the tap:

```sh
python3 Scripts/Release/homebrew.py render --tag "$(python3 Scripts/Release/version.py --field tag)"
ruby -c build/release/norna-studio.rb
```

The `sync` command is the remote mutation and requires the tap token as `GH_TOKEN`. The normal packaging command does not update Homebrew.

The local tap checkout is `/Users/dufu/Documents/github/dufu1991/homebrew-tap`. Maintain `Casks/norna-studio.rb` and its README together when adding or updating Norna. After an automated remote update, inspect local changes and bring the checkout up to date without discarding them. Keep the README's installation, upgrade, first-launch, and release automation instructions consistent with the Cask.

## Recovery

Build and notarization happen before a public Release is created. Packages are retained as an Actions artifact for 14 days, then uploaded to a draft Release. It becomes public only after all four files have uploaded.

Rerun a failed job, or manually dispatch on the same `main` commit with `release` enabled. A draft can be reused only for that exact commit; partial assets are replaced before publication. If `main` moved after the failed draft, bump the version instead. An existing tag targeting another commit also blocks publication.

Main checks run independently so an ordinary follow-up push cannot cancel a version change awaiting publication. Publication jobs are serialized without canceling an active release; GitHub may replace an older pending publication with a newer candidate. Published version checks prevent a delayed older build from replacing a newer release. PR checks cancel older checks for that PR. Only the release job has `contents: write`, and it runs only on this repository's `main` after checks pass. PR jobs never receive signing secrets or publish packages.

## Local verification

```sh
python3 -m unittest discover -s Tests/ReleaseTests -p 'test_*.py'
swift test
bash Scripts/Release/package.sh
```

The packaging script writes to `build/release/`. It does not launch the app, create tags, or contact GitHub. With signing enabled it contacts Apple's notarization service. Local manifests use `working-tree` unless `GITHUB_SHA` is supplied; the workflow always supplies the real commit SHA.

## References

- [GitHub runner images](https://github.com/actions/runner-images)
- [Xcode 27 runner software](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md)
- [GitHub Actions workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)
- [GitHub CLI release commands](https://cli.github.com/manual/gh_release)
- [Apple notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
- [Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)
- [Maintaining a Homebrew tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
- [GitHub token scope](https://docs.github.com/en/actions/concepts/security/github_token)
