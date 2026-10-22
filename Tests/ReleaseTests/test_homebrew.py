"""Check Cask integrity, first publication, retries, and delayed releases offline."""
import base64
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "Scripts/Release"))
from homebrew import CASK_PATH, DMG_NAME, cask_version, download, render, sync
from release_metadata import MARKER, append_manifest, read_manifest


class HomebrewTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.manifest = {
            "version": "1.2.3", "tag": "studio-v1.2.3", "architectures": ["arm64"],
            "minimumMacOS": "14.0", "signing": "ad-hoc",
        }
        data = b"release package fixture"
        self.digest = hashlib.sha256(data).hexdigest()
        (self.directory / DMG_NAME).write_bytes(data)
        (self.directory / "SHA256SUMS.txt").write_text(f"{self.digest}  {DMG_NAME}\n")
        self.write_manifest()

    def write_manifest(self):
        (self.directory / "release.json").write_text(json.dumps(self.manifest))

    def content(self):
        return render(self.directory, "studio-v1.2.3")

    def published(self):
        return {"tag_name": "studio-v1.2.3", "draft": False, "prerelease": False,
                "body": append_manifest("Studio notes.", self.manifest, self.directory),
                "assets": [{"name": DMG_NAME, "digest": "sha256:" + self.digest}]}

    @patch("homebrew.subprocess.run")
    @patch("homebrew.gh")
    def test_dmg_only_release_downloads_and_generates_the_same_cask(self, gh, run):
        gh.return_value = json.dumps(self.published())
        expected = self.content()
        (self.directory / "release.json").unlink()
        (self.directory / "SHA256SUMS.txt").unlink()
        download(self.directory, "studio-v1.2.3")
        self.assertEqual(self.content(), expected)
        arguments = run.call_args.args[0]
        self.assertEqual(arguments.count("--pattern"), 1)
        self.assertIn(DMG_NAME, arguments)

    @patch("homebrew.subprocess.run")
    @patch("homebrew.gh")
    def test_unpublished_or_mismatched_release_fails_before_download(self, gh, run):
        for change in [{"draft": True}, {"prerelease": True}, {"tag_name": "studio-v9.0.0"},
                       {"assets": []}, {"assets": [{"name": DMG_NAME, "digest": "sha256:" + "0" * 64}]}]:
            gh.return_value = json.dumps(self.published() | change)
            with self.assertRaises(ValueError):
                download(self.directory, "studio-v1.2.3")
        run.assert_not_called()

    @patch("homebrew.subprocess.run")
    @patch("homebrew.gh")
    def test_downloaded_dmg_must_match_both_published_digests(self, gh, run):
        gh.return_value = json.dumps(self.published())
        (self.directory / DMG_NAME).write_bytes(b"corrupt download")
        with self.assertRaises(ValueError):
            download(self.directory, "studio-v1.2.3")

    @patch("homebrew.subprocess.run")
    @patch("homebrew.gh")
    def test_legacy_release_downloads_its_attached_metadata(self, gh, run):
        release = self.published() | {"body": "Legacy notes.", "assets": [
            {"name": name} for name in [DMG_NAME, "release.json", "SHA256SUMS.txt"]]}
        gh.return_value = json.dumps(release)
        download(self.directory, "studio-v1.2.3")
        self.assertEqual(run.call_args.args[0].count("--pattern"), 3)

    def test_hidden_manifest_is_optional_but_malformed_or_duplicate_comments_fail(self):
        notes = self.published()["body"]
        self.assertEqual(read_manifest(notes)["sha256"], self.digest)
        self.assertIsNone(read_manifest("Plain release notes."))
        for value in [notes + notes, MARKER + " broken -->", notes.replace(self.digest, "bad")]:
            with self.assertRaises(ValueError):
                read_manifest(value)

    def test_cask_uses_versioned_release_and_real_package_checksum(self):
        content = self.content()
        self.assertIn(f'sha256 "{self.digest}"', content)
        self.assertIn(f'releases/download/studio-v#{{version}}/{DMG_NAME}', content)
        self.assertIn('app "Norna Studio.app"', content)
        self.assertIn("depends_on arch: :arm64", content)
        self.assertIn("depends_on macos: :sonoma", content)
        self.assertIn("not notarized", content)
        self.manifest["signing"] = "developer-id-notarized"
        self.write_manifest()
        self.assertNotIn("caveats", self.content())

    def test_modified_or_mismatched_packages_cannot_generate_a_cask(self):
        with self.assertRaises(ValueError):
            render(self.directory, "studio-v1.2.4")
        (self.directory / DMG_NAME).write_bytes(b"modified package")
        with self.assertRaises(ValueError):
            self.content()

    def test_unsupported_metadata_cannot_generate_a_cask(self):
        for key, value in [("architectures", ["arm64", "x86_64"]), ("minimumMacOS", "13.0"),
                           ("signing", "unknown"), ("version", '1.2.3"; system("unexpected")')]:
            with self.subTest(key=key):
                previous = self.manifest[key]
                self.manifest[key] = value
                self.write_manifest()
                with self.assertRaises(ValueError):
                    self.content()
                self.manifest[key] = previous

    @patch("homebrew.subprocess.run")
    @patch("homebrew.gh")
    def test_first_publication_creates_only_the_norna_cask(self, gh, run):
        gh.return_value = json.dumps([{"path": "Casks/youran-toolbox.rb"}])
        content = self.content()
        sync(content)
        arguments = run.call_args.args[0]
        self.assertIn(f"repos/dufu1991/homebrew-tap/contents/{CASK_PATH}", arguments)
        payload = json.loads(run.call_args.kwargs["input"])
        self.assertEqual(base64.b64decode(payload["content"]).decode(), content)
        self.assertEqual(payload["branch"], "main")
        self.assertNotIn("sha", payload)

    @patch("homebrew.subprocess.run")
    @patch("homebrew.gh")
    def test_updates_use_current_blob_sha(self, gh, run):
        previous = self.content().replace('version "1.2.3"', 'version "1.2.2"')
        gh.side_effect = [json.dumps([{"path": CASK_PATH}]),
                          json.dumps({"sha": "current-blob", "content": base64.b64encode(previous.encode()).decode()})]
        sync(self.content())
        self.assertEqual(json.loads(run.call_args.kwargs["input"])["sha"], "current-blob")

    @patch("homebrew.subprocess.run")
    @patch("homebrew.gh")
    def test_retries_and_older_releases_do_not_write(self, gh, run):
        for previous in [self.content(), self.content().replace('version "1.2.3"', 'version "2.0.0"')]:
            gh.side_effect = [json.dumps([{"path": CASK_PATH}]),
                              json.dumps({"sha": "current-blob", "content": base64.b64encode(previous.encode()).decode()})]
            sync(self.content())
            run.assert_not_called()

    @patch("homebrew.subprocess.run")
    @patch("homebrew.gh")
    def test_same_version_with_different_content_cannot_be_overwritten(self, gh, run):
        previous = self.content().replace(self.digest, "a" * 64)
        gh.side_effect = [json.dumps([{"path": CASK_PATH}]),
                          json.dumps({"sha": "current-blob", "content": base64.b64encode(previous.encode()).decode()})]
        with self.assertRaises(ValueError):
            sync(self.content())
        run.assert_not_called()

    def test_kit_release_uses_independent_studio_version_and_literal_release_url(self):
        self.manifest |= {"version": "1.2.3", "build": "18", "kitVersion": "0.4.0", "releaseTag": "v0.4.0"}
        self.write_manifest()
        content = render(self.directory, "v0.4.0")
        self.assertIn('version "1.2.3,18"', content)
        self.assertIn(f"releases/download/v0.4.0/{DMG_NAME}", content)
        self.assertNotIn('version "0.4.0"', content)
        self.assertGreater(cask_version(content), cask_version(self.content()))
        self.manifest["kitVersion"] = "0.4.1"
        self.write_manifest()
        with self.assertRaises(ValueError):
            render(self.directory, "v0.4.0")

    @patch("homebrew.subprocess.run")
    @patch("homebrew.gh")
    def test_followup_build_updates_even_when_studio_marketing_version_is_unchanged(self, gh, run):
        previous = self.content()
        self.manifest |= {"build": "18", "kitVersion": "0.4.0", "releaseTag": "v0.4.0"}
        self.write_manifest()
        content = render(self.directory, "v0.4.0")
        gh.side_effect = [json.dumps([{"path": CASK_PATH}]),
                          json.dumps({"sha": "current-blob", "content": base64.b64encode(previous.encode()).decode()})]
        sync(content)
        payload = json.loads(run.call_args.kwargs["input"])
        self.assertEqual(payload["sha"], "current-blob")
        self.assertEqual(base64.b64decode(payload["content"]).decode(), content)


if __name__ == "__main__":
    unittest.main()
