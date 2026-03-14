#!/usr/bin/env python3
"""Plot synthesis sweep results from reports/summary.csv.

Usage:
  python3 plot_results.py           # single design plots (backward-compat)
  python3 plot_results.py --both    # side-by-side comparison plots
  python3 plot_results.py --all     # comparison plots for all three designs
"""

import csv
import os
import sys

try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.patches import Patch
except ImportError:
    print("matplotlib not installed. Install with: pip install matplotlib")
    sys.exit(1)

CSV_PATH = "reports/summary.csv"
FIG_DIR  = "../docs/figures"

DESIGN_STYLES = {
    "single_cycle": {"color": "royalblue",  "marker": "o", "label": "Single-cycle"},
    "pipeline":     {"color": "darkorange", "marker": "s", "label": "Pipeline"},
    "pipeline_bp":  {"color": "seagreen",   "marker": "^", "label": "Pipeline+BP"},
}


def load_csv(path):
    with open(path) as f:
        return list(csv.DictReader(f))


def split_by_design(rows):
    """Return dict {design: [rows]}."""
    designs = {}
    for r in rows:
        d = r.get("design", "single_cycle")
        designs.setdefault(d, []).append(r)
    return designs


def extract(rows, key):
    return [float(r[key]) for r in rows if r[key] != ""]


