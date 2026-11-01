#!/usr/bin/env python3
"""Tests for the processes `hub play` offers the activation helper (roadmap 0016)."""

import importlib.machinery
import os
import unittest

hub = importlib.machinery.SourceFileLoader("hub", os.path.join(os.path.dirname(__file__), "..", "hub")).load_module()

STEAM = [
    (10, "01:00:00", r"E:\Library\Steam\steam.exe -silent"),
    (11, "59:00", r"E:\Library\Steam\bin\cef\cef.win64\steamwebhelper.exe -nocrashdialog"),
]


class ActivationCandidateTests(unittest.TestCase):

    def test_a_game_started_through_its_launcher_offers_both(self):
        # HITMAN 3: Launcher.exe (no window) is the process the hub finds; retail\hitman3.exe shows the game.
        rows = STEAM + [
            (20, "05:12", r'"E:\Library\Steam\steamapps\common\HITMAN 3\Launcher.exe" -SKIP_LAUNCHER'),
            (21, "05:10", r"retail\hitman3.exe -SKIP_LAUNCHER"),
        ]
        self.assertEqual(hub.activation_candidates(20, rows), [20, 21])

    def test_the_stores_and_wines_own_processes_are_left_out(self):
        rows = STEAM + [
            (20, "05:12", r"E:\Library\Steam\steamapps\common\Game\game.exe"),
            (22, "04:00", r"C:\windows\system32\conhost.exe"),
            (23, "03:00", r"E:\Library\Steam\bin\cef\cef.win64\steamwebhelper.exe --type=renderer"),
            (24, "04:30", r"E:\Library\Steam\gameoverlayui64.exe"),
            (25, "04:40", r"C:\Program Files (x86)\Ubisoft\Ubisoft Game Launcher\upc.exe"),
            (26, "04:41", r"C:\Program Files\Electronic Arts\EA Desktop\EA Desktop\EADesktop.exe"),
            (27, "04:42", r"Z:\x87sidecar\sidecar.exe"),
            (28, "02:00", "/usr/bin/caffeinate"),
        ]
        self.assertEqual(hub.activation_candidates(20, rows), [20])

    def test_processes_older_than_the_game_are_left_out(self):
        rows = STEAM + [
            (19, "10:00", r"C:\Games\Other\other.exe"),
            (20, "05:12", r"C:\Games\Game\game.exe"),
        ]
        self.assertEqual(hub.activation_candidates(20, rows), [20])

    def test_a_game_that_is_gone_is_still_offered_alone(self):
        self.assertEqual(hub.activation_candidates(99, STEAM), [99])

    def test_elapsed_times_in_every_ps_form(self):
        self.assertEqual(hub.etime_seconds("03:04"), 184)
        self.assertEqual(hub.etime_seconds("02:03:04"), 7384)
        self.assertEqual(hub.etime_seconds("1-02:03:04"), 93784)


if __name__ == "__main__":
    unittest.main()
