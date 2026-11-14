#!/usr/bin/env python3
"""Tests for the Rockstar launcher's sessions: the pad device they get, and what `hub` leaves out of activation."""

import importlib.machinery
import os
import tempfile
import unittest
from pathlib import Path

hub = importlib.machinery.SourceFileLoader("hub", os.path.join(os.path.dirname(__file__), "..", "hub")).load_module()

MAPPED = {"054C/05C4": 0, "054C/0CE6": 0}   # the prefix as the NFS 2015 recipe leaves it
RAW = {"054C/05C4": 1, "054C/0CE6": 1}
UNSET = {"054C/05C4": None, "054C/0CE6": None}


class PadModeTests(unittest.TestCase):

    def test_a_rockstar_session_gets_the_raw_device(self):
        self.assertEqual(hub.pad_mode_changes("rockstar", MAPPED, None), RAW)
        self.assertEqual(hub.pad_mode_changes("rockstar", UNSET, None), RAW)

    def test_nothing_is_written_when_the_mode_is_already_right(self):
        self.assertEqual(hub.pad_mode_changes("rockstar", RAW, MAPPED), {})
        self.assertEqual(hub.pad_mode_changes("steam", MAPPED, None), {})

    def test_other_launchers_are_left_alone_until_the_hub_has_switched(self):
        self.assertEqual(hub.pad_mode_changes("steam", RAW, None), {})   # raw by the owner's choice, not the hub's

    def test_the_next_session_of_another_launcher_puts_back_what_was_there(self):
        self.assertEqual(hub.pad_mode_changes("steam", RAW, MAPPED), MAPPED)
        self.assertEqual(hub.pad_mode_changes("ea", RAW, UNSET), UNSET)   # None: the value is deleted

    def test_the_values_are_read_from_the_registry_file(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "system.reg").write_text(
                "[System\\\\ControlSet001\\\\Services\\\\winebus] 1790938456\n\"Start\"=dword:00000003\n\n"
                "[System\\\\ControlSet001\\\\Services\\\\winebus\\\\Devices\\\\054C/05C4] 1790938456\n#time=1dd525c5e7cd184\n"
                "\"Hidraw\"=dword:00000001\n\n"
                "[System\\\\ControlSet001\\\\Services\\\\winebus\\\\Devices\\\\054C/0CE6] 1790938456\n#time=1dd525c5e7cd418\n\n"
                "[System\\\\ControlSet001\\\\Services\\\\winehid] 1790938446\n\"Hidraw\"=dword:00000000\n")
            old, hub.PREFIX = hub.PREFIX, Path(d)
            try:
                self.assertEqual(hub.pad_hidraw(), {"054C/05C4": 1, "054C/0CE6": None})
            finally:
                hub.PREFIX = old


class RockstarProcessTests(unittest.TestCase):

    def test_the_launcher_and_its_helpers_are_not_the_game(self):
        rows = [
            (30, "06:00", r"C:\Program Files\Rockstar Games\Launcher\Launcher.exe"),
            (31, "05:50", r"C:\Program Files\Rockstar Games\Social Club\SocialClubHelper.exe --type=renderer"),
            (32, "05:55", r"C:\Program Files\Rockstar Games\Launcher\RockstarService.exe"),
            (40, "02:00", r"C:\Program Files\Rockstar Games\Red Dead Redemption 2\RDR2.exe -fromRGL"),
        ]
        self.assertEqual(hub.activation_candidates(40, rows), [40])


if __name__ == "__main__":
    unittest.main()
