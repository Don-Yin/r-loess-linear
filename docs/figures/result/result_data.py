"""Read measured inputs and retain their provenance for README result figures."""
from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path
from typing import Any, cast

import numpy as np
from matplotlib.image import BboxImage, imread
from matplotlib.legend_handler import HandlerBase, HandlerTuple
from matplotlib.lines import Line2D
from matplotlib.offsetbox import AnnotationBbox, OffsetImage
from matplotlib.patches import Rectangle
from matplotlib.ticker import FuncFormatter, MaxNLocator
from matplotlib.transforms import Bbox, TransformedBbox
from python_plotting_convention import (  # pyright: ignore[reportMissingImports]
    place_labels,
    publication_subplots,
    tag_artist,
)

ROOT = Path(__file__).resolve().parents[3]


def read_csv(relative_path, *, numeric_columns=(), integer_columns=()) -> list[dict[str, Any]]:
    with (ROOT / relative_path).open(newline="", encoding="utf-8") as stream:
        rows: list[dict[str, Any]] = list(csv.DictReader(stream))
    for row in rows:
        for columns, convert in ((numeric_columns, float), (integer_columns, int)):
            for column in columns:
                try:
                    row[column] = convert(row[column])
                except ValueError as error:
                    raise ValueError(f"invalid measured number in {relative_path}, column {column}") from error
    return rows


def source_record(relative_path, columns):
    return {
        "path": relative_path,
        "sha256": hashlib.sha256((ROOT / relative_path).read_bytes()).hexdigest(),
        "columns": columns,
    }


def quiet_axes(ax):
    ax.spines[["top", "right"]].set_visible(False)
    ax.tick_params(labelsize=9)
    ax.grid(axis="x", color="#d9dfe4", linestyle=":", linewidth=0.6)
    ax.set_axisbelow(True)


# One plot kind for every experiment's result: one input, memory requested
# across and time up, both on plain linear axes in readable units, with the
# unpatched implementation as its logo and each build as a numbered circle.
# The right panel enlarges the grey box.

DEFAULT_BLUE = "#4477aa"
BEFORE_RED = "#cc6677"
KEPT_GREEN = "#228833"
DROPPED_PURPLE = "#aa3377"

# R's logo, rendered from doc/html/Rlogo.svg of R 4.5.2 (The R Foundation, CC-BY-SA 4.0); drawn 13 pt tall.
# Original sources, licence links, transformations and Python-mark terms: docs/licences.md.

R_LOGO = imread(ROOT / "docs/assets/r-logo.png")
LOGO_PT = 13
MEMORY_NOTE = "memory: the native bytes each call requests; for R its C workspace"


# The case the figures for exp_002, exp_003, exp_005 and exp_006 use: one predictor, N = 45,000, M = 80.

HEADLINE = {"d": "1", "n": "45000", "m": "80"}
HEADLINE_TEXT = "one predictor, N = 45,000, M = 80"
PROTOTYPE_TIMING = "experiments/exp_002_baseline_prototype/.results/tables/timing.csv"
R_TIMING = "experiments/exp_002_baseline_prototype/.results/tables/r-timing.csv"


def headline_row(relative_path, numeric_columns):
    rows = [row for row in read_csv(relative_path) if all(row[k] == v for k, v in HEADLINE.items())]
    if len(rows) != 1:
        raise ValueError(f"{relative_path}: {len(rows)} rows for {HEADLINE_TEXT}")
    row = rows[0]
    for column in numeric_columns:
        try:
            row[column] = float(row[column])
        except ValueError as error:
            raise ValueError(f"invalid measured number in {relative_path}, column {column}") from error
    return row


# The normal builds of exp_005 and exp_006 have no allocation probe; exp_006 measures both sources built with it.

PROBED_TIMING = "experiments/exp_006_sparse_retention/.results/tables/timing-comparison.csv"
HEADLINE_CASE = "d1-n45000-m80-cell0.2"


def probed_headline_bytes(column):
    """Native bytes in the headline case: `before_native_bytes` (package source) or `after_native_bytes`."""
    found = [row for row in read_csv(PROBED_TIMING, numeric_columns=[column]) if row["case"] == HEADLINE_CASE]
    if len(found) != 1:
        raise ValueError(f"{PROBED_TIMING}: {len(found)} rows for {HEADLINE_CASE}")
    return found[0][column], source_record(PROBED_TIMING, ["case", column])


def logo_point(label, image, seconds, native_bytes):
    """One unpatched implementation, identified by its language's logo."""
    return {"label": label, "kind": "logo", "image": image, "bytes": native_bytes, "seconds": seconds}