def main():
    both = "--both" in sys.argv or "--all" in sys.argv

    if not os.path.exists(CSV_PATH):
        print(f"Error: {CSV_PATH} not found. Run 'make sweep' first.")
        sys.exit(1)

    os.makedirs(FIG_DIR, exist_ok=True)
    rows = load_csv(CSV_PATH)
    by_design = split_by_design(rows)

    if both and len(by_design) < 2:
        print("Warning: --both requested but only one design found in summary.csv")

    # -----------------------------------------------------------------------
    # 1. Area vs Frequency
    # -----------------------------------------------------------------------
    fig, ax1 = plt.subplots(figsize=(7, 4))
    ax2 = ax1.twinx()
    for design, drows in by_design.items():
        style = DESIGN_STYLES.get(design, {"color": "gray", "marker": "o", "label": design})
        freqs = extract(drows, "freq_mhz")
        areas = extract(drows, "area_um2")
        gtes  = extract(drows, "area_gte")
        ax1.plot(freqs, areas, color=style["color"], marker=style["marker"],
                 linestyle="-",  label=f"{style['label']} (µm²)")
        ax2.plot(freqs, gtes,  color=style["color"], marker=style["marker"],
                 linestyle="--", alpha=0.55, label=f"{style['label']} (GTE)")
    ax1.set_xlabel("Target Frequency (MHz)")
    ax1.set_ylabel("Area (µm²)")
    ax2.set_ylabel("Gate Equivalents (GTE)")
    ax1.set_title("Area vs Target Frequency — NauV RV32I @ NanGate45")
    ax1.grid(True, alpha=0.3)
    lines1, labels1 = ax1.get_legend_handles_labels()
    lines2, labels2 = ax2.get_legend_handles_labels()
    ax1.legend(lines1 + lines2, labels1 + labels2, loc="upper left", fontsize=8)
    fig.tight_layout()
    out = f"{FIG_DIR}/area_vs_freq.png"
    fig.savefig(out, dpi=150)
    plt.close(fig)
    print(f"  Saved {out}")

    # -----------------------------------------------------------------------
    # 2. Power vs Frequency
    # -----------------------------------------------------------------------
    fig, ax = plt.subplots(figsize=(7, 4))
    for design, drows in by_design.items():
        style = DESIGN_STYLES.get(design, {"color": "gray", "marker": "o", "label": design})
        freqs  = extract(drows, "freq_mhz")
        powers = extract(drows, "power_mw")
        met    = [r["slack_met"] == "True" for r in drows if r.get("power_mw", "") != ""]
        colors = ["green" if m else "red" for m in met]
        ax.plot(freqs, powers, color=style["color"], linewidth=1, linestyle="-",
                label=style["label"], zorder=1)
        ax.scatter(freqs, powers, c=colors, zorder=2, s=60)
    ax.set_xlabel("Target Frequency (MHz)")
    ax.set_ylabel("Total Power (mW)")
    ax.set_title("Power vs Target Frequency — NauV RV32I @ NanGate45")
    ax.grid(True, alpha=0.3)
    legend_handles = [Patch(color="green", label="Timing met"),
                      Patch(color="red",   label="Timing violated")]
    for design, drows in by_design.items():
        style = DESIGN_STYLES.get(design, {"color": "gray", "marker": "o", "label": design})
        from matplotlib.lines import Line2D
        legend_handles.append(Line2D([0], [0], color=style["color"], label=style["label"]))
    ax.legend(handles=legend_handles, fontsize=8)
    fig.tight_layout()
    out = f"{FIG_DIR}/power_vs_freq.png"
    fig.savefig(out, dpi=150)
    plt.close(fig)
    print(f"  Saved {out}")

    # -----------------------------------------------------------------------
    # 3. Slack (WNS) vs Frequency — grouped bars when both designs present
    # -----------------------------------------------------------------------
    fig, ax = plt.subplots(figsize=(7, 4))
    import numpy as np
    design_list = list(by_design.items())
    n_designs = len(design_list)
    bar_width = 16 / n_designs

    for i, (design, drows) in enumerate(design_list):
        style = DESIGN_STYLES.get(design, {"color": "gray", "marker": "o", "label": design})
        freqs    = [float(r["freq_mhz"]) for r in drows if r.get("wns_ns", "") != ""]
        wns_vals = [float(r["wns_ns"])   for r in drows if r.get("wns_ns", "") != ""]
        met      = [r["slack_met"] == "True" for r in drows if r.get("wns_ns", "") != ""]
        bar_colors = ["green" if m else "red" for m in met]
        offsets = [f + (i - (n_designs - 1) / 2) * bar_width for f in freqs]
        bars = ax.bar(offsets, wns_vals, color=bar_colors, width=bar_width * 0.9,
                      alpha=0.8, zorder=2, label=style["label"],
                      edgecolor=style["color"], linewidth=1.2)

        # Annotate Fmax
        fmax_pts = [(f, w) for f, w, m in zip(freqs, wns_vals, met) if m]
        if fmax_pts:
            fmax_f, fmax_w = max(fmax_pts, key=lambda x: x[0])
            ax.annotate(
                f"Fmax≥{int(fmax_f)} ({style['label']})",
                xy=(fmax_f + (i - (n_designs - 1) / 2) * bar_width, fmax_w),
                xytext=(fmax_f - 70 + i * 40, max(wns_vals) * (0.5 - i * 0.2)),
                arrowprops=dict(arrowstyle="->", color=style["color"]),
                color=style["color"], fontsize=8,
            )

    ax.axhline(0, color="black", linewidth=1.2, linestyle="--", zorder=3)
    ax.set_xlabel("Target Frequency (MHz)")
    ax.set_ylabel("WNS (ns)")
    ax.set_title("Slack vs Target Frequency — NauV RV32I @ NanGate45")
    ax.grid(True, alpha=0.3, axis="y", zorder=1)
    legend_handles = [Patch(color="green", label="Timing met"),
                      Patch(color="red",   label="Timing violated")]
    for design, _ in design_list:
        style = DESIGN_STYLES.get(design, {"color": "gray", "label": design})
        from matplotlib.lines import Line2D
        legend_handles.append(Line2D([0], [0], color=style["color"],
                                     linewidth=4, alpha=0.7, label=style["label"]))
    ax.legend(handles=legend_handles, fontsize=8)
    fig.tight_layout()
    out = f"{FIG_DIR}/slack_vs_freq.png"
    fig.savefig(out, dpi=150)
    plt.close(fig)
    print(f"  Saved {out}")

    print(f"\nAll plots saved to {FIG_DIR}/")


if __name__ == "__main__":
    main()
