import fcntl
import os
import signal
import subprocess
import sys
import time
import tempfile
import unittest
from pathlib import Path

from tests import support  # noqa: F401
from opennow_decky import process


class LockHolderTests(unittest.TestCase):
    def setUp(self):
        self.data_dir = Path(tempfile.mkdtemp())

    def test_reads_a_real_flock_from_the_kernel(self):
        lock = self.data_dir / "core.lock"
        lock.write_text("")
        self.assertIsNone(process.lock_holder(self.data_dir))
        child = subprocess.Popen([sys.executable, "-c",
                                  "import fcntl, sys\n"
                                  "handle = open(sys.argv[1]); fcntl.flock(handle, fcntl.LOCK_EX)\n"
                                  "print('ready', flush=True); sys.stdin.readline()", str(lock)],
                                 stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        self.addCleanup(child.stdout.close)
        child.stdout.readline()
        self.assertEqual(process.lock_holder(self.data_dir), child.pid)
        child.communicate("\n", timeout=5)
        self.assertIsNone(process.lock_holder(self.data_dir))

    def test_checking_does_not_take_the_lock(self):
        lock = self.data_dir / "core.lock"
        lock.write_text("")
        process.lock_holder(self.data_dir)
        with open(lock) as handle:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)

    def test_missing_lock_file_means_not_running(self):
        self.assertIsNone(process.lock_holder(self.data_dir))

    def test_waiters_and_other_inodes_are_ignored(self):
        lock = self.data_dir / "core.lock"
        lock.write_text("")
        status = os.stat(lock)
        device = f"{os.major(status.st_dev):02x}:{os.minor(status.st_dev):02x}"
        locks = self.data_dir / "locks"
        locks.write_text(
            f"1: FLOCK  ADVISORY  WRITE 111 {device}:{status.st_ino + 1} 0 EOF\n"
            f"1: -> FLOCK  ADVISORY  WRITE 222 {device}:{status.st_ino} 0 EOF\n"
            f"2: POSIX  ADVISORY  WRITE 333 {device}:{status.st_ino} 0 EOF\n"
        )
        self.assertIsNone(process.lock_holder(self.data_dir, str(locks)))
        locks.write_text(locks.read_text() + f"3: FLOCK  ADVISORY  WRITE 444 {device}:{status.st_ino} 0 EOF\n")
        self.assertEqual(process.lock_holder(self.data_dir, str(locks)), 444)

    def test_core_lock_refuses_while_the_core_holds_it_and_blocks_the_core_while_writing(self):
        with open(self.data_dir / "core.lock", "w") as core:
            fcntl.flock(core, fcntl.LOCK_EX | fcntl.LOCK_NB)
            with self.assertRaises(process.CoreRunning):
                with process.core_lock(self.data_dir):
                    pass
            fcntl.flock(core, fcntl.LOCK_UN)
            with process.core_lock(self.data_dir):
                with self.assertRaises(BlockingIOError):
                    fcntl.flock(core, fcntl.LOCK_EX | fcntl.LOCK_NB)
            fcntl.flock(core, fcntl.LOCK_EX | fcntl.LOCK_NB)

    def test_the_plugins_own_settings_lock_is_never_reported_or_killed(self):
        with process.core_lock(self.data_dir):
            self.assertIsNone(process.lock_holder(self.data_dir))
            self.assertFalse(process.terminate(self.data_dir, grace_seconds=0.2))

    def test_a_holder_that_is_not_opennow_is_waited_for_not_killed(self):
        lock = self.data_dir / "core.lock"
        lock.write_text("")
        child = subprocess.Popen([sys.executable, "-c",
                                  "import fcntl, sys, time\n"
                                  "handle = open(sys.argv[1]); fcntl.flock(handle, fcntl.LOCK_EX)\n"
                                  "print('ready', flush=True); time.sleep(2)", str(lock)],
                                 stdout=subprocess.PIPE, text=True)
        self.addCleanup(child.stdout.close)
        child.stdout.readline()
        self.assertFalse(process.terminate(self.data_dir, grace_seconds=0.3))
        self.assertIsNone(child.poll())
        self.assertEqual(child.wait(timeout=5), 0)

    def test_terminate_waits_until_the_lock_is_released(self):
        lock = self.data_dir / "core.lock"
        lock.write_text("")
        child = subprocess.Popen([sys.executable, "-c",
                                  "import fcntl, signal, sys, time\n"
                                  "open('/proc/self/comm', 'w').write('opennow-core')\n"
                                  "signal.signal(signal.SIGTERM, lambda *a: None)\n"
                                  "handle = open(sys.argv[1]); fcntl.flock(handle, fcntl.LOCK_EX)\n"
                                  "print('ready', flush=True); time.sleep(60)", str(lock)],
                                 stdout=subprocess.PIPE, text=True)
        self.addCleanup(child.stdout.close)
        child.stdout.readline()
        self.assertEqual(process.lock_holder(self.data_dir), child.pid)
        self.assertTrue(process.terminate(self.data_dir, grace_seconds=0.5))
        self.assertIsNone(process.lock_holder(self.data_dir))
        child.wait(timeout=5)

    def test_stop_escalates_to_sigkill_when_sigterm_is_swallowed(self):
        child = subprocess.Popen([sys.executable, "-c",
                                  "import signal, time; signal.signal(signal.SIGTERM, lambda *a: None); print('ready', flush=True); time.sleep(60)"],
                                 stdout=subprocess.PIPE)
        self.addCleanup(child.stdout.close)
        child.stdout.readline()
        started = time.monotonic()
        self.assertTrue(process.stop(child.pid, grace_seconds=0.5))
        self.assertEqual(child.wait(timeout=5), -signal.SIGKILL)
        self.assertLess(time.monotonic() - started, 3)

    def test_stop_returns_once_sigterm_works(self):
        child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"])
        self.assertTrue(process.stop(child.pid, grace_seconds=5))
        self.assertEqual(child.wait(timeout=5), -signal.SIGTERM)

    def test_parent_pid_parses_names_with_spaces_and_parentheses(self):
        proc = self.data_dir / "proc"
        (proc / "42").mkdir(parents=True)
        (proc / "42" / "stat").write_text("42 (opennow (core) x) S 7 42 42 0 -1\n")
        self.assertEqual(process.parent_pid(42, str(proc)), 7)


if __name__ == "__main__":
    unittest.main()
