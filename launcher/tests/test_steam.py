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


if __name__ == "__main__":
    unittest.main()
