import io
import subprocess
import tempfile
import threading
import unittest
from pathlib import Path
from unittest import mock

from tests import support  # noqa: F401
from opennow_decky import installer


class FakeResponse(io.BytesIO):
    headers = {"Content-Length": str(4 * installer.CHUNK)}


class DownloadTests(unittest.TestCase):
    def setUp(self):
        self.destination = Path(tempfile.mkdtemp()) / "OpenNOW.flatpak"

    def test_download_reports_progress_and_leaves_no_partial_file(self):
        seen = []
        with mock.patch.object(installer, "open_url", return_value=FakeResponse(b"x" * 4 * installer.CHUNK)):
            installer.download("https://github.com/a", self.destination, 0, lambda phase, f: seen.append(f), threading.Event())
        self.assertEqual(seen[-1], 1.0)
        self.assertEqual(self.destination.stat().st_size, 4 * installer.CHUNK)
        self.assertFalse(self.destination.with_name("OpenNOW.flatpak.part").exists())

    def test_cancelling_stops_the_download_before_flatpak_runs(self):
        cancelled = threading.Event()

        def progress(phase, fraction):
            cancelled.set()

        with mock.patch.object(installer, "open_url", return_value=FakeResponse(b"x" * 4 * installer.CHUNK)), \
                mock.patch.object(installer, "run_checked") as run:
            with self.assertRaises(installer.Cancelled):
                installer.install_bundle("https://github.com/a", 0, self.destination.parent, progress, cancelled)
        run.assert_not_called()
        self.assertEqual(list(self.destination.parent.iterdir()), [])

    def test_downloads_only_come_from_github(self):
        with self.assertRaises(ValueError):
            installer.download("https://example.com/a", self.destination, 0, lambda *a: None, threading.Event())



class FlatpakStepTests(unittest.TestCase):
    def setUp(self):
        self.work = Path(tempfile.mkdtemp())
        self.calls = []
        self.installed = False
        self.progress = []
        mock.patch.object(installer, "download", side_effect=lambda url, path, *a: path.write_bytes(b"bundle")).start()
        mock.patch.object(installer.shutil, "which", return_value="/usr/bin/flatpak").start()
        mock.patch.object(installer.host, "run", side_effect=self.run_flatpak).start()
        mock.patch.object(installer, "DROIDDECK_FLATPAK", str(self.work / "missing")).start()
        self.addCleanup(mock.patch.stopall)

    def run_flatpak(self, command, timeout):
        self.calls.append(command)
        if command[1] == "install":
            self.installed = True
        installed = self.installed or (self.work / "installed").exists()
        code = 0 if command[1] != "info" or installed else 1
        return subprocess.CompletedProcess(command, code, "", "")

    def helper(self, body: str) -> Path:
        path = self.work / "droiddeck-flatpak"
        path.write_text("#!/bin/sh\necho \"$@\" > \"$(dirname \"$0\")/args\"\n" + body)
        path.chmod(0o755)
        installer.DROIDDECK_FLATPAK = str(path)
        return path

    def install(self):
        installer.install_bundle("https://github.com/a", 0, self.work, lambda phase, f: self.progress.append((phase, f)),
                                 threading.Event())

    def test_steam_deck_reinstalls_through_the_flatpak_cli(self):
        self.installed = True
        self.install()
        self.assertIn(["flatpak", "install", "--user", "--noninteractive", "-y", "--reinstall",
                       str(self.work / "OpenNOW.flatpak")], self.calls)
        self.assertEqual(self.progress[-1], ("install", 1.0))
        self.assertFalse((self.work / "OpenNOW.flatpak").exists())

    def test_droiddeck_installs_through_its_helper_with_progress(self):
        self.helper("echo 'not json'\n"
                    "echo '{\"e\":\"progress\",\"i\":1,\"n\":2,\"percent\":50}'\n"
                    "echo '{\"e\":\"progress\",\"i\":2,\"n\":2,\"percent\":100}'\n"
                    "touch \"$(dirname \"$0\")/installed\"\n"
                    "echo '{\"e\":\"done\"}'\n")
        self.install()
        self.assertEqual((self.work / "args").read_text().strip(), f"install-bundle {self.work / 'OpenNOW.flatpak'}")
        self.assertNotIn("install", [command[1] for command in self.calls])
        self.assertEqual([f for phase, f in self.progress if phase == "install"], [0.0, 0.25, 1.0, 1.0])

    def test_droiddeck_update_reinstalls_because_its_helper_skips_installed_apps(self):
        self.helper("exit 0\n")
        self.installed = True
        self.install()
        self.assertFalse((self.work / "args").exists())
        self.assertIn("--reinstall", self.calls[-2])

    def test_droiddeck_helper_errors_reach_the_user(self):
        self.helper("echo '{\"e\":\"error\",\"message\":\"runtime/org.kde.Platform: no space\"}'\nexit 1\n")
        with self.assertRaisesRegex(installer.InstallError, "no space"):
            self.install()

    def test_a_stalled_droiddeck_helper_is_killed_and_reported(self):
        self.helper("sleep 30\n")
        with mock.patch.object(installer, "INSTALL_TIMEOUT", 0.5), \
                self.assertRaisesRegex(installer.InstallError, "didn't finish within 0.5 seconds"):
            self.install()

    def test_missing_flatpak_on_droiddeck_points_at_its_store(self):
        self.helper("exit 0\n")
        installer.shutil.which.return_value = None
        with self.assertRaisesRegex(installer.InstallError, "DroidDeck's Store"):
            self.install()
        self.assertEqual(self.calls, [])

    def test_a_flatpak_timeout_is_an_install_error(self):
        installer.host.run.side_effect = subprocess.TimeoutExpired(["flatpak"], 60)
        with self.assertRaisesRegex(installer.InstallError, "didn't finish within 60 seconds"):
            self.install()


if __name__ == "__main__":
    unittest.main()
