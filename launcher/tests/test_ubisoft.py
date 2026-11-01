#!/usr/bin/env python3
"""Ubisoft Connect install registration (roadmap 0008)."""

import importlib.machinery
import os
import unittest

hub = importlib.machinery.SourceFileLoader("hub", os.path.join(os.path.dirname(__file__), "..", "hub")).load_module()

CONFIG = r'''version: 2.0
root:
  name: "Far Cry 3"
  start_game:
    online:
      executables:
        - path:
            register: HKEY_CURRENT_USER\SOFTWARE\UBISOFT\Far Cry 3\ExecutableName
          working_directory:
            register: HKEY_LOCAL_MACHINE\SOFTWARE\UBISOFT\Far Cry 3\InstallDir
          evil_updater:
            path:
              relative: bin\FC3Updater.exe
            arguments: -write_registry
  installer:
    game_identifier: Far Cry 3
---
version: 2.0
root:
  start_game:
    online:
      executables:
        - working_directory:
            register: HKEY_LOCAL_MACHINE\SOFTWARE\Ubisoft\Launcher\Installs\720\InstallDir
  installer:
    game_identifier: "Assassin's Creed Unity"
---
version: 2.0
root:
  installer:
    game_identifier: Not Installed Here
  start_game:
    online:
      executables:
        - working_directory:
            register: HKEY_LOCAL_MACHINE\SOFTWARE\Ubisoft\Other\InstallDir
'''


class UbisoftRegistrationTests(unittest.TestCase):

    def test_each_installed_folder_gets_its_records_install_dir_key(self):
        regs = hub.ubisoft_install_registrations(CONFIG, ["Far Cry 3", "Assassin's Creed Unity"])
        self.assertEqual(regs, [("SOFTWARE\\UBISOFT\\Far Cry 3", "InstallDir", "Far Cry 3"),
                                ("SOFTWARE\\Ubisoft\\Launcher\\Installs\\720", "InstallDir", "Assassin's Creed Unity")])

    def test_folder_names_match_without_case(self):
        regs = hub.ubisoft_install_registrations(CONFIG, ["far cry 3"])
        self.assertEqual(regs[0][2], "far cry 3")

    def test_games_that_are_not_on_disk_are_left_alone(self):
        self.assertEqual(hub.ubisoft_install_registrations(CONFIG, []), [])


    def test_an_updater_written_executable_name_is_relative_to_the_install_dir(self):
        regs = hub.ubisoft_executable_registrations(CONFIG, {"Far Cry 3": "bin/farcry3_d3d11.exe", "Assassin's Creed Unity": "ACU.exe"})
        self.assertEqual(regs, [("SOFTWARE\\UBISOFT\\Far Cry 3", "ExecutableName", "Far Cry 3", "bin/farcry3_d3d11.exe")])


if __name__ == "__main__":
    unittest.main()
