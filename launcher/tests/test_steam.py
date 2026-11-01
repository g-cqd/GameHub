#!/usr/bin/env python3
"""Tests for the Steam preparation the hub does before Steam and its games start."""

import importlib.machinery
import os
import tempfile
import unittest
from pathlib import Path

hub = importlib.machinery.SourceFileLoader("hub", os.path.join(os.path.dirname(__file__), "..", "hub")).load_module()


class SteamOverlayTests(unittest.TestCase):

    def test_every_overlay_file_the_client_restored_is_moved_aside(self):
        with tempfile.TemporaryDirectory() as d:
            steam = Path(d)
            for n in ("GameOverlayRenderer64.dll", "SteamOverlayVulkanLayer64.json", "steam.exe"):
                (steam / n).write_text("new")
            moved = hub.disable_steam_overlay(steam)
            self.assertEqual(sorted(moved), ["GameOverlayRenderer64.dll", "SteamOverlayVulkanLayer64.json"])
            self.assertFalse((steam / "GameOverlayRenderer64.dll").exists())
            self.assertTrue((steam / "_overlay-disabled/SteamOverlayVulkanLayer64.json").exists())
            self.assertTrue((steam / "steam.exe").exists())

    def test_a_restored_file_replaces_the_copy_disabled_earlier(self):
        with tempfile.TemporaryDirectory() as d:
            steam = Path(d)
            (steam / "_overlay-disabled").mkdir()
            (steam / "_overlay-disabled/GameOverlayRenderer64.dll").write_text("old")
            (steam / "GameOverlayRenderer64.dll").write_text("new")
            hub.disable_steam_overlay(steam)
            self.assertEqual((steam / "_overlay-disabled/GameOverlayRenderer64.dll").read_text(), "new")

    def test_nothing_to_move_creates_nothing(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(hub.disable_steam_overlay(Path(d)), [])
            self.assertFalse((Path(d) / "_overlay-disabled").exists())


class SteamStartTests(unittest.TestCase):
    """Roadmap 0031: a slow Steam start is waited for, a dead one is reported."""

    def test_logged_on_is_done_whatever_else(self):
        self.assertEqual(hub.steam_start_verdict(True, False, 999, 999), "ok")

    def test_a_slow_but_alive_steam_is_waited_for(self):
        self.assertEqual(hub.steam_start_verdict(False, True, 0, 300), "wait")

    def test_a_short_disappearance_is_a_relaunch_not_a_death(self):
        self.assertEqual(hub.steam_start_verdict(False, False, 5, 40), "wait")

    def test_steam_gone_past_the_grace_period_died(self):
        self.assertEqual(hub.steam_start_verdict(False, False, 10, 40), "died")

    def test_the_limit_ends_the_wait(self):
        self.assertEqual(hub.steam_start_verdict(False, True, 0, hub.STEAM_LOGON_LIMIT), "timeout")


if __name__ == "__main__":
    unittest.main()
