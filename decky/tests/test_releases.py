import unittest

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

    def test_update_is_offered_only_for_a_newer_installed_version(self):
        self.assertTrue(releases.summarize(RELEASE, "1.0.3", "x86_64")["updateAvailable"])
        self.assertFalse(releases.summarize(RELEASE, "1.0.4", "x86_64")["updateAvailable"])
        self.assertFalse(releases.summarize(RELEASE, None, "x86_64")["updateAvailable"])
        self.assertEqual(releases.summarize(RELEASE, None, "x86_64")["version"], "1.0.4")


if __name__ == "__main__":
    unittest.main()
