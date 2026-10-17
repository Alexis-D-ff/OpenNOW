import subprocess
import unittest
from unittest import mock

from tests import support  # noqa: F401
from opennow_decky import releases

RELEASE = {"tag_name": "v1.0.4", "assets": [
    {"name": "OpenNOW-Qt-1.0.4-Linux-x64.flatpak.manifest.json", "browser_download_url": "https://github.com/m", "size": 1},
    {"name": "OpenNOW-Qt-1.0.4-Linux-x64.AppImage", "browser_download_url": "https://github.com/a", "size": 2},
    {"name": "OpenNOW-Qt-1.0.4-Linux-x64.flatpak", "browser_download_url": "https://github.com/x64", "size": 3},
    {"name": "OpenNOW-Qt-1.0.4-Linux-arm64.flatpak", "browser_download_url": "https://github.com/arm", "size": 4},
]}


class ReleaseTests(unittest.TestCase):
    def test_picks_the_flatpak_bundle_for_the_machine(self):
        self.assertEqual(releases.flatpak_asset(RELEASE, "x86_64")["url"], "https://github.com/x64")
        self.assertEqual(releases.flatpak_asset(RELEASE, "aarch64")["url"], "https://github.com/arm")
        self.assertIsNone(releases.flatpak_asset(RELEASE, "riscv64"))

    def test_flatpaks_architecture_wins_over_an_emulated_python(self):
        flatpak = subprocess.CompletedProcess([], 0, "aarch64\n", "")
        with mock.patch.object(releases.host, "run", return_value=flatpak) as run, \
                mock.patch.object(releases.platform, "machine", return_value="x86_64"):
            self.assertEqual(releases.flatpak_asset(RELEASE)["url"], "https://github.com/arm")
        run.assert_called_once_with(["flatpak", "--default-arch"], timeout=15)

    def test_architecture_falls_back_to_the_machine_without_flatpak(self):
        with mock.patch.object(releases.host, "run", side_effect=FileNotFoundError("flatpak")), \
                mock.patch.object(releases.platform, "machine", return_value="x86_64"):
            self.assertEqual(releases.flatpak_asset(RELEASE)["url"], "https://github.com/x64")

    def test_update_is_offered_only_for_a_newer_installed_version(self):
        self.assertTrue(releases.summarize(RELEASE, "1.0.3", "x86_64")["updateAvailable"])
        self.assertFalse(releases.summarize(RELEASE, "1.0.4", "x86_64")["updateAvailable"])
        self.assertFalse(releases.summarize(RELEASE, None, "x86_64")["updateAvailable"])
        self.assertEqual(releases.summarize(RELEASE, None, "x86_64")["version"], "1.0.4")

    def test_nightly_is_the_newest_published_prerelease_with_a_flatpak_for_the_machine(self):
        def release(tag, prerelease=True, draft=False, arch="x64"):
            return {"tag_name": tag, "prerelease": prerelease, "draft": draft,
                    "assets": [{"name": f"OpenNOW-Qt-{tag[1:]}-Linux-{arch}.flatpak", "browser_download_url": tag, "size": 1}]}

        recent = [release("v1.0.4-nightly.1203.1", draft=True), release("v1.0.4-nightly.1202.1", arch="arm64"),
                  release("v1.0.4-rc.1"), release("v1.0.3", prerelease=False), release("v1.0.4-nightly.1201.1"),
                  release("v1.0.4-nightly.1191.1")]
        self.assertEqual(releases.latest_nightly(recent, "x86_64")["tag_name"], "v1.0.4-nightly.1201.1")
        self.assertEqual(releases.latest_nightly(recent, "aarch64")["tag_name"], "v1.0.4-nightly.1202.1")
        self.assertIsNone(releases.latest_nightly([release("v1.0.3", prerelease=False)], "x86_64"))
        self.assertTrue(releases.summarize(recent[4], "1.0.3", "x86_64")["updateAvailable"])

    def test_an_unknown_installed_version_is_reported_rather_than_called_current(self):
        self.assertFalse(releases.summarize(RELEASE, None, "x86_64")["installedVersionKnown"])
        self.assertTrue(releases.summarize(RELEASE, "1.0.4", "x86_64")["installedVersionKnown"])


if __name__ == "__main__":
    unittest.main()