def r_point(seconds, workspace_bytes):
    return logo_point("R (unpatched)", R_LOGO, seconds, workspace_bytes)


R_ON_TIED = "docs/figures/result/r-tied.json"


def r_on_tied(case):
    """Unpatched R on a tied input: its own native routine and the workspace it requests. The experiments do
    not run R there, so r-tied.R beside this file measures it; returns its point and its source record."""
    measured = json.loads((ROOT / R_ON_TIED).read_text(encoding="utf-8"))[case]
    if not measured["identical"]:
        raise ValueError(f"{R_ON_TIED}: R's result on {case} is not the package source's")
    return r_point(measured["seconds"], measured["bytes"]), source_record(R_ON_TIED, [case])


def build_point(label, digit, colour, seconds, native_bytes, *, filled=True, name=None):
    """One build: a circle with its experiment number; `name` adds a direct label in the zoom panel."""
    return {"label": label, "kind": "build", "digit": str(digit), "color": colour, "filled": filled,
            "bytes": native_bytes, "seconds": seconds, "name": name}


def _unit(maximum, units):
    for name, size in units:
        if maximum >= 2 * size:
            return name, size
    return units[-1]


BYTE_UNITS = (("GB", 1e9), ("MB", 1e6), ("kB", 1e3))
TIME_UNITS = (("s", 1.0), ("ms", 1e-3))


class _LogoHandler(HandlerBase):
    """Legend handle showing the supplied logo, centred in the handle box."""

    def create_artists(self, legend, orig_handle, xdescent, ydescent, width, height, fontsize, trans):
        logo = np.asarray(cast(OffsetImage, orig_handle).get_data())
        tall = 1.5 * height
        wide = tall * logo.shape[1] / logo.shape[0]
        box = Bbox.from_bounds(width / 2 - xdescent - wide / 2, height / 2 - ydescent - tall / 2, wide, tall)
        image = BboxImage(TransformedBbox(box, trans), interpolation="antialiased")
        image.set_data(logo)
        return [image]


def _marker_styles(entry, scale=1.0):
    """Line2D keyword sets drawn on top of each other for one build entry."""
    colour, filled = entry["color"], entry["filled"]
    return [{"marker": "o", "markersize": 11 * scale, "color": colour, "markeredgewidth": 1.1,
             "markerfacecolor": colour if filled else "white"},
            {"marker": f"$\\mathsf{{{entry['digit']}}}$", "markersize": 6 * scale, "markeredgewidth": 0,
             "color": "white" if filled else colour, "markerfacecolor": "white" if filled else colour}]


def _draw(ax, entries, links, x_size, y_size):
    for path in links:
        ax.plot([p["bytes"] / x_size for p in path], [p["seconds"] / y_size for p in path],
                color="#9aa4ae", linewidth=0.8, zorder=2)
    for entry in entries:
        at = (entry["bytes"] / x_size, entry["seconds"] / y_size)
        if entry["kind"] == "logo":
            logo = entry["image"]
            ax.add_artist(AnnotationBbox(OffsetImage(logo, zoom=LOGO_PT / logo.shape[0]), at,
                                         frameon=False, pad=0, zorder=3))
            continue
        for style in _marker_styles(entry):
            ax.plot(*at, linestyle="none", zorder=3, **style)


def _axes(ax, x_unit, y_unit, xmax, ymax):
    """Linear axes from just below 0, so points at 0 clear the spines; memory ticks carry their unit."""
    quiet_axes(ax)
    ax.grid(axis="y", color="#d9dfe4", linestyle=":", linewidth=0.6)
    tag_artist(ax, semantic_role="body")
    ax.set_xlim(-0.05 * xmax, xmax)
    ax.set_ylim(-0.06 * ymax, ymax)
    ax.xaxis.set_major_locator(MaxNLocator(4, min_n_ticks=3))
    ax.yaxis.set_major_locator(MaxNLocator(5, min_n_ticks=3))
    ax.xaxis.set_major_formatter(FuncFormatter(lambda value, _: "0" if value == 0 else f"{value:g} {x_unit}"))
    ax.yaxis.set_major_formatter(FuncFormatter(lambda value, _: f"{value:g}"))
    ax.set_ylabel(f"time ({y_unit})", fontsize=9)


