#!/usr/bin/env python3
"""Check DC timing artifacts for the Fmax optimization flow."""

import argparse
import math
import re
import sys
from pathlib import Path


def read_text(path):
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        raise SystemExit(f"missing required file: {path}")


def expect_close(name, actual, expected, tol=1e-3):
    if not math.isclose(actual, expected, abs_tol=tol):
        raise SystemExit(f"{name}: expected {expected:.3f}, found {actual:.3f}")


def find_number(pattern, text, name):
    match = re.search(pattern, text, re.MULTILINE)
    if not match:
        raise SystemExit(f"could not find {name}")
    return float(match.group(1))


def first_setup_path(timing_text):
    start = timing_text.find("Startpoint:")
    if start < 0:
        raise SystemExit("timing report does not contain a setup Startpoint")
    end = timing_text.find("\n\n", timing_text.find("slack", start))
    if end < 0:
        end = len(timing_text)
    return timing_text[start:end]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--report-dir", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--design", default="pipeline_cpu_core")
    parser.add_argument("--period", type=float, required=True)
    parser.add_argument("--require-proportional-constraints", action="store_true")
    parser.add_argument("--require-setup-path", action="store_true")
    parser.add_argument("--reject-mdu-final-path", action="store_true")
    parser.add_argument("--max-critical-path", type=float)
    args = parser.parse_args()

    report_dir = Path(args.report_dir)
    output_dir = Path(args.output_dir)
    timing_text = read_text(report_dir / f"{args.design}.timing.rpt")
    worst_timing_text = read_text(report_dir / f"{args.design}.timing.setup.worst.rpt")
    qor_text = read_text(report_dir / f"{args.design}.qor.rpt")
    sdc_text = read_text(output_dir / f"{args.design}.sdc")

    if args.require_proportional_constraints:
        transition = find_number(
            r"set_clock_transition(?:\s+-\S+)*\s+([0-9.]+)\s+\[get_clocks clk\]",
            sdc_text,
            "set_clock_transition",
        )
        uncertainty = find_number(
            r"set_clock_uncertainty(?:\s+-\S+)*\s+([0-9.]+)\s+\[get_clocks clk\]",
            sdc_text,
            "set_clock_uncertainty",
        )
        input_delay = find_number(
            r"set_input_delay\s+-clock clk\s+([0-9.]+)\s+",
            sdc_text,
            "set_input_delay",
        )
        output_delay = find_number(
            r"set_output_delay\s+-clock clk\s+([0-9.]+)\s+",
            sdc_text,
            "set_output_delay",
        )
        expect_close("clock transition", transition, args.period * 0.05)
        expect_close("clock uncertainty", uncertainty, args.period * 0.10)
        expect_close("input delay", input_delay, args.period * 0.10)
        expect_close("output delay", output_delay, args.period * 0.10)

    if args.require_setup_path:
        path = first_setup_path(worst_timing_text)
        required_tokens = [
            "Endpoint:",
            "Path Type: max",
            "data arrival time",
            "data required time",
            "slack",
        ]
        missing = [token for token in required_tokens if token not in path]
        if missing:
            raise SystemExit(f"first setup path is missing: {', '.join(missing)}")

    if args.reject_mdu_final_path:
        path = first_setup_path(worst_timing_text)
        bad_endpoint = re.search(r"Endpoint:\s+u_mul_div/res_reg", path)
        bad_long_add = "u_mul_div/add_70" in path and "u_mul_div/add_71" in path
        if bad_endpoint or bad_long_add:
            raise SystemExit("first setup path is still the MDU final multiply add/sign-correction path")

    if args.max_critical_path is not None:
        crit = find_number(r"Critical Path Length:\s+([0-9.]+)", qor_text, "Critical Path Length")
        if crit > args.max_critical_path:
            raise SystemExit(f"critical path too long: expected <= {args.max_critical_path:.3f} ns, found {crit:.3f} ns")

    print("timing artifact checks passed")


if __name__ == "__main__":
    main()
