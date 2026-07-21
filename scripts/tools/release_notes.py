#!/usr/bin/env python3
"""Render and validate PHTV release notes from CHANGELOG.md.

The changelog is the single source of truth. The release workflow uses this
tool to create the GitHub release body and to inject equivalent HTML into each
architecture-specific Sparkle appcast.
"""

from __future__ import annotations

import argparse
import html
import re
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path


RELEASE_HEADING = re.compile(r"^## \[(?P<version>[^]]+)](?:\s+-\s+.+)?$", re.MULTILINE)
INLINE_CODE = re.compile(r"`([^`]+)`")
INLINE_STRONG = re.compile(r"\*\*([^*]+)\*\*")
INLINE_LINK = re.compile(r"\[([^]]+)]\((https?://[^)]+)\)")
SPARKLE_NAMESPACE = "http://www.andymatuschak.org/xml-namespaces/sparkle"


class ReleaseNotesError(RuntimeError):
    """Raised when release metadata is missing or inconsistent."""


@dataclass
class ListItem:
    text: str
    children: list["ListItem"] = field(default_factory=list)


def extract_release(changelog: str, version: str) -> str:
    matches = list(RELEASE_HEADING.finditer(changelog))
    for index, match in enumerate(matches):
        if match.group("version") != version:
            continue
        end = matches[index + 1].start() if index + 1 < len(matches) else len(changelog)
        body = changelog[match.end() : end].strip()
        if not body:
            raise ReleaseNotesError(f"CHANGELOG entry for {version} is empty")
        return body
    raise ReleaseNotesError(f"CHANGELOG.md has no release entry for {version}")


def latest_release_version(changelog: str) -> str:
    for match in RELEASE_HEADING.finditer(changelog):
        version = match.group("version")
        if version.lower() != "unreleased":
            return version
    raise ReleaseNotesError("CHANGELOG.md has no released version")


def latest_appcast_version(path: Path) -> str:
    """Return the first Sparkle item version from an appcast."""
    try:
        root = ET.parse(path).getroot()
    except (ET.ParseError, OSError) as error:
        raise ReleaseNotesError(f"Invalid appcast {path}: {error}") from error

    namespace = {"sparkle": SPARKLE_NAMESPACE}
    item = root.find("./channel/item")
    version = item.find("sparkle:shortVersionString", namespace) if item is not None else None
    value = (version.text or "").strip() if version is not None else ""
    if not value:
        raise ReleaseNotesError(f"Appcast has no current short version: {path}")
    return value


def render_inline(value: str) -> str:
    rendered = html.escape(value, quote=True)
    rendered = INLINE_CODE.sub(r"<code>\1</code>", rendered)
    rendered = INLINE_STRONG.sub(r"<strong>\1</strong>", rendered)
    rendered = INLINE_LINK.sub(r'<a href="\2">\1</a>', rendered)
    return rendered


def _parse_list(lines: list[str], start: int) -> tuple[list[ListItem], int]:
    roots: list[ListItem] = []
    stack: list[ListItem] = []
    index = start

    while index < len(lines):
        line = lines[index]
        bullet = re.match(r"^(?P<indent>\s*)-\s+(?P<text>.+)$", line)
        if bullet:
            depth = len(bullet.group("indent").expandtabs(4)) // 2
            item = ListItem(bullet.group("text").strip())
            if depth == 0 or not stack:
                roots.append(item)
                stack = [item]
            else:
                depth = min(depth, len(stack))
                parent = stack[depth - 1]
                parent.children.append(item)
                stack = stack[:depth] + [item]
            index += 1
            continue

        if not line.strip():
            next_index = index + 1
            while next_index < len(lines) and not lines[next_index].strip():
                next_index += 1
            if next_index < len(lines) and re.match(r"^\s*-\s+", lines[next_index]):
                index = next_index
                continue
            break

        if line[:1].isspace() and stack:
            stack[-1].text += " " + line.strip()
            index += 1
            continue

        break

    return roots, index


def _render_list(items: list[ListItem], output: list[str]) -> None:
    output.append("<ul>")
    for item in items:
        if item.children:
            output.append(f"<li>{render_inline(item.text)}")
            _render_list(item.children, output)
            output.append("</li>")
        else:
            output.append(f"<li>{render_inline(item.text)}</li>")
    output.append("</ul>")


def render_html(version: str, body: str) -> str:
    lines = body.splitlines()
    output = [f"<h2>PHTV {html.escape(version)}</h2>"]
    index = 0

    while index < len(lines):
        line = lines[index]
        if not line.strip():
            index += 1
            continue

        heading = re.match(r"^(#{3,6})\s+(.+)$", line)
        if heading:
            level = len(heading.group(1))
            output.append(f"<h{level}>{render_inline(heading.group(2))}</h{level}>")
            index += 1
            continue

        if re.match(r"^\s*-\s+", line):
            items, index = _parse_list(lines, index)
            _render_list(items, output)
            continue

        paragraph = [line.strip()]
        index += 1
        while index < len(lines):
            candidate = lines[index]
            if (
                not candidate.strip()
                or re.match(r"^#{3,6}\s+", candidate)
                or re.match(r"^\s*-\s+", candidate)
            ):
                break
            paragraph.append(candidate.strip())
            index += 1
        output.append(f"<p>{render_inline(' '.join(paragraph))}</p>")

    return "\n".join(output)


