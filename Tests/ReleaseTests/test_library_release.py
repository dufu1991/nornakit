"""Verify independent Kit publication and the matching Studio companion offline."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "Scripts/Release"))
import library_release as library
from version import read_version


class LibraryReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.kit = {"version": "0.1.0", "tag": "v0.1.0"}
        self.studio = {"version": "0.1.1", "build": "7", "tag": "studio-v0.1.1"}
        self.manifest = self.studio | {"commit": "source", "kitVersion": "0.1.0", "releaseTag": "v0.1.0",
                                      "architectures": ["arm64"], "minimumMacOS": "14.0", "signing": "ad-hoc"}
        self.changelog = "# NornaKit\n\n## 0.1.0 — 2026-10-22\n\nFix native borders.\n\n## 0.0.1\n\nOld notes.\n"

    def package(self):
        for name in library.ASSETS[:2]:
            (self.directory / name).write_bytes(b"native package")
        (self.directory / "release.json").write_text(json.dumps(self.manifest))
        (self.directory / "SHA256SUMS.txt").write_text("".join(
            hashlib.sha256((self.directory / name).read_bytes()).hexdigest() + "  " + name + "\n"
            for name in [*library.ASSETS[:2], "release.json"]))

    def test_kit_configuration_has_its_own_version_namespace(self):
        path = self.directory / "kit.json"
        path.write_text('{"version":"0.1.0"}')
        self.assertEqual(library.read_library_version(path), self.kit)
        self.assertNotEqual(library.read_library_version(path)["tag"], read_version()["tag"])
        for value in [{"version": "studio-v0.1.0"}, {"version": "01.2.3"}, {"version": "1.2.3", "build": "7"}]:
            path.write_text(json.dumps(value))
            with self.assertRaises(ValueError):
                library.read_library_version(path)

    def test_notes_are_required_for_the_exact_library_version(self):
        self.assertEqual(library.changelog_notes(self.changelog, "0.1.0"), "Fix native borders.")
        self.assertEqual(library.changelog_notes("## 1.2.3\nFirst line.\n", "1.2.3"), "First line.")
        for source in [self.changelog, "## 1.2.3\n\n", "## 1.2.30\nOther version.\n"]:
            with self.assertRaises(ValueError):
                library.changelog_notes(source, "1.2.3")

    @patch("library_release.read_library_version")
    @patch("github_release.subprocess.check_output")
    def test_only_explicit_kit_changes_or_matching_tags_publish(self, command, metadata):
        metadata.return_value = self.kit
        command.return_value = "Configuration/Studio-Version.xcconfig\n"
        self.assertFalse(library.candidate("push", "refs/heads/main", "a", "b", "false"))
        command.return_value += "Configuration/Kit-Version.json\n"
        self.assertTrue(library.candidate("push", "refs/heads/main", "a", "b", "false"))
        self.assertTrue(library.candidate("push", "refs/tags/v0.1.0", "a", "b", "false"))
        self.assertFalse(library.candidate("push", "refs/tags/studio-v0.1.0", "a", "b", "false"))
        self.assertFalse(library.candidate("push", "refs/tags/v0.1.1", "a", "b", "false"))
        self.assertFalse(library.candidate("pull_request", "refs/heads/main", "a", "b", "true"))
        self.assertFalse(library.candidate("workflow_dispatch", "refs/heads/feature", "a", "b", "true"))
        self.assertTrue(library.candidate("workflow_dispatch", "refs/heads/main", "a", "b", "true"))

    def test_library_versions_are_immutable_and_independent_of_studio(self):
        item = {"tag_name": "v0.1.0", "draft": False, "prerelease": False, "target_commitish": "source"}
        self.assertFalse(library.release_needed(self.kit, [item], "another"))
        item["draft"] = True
        self.assertTrue(library.release_needed(self.kit, [item], "source"))
        with self.assertRaises(ValueError):
            library.release_needed(self.kit, [item], "another")
        item.update(tag_name="v0.2.0", draft=False)
        with self.assertRaises(ValueError):
            library.release_needed(self.kit, [item], "source")
        item["tag_name"] = "studio-v9.0.0"
        self.assertTrue(library.release_needed(self.kit, [item], "source"))

    @patch("library_release.gh")
    def test_existing_tag_source_is_reused_without_moving_it(self, gh):
        gh.side_effect = [json.dumps([{"ref": "refs/tags/v0.1.0"}]), "verified-source"]
        self.assertEqual(library.source_target("owner/repo", self.kit, "new-main"), "verified-source")
        self.assertTrue(all(call.args[0] == "api" for call in gh.call_args_list))

    def test_companion_metadata_separates_kit_and_studio_versions(self):
        self.package()
        result = library.validate_companion(self.directory, self.kit, "source", self.studio)
        self.assertEqual(result["version"], "0.1.1")
        self.assertEqual(result["kitVersion"], "0.1.0")
        self.assertEqual(result["releaseTag"], "v0.1.0")
        for key, value in [("commit", "another"), ("build", "6"), ("kitVersion", "0.1.1"), ("releaseTag", "studio-v0.1.1")]:
            previous = self.manifest[key]
            self.manifest[key] = value
            self.package()
            with self.assertRaises(ValueError):
                library.validate_companion(self.directory, self.kit, "source", self.studio)
            self.manifest[key] = previous

    def test_missing_or_corrupt_companion_assets_cannot_publish(self):
        with self.assertRaises(ValueError):
            library.validate_companion(self.directory, self.kit, "source", self.studio)
        self.package()
        (self.directory / library.ASSETS[0]).write_bytes(b"corrupt")
        with self.assertRaises(ValueError):
            library.validate_companion(self.directory, self.kit, "source", self.studio)

    @patch("library_release.gh")
    def test_following_a_kit_release_requires_a_new_companion_build(self, gh):
        previous = [{"draft": False, "prerelease": False, "assets": [{"name": "release.json", "id": 7}]}]
        gh.return_value = json.dumps({"version": "0.1.1", "build": "6"})
        library.validate_studio_build("owner/repo", self.studio, previous)
        gh.return_value = json.dumps({"version": "0.1.1", "build": "7"})
        with self.assertRaises(ValueError):
            library.validate_studio_build("owner/repo", self.studio, previous)

    @patch("library_release.read_version")
    @patch("library_release.read_library_version")
    @patch("library_release.subprocess.check_output")
    @patch("library_release.gh")
    def test_kit_notes_lead_and_assets_upload_before_publication(self, gh, source, kit, studio):
        kit.return_value, studio.return_value = self.kit, self.studio
        source.return_value = self.changelog
        gh.side_effect = ["[]", "[[]]", "created", "uploaded", "published"]
        self.package()
        library.publish("owner/repo", "source", self.directory)
        calls = [call.args for call in gh.call_args_list]
        self.assertIn("--draft", calls[2])
        self.assertIn("NornaKit 0.1.0", calls[2])
        self.assertEqual(calls[3][:2], ("release", "upload"))
        self.assertIn("--draft=false", calls[4])
        self.assertIn("--latest", calls[4])
        notes = (self.directory / "KIT_RELEASE_NOTES.md").read_text()
        self.assertTrue(notes.startswith("# NornaKit 0.1.0\n"))
        self.assertIn("Fix native borders.", notes)
        self.assertIn("Norna Studio 0.1.1 (build 7)", notes)
        self.assertNotIn("Old notes", notes)

    @patch("library_release.read_version")
    @patch("library_release.read_library_version")
    @patch("library_release.gh")
    def test_tag_race_is_rejected_before_any_release_mutation(self, gh, kit, studio):
        kit.return_value, studio.return_value = self.kit, self.studio
        gh.side_effect = [json.dumps([{"ref": "refs/tags/v0.1.0"}]), "another-source"]
        with self.assertRaises(ValueError):
            library.publish("owner/repo", "source", self.directory)
        self.assertTrue(all(call.args[0] == "api" for call in gh.call_args_list))


if __name__ == "__main__":
    unittest.main()
