"""Memory the prototype requests against R's workspace, over N (exp_002 README)."""
from __future__ import annotations

import re

from matplotlib.lines import Line2D
from matplotlib.ticker import FuncFormatter, MaxNLocator
from python_plotting_convention import (  # pyright: ignore[reportMissingImports]
    SINGLE_COLUMN_CM,
    publication_subplots,
    tag_artist,
)
from result_data import (
    BEFORE_RED,
    DEFAULT_BLUE,
    ROOT,
    quiet_axes,
    read_csv,
    source_record,
)

MEMORY = "experiments/exp_002_baseline_prototype/.results/tables/memory.csv"
GB, MB = 1e9, 1e6


def build_figure(*, target_width_cm: float = SINGLE_COLUMN_CM):
    memory = read_csv(MEMORY, numeric_columns=("n", "r_workspace_bytes", "native_bytes"))
    running = [row for row in memory if row["r_runs"] == "TRUE"]
    stopped = [row for row in memory if row["r_runs"] == "FALSE"]
    first_stop, largest = stopped[0], memory[-1]
    stop_label = f"{round(first_stop['n'], -2):,.0f}"
    documented = re.search(r"N stops near ([\d,]+)", (ROOT / "docs/000-context.md").read_text(encoding="utf-8"))
    if documented is None or stop_label != documented.group(1):
        raise ValueError("measured R workspace limit disagrees with docs/000-context.md")

    fig, ax = publication_subplots(target_width_cm=target_width_cm, height_cm=7.5)
    ax.set_position([0.17, 0.17, 0.78, 0.56])
    quiet_axes(ax)
    tag_artist(ax, semantic_role="body")
    ax.plot([row["n"] for row in running], [row["r_workspace_bytes"] / GB for row in running],
            color=BEFORE_RED, marker="s", markersize=3.2, linewidth=1.2)
    ax.plot([row["n"] for row in running[-1:] + stopped],
            [row["r_workspace_bytes"] / GB for row in running[-1:] + stopped],
            color=BEFORE_RED, linestyle="--", linewidth=1.2, marker="s", markersize=3.2, markerfacecolor="white")
    ax.plot([row["n"] for row in memory], [row["native_bytes"] / GB for row in memory],
            color=DEFAULT_BLUE, marker="o", markersize=3.2, linewidth=1.2)
    x_max, y_max = largest["n"] * 1.12, largest["r_workspace_bytes"] / GB * 1.08
    ax.set_xlim(-0.03 * x_max, x_max)
    ax.set_ylim(-0.05 * y_max, y_max)
    ax.xaxis.set_major_locator(MaxNLocator(4))
    ax.xaxis.set_major_formatter(FuncFormatter(lambda value, _: f"{value:,.0f}"))
    ax.yaxis.set_major_locator(MaxNLocator(5))
    ax.grid(axis="y", color="#d9dfe4", linestyle=":", linewidth=0.6)
    ax.set_xlabel("observations (N)", fontsize=9)
    ax.set_ylabel("memory requested (GB)", fontsize=9)
    fig.legend(
        handles=[
            Line2D([], [], color=BEFORE_RED, marker="s", markersize=3.2, linewidth=1.2,
                   label="R's workspace while R runs"),
            Line2D([], [], color=BEFORE_RED, marker="s", markersize=3.2, linewidth=1.2, linestyle="--",
                   markerfacecolor="white", label=f"past N ≈ {stop_label}, where R stops"),
            Line2D([], [], color=DEFAULT_BLUE, marker="o", markersize=3.2, linewidth=1.2,
                   label=f"prototype, {largest['native_bytes'] / MB:.0f} MB at N = {largest['n']:,.0f}"),
        ],
        loc="upper center", bbox_to_anchor=(0.5, 0.995), ncol=1, fontsize=9,
        handlelength=2.2, handletextpad=0.4, labelspacing=0.25, borderaxespad=0, frameon=False,
    )
    return fig, {
        "scientific_job": "memory the prototype requests against R's requested workspace over N",
        "target_width_cm": target_width_cm,
        "sources": [
            source_record(MEMORY, ["n", "r_runs", "r_workspace_bytes", "native_bytes"]),
            source_record("shared/harness/memory.R", ["reference_bytes", "reference_first_invalid_n"]),
            source_record("experiments/exp_002_baseline_prototype/src/modules/memory-sweep.R", ["setup"]),
            source_record("docs/000-context.md", ["workspace-limit sentence"]),
        ],
        "plotted_memory": memory,
        "workspace_limit": {"first_invalid_n": first_stop["n"], "label": stop_label},
        "memory_encoding": "linear axes in GB; R requested workspace solid while R runs and dashed beyond",
    }
