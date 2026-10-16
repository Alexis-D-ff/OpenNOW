import asyncio
import fcntl
import json
import shlex
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tests import support


class PluginTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.home = Path(tempfile.mkdtemp())
        self.decky = support.install_fake_decky(self.home)
        import main
        main.decky = self.decky
        flatpak = subprocess.CompletedProcess([], 0, "      Commit: abc123\n", "")
        mock.patch("opennow_decky.install.run_quiet", return_value=flatpak).start()
        self.addCleanup(mock.patch.stopall)
        with mock.patch.object(main.Plugin, "_warm_catalog", new=mock.AsyncMock()):
            self.plugin = main.Plugin()
            await self.plugin._main()
        self.data_dir = self.home / ".var/app/io.github.opencloudgaming.OpenNOW/config/OpenNOW"

    async def test_game_shortcut_runs_the_flatpak_in_game_mode_with_a_direct_launch(self):
        command = await self.plugin.launch_command("102279111", "Tower of \"Fantasy\" & Co")
        self.assertEqual(command["exe"], '"/usr/bin/flatpak"')
        self.assertEqual(shlex.split(command["options"]), [
            "run", "--user", "io.github.opencloudgaming.OpenNOW", "--console",
            "--launch-app-id=102279111", "--launch-title=Tower of \"Fantasy\" & Co",
        ])

    async def test_desktop_layout_preference_drops_the_console_flag(self):
        await self.plugin.set_preference("consoleLayout", False)
        command = await self.plugin.launch_command()
        self.assertNotIn("--console", shlex.split(command["options"]))

    async def test_non_numeric_variant_is_refused(self):
        with self.assertRaises(ValueError):
            await self.plugin.launch_command("1; rm -rf ~")

    async def test_stream_settings_write_to_the_flatpak_data_dir(self):
        result = await self.plugin.get_stream_settings()
        self.assertFalse(result["locked"])
        await self.plugin.set_stream_setting("fps", 90)
        self.assertEqual(json.loads((self.data_dir / "settings.json").read_text())["fps"], 90)

    async def test_stream_settings_lock_while_the_core_holds_its_lock(self):
        with mock.patch("opennow_decky.process.lock_holder", return_value=123):
            self.assertTrue((await self.plugin.get_stream_settings())["locked"])
            self.assertTrue((await self.plugin.get_status())["running"])
        self.data_dir.mkdir(parents=True)
        with open(self.data_dir / "core.lock", "w") as core:
            fcntl.flock(core, fcntl.LOCK_EX | fcntl.LOCK_NB)
            with self.assertRaises(RuntimeError):
                await self.plugin.set_stream_setting("fps", 90)
        self.assertFalse((self.data_dir / "settings.json").exists())

    async def test_install_reports_progress_and_completion(self):
        release = {"version": "1.0.4", "asset": {"url": "https://github.com/x", "size": 1}, "updateAvailable": True}
        self.plugin.release = release

        def fake_install(url, size, work_dir, progress):
            progress("download", 0.5)
            progress("install", 1.0)

        with mock.patch("opennow_decky.installer.install_bundle", side_effect=fake_install):
            self.assertTrue(await self.plugin.install_opennow())
            await self.plugin.install_task
        await asyncio.sleep(0)
        events = [event for event, _ in self.decky.emitted]
        self.assertIn("install_progress", events)
        self.assertEqual(self.decky.emitted[-1], ("install_done", (True, "1.0.4")))
        self.assertIsNone(self.plugin.install_progress)
        status = await self.plugin.get_status()
        self.assertEqual(status["install"]["version"], "1.0.4")
        with mock.patch("opennow_decky.releases.fetch_latest", return_value={"tag_name": "v1.0.4", "assets": []}):
            self.assertFalse((await self.plugin.check_update())["updateAvailable"])
        with mock.patch("opennow_decky.releases.fetch_latest", return_value={"tag_name": "v1.0.5", "assets": []}):
            self.assertTrue((await self.plugin.check_update())["updateAvailable"])


if __name__ == "__main__":
    unittest.main()
