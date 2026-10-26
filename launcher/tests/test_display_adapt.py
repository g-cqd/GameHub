#!/usr/bin/env python3
"""Tests for display detection, safety rules, and Frostbite profile adaptation."""

import os
import shutil
import tempfile
import unittest

# Import functions from launcher/hub using SourceFileLoader
import importlib.machinery
loader = importlib.machinery.SourceFileLoader("hub", os.path.join(os.path.dirname(__file__), "..", "hub"))
hub = loader.load_module()


class DisplayAdaptationTests(unittest.TestCase):

    def test_compute_display_settings_4k(self):
        # 4K monitor scaled to 2560x1440 (5120x2880 backing pixels, 60Hz)
        w, h, hz_int, hz_float, retina_mode = hub.compute_display_settings(2560, 1440, 5120, 2880, 60.0)
        self.assertEqual((w, h), (5120, 2880))
        self.assertEqual(hz_int, 60)
        self.assertEqual(hz_float, "60.000000")
        self.assertEqual(retina_mode, "y")

    def test_compute_display_settings_retina_mbp(self):
        # 16-inch MacBook Pro: 1728x1117 points, 3456x2234 pixels, 120Hz
        w, h, hz_int, hz_float, retina_mode = hub.compute_display_settings(1728, 1117, 3456, 2234, 120.0)
        self.assertEqual((w, h), (3456, 2234))
        self.assertEqual(hz_int, 120)
        self.assertEqual(hz_float, "120.000000")
        self.assertEqual(retina_mode, "y")

    def test_compute_display_settings_14inch_mbp(self):
        # 14-inch MacBook Pro: 1512x982 points, 3024x1964 pixels, 120Hz
        w, h, hz_int, hz_float, retina_mode = hub.compute_display_settings(1512, 982, 3024, 1964, 120.0)
        self.assertEqual((w, h), (3024, 1964))
        self.assertEqual(hz_int, 120)
        self.assertEqual(retina_mode, "y")

    def test_compute_display_settings_1440p(self):
        # 1440p monitor: 2560x1440 points, 2560x1440 pixels, 144Hz
        w, h, hz_int, hz_float, retina_mode = hub.compute_display_settings(2560, 1440, 2560, 1440, 144.0)
        self.assertEqual((w, h), (2560, 1440))
        self.assertEqual(hz_int, 144)
        self.assertEqual(hz_float, "144.000000")
        self.assertEqual(retina_mode, "y")

    def test_update_profile_text_replaces_and_preserves(self):
        sample = (
            "GstAudio.Volume 1.000000\r\n"
            "GstRender.FullscreenEnabled 0\r\n"
            "GstRender.FullscreenMode 0\r\n"
            "GstRender.FullscreenRefreshRate 60.000000\r\n"
            "GstRender.FullscreenScreen 1\r\n"
            "GstRender.ResolutionHeight 1600\r\n"
            "GstRender.ResolutionHertz 0\r\n"
            "GstRender.ResolutionWidth 2560\r\n"
            "GstRender.TextureQuality 3\r\n"
        )
        updated = hub.update_profile_text(sample, width=3840, height=2160, hz_int=60, hz_float="60.000000")
        self.assertIn("GstRender.FullscreenEnabled 1\r\n", updated)
        self.assertIn("GstRender.FullscreenMode 1\r\n", updated)
        self.assertIn("GstRender.FullscreenScreen 0\r\n", updated)
        self.assertIn("GstRender.FullscreenRefreshRate 60.000000\r\n", updated)
        self.assertIn("GstRender.ResolutionWidth 3840\r\n", updated)
        self.assertIn("GstRender.ResolutionHeight 2160\r\n", updated)
        self.assertIn("GstRender.ResolutionHertz 60\r\n", updated)
        self.assertIn("GstAudio.Volume 1.000000\r\n", updated)
        self.assertIn("GstRender.TextureQuality 3\r\n", updated)

    def test_adapt_profile_file_with_backups(self):
        tmpdir = tempfile.mkdtemp()
        try:
            profile_path = os.path.join(tmpdir, "PROFSAVE_profile")
            with open(profile_path, "w", encoding="utf-8") as f:
                f.write(
                    "GstAudio.Volume 1.000000\n"
                    "GstRender.ResolutionHeight 1600\n"
                    "GstRender.ResolutionWidth 2560\n"
                )

            # First adapt
            changed = hub.adapt_profile_file(profile_path, width=3840, height=2160, hz_int=60, hz_float="60.000000")
            self.assertTrue(changed)

            with open(profile_path, "r", encoding="utf-8") as f:
                content = f.read()
            self.assertIn("GstRender.ResolutionWidth 3840\n", content)
            self.assertIn("GstRender.ResolutionHeight 2160\n", content)
            self.assertIn("GstRender.ResolutionHertz 60\n", content)

            # Check that a backup was created
            backups = [f for f in os.listdir(tmpdir) if f.startswith("PROFSAVE_profile.bak-")]
            self.assertEqual(len(backups), 1)

            # Second adapt with same values should be no-op and not create new backup
            changed2 = hub.adapt_profile_file(profile_path, width=3840, height=2160, hz_int=60, hz_float="60.000000")
            self.assertFalse(changed2)
            backups2 = [f for f in os.listdir(tmpdir) if f.startswith("PROFSAVE_profile.bak-")]
            self.assertEqual(len(backups2), 1)
        finally:
            shutil.rmtree(tmpdir)

    def test_update_user_reg_retina_mode(self):
        tmpdir = tempfile.mkdtemp()
        try:
            reg_path = os.path.join(tmpdir, "user.reg")
            with open(reg_path, "w", encoding="utf-8") as f:
                f.write(
                    'WINE REGISTRY Version 2\n\n'
                    '[Software\\\\Wine\\\\Mac Driver] 1792693461\n'
                    '#time=1dd62528eb509d8\n'
                    '"RetinaMode"="y"\n\n'
                    '[Software\\\\Wine\\\\Other] 123\n'
                    '"Foo"="bar"\n'
                )

            changed = hub.update_user_reg_retina(reg_path, "N")
            self.assertTrue(changed)

            with open(reg_path, "r", encoding="utf-8") as f:
                content = f.read()
            self.assertIn('"RetinaMode"="N"\n', content)
            self.assertIn('"Foo"="bar"\n', content)

            # Check unchanged
            changed2 = hub.update_user_reg_retina(reg_path, "N")
            self.assertFalse(changed2)
        finally:
            shutil.rmtree(tmpdir)

    def test_update_gtav_settings(self):
        sample = (
            '<Settings>\n'
            '  <video>\n'
            '    <ScreenWidth value="1920" />\n'
            '    <ScreenHeight value="1080" />\n'
            '    <RefreshRate value="60" />\n'
            '    <Windowed value="0" />\n'
            '  </video>\n'
            '</Settings>\n'
        )
        updated = hub.update_gtav_settings_text(sample, 3840, 2160, 60)
        self.assertIn('<ScreenWidth value="3840" />', updated)
        self.assertIn('<ScreenHeight value="2160" />', updated)
        self.assertIn('<RefreshRate value="60" />', updated)

    def test_update_generals_options(self):
        sample = (
            'AntiAliasing = 4\n'
            'Resolution = 1920 1080\n'
            'UseShadowDecals = yes\n'
        )
        updated = hub.update_ini_resolution_text(sample, "Resolution", "3840 2160")
        self.assertIn('Resolution = 3840 2160\n', updated)
        self.assertIn('AntiAliasing = 4\n', updated)

    def test_update_aoa_options(self):
        sample = (
            '[video]\n'
            '\tDefaultResolutionX = 1920\n'
            '\tDefaultResolutionY = 1080\n'
            '[system_values]\n'
            '\tDesktopWidth = 1920\n'
            '\tDesktopHeight = 1080\n'
        )
        updated = hub.update_aoa_options_text(sample, 3840, 2160)
        self.assertIn('DefaultResolutionX = 3840', updated)
        self.assertIn('DefaultResolutionY = 2160', updated)
        self.assertIn('DesktopWidth = 3840', updated)
        self.assertIn('DesktopHeight = 2160', updated)



if __name__ == "__main__":
    unittest.main()
