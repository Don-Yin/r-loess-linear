"""One plot kind for the 15 tied inputs of exp_004 to exp_006: a row per input, the build as a multiple of R."""
from __future__ import annotations

import json

from matplotlib.legend_handler import HandlerTuple
from matplotlib.lines import Line2D
from matplotlib.offsetbox import OffsetImage
from matplotlib.ticker import FuncFormatter, MaxNLocator
from python_plotting_convention import (  # pyright: ignore[reportMissingImports]
    publication_subplots,
    tag_artist,
)
from result_data import (
    R_LOGO,
    R_ON_TIED,
    ROOT,
    _LogoHandler,
    _marker_styles,
    quiet_axes,
    read_csv,
    source_record,
)

R_BLUE = "#276dc3"
TIME = {"heading": "time", "xlabel": "time (R = 1)", "r": "seconds"}
MEMORY = {"heading": "memory", "xlabel": "memory requested (R = 1)", "r": "bytes"}


def tied_cases_figure(table, build, panels, *, target_width_cm):
    """Draw every row of `table` (one tied input each) in two panels that share the rows.

    build: (label, experiment number, colour). panels: per panel TIME or MEMORY with `column` (the build's table
    column, divided by R's measurement in r-tied.json) and optionally `below` (leave out larger values: an
    enlarged view). R is the line at 1.
    """
    columns = sorted({panel["column"] for panel in panels})
    rows = read_csv(table, numeric_columns=columns)
    names = [row["id"] for row in rows]
    r = json.loads((ROOT / R_ON_TIED).read_text(encoding="utf-8"))
    if not all(r[name]["identical"] for name in names):
        raise ValueError(f"{R_ON_TIED}: R's result differs from the package source's on a tied input")
    label, digit, colour = build
    entry = {"kind": "build", "digit": str(digit), "color": colour, "filled": True}
    fig, axes = publication_subplots(1, 2, target_width_cm=target_width_cm, height_cm=10.6, sharey=True)
    plotted = []
    for ax, panel, left in zip(axes, panels, (0.27, 0.63), strict=True):
        ax.set_position([left, 0.105, 0.325, 0.775])
        quiet_axes(ax)
        ax.grid(axis="y", color="#d9dfe4", linestyle=":", linewidth=0.6)
        tag_artist(ax, semantic_role="body")
        ax.tick_params(axis="y", length=0)
        below = panel.get("below")
        values = [row[panel["column"]] / r[row["id"]][panel["r"]] for row in rows]
        top = below if below else max(max(values), 1.0) * 1.1
        ax.set_xlim(-0.06 * top, top)
        ax.axvline(1, color=R_BLUE, linewidth=1.2, zorder=1)
        if below:
            ax.set_facecolor("#eef1f4")
        for place, value in enumerate(values):
            if below and value > below:
                continue
            for style in _marker_styles(entry, 0.8):
                ax.plot(value, place, linestyle="none", zorder=3, **style)
        ax.xaxis.set_major_locator(MaxNLocator(4, min_n_ticks=3))
        ax.xaxis.set_major_formatter(FuncFormatter(lambda value, _: "0" if value == 0 else f"{value:g}×"))
        ax.set_xlabel(panel["xlabel"], fontsize=9)
        text = panel["heading"] + (f", below {below:g}× enlarged" if below else "")
        heading = ax.text(0, 1.015, text, transform=ax.transAxes, fontsize=9, fontweight="bold", ha="left", va="bottom")
        tag_artist(heading, semantic_role="column_heading")
        plotted.append({"heading": text, "column": panel["column"], "r": panel["r"], "x_max": top,
                        "values": dict(zip(names, values, strict=True))})

    # the inputs' names, left-aligned in one column beside the left panel

    first = axes[0]
    first.set_ylim(len(rows) - 0.4, -0.6)
    first.set_yticks(range(len(rows)), names)
    fig.canvas.draw()
    widest = max(tick.get_window_extent().width for tick in first.get_yticklabels()) * 72 / fig.dpi
    first.tick_params(axis="y", pad=widest + 5)
    for tick in first.get_yticklabels():
        tick.set_horizontalalignment("left")

    handles: list = [OffsetImage(R_LOGO),
                     tuple(Line2D([], [], linestyle="none", **style) for style in _marker_styles(entry, 0.8))]
    fig.legend(handles, ["R (unpatched), the blue line at 1", label],
               handler_map={tuple: HandlerTuple(ndivide=1), OffsetImage: _LogoHandler()}, loc="upper center",
               bbox_to_anchor=(0.5, 0.995), ncol=2, fontsize=9, handlelength=1.2, handletextpad=0.4,
               columnspacing=1.4, borderaxespad=0, frameon=False)
    return fig, {"plot_kind": "the tied inputs as rows, the build as a multiple of R, linear axes",
                 "target_width_cm": target_width_cm,
                 "sources": [source_record(table, ["id", *columns]), source_record(R_ON_TIED, names)],
                 "panels": plotted}
