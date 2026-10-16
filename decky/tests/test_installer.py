import io
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


if __name__ == "__main__":
    unittest.main()
