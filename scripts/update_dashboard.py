#!/usr/bin/env python3
"""
Update the test-status dashboard table in README.md.

Usage:
    update_dashboard.py <readme_path>
        --unit-status   pass|fail
        --unit-tb       <passed>/<total>          e.g. 5/5
        --unit-checks   <passed>/<total>          e.g. 155/155
        --riscv-status  pass|fail|unavailable
        --riscv-counts  <passed>/<total>/<skipped> e.g. 40/40/2
        --timestamp     "<YYYY-MM-DD HH:MM UTC>"
"""

import argparse
import re
import sys

MARKER_START = "<!-- DASHBOARD_START -->"
MARKER_END   = "<!-- DASHBOARD_END -->"


def badge(status: str) -> str:
    return {
        "pass": "$\\color{green}{\\textsf{PASS}}$",
        "fail": "$\\color{red}{\\textsf{FAIL}}$",
    }.get(status, "N/A")


def build_table(args) -> str:
    unit_b   = badge(args.unit_status)
    unit_det = f"{args.unit_checks} checks · {args.unit_tb} testbenches"

    if args.riscv_status == "unavailable":
        riscv_b   = "not configured"
        p, t, s   = "—", "—", "—"
        riscv_det = "clone riscv-tests/ to enable"
    else:
        riscv_b = badge(args.riscv_status)
        p, t, s = args.riscv_counts.split("/")
        riscv_det = f"{p}/{t} passed · {s} skipped"

    ts = args.timestamp

    return (
        "| Suite | Status | Details | Last run |\n"
        "|-------|--------|---------|----------|\n"
        f"| Unit tests (Verilator) | {unit_b} | {unit_det} | {ts} |\n"
        f"| riscv-tests RV32UI | {riscv_b} | {riscv_det} | {ts} |"
    )


def update_readme(readme_path: str, table: str) -> bool:
    with open(readme_path) as f:
        content = f.read()

    pattern = re.compile(
        re.escape(MARKER_START) + r".*?" + re.escape(MARKER_END),
        re.DOTALL,
    )
    if not pattern.search(content):
        print(f"WARNING: dashboard markers not found in {readme_path}", file=sys.stderr)
        return False

    replacement = f"{MARKER_START}\n{table}\n{MARKER_END}"
    new_content = pattern.sub(lambda _: replacement, content)
    with open(readme_path, "w") as f:
        f.write(new_content)
    return True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("readme")
    parser.add_argument("--unit-status",   required=True)
    parser.add_argument("--unit-tb",       required=True)
    parser.add_argument("--unit-checks",   required=True)
    parser.add_argument("--riscv-status",  required=True)
    parser.add_argument("--riscv-counts",  required=True)  # pass/total/skip
    parser.add_argument("--timestamp",     required=True)
    args = parser.parse_args()

    table = build_table(args)
    if update_readme(args.readme, table):
        print(f"Dashboard updated ({args.unit_status} / {args.riscv_status})")
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
