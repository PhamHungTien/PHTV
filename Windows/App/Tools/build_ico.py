#!/usr/bin/env python3
"""
Build Windows .ico files from PNG assets without external Python dependencies.

Requires:
- macOS: sips
"""

from __future__ import annotations

import argparse
import struct
import subprocess
import tempfile
from pathlib import Path


ICON_SIZES = (16, 20, 24, 32, 40, 48, 64, 96, 128, 256)


def run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True)


def ensure_file(path: Path) -> None:
    if not path.is_file():
        raise FileNotFoundError(f"Missing input file: {path}")


def resize_png(input_png: Path, output_png: Path, size: int) -> None:
    run(
        [
            "sips",
            "-z",
            str(size),
            str(size),
            str(input_png),
            "--out",
            str(output_png),
        ]
    )


def encode_ico_from_pngs(png_paths: list[Path], output_ico: Path) -> None:
    image_blobs: list[bytes] = [path.read_bytes() for path in png_paths]
    icon_count = len(image_blobs)
    if icon_count == 0:
        raise ValueError("No icon images were generated")

    header = struct.pack("<HHH", 0, 1, icon_count)
    dir_entries = bytearray()
    image_data = bytearray()
    offset = 6 + (16 * icon_count)

    for idx, blob in enumerate(image_blobs):
        size = ICON_SIZES[idx]
        width_byte = 0 if size >= 256 else size
        height_byte = 0 if size >= 256 else size

        # ICONDIRENTRY:
        # BYTE width, BYTE height, BYTE colorCount, BYTE reserved,
        # WORD planes, WORD bitCount, DWORD bytesInRes, DWORD imageOffset
        dir_entries.extend(
            struct.pack(
                "<BBBBHHII",
                width_byte,
                height_byte,
                0,
                0,
                1,
                32,
                len(blob),
                offset,
            )
        )
        image_data.extend(blob)
        offset += len(blob)

    output_ico.write_bytes(header + dir_entries + image_data)


def build_icon(input_png: Path, output_ico: Path) -> None:
    ensure_file(input_png)
    output_ico.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="phtv-ico-") as temp_dir:
        tmp_root = Path(temp_dir)
        resized: list[Path] = []
        for size in ICON_SIZES:
            out = tmp_root / f"{output_ico.stem}-{size}.png"
            resize_png(input_png, out, size)
            resized.append(out)
        encode_ico_from_pngs(resized, output_ico)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build PHTV Windows .ico assets.")
    parser.add_argument(
        "--assets-dir",
        default=str(Path(__file__).resolve().parents[1] / "Assets"),
        help="Path to Windows/App/Assets directory",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    assets_dir = Path(args.assets_dir).resolve()

    app_icon_source = assets_dir / "icon.png"
    tray_vi_source = assets_dir / "tray_vi.png"
    tray_en_source = assets_dir / "tray_en.png"

    app_icon_dest = assets_dir / "PHTV.ico"
    tray_vi_dest = assets_dir / "tray_vi.ico"
    tray_en_dest = assets_dir / "tray_en.ico"

    build_icon(app_icon_source, app_icon_dest)
    print(f"Generated: {app_icon_dest}")

    build_icon(tray_vi_source, tray_vi_dest)
    print(f"Generated: {tray_vi_dest}")

    build_icon(tray_en_source, tray_en_dest)
    print(f"Generated: {tray_en_dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
