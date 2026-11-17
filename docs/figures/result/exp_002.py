"""Prototype against R, in the timing case with one predictor and N = 45,000."""
from __future__ import annotations

from python_plotting_convention import FULL_TEXT_WIDTH_CM  # pyright: ignore[reportMissingImports]
from result_data import (
    DEFAULT_BLUE,
    PROTOTYPE_TIMING,
    build_point,
    headline_figure,
    headline_row,
    source_record,
)

TIMING_COLUMNS = ("variant_s", "native_bytes")


def build_figure(*, target_width_cm: float = FULL_TEXT_WIDTH_CM):
    timing = headline_row(PROTOTYPE_TIMING, TIMING_COLUMNS)
    prototype = build_point("prototype", 2, DEFAULT_BLUE, timing["variant_s"], timing["native_bytes"])
    return headline_figure([prototype], [source_record(PROTOTYPE_TIMING, list(TIMING_COLUMNS))],
                           "prototype memory and time against R in one large timing case",
                           target_width_cm=target_width_cm)