def absolute_figure(entries, *, zoom, zoom_heading="near 0, enlarged", links=(), target_width_cm):
    """Draw one input's points on linear axes, with a second panel enlarging `zoom` = (max bytes, max seconds)."""
    fig, (main, near) = publication_subplots(1, 2, target_width_cm=target_width_cm, height_cm=7.4)
    main.set_position([0.11, 0.14, 0.37, 0.58])
    near.set_position([0.61, 0.14, 0.37, 0.58])
    limits = {"all": (max(p["bytes"] for p in entries) * 1.08, max(p["seconds"] for p in entries) * 1.1),
              "zoom": zoom}
    units = {key: (_unit(x, BYTE_UNITS), _unit(y, TIME_UNITS)) for key, (x, y) in limits.items()}
    panels = {}
    for key, ax in (("all", main), ("zoom", near)):
        (xmax, ymax), ((x_unit, x_size), (y_unit, y_size)) = limits[key], units[key]
        _axes(ax, x_unit, y_unit, xmax / x_size, ymax / y_size)
        ax.set_xlabel("memory requested", fontsize=9)
        shown = [p for p in entries if key == "all" or (p["bytes"] <= zoom[0] and p["seconds"] <= zoom[1])]
        _draw(ax, shown, [path for path in links if all(p in shown for p in path)], x_size, y_size)
        panels[key] = {"x_unit": x_unit, "y_unit": y_unit, "x_max": xmax / x_size, "y_max": ymax / y_size}
    (_, main_x), (_, main_y) = units["all"]
    main.add_patch(Rectangle((-0.05 * limits["all"][0] / main_x, -0.06 * limits["all"][1] / main_y),
                             (zoom[0] + 0.05 * limits["all"][0]) / main_x, (zoom[1] + 0.06 * limits["all"][1]) / main_y,
                             facecolor="#eef1f4",
                             edgecolor="#9aa4ae", linewidth=0.8, zorder=1))
    near.set_facecolor("#eef1f4")
    if panels["all"]["y_unit"] == panels["zoom"]["y_unit"]:
        near.set_ylabel("")  # the same label once, on the left panel
    named = [p for p in entries if p.get("name") and p["bytes"] <= zoom[0] and p["seconds"] <= zoom[1]]
    if named:
        (_, near_x), (_, near_y) = units["zoom"]
        unplaced = place_labels(near, [p["bytes"] / near_x for p in named], [p["seconds"] / near_y for p in named],
                                [p["name"] for p in named], fontsize=9)
        if unplaced:
            raise ValueError(f"labels that fit nowhere: {unplaced}")
    for ax, text in ((main, "all"), (near, zoom_heading)):
        heading = ax.text(0, 1.03, text, transform=ax.transAxes, fontsize=9, fontweight="bold", ha="left", va="bottom")
        tag_artist(heading, semantic_role="column_heading")
    handles, labels, seen = [], [], set()
    for entry in entries:
        if entry["label"] in seen:
            continue
        seen.add(entry["label"])
        handles.append(OffsetImage(entry["image"]) if entry["kind"] == "logo" else tuple(
            Line2D([], [], linestyle="none", **style) for style in _marker_styles(entry, 0.85)))
        labels.append(entry["label"])
    fig.legend(handles, labels, handler_map={tuple: HandlerTuple(ndivide=1), OffsetImage: _LogoHandler()},
               loc="upper center",
               bbox_to_anchor=(0.5, 0.99), ncol=3, fontsize=9, handlelength=1.2,
               handletextpad=0.4, columnspacing=1.2, borderaxespad=0, frameon=False)
    return fig, {"plot_kind": "one input: memory requested across, time up, linear axes; right panel enlarges the grey box",
                 "target_width_cm": target_width_cm,
                 "panels": panels, "zoom_box": {"bytes": zoom[0], "seconds": zoom[1]},
                 "memory_definition": MEMORY_NOTE,
                 "plotted_points": [{k: v for k, v in p.items() if k in ("label", "name", "bytes", "seconds")}
                                    for p in entries]}


def headline_figure(builds, sources, job, *, target_width_cm):
    """R against an experiment's builds in the case with one predictor and N = 45,000."""
    r = headline_row(R_TIMING, ("r_s", "r_workspace_bytes"))
    zoom = (max(p["bytes"] for p in builds) * 1.35, max(p["seconds"] for p in builds) * 1.5)
    fig, kind = absolute_figure([r_point(r["r_s"], r["r_workspace_bytes"]), *builds], zoom=zoom,
                                target_width_cm=target_width_cm)
    return fig, {**kind, "scientific_job": job, "input": HEADLINE_TEXT,
                 "sources": [source_record(R_TIMING, ["r_s", "r_workspace_bytes"]), *sources],
                 "timing": "median user CPU; R from exp_002, each build from its own experiment"}
