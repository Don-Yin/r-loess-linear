"""Actual-vertex coefficient storage against R in the one-predictor, N = 45,000 timing case."""
from __future__ import annotations

from python_plotting_convention import FULL_TEXT_WIDTH_CM  # pyright: ignore[reportMissingImports]
from result_data import (
    DEFAULT_BLUE,
    HEADLINE_TEXT,
    absolute_figure,
    build_point,
    headline_row,
    r_point,
    source_record,
)

TIMING = "experiments/exp_001_actual_vertices/.results/tables/timing.csv"
COLUMNS = ("r_s", "variant_s", "r_native_bytes", "native_bytes")


def build_figure(*, target_width_cm: float = FULL_TEXT_WIDTH_CM):
    timing = headline_row(TIMING, COLUMNS)
    original = r_point(timing["r_s"], timing["r_native_bytes"])
    actual = build_point("actual vertices", 1, DEFAULT_BLUE, timing["variant_s"], timing["native_bytes"])
    zoom = (actual["bytes"] * 1.35, actual["seconds"] * 1.5)
    fig, record = absolute_figure([original, actual], zoom=zoom, target_width_cm=target_width_cm)
    return fig, {**record, "scientific_job": "compare actual-vertex storage memory and prediction time with original R",
                 "input": HEADLINE_TEXT, "sources": [source_record(TIMING, list(COLUMNS))],
                 "timing": "median user CPU of each public prediction call, both from this experiment"}
