"""The deletion-only source and further reductions against R at N = 45,000."""
from __future__ import annotations

from python_plotting_convention import FULL_TEXT_WIDTH_CM  # pyright: ignore[reportMissingImports]
from result_data import (
    BEFORE_RED,
    DEFAULT_BLUE,
    HEADLINE_TEXT,
    absolute_figure,
    build_point,
    headline_row,
    r_point,
    source_record,
)

TABLES = "experiments/exp_007_shorter_source/.results/tables"
TIMING = f"{TABLES}/ordinary-timing.csv"
BYTES = f"{TABLES}/requested-bytes.csv"
TIME_COLUMNS = ("r_s", "deletions_only_s", "reduced_s")
BYTE_COLUMNS = ("r_native_bytes", "deletions_only_native_bytes", "reduced_native_bytes")


def build_figure(*, target_width_cm: float = FULL_TEXT_WIDTH_CM):
    timing, size = headline_row(TIMING, TIME_COLUMNS), headline_row(BYTES, BYTE_COLUMNS)
    for path, row in ((TIMING, timing), (BYTES, size)):
        if row["identical"] != "TRUE":
            raise ValueError(f"{path}: {HEADLINE_TEXT} is not identical to R")
    original = r_point(timing["r_s"], size["r_native_bytes"])
    builds = [build_point(label, 7, colour, timing[f"{variant}_s"], size[f"{variant}_native_bytes"], filled=filled)
              for variant, label, colour, filled in (
                  ("deletions_only", "deletions only", DEFAULT_BLUE, True),
                  ("reduced", "additional reductions", BEFORE_RED, False))]
    zoom = (max(point["bytes"] for point in builds) * 1.35, max(point["seconds"] for point in builds) * 1.5)
    fig, record = absolute_figure([original, *builds], zoom=zoom, target_width_cm=target_width_cm)
    return fig, {**record, "scientific_job": "compare deletion-only source and further reductions with original R",
                 "input": HEADLINE_TEXT,
                 "sources": [source_record(TIMING, ["identical", *TIME_COLUMNS]),
                             source_record(BYTES, ["identical", *BYTE_COLUMNS])],
                 "timing": "median user CPU of public predictions; all methods measured by this experiment",
                 "memory": "original R from its allocation formula; both variants from separate checked probe libraries"}
