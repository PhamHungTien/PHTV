#!/usr/bin/env python3

import json
import plistlib
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class RepositoryPolicyTests(unittest.TestCase):
    def test_external_github_actions_are_pinned_to_full_commits(self):
        for workflow in (ROOT / ".github" / "workflows").glob("*.yml"):
            for line_number, line in enumerate(workflow.read_text(encoding="utf-8").splitlines(), 1):
                match = re.match(r"^\s*uses:\s*([^\s#]+)", line)
                if not match or match.group(1).startswith("./"):
                    continue
                reference = match.group(1)
                self.assertRegex(
                    reference,
                    r"^[^@]+@[0-9a-f]{40}$",
                    f"{workflow.relative_to(ROOT)}:{line_number} must use a full commit SHA",
                )

    def test_sparkle_resolution_is_checked_in_and_pinned(self):
        resolved_path = (
            ROOT
            / "App/PHTV.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
        )
        resolved = json.loads(resolved_path.read_text(encoding="utf-8"))
        sparkle = next(pin for pin in resolved["pins"] if pin["identity"] == "sparkle")
        self.assertEqual(sparkle["state"]["version"], "2.8.1")
        self.assertRegex(sparkle["state"]["revision"], r"^[0-9a-f]{40}$")

    def test_privacy_manifest_declares_picker_data(self):
        with (ROOT / "App/PHTV/PrivacyInfo.xcprivacy").open("rb") as handle:
            manifest = plistlib.load(handle)
        declared = {
            item["NSPrivacyCollectedDataType"]
            for item in manifest["NSPrivacyCollectedDataTypes"]
        }
        expected = {
            "NSPrivacyCollectedDataTypeUserID",
            "NSPrivacyCollectedDataTypeSearchHistory",
            "NSPrivacyCollectedDataTypeProductInteraction",
            "NSPrivacyCollectedDataTypeAdvertisingData",
            "NSPrivacyCollectedDataTypeCoarseLocation",
        }
        self.assertTrue(expected.issubset(declared))

    def test_picker_does_not_log_search_or_target_urls(self):
        source = (ROOT / "App/PHTV/Data/KlipyAPIClient.swift").read_text(encoding="utf-8")
        self.assertNotIn("url.absoluteString", source)
        self.assertNotIn("ad.targetURL", source)
        self.assertNotIn("search query", source.lower())

        picker_sources = [
            ROOT / "App/PHTV/Services/MediaStorageHelper.swift",
            ROOT / "App/PHTV/UI/Picker/ContentViews/GIFOnlyView.swift",
            ROOT / "App/PHTV/UI/Picker/ContentViews/StickerOnlyView.swift",
            ROOT / "App/PHTV/UI/Picker/ContentViews/UnifiedContentView.swift",
        ]
        logged_lines = "\n".join(
            line
            for path in picker_sources
            for line in path.read_text(encoding="utf-8").splitlines()
            if "NSLog" in line
        )
        for sensitive_value in ("fullURL", ".slug", ".lastPathComponent", ".absoluteString"):
            self.assertNotIn(sensitive_value, logged_lines)

    def test_legacy_nslog_count_cannot_grow(self):
        # Existing call sites are migrated incrementally. New code must use
        # PHTVLogger/os.Logger and may not increase this explicit debt budget.
        count = sum(
            path.read_text(encoding="utf-8").count("NSLog(")
            for path in (ROOT / "App/PHTV").rglob("*.swift")
        )
        self.assertLessEqual(count, 364)

    def test_no_unprotected_nonisolated_global_state(self):
        offenders = [
            str(path.relative_to(ROOT))
            for path in (ROOT / "App/PHTV").rglob("*.swift")
            if "nonisolated(unsafe)" in path.read_text(encoding="utf-8")
        ]
        self.assertEqual(offenders, [])

    def test_unchecked_sendable_debt_cannot_grow(self):
        count = sum(
            path.read_text(encoding="utf-8").count("@unchecked Sendable")
            for path in (ROOT / "App/PHTV").rglob("*.swift")
        )
        self.assertLessEqual(count, 36)

    def test_local_markdown_links_resolve(self):
        markdown_files = list(ROOT.glob("*.md"))
        markdown_files += list((ROOT / "docs").glob("*.md"))
        markdown_files += list((ROOT / ".github").glob("*.md"))
        markdown_files += list((ROOT / ".github/workflows").glob("*.md"))
        link_pattern = re.compile(r"(?<!!)\[[^]]*]\(([^)]+)\)")

        failures: list[str] = []
        for document in markdown_files:
            for target in link_pattern.findall(document.read_text(encoding="utf-8")):
                target = target.strip().strip("<>").split("#", 1)[0]
                if not target or re.match(r"^(https?://|mailto:)", target):
                    continue
                resolved = (document.parent / target).resolve()
                if not resolved.exists():
                    failures.append(f"{document.relative_to(ROOT)} -> {target}")
        self.assertEqual(failures, [], "Broken local Markdown links:\n" + "\n".join(failures))


if __name__ == "__main__":
    unittest.main()
