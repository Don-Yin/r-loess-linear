"""The inverse-neighbor cache against R in the one-predictor, N = 45,000 timing case."""
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

TIMING = "experiments/exp_000_nov6_cache/.results/tables/timing.csv"
COLUMNS = ("r_s", "variant_s", "r_native_bytes", "native_bytes")


def build_figure(*, target_width_cm: float = FULL_TEXT_WIDTH_CM):
    timing = headline_row(TIMING, COLUMNS)
    original = r_point(timing["r_s"], timing["r_native_bytes"])
    cache = build_point("cache", 0, DEFAULT_BLUE, timing["variant_s"], timing["native_bytes"])
    zoom = (max(original["bytes"], cache["bytes"]) * 1.08, cache["seconds"] * 1.5)
    fig, record = absolute_figure([original, cache], zoom=zoom, target_width_cm=target_width_cm)
    return fig, {**record, "scientific_job": "compare cache memory and prediction time with original R",
                 "input": HEADLINE_TEXT, "sources": [source_record(TIMING, list(COLUMNS))],
                 "timing": "median user CPU of each public prediction call, both from this experiment",
                 "zoom_definition": "same memory range; the grey strip enlarges the low-time range"}