def render_markdown(version: str, body: str) -> str:
    return f"# PHTV {version}\n\n{body.strip()}\n"


def _description_block(rendered_html: str, indent: str = "            ") -> str:
    html_lines = "\n".join(f"{indent}    {line}" for line in rendered_html.splitlines())
    return (
        f"{indent}<description><![CDATA[\n"
        f"{html_lines}\n"
        f"{indent}]]></description>"
    )


def inject_appcast(appcast: str, version: str, rendered_html: str) -> str:
    item_pattern = re.compile(r"(?P<item>\s*<item>.*?</item>)", re.DOTALL)
    version_marker = f"<sparkle:shortVersionString>{version}</sparkle:shortVersionString>"
    for match in item_pattern.finditer(appcast):
        item = match.group("item")
        if version_marker not in item:
            continue

        enclosure_match = re.search(r"(?m)^(?P<indent>[ \t]*)<enclosure\s", item)
        if enclosure_match is None:
            raise ReleaseNotesError(f"Appcast item {version} has no enclosure")
        description = _description_block(rendered_html, enclosure_match.group("indent"))

        if "<description>" in item:
            updated_item = re.sub(
                r"\n[ \t]*<description><!\[CDATA\[.*?\]\]></description>",
                "\n" + description,
                item,
                count=1,
                flags=re.DOTALL,
            )
        else:
            updated_item = re.sub(
                r"(?m)^(?P<indent>[ \t]*)<enclosure\s",
                description + r"\n\g<indent><enclosure ",
                item,
                count=1,
            )
        return appcast[: match.start()] + updated_item + appcast[match.end() :]

    raise ReleaseNotesError(f"Appcast has no item for {version}")


def validate_appcast(path: Path, version: str, expected_html: str) -> None:
    try:
        root = ET.parse(path).getroot()
    except (ET.ParseError, OSError) as error:
        raise ReleaseNotesError(f"Invalid appcast {path}: {error}") from error

    namespace = {"sparkle": SPARKLE_NAMESPACE}
    for item in root.findall("./channel/item"):
        short_version = item.find("sparkle:shortVersionString", namespace)
        if short_version is None or (short_version.text or "").strip() != version:
            continue

        description = item.find("description")
        actual_html = (description.text or "").strip() if description is not None else ""
        normalized_actual = "\n".join(line.strip() for line in actual_html.splitlines())
        normalized_expected = "\n".join(line.strip() for line in expected_html.strip().splitlines())
        if normalized_actual != normalized_expected:
            raise ReleaseNotesError(f"Appcast description for {version} is missing or stale: {path}")

        enclosure = item.find("enclosure")
        if enclosure is None:
            raise ReleaseNotesError(f"Appcast item {version} has no enclosure: {path}")
        required = ["url", "length", f"{{{SPARKLE_NAMESPACE}}}edSignature"]
        missing = [attribute for attribute in required if not enclosure.get(attribute)]
        if missing:
            raise ReleaseNotesError(
                f"Appcast item {version} is missing {', '.join(missing)}: {path}"
            )
        return

    raise ReleaseNotesError(f"Appcast has no item for {version}: {path}")


def write_output(value: str, output: Path | None) -> None:
    if output is None:
        sys.stdout.write(value)
        if not value.endswith("\n"):
            sys.stdout.write("\n")
        return
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(value, encoding="utf-8")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--changelog", type=Path, default=Path("CHANGELOG.md"))
    subparsers = parser.add_subparsers(dest="command", required=True)

    latest = subparsers.add_parser("latest", help="Print the latest released version")
    latest.set_defaults(command="latest")

    appcast_version = subparsers.add_parser(
        "appcast-version", help="Print the first version in a Sparkle feed"
    )
    appcast_version.add_argument("--appcast", type=Path, required=True)

    render = subparsers.add_parser("render", help="Render one changelog release")
    render.add_argument("--version", required=True)
    render.add_argument("--format", choices=["markdown", "html"], required=True)
    render.add_argument("--output", type=Path)

    inject = subparsers.add_parser("inject-appcast", help="Inject HTML into a Sparkle feed")
    inject.add_argument("--version", required=True)
    inject.add_argument("--appcast", type=Path, required=True)

    check = subparsers.add_parser("check", help="Validate changelog and optional appcasts")
    check.add_argument("--version", required=True)
    check.add_argument("--appcast", type=Path, action="append", default=[])

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    try:
        if args.command == "appcast-version":
            print(latest_appcast_version(args.appcast))
            return 0

        changelog = args.changelog.read_text(encoding="utf-8")
        if args.command == "latest":
            print(latest_release_version(changelog))
            return 0

        body = extract_release(changelog, args.version)
        rendered_html = render_html(args.version, body)

        if args.command == "render":
            value = (
                render_markdown(args.version, body)
                if args.format == "markdown"
                else rendered_html + "\n"
            )
            write_output(value, args.output)
        elif args.command == "inject-appcast":
            original = args.appcast.read_text(encoding="utf-8")
            updated = inject_appcast(original, args.version, rendered_html)
            args.appcast.write_text(updated, encoding="utf-8")
            validate_appcast(args.appcast, args.version, rendered_html)
        elif args.command == "check":
            for appcast in args.appcast:
                validate_appcast(appcast, args.version, rendered_html)
            print(f"Release metadata is valid for PHTV {args.version}")
        return 0
    except (OSError, ReleaseNotesError) as error:
        print(f"release-notes: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
