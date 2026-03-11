#!/usr/bin/env python3
"""Plot synthesis sweep results from reports/summary.csv."""

import csv
import os
import sys

try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
except ImportError:
    print("matplotlib not installed. Install with: pip install matplotlib")
    sys.exit(1)

CSV_PATH = "reports/summary.csv"
FIG_DIR  = "../docs/figures"


def load_csv(path):
    with open(path) as f:
        return list(csv.DictReader(f))


def main():
    if not os.path.exists(CSV_PATH):
        print(f"Error: {CSV_PATH} not found. Run 'make sweep' first.")
        sys.exit(1)

    os.makedirs(FIG_DIR, exist_ok=True)
    rows = load_csv(CSV_PATH)

    freqs    = [float(r["freq_mhz"])    for r in rows]
    areas    = [float(r["area_um2"])    for r in rows]
    gtes     = [float(r["area_gte"])    for r in rows]
    powers   = [float(r["power_mw"])    for r in rows]
    wns_vals = [float(r["wns_ns"])      for r in rows]
    met      = [r["slack_met"] == "True" for r in rows]

    # -----------------------------------------------------------------------
    # 1. Area vs Frequency
    # -----------------------------------------------------------------------
    fig, ax1 = plt.subplots(figsize=(7, 4))
    ax2 = ax1.twinx()
    ax1.plot(freqs, areas, "b-o", label="Area (µm²)")
    ax2.plot(freqs, gtes,  "b--s", alpha=0.55, label="Area (GTE)")
    ax1.set_xlabel("Target Frequency (MHz)")
    ax1.set_ylabel("Area (µm²)", color="blue")
    ax2.set_ylabel("Gate Equivalents (GTE)", color="blue")
    ax1.set_title("Area vs Target Frequency — NauV RV32I @ NanGate45")
    ax1.grid(True, alpha=0.3)
    # Combined legend
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
    colors = ["green" if m else "red" for m in met]
    ax.plot(freqs, powers, "k-", linewidth=1, zorder=1)
    ax.scatter(freqs, powers, c=colors, zorder=2, s=60)
    ax.set_xlabel("Target Frequency (MHz)")
    ax.set_ylabel("Total Power (mW)")
    ax.set_title("Power vs Target Frequency — NauV RV32I @ NanGate45")
    ax.grid(True, alpha=0.3)
    # Legend patches
    from matplotlib.patches import Patch
    ax.legend(handles=[Patch(color="green", label="Timing met"),
                        Patch(color="red",   label="Timing violated")],
              fontsize=8)
    fig.tight_layout()
    out = f"{FIG_DIR}/power_vs_freq.png"
    fig.savefig(out, dpi=150)
    plt.close(fig)
    print(f"  Saved {out}")

    # -----------------------------------------------------------------------
    # 3. Slack (WNS) vs Frequency
    # -----------------------------------------------------------------------
    fig, ax = plt.subplots(figsize=(7, 4))
    bar_colors = ["green" if m else "red" for m in met]
    ax.bar(freqs, wns_vals, color=bar_colors, width=18, alpha=0.8, zorder=2)
    ax.axhline(0, color="black", linewidth=1.2, linestyle="--", zorder=3)
    ax.set_xlabel("Target Frequency (MHz)")
    ax.set_ylabel("WNS (ns)")
    ax.set_title("Slack vs Target Frequency — NauV RV32I @ NanGate45")
    ax.grid(True, alpha=0.3, axis="y", zorder=1)
    # Annotate Fmax
    fmax_freqs = [f for f, m in zip(freqs, met) if m]
    if fmax_freqs:
        fmax = max(fmax_freqs)
        fmax_wns = wns_vals[freqs.index(fmax)]
        ax.annotate(
            f"Fmax ≥ {int(fmax)} MHz",
            xy=(fmax, fmax_wns),
            xytext=(fmax - 60, max(wns_vals) * 0.6),
            arrowprops=dict(arrowstyle="->", color="darkgreen"),
            color="darkgreen", fontsize=9,
        )
    from matplotlib.patches import Patch
    ax.legend(handles=[Patch(color="green", label="Timing met"),
                        Patch(color="red",   label="Timing violated")],
              fontsize=8)
    fig.tight_layout()
    out = f"{FIG_DIR}/slack_vs_freq.png"
    fig.savefig(out, dpi=150)
    plt.close(fig)
    print(f"  Saved {out}")

    print(f"\nAll plots saved to {FIG_DIR}/")


if __name__ == "__main__":
    main()
