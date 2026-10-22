"""Release policy tests run without credentials or remote mutations."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "Scripts/Release"))
from github_release import is_release_candidate, prepare, publish, release_needed
from version import read_version


class ReleaseTests(unittest.TestCase):
    def test_version_file_is_strict_and_independent(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Version.xcconfig"
            path.write_text("MARKETING_VERSION = 2.3.4\nCURRENT_PROJECT_VERSION = 18\n")
            self.assertEqual(read_version(path), {"version": "2.3.4", "build": "18", "tag": "studio-v2.3.4"})
            for content in ["MARKETING_VERSION = 2.3.4\n", "MARKETING_VERSION = 01.2.3\nCURRENT_PROJECT_VERSION = 1\n",
                            "MARKETING_VERSION = 1.2.3-rc.1\nCURRENT_PROJECT_VERSION = 1\n",
                            "MARKETING_VERSION = 1.2.3\nCURRENT_PROJECT_VERSION = 0\n",
                            "MARKETING_VERSION = 1.2.3\nCURRENT_PROJECT_VERSION = 1\nMARKETING_VERSION = 2.0.0\n"]:
                path.write_text(content)
                with self.assertRaises(ValueError):
                    read_version(path)

    @patch("github_release.subprocess.check_output")
    def test_only_main_version_changes_or_explicit_dispatch_release(self, command):
        command.return_value = "README.md\nSources/NornaStudio/Editor/StudioView.swift\n"
        self.assertFalse(is_release_candidate("push", "refs/heads/main", "a" * 40, "b" * 40, ""))
        command.return_value += "Configuration/Studio-Version.xcconfig\n"
        self.assertTrue(is_release_candidate("push", "refs/heads/main", "a" * 40, "b" * 40, ""))
        self.assertTrue(is_release_candidate("push", "refs/heads/main", "0" * 40, "b" * 40, ""))
        self.assertEqual(command.call_args.args[0][:3], ["git", "ls-tree", "-r"])
        self.assertFalse(is_release_candidate("pull_request", "refs/heads/main", "", "b" * 40, ""))
        self.assertFalse(is_release_candidate("push", "refs/tags/v1.2.3", "", "b" * 40, ""))
        self.assertFalse(is_release_candidate("workflow_dispatch", "refs/heads/feature", "", "b" * 40, "true"))
        self.assertTrue(is_release_candidate("workflow_dispatch", "refs/heads/main", "", "b" * 40, "true"))
        self.assertFalse(is_release_candidate("workflow_dispatch", "refs/heads/main", "", "b" * 40, "false"))

    def test_published_versions_are_immutable_and_drafts_require_same_commit(self):
        metadata = {"version": "1.2.3", "build": "18", "tag": "studio-v1.2.3"}
        release = {"tag_name": metadata["tag"], "draft": False, "prerelease": False, "target_commitish": "a"}
        self.assertFalse(release_needed(metadata, [release], "b"))
        release["draft"] = True
        self.assertTrue(release_needed(metadata, [release], "a"))
        with self.assertRaises(ValueError):
            release_needed(metadata, [release], "b")
        release.update(tag_name="studio-v2.0.0", draft=False)
        with self.assertRaises(ValueError):
            release_needed(metadata, [release], "b")
        release["tag_name"] = "v9.0.0"
        self.assertTrue(release_needed(metadata, [release], "b"))

    @patch("github_release.gh")
    def test_orphaned_tag_cannot_publish_another_commit(self, gh):
        metadata = read_version()
        gh.side_effect = ["[[]]", json.dumps([{"ref": f"refs/tags/{metadata['tag']}"}]), "another-commit"]
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):
                prepare("owner/repo", "this-commit", Path(directory) / "outputs")

    @patch("github_release.gh")
    def test_partial_package_never_creates_a_release(self, gh):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "release.json").write_text(json.dumps(read_version() | {"commit": "a"}))
            with self.assertRaises(ValueError):
                publish("owner/repo", "a", path)
            gh.assert_not_called()

    @patch("github_release.gh")
    def test_assets_upload_to_a_draft_before_publication(self, gh):
        gh.side_effect = ["[[]]", "created", "uploaded", "published"]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "release.json").write_text(json.dumps(read_version() | {"commit": "a"}))
            for name in ["Norna-Studio-macOS-arm64.dmg", "Norna-Studio-macOS-arm64.zip", "SHA256SUMS.txt", "RELEASE_NOTES.md"]:
                (path / name).write_text("fixture")
            publish("owner/repo", "a", path)
            calls = [call.args for call in gh.call_args_list]
            self.assertIn("--draft", calls[1])
            self.assertEqual(calls[2][:2], ("release", "upload"))
            self.assertIn(str(path / "Norna-Studio-macOS-arm64.dmg"), calls[2])
            for name in ["Norna-Studio-macOS-arm64.zip", "release.json", "SHA256SUMS.txt"]:
                self.assertNotIn(str(path / name), calls[2])
            self.assertIn("--draft=false", calls[3])


if __name__ == "__main__":
    unittest.main()
