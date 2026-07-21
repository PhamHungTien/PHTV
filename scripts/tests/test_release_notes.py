#!/usr/bin/env python3

import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "tools"))

from release_notes import (  # noqa: E402
    ReleaseNotesError,
    extract_release,
    inject_appcast,
    latest_appcast_version,
    latest_release_version,
    render_html,
    validate_appcast,
)


CHANGELOG = """# Changelog

## [Unreleased]

## [3.4.2] - 2026-07-22

### Tổng quan
Một bản cập nhật **ổn định** cho `PHTV`.

### Fixed
- Mục cấp một
  - Mục cấp hai được xuống
    dòng đúng.

## [3.4.1] - 2026-07-20

Nội dung cũ.
"""

APPCAST = """<?xml version="1.0" encoding="utf-8"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <item>
      <title>3.4.2</title>
      <sparkle:version>308</sparkle:version>
      <sparkle:shortVersionString>3.4.2</sparkle:shortVersionString>
      <enclosure url="https://example.test/PHTV.dmg" length="42" type="application/octet-stream" sparkle:edSignature="signature"/>
    </item>
  </channel>
</rss>
"""


class ReleaseNotesTests(unittest.TestCase):
    def test_extracts_latest_release_without_unreleased_section(self):
        self.assertEqual(latest_release_version(CHANGELOG), "3.4.2")
        body = extract_release(CHANGELOG, "3.4.2")
        self.assertIn("### Tổng quan", body)
        self.assertNotIn("Nội dung cũ", body)

    def test_renders_safe_nested_html(self):
        html = render_html("3.4.2", extract_release(CHANGELOG, "3.4.2"))
        self.assertIn("<h2>PHTV 3.4.2</h2>", html)
        self.assertIn("<strong>ổn định</strong>", html)
        self.assertIn("<code>PHTV</code>", html)
        self.assertIn("<li>Mục cấp hai được xuống dòng đúng.</li>", html)

    def test_injection_is_idempotent_and_valid(self):
        rendered = render_html("3.4.2", extract_release(CHANGELOG, "3.4.2"))
        first = inject_appcast(APPCAST, "3.4.2", rendered)
        second = inject_appcast(first, "3.4.2", rendered)
        self.assertEqual(first, second)

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "appcast.xml"
            path.write_text(second, encoding="utf-8")
            validate_appcast(path, "3.4.2", rendered)
            self.assertEqual(latest_appcast_version(path), "3.4.2")

    def test_missing_release_fails_closed(self):
        with self.assertRaises(ReleaseNotesError):
            extract_release(CHANGELOG, "9.9.9")


if __name__ == "__main__":
    unittest.main()
