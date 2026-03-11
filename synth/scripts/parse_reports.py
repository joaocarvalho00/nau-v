#!/usr/bin/env python3
"""Parse synthesis and STA reports for each sweep frequency → reports/summary.csv."""

import re
import csv
import os

FREQS = [50, 100, 150, 200, 250]
NAND2_AREA_UM2 = 0.798  # NAND2_X1 area in NanGate45


def parse_area(path):
    """Return (area_um2, gte) from area.rpt."""
    with open(path) as f:
        text = f.read()
    m = re.search(r"Chip area for module.*?:\s+([\d.]+)", text)
    if not m:
        return None, None
    area = float(m.group(1))
    gte = area / NAND2_AREA_UM2
    return area, gte


def parse_timing(path):
    """Return (period_ns, wns_ns, crit_path_ns, fmax_est_mhz) from timing.rpt."""
    with open(path) as f:
        text = f.read()

    def get(key):
        m = re.search(rf"^{key}\s+([-\d.e+]+)", text, re.MULTILINE)
        return float(m.group(1)) if m else None

    return get("PERIOD_NS"), get("WNS_NS"), get("CRIT_PATH_NS"), get("FMAX_MHZ")


def parse_power(path):
    """Return total power in mW from power.rpt."""
    with open(path) as f:
        text = f.read()
    # Match: "Total  X.XXe-XX  X.XXe-XX  X.XXe-XX  X.XXe-XX  100.0%"
    m = re.search(
        r"^Total\s+\S+\s+\S+\s+\S+\s+([\d.e+\-]+)\s+\d+\.\d+%",
        text, re.MULTILINE
    )
    if not m:
        return None
    return float(m.group(1)) * 1000.0  # W → mW


def main():
    rows = []
    fmax_achieved = None

    print(f"\n{'Freq':>6}  {'Area µm²':>10}  {'GTE':>7}  {'WNS ns':>8}  {'Fmax MHz':>9}  {'Power mW':>9}  Status")
    print("-" * 65)

    for freq in FREQS:
        d = f"reports/{freq}MHz"
        files = [f"{d}/area.rpt", f"{d}/timing.rpt", f"{d}/power.rpt"]

        if not all(os.path.exists(f) for f in files):
            print(f"{freq:>5} MHz  (reports missing — skipped)")
            continue

        area_um2, gte       = parse_area(f"{d}/area.rpt")
        period_ns, wns_ns, crit_ns, fmax_mhz = parse_timing(f"{d}/timing.rpt")
        power_mw            = parse_power(f"{d}/power.rpt")

        slack_met = wns_ns is not None and wns_ns >= 0.0
        if slack_met:
            fmax_achieved = freq

        status = "PASS" if slack_met else "FAIL"
        print(
            f"{freq:>5} MHz  "
            f"{area_um2:>10.1f}  "
            f"{gte:>7.0f}  "
            f"{wns_ns:>+8.3f}  "
            f"{fmax_mhz:>9.1f}  "
            f"{power_mw:>9.3f}  "
            f"{status}"
        )

        rows.append({
            "freq_mhz":      freq,
            "period_ns":     period_ns,
            "area_um2":      round(area_um2, 2) if area_um2  is not None else "",
            "area_gte":      round(gte, 0)      if gte       is not None else "",
            "wns_ns":        round(wns_ns, 3)   if wns_ns    is not None else "",
            "crit_path_ns":  round(crit_ns, 3)  if crit_ns   is not None else "",
            "fmax_est_mhz":  round(fmax_mhz, 1) if fmax_mhz  is not None else "",
            "slack_met":     slack_met,
            "power_mw":      round(power_mw, 3) if power_mw  is not None else "",
        })

    if not rows:
        print("No reports found. Run 'make sweep' first.")
        return

    csv_path = "reports/summary.csv"
    with open(csv_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    print(f"\nSummary → {csv_path}")
    if fmax_achieved:
        print(f"Fmax (sweep): {fmax_achieved} MHz  (highest frequency with slack ≥ 0)")
    else:
        print("Fmax: timing failed at all tested frequencies")


if __name__ == "__main__":
    main()
