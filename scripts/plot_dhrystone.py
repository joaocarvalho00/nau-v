#!/usr/bin/env python3
"""
plot_dhrystone.py — Plot NauV Dhrystone benchmark results.

Reads reports/dhrystone.csv and reports/dhrystone_pipeline.csv and produces:
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

REPO_ROOT   = pathlib.Path(__file__).resolve().parent.parent
FIG_DIR     = REPO_ROOT / "docs" / "figures"

DESIGNS = [
    {
        "csv":    REPO_ROOT / "reports" / "dhrystone.csv",
        "label":  "Single-cycle",
        "color":  "#2196F3",
        "marker": "o",
    },
    {
        "csv":    REPO_ROOT / "reports" / "dhrystone_pipeline.csv",
        "label":  "Pipeline",
        "color":  "#FF9800",
        "marker": "s",
    },
]

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
        "figure.dpi":        120,
        "axes.spines.top":   False,
        "axes.spines.right": False,
        "axes.grid":         True,
        "grid.alpha":        0.4,
        "font.size":         11,
    })


def plot_dmips(datasets):
    fig, ax = plt.subplots(figsize=(7, 4))

    for d, (runs, _, _, dmips) in datasets:
        ax.plot(runs, dmips, marker=d["marker"], linewidth=2, color=d["color"],
                markersize=7, label=d["label"])
        # Annotate steady-state value at largest run count
        ax.annotate(f"{dmips[-1]:.2f} DMIPS/MHz",
                    xy=(runs[-1], dmips[-1]),
                    xytext=(-90, 10 if d["marker"] == "o" else -20),
                    textcoords="offset points",
                    fontsize=9, color=d["color"],
                    arrowprops=dict(arrowstyle="->", color=d["color"], lw=1.2))

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


def plot_cpr(datasets):
    fig, ax = plt.subplots(figsize=(7, 4))

    for d, (runs, _, cpr, _) in datasets:
        ax.plot(runs, cpr, marker=d["marker"], linewidth=2, color=d["color"],
                markersize=7, label=d["label"])
        ax.annotate(f"{cpr[-1]:.0f} cyc/run",
                    xy=(runs[-1], cpr[-1]),
                    xytext=(-80, 15 if d["marker"] == "o" else -25),
                    textcoords="offset points",
                    fontsize=9, color=d["color"],
                    arrowprops=dict(arrowstyle="->", color=d["color"], lw=1.2))

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
    style()

    datasets = []
    for d in DESIGNS:
        if not d["csv"].exists():
            print(f"Warning: {d['csv']} not found — skipping {d['label']}")
            continue
        data = load_csv(d["csv"])
        datasets.append((d, data))
        print(f"Loaded {len(data[0])} data points from {d['csv']}")

    if not datasets:
        print("ERROR: no Dhrystone CSV files found.  Run sim/run_dhrystone.sh first.")
        sys.exit(1)

    plot_dmips(datasets)
    plot_cpr(datasets)
    print("Done.")


if __name__ == "__main__":
    main()
