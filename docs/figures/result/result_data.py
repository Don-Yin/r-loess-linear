"""Read saved figure data and share its colours, markers and source records."""
from __future__ import annotations

import csv
import hashlib
from pathlib import Path
from typing import Any, cast

import numpy as np
from matplotlib.image import BboxImage, imread
from matplotlib.legend_handler import HandlerBase
from matplotlib.offsetbox import OffsetImage
from matplotlib.transforms import Bbox, TransformedBbox

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
    return {"path": relative_path, "sha256": hashlib.sha256((ROOT / relative_path).read_bytes()).hexdigest(),
            "columns": columns}


def quiet_axes(ax):
    ax.spines[["top", "right"]].set_visible(False)
    ax.tick_params(labelsize=9)
    ax.grid(axis="x", color="#d9dfe4", linestyle=":", linewidth=0.6)
    ax.set_axisbelow(True)


DEFAULT_BLUE = "#4477aa"
BEFORE_RED = "#cc6677"
KEPT_GREEN = "#228833"
DROPPED_PURPLE = "#aa3377"

# R's logo comes from doc/html/Rlogo.svg of R 4.5.2 (The R Foundation, CC-BY-SA 4.0).
# Sources, licence links, transformations and Python-mark terms: docs/licences.md.

R_LOGO = imread(ROOT / "docs/assets/r-logo.png")
LOGO_PT = 13
R_ON_TIED = "docs/figures/result/r-tied.json"


class _LogoHandler(HandlerBase):
    """Show the supplied logo centred in a legend handle."""

    def create_artists(self, legend, orig_handle, xdescent, ydescent, width, height, fontsize, trans):
        logo = np.asarray(cast(OffsetImage, orig_handle).get_data())
        tall = 1.5 * height
        wide = tall * logo.shape[1] / logo.shape[0]
        box = Bbox.from_bounds(width / 2 - xdescent - wide / 2, height / 2 - ydescent - tall / 2, wide, tall)
        image = BboxImage(TransformedBbox(box, trans), interpolation="antialiased")
        image.set_data(logo)
        return [image]


def _marker_styles(entry, scale=1.0):
    """Draw one build's numbered circle as two Line2D marker layers."""
    colour, filled = entry["color"], entry["filled"]
    return [{"marker": "o", "markersize": 11 * scale, "color": colour, "markeredgewidth": 1.1,
             "markerfacecolor": colour if filled else "white"},
            {"marker": f"$\\mathsf{{{entry['digit']}}}$", "markersize": 6 * scale, "markeredgewidth": 0,
             "color": "white" if filled else colour, "markerfacecolor": "white" if filled else colour}]


X_PAD, Y_PAD = 0.08, 0.10
ZOOM_COLOUR = "#dd6b20"
MIN_BOX_PT = 18


def _visible_box(ax, low, high):
    """Grow a zoom box about its centre to at least MIN_BOX_PT on each side."""
    corners = ax.transData.transform([low, high])
    grow = np.maximum(MIN_BOX_PT * ax.figure.dpi / 72 - (corners[1] - corners[0]), 0) / 2
    return ax.transData.inverted().transform([corners[0] - grow, corners[1] + grow])
