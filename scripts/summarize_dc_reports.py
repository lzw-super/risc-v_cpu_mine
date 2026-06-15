#!/usr/bin/env python3
"""Emit one CSV row summarizing an archived Design Compiler run."""

import argparse
import re
from pathlib import Path


def read(path):
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return ""


def grab(pattern, text, default="NA"):
    match = re.search(pattern, text, re.MULTILINE)
    return match.group(1) if match else default


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--period", required=True)
    parser.add_argument("--archive-dir", required=True)
    parser.add_argument("--design", default="pipeline_cpu_core")
    args = parser.parse_args()

    archive = Path(args.archive_dir)
    qor = read(archive / f"{args.design}.qor.rpt")
    area = read(archive / f"{args.design}.area.rpt")

    wns = grab(r"Design\s+WNS:\s+([-0-9.]+)", qor)
    tns = grab(r"Design\s+WNS:\s+[-0-9.]+\s+TNS:\s+([-0-9.]+)", qor)
    critical = grab(r"Critical Path Length:\s+([-0-9.]+)", qor)
    levels = grab(r"Levels of Logic:\s+([-0-9.]+)", qor)
    violations = grab(r"Number of Violating Paths:\s+([-0-9.]+)", qor)
    cell_area = grab(r"Total cell area:\s+([-0-9.]+)", area)

    print(
        ",".join(
            [
                args.period,
                str(archive),
                wns,
                tns,
                critical,
                levels,
                cell_area,
                violations,
            ]
        )
    )


if __name__ == "__main__":
    main()
