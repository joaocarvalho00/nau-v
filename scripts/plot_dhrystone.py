#!/usr/bin/env python3
"""
plot_dhrystone.py — Plot NauV Dhrystone benchmark results.

Reads reports/dhrystone.csv and produces two figures:
  docs/figures/dhrystone_dmips.png   — DMIPS/MHz vs iteration count
  docs/figures/dhrystone_cpr.png     — Cycles per Dhrystone run vs iteration count

Usage:
    python3 scripts/plot_dhrystone.py
"""

import csv
import pathlib
import sys

try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import matplotlib.ticker as ticker
except ImportError:
    print("ERROR: matplotlib not installed.  Run: pip install matplotlib")
    sys.exit(1)

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
CSV_PATH  = REPO_ROOT / "reports" / "dhrystone.csv"
FIG_DIR   = REPO_ROOT / "docs" / "figures"

FIG_DIR.mkdir(parents=True, exist_ok=True)


def load_csv(path):
    runs, cycles, cpr, dmips = [], [], [], []
    with open(path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            runs.append(int(row["runs"]))
            cycles.append(int(row["cycles"]))
            cpr.append(float(row["cycles_per_run"]))
            dmips.append(float(row["dmips_mhz"]))
    return runs, cycles, cpr, dmips


def style():
    plt.rcParams.update({
        "figure.dpi":       120,
        "axes.spines.top":  False,
        "axes.spines.right":False,
        "axes.grid":        True,
        "grid.alpha":       0.4,
        "font.size":        11,
    })


def plot_dmips(runs, dmips):
    fig, ax = plt.subplots(figsize=(7, 4))
    ax.plot(runs, dmips, marker="o", linewidth=2, color="#2196F3",
            markersize=7, label="NauV (single-cycle RV32I)")

    # Annotate the steady-state value (largest run count)
    ax.annotate(f"{dmips[-1]:.2f} DMIPS/MHz",
                xy=(runs[-1], dmips[-1]),
                xytext=(-90, 10), textcoords="offset points",
                fontsize=10, color="#1565C0",
                arrowprops=dict(arrowstyle="->", color="#1565C0", lw=1.2))

    ax.set_xlabel("Number of Dhrystone iterations")
    ax.set_ylabel("DMIPS/MHz")
    ax.set_title("NauV — Dhrystone Performance")
    ax.xaxis.set_major_formatter(ticker.FuncFormatter(lambda x, _: f"{int(x):,}"))
    ax.set_ylim(bottom=0)
    ax.legend(loc="lower right", fontsize=9)
    fig.tight_layout()

    out = FIG_DIR / "dhrystone_dmips.png"
    fig.savefig(out)
    plt.close(fig)
    print(f"  Saved: {out}")


def plot_cpr(runs, cpr):
    fig, ax = plt.subplots(figsize=(7, 4))
    ax.plot(runs, cpr, marker="s", linewidth=2, color="#4CAF50",
            markersize=7, label="cycles / run")

    # Annotate steady state
    ax.annotate(f"{cpr[-1]:.0f} cyc/run",
                xy=(runs[-1], cpr[-1]),
                xytext=(-80, 15), textcoords="offset points",
                fontsize=10, color="#2E7D32",
                arrowprops=dict(arrowstyle="->", color="#2E7D32", lw=1.2))

    ax.set_xlabel("Number of Dhrystone iterations")
    ax.set_ylabel("Cycles per Dhrystone run")
    ax.set_title("NauV — Dhrystone Cycles per Run\n(includes one-time startup overhead at low counts)")
    ax.xaxis.set_major_formatter(ticker.FuncFormatter(lambda x, _: f"{int(x):,}"))
    ax.set_ylim(bottom=0)
    ax.legend(loc="upper right", fontsize=9)
    fig.tight_layout()

    out = FIG_DIR / "dhrystone_cpr.png"
    fig.savefig(out)
    plt.close(fig)
    print(f"  Saved: {out}")


def main():
    if not CSV_PATH.exists():
        print(f"ERROR: {CSV_PATH} not found.  Run sim/run_dhrystone.sh first.")
        sys.exit(1)

    style()
    runs, cycles, cpr, dmips = load_csv(CSV_PATH)

    print(f"Loaded {len(runs)} data points from {CSV_PATH}")
    plot_dmips(runs, dmips)
    plot_cpr(runs, cpr)
    print("Done.")


if __name__ == "__main__":
    main()
